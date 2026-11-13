begin;
-- Approved M11.4 item-level CAS. Only explicit movement advances this token; sibling reorders do not.
alter table public.affinity_group_items add column move_revision integer not null default 0 check(move_revision>=0);
create or replace function public.move_affinity_item(input jsonb) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare actor uuid:=public.current_platform_user_id();item public.affinity_group_items;source_group public.affinity_groups;target_group public.affinity_groups;a public.activity_instances;pos integer;n bigint;old_pos integer;
begin
 if actor is null then if auth.uid() is null then raise exception 'Authentication required' using errcode='28000';end if;raise exception 'Resource unavailable' using errcode='42501';end if;
 if input is null or jsonb_typeof(input)<>'object' or exists(select 1 from jsonb_object_keys(input) k where k not in ('itemId','targetGroupId','position','expectedRevision'))
 or jsonb_typeof(input->'itemId') is distinct from 'string' or jsonb_typeof(input->'targetGroupId') is distinct from 'string'
 or jsonb_typeof(input->'expectedRevision') is distinct from 'number' or (input->>'expectedRevision') !~ '^[0-9]+$' or (input->>'expectedRevision')::numeric>2147483647
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
 if item.move_revision<>(input->>'expectedRevision')::integer then raise exception 'Affinity item conflict' using errcode='40001';end if;
 if exists(select 1 from public.affinity_group_items x where x.affinity_group_id=target_group.id and x.id<>item.id and ((item.development_object_id is not null and x.development_object_id=item.development_object_id) or (item.brainstorm_entry_id is not null and x.brainstorm_entry_id=item.brainstorm_entry_id))) then raise exception 'Duplicate source' using errcode='23505';end if;
 select count(*) into n from public.affinity_group_items where affinity_group_id=target_group.id;
 if source_group.id<>target_group.id and n>=2147483647 then raise exception 'Ordering capacity reached' using errcode='55000';end if;
 if (input->>'position')::numeric not between 1 and (n+(case when source_group.id=target_group.id then 0 else 1 end)) then raise exception 'Invalid position' using errcode='22023';end if;
 pos:=(input->>'position')::integer;
 if source_group.id=target_group.id and item.position=pos then return to_jsonb(item);end if;
 if item.move_revision=2147483647 then raise exception 'Revision capacity reached' using errcode='55000';end if;
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
 update public.affinity_group_items set move_revision=move_revision+1 where id=item.id;
 perform private.require_affinity_write(a.id);perform private.require_affinity_source(a,item.development_object_id,item.brainstorm_entry_id);
 select * into item from public.affinity_group_items where id=item.id;return to_jsonb(item);
end $$;
create function public.get_affinity_collaboration_board(target_activity uuid) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare actor uuid:=public.current_platform_user_id();a public.activity_instances;i public.affinity_group_items;result jsonb;
begin
 if actor is null then if auth.uid() is null then raise exception 'Authentication required' using errcode='28000';end if;raise exception 'Resource unavailable' using errcode='42501';end if;
 a:=private.require_affinity_write(target_activity);
 -- Serialize reload with canonical moves/adds, without upgrading shared Activity locks.
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('affinity-items:'||a.id::text,0));
 a:=private.require_affinity_write(a.id);
 for i in select x.* from public.affinity_group_items x join public.affinity_groups g on g.id=x.affinity_group_id where g.activity_instance_id=a.id loop
  perform private.require_affinity_source(a,i.development_object_id,i.brainstorm_entry_id);
 end loop;
 -- Minimal layout/source identities only: no raw Object/Brainstorm content, settings, owner or other board data.
 select jsonb_build_object('activityInstanceId',a.id,'roomId','affinity:'||a.id::text,
  'groups',coalesce((select jsonb_agg(jsonb_build_object('id',g.id,'sequence',g.sequence) order by g.sequence,g.id) from public.affinity_groups g where g.activity_instance_id=a.id),'[]'::jsonb),
  'items',coalesce((select jsonb_agg(jsonb_build_object('id',x.id,'affinity_group_id',x.affinity_group_id,'position',x.position,'move_revision',x.move_revision,'development_object_id',x.development_object_id,'brainstorm_entry_id',x.brainstorm_entry_id) order by g.sequence,x.position,x.id) from public.affinity_group_items x join public.affinity_groups g on g.id=x.affinity_group_id where g.activity_instance_id=a.id),'[]'::jsonb)) into result;
 perform private.require_affinity_write(a.id);
 return result;
end $$;
revoke all on function public.get_affinity_collaboration_board(uuid) from public,anon,authenticated,service_role;
grant execute on function public.get_affinity_collaboration_board(uuid) to authenticated;
commit;
