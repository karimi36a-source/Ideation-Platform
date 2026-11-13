-- M7.7: display identity alone needs definer access because Definitions are
-- curriculum administration data. Gate before reading; expose no execution fields.
create function public.activity_resume_definition_identity(target_instance uuid)
returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object('id',d.id,'name',d.name)
 from public.activity_instances a join public.activity_definitions d on d.id=a.activity_definition_id
 where a.id=target_instance and public.can_read_activity_instance(a.id)
$$;
revoke all on function public.activity_resume_definition_identity(uuid) from public,anon,authenticated,service_role;
grant execute on function public.activity_resume_definition_identity(uuid) to authenticated;
-- Invoker rights are essential: Object/link RLS must independently filter I/O.
-- One statement snapshot yields persisted canonical state without any writes.
create function public.resume_activity(target_instance uuid)
returns jsonb language sql stable security invoker set search_path='' as $$
 select jsonb_build_object(
  'activity',to_jsonb(a),
  'definition',public.activity_resume_definition_identity(a.id),
  'inputs',coalesce((select jsonb_agg(to_jsonb(i) order by i.created_at,i.id) from public.activity_inputs i where i.activity_instance_id=a.id),'[]'::jsonb),
  'outputs',coalesce((select jsonb_agg(to_jsonb(o) order by o.created_at,o.id) from public.activity_outputs o where o.activity_instance_id=a.id),'[]'::jsonb),
  'participants',coalesce((select jsonb_agg(to_jsonb(p) order by p.joined_at,p.id) from public.activity_participants p where p.activity_instance_id=a.id),'[]'::jsonb)
 ) from public.activity_instances a where a.id=target_instance
$$;
revoke all on function public.resume_activity(uuid) from public,anon,authenticated,service_role;
grant execute on function public.resume_activity(uuid) to authenticated;
comment on function public.resume_activity(uuid) is 'Read-only canonical resume. Invoker RLS filters parent, participants and independently authorized Object references. Null means unavailable, whether inaccessible or nonexistent.';
