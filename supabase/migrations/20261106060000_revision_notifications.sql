begin;
-- Notification delivery bookkeeping only: no review state, source ACL or body.
-- First post-commit dispatch freezes its current audience, including an empty
-- audience. Retries cannot fan out historical notices to later Team joiners.
create table private.revision_notification_batches(
 event_id uuid primary key references public.audit_events(id) on delete restrict,
 audience jsonb not null check(jsonb_typeof(audience)='array'),
 created_at timestamptz not null default clock_timestamp()
);
alter table private.revision_notification_batches enable row level security;
revoke all on private.revision_notification_batches from public,anon,authenticated,service_role;
create function private.freeze_revision_notification_batch() returns trigger
language plpgsql set search_path='' as $$begin raise exception 'Notification audience is immutable' using errcode='23514';end$$;
revoke all on function private.freeze_revision_notification_batch() from public,anon,authenticated,service_role;
create trigger revision_notification_batches_frozen before update or delete on private.revision_notification_batches
 for each row execute function private.freeze_revision_notification_batch();
create function public.revision_notification_contexts(target_submission uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare s public.submissions;a public.artifacts;w public.workspaces;p public.development_projects;e uuid;candidates jsonb;result jsonb;
begin
 select * into s from public.submissions where id=target_submission and status='REVISION_REQUESTED' for share;
 if not found or s.status<>'REVISION_REQUESTED' then return '[]'::jsonb;end if;
 select * into a from public.artifacts where id=s.artifact_id;
 select * into w from public.workspaces where id=a.workspace_id;
 select * into p from public.development_projects where id=a.project_id;
 if w.status<>'active' or p.status<>'active' or p.archived_at is not null or p.primary_workspace_id<>w.id
 or not exists(select 1 from public.artifact_versions v where v.id=s.artifact_version_id and v.artifact_id=a.id and v.status='REVISION_REQUESTED')
 or not exists(select 1 from public.review_actions r join public.feedback_items f on f.submission_id=r.submission_id
 where r.submission_id=s.id and r.action_type='REQUESTED_REVISION' and r.reviewer_user_id=s.reviewer_user_id
 and f.feedback_type='REVISION_REQUEST' and f.author_user_id=r.reviewer_user_id and f.content=r.note
 and f.target_entity_type='ARTIFACT' and f.target_entity_id=a.id and f.target_version_id=s.artifact_version_id and f.project_id=p.id)
 then return '[]'::jsonb;end if;
 select id into e from public.audit_events where event_type='REVISION_REQUESTED' and entity_type='submission' and entity_id=s.id
 and scope_type='submission' and scope_id=s.id and actor_user_id=s.reviewer_user_id and metadata='{}'::jsonb;
 if e is null then return '[]'::jsonb;end if;
 -- Same existing M15.3 recipient gates. No role-only authority or source grant.
 if w.workspace_type='PERSONAL' and p.project_type='individual' and p.owner_user_id=w.owner_user_id then
  select coalesce(jsonb_agg(jsonb_build_object('userId',u.id)),'[]'::jsonb) into candidates from public.users u where u.id=w.owner_user_id and u.account_status='active';
 elsif w.workspace_type='TEAM' and p.project_type='team' and p.owner_team_id=w.team_id then
  select coalesce(jsonb_agg(jsonb_build_object('userId',x.user_id,'teamMembershipId',x.id) order by x.user_id),'[]'::jsonb) into candidates
  from (select distinct on(m.user_id) m.id,m.user_id from public.team_memberships m where m.team_id=w.team_id
   and private.notification_team_recipient(m.id,w.team_id)=m.user_id
   and exists(select 1 from public.project_memberships pm where pm.project_id=p.id and pm.user_id=m.user_id and pm.project_role='participant'
   and pm.status='active' and pm.starts_at<=statement_timestamp() and (pm.ends_at is null or pm.ends_at>statement_timestamp())) order by m.user_id,m.id) x;
 else return '[]'::jsonb;end if;
 insert into private.revision_notification_batches(event_id,audience) values(e,candidates) on conflict(event_id) do nothing;
 select coalesce(jsonb_agg(jsonb_build_object('recipientContext',jsonb_strip_nulls(jsonb_build_object('sourceId',e,'teamMembershipId',x.value->'teamMembershipId')),
  'idempotencyKey','revision-requested:'||e::text||':'||(x.value->>'userId')) order by x.value->>'userId'),'[]'::jsonb) into result
 from private.revision_notification_batches b cross join lateral jsonb_array_elements(b.audience) x
 where b.event_id=e and exists(select 1 from public.users u where u.id=(x.value->>'userId')::uuid and u.account_status='active')
 and ((w.workspace_type='PERSONAL' and p.project_type='individual' and p.owner_user_id=w.owner_user_id and w.owner_user_id=(x.value->>'userId')::uuid)
 or (w.workspace_type='TEAM' and p.project_type='team' and p.owner_team_id=w.team_id
 and private.notification_team_recipient((x.value->>'teamMembershipId')::uuid,w.team_id)=(x.value->>'userId')::uuid
 and exists(select 1 from public.project_memberships pm where pm.project_id=p.id and pm.user_id=(x.value->>'userId')::uuid and pm.project_role='participant'
 and pm.status='active' and pm.starts_at<=statement_timestamp() and (pm.ends_at is null or pm.ends_at>statement_timestamp()))));
 return result;
end $$;
revoke all on function public.revision_notification_contexts(uuid) from public,anon,authenticated;
grant execute on function public.revision_notification_contexts(uuid) to service_role;
commit;
