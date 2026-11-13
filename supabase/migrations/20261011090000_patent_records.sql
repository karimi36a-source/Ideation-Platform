begin;
create type public.patent_relevance_status as enum ('NOT_REVIEWED','RELEVANT','POSSIBLY_RELEVANT','NOT_RELEVANT');
create type public.patent_source_database as enum ('PATENTSCOPE','USPTO','GOOGLE_PATENTS');
-- Syntax validation only: no fetch, provider/domain allowlist, normalization or legal inference.
create function private.valid_patent_source_url(value text) returns boolean
language plpgsql immutable set search_path='' as $$
declare parts text[];authority text;host text;port text;
begin
 parts:=pg_catalog.regexp_match(value,'^https://([^/?#[:space:]\\]+)([/?#][^[:space:]\\]*)?$','i');
 if parts is null then return false;end if;
 authority:=parts[1];
 -- Optional URL user-info is source metadata, never used as authentication.
 if pg_catalog.strpos(authority,'@')>0 then
  if authority !~ '^[^@]+@[^@]+$' then return false;end if;
  authority:=pg_catalog.split_part(authority,'@',2);
 end if;
 if pg_catalog.left(authority,1)='[' then
  parts:=pg_catalog.regexp_match(authority,'^\[([^]]+)\](:([0-9]+))?$');
  if parts is null or pg_catalog.strpos(parts[1],':')=0 or not pg_catalog.pg_input_is_valid(parts[1],'pg_catalog.inet') then return false;end if;
  host:=parts[1];port:=parts[3];
 else
  parts:=pg_catalog.regexp_match(authority,'^([[:alnum:]_.-]+)(:([0-9]+))?$');
  if parts is null then return false;end if;
  host:=parts[1];port:=parts[3];
  if host ~ '^\.' or host ~ '\.\.' then return false;end if;
  -- Numeric address hosts must be valid IPv4; do not accept malformed octets.
  if host ~ '^[0-9.]+$' and not pg_catalog.pg_input_is_valid(host,'pg_catalog.inet') then return false;end if;
 end if;
 if port is not null and (length(port)>5 or port::integer>65535) then return false;end if;
 return true;
end$$;
revoke all on function private.valid_patent_source_url(text) from public,anon,authenticated,service_role;
create table public.patent_records(
 id uuid primary key default gen_random_uuid(),
 project_id uuid not null,
 workspace_id uuid not null references public.workspaces(id) on update restrict on delete restrict,
 publication_number text not null check(length(btrim(publication_number))>0),
 application_number text,
 title text not null check(length(btrim(title))>0),
 applicant text,inventor text,
 priority_date date,filing_date date,publication_date date,
 ipc_cpc text,
 source_database public.patent_source_database not null,
 source_url text not null check(private.valid_patent_source_url(source_url)),
 abstract_text text,
 relevance_status public.patent_relevance_status not null default 'NOT_REVIEWED',
 why_retained text,
 created_by uuid not null default public.current_platform_user_id() references public.users(id) on update restrict on delete restrict,
 created_at timestamptz not null default statement_timestamp(),
 constraint patent_records_project_workspace foreign key(project_id,workspace_id) references public.development_projects(id,primary_workspace_id) on update restrict on delete restrict
);
create index patent_records_project_lookup on public.patent_records(project_id);
create index patent_records_workspace_lookup on public.patent_records(workspace_id);
create index patent_records_creator_lookup on public.patent_records(created_by);
create index patent_records_publication_lookup on public.patent_records(publication_number);
create function private.preserve_patent_record_history() returns trigger
language plpgsql set search_path='' as $$
declare actor uuid:=public.current_platform_user_id();
begin
 if tg_op='DELETE' then raise exception 'Patent research history is preserved' using errcode='55000';end if;
 if actor is null then raise exception 'Authentication required' using errcode='28000';end if;
 if tg_op='INSERT' then
  if new.created_by is distinct from actor then raise exception 'Creator must match authenticated actor' using errcode='42501';end if;
  new.created_at:=statement_timestamp();
 elsif (new.id,new.project_id,new.workspace_id,new.created_by,new.created_at) is distinct from (old.id,old.project_id,old.workspace_id,old.created_by,old.created_at) then
  raise exception 'Patent provenance and scope are immutable' using errcode='23514';
 end if;
 return new;
end$$;
revoke all on function private.preserve_patent_record_history() from public,anon,authenticated,service_role;
create trigger patent_records_history_guard before insert or update or delete on public.patent_records for each row execute function private.preserve_patent_record_history();
alter table public.patent_records enable row level security;
revoke all on public.patent_records from public,anon,authenticated,service_role;
grant select on public.patent_records to authenticated;
create policy patent_records_scoped_read on public.patent_records for select to authenticated using(public.can_read_development_project(project_id));
create policy patent_records_no_client_insert on public.patent_records as restrictive for insert to authenticated with check(false);
create policy patent_records_no_client_update on public.patent_records as restrictive for update to authenticated using(false) with check(false);
create policy patent_records_no_client_delete on public.patent_records as restrictive for delete to authenticated using(false);
comment on table public.patent_records is 'Retained patent source metadata only. No creation API, search, Evidence linkage, AI comparison or legal conclusions. Reads inherit current canonical Project/Workspace privacy.';
comment on column public.patent_records.relevance_status is 'Human research classification only; never novelty, patentability, infringement, validity, freedom-to-operate or legal opinion.';
comment on column public.patent_records.publication_number is 'Exact source value/formatting. Deliberately nonunique across and within scopes; no merge or legal-status inference.';
commit;
