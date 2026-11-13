begin;
create table private.comment_notification_batches(source_id uuid primary key,audience jsonb not null check(jsonb_typeof(audience)='array'),created_at timestamptz not null default clock_timestamp());
alter table private.comment_notification_batches enable row level security;
revoke all on private.comment_notification_batches from public,anon,authenticated,service_role;
create trigger comment_notification_batches_frozen before update or delete on private.comment_notification_batches for each row execute function private.freeze_approval_notification_batch();
-- Evaluate the existing exact-thread ACL for a server-derived candidate, then
-- restore both request identity settings even on failure. No caller can invoke
-- this helper or supply its actor through a notification request.
create function private.notification_thread_readable(actor uuid,sid uuid) returns boolean language plpgsql security definer set search_path='' as $$
declare prior_sub text:=current_setting('request.jwt.claim.sub',true);prior_claims text:=current_setting('request.jwt.claims',true);ok boolean;
begin
 perform set_config('request.jwt.claim.sub',actor::text,true);perform set_config('request.jwt.claims',jsonb_build_object('sub',actor)::text,true);
 ok:=public.can_read_share_comments(sid);
 perform set_config('request.jwt.claim.sub',coalesce(prior_sub,''),true);perform set_config('request.jwt.claims',coalesce(prior_claims,''),true);return coalesce(ok,false);
exception when others then
 perform set_config('request.jwt.claim.sub',coalesce(prior_sub,''),true);perform set_config('request.jwt.claims',coalesce(prior_claims,''),true);return false;
