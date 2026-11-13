begin;
-- Add one immutable identifier-only event; preserve every existing context.
alter table public.audit_events drop constraint audit_events_context_check;
alter table public.audit_events add constraint audit_events_context_check check (
 (event_type in ('TEAM_CREATED','MEMBER_ADDED','MEMBER_REMOVED','MEMBER_MOVED','TEAM_LEAD_CHANGED','TEAM_ARCHIVED') and entity_type='team' and scope_type='team')
 or (event_type in ('REVISION_REQUESTED','ARTIFACT_APPROVED') and entity_type='submission' and scope_type='submission' and metadata='{}'::jsonb)
 or (event_type in ('ARTIFACT_REOPENED','PROBLEM_BANK_COMPOSED','SOLUTION_BANK_COMPOSED','TEAM_DECISION_RECORD_COMPOSED') and entity_type='artifact' and scope_type='artifact' and entity_id=scope_id and metadata='{}'::jsonb)
 or (event_type='BASELINE_UPDATED' and entity_type='project' and scope_type='project' and entity_id=scope_id and metadata='{}'::jsonb)
 or (event_type='SHARE_CREATED' and entity_type='share' and scope_type='share' and entity_id=scope_id and metadata='{}'::jsonb));
alter table public.audit_events add column share_target_id uuid generated always as
 (case when entity_type='share' then entity_id end) stored references public.shares(id) on update restrict on delete restrict;
create unique index audit_share_created_once on public.audit_events(share_target_id) where event_type='SHARE_CREATED';

create function public.share_entity(input jsonb) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare actor uuid:=public.current_platform_user_id();request jsonb;decision jsonb;wid uuid;pid uuid;eid uuid;did uuid;vid uuid;
 kind text;dest text;w public.workspaces;dw public.workspaces;s public.shares;ss public.share_snapshots;
 v public.artifact_versions;scope_workspace uuid;scope_project uuid;
