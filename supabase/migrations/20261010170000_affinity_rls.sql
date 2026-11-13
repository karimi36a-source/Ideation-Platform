begin;
-- Read-only, caller-bound predicates. Definers avoid source/group RLS recursion;
-- neither accepts a claimed actor, role or scope, and neither returns metadata.
create function public.can_read_affinity_group(target_group uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.affinity_groups g
 join public.activity_instances a on a.id=g.activity_instance_id
 join public.activity_definitions d on d.id=a.activity_definition_id
 join public.workspaces w on w.id=a.workspace_id
 where g.id=target_group and d.method_type='affinity'
 and a.configuration_snapshot->>'method_type'='affinity'
 and public.can_read_activity_instance(a.id)
 and ((w.workspace_type='PERSONAL' and w.owner_user_id=public.current_platform_user_id() and a.team_id is null)
 or (w.workspace_type='TEAM' and w.team_id=a.team_id and public.get_team_workspace_access(w.id) is not null)));
$$;
create function public.can_read_affinity_item(target_item uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.affinity_group_items i
 join public.affinity_groups g on g.id=i.affinity_group_id
 join public.activity_instances a on a.id=g.activity_instance_id
 join public.workspaces w on w.id=a.workspace_id
 where i.id=target_item and public.can_read_affinity_group(g.id)
 and ((i.development_object_id is not null and exists(
  select 1 from public.development_objects o where o.id=i.development_object_id
  and (o.project_id,o.workspace_id)=(a.project_id,a.workspace_id)
  and o.archived_at is null and public.can_read_development_project(o.project_id)))
 or (i.brainstorm_entry_id is not null and exists(
  select 1 from public.brainstorm_entries b join public.activity_instances s on s.id=b.activity_instance_id
  where b.id=i.brainstorm_entry_id and (b.project_id,b.workspace_id)=(a.project_id,a.workspace_id)
  and s.team_id is not distinct from a.team_id and public.can_read_brainstorm_entry(b.id)
  and ((w.workspace_type='PERSONAL' and b.created_by=public.current_platform_user_id())
   or (w.workspace_type='TEAM' and b.revealed_at is not null
    and s.configuration_snapshot->>'method_type'='brainstorming'
    and s.configuration_snapshot#>>'{configuration,brainstorming,visibility_mode}'='private_before_reveal'
    and s.configuration_snapshot#>>'{configuration,brainstorming,reveal_authority}'='team_lead_or_scoped_master'))))));
$$;
revoke all on function public.can_read_affinity_group(uuid),public.can_read_affinity_item(uuid) from public,anon,authenticated,service_role;
grant execute on function public.can_read_affinity_group(uuid),public.can_read_affinity_item(uuid) to authenticated;
alter table public.affinity_groups enable row level security;
alter table public.affinity_group_items enable row level security;
revoke all on public.affinity_groups,public.affinity_group_items from public,anon,authenticated,service_role;
grant select on public.affinity_groups,public.affinity_group_items to authenticated;
drop policy affinity_groups_client_deny on public.affinity_groups;
drop policy affinity_items_client_deny on public.affinity_group_items;
create policy affinity_groups_scoped_read on public.affinity_groups for select to authenticated using(public.can_read_affinity_group(id));
create policy affinity_groups_read_guard on public.affinity_groups as restrictive for select to authenticated using(public.can_read_affinity_group(id));
create policy affinity_items_scoped_read on public.affinity_group_items for select to authenticated using(public.can_read_affinity_item(id));
create policy affinity_items_read_guard on public.affinity_group_items as restrictive for select to authenticated using(public.can_read_affinity_item(id));
create policy affinity_groups_insert_deny on public.affinity_groups as restrictive for insert to authenticated with check(false);
create policy affinity_groups_update_deny on public.affinity_groups as restrictive for update to authenticated using(false) with check(false);
create policy affinity_groups_delete_deny on public.affinity_groups as restrictive for delete to authenticated using(false);
create policy affinity_items_insert_deny on public.affinity_group_items as restrictive for insert to authenticated with check(false);
create policy affinity_items_update_deny on public.affinity_group_items as restrictive for update to authenticated using(false) with check(false);
create policy affinity_items_delete_deny on public.affinity_group_items as restrictive for delete to authenticated using(false);
create policy affinity_groups_anon_deny on public.affinity_groups as restrictive for all to anon using(false) with check(false);
create policy affinity_items_anon_deny on public.affinity_group_items as restrictive for all to anon using(false) with check(false);
comment on table public.affinity_groups is 'Private canonical Activity-scoped Affinity groups. Authenticated reads require current scope; writes use validated RPCs only.';
comment on table public.affinity_group_items is 'Canonical source references. Reads require group scope plus compatible source visibility; direct client writes are revoked.';
commit;
