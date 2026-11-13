begin;
-- Preserve uniqueness, checking complete reorder statements rather than row order.
alter table public.affinity_group_items drop constraint affinity_item_position;
alter table public.affinity_group_items add constraint affinity_item_position unique(affinity_group_id,position) deferrable initially immediate;

create function private.require_affinity_source(a public.activity_instances,object_id uuid,entry_id uuid) returns void
language plpgsql volatile security definer set search_path='' as $$
declare actor uuid:=public.current_platform_user_id();o public.development_objects;b public.brainstorm_entries;s public.activity_instances;w public.workspaces;
begin
 if num_nonnulls(object_id,entry_id)<>1 then raise exception 'Invalid source' using errcode='22023';end if;
 if object_id is not null then
  select * into o from public.development_objects where id=object_id for share;
  if not found or o.archived_at is not null or (o.project_id,o.workspace_id) is distinct from (a.project_id,a.workspace_id)
  or not public.can_read_development_project(o.project_id) then raise exception 'Resource unavailable' using errcode='42501';end if;
 else
  select * into b from public.brainstorm_entries where id=entry_id for share;
  if not found or (b.project_id,b.workspace_id) is distinct from (a.project_id,a.workspace_id)
   or not public.can_read_brainstorm_entry(b.id) then raise exception 'Resource unavailable' using errcode='42501';end if;
  select * into s from public.activity_instances where id=b.activity_instance_id for share;
  select * into w from public.workspaces where id=a.workspace_id;
  perform 1 from public.enrollments where user_id=actor and cohort_id=s.cohort_id for share;
  perform 1 from public.role_assignments where user_id=actor for share;
  if s.team_id is distinct from a.team_id then raise exception 'Resource unavailable' using errcode='42501';end if;
  if w.workspace_type='TEAM' then
   -- No directly-visible M9 runtime/configuration value is currently approved.
   if s.configuration_snapshot#>>'{configuration,brainstorming,visibility_mode}' is distinct from 'private_before_reveal'
    or s.configuration_snapshot->>'method_type' is distinct from 'brainstorming'
    or s.configuration_snapshot#>>'{configuration,brainstorming,reveal_authority}' is distinct from 'team_lead_or_scoped_master'
    or b.revealed_at is null then raise exception 'Resource unavailable' using errcode='42501';end if;
  elsif w.workspace_type='PERSONAL' then
   if w.owner_user_id is distinct from actor or b.created_by is distinct from actor or a.team_id is not null
    then raise exception 'Resource unavailable' using errcode='42501';end if;
  else raise exception 'Resource unavailable' using errcode='42501';end if;
 end if;
end $$;
revoke all on function private.require_affinity_source(public.activity_instances,uuid,uuid) from public,anon,authenticated,service_role;

create function private.normalize_affinity_positions(target_group uuid) returns void
language sql volatile set search_path='' as $$
 with ordered as(select id,row_number() over(order by position,id)::integer n from public.affinity_group_items where affinity_group_id=target_group)
 update public.affinity_group_items i set position=o.n from ordered o where i.id=o.id and i.position<>o.n;
$$;
revoke all on function private.normalize_affinity_positions(uuid) from public,anon,authenticated,service_role;

create function public.add_affinity_item(input jsonb) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare actor uuid:=public.current_platform_user_id();g public.affinity_groups;a public.activity_instances;item public.affinity_group_items;oid uuid;bid uuid;n bigint;pos integer;
begin
 if actor is null then if auth.uid() is null then raise exception 'Authentication required' using errcode='28000';end if;raise exception 'Resource unavailable' using errcode='42501';end if;
 if input is null or jsonb_typeof(input)<>'object' or exists(select 1 from jsonb_object_keys(input) k where k not in ('affinityGroupId','developmentObjectId','brainstormEntryId','position'))
 or jsonb_typeof(input->'affinityGroupId') is distinct from 'string'
 or (input ? 'developmentObjectId' and jsonb_typeof(input->'developmentObjectId') is distinct from 'string')
 or (input ? 'brainstormEntryId' and jsonb_typeof(input->'brainstormEntryId') is distinct from 'string')
 or ((input ? 'developmentObjectId')::integer+(input ? 'brainstormEntryId')::integer)<>1
 or (input ? 'position' and (jsonb_typeof(input->'position')<>'number' or (input->>'position') !~ '^[0-9]+$')) then raise exception 'Invalid Affinity input' using errcode='22023';end if;
 oid:=(input->>'developmentObjectId')::uuid;bid:=(input->>'brainstormEntryId')::uuid;
 select * into g from public.affinity_groups where id=(input->>'affinityGroupId')::uuid;
 if not found then raise exception 'Resource unavailable' using errcode='42501';end if;
 a:=private.require_affinity_write(g.activity_instance_id);
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('affinity-items:'||a.id::text,0));
 select * into g from public.affinity_groups where id=g.id for update;
 if not found or g.activity_instance_id<>a.id then raise exception 'Resource unavailable' using errcode='42501';end if;
 a:=private.require_affinity_write(a.id);perform private.require_affinity_source(a,oid,bid);
 if exists(select 1 from public.affinity_group_items where affinity_group_id=g.id and ((oid is not null and development_object_id=oid) or (bid is not null and brainstorm_entry_id=bid))) then raise exception 'Duplicate source' using errcode='23505';end if;
 select count(*) into n from public.affinity_group_items where affinity_group_id=g.id;
 if n>=2147483647 then raise exception 'Ordering capacity reached' using errcode='55000';end if;
 if input ? 'position' then
  if (input->>'position')::numeric not between 1 and n+1 then raise exception 'Invalid position' using errcode='22023';end if;pos:=(input->>'position')::integer;
 else pos:=(n+1)::integer;end if;
 perform private.normalize_affinity_positions(g.id);
 update public.affinity_group_items set position=position+1 where affinity_group_id=g.id and position>=pos;
 insert into public.affinity_group_items(affinity_group_id,development_object_id,brainstorm_entry_id,position,added_by) values(g.id,oid,bid,pos,actor) returning * into item;
 perform private.require_affinity_write(a.id);perform private.require_affinity_source(a,oid,bid);
 return to_jsonb(item);