end $$;
revoke all on function private.notification_thread_readable(uuid,uuid) from public,anon,authenticated,service_role;
create function private.comment_notification_candidates(source uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare f public.feedback_items;c public.share_comments;s public.shares;wid uuid;pid uuid;author0 uuid;target_id uuid;target_type text;w public.workspaces;p public.development_projects;audience jsonb;answer jsonb:='[]';x jsonb;
begin
 select * into f from public.feedback_items where id=source;
 select * into c from public.share_comments where id=source;
 if (f.id is null)=(c.id is null) then return '[]';end if;
 if f.id is not null then
  if f.feedback_type not in ('COMMENT','QUESTION','CORRECTION','SUGGESTION','WARNING') then return '[]';end if;
  select a.workspace_id,a.project_id,sub.id into wid,pid,target_id from public.submissions sub join public.artifacts a on a.id=sub.artifact_id where sub.id=f.submission_id and a.project_id=f.project_id;
  target_type:='submission';author0:=f.author_user_id;
 else
  select * into s from public.shares where id=c.share_id and permission_level='COMMENT' and share_mode='SNAPSHOT';
  if s.id is null or (c.target_entity_type,c.target_entity_id) is distinct from (s.shared_entity_type,s.shared_entity_id)
   or not exists(select 1 from public.share_snapshots snap where snap.share_id=s.id and snap.source_version_id is not distinct from c.target_version_id) then return '[]';end if;
  case s.shared_entity_type
   when 'ARTIFACT' then select workspace_id,project_id into wid,pid from public.artifacts where id=s.shared_entity_id;
   when 'DEVELOPMENT_OBJECT' then select workspace_id,project_id into wid,pid from public.development_objects where id=s.shared_entity_id;
   when 'FILE' then select workspace_id,project_id into wid,pid from public.files where id=s.shared_entity_id;
   when 'EVIDENCE' then select workspace_id,project_id into wid,pid from public.evidence where id=s.shared_entity_id;
   when 'PATENT_RECORD' then select workspace_id,project_id into wid,pid from public.patent_records where id=s.shared_entity_id;
   when 'SCAMPER_ENTRY' then select workspace_id,project_id into wid,pid from public.scamper_entries where id=s.shared_entity_id;
  end case;
  if wid is distinct from s.source_workspace_id then return '[]';end if;
  target_type:='share';target_id:=s.id;author0:=c.author_user_id;
 end if;
 select * into w from public.workspaces where id=wid and status='active';
 select * into p from public.development_projects where id=pid and primary_workspace_id=wid and status='active' and archived_at is null;
 if w.id is null or p.id is null or target_id is null then return '[]';end if;
 if w.workspace_type='PERSONAL' and p.project_type='individual' and p.owner_user_id=w.owner_user_id then
  select coalesce(jsonb_agg(jsonb_build_object('userId',u.id)),'[]') into audience from public.users u where u.id=w.owner_user_id and u.account_status='active' and u.id<>author0;
 elsif w.workspace_type='TEAM' and p.project_type='team' and p.owner_team_id=w.team_id then
  select coalesce(jsonb_agg(jsonb_build_object('userId',m.user_id,'teamMembershipId',m.id)),'[]') into audience from public.team_memberships m where m.team_id=w.team_id and m.user_id<>author0 and private.notification_team_recipient(m.id,w.team_id)=m.user_id
   and exists(select 1 from public.project_memberships pm where pm.project_id=pid and pm.user_id=m.user_id and pm.project_role='participant' and pm.status='active' and pm.starts_at<=statement_timestamp() and (pm.ends_at is null or pm.ends_at>statement_timestamp()));
 else return '[]';end if;
 for x in select value from jsonb_array_elements(audience) loop
  if c.id is null or private.notification_thread_readable((x->>'userId')::uuid,s.id) then
   answer:=answer||jsonb_build_array(x||jsonb_build_object('entityType',target_type,'entityId',target_id));
  end if;
 end loop;
 return answer;
end $$;
revoke all on function private.comment_notification_candidates(uuid) from public,anon,authenticated,service_role;
create function public.comment_notification_contexts(target_source uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare candidates jsonb:=private.comment_notification_candidates(target_source);answer jsonb;
begin
 -- Do not freeze an unknown/uncommitted event. Empty legitimate audiences are frozen.
 if not exists(select 1 from public.feedback_items where id=target_source and feedback_type in ('COMMENT','QUESTION','CORRECTION','SUGGESTION','WARNING')) and not exists(select 1 from public.share_comments where id=target_source) then return '[]';end if;
 insert into private.comment_notification_batches(source_id,audience) values(target_source,candidates) on conflict do nothing;
 select coalesce(jsonb_agg(jsonb_build_object('recipientUserId',x->'userId','recipientContext',jsonb_strip_nulls(jsonb_build_object('sourceId',target_source,'teamMembershipId',x->'teamMembershipId')),'entityReference',jsonb_build_object('entityType',x->'entityType','entityId',x->'entityId'),'idempotencyKey','comment-received:'||target_source::text||':'||(x->>'userId')) order by x->>'userId'),'[]') into answer
 from private.comment_notification_batches b cross join lateral jsonb_array_elements(b.audience) x where b.source_id=target_source and candidates @> jsonb_build_array(x);
 return answer;
end $$;
revoke all on function public.comment_notification_contexts(uuid) from public,anon,authenticated;
grant execute on function public.comment_notification_contexts(uuid) to service_role;
create function private.create_comment_notification(input jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare d jsonb;n public.notifications;digest0 text;fingerprint0 text;source uuid;
begin
 if jsonb_typeof(input) is distinct from 'object' or input-array['notificationType','recipientContext','formatterInput','entityReference','idempotencyKey','title','body','recipientStrategy']<>'{}'
 or not(input?&array['notificationType','recipientContext','formatterInput','entityReference','title','body','recipientStrategy'])
 or input->'formatterInput' is distinct from '{}'::jsonb or input->>'title' is distinct from 'New comment received' or input->>'body' is distinct from 'New feedback was added.'
 or input->>'recipientStrategy' is distinct from 'CURRENT_AUTHORIZED_TARGET_OWNERS_EXCLUDING_AUTHOR'
 or jsonb_typeof(input->'recipientContext') is distinct from 'object' or (input->'recipientContext')-array['sourceId','teamMembershipId']<>'{}'
 or jsonb_typeof(input->'entityReference') is distinct from 'object' or (input->'entityReference')-array['entityType','entityId']<>'{}'
 then raise exception 'Notification unavailable' using errcode='22023';end if;
 source:=(input->'recipientContext'->>'sourceId')::uuid;
 select value into d from jsonb_array_elements(public.comment_notification_contexts(source)) where value->'recipientContext'=input->'recipientContext' and value->'entityReference'=input->'entityReference';
 if d is null then raise exception 'Notification unavailable' using errcode='42501';end if;
 if input?'idempotencyKey' and input->>'idempotencyKey' is distinct from d->>'idempotencyKey' then raise exception 'Notification unavailable' using errcode='22023';end if;
 digest0:=encode(sha256(convert_to(d->>'idempotencyKey','UTF8')),'hex');fingerprint0:=encode(sha256(convert_to(d::text,'UTF8')),'hex');
 insert into public.notifications(recipient_user_id,notification_type,title,body,entity_type,entity_id,metadata,idempotency_digest,request_fingerprint)
 values((d->>'recipientUserId')::uuid,'COMMENT_RECEIVED','New comment received','New feedback was added.',d->'entityReference'->>'entityType',(d->'entityReference'->>'entityId')::uuid,'{}',digest0,fingerprint0)
 on conflict(idempotency_digest) where idempotency_digest is not null do nothing returning * into n;
 if not found then select * into n from public.notifications where idempotency_digest=digest0;if n.request_fingerprint is distinct from fingerprint0 then raise exception 'Notification conflict' using errcode='23505';end if;end if;
 return to_jsonb(n)-array['metadata','idempotency_digest','request_fingerprint'];
end $$;
revoke all on function private.create_comment_notification(jsonb) from public,anon,authenticated,service_role;
create or replace function public.create_domain_notification(input jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare code text:=input->>'notificationType';ctx jsonb:=input->'recipientContext';ref jsonb:=input->'entityReference';
 source_id uuid;mid uuid;recipient uuid;target_id uuid;target_type text;ev public.audit_events;s public.submissions;sh public.shares;
 a public.artifacts;w public.workspaces;pid uuid;digest0 text;fingerprint0 text;n public.notifications;
begin
 if code='COMMENT_RECEIVED' then return private.create_comment_notification(input);end if;
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
