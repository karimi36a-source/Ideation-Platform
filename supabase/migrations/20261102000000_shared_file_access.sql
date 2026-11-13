begin;
-- Exact FILE capability only. No File/Storage SELECT policy, collection grant,
-- linked-entity traversal, signing credential or storage reference is exposed.
create function public.authorize_shared_file_access(target_file uuid) returns boolean
language plpgsql stable security definer set search_path='' as $$
declare s record;access_result jsonb;
begin
 if public.current_platform_user_id() is null or target_file is null then return false;end if;
 for s in select id from public.shares where shared_entity_type='FILE'
  and shared_entity_id=target_file and revoked_at is null
  and share_mode='SNAPSHOT' and permission_level in ('VIEW','COMMENT') loop
  access_result:=public.resolve_shared_entity_access(jsonb_build_object('shareId',s.id));
  if access_result->>'allowed'='true' and access_result->>'sharedEntityType'='FILE'
   and access_result->>'sharedEntityId'=target_file::text then return true;end if;
 end loop;
 return false;
end$$;
revoke all on function public.authorize_shared_file_access(uuid) from public,anon,authenticated,service_role;
grant execute on function public.authorize_shared_file_access(uuid) to authenticated;
comment on function public.authorize_shared_file_access(uuid) is 'M13.15 caller-bound boolean for exact explicit FILE Share; reuses M13.5 active SNAPSHOT VIEW/COMMENT destination/provenance checks. No linked Files, metadata, signing, storage or mutation grant. Existing archived File identity remains valid.';
-- M12 deliberately grants service_role no table SELECT. Keep the privileged
-- canonical lookup narrow and server-only instead of widening table grants.
create function public.get_file_signing_record(target_file uuid) returns jsonb
language sql stable security definer set search_path='' as $$
 select to_jsonb(f) from public.files f where f.id=target_file
$$;
revoke all on function public.get_file_signing_record(uuid) from public,anon,authenticated,service_role;
grant execute on function public.get_file_signing_record(uuid) to service_role;
comment on function public.get_file_signing_record(uuid) is 'Server-only exact canonical File record for signing after caller-scoped authorization. Never exposed to anon/authenticated; no table grants or mutations.';
commit;
