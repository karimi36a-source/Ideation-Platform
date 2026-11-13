begin;
-- Source management inspection only; never recipient access or Workspace listing.
create function public.list_entity_shares(input jsonb) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=public.current_platform_user_id();kind text;eid uuid;wid uuid;pid uuid;w public.workspaces;rows jsonb;
begin
 if actor is null then
  if auth.uid() is null then raise exception 'Authentication required' using errcode='28000';end if;
  raise exception 'Resource unavailable' using errcode='42501';end if;
 if jsonb_typeof(input) is distinct from 'object' then raise exception 'Invalid history input' using errcode='22023';end if;
 if (select count(*) from jsonb_object_keys(input))<>2
 or jsonb_typeof(input->'entityType') is distinct from 'string' or jsonb_typeof(input->'entityId') is distinct from 'string'
 or input->>'entityType'<>all(array['ARTIFACT','DEVELOPMENT_OBJECT','FILE','EVIDENCE','PATENT_RECORD','SCAMPER_ENTRY'])
 or input->>'entityId' !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
 then raise exception 'Invalid history input' using errcode='22023';end if;
 kind:=input->>'entityType';eid:=(input->>'entityId')::uuid;
 case kind
 when 'ARTIFACT' then select workspace_id,project_id into wid,pid from public.artifacts where id=eid;
 when 'DEVELOPMENT_OBJECT' then select workspace_id,project_id into wid,pid from public.development_objects where id=eid;
 when 'FILE' then select workspace_id,project_id into wid,pid from public.files where id=eid;
 when 'EVIDENCE' then select workspace_id,project_id into wid,pid from public.evidence where id=eid;
 when 'PATENT_RECORD' then select workspace_id,project_id into wid,pid from public.patent_records where id=eid;
 when 'SCAMPER_ENTRY' then select workspace_id,project_id into wid,pid from public.scamper_entries where id=eid;
 end case;
 select * into w from public.workspaces where id=wid;
 if wid is null or w.id is null or w.visibility<>'private'
 or (pid is not null and not exists(select 1 from public.development_projects where id=pid and primary_workspace_id=wid))
 then raise exception 'Resource unavailable' using errcode='42501';end if;
 -- Same current source authority as M13.12, independent of creator, sharer,
 -- recipient, review roles, source lifecycle or destination eligibility.
 if w.workspace_type='TEAM' then
  if public.get_team_workspace_access(wid) is distinct from 'team_lead' or not exists(
   select 1 from public.teams t where t.id=w.team_id and t.workspace_id=wid and t.team_lead_user_id=actor and t.status in ('created','active'))
  then raise exception 'Resource unavailable' using errcode='42501';end if;
 elsif w.workspace_type<>'PERSONAL' or w.owner_user_id is distinct from actor then
  raise exception 'Resource unavailable' using errcode='42501';end if;
 -- No roster, destination Workspace, assignment payload or Snapshot content.
 -- MASTER is displayed as a user reference, never a raw assignment record.
 select coalesce(jsonb_agg(jsonb_build_object(
  'shareId',s.id,
  'destination',case when s.destination_type='MASTER' then jsonb_build_object('type','MASTER','userId',ra.user_id)
   when s.destination_type='TEAM' then jsonb_build_object('type','TEAM','teamId',s.destination_id)
   when s.destination_type='USER' then jsonb_build_object('type','USER','userId',s.destination_id)
   when s.destination_type='COHORT' then jsonb_build_object('type','COHORT','cohortId',s.destination_id)
   else jsonb_build_object('type','WORKSPACE','workspaceId',s.destination_id) end,
  'permissionLevel',s.permission_level,'shareMode',s.share_mode,
  'sourceVersionId',case when kind='ARTIFACT' and exists(select 1 from public.artifact_versions v where v.id=ss.source_version_id and v.artifact_id=eid) then ss.source_version_id else null end,
  'createdAt',s.created_at,'sharedBy',s.shared_by,
  'state',case when s.revoked_at is null then 'ACTIVE' else 'REVOKED' end,
  'revokedAt',s.revoked_at,'revokedBy',s.revoked_by
 ) order by s.created_at,s.id),'[]'::jsonb) into rows
 from public.shares s left join public.share_snapshots ss on ss.share_id=s.id
 left join public.role_assignments ra on s.destination_type='MASTER' and ra.id=s.destination_id
 where s.shared_entity_type=kind::public.share_entity_type and s.shared_entity_id=eid and s.source_workspace_id=wid;
 return jsonb_build_object('entityType',kind,'entityId',eid,'shares',rows);
end$$;
revoke all on function public.list_entity_shares(jsonb) from public,anon,authenticated,service_role;
grant execute on function public.list_entity_shares(jsonb) to authenticated;
comment on function public.list_entity_shares(jsonb) is 'M13.13 current source owner/exact active Team Lead only. Read-only one-entity history, creation-time/ID ordering, exact Snapshot Version IDs and identifier-only destinations; no recipient enumeration or source content.';
commit;
