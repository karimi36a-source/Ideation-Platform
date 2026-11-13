begin;
-- Server credential only. User/anonymous clients retain no template-read access.
create function public.read_active_ai_prompt_template(role0 public.ai_prompt_role_code,activity0 public.activity_method_type)
returns jsonb language sql stable security definer set search_path='' as $$
 select private.resolve_active_ai_prompt_template(role0,activity0)
$$;
revoke all on function public.read_active_ai_prompt_template(public.ai_prompt_role_code,public.activity_method_type) from public,anon,authenticated,service_role;
grant execute on function public.read_active_ai_prompt_template(public.ai_prompt_role_code,public.activity_method_type) to service_role;
commit;
