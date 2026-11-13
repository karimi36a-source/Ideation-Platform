begin;
create function private.require_affinity_write(target_instance uuid) returns public.activity_instances
language plpgsql volatile security definer set search_path='' as $$
declare a public.activity_instances;
begin
 begin a:=public.lock_activity_artifact_contribution(target_instance);
 exception when insufficient_privilege then raise exception 'Resource unavailable' using errcode='42501';end;
 if a.configuration_snapshot->>'method_type' is distinct from 'affinity'
 or not exists(select 1 from public.activity_definitions d where d.id=a.activity_definition_id and d.method_type='affinity')
 then raise exception 'Invalid Activity method' using errcode='22023';end if;
 return a;
end $$;
revoke all on function private.require_affinity_write(uuid) from public,anon,authenticated,service_role;

create function private.validate_affinity_label(input jsonb,id_key text) returns void
language plpgsql immutable set search_path='' as $$
begin
 if input is null or jsonb_typeof(input)<>'object'
 or exists(select 1 from jsonb_object_keys(input) k where k not in (id_key,'name','description'))
 or jsonb_typeof(input->id_key) is distinct from 'string'
 or jsonb_typeof(input->'name') is distinct from 'string'
 or length(private.trim_decision_text(input->>'name')) not between 1 and 200
 or (input ? 'description' and (jsonb_typeof(input->'description') not in ('string','null') or length(private.trim_decision_text(input->>'description'))>10000))
 then raise exception 'Invalid Affinity input' using errcode='22023';end if;
end $$;
revoke all on function private.validate_affinity_label(jsonb,text) from public,anon,authenticated,service_role;

create function public.create_affinity_group(input jsonb) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare actor uuid:=public.current_platform_user_id();a public.activity_instances;g public.affinity_groups;next_sequence bigint;
begin
 if actor is null then
  if auth.uid() is null then raise exception 'Authentication required' using errcode='28000';end if;
  raise exception 'Resource unavailable' using errcode='42501';end if;
 perform private.validate_affinity_label(input,'activityInstanceId');
 a:=private.require_affinity_write((input->>'activityInstanceId')::uuid);
 -- Do not upgrade shared Activity locks: that would deadlock concurrent creators.
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('affinity-sequence:'||a.id::text,0));
 a:=private.require_affinity_write(a.id);
 select coalesce(max(sequence)::bigint,0)+1 into next_sequence from public.affinity_groups where activity_instance_id=a.id;
 if next_sequence>2147483647 then raise exception 'Ordering capacity reached' using errcode='55000';end if;
 insert into public.affinity_groups(activity_instance_id,name,description,sequence,created_by)
 values(a.id,private.trim_decision_text(input->>'name'),private.trim_decision_text(input->>'description'),next_sequence::integer,actor) returning * into g;
 perform private.require_affinity_write(a.id);
 return to_jsonb(g);
end $$;
revoke all on function public.create_affinity_group(jsonb) from public,anon,authenticated,service_role;
grant execute on function public.create_affinity_group(jsonb) to authenticated;

create function public.rename_affinity_group(input jsonb) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare actor uuid:=public.current_platform_user_id();g public.affinity_groups;parent uuid;label text;details text;
begin
 if actor is null then
  if auth.uid() is null then raise exception 'Authentication required' using errcode='28000';end if;
  raise exception 'Resource unavailable' using errcode='42501';end if;
 perform private.validate_affinity_label(input,'affinityGroupId');
 select activity_instance_id into parent from public.affinity_groups where id=(input->>'affinityGroupId')::uuid;
 if not found then raise exception 'Resource unavailable' using errcode='42501';end if;
 perform private.require_affinity_write(parent);
 select * into g from public.affinity_groups where id=(input->>'affinityGroupId')::uuid for update;
 if not found or g.activity_instance_id<>parent then raise exception 'Resource unavailable' using errcode='42501';end if;
 perform private.require_affinity_write(parent);
 label:=private.trim_decision_text(input->>'name');
 details:=case when input ? 'description' then private.trim_decision_text(input->>'description') else g.description end;
 if (g.name,g.description) is distinct from (label,details) then
  update public.affinity_groups set name=label,description=details where id=g.id returning * into g;
 end if;
 perform private.require_affinity_write(parent);
 return to_jsonb(g);
end $$;
revoke all on function public.rename_affinity_group(jsonb) from public,anon,authenticated,service_role;
grant execute on function public.rename_affinity_group(jsonb) to authenticated;
commit;
