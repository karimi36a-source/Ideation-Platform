begin;
-- Caller-bound boolean avoids RLS recursion. No row/creator metadata is returned.
create function public.can_read_brainstorm_entry(target_entry uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.brainstorm_entries b join public.activity_instances a on a.id=b.activity_instance_id
 where b.id=target_entry and public.can_read_activity_instance(a.id)
 and (b.created_by=public.current_platform_user_id() or
  (b.revealed_at is not null and a.team_id is not null
   and a.configuration_snapshot->>'method_type'='brainstorming'
   and a.configuration_snapshot #>> '{configuration,brainstorming,visibility_mode}'='private_before_reveal'
   and a.configuration_snapshot #>> '{configuration,brainstorming,reveal_authority}'='team_lead_or_scoped_master'
   and exists(select 1 from public.workspaces w where w.id=a.workspace_id and w.workspace_type='TEAM' and w.team_id=a.team_id))));
$$;
revoke all on function public.can_read_brainstorm_entry(uuid) from public,anon,authenticated,service_role;
grant execute on function public.can_read_brainstorm_entry(uuid) to authenticated;

-- Private elevated validation reuses M7 contribution/context locks. MASTER alone
-- never bypasses canonical Project/Workspace/Team access, matching M7 start.
create function private.require_brainstorm_reveal(target_instance uuid) returns public.activity_instances
language plpgsql volatile security definer set search_path='' as $$
declare a public.activity_instances;actor uuid;checked_at timestamptz;
begin
 a:=private.require_brainstorm_write(target_instance);actor:=public.current_platform_user_id();
 if a.team_id is null or not exists(select 1 from public.workspaces w where w.id=a.workspace_id and w.workspace_type='TEAM' and w.team_id=a.team_id)
  or a.configuration_snapshot #>> '{configuration,brainstorming,reveal_authority}' is distinct from 'team_lead_or_scoped_master' then
  raise exception 'Required Activity configuration unavailable' using errcode='0A000';end if;
 checked_at:=pg_catalog.clock_timestamp();
 if not exists(select 1 from public.team_memberships m join public.teams t on t.id=m.team_id
  where m.team_id=a.team_id and m.user_id=actor and t.team_lead_user_id=actor and m.membership_role='team_lead'
  and m.status='active' and m.left_at is null and m.joined_at<=checked_at)
 and not exists(select 1 from public.role_assignments ra join public.roles rr on rr.id=ra.role_id
  where ra.user_id=actor and rr.code='MASTER' and ra.status='active' and ra.starts_at<=checked_at and (ra.ends_at is null or ra.ends_at>checked_at)
  and ra.organization_id is null and ra.program_id is null and ra.project_id is null
  and ((ra.cohort_id=a.cohort_id and ra.team_id is null) or (ra.team_id=a.team_id and ra.cohort_id is null))) then
  raise exception 'Resource unavailable' using errcode='42501';end if;
 return a;
end $$;
revoke all on function private.require_brainstorm_reveal(uuid) from public,anon,authenticated,service_role;

-- Definer required for the narrow transition: clients retain SELECT-only grants.
create function public.reveal_brainstorm_entries(target_instance uuid,target_entries uuid[]) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare a public.activity_instances;n bigint;revealed timestamptz;result jsonb;
begin
 a:=private.require_brainstorm_reveal(target_instance);
 if target_entries is null or cardinality(target_entries)=0 or array_position(target_entries,null) is not null
  or cardinality(target_entries)<>(select count(distinct e) from unnest(target_entries) e) then
  raise exception 'Invalid input' using errcode='22023';end if;
 -- Deterministic row-lock order serializes overlapping requests; validate every
 -- target after waiting, before any mutation. No inaccessible row is returned.
 perform 1 from public.brainstorm_entries b where b.id=any(target_entries)
  and b.activity_instance_id=a.id and b.project_id=a.project_id and b.workspace_id=a.workspace_id and b.status='active'
  order by b.id for update;
 get diagnostics n=row_count;
 if n<>cardinality(target_entries) then raise exception 'Resource unavailable' using errcode='42501';end if;
 a:=private.require_brainstorm_reveal(target_instance);
 revealed:=pg_catalog.clock_timestamp();
 update public.brainstorm_entries set revealed_at=revealed where id=any(target_entries) and revealed_at is null;
 select jsonb_build_object('activityInstanceId',a.id,'entries',jsonb_agg(jsonb_build_object('entryId',b.id,'revealedAt',b.revealed_at) order by b.id))
 into result from public.brainstorm_entries b where b.id=any(target_entries);
 return result;
