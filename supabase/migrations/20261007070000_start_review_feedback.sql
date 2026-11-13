begin;
create type public.review_action_type as enum ('STARTED_REVIEW','COMMENTED','REQUESTED_REVISION','APPROVED','REOPENED','REJECTED');
create type public.feedback_target_type as enum ('ARTIFACT','DEVELOPMENT_OBJECT');
create type public.feedback_type as enum ('COMMENT','QUESTION','CORRECTION','SUGGESTION','REVISION_REQUEST','APPROVAL_NOTE','WARNING');
create type public.feedback_status as enum ('OPEN','RESOLVED');
create table public.review_actions (
 id uuid primary key default gen_random_uuid(),
 submission_id uuid not null references public.submissions(id) on delete restrict,
 reviewer_user_id uuid not null references public.users(id) on delete restrict,
 action_type public.review_action_type not null,
 note text,
 created_at timestamptz not null default clock_timestamp()
);
create unique index review_actions_one_start on public.review_actions(submission_id) where action_type='STARTED_REVIEW';
create index review_actions_history on public.review_actions(submission_id,created_at,id);
create table public.feedback_items (
 id uuid primary key default gen_random_uuid(),
 submission_id uuid not null references public.submissions(id) on delete restrict,
 project_id uuid not null references public.development_projects(id) on delete restrict,
 target_entity_type public.feedback_target_type not null,
 target_entity_id uuid not null,
 target_version_id uuid references public.artifact_versions(id) on delete restrict,
 author_user_id uuid not null references public.users(id) on delete restrict,
 feedback_type public.feedback_type not null,
 content text not null check(content=regexp_replace(content,'^\s+|\s+$','','g') and length(content)>0),
 status public.feedback_status not null default 'OPEN',
 created_at timestamptz not null default clock_timestamp(),
 resolved_at timestamptz,
 check((status='OPEN' and resolved_at is null) or (status='RESOLVED' and resolved_at is not null))
);
create index feedback_items_review on public.feedback_items(submission_id,created_at,id);
create index feedback_items_target on public.feedback_items(target_entity_type,target_entity_id,target_version_id);
-- Append-only history. Resolution has no business operation in M8.8. New later
-- workflow must retain immutable target/content/author/time fields.
create function public.preserve_review_action() returns trigger language plpgsql set search_path='' as $$
begin raise exception 'Review action history is append-only' using errcode='23514';end $$;
create trigger review_actions_preserve before update or delete on public.review_actions for each row execute function public.preserve_review_action();
create function public.preserve_feedback_history() returns trigger language plpgsql set search_path='' as $$
begin
 if tg_op='DELETE' then raise exception 'Feedback history must be preserved' using errcode='23514';end if;
 if (new.id,new.submission_id,new.project_id,new.target_entity_type,new.target_entity_id,new.target_version_id,new.author_user_id,new.feedback_type,new.content,new.created_at)
 is distinct from (old.id,old.submission_id,old.project_id,old.target_entity_type,old.target_entity_id,old.target_version_id,old.author_user_id,old.feedback_type,old.content,old.created_at)
 then raise exception 'Feedback attribution/target/content are immutable' using errcode='23514';end if;
 return new;
end $$;
create trigger feedback_items_preserve before update or delete on public.feedback_items for each row execute function public.preserve_feedback_history();
-- Structural invoker validation for trusted writes; no polymorphic free targets.
create function public.validate_feedback_target() returns trigger language plpgsql set search_path='' as $$
declare s public.submissions;a public.artifacts;begin
 select * into s from public.submissions where id=new.submission_id;
 select * into a from public.artifacts where id=s.artifact_id;
 if a.id is null or new.project_id is distinct from a.project_id or new.author_user_id is distinct from s.reviewer_user_id
 or (new.target_version_id is not null and new.target_version_id is distinct from s.artifact_version_id) then raise exception 'Invalid feedback context' using errcode='23514';end if;
 if new.target_entity_type='ARTIFACT' then
 if new.target_entity_id<>a.id then raise exception 'Invalid feedback target' using errcode='23514';end if;
 else
 if not exists(select 1 from public.artifact_object_links l join public.development_objects o on o.id=l.development_object_id
 where l.artifact_id=a.id and l.artifact_version_id=s.artifact_version_id and o.id=new.target_entity_id and o.project_id=a.project_id and o.workspace_id=a.workspace_id)
 then raise exception 'Invalid feedback target' using errcode='23514';end if;
 end if;return new;
