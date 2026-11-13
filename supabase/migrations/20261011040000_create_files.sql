begin;
create type public.file_status as enum ('active','archived');
create type public.file_link_entity_type as enum ('EVIDENCE','ARTIFACT','ACTIVITY_INSTANCE','CHAT_MESSAGE','DEVELOPMENT_OBJECT');
create type public.file_relationship_type as enum ('ATTACHMENT','EVIDENCE_SOURCE','ARTIFACT_FILE','CHAT_ATTACHMENT','REFERENCE');
create table public.files (
 id uuid primary key default gen_random_uuid(),
 uploaded_by uuid not null default public.current_platform_user_id() references public.users(id) on update restrict on delete restrict,
 workspace_id uuid not null references public.workspaces(id) on update restrict on delete restrict,
 project_id uuid,
 storage_reference text generated always as ('workspaces/'||workspace_id::text||'/files/'||id::text) stored not null unique,
 filename text not null check(length(btrim(filename))>0 and filename not in ('.','..') and filename !~ E'[\\\\/[:cntrl:]]'),
 mime_type text not null check(mime_type ~ '^[A-Za-z0-9][A-Za-z0-9!#$&^_.+-]*/[A-Za-z0-9][A-Za-z0-9!#$&^_.+-]*$'),
 size bigint not null check(size>=0 and size<=9007199254740991),
 status public.file_status not null default 'active',
 created_at timestamptz not null default statement_timestamp(),
 updated_at timestamptz not null default statement_timestamp(),
 updated_by uuid not null default public.current_platform_user_id() references public.users(id) on update restrict on delete restrict,
 archived_at timestamptz,
 constraint files_project_workspace foreign key(project_id,workspace_id) references public.development_projects(id,primary_workspace_id) on update restrict on delete restrict,
 constraint files_archive_state check((status='active' and archived_at is null) or (status='archived' and archived_at is not null and archived_at>=created_at)),
 constraint files_update_time check(updated_at>=created_at)
);
comment on column public.files.storage_reference is 'Generated provider-internal key in the fici-private-files bucket. Never a URL or caller-selected path. Does not register or upload an object.';
comment on column public.files.size is 'Nonnegative integer bytes bounded by exact JavaScript number representation, not an upload product maximum. M12.7 owns upload validation.';
create index files_workspace_lookup on public.files(workspace_id);
create index files_project_lookup on public.files(project_id) where project_id is not null;
create index files_uploader_lookup on public.files(uploaded_by);
-- Normal metadata reads always filter lifecycle state alongside the owning scope.
create index files_active_workspace_lookup on public.files(workspace_id,id) where status='active' and archived_at is null;

