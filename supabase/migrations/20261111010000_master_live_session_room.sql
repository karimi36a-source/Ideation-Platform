begin;
-- Local M16 authority boundary only. Existing RLS/helpers remain unchanged.
-- The actor argument is usable only inside definer functions; public reads
-- derive it from auth.uid(), while the internal writer receives server identity.
create function private.master_live_room_context(target_cohort uuid,target_session uuid,target_activity uuid,actor uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare c public.cohorts;org uuid;assignment uuid;previous uuid;room_key text;
begin
 select * into c from public.cohorts where id=target_cohort for share;
 select organization_id into org from public.programs where id=c.program_id;
 if c.id is null or c.status<>'active' or not exists(select 1 from public.session_definitions s where s.id=target_session and s.curriculum_version_id=c.curriculum_version_id and s.status='active') then raise exception 'Access denied' using errcode='42501';end if;
 -- Same current, single-scope role semantics as canonical Cohort authority.
 -- Lock the qualifying assignment/profile through the mapping transaction.
 select a.id into assignment from public.role_assignments a join public.roles r on r.id=a.role_id join public.users u on u.id=a.user_id
 where u.id=actor and u.account_status='active' and r.is_system_role and a.status='active'
 and a.starts_at<=statement_timestamp() and (a.ends_at is null or a.ends_at>statement_timestamp())
 and num_nonnulls(a.organization_id,a.program_id,a.cohort_id,a.team_id,a.project_id)=1
 and ((r.code='MASTER' and a.cohort_id=c.id) or (r.code='ADMIN' and a.organization_id=org))
 order by a.id limit 1 for share of a,u;
 if assignment is null then raise exception 'Access denied' using errcode='42501';end if;
 -- Optional linkage validates identity only; it grants no private Activity data.
 if target_activity is not null and not exists(select 1 from public.activity_instances i join public.activity_definitions d on d.id=i.activity_definition_id where i.id=target_activity and i.cohort_id=c.id and d.session_definition_id=target_session and i.status<>'archived') then raise exception 'Access denied' using errcode='42501';end if;
 select id into previous from public.live_session_rooms where cohort_id=c.id and session_definition_id=target_session and provider='DAILY' and status='EXPIRED' order by ended_at desc,id desc limit 1;
 room_key:='fici-'||encode(sha256(convert_to(c.id::text||':'||target_session::text||':'||coalesce(previous::text,'initial'),'UTF8')),'hex');
 return jsonb_build_object('actorId',actor,'cohortId',c.id,'sessionDefinitionId',target_session,'roomKey',room_key);
end $$;
revoke all on function private.master_live_room_context(uuid,uuid,uuid,uuid) from public,anon,authenticated,service_role;

create function public.authorize_master_live_room(target_cohort uuid,target_session uuid,target_activity uuid default null)
returns jsonb language plpgsql security definer set search_path='' as $$
begin
 return private.master_live_room_context(target_cohort,target_session,target_activity,public.current_platform_user_id());
end $$;
revoke all on function public.authorize_master_live_room(uuid,uuid,uuid) from public,anon,authenticated,service_role;
grant execute on function public.authorize_master_live_room(uuid,uuid,uuid) to authenticated;

-- Only the server can supply a provider-confirmed room reference. Normal
-- authenticated clients cannot register arbitrary provider rooms via RPC.
create function public.master_live_room_mapping(command text,target_cohort uuid,target_session uuid,target_activity uuid,room_reference text,actor uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare context jsonb;existing jsonb;
begin
 if command is null or command not in ('FIND_ACTIVE','REUSE_OR_CREATE') then raise exception 'Access denied' using errcode='42501';end if;
 perform pg_advisory_xact_lock(hashtextextended(target_cohort::text||':'||target_session::text||':DAILY',0));
 context:=private.master_live_room_context(target_cohort,target_session,target_activity,actor);
 existing:=public.manage_live_room_mapping('FIND_ACTIVE',target_cohort,target_session,'DAILY',null,actor);
 if command='FIND_ACTIVE' then
  if room_reference is not null then raise exception 'Access denied' using errcode='42501';end if;
  return existing;
 end if;
 if existing is not null then return existing;end if;
 if room_reference is distinct from context->>'roomKey' then raise exception 'Access denied' using errcode='42501';end if;
 return public.manage_live_room_mapping('REUSE_OR_CREATE',target_cohort,target_session,'DAILY',room_reference,actor);
end $$;
revoke all on function public.master_live_room_mapping(text,uuid,uuid,uuid,text,uuid) from public,anon,authenticated,service_role;
grant execute on function public.master_live_room_mapping(text,uuid,uuid,uuid,text,uuid) to service_role;
commit;