end $$;
revoke all on function public.add_affinity_item(jsonb) from public,anon,authenticated,service_role;
grant execute on function public.add_affinity_item(jsonb) to authenticated;

create function public.move_affinity_item(input jsonb) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare actor uuid:=public.current_platform_user_id();item public.affinity_group_items;source_group public.affinity_groups;target_group public.affinity_groups;a public.activity_instances;pos integer;n bigint;old_pos integer;
begin
 if actor is null then if auth.uid() is null then raise exception 'Authentication required' using errcode='28000';end if;raise exception 'Resource unavailable' using errcode='42501';end if;
 if input is null or jsonb_typeof(input)<>'object' or exists(select 1 from jsonb_object_keys(input) k where k not in ('itemId','targetGroupId','position'))
 or jsonb_typeof(input->'itemId') is distinct from 'string' or jsonb_typeof(input->'targetGroupId') is distinct from 'string'
 or jsonb_typeof(input->'position') is distinct from 'number' or (input->>'position') !~ '^[0-9]+$' then raise exception 'Invalid Affinity input' using errcode='22023';end if;
 select * into item from public.affinity_group_items where id=(input->>'itemId')::uuid;
 if not found then raise exception 'Resource unavailable' using errcode='42501';end if;
 select * into source_group from public.affinity_groups where id=item.affinity_group_id;
 a:=private.require_affinity_write(source_group.activity_instance_id);
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('affinity-items:'||a.id::text,0));
 select * into item from public.affinity_group_items where id=item.id for update;
 if not found then raise exception 'Resource unavailable' using errcode='42501';end if;
 perform 1 from public.affinity_groups where id in(item.affinity_group_id,(input->>'targetGroupId')::uuid) order by id for update;
 select * into source_group from public.affinity_groups where id=item.affinity_group_id;
 select * into target_group from public.affinity_groups where id=(input->>'targetGroupId')::uuid;
 if target_group.id is null or source_group.activity_instance_id<>a.id or target_group.activity_instance_id<>a.id then raise exception 'Resource unavailable' using errcode='42501';end if;
 a:=private.require_affinity_write(a.id);perform private.require_affinity_source(a,item.development_object_id,item.brainstorm_entry_id);
 if exists(select 1 from public.affinity_group_items x where x.affinity_group_id=target_group.id and x.id<>item.id and ((item.development_object_id is not null and x.development_object_id=item.development_object_id) or (item.brainstorm_entry_id is not null and x.brainstorm_entry_id=item.brainstorm_entry_id))) then raise exception 'Duplicate source' using errcode='23505';end if;
 select count(*) into n from public.affinity_group_items where affinity_group_id=target_group.id;
 if source_group.id<>target_group.id and n>=2147483647 then raise exception 'Ordering capacity reached' using errcode='55000';end if;
 if (input->>'position')::numeric not between 1 and (n+(case when source_group.id=target_group.id then 0 else 1 end)) then raise exception 'Invalid position' using errcode='22023';end if;
 pos:=(input->>'position')::integer;
 if source_group.id=target_group.id and item.position=pos then return to_jsonb(item);end if;
 perform private.normalize_affinity_positions(source_group.id);
 if source_group.id<>target_group.id then perform private.normalize_affinity_positions(target_group.id);end if;
 select position into old_pos from public.affinity_group_items where id=item.id;
 if source_group.id=target_group.id then
  update public.affinity_group_items set position=case when id=item.id then pos when pos<old_pos then position+1 else position-1 end
  where affinity_group_id=source_group.id and (id=item.id or (pos<old_pos and position>=pos and position<old_pos) or (pos>old_pos and position>old_pos and position<=pos));
 else
  update public.affinity_group_items set position=position+1 where affinity_group_id=target_group.id and position>=pos;
  update public.affinity_group_items set affinity_group_id=target_group.id,position=pos where id=item.id;
  update public.affinity_group_items set position=position-1 where affinity_group_id=source_group.id and position>old_pos;
 end if;
 perform private.require_affinity_write(a.id);perform private.require_affinity_source(a,item.development_object_id,item.brainstorm_entry_id);
 select * into item from public.affinity_group_items where id=item.id;return to_jsonb(item);
end $$;
revoke all on function public.move_affinity_item(jsonb) from public,anon,authenticated,service_role;
grant execute on function public.move_affinity_item(jsonb) to authenticated;
commit;
