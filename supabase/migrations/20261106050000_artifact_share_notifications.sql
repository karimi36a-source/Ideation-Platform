begin;
-- Durable recipient candidates for the existing SHARE_CREATED hook only. No
-- notification is written inside share_entity; delivery follows RPC commit.
-- This private ledger prevents retries from fanning out to later joiners.
create table private.artifact_share_notification_audience(
 event_id uuid not null references public.audit_events(id) on delete restrict,
 recipient_user_id uuid not null references public.users(id) on delete restrict,
 team_membership_id uuid references public.team_memberships(id) on delete restrict,
 primary key(event_id,recipient_user_id)
);
alter table private.artifact_share_notification_audience enable row level security;
revoke all on private.artifact_share_notification_audience from public,anon,authenticated,service_role;
create function private.capture_artifact_share_notification_audience() returns trigger
language plpgsql security definer set search_path='' as $$
declare sh public.shares;w public.workspaces;
begin
 if new.event_type<>'SHARE_CREATED' or new.entity_type<>'share' then return new;end if;
 select * into sh from public.shares where id=new.entity_id;
 if not found or sh.shared_entity_type<>'ARTIFACT' or sh.revoked_at is not null or sh.share_mode<>'SNAPSHOT'
  or sh.permission_level not in ('VIEW','COMMENT') then return new;end if;
 if new.scope_type<>'share' or new.scope_id<>sh.id or new.actor_user_id<>sh.shared_by
  or new.metadata<>'{}'::jsonb or not exists(select 1 from public.share_snapshots ss
   join public.artifact_versions v on v.id=ss.source_version_id and v.artifact_id=sh.shared_entity_id where ss.share_id=sh.id)
 then raise exception 'Invalid Share event' using errcode='23514';end if;
 if sh.destination_type='TEAM' then
  insert into private.artifact_share_notification_audience(event_id,recipient_user_id,team_membership_id)
  select distinct on(m.user_id) new.id,m.user_id,m.id from public.team_memberships m
  where m.team_id=sh.destination_id and private.notification_team_recipient(m.id,sh.destination_id)=m.user_id
  order by m.user_id,m.id;
 elsif sh.destination_type='MASTER' then
  select * into w from public.workspaces where id=sh.source_workspace_id;
  insert into private.artifact_share_notification_audience(event_id,recipient_user_id)
  select new.id,ra.user_id from public.role_assignments ra join public.roles r on r.id=ra.role_id join public.users u on u.id=ra.user_id
  where ra.id=sh.destination_id and r.code='MASTER' and u.account_status='active' and ra.status='active'
   and ra.starts_at<=statement_timestamp() and (ra.ends_at is null or ra.ends_at>statement_timestamp())
   and ra.organization_id is null and ra.program_id is null and ra.project_id is null
   and ((ra.team_id=w.team_id and ra.cohort_id is null) or (ra.cohort_id=w.cohort_id and ra.team_id is null));
 end if;
 return new;
end $$;
revoke all on function private.capture_artifact_share_notification_audience() from public,anon,authenticated,service_role;
create trigger artifact_share_notification_audience after insert on public.audit_events
 for each row execute function private.capture_artifact_share_notification_audience();
