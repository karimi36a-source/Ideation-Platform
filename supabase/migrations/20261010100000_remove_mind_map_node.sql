begin;
-- One narrow controlled operation; existing RESTRICT FKs/RLS remain unchanged.
create function public.remove_mind_map_node(input jsonb) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare actor uuid:=public.current_platform_user_id();n public.mind_map_nodes;m public.mind_maps;expected bigint;
begin
 if actor is null then if auth.uid() is null then raise exception 'Authentication required' using errcode='28000';end if;raise exception 'Resource unavailable' using errcode='42501';end if;
 if input is null or jsonb_typeof(input)<>'object'
 or exists(select 1 from jsonb_object_keys(input) k where k not in('nodeId','expectedRevision'))
 or jsonb_typeof(input->'nodeId') is distinct from 'string'
 or jsonb_typeof(input->'expectedRevision') is distinct from 'number'
 or (input->>'expectedRevision') !~ '^[0-9]+$' or (input->>'expectedRevision')::numeric>9007199254740991
 then raise exception 'Invalid input' using errcode='22023';end if;
 expected:=(input->>'expectedRevision')::bigint;
 select * into n from public.mind_map_nodes where id=(input->>'nodeId')::uuid;
 if not found then raise exception 'Resource unavailable' using errcode='42501';end if;
 -- Shared with M11.9 node updates/adds and M11.10 edge writes. Scope is
 -- revalidated after waiting; no caller-supplied Map or ownership is accepted.
 perform private.require_mind_map_node_edit(n.mind_map_id);
 select * into n from public.mind_map_nodes where id=n.id for update;
 if not found then raise exception 'Resource unavailable' using errcode='42501';end if;
 if n.edit_revision<>expected then raise exception 'Node edit conflict' using errcode='40001';end if;
 select * into m from public.mind_maps where id=n.mind_map_id;
 if n.id=m.root_node_id or n.node_type='CENTRAL_INVENTION' then raise exception 'Root removal forbidden' using errcode='22023';end if;
 if exists(select 1 from public.mind_map_nodes where parent_node_id=n.id)
 then raise exception 'Node has children' using errcode='22023';end if;
 -- All preconditions precede cleanup. No child cascade, reparent or Object write.
 delete from public.mind_map_edges where mind_map_id=n.mind_map_id and (source_node_id=n.id or target_node_id=n.id);
 delete from public.mind_map_nodes where id=n.id and edit_revision=expected returning * into n;
 if not found then raise exception 'Node edit conflict' using errcode='40001';end if;
 perform private.require_mind_map_node_edit(n.mind_map_id);
 return to_jsonb(n);
exception when invalid_text_representation or numeric_value_out_of_range then raise exception 'Invalid input' using errcode='22023';
end $$;
revoke all on function public.remove_mind_map_node(jsonb) from public,anon,authenticated,service_role;
grant execute on function public.remove_mind_map_node(jsonb) to authenticated;
comment on function public.remove_mind_map_node(jsonb) is 'M11.11 current-scope, DRAFT Map leaf removal with node CAS. Root/children guarded before atomic visual edge cleanup; canonical Objects/history untouched.';
commit;
