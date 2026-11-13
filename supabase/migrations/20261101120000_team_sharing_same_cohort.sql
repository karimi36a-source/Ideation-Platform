begin;
-- Read-only decision, never a capability token or a Share transaction.
create or replace function public.resolve_shareability(input jsonb) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=public.current_platform_user_id();eid uuid;did uuid;kind text;dest text;
 wid uuid;pid uuid;activity uuid;restricted boolean;w public.workspaces;valid boolean;
begin
 if actor is null then return jsonb_build_object('allowed',false,'deniedReason','UNAUTHENTICATED');end if;
 if jsonb_typeof(input) is distinct from 'object' or
  not (input ?& array['entityType','entityId','destinationType','destinationId','permissionLevel','shareMode']) or
  exists(select 1 from jsonb_object_keys(input) k where k<>all(array['entityType','entityId','destinationType','destinationId','permissionLevel','shareMode'])) or
  exists(select 1 from jsonb_each(input) x where jsonb_typeof(x.value)<>'string') then
  return jsonb_build_object('allowed',false,'deniedReason','VALIDATION_ERROR');end if;
 kind:=input->>'entityType';dest:=input->>'destinationType';
 if kind<>all(array['ARTIFACT','DEVELOPMENT_OBJECT','FILE','EVIDENCE','PATENT_RECORD','SCAMPER_ENTRY']) then
  return jsonb_build_object('allowed',false,'deniedReason','ENTITY_NOT_SHAREABLE');end if;
 if input->>'entityId' !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' or
    input->>'destinationId' !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
  return jsonb_build_object('allowed',false,'deniedReason','VALIDATION_ERROR');end if;
 eid:=(input->>'entityId')::uuid;did:=(input->>'destinationId')::uuid;
 if input->>'shareMode'<>'SNAPSHOT' then return jsonb_build_object('allowed',false,'deniedReason','MODE_NOT_ALLOWED');end if;
 if input->>'permissionLevel'<>all(array['VIEW','COMMENT']) then return jsonb_build_object('allowed',false,'deniedReason','PERMISSION_NOT_ALLOWED');end if;
 case kind
 when 'ARTIFACT' then select workspace_id,project_id,status<>'ACTIVE' or archived_at is not null into wid,pid,restricted from public.artifacts where id=eid;
 when 'DEVELOPMENT_OBJECT' then select workspace_id,project_id,archived_at is not null into wid,pid,restricted from public.development_objects where id=eid;
 when 'FILE' then select workspace_id,project_id,status<>'active' or archived_at is not null into wid,pid,restricted from public.files where id=eid;
 when 'EVIDENCE' then select workspace_id,project_id,archived_at is not null into wid,pid,restricted from public.evidence where id=eid;
 when 'PATENT_RECORD' then select workspace_id,project_id,false into wid,pid,restricted from public.patent_records where id=eid;
 when 'SCAMPER_ENTRY' then select workspace_id,project_id,status<>'active' or archived_at is not null,activity_instance_id into wid,pid,restricted,activity from public.scamper_entries where id=eid;
 end case;
 -- Missing and inaccessible IDs are deliberately indistinguishable.
 if wid is null or not public.can_read_file_scope(wid,pid) or
  (activity is not null and not public.can_read_activity_instance(activity)) then
  return jsonb_build_object('allowed',false,'deniedReason','SOURCE_ACCESS_DENIED');end if;
 select * into w from public.workspaces where id=wid;
 if w.workspace_type='TEAM' then
  if public.get_team_workspace_access(wid) is distinct from 'team_lead' or not exists(
   select 1 from public.teams t where t.id=w.team_id and t.workspace_id=wid
   and t.team_lead_user_id=actor and t.status in ('created','active')) then
   return jsonb_build_object('allowed',false,'deniedReason','SHARE_AUTHORITY_DENIED');end if;
 elsif w.workspace_type<>'PERSONAL' or w.owner_user_id is distinct from actor then
  return jsonb_build_object('allowed',false,'deniedReason','SHARE_AUTHORITY_DENIED');
 end if;
 if restricted then return jsonb_build_object('allowed',false,'deniedReason','SOURCE_RESTRICTED');end if;
 if dest in ('USER','WORKSPACE','COHORT') then
  return jsonb_build_object('allowed',false,'deniedReason','DESTINATION_SCOPE_DENIED');
 elsif dest='TEAM' then
  -- Personal owners may target only their currently authorized Team. Check
  -- scope first so nonexistent and inaccessible Teams cannot be distinguished.
  if w.workspace_type='PERSONAL' and not exists(
   select 1 from public.teams t where t.id=did and public.get_team_workspace_access(t.workspace_id) is not null) then
   return jsonb_build_object('allowed',false,'deniedReason','DESTINATION_SCOPE_DENIED');end if;
  select exists(select 1 from public.teams t join public.workspaces dw on dw.id=t.workspace_id
   where t.id=did and t.status in ('created','active') and dw.workspace_type='TEAM' and dw.team_id=t.id
   and dw.status='active' and dw.visibility='private') into valid;
  -- M13.8: canonical Team relationships, never caller-provided Cohort scope.
  -- Keep a uniform scope denial so a destination's Cohort is not disclosed.
  if valid and w.workspace_type='TEAM' and not exists(
   select 1 from public.teams source_team
   join public.teams destination_team on destination_team.id=did
   join public.cohorts c on c.id=source_team.cohort_id
   join public.workspaces destination_workspace on destination_workspace.id=destination_team.workspace_id
   where source_team.id=w.team_id and source_team.workspace_id=w.id
    and source_team.cohort_id=destination_team.cohort_id and c.status='active'
    and w.cohort_id=c.id and destination_workspace.cohort_id=c.id
    and source_team.status in ('created','active') and destination_team.status in ('created','active')
  ) then return jsonb_build_object('allowed',false,'deniedReason','DESTINATION_SCOPE_DENIED');end if;
 elsif dest='MASTER' then
  select exists(select 1 from public.role_assignments ra join public.roles r on r.id=ra.role_id join public.users u on u.id=ra.user_id
   where ra.id=did and r.code='MASTER' and u.account_status='active' and ra.status='active'
   and ra.starts_at<=statement_timestamp() and (ra.ends_at is null or ra.ends_at>statement_timestamp())
   and ra.organization_id is null and ra.program_id is null and ra.project_id is null
   and ((ra.team_id=w.team_id and ra.cohort_id is null) or (ra.cohort_id=w.cohort_id and ra.team_id is null))) into valid;
 else return jsonb_build_object('allowed',false,'deniedReason','DESTINATION_INVALID');
 end if;
 if not valid then return jsonb_build_object('allowed',false,'deniedReason','DESTINATION_INVALID');end if;
 return jsonb_build_object('allowed',true,'sourceWorkspaceId',wid,'normalizedEntityType',kind,
  'normalizedDestination',jsonb_build_object('type',dest,'id',did),
  'allowedPermissionLevels',jsonb_build_array('VIEW','COMMENT'),'allowedModes',jsonb_build_array('SNAPSHOT'));
end $$;
revoke all on function public.resolve_shareability(jsonb) from public,anon,authenticated,service_role;
grant execute on function public.resolve_shareability(jsonb) to authenticated;
comment on function public.resolve_shareability(jsonb) is 'M13.3 caller-bound read-only eligibility. Personal owner or exact current Team Lead only; no creation, recipient access, re-sharing, publication or LIVE_REFERENCE.';
commit;
