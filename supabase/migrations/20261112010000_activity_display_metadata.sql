begin;
-- Reuse M7's caller-bound instance gate. Definition administration stays private;
-- this projection adds only the Session/tool identity needed for authorized UI.
create function public.activity_resume_definition_metadata(target_instance uuid)
returns jsonb language sql stable security definer set search_path='' as $$
 select identity.value || jsonb_build_object('session_definition_id',d.session_definition_id,'method_type',d.method_type)
 from (select public.activity_resume_definition_identity(target_instance) as value) identity
 join public.activity_definitions d on d.id=(identity.value->>'id')::uuid
 where identity.value is not null
$$;
revoke all on function public.activity_resume_definition_metadata(uuid) from public,anon,authenticated,service_role;
grant execute on function public.activity_resume_definition_metadata(uuid) to authenticated;
commit;
