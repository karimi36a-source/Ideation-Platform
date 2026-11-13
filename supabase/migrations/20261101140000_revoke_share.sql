begin;
-- The immutable identifier-only event is also the existing durable M15 hook.
-- The referenced Share preserves source/destination/permission/mode and time.
alter table public.audit_events drop constraint audit_events_context_check;
alter table public.audit_events add constraint audit_events_context_check check (
 (event_type in ('TEAM_CREATED','MEMBER_ADDED','MEMBER_REMOVED','MEMBER_MOVED','TEAM_LEAD_CHANGED','TEAM_ARCHIVED') and entity_type='team' and scope_type='team')
 or (event_type in ('REVISION_REQUESTED','ARTIFACT_APPROVED') and entity_type='submission' and scope_type='submission' and metadata='{}'::jsonb)
 or (event_type in ('ARTIFACT_REOPENED','PROBLEM_BANK_COMPOSED','SOLUTION_BANK_COMPOSED','TEAM_DECISION_RECORD_COMPOSED') and entity_type='artifact' and scope_type='artifact' and entity_id=scope_id and metadata='{}'::jsonb)
 or (event_type='BASELINE_UPDATED' and entity_type='project' and scope_type='project' and entity_id=scope_id and metadata='{}'::jsonb)
 or (event_type in ('SHARE_CREATED','SHARE_REVOKED') and entity_type='share' and scope_type='share' and entity_id=scope_id and metadata='{}'::jsonb));
create unique index audit_share_revoked_once on public.audit_events(share_target_id) where event_type='SHARE_REVOKED';

create function public.revoke_share(input jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=public.current_platform_user_id();s public.shares;w public.workspaces;
 wid uuid;pid uuid;locked_workspace uuid;locked_project uuid;sid uuid;
begin
 if actor is null then
  if auth.uid() is null then raise exception 'Authentication required' using errcode='28000';end if;
  raise exception 'Resource unavailable' using errcode='42501';end if;
 if jsonb_typeof(input) is distinct from 'object' then raise exception 'Invalid Share input' using errcode='22023';end if;
 if (select count(*) from jsonb_object_keys(input))<>1
 or jsonb_typeof(input->'shareId') is distinct from 'string'
 or input->>'shareId' !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
 then raise exception 'Invalid Share input' using errcode='22023';end if;
 sid:=(input->>'shareId')::uuid;
 select * into s from public.shares where id=sid;
 if not found then raise exception 'Resource unavailable' using errcode='42501';end if;
 case s.shared_entity_type
 when 'ARTIFACT' then select workspace_id,project_id into wid,pid from public.artifacts where id=s.shared_entity_id;
 when 'DEVELOPMENT_OBJECT' then select workspace_id,project_id into wid,pid from public.development_objects where id=s.shared_entity_id;
 when 'FILE' then select workspace_id,project_id into wid,pid from public.files where id=s.shared_entity_id;
 when 'EVIDENCE' then select workspace_id,project_id into wid,pid from public.evidence where id=s.shared_entity_id;
 when 'PATENT_RECORD' then select workspace_id,project_id into wid,pid from public.patent_records where id=s.shared_entity_id;
 when 'SCAMPER_ENTRY' then select workspace_id,project_id into wid,pid from public.scamper_entries where id=s.shared_entity_id;
 end case;
 if wid is null or wid is distinct from s.source_workspace_id then raise exception 'Resource unavailable' using errcode='42501';end if;
 select * into w from public.workspaces where id=wid;
 -- Same scope-first ordering as Share creation. Current source authority is
 -- held through commit; destination expiry/removal never prevents revocation.
 perform 1 from public.cohorts where id=w.cohort_id for share;
 perform 1 from public.teams where id=w.team_id for share;
 perform 1 from public.development_projects where id=pid for share;
 perform 1 from public.workspaces where id=wid for share;
 perform 1 from public.users where id=actor for share;
 perform 1 from public.role_assignments where user_id=actor order by id for share;
 perform 1 from public.enrollments where user_id=actor order by id for share;
 perform 1 from public.project_memberships where project_id=pid and user_id=actor order by id for share;
 perform 1 from public.team_memberships where team_id=w.team_id and user_id=actor order by id for share;
 case s.shared_entity_type
 when 'ARTIFACT' then select workspace_id,project_id into locked_workspace,locked_project from public.artifacts where id=s.shared_entity_id for share;
 when 'DEVELOPMENT_OBJECT' then select workspace_id,project_id into locked_workspace,locked_project from public.development_objects where id=s.shared_entity_id for share;
 when 'FILE' then select workspace_id,project_id into locked_workspace,locked_project from public.files where id=s.shared_entity_id for share;
 when 'EVIDENCE' then select workspace_id,project_id into locked_workspace,locked_project from public.evidence where id=s.shared_entity_id for share;
 when 'PATENT_RECORD' then select workspace_id,project_id into locked_workspace,locked_project from public.patent_records where id=s.shared_entity_id for share;
 when 'SCAMPER_ENTRY' then select workspace_id,project_id into locked_workspace,locked_project from public.scamper_entries where id=s.shared_entity_id for share;
 end case;
 select * into s from public.shares where id=sid for update;
 select * into w from public.workspaces where id=wid;
 if actor is distinct from public.current_platform_user_id() or locked_workspace is distinct from wid or locked_project is distinct from pid
 or w.id is null or w.visibility<>'private'
 or (pid is not null and not exists(select 1 from public.development_projects where id=pid and primary_workspace_id=wid))
 then raise exception 'Resource unavailable' using errcode='42501';end if;
 if w.workspace_type='TEAM' then
  if public.get_team_workspace_access(wid) is distinct from 'team_lead' or not exists(
   select 1 from public.teams t where t.id=w.team_id and t.workspace_id=wid and t.team_lead_user_id=actor and t.status in ('created','active'))
  then raise exception 'Resource unavailable' using errcode='42501';end if;
 elsif w.workspace_type<>'PERSONAL' or w.owner_user_id is distinct from actor then
  raise exception 'Resource unavailable' using errcode='42501';end if;
 -- Re-authorize retries, but preserve the first committed actor/time forever.
 if s.revoked_at is not null then
  if not exists(select 1 from public.audit_events where event_type='SHARE_REVOKED' and share_target_id=s.id
   and actor_user_id=s.revoked_by and created_at=s.revoked_at and metadata='{}'::jsonb)
  then raise exception 'Incomplete Share history' using errcode='23514';end if;
  return to_jsonb(s);
 end if;
 update public.shares set revoked_at=clock_timestamp(),revoked_by=actor where id=s.id returning * into s;
 insert into public.audit_events(actor_user_id,event_type,entity_type,entity_id,scope_type,scope_id,metadata,created_at)
 values(actor,'SHARE_REVOKED','share',s.id,'share',s.id,'{}',s.revoked_at);
 return to_jsonb(s);
end$$;
revoke all on function public.revoke_share(jsonb) from public,anon,authenticated,service_role;
grant execute on function public.revoke_share(jsonb) to authenticated;
comment on function public.revoke_share(jsonb) is 'M13.12 current Personal owner/exact active source Team Lead only. Atomic one-way revocation + immutable identifier-only audit/M15 hook; caller-bound authorized retries preserve original actor/time. No source grant, history query or delivery.';
commit;
