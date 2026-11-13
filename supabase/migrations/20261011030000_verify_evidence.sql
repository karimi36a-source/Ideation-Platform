begin;
create table public.evidence_verification_history (
 id uuid primary key default gen_random_uuid(),
 evidence_id uuid not null references public.evidence(id) on update restrict on delete restrict,
 previous_status public.evidence_verification_status not null,
 new_status public.evidence_verification_status not null,
 verified_by uuid not null references public.users(id) on update restrict on delete restrict,
 verified_at timestamptz not null,
 note text check(note is null or length(private.trim_decision_text(note))>0),
 constraint evidence_verification_transition check(previous_status<>new_status)
);
create index evidence_verification_history_source_time on public.evidence_verification_history(evidence_id,verified_at,id);
comment on table public.evidence_verification_history is 'M12.4 immutable explicit confidence-state transitions, not legal/scientific conclusions. Creation and same-status retries create no event. UNVERIFIED events retain actor/time independently of the current-row NULL fields.';

create function private.preserve_evidence_verification() returns trigger language plpgsql set search_path='' as $$
declare e public.evidence;actor uuid:=public.current_platform_user_id();
begin
 if tg_op<>'INSERT' then raise exception 'Verification history is immutable' using errcode='55000';end if;
 select * into e from public.evidence where id=new.evidence_id;
 if actor is null or new.verified_by is distinct from actor or e.id is null or e.archived_at is not null or e.verification_status is distinct from new.new_status
 or (new.new_status='UNVERIFIED' and (e.verified_by is not null or e.verified_at is not null))
 or (new.new_status<>'UNVERIFIED' and (e.verified_by is distinct from actor or e.verified_at is distinct from new.verified_at))
 then raise exception 'Invalid verification history context' using errcode='23514';end if;
 return new;
end $$;
revoke all on function private.preserve_evidence_verification() from public,anon,authenticated,service_role;
create trigger evidence_verification_history_guard before insert or update or delete on public.evidence_verification_history for each row execute function private.preserve_evidence_verification();
alter table public.evidence_verification_history enable row level security;
revoke all on public.evidence_verification_history from public,anon,authenticated,service_role;
grant select on public.evidence_verification_history to authenticated;
create policy evidence_verification_read on public.evidence_verification_history for select to authenticated using(
 exists(select 1 from public.evidence e where e.id=evidence_id));
create policy evidence_verification_no_insert on public.evidence_verification_history as restrictive for insert to authenticated with check(false);
create policy evidence_verification_no_update on public.evidence_verification_history as restrictive for update to authenticated using(false) with check(false);
create policy evidence_verification_no_delete on public.evidence_verification_history as restrictive for delete to authenticated using(false);

create function public.verify_evidence(target_evidence uuid,target_status public.evidence_verification_status,verification_note text default null)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare actor uuid:=public.current_platform_user_id();observed jsonb;e public.evidence;w public.workspaces;
 prior public.evidence_verification_status;event_time timestamptz;normalized_note text:=private.trim_decision_text(verification_note);history_count bigint;
begin
 if actor is null then
  if auth.uid() is null then raise exception 'Authentication required' using errcode='28000';end if;
  raise exception 'Resource unavailable' using errcode='42501';end if;
 if target_evidence is null or target_status is null or (verification_note is not null and length(normalized_note)=0)
 then raise exception 'Invalid verification input' using errcode='22023';end if;
 -- One snapshot captures the row AND immutable history count. A transition
 -- away and back to UNVERIFIED cannot conceal a concurrent change (ABA).
 select jsonb_build_object('row',to_jsonb(s),'historyCount',(select count(*) from public.evidence_verification_history h where h.evidence_id=s.id))
 into observed from public.evidence s where s.id=target_evidence;
 if observed is null or not public.can_read_development_project((observed#>>'{row,project_id}')::uuid)
 then raise exception 'Resource unavailable' using errcode='42501';end if;
 perform public.require_development_object_write((observed#>>'{row,project_id}')::uuid,(observed#>>'{row,workspace_id}')::uuid);
 select * into e from public.evidence where id=target_evidence;
 if e.id is null or e.archived_at is not null then raise exception 'Resource unavailable' using errcode='42501';end if;
 select * into w from public.workspaces where id=e.workspace_id;
 if w.workspace_type='TEAM' then
  if not exists(select 1 from public.development_projects p join public.teams t on t.id=p.owner_team_id
   join public.team_memberships m on m.team_id=t.id and m.user_id=actor
   where p.id=e.project_id and p.project_type='team' and p.primary_workspace_id=w.id and w.team_id=t.id
   and t.workspace_id=w.id and t.cohort_id=w.cohort_id and t.team_lead_user_id=actor
   and m.status='active' and m.membership_role='team_lead' and m.left_at is null and m.joined_at<=clock_timestamp())
  then raise exception 'Resource unavailable' using errcode='42501';end if;
 elsif w.workspace_type='PERSONAL' then
  if w.owner_user_id is distinct from actor then raise exception 'Resource unavailable' using errcode='42501';end if;
 else raise exception 'Resource unavailable' using errcode='42501';end if;
 -- Unauthorized callers never acquire the verification lock or receive its
 -- conflict signal. The shared canonical Team/ownership locks stay held.
 begin
  select * into e from public.evidence where id=target_evidence for update nowait;
 exception when lock_not_available then raise exception 'Verification conflict' using errcode='40001';end;
 if e.id is null or e.archived_at is not null then raise exception 'Resource unavailable' using errcode='42501';end if;
 select count(*) into history_count from public.evidence_verification_history where evidence_id=e.id;
 if to_jsonb(e) is distinct from observed->'row' or history_count<>(observed->>'historyCount')::bigint
 then raise exception 'Verification conflict' using errcode='40001';end if;
 -- Authorization precedes the no-op: stale Leads cannot exploit idempotency.
 if e.verification_status=target_status then return to_jsonb(e);end if;
 prior:=e.verification_status;event_time:=clock_timestamp();
 update public.evidence set verification_status=target_status,
 verified_by=case when target_status='UNVERIFIED' then null else actor end,
 verified_at=case when target_status='UNVERIFIED' then null else event_time end
 where id=e.id returning * into e;
 insert into public.evidence_verification_history(evidence_id,previous_status,new_status,verified_by,verified_at,note)
 values(e.id,prior,target_status,actor,event_time,normalized_note);
 if public.current_platform_user_id() is distinct from actor then raise exception 'Resource unavailable' using errcode='42501';end if;
 return to_jsonb(e);
end $$;
revoke all on function public.verify_evidence(uuid,public.evidence_verification_status,text) from public,anon,authenticated,service_role;
grant execute on function public.verify_evidence(uuid,public.evidence_verification_status,text) to authenticated;
comment on function public.verify_evidence(uuid,public.evidence_verification_status,text) is 'Current Team Lead or Personal owner only. Explicit conflict on overlapping/stale observations, atomic state plus immutable history. Same-status requests are authorized no-ops (including notes). No source, link, downstream workflow, sharing or verification-authority expansion.';
commit;
