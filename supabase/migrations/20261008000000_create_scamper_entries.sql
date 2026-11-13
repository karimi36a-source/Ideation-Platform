begin;
create type public.scamper_lens as enum ('SUBSTITUTE','COMBINE','ADAPT','MODIFY','PUT_TO_ANOTHER_USE','ELIMINATE','REVERSE_REARRANGE');
create type public.scamper_entry_status as enum ('active','archived');
create table public.scamper_entries (
 id uuid primary key default gen_random_uuid(),
 activity_instance_id uuid not null,
 project_id uuid not null,
 workspace_id uuid not null references public.workspaces(id) on delete restrict,
 created_by uuid not null default auth.uid() references public.users(id) on delete restrict,
 scamper_type public.scamper_lens not null,
 original_element text not null,
 proposed_change text not null,
 result_text text not null,
 idea_object_id uuid,
 status public.scamper_entry_status not null default 'active',
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 updated_by uuid not null references public.users(id) on delete restrict,
 archived_at timestamptz,
 constraint scamper_activity_scope foreign key(activity_instance_id,project_id,workspace_id)
  references public.activity_instances(id,project_id,workspace_id) on update restrict on delete restrict,
 constraint scamper_project_workspace foreign key(project_id,workspace_id)
  references public.development_projects(id,primary_workspace_id) on update restrict on delete restrict,
 constraint scamper_idea_project foreign key(idea_object_id,project_id)
  references public.development_objects(id,project_id) on update restrict on delete restrict,
 constraint scamper_archive_state check((status='active' and archived_at is null) or (status='archived' and archived_at is not null))
);
create index scamper_activity_lookup on public.scamper_entries(activity_instance_id);
create index scamper_project_lookup on public.scamper_entries(project_id);
create index scamper_workspace_lookup on public.scamper_entries(workspace_id);
create index scamper_creator_lookup on public.scamper_entries(created_by);
create index scamper_idea_lookup on public.scamper_entries(idea_object_id) where idea_object_id is not null;
-- Invoker-only integrity guard. This is not a public write/provisioning path.
create function public.validate_scamper_entry() returns trigger language plpgsql set search_path='' as $$
declare actor uuid:=auth.uid();
begin
 if tg_op='DELETE' then raise exception 'SCAMPER history must be preserved' using errcode='23514';end if;
 if tg_op='UPDATE' then
  if (new.id,new.activity_instance_id,new.project_id,new.workspace_id,new.created_by,new.created_at)
   is distinct from (old.id,old.activity_instance_id,old.project_id,old.workspace_id,old.created_by,old.created_at) then
   raise exception 'SCAMPER identity and provenance are immutable' using errcode='23514';end if;
  if old.status='archived' and new is distinct from old then raise exception 'Archived SCAMPER history is immutable' using errcode='23514';end if;
  if new is not distinct from old then return old;end if;
 else
  if actor is not null and (new.created_by is distinct from actor or public.current_platform_user_id() is distinct from actor
   or not public.can_read_activity_instance(new.activity_instance_id)) then
   raise exception 'Invalid SCAMPER actor or context' using errcode='42501';end if;
 end if;
 if not exists(select 1 from public.activity_instances i join public.activity_definitions d on d.id=i.activity_definition_id
  where i.id=new.activity_instance_id and i.project_id=new.project_id and i.workspace_id=new.workspace_id and d.method_type='scamper') then
  raise exception 'Invalid SCAMPER Activity context' using errcode='23514';end if;
 if new.idea_object_id is not null and not exists(select 1 from public.development_objects o
  where o.id=new.idea_object_id and o.object_type='IDEA' and o.project_id=new.project_id and o.workspace_id=new.workspace_id) then
  raise exception 'Invalid SCAMPER IDEA context' using errcode='23514';end if;
 if tg_op='INSERT' then new.updated_by:=new.created_by;
 else new.updated_by:=coalesce(actor,new.updated_by);new.updated_at:=pg_catalog.clock_timestamp();end if;
 return new;
end $$;
revoke all on function public.validate_scamper_entry() from public,anon,authenticated,service_role;
create trigger scamper_entries_integrity before insert or update or delete on public.scamper_entries
 for each row execute function public.validate_scamper_entry();
alter table public.scamper_entries enable row level security;
revoke all on public.scamper_entries from public,anon,authenticated,service_role;
-- Restrictive backstop also denies access if an ordinary grant/permissive policy is accidentally added.
create policy scamper_client_deny on public.scamper_entries as restrictive for all to authenticated,anon
 using(false) with check(false);
comment on table public.scamper_entries is 'M9.1 structured methodology schema only. Ordinary client access denied; CRUD, promotion, sharing and dedicated SCAMPER access policies belong to later tasks.';
comment on column public.scamper_entries.created_by is 'Verified database auth identity for future server writes. Explicit identities without auth context are restricted to trusted database fixtures/administration, never client CRUD.';
comment on column public.scamper_entries.idea_object_id is 'Optional same Project/Workspace IDEA reference only; no automatic promotion or Object creation.';
commit;