create function public.can_read_file_scope(target_workspace uuid,target_project uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select public.current_platform_user_id() is not null and exists(
  select 1 from public.workspaces w where w.id=target_workspace and w.status='active' and w.visibility='private'
  and (case w.workspace_type
   when 'PERSONAL' then w.owner_user_id=public.current_platform_user_id() and w.team_id is null
   when 'TEAM' then public.get_team_workspace_access(w.id) is not null
   when 'MASTER' then w.owner_user_id=public.current_platform_user_id() and w.cohort_id is not null and public.has_active_role_in_cohort('MASTER',w.cohort_id)
   when 'CASE_STUDY' then w.owner_user_id=public.current_platform_user_id() and w.cohort_id is not null and public.has_active_role_in_cohort('MASTER',w.cohort_id)
   else false end)
  and (target_project is null or exists(select 1 from public.development_projects p where p.id=target_project and p.primary_workspace_id=w.id and public.can_read_development_project(p.id))))
$$;
revoke all on function public.can_read_file_scope(uuid,uuid) from public,anon,authenticated,service_role;
grant execute on function public.can_read_file_scope(uuid,uuid) to authenticated;

create function private.preserve_file_history() returns trigger language plpgsql set search_path='' as $$
declare actor uuid:=public.current_platform_user_id();
begin
 if tg_op='DELETE' then raise exception 'File history is preserved' using errcode='55000';end if;
 if actor is null then raise exception 'Authentication required' using errcode='28000';end if;
 if tg_op='INSERT' then
  if new.uploaded_by is distinct from actor or new.updated_by is distinct from actor then raise exception 'Uploader must match authenticated actor' using errcode='42501';end if;
  if not public.can_read_file_scope(new.workspace_id,new.project_id) then raise exception 'Resource unavailable' using errcode='42501';end if;
  new.created_at:=statement_timestamp();new.updated_at:=new.created_at;
 else
  if (new.id,new.uploaded_by,new.workspace_id,new.project_id,new.filename,new.mime_type,new.size,new.created_at)
   is distinct from (old.id,old.uploaded_by,old.workspace_id,old.project_id,old.filename,old.mime_type,old.size,old.created_at)
  then raise exception 'File identity and metadata are immutable' using errcode='23514';end if;
  if old.status='archived' then
   if new is distinct from old then raise exception 'Archived File is immutable' using errcode='55000';end if;
   return old;
  end if;
  new.updated_by:=actor;new.updated_at:=statement_timestamp();
 end if;
 return new;
end$$;
revoke all on function private.preserve_file_history() from public,anon,authenticated,service_role;
create trigger files_history_guard before insert or update or delete on public.files for each row execute function private.preserve_file_history();
alter table public.files enable row level security;
revoke all on public.files from public,anon,authenticated,service_role;
grant select on public.files to authenticated;
create policy files_current_scope_read on public.files for select to authenticated using(status='active' and archived_at is null and public.can_read_file_scope(workspace_id,project_id));
create policy files_no_client_insert on public.files as restrictive for insert to authenticated with check(false);
create policy files_no_client_update on public.files as restrictive for update to authenticated using(false) with check(false);
create policy files_no_client_delete on public.files as restrictive for delete to authenticated using(false);

create table public.file_links (
 id uuid primary key default gen_random_uuid(),
 file_id uuid not null references public.files(id) on update restrict on delete restrict,
 entity_type public.file_link_entity_type not null,
 entity_id uuid not null,
 relationship_type public.file_relationship_type not null,
 created_by uuid not null default public.current_platform_user_id() references public.users(id) on update restrict on delete restrict,
 created_at timestamptz not null default statement_timestamp(),
 archived_at timestamptz check(archived_at is null or archived_at>=created_at)
);
create unique index file_links_active_identity on public.file_links(file_id,entity_type,entity_id,relationship_type) where archived_at is null;
create index file_links_file_lookup on public.file_links(file_id);
create index file_links_target_lookup on public.file_links(entity_type,entity_id);
comment on column public.file_links.entity_id is 'Polymorphic canonical target UUID. M12.8 owns target resolution/authorization; no ordinary link mutation or SELECT is permitted in M12.6.';
create function private.preserve_file_link_history() returns trigger language plpgsql set search_path='' as $$
begin
 if tg_op='DELETE' then raise exception 'File Link history is preserved' using errcode='55000';end if;
 if public.current_platform_user_id() is null then raise exception 'Authentication required' using errcode='28000';end if;
 if tg_op='INSERT' then
  if new.created_by is distinct from public.current_platform_user_id() then raise exception 'Creator must match authenticated actor' using errcode='42501';end if;
  new.created_at:=statement_timestamp();
 elsif (new.id,new.file_id,new.entity_type,new.entity_id,new.relationship_type,new.created_by,new.created_at) is distinct from (old.id,old.file_id,old.entity_type,old.entity_id,old.relationship_type,old.created_by,old.created_at)
 then raise exception 'File Link identity is immutable' using errcode='23514';
 elsif old.archived_at is not null and new is distinct from old then raise exception 'Archived File Link is immutable' using errcode='55000';end if;
 return new;
end$$;
revoke all on function private.preserve_file_link_history() from public,anon,authenticated,service_role;
create trigger file_links_history_guard before insert or update or delete on public.file_links for each row execute function private.preserve_file_link_history();
alter table public.file_links enable row level security;
revoke all on public.file_links from public,anon,authenticated,service_role;
grant select on public.file_links to authenticated;
create policy file_links_deferred_read on public.file_links as restrictive for select to authenticated using(false);
create policy file_links_no_client_insert on public.file_links as restrictive for insert to authenticated with check(false);
create policy file_links_no_client_update on public.file_links as restrictive for update to authenticated using(false) with check(false);
create policy file_links_no_client_delete on public.file_links as restrictive for delete to authenticated using(false);

alter table public.evidence add constraint evidence_file_reference foreign key(file_id) references public.files(id) on update restrict on delete restrict;
create index evidence_file_lookup on public.evidence(file_id) where file_id is not null;
comment on column public.evidence.file_id is 'Canonical Files FK with RESTRICT history. New bindings require compatible current readable active File scope. createEvidence non-null File input remains deferred until secure upload/registration and linking milestones.';
create function private.validate_evidence_file_scope() returns trigger language plpgsql set search_path='' as $$
begin
 if new.file_id is not null and (tg_op='INSERT' or new.file_id is distinct from old.file_id) then
  if not exists(select 1 from public.files f where f.id=new.file_id and f.workspace_id=new.workspace_id
   and (f.project_id is null or f.project_id=new.project_id) and f.status='active' and f.archived_at is null
   and public.can_read_file_scope(f.workspace_id,f.project_id))
  then raise exception 'Resource unavailable' using errcode='42501';end if;
 end if;
 return new;
end$$;
revoke all on function private.validate_evidence_file_scope() from public,anon,authenticated,service_role;
create trigger evidence_file_scope_guard before insert or update of file_id on public.evidence for each row execute function private.validate_evidence_file_scope();
commit;