end $$;
create trigger feedback_items_validate before insert or update on public.feedback_items for each row execute function public.validate_feedback_target();
-- Private definer locks canonical scope before Artifact/Version/Submission, as
-- M8 provisioning/archive do. Recheck current caller/reviewer after any wait.
create function public.lock_review_submission(target_submission uuid) returns public.submissions language plpgsql security definer set search_path='' as $$
declare actor uuid;s public.submissions;a public.artifacts;i public.activity_instances;p public.development_projects;
begin
 actor:=public.current_platform_user_id();
 if actor is null then
 if auth.uid() is null then raise exception 'Authentication required' using errcode='28000';end if;
 raise exception 'Access denied' using errcode='42501';end if;
 if not public.can_review_submission(target_submission) then raise exception 'Access denied' using errcode='42501';end if;
 select * into s from public.submissions where id=target_submission;
 select * into i from public.activity_instances where id=s.activity_instance_id;
 select * into a from public.artifacts where id=s.artifact_id;
 select * into p from public.development_projects where id=a.project_id;
 perform 1 from public.cohorts where id=i.cohort_id for share;
 if p.owner_team_id is not null then perform 1 from public.teams where id=p.owner_team_id for share;end if;
 perform 1 from public.development_projects where id=p.id for share;
 perform 1 from public.workspaces where id=a.workspace_id for share;
 perform 1 from public.users where id=actor for share;
 perform 1 from public.role_assignments where user_id=actor order by id for share;
 perform 1 from public.activity_instances where id=i.id for share;
 select * into a from public.artifacts where id=s.artifact_id for update;
 perform 1 from public.artifact_versions where id=s.artifact_version_id for update;
 select * into s from public.submissions where id=target_submission for update;
 if public.current_platform_user_id() is distinct from actor or not public.can_review_submission(s.id) or a.status<>'ACTIVE' or a.archived_at is not null then raise exception 'Access denied' using errcode='42501';end if;
 return s;
