begin;
-- Preserve the Team audit model while adding exactly one approved review event.
alter table public.audit_events drop constraint audit_events_event_type_check,
 drop constraint audit_events_entity_type_check, drop constraint audit_events_scope_type_check,
 drop constraint audit_events_entity_id_fkey, drop constraint audit_events_scope_id_fkey;
alter table public.audit_events add constraint audit_events_context_check check (
 (event_type in ('TEAM_CREATED','MEMBER_ADDED','MEMBER_REMOVED','MEMBER_MOVED','TEAM_LEAD_CHANGED','TEAM_ARCHIVED') and entity_type='team' and scope_type='team')
 or (event_type='REVISION_REQUESTED' and entity_type='submission' and scope_type='submission' and metadata='{}'::jsonb));
-- Stored generated targets keep actual PostgreSQL referential integrity for
-- each approved context, including concurrent deletion and identity changes.
alter table public.audit_events
 add column team_target_id uuid generated always as (case when entity_type='team' then entity_id end) stored references public.teams(id) on update restrict on delete restrict,
 add column submission_target_id uuid generated always as (case when entity_type='submission' then entity_id end) stored references public.submissions(id) on update restrict on delete restrict;

create function public.request_revision(target_submission uuid,revision_note text) returns jsonb language plpgsql security definer set search_path='' as $$
declare s public.submissions;v public.artifact_versions;a public.artifacts;body text;ra public.review_actions;f public.feedback_items;
begin
 s:=public.lock_review_submission(target_submission);
 body:=regexp_replace(revision_note,'^\s+|\s+$','','g');
 if body is null or length(body)=0 then raise exception 'Invalid revision note' using errcode='22023';end if;
 select * into v from public.artifact_versions where id=s.artifact_version_id;
 select * into a from public.artifacts where id=s.artifact_id;
 if s.status='REVISION_REQUESTED' and v.status='REVISION_REQUESTED' then
 if (select count(*) from public.review_actions where submission_id=s.id and action_type='REQUESTED_REVISION')<>1
 or (select count(*) from public.feedback_items where submission_id=s.id and feedback_type='REVISION_REQUEST')<>1
 or (select count(*) from public.audit_events where entity_type='submission' and entity_id=s.id and event_type='REVISION_REQUESTED')<>1 then
 raise exception 'Revision state conflict' using errcode='22023';end if;
 select * into ra from public.review_actions where submission_id=s.id and action_type='REQUESTED_REVISION';
 select * into f from public.feedback_items where submission_id=s.id and feedback_type='REVISION_REQUEST';
 if ra.reviewer_user_id is distinct from auth.uid() or ra.note is distinct from body
 or f.author_user_id is distinct from auth.uid() or f.content is distinct from body
 or f.target_entity_type<>'ARTIFACT' or f.target_entity_id<>a.id or f.target_version_id is distinct from v.id
 or f.project_id<>a.project_id or f.status<>'OPEN' or f.resolved_at is not null
 or not exists(select 1 from public.audit_events where entity_type='submission' and entity_id=s.id and event_type='REVISION_REQUESTED' and actor_user_id=auth.uid() and scope_type='submission' and scope_id=s.id and metadata='{}'::jsonb)
 then raise exception 'Revision state conflict' using errcode='22023';end if;
 return to_jsonb(s);
 end if;
 if s.status<>'UNDER_REVIEW' or v.status<>'UNDER_REVIEW'
 or exists(select 1 from public.review_actions where submission_id=s.id and action_type='REQUESTED_REVISION')
 or exists(select 1 from public.feedback_items where submission_id=s.id and feedback_type='REVISION_REQUEST')
 or exists(select 1 from public.audit_events where entity_type='submission' and entity_id=s.id and event_type='REVISION_REQUESTED')
 then raise exception 'Revision state conflict' using errcode='22023';end if;
 update public.submissions set status='REVISION_REQUESTED' where id=s.id returning * into s;
 update public.artifact_versions set status='REVISION_REQUESTED' where id=v.id;
 insert into public.review_actions(submission_id,reviewer_user_id,action_type,note) values(s.id,auth.uid(),'REQUESTED_REVISION',body);
 insert into public.feedback_items(submission_id,project_id,target_entity_type,target_entity_id,target_version_id,author_user_id,feedback_type,content)
 values(s.id,a.project_id,'ARTIFACT',a.id,v.id,auth.uid(),'REVISION_REQUEST',body);
 insert into public.audit_events(actor_user_id,event_type,entity_type,entity_id,scope_type,scope_id,metadata)
 values(auth.uid(),'REVISION_REQUESTED','submission',s.id,'submission',s.id,'{}');
 return to_jsonb(s);
end $$;
revoke all on function public.request_revision(uuid,text) from public,anon,authenticated,service_role;
grant execute on function public.request_revision(uuid,text) to authenticated;
comment on function public.request_revision(uuid,text) is 'Exact current reviewer-only revision transition. Submission lock serializes retries; no Version creation, pointer change, or Activity mutation.';
commit;
