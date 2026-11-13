begin;
-- A digest, not user-facing text, supplies durable retry identity. Existing M5
-- rows remain untouched and need no backfill or retry metadata.
alter table public.notifications add column idempotency_digest text, add column request_fingerprint text;
alter table public.notifications add constraint notifications_retry_digest check(
 (idempotency_digest is null or idempotency_digest ~ '^[0-9a-f]{64}$') and
 (request_fingerprint is null or request_fingerprint ~ '^[0-9a-f]{64}$') and
 (idempotency_digest is null or request_fingerprint is not null));
create unique index notifications_retry_identity on public.notifications(idempotency_digest) where idempotency_digest is not null;
-- Pure recipient eligibility for notification delivery, NOT an entity-access
-- grant. No roles confer membership; current canonical Team/enrollment gates.
create function private.notification_team_recipient(mid uuid,tid uuid) returns uuid
language sql stable security definer set search_path='' as $$
 select m.user_id from public.team_memberships m
 join public.teams t on t.id=m.team_id
 join public.workspaces w on w.id=t.workspace_id and w.team_id=t.id and w.cohort_id=t.cohort_id
 join public.users u on u.id=m.user_id
 where m.id=mid and t.id=tid and t.status in ('created','active')
 and w.status='active' and w.visibility='private' and w.workspace_type='TEAM'
 and m.status='active' and m.left_at is null and m.joined_at<=statement_timestamp()
 and m.membership_role in ('member','team_lead','mentor') and u.account_status='active'
 and exists(select 1 from public.enrollments e where e.user_id=u.id and e.cohort_id=t.cohort_id and e.status='active' and e.enrollment_role='participant')
$$;
revoke all on function private.notification_team_recipient(uuid,uuid) from public,anon,authenticated,service_role;
create function public.create_domain_notification(input jsonb) returns jsonb
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
 if recipient is null or not exists(select 1 from public.users where id=recipient and account_status='active')
 or ref->>'entityType' is distinct from target_type or (ref->>'entityId')::uuid is distinct from target_id
 then raise exception 'Notification unavailable' using errcode='42501';end if;
 if input?'idempotencyKey' then
  if jsonb_typeof(input->'idempotencyKey') is distinct from 'string' or input->>'idempotencyKey' !~ '^[A-Za-z0-9:_-]{1,160}$' then raise exception 'Notification unavailable' using errcode='22023';end if;
  digest0:=encode(sha256(convert_to(input->>'idempotencyKey','UTF8')),'hex');
  fingerprint0:=encode(sha256(convert_to(input::text,'UTF8')),'hex');
 end if;
 insert into public.notifications(recipient_user_id,notification_type,title,body,entity_type,entity_id,idempotency_digest,request_fingerprint)
 values(recipient,code,input->>'title',input->>'body',target_type,target_id,digest0,fingerprint0)
 on conflict(idempotency_digest) where idempotency_digest is not null do nothing returning * into n;
 if not found then
  select * into n from public.notifications where idempotency_digest=digest0;
  if n.request_fingerprint is distinct from fingerprint0 then raise exception 'Notification conflict' using errcode='23505';end if;
 end if;
 return to_jsonb(n)-array['metadata','idempotency_digest','request_fingerprint'];
end $$;
revoke all on function public.create_domain_notification(jsonb) from public,anon,authenticated;
grant execute on function public.create_domain_notification(jsonb) to service_role;
comment on function public.create_domain_notification(jsonb) is 'Internal M15.3 only: committed domain references, current canonical recipient, registry-formatted bounded text, atomic durable retry. Never grant to normal clients; no delivery or source access.';
commit;