end $$;
revoke all on function public.reveal_brainstorm_entries(uuid,uuid[]) from public,anon,authenticated,service_role;
grant execute on function public.reveal_brainstorm_entries(uuid,uuid[]) to authenticated;
create or replace function public.validate_brainstorm_entry() returns trigger language plpgsql set search_path='' as $$
declare actor uuid:=auth.uid();reveal_change boolean:=false;
begin
 if tg_op='DELETE' then raise exception 'Brainstorm history must be preserved' using errcode='23514';end if;
 if tg_op='UPDATE' then
  if old.revealed_at is not null and new.revealed_at is distinct from old.revealed_at then raise exception 'Reveal history is immutable' using errcode='23514';end if;
  reveal_change:=old.revealed_at is null and new.revealed_at is not null;
 end if;
 if actor is not null and reveal_change then
  -- Execution role, not a caller-writable GUC, restricts the one transition.
  if current_user is distinct from pg_catalog.pg_get_userbyid((select proowner from pg_catalog.pg_proc where oid='public.reveal_brainstorm_entries(uuid,uuid[])'::regprocedure))
   or (to_jsonb(new)-array['revealed_at','updated_at','updated_by']) is distinct from (to_jsonb(old)-array['revealed_at','updated_at','updated_by']) then
   raise exception 'Resource unavailable' using errcode='42501';end if;
  begin perform private.require_brainstorm_reveal(new.activity_instance_id);
  exception when others then raise exception 'Resource unavailable' using errcode='42501';end;
 end if;
 if actor is not null and not reveal_change and (public.current_platform_user_id() is distinct from actor or new.created_by is distinct from actor
  or not public.can_read_activity_instance(new.activity_instance_id)) then raise exception 'Resource unavailable' using errcode='42501';end if;
 if actor is not null and new.revealed_at is not null and not reveal_change then raise exception 'Reveal workflow unavailable' using errcode='42501';end if;
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
 if new.parent_entry_id is not null and actor is not null and not reveal_change and not exists(select 1 from public.brainstorm_entries p
  where p.id=new.parent_entry_id and (p.created_by=actor or (p.revealed_at is not null and public.can_read_brainstorm_entry(p.id))) and p.activity_instance_id=new.activity_instance_id
  and p.project_id=new.project_id and p.workspace_id=new.workspace_id) then raise exception 'Resource unavailable' using errcode='42501';end if;
 if tg_op='INSERT' then new.updated_by:=new.created_by;
 else new.updated_by:=coalesce(actor,new.updated_by);new.updated_at:=pg_catalog.clock_timestamp();end if;
 return new;
end $$;
create or replace function public.create_brainstorm_entry(target_instance uuid,entry_content text,visibility_state text,parent_entry uuid default null)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare a public.activity_instances;actor uuid;parent public.brainstorm_entries;entry public.brainstorm_entries;
begin
 a:=private.require_brainstorm_write(target_instance);
 actor:=public.current_platform_user_id();
 if entry_content is null or visibility_state is distinct from 'private' then raise exception 'Invalid input' using errcode='22023';end if;
 if parent_entry is not null then
  -- Exact current M9.5 read predicate plus matching canonical scope. No foreign
  -- parent lock, content, existence distinction or lifecycle diagnostic escapes.
  select * into parent from public.brainstorm_entries p where p.id=parent_entry and (p.created_by=actor or (p.revealed_at is not null and public.can_read_brainstorm_entry(p.id)))
   and p.activity_instance_id=a.id and p.project_id=a.project_id and p.workspace_id=a.workspace_id and p.status='active'
   and public.can_read_activity_instance(p.activity_instance_id) for share;
  if not found then raise exception 'Resource unavailable' using errcode='42501';end if;
 end if;
 -- Revalidate time-sensitive contribution authority after a possible parent lock wait.
 a:=private.require_brainstorm_write(target_instance);
 insert into public.brainstorm_entries(activity_instance_id,project_id,workspace_id,created_by,content,parent_entry_id,
  status,archived_at,revealed_at,development_object_id)
 values(a.id,a.project_id,a.workspace_id,actor,entry_content,parent_entry,'active',null,null,null) returning * into entry;
 return to_jsonb(entry);
end $$;

drop policy brainstorm_owner_read on public.brainstorm_entries;
drop policy brainstorm_read_guard on public.brainstorm_entries;
create policy brainstorm_owner_or_revealed_pool_read on public.brainstorm_entries for select to authenticated
 using(public.can_read_brainstorm_entry(id));
create policy brainstorm_read_guard on public.brainstorm_entries as restrictive for select to authenticated
 using(public.can_read_brainstorm_entry(id));
comment on function public.reveal_brainstorm_entries(uuid,uuid[]) is 'M9.8 exact Team Lead/scoped Master with canonical M7 access; immutable snapshot policy; all-target atomic reveal; stable timestamps and minimal canonical result. No sharing/promotion.';
commit;