end $$;
create function public.start_review(target_submission uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare s public.submissions;v public.artifact_versions;begin
 s:=public.lock_review_submission(target_submission);
 select * into v from public.artifact_versions where id=s.artifact_version_id;
 if s.status='UNDER_REVIEW' and v.status='UNDER_REVIEW' and exists(select 1 from public.review_actions where submission_id=s.id and action_type='STARTED_REVIEW' and reviewer_user_id=auth.uid()) then return to_jsonb(s);end if;
 if s.status<>'SUBMITTED' or v.status<>'SUBMITTED' then raise exception 'Invalid review state' using errcode='22023';end if;
 update public.submissions set status='UNDER_REVIEW' where id=s.id returning * into s;
 update public.artifact_versions set status='UNDER_REVIEW' where id=v.id;
 insert into public.review_actions(submission_id,reviewer_user_id,action_type,note) values(s.id,auth.uid(),'STARTED_REVIEW',null);
 return to_jsonb(s);
end $$;
create function public.add_feedback(target_kind public.feedback_target_type,target_entity uuid,target_version uuid,kind public.feedback_type,body text) returns jsonb language plpgsql security definer set search_path='' as $$
declare ids uuid[];s public.submissions;a public.artifacts;f public.feedback_items;begin
 if public.current_platform_user_id() is null then
 if auth.uid() is null then raise exception 'Authentication required' using errcode='28000';end if;
 raise exception 'Access denied' using errcode='42501';end if;
 if target_kind is null or target_entity is null or kind is null or kind not in ('COMMENT','QUESTION','CORRECTION','SUGGESTION','WARNING') or body is null or length(regexp_replace(body,'^\s+|\s+$','','g'))=0 then raise exception 'Invalid feedback input' using errcode='22023';end if;
 select array_agg(s0.id order by s0.id) into ids from public.submissions s0
 join public.artifact_versions v on v.id=s0.artifact_version_id
 join public.artifacts a0 on a0.id=s0.artifact_id
 where s0.status='UNDER_REVIEW' and v.status='UNDER_REVIEW' and public.can_review_submission(s0.id) and a0.status='ACTIVE' and a0.archived_at is null
 and (target_version is null or s0.artifact_version_id=target_version)
 and ((target_kind='ARTIFACT' and s0.artifact_id=target_entity) or
 (target_kind='DEVELOPMENT_OBJECT' and exists(select 1 from public.artifact_object_links l join public.development_objects o on o.id=l.development_object_id
 where l.artifact_version_id=s0.artifact_version_id and l.artifact_id=s0.artifact_id and o.id=target_entity and o.project_id=a0.project_id and o.workspace_id=a0.workspace_id)));
 if coalesce(cardinality(ids),0)=0 then raise exception 'Access denied' using errcode='42501';end if;
 if cardinality(ids)<>1 then raise exception 'Specify exact review Version' using errcode='22023';end if;
 s:=public.lock_review_submission(ids[1]);
 select array_agg(s0.id order by s0.id) into ids from public.submissions s0
 join public.artifact_versions v on v.id=s0.artifact_version_id
 join public.artifacts a0 on a0.id=s0.artifact_id
 where s0.status='UNDER_REVIEW' and v.status='UNDER_REVIEW' and public.can_review_submission(s0.id) and a0.status='ACTIVE' and a0.archived_at is null
 and (target_version is null or s0.artifact_version_id=target_version)
 and ((target_kind='ARTIFACT' and s0.artifact_id=target_entity) or
 (target_kind='DEVELOPMENT_OBJECT' and exists(select 1 from public.artifact_object_links l join public.development_objects o on o.id=l.development_object_id
 where l.artifact_version_id=s0.artifact_version_id and l.artifact_id=s0.artifact_id and o.id=target_entity and o.project_id=a0.project_id and o.workspace_id=a0.workspace_id)));
 if coalesce(cardinality(ids),0)<>1 or ids[1]<>s.id then raise exception 'Specify exact review Version' using errcode='22023';end if;
 if s.status<>'UNDER_REVIEW' or not exists(select 1 from public.artifact_versions where id=s.artifact_version_id and status='UNDER_REVIEW') then raise exception 'Invalid review state' using errcode='22023';end if;
 select * into a from public.artifacts where id=s.artifact_id;
 if target_kind='DEVELOPMENT_OBJECT' then
 perform 1 from public.development_objects where id=target_entity for share;
 perform 1 from public.artifact_object_links where artifact_id=s.artifact_id and artifact_version_id=s.artifact_version_id and development_object_id=target_entity for share;
 if not found then raise exception 'Access denied' using errcode='42501';end if;
 end if;
 insert into public.feedback_items(submission_id,project_id,target_entity_type,target_entity_id,target_version_id,author_user_id,feedback_type,content)
 values(s.id,a.project_id,target_kind,target_entity,target_version,auth.uid(),kind,regexp_replace(body,'^\s+|\s+$','','g')) returning * into f;
 insert into public.review_actions(submission_id,reviewer_user_id,action_type,note) values(s.id,auth.uid(),'COMMENTED',null);
 return to_jsonb(f);
end $$;
alter table public.review_actions enable row level security;
alter table public.feedback_items enable row level security;
revoke all on public.review_actions,public.feedback_items from public,anon,authenticated,service_role;
grant select on public.review_actions,public.feedback_items to authenticated;
create policy review_actions_read on public.review_actions for select to authenticated using(exists(select 1 from public.submissions s where s.id=submission_id));
create policy review_actions_read_guard on public.review_actions as restrictive for select to authenticated using(exists(select 1 from public.submissions s where s.id=submission_id));
create policy feedback_items_read on public.feedback_items for select to authenticated using(exists(select 1 from public.submissions s where s.id=submission_id));
create policy feedback_items_read_guard on public.feedback_items as restrictive for select to authenticated using(exists(select 1 from public.submissions s where s.id=submission_id));
revoke all on function public.preserve_review_action(),public.preserve_feedback_history(),public.validate_feedback_target(),public.lock_review_submission(uuid),public.start_review(uuid),public.add_feedback(public.feedback_target_type,uuid,uuid,public.feedback_type,text) from public,anon,authenticated,service_role;
grant execute on function public.start_review(uuid),public.add_feedback(public.feedback_target_type,uuid,uuid,public.feedback_type,text) to authenticated;
comment on column public.feedback_items.submission_id is 'Approved M8.8 server-derived exact formal review context. Nullable Version targeting never implies newest review; ambiguous targets are rejected.';
comment on function public.lock_review_submission(uuid) is 'Private current-reviewer-only lock/recheck. No caller actor/scope override or general Personal access.';
commit;
