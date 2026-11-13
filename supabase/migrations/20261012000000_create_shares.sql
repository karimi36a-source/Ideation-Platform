-- M13.1 structural foundation only. No recipient access resolver or client writer.
begin;
create type public.share_entity_type as enum ('ARTIFACT','DEVELOPMENT_OBJECT','FILE','EVIDENCE','PATENT_RECORD','SCAMPER_ENTRY');
create type public.share_destination_type as enum ('USER','TEAM','MASTER','COHORT','WORKSPACE');
create type public.share_permission_level as enum ('VIEW','COMMENT','COLLABORATE');
create type public.share_mode as enum ('LIVE_REFERENCE','SNAPSHOT');
create table public.shares (
 id uuid primary key default gen_random_uuid(),
 source_workspace_id uuid not null references public.workspaces(id) on delete restrict,
 shared_entity_type public.share_entity_type not null,
 shared_entity_id uuid not null,
 shared_by uuid not null default public.current_platform_user_id() references public.users(id) on delete restrict,
 destination_type public.share_destination_type not null,
 destination_id uuid not null,
 permission_level public.share_permission_level not null,
 share_mode public.share_mode not null,
 created_at timestamptz not null default clock_timestamp(),
 revoked_at timestamptz,
 revoked_by uuid references public.users(id) on delete restrict,
 constraint shares_revocation_pair check ((revoked_at is null)=(revoked_by is null)),
 constraint shares_revocation_time check (revoked_at is null or revoked_at>=created_at)
);
create unique index shares_identical_active_unique on public.shares(source_workspace_id,shared_entity_type,shared_entity_id,destination_type,destination_id,permission_level,share_mode) where revoked_at is null;
create index shares_entity_lookup on public.shares(shared_entity_type,shared_entity_id);
create index shares_destination_lookup on public.shares(destination_type,destination_id);
create index shares_revocation_lookup on public.shares(revoked_at);
create index shares_source_workspace_lookup on public.shares(source_workspace_id);
alter table public.shares enable row level security;
revoke all on public.shares from public,anon,authenticated,service_role;
-- No policies: even a separately granted SELECT cannot expose Share metadata.
create function private.validate_share_structure() returns trigger language plpgsql set search_path='' as $$
declare source_workspace uuid;source_project uuid;w public.workspaces;valid_destination boolean:=false;actor uuid:=public.current_platform_user_id();
begin
 if tg_op='DELETE' then raise exception 'Share history is preserved' using errcode='23514';end if;
 if tg_op='UPDATE' then
  if old.revoked_at is not null or
   (to_jsonb(new)-'revoked_at'-'revoked_by') is distinct from (to_jsonb(old)-'revoked_at'-'revoked_by')
   or new.revoked_at is null or new.revoked_by is distinct from actor or actor is null
  then raise exception 'Share history is immutable' using errcode='23514';end if;
  new.revoked_at:=clock_timestamp();
  return new;
 end if;
 if actor is null or new.shared_by is distinct from actor or new.revoked_at is not null or new.revoked_by is not null then
  raise exception 'Invalid Share attribution' using errcode='42501';end if;
 case new.shared_entity_type
 when 'ARTIFACT' then select workspace_id,project_id into source_workspace,source_project from public.artifacts where id=new.shared_entity_id for key share;
 when 'DEVELOPMENT_OBJECT' then select workspace_id,project_id into source_workspace,source_project from public.development_objects where id=new.shared_entity_id for key share;
 when 'FILE' then select workspace_id,project_id into source_workspace,source_project from public.files where id=new.shared_entity_id for key share;
 when 'EVIDENCE' then select workspace_id,project_id into source_workspace,source_project from public.evidence where id=new.shared_entity_id for key share;
 when 'PATENT_RECORD' then select workspace_id,project_id into source_workspace,source_project from public.patent_records where id=new.shared_entity_id for key share;
 when 'SCAMPER_ENTRY' then select workspace_id,project_id into source_workspace,source_project from public.scamper_entries where id=new.shared_entity_id for key share;
 end case;
 if source_workspace is null or (new.source_workspace_id is not null and new.source_workspace_id<>source_workspace)
  or (source_project is not null and not exists(select 1 from public.development_projects where id=source_project and primary_workspace_id=source_workspace))
 then raise exception 'Invalid Share source' using errcode='23514';end if;
 new.source_workspace_id:=source_workspace;
 select * into w from public.workspaces where id=source_workspace;
 case new.destination_type
 when 'USER' then select exists(select 1 from public.users where id=new.destination_id) into valid_destination;
 when 'TEAM' then select exists(select 1 from public.teams where id=new.destination_id) into valid_destination;
 when 'WORKSPACE' then select exists(select 1 from public.workspaces where id=new.destination_id) into valid_destination;
 when 'COHORT' then select exists(select 1 from public.cohorts where id=new.destination_id) into valid_destination;
 when 'MASTER' then
  -- Match the existing exact Team/Cohort MASTER scope shape; no global or
  -- organization/program authority is inferred, and no access is granted.
  select exists(select 1 from public.role_assignments ra join public.roles r on r.id=ra.role_id
   join public.users u on u.id=ra.user_id
   where ra.id=new.destination_id and r.code='MASTER' and u.account_status='active'
   and ra.status='active' and ra.starts_at<=statement_timestamp() and (ra.ends_at is null or ra.ends_at>statement_timestamp())
   and ra.organization_id is null and ra.program_id is null and ra.project_id is null
   and ((ra.team_id=w.team_id and ra.cohort_id is null) or (ra.cohort_id=w.cohort_id and ra.team_id is null))) into valid_destination;
 end case;
 if not valid_destination then raise exception 'Invalid Share destination' using errcode='23514';end if;
 new.created_at:=clock_timestamp();
 return new;
end $$;
revoke all on function private.validate_share_structure() from public,anon,authenticated,service_role;
create trigger shares_structure before insert or update or delete on public.shares for each row execute function private.validate_share_structure();
comment on table public.shares is 'M13.1 inert object-specific sharing records. No recipient authorization, snapshot payload, re-sharing or client mutation is enabled.';
commit;