-- No backfill: past Shares must not notify members who joined afterward.
-- Only trusted post-commit domain code can obtain opaque recipient selectors.
create function public.artifact_share_notification_contexts(target_share uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare sh public.shares;result jsonb;
begin
 select * into sh from public.shares where id=target_share;
 if not found or sh.shared_entity_type<>'ARTIFACT' or sh.revoked_at is not null or sh.share_mode<>'SNAPSHOT'
  or sh.permission_level not in ('VIEW','COMMENT') then return '[]'::jsonb;end if;
 select coalesce(jsonb_agg(jsonb_strip_nulls(jsonb_build_object('sourceId',x.event_id,'teamMembershipId',x.team_membership_id)) order by x.recipient_user_id),'[]'::jsonb)
 into result from private.artifact_share_notification_audience x join public.audit_events e on e.id=x.event_id
 where e.entity_type='share' and e.entity_id=sh.id and e.event_type='SHARE_CREATED'
 and exists(select 1 from public.users u where u.id=x.recipient_user_id and u.account_status='active')
 and ((sh.destination_type='TEAM' and private.notification_team_recipient(x.team_membership_id,sh.destination_id)=x.recipient_user_id)
 or (sh.destination_type='MASTER' and x.team_membership_id is null and exists(
 select 1 from public.role_assignments ra join public.roles r on r.id=ra.role_id join public.workspaces w on w.id=sh.source_workspace_id
 where ra.id=sh.destination_id and ra.user_id=x.recipient_user_id and r.code='MASTER' and ra.status='active'
 and ra.starts_at<=statement_timestamp() and (ra.ends_at is null or ra.ends_at>statement_timestamp())
 and ra.organization_id is null and ra.program_id is null and ra.project_id is null
 and ((ra.team_id=w.team_id and ra.cohort_id is null) or (ra.cohort_id=w.cohort_id and ra.team_id is null)))));
 return result;
end $$;
revoke all on function public.artifact_share_notification_contexts(uuid) from public,anon,authenticated;
grant execute on function public.artifact_share_notification_contexts(uuid) to service_role;
create or replace function public.create_domain_notification(input jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare code text:=input->>'notificationType';ctx jsonb:=input->'recipientContext';ref jsonb:=input->'entityReference';
 source_id uuid;mid uuid;recipient uuid;target_id uuid;target_type text;ev public.audit_events;s public.submissions;sh public.shares;
 a public.artifacts;w public.workspaces;pid uuid;digest0 text;fingerprint0 text;n public.notifications;
begin
 if jsonb_typeof(input) is distinct from 'object' or input - array['notificationType','recipientContext','formatterInput','entityReference','idempotencyKey','title','body','recipientStrategy'] <> '{}'::jsonb
 or not(input ?& array['notificationType','recipientContext','formatterInput','entityReference','title','body','recipientStrategy'])
 or input->'formatterInput' is distinct from '{}'::jsonb or jsonb_typeof(ctx) is distinct from 'object'
 or ctx-array['sourceId','teamMembershipId']<>'{}'::jsonb or not(ctx?'sourceId')
 or jsonb_typeof(ref) is distinct from 'object' or ref-array['entityType','entityId']<>'{}'::jsonb or not(ref ?& array['entityType','entityId'])
 or jsonb_typeof(input->'title') is distinct from 'string' or jsonb_typeof(input->'body') is distinct from 'string'
 then raise exception 'Notification unavailable' using errcode='22023';end if;
 if input->>'recipientStrategy' is distinct from (case
 when code in ('MEMBER_ADDED','MEMBER_REMOVED','MEMBER_MOVED') then 'AFFECTED_MEMBERSHIP_USER'
 when code='ARTIFACT_SHARED' then 'CURRENT_SHARE_DESTINATION'
 when code='SUBMISSION_RECEIVED' then 'CURRENT_ASSIGNED_SUBMISSION_REVIEWER'
 when code in ('REVISION_REQUESTED','ARTIFACT_APPROVED') then 'CURRENT_AUTHORIZED_SUBMITTER_OR_OWNING_TEAM' end)
 then raise exception 'Notification unavailable' using errcode='22023';end if;
 source_id:=(ctx->>'sourceId')::uuid;mid:=(ctx->>'teamMembershipId')::uuid;
 if source_id is null or (ctx?'teamMembershipId' and mid is null) then raise exception 'Notification unavailable' using errcode='22023';end if;
 if code='SUBMISSION_RECEIVED' then
  select * into s from public.submissions where id=source_id for share;
  if not found or mid is not null or s.status not in ('SUBMITTED','UNDER_REVIEW','REVISION_REQUESTED') then raise exception 'Notification unavailable' using errcode='42501';end if;
  target_id:=s.id;target_type:='submission';recipient:=s.reviewer_user_id;
  -- Use the canonical M8 assigned reviewer and current scoped MASTER gates.
  if not exists(select 1 from public.artifacts ar join public.artifact_versions v on v.id=s.artifact_version_id and v.artifact_id=ar.id
   join public.development_projects p on p.id=ar.project_id and p.primary_workspace_id=ar.workspace_id
   join public.workspaces ws on ws.id=ar.workspace_id
   join public.activity_instances i on i.id=s.activity_instance_id and i.project_id=p.id and i.workspace_id=ws.id and i.team_id is not distinct from p.owner_team_id
   join public.cohorts c on c.id=i.cohort_id
   join public.role_assignments ra on ra.user_id=recipient join public.roles r on r.id=ra.role_id
   where ar.id=s.artifact_id and p.status='active' and p.archived_at is null and ws.status='active'
   and exists(select 1 from public.project_program_links l where l.project_id=p.id and l.cohort_id=c.id and l.program_id=c.program_id)
   and (i.team_id is null or exists(select 1 from public.teams t where t.id=i.team_id and t.workspace_id=ws.id and t.cohort_id=c.id and t.status in ('created','active')))
   and c.primary_master_id=recipient and r.code='MASTER'
   and ra.cohort_id=c.id and ra.organization_id is null and ra.program_id is null and ra.project_id is null and ra.team_id is null
   and ra.status='active' and ra.starts_at<=statement_timestamp() and (ra.ends_at is null or ra.ends_at>statement_timestamp()))
  then raise exception 'Notification unavailable' using errcode='42501';end if;
 elsif code in ('MEMBER_ADDED','MEMBER_REMOVED','MEMBER_MOVED','ARTIFACT_SHARED','REVISION_REQUESTED','ARTIFACT_APPROVED') then
  select * into ev from public.audit_events where id=source_id;
  if not found then raise exception 'Notification unavailable' using errcode='42501';end if;
  if code in ('MEMBER_ADDED','MEMBER_REMOVED','MEMBER_MOVED') then
   if ev.event_type<>code or ev.entity_type<>'team' or mid is not null then raise exception 'Notification unavailable' using errcode='42501';end if;
   recipient:=(ev.metadata->>'userId')::uuid;target_id:=ev.entity_id;target_type:='team';
   if not exists(select 1 from public.teams where id=target_id) then raise exception 'Notification unavailable' using errcode='42501';end if;
   -- Removed user may receive the safe membership-ended notice without source
   -- access. For active membership notices require current membership.
   if code<>'MEMBER_REMOVED' and not exists(select 1 from public.team_memberships m where m.team_id=target_id and m.user_id=recipient and private.notification_team_recipient(m.id,target_id)=recipient)
   then raise exception 'Notification unavailable' using errcode='42501';end if;
  elsif code='ARTIFACT_SHARED' then
   if ev.event_type<>'SHARE_CREATED' or ev.entity_type<>'share' then raise exception 'Notification unavailable' using errcode='42501';end if;
   select * into sh from public.shares where id=ev.entity_id for share;
   if not found or sh.revoked_at is not null or sh.share_mode<>'SNAPSHOT' or sh.permission_level not in ('VIEW','COMMENT') or sh.shared_entity_type<>'ARTIFACT'
    or not exists(select 1 from public.share_snapshots where share_id=sh.id) then raise exception 'Notification unavailable' using errcode='42501';end if;
   target_id:=sh.id;target_type:='share';
   if sh.destination_type='TEAM' then
    recipient:=private.notification_team_recipient(mid,sh.destination_id);
   elsif sh.destination_type='MASTER' and mid is null then
    select ra.user_id into recipient from public.role_assignments ra join public.roles r on r.id=ra.role_id join public.workspaces sw on sw.id=sh.source_workspace_id
     where ra.id=sh.destination_id and r.code='MASTER' and ra.status='active' and ra.starts_at<=statement_timestamp() and (ra.ends_at is null or ra.ends_at>statement_timestamp())
     and ra.organization_id is null and ra.program_id is null and ra.project_id is null
     and ((ra.team_id=sw.team_id and ra.cohort_id is null) or (ra.cohort_id=sw.cohort_id and ra.team_id is null));
   end if;
  else
   if ev.event_type<>code or ev.entity_type<>'submission' then raise exception 'Notification unavailable' using errcode='42501';end if;
   select * into s from public.submissions where id=ev.entity_id for share;
   if not found or (code='REVISION_REQUESTED' and s.status<>'REVISION_REQUESTED') or (code='ARTIFACT_APPROVED' and s.status<>'APPROVED') then raise exception 'Notification unavailable' using errcode='42501';end if;
   target_id:=s.id;target_type:='submission';
   select * into a from public.artifacts where id=s.artifact_id;
   select * into w from public.workspaces where id=a.workspace_id;
   pid:=a.project_id;
   if w.status<>'active' then raise exception 'Notification unavailable' using errcode='42501';end if;
   if w.workspace_type='PERSONAL' and mid is null then recipient:=w.owner_user_id;
   elsif w.workspace_type='TEAM' then
    if mid is null then select m.id into mid from public.team_memberships m where m.team_id=w.team_id and m.user_id=s.submitted_by and private.notification_team_recipient(m.id,w.team_id) is not null;end if;
    recipient:=private.notification_team_recipient(mid,w.team_id);
   end if;
   if not exists(select 1 from public.development_projects p
    where p.id=pid and p.primary_workspace_id=w.id and p.status='active' and p.archived_at is null
    and ((w.workspace_type='PERSONAL' and p.project_type='individual' and p.owner_user_id=recipient and p.owner_team_id is null)
     or (w.workspace_type='TEAM' and p.project_type='team' and p.owner_team_id=w.team_id and exists(select 1 from public.project_memberships pm where pm.project_id=p.id
      and pm.user_id=recipient and pm.project_role='participant' and pm.status='active' and pm.starts_at<=statement_timestamp() and (pm.ends_at is null or pm.ends_at>statement_timestamp()))))) then recipient:=null;end if;
  end if;
 else raise exception 'Notification unavailable' using errcode='22023';end if;
 if recipient is null or not exists(select 1 from public.users where id=recipient and (account_status='active' or code='MEMBER_REMOVED'))
 or ref->>'entityType' is distinct from target_type or (ref->>'entityId')::uuid is distinct from target_id
 then raise exception 'Notification unavailable' using errcode='42501';end if;
 -- Only the immutable creation-time audience may receive this event. Current
 -- destination eligibility was checked above; history is never a capability.
 if code='ARTIFACT_SHARED' and not exists(select 1 from private.artifact_share_notification_audience x
  where x.event_id=source_id and x.recipient_user_id=recipient and x.team_membership_id is not distinct from mid)
 then raise exception 'Notification unavailable' using errcode='42501';end if;
 if input?'idempotencyKey' and (jsonb_typeof(input->'idempotencyKey') is distinct from 'string' or input->>'idempotencyKey' !~ '^[A-Za-z0-9:_-]{1,160}$') then raise exception 'Notification unavailable' using errcode='22023';end if;
 -- Membership retry identity belongs to the immutable event, not a caller key.
 if code in ('MEMBER_ADDED','MEMBER_REMOVED','MEMBER_MOVED') then
  if input->>'title' is distinct from private.membership_notification_text(code)->>'title'
   or input->>'body' is distinct from private.membership_notification_text(code)->>'body'
   then raise exception 'Notification unavailable' using errcode='22023';end if;
  digest0:=encode(sha256(convert_to('m5-membership:'||source_id::text,'UTF8')),'hex');
  fingerprint0:=encode(sha256(convert_to((input-'idempotencyKey')::text,'UTF8')),'hex');
 elsif code='ARTIFACT_SHARED' then
  if input->>'title'<>'Artifact shared' or input->>'body'<>'An Artifact Snapshot has been shared with you.'
   then raise exception 'Notification unavailable' using errcode='22023';end if;
  digest0:=encode(sha256(convert_to('artifact-share:'||source_id::text||':'||recipient::text,'UTF8')),'hex');
  fingerprint0:=encode(sha256(convert_to(jsonb_build_object('event',source_id,'recipient',recipient,'share',target_id,
   'code',code,'title',input->>'title','body',input->>'body')::text,'UTF8')),'hex');
 elsif input?'idempotencyKey' then
  if jsonb_typeof(input->'idempotencyKey') is distinct from 'string' or input->>'idempotencyKey' !~ '^[A-Za-z0-9:_-]{1,160}$' then raise exception 'Notification unavailable' using errcode='22023';end if;
  digest0:=encode(sha256(convert_to(input->>'idempotencyKey','UTF8')),'hex');
  fingerprint0:=encode(sha256(convert_to(input::text,'UTF8')),'hex');
 end if;
 insert into public.notifications(recipient_user_id,notification_type,title,body,entity_type,entity_id,metadata,idempotency_digest,request_fingerprint)
 values(recipient,code,input->>'title',input->>'body',target_type,target_id,case when code='MEMBER_MOVED' then jsonb_strip_nulls(jsonb_build_object('sourceTeamId',ev.metadata->'sourceTeamId')) else '{}'::jsonb end,digest0,fingerprint0)
 on conflict(idempotency_digest) where idempotency_digest is not null do nothing returning * into n;
 if not found then
  select * into n from public.notifications where idempotency_digest=digest0;
  if n.request_fingerprint is distinct from fingerprint0 then raise exception 'Notification conflict' using errcode='23505';end if;
 end if;
 return to_jsonb(n)-array['metadata','idempotency_digest','request_fingerprint'];
end $$;
commit;