begin
 if actor is null then
  if auth.uid() is null then raise exception 'Authentication required' using errcode='28000';end if;
  raise exception 'Resource unavailable' using errcode='42501';end if;
 if jsonb_typeof(input) is distinct from 'object' then raise exception 'Invalid Share input' using errcode='22023';end if;
 request:=input-'sourceVersionId';
 decision:=public.resolve_shareability(request);
 if decision->>'deniedReason' in ('VALIDATION_ERROR','ENTITY_NOT_SHAREABLE') then raise exception 'Invalid Share input' using errcode='22023';end if;
 if decision->>'allowed' is distinct from 'true' then raise exception 'Resource unavailable' using errcode='42501';end if;
 kind:=request->>'entityType';dest:=request->>'destinationType';eid:=(request->>'entityId')::uuid;did:=(request->>'destinationId')::uuid;
 if kind='ARTIFACT' then
  if jsonb_typeof(input->'sourceVersionId') is distinct from 'string' or (input->>'sourceVersionId') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
   then raise exception 'Invalid source Version selection' using errcode='22023';end if;
  vid:=(input->>'sourceVersionId')::uuid;
 elsif input->>'sourceVersionId' is not null then raise exception 'Invalid source Version selection' using errcode='22023';end if;
 wid:=(decision->>'sourceWorkspaceId')::uuid;
 select * into w from public.workspaces where id=wid;
 if dest='TEAM' then select x.* into dw from public.teams t join public.workspaces x on x.id=t.workspace_id where t.id=did;end if;
 -- Existing scope-first lock order. Protect mutable current authority through
 -- commit, including Personal destination membership and scoped MASTER expiry.
 perform 1 from public.cohorts where id in (w.cohort_id,dw.cohort_id) order by id for share;
 perform 1 from public.teams where id in (w.team_id,dw.team_id) order by id for share;
 case kind
 when 'ARTIFACT' then select project_id into pid from public.artifacts where id=eid;
 when 'DEVELOPMENT_OBJECT' then select project_id into pid from public.development_objects where id=eid;
 when 'FILE' then select project_id into pid from public.files where id=eid;
 when 'EVIDENCE' then select project_id into pid from public.evidence where id=eid;
 when 'PATENT_RECORD' then select project_id into pid from public.patent_records where id=eid;
 when 'SCAMPER_ENTRY' then select project_id into pid from public.scamper_entries where id=eid;
 end case;
 perform 1 from public.development_projects where id=pid for share;
 perform 1 from public.workspaces where id in (wid,dw.id) order by id for share;
 perform 1 from public.users where id=actor or id in(select user_id from public.role_assignments where id=did and dest='MASTER') order by id for share;
 perform 1 from public.role_assignments where user_id=actor or (id=did and dest='MASTER') order by id for share;
 perform 1 from public.enrollments where user_id=actor order by id for share;
 perform 1 from public.project_memberships where project_id=pid and user_id=actor order by id for share;
 perform 1 from public.team_memberships where user_id=actor and team_id in(w.team_id,dw.team_id) order by id for share;
 if kind='SCAMPER_ENTRY' then
  -- Match methodology mutations: Activity before source entry.
  perform 1 from public.activity_instances where id=(select activity_instance_id from public.scamper_entries where id=eid) for share;
 end if;
 -- Lock the selected source before deriving its frozen projection.
 case kind
 when 'ARTIFACT' then select workspace_id,project_id into scope_workspace,scope_project from public.artifacts where id=eid for share;
 when 'DEVELOPMENT_OBJECT' then select workspace_id,project_id into scope_workspace,scope_project from public.development_objects where id=eid for share;
 when 'FILE' then select workspace_id,project_id into scope_workspace,scope_project from public.files where id=eid for share;
 when 'EVIDENCE' then select workspace_id,project_id into scope_workspace,scope_project from public.evidence where id=eid for share;
 when 'PATENT_RECORD' then select workspace_id,project_id into scope_workspace,scope_project from public.patent_records where id=eid for share;
 when 'SCAMPER_ENTRY' then select workspace_id,project_id into scope_workspace,scope_project from public.scamper_entries where id=eid for share;
 end case;
 if scope_workspace is distinct from wid or scope_project is distinct from pid then raise exception 'Resource unavailable' using errcode='42501';end if;
 decision:=public.resolve_shareability(request);
 if public.current_platform_user_id() is distinct from actor or decision->>'allowed' is distinct from 'true' or decision->>'sourceWorkspaceId' is distinct from wid::text then
  raise exception 'Resource unavailable' using errcode='42501';end if;
 if kind='ARTIFACT' then
  select * into v from public.artifact_versions where id=vid and artifact_id=eid for share;
  if not found or v.status='ARCHIVED' then raise exception 'Resource unavailable' using errcode='42501';end if;
 end if;
 -- The unchanged seven-column partial unique index serializes concurrent
 -- identical identities. DO NOTHING waits for a competing commit/rollback.
 insert into public.shares(shared_entity_type,shared_entity_id,destination_type,destination_id,permission_level,share_mode)
 values(kind::public.share_entity_type,eid,dest::public.share_destination_type,did,(request->>'permissionLevel')::public.share_permission_level,'SNAPSHOT')
 on conflict(source_workspace_id,shared_entity_type,shared_entity_id,destination_type,destination_id,permission_level,share_mode) where revoked_at is null do nothing returning * into s;
 if not found then
  select * into s from public.shares where source_workspace_id=wid and shared_entity_type=kind::public.share_entity_type and shared_entity_id=eid
   and destination_type=dest::public.share_destination_type and destination_id=did and permission_level=(request->>'permissionLevel')::public.share_permission_level and share_mode='SNAPSHOT' and revoked_at is null for share;
  if not found then raise exception 'Retry Share request' using errcode='40001';end if;
  select * into ss from public.share_snapshots where share_id=s.id;
  if not found then raise exception 'Incomplete Share history' using errcode='23514';end if;
  if not exists(select 1 from public.audit_events where event_type='SHARE_CREATED' and entity_type='share' and entity_id=s.id
    and scope_type='share' and scope_id=s.id and actor_user_id=s.shared_by and metadata='{}') then
   raise exception 'Incomplete Share history' using errcode='23514';end if;
  if ss.source_version_id is distinct from vid then raise exception 'ACTIVE_SHARE_DIFFERENT_VERSION' using errcode='P1304';end if;
  return to_jsonb(s);
 end if;
 insert into public.share_snapshots(share_id,source_version_id) values(s.id,vid);
 -- Share ID refers to immutable actor/source/destination/permission/mode;
 -- no confidential content is copied into the audit event. This durable event
 -- is the M15 hook; existing notifications only support M5 membership events.
 insert into public.audit_events(actor_user_id,event_type,entity_type,entity_id,scope_type,scope_id,metadata)
 values(actor,'SHARE_CREATED','share',s.id,'share',s.id,'{}');
 return to_jsonb(s);
end $$;
revoke all on function public.share_entity(jsonb) from public,anon,authenticated,service_role;
grant execute on function public.share_entity(jsonb) to authenticated;
comment on function public.share_entity(jsonb) is 'M13.4 atomic explicit-version Share + frozen Snapshot + SHARE_CREATED event. No recipient resolver, re-share grant, notification delivery or revoke API.';
commit;
