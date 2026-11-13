begin;
create type public.brainstorm_entry_status as enum ('active','archived');
create table public.brainstorm_entries (
 id uuid primary key default gen_random_uuid(),
 activity_instance_id uuid not null,
 project_id uuid not null,
 workspace_id uuid not null references public.workspaces(id) on delete restrict,
 created_by uuid not null default auth.uid() references public.users(id) on delete restrict,
 content text not null,
 revealed_at timestamptz,
 parent_entry_id uuid,
 development_object_id uuid,
 status public.brainstorm_entry_status not null default 'active',
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 updated_by uuid not null references public.users(id) on delete restrict,
 archived_at timestamptz,
 constraint brainstorm_activity_scope foreign key(activity_instance_id,project_id,workspace_id)
  references public.activity_instances(id,project_id,workspace_id) on update restrict on delete restrict,
 constraint brainstorm_project_workspace foreign key(project_id,workspace_id)
  references public.development_projects(id,primary_workspace_id) on update restrict on delete restrict,
 constraint brainstorm_object_project foreign key(development_object_id,project_id)
  references public.development_objects(id,project_id) on update restrict on delete restrict,
 constraint brainstorm_identity_scope unique(id,activity_instance_id,project_id,workspace_id),
 constraint brainstorm_parent_scope foreign key(parent_entry_id,activity_instance_id,project_id,workspace_id)
 references public.brainstorm_entries(id,activity_instance_id,project_id,workspace_id) on update restrict on delete restrict,
 constraint brainstorm_not_self_parent check(parent_entry_id is distinct from id),
 constraint brainstorm_archive_state check((status='active' and archived_at is null) or (status='archived' and archived_at is not null))
);
create index brainstorm_activity_lookup on public.brainstorm_entries(activity_instance_id);
create index brainstorm_project_lookup on public.brainstorm_entries(project_id);
create index brainstorm_workspace_lookup on public.brainstorm_entries(workspace_id);
create index brainstorm_creator_lookup on public.brainstorm_entries(created_by);
create index brainstorm_object_lookup on public.brainstorm_entries(development_object_id) where development_object_id is not null;
-- Invoker-only integrity guard. This is not a public write/provisioning path.
create function public.validate_brainstorm_entry() returns trigger language plpgsql set search_path='' as $$
declare actor uuid:=auth.uid();
begin
 if tg_op='DELETE' then raise exception 'Brainstorm history must be preserved' using errcode='23514';end if;
 if actor is not null and (public.current_platform_user_id() is distinct from actor or new.created_by is distinct from actor
  or not public.can_read_activity_instance(new.activity_instance_id)) then raise exception 'Resource unavailable' using errcode='42501';end if;
 if actor is not null and new.revealed_at is not null then raise exception 'Reveal workflow unavailable' using errcode='42501';end if;
 if tg_op='UPDATE' then
  if (new.id,new.activity_instance_id,new.project_id,new.workspace_id,new.created_by,new.created_at)
   is distinct from (old.id,old.activity_instance_id,old.project_id,old.workspace_id,old.created_by,old.created_at) then
   raise exception 'Brainstorm identity and provenance are immutable' using errcode='23514';end if;
  if old.status='archived' and new is distinct from old then raise exception 'Archived Brainstorm history is immutable' using errcode='23514';end if;
  if new is not distinct from old then return old;end if;

 end if;
 if not exists(select 1 from public.activity_instances i join public.activity_definitions d on d.id=i.activity_definition_id
  where i.id=new.activity_instance_id and i.project_id=new.project_id and i.workspace_id=new.workspace_id and d.method_type='brainstorming' and (not (i.configuration_snapshot ? 'method_type') or i.configuration_snapshot->>'method_type'='brainstorming')) then
  raise exception 'Invalid Brainstorm Activity context' using errcode='23514';end if;
 if new.development_object_id is not null and not exists(select 1 from public.development_objects o
  where o.id=new.development_object_id and o.object_type in ('IDEA','SOLUTION') and o.project_id=new.project_id and o.workspace_id=new.workspace_id) then
  raise exception 'Invalid Brainstorm Object context' using errcode='23514';end if;
 if new.parent_entry_id is not null and actor is not null and not exists(select 1 from public.brainstorm_entries p
  where p.id=new.parent_entry_id and p.created_by=actor and p.activity_instance_id=new.activity_instance_id
  and p.project_id=new.project_id and p.workspace_id=new.workspace_id) then raise exception 'Resource unavailable' using errcode='42501';end if;
 if tg_op='INSERT' then new.updated_by:=new.created_by;
 else new.updated_by:=coalesce(actor,new.updated_by);new.updated_at:=pg_catalog.clock_timestamp();end if;
 return new;
end $$;
revoke all on function public.validate_brainstorm_entry() from public,anon,authenticated,service_role;
create trigger brainstorm_entries_integrity before insert or update or delete on public.brainstorm_entries
 for each row execute function public.validate_brainstorm_entry();
alter table public.brainstorm_entries enable row level security;
revoke all on public.brainstorm_entries from public,anon,authenticated,service_role;
grant select on public.brainstorm_entries to authenticated;
create policy brainstorm_owner_read on public.brainstorm_entries for select to authenticated
 using(created_by=public.current_platform_user_id() and public.can_read_activity_instance(activity_instance_id));
create policy brainstorm_read_guard on public.brainstorm_entries as restrictive for select to authenticated
 using(created_by=public.current_platform_user_id() and public.can_read_activity_instance(activity_instance_id));
create index brainstorm_parent_lookup on public.brainstorm_entries(parent_entry_id) where parent_entry_id is not null;
comment on table public.brainstorm_entries is 'M9.5 creator-only reads with current Activity authorization. No client writes or reveal/promotion behavior.';
comment on column public.brainstorm_entries.status is 'Identity lifecycle only; reveal state exclusively revealed_at.';
comment on column public.brainstorm_entries.parent_entry_id is 'Exact Activity/Project/Workspace scope. Future create operation must revalidate parent visibility and prevent cycles; no public writes in M9.5.';
comment on column public.brainstorm_entries.development_object_id is 'Same-context IDEA/SOLUTION only; no promotion.';
commit;
