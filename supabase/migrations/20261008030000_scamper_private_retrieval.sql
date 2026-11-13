begin;
-- No table SELECT grant: this exact-ID read composes the canonical M7 resolver.
-- Owner execution is needed solely to inspect the default-denied source table.
create function public.get_scamper_entry(target_entry uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare s public.scamper_entries;
begin
 if public.current_platform_user_id() is null then
  if auth.uid() is null then raise exception 'Authentication required' using errcode='28000';end if;
  raise exception 'Resource unavailable' using errcode='42501';end if;
 select * into s from public.scamper_entries where id=target_entry;
 if not found then raise exception 'Resource unavailable' using errcode='42501';end if;
 if not public.can_read_activity_instance(s.activity_instance_id) then raise exception 'Resource unavailable' using errcode='42501';end if;
 return to_jsonb(s);
end $$;
revoke all on function public.get_scamper_entry(uuid) from public,anon,authenticated,service_role;
grant execute on function public.get_scamper_entry(uuid) to authenticated;
comment on function public.get_scamper_entry(uuid) is 'M9.4 exact canonical Activity/Project/Workspace privacy. No sharing exceptions or broad role override. Inaccessible and absent IDs have identical safe denial.';
commit;
