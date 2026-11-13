begin;
create type public.development_object_type as enum ('PROBLEM','IDEA','SOLUTION','FEATURE','FUNCTION','COMPONENT','SYSTEM','SUBSYSTEM','GAP','OPEN_QUESTION','REQUIREMENT','RISK');
alter table public.development_projects add constraint development_projects_id_workspace_unique unique(id,primary_workspace_id);
create table public.development_objects (
 id uuid primary key default gen_random_uuid(),
 project_id uuid not null references public.development_projects(id) on delete restrict,
 workspace_id uuid not null references public.workspaces(id) on delete restrict,
 object_type public.development_object_type not null,
 title text not null check(length(btrim(title))>0),
 content text not null default '',
 status text check(status is null or length(btrim(status))>0),
 verification_status text check(verification_status is null or length(btrim(verification_status))>0),
 origin_type text check(origin_type is null or length(btrim(origin_type))>0),
 origin_reference_id uuid,
 created_by uuid not null references public.users(id) on delete restrict,
 current_version_number integer not null default 1 check(current_version_number>=1),
 archived_at timestamptz,
 metadata jsonb not null default '{}' check(jsonb_typeof(metadata)='object'),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 foreign key(project_id,workspace_id) references public.development_projects(id,primary_workspace_id) on update restrict on delete restrict
);
create index development_objects_project on public.development_objects(project_id);
create index development_objects_workspace on public.development_objects(workspace_id);
create index development_objects_type on public.development_objects(object_type);
create index development_objects_creator on public.development_objects(created_by);
create index development_objects_archive on public.development_objects(archived_at);
create index development_objects_project_workspace on public.development_objects(project_id,workspace_id);
comment on column public.development_objects.origin_reference_id is 'Nullable provenance UUID; source-specific validation/FKs deferred until the owning M7+ entities exist.';
comment on column public.development_objects.status is 'Nullable nonblank descriptive metadata; no permanent lifecycle vocabulary or authorization semantics in M6.5.';
comment on column public.development_objects.verification_status is 'Nullable descriptive metadata; no verification workflow or authorization semantics.';
comment on column public.development_objects.origin_type is 'Nullable descriptive provenance metadata; controlled origin vocabulary deferred to approved provenance operations.';
comment on column public.development_objects.workspace_id is 'M6.5 binds objects to their Project primary Workspace. Authorized related Workspace support requires a later explicit policy/model.';
create function public.preserve_development_object_identity() returns trigger language plpgsql set search_path='' as $$
begin
 if tg_op='DELETE' then raise exception 'Development Object history must be preserved' using errcode='23514';end if;
 if (new.id,new.project_id,new.workspace_id,new.created_by,new.created_at) is distinct from (old.id,old.project_id,old.workspace_id,old.created_by,old.created_at) then
 raise exception 'Development Object identity is immutable' using errcode='23514';end if;
 return new;
end $$;
revoke all on function public.preserve_development_object_identity() from public,anon,authenticated,service_role;
create trigger development_objects_preserve_identity before update or delete on public.development_objects for each row execute function public.preserve_development_object_identity();
alter table public.development_objects enable row level security;
revoke all on public.development_objects from public,anon,authenticated,service_role;
grant select on public.development_objects to authenticated;
-- Invoker subqueries compose existing Project AND Workspace RLS; no definer,
-- supplied identity, metadata authorization, or circular dependency is added.
create policy development_objects_read on public.development_objects for select to authenticated using(
 exists(select 1 from public.development_projects p where p.id=project_id and p.primary_workspace_id=workspace_id)
 and exists(select 1 from public.workspaces w where w.id=workspace_id));
create policy development_objects_read_guard on public.development_objects as restrictive for select to authenticated using(
 exists(select 1 from public.development_projects p where p.id=project_id and p.primary_workspace_id=workspace_id)
 and exists(select 1 from public.workspaces w where w.id=workspace_id));
create policy development_objects_insert_deny on public.development_objects as restrictive for insert to authenticated with check(false);
create policy development_objects_update_deny on public.development_objects as restrictive for update to authenticated using(false) with check(false);
create policy development_objects_delete_deny on public.development_objects as restrictive for delete to authenticated using(false);
create policy development_objects_anon_deny on public.development_objects as restrictive for all to anon using(false) with check(false);
commit;
