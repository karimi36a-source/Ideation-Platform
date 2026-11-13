begin;
create type public.artifact_version_status as enum ('DRAFT','SUBMITTED','UNDER_REVIEW','REVISION_REQUESTED','APPROVED','CURRENT','SUPERSEDED','ARCHIVED');
create table public.artifact_versions (
 id uuid primary key default gen_random_uuid(),
 artifact_id uuid not null references public.artifacts(id) on update restrict on delete restrict,
 version_number integer not null check(version_number>0),
 version_label text,
 content_snapshot jsonb not null,
 change_summary text,
 status public.artifact_version_status not null,
 created_by uuid not null references public.users(id) on delete restrict,
 created_at timestamptz not null default now(),
 previous_version_id uuid,
 approved_by uuid references public.users(id) on delete restrict,
 approved_at timestamptz,
 approval_note text,
 constraint artifact_versions_number_unique unique(artifact_id,version_number),
 constraint artifact_versions_id_artifact_unique unique(id,artifact_id),
 constraint artifact_versions_lineage foreign key(previous_version_id,artifact_id) references public.artifact_versions(id,artifact_id) on update restrict on delete restrict,
 constraint artifact_versions_not_self check(previous_version_id is null or previous_version_id<>id),
 constraint artifact_versions_approval_pair check((approved_by is null)=(approved_at is null)),
 constraint artifact_versions_approved_identity check(status not in ('APPROVED','CURRENT') or (approved_by is not null and approved_at is not null))
);
-- Existing number index also provides Artifact lookup; avoid a duplicate index.
create index artifact_versions_status_lookup on public.artifact_versions(status);
create index artifact_versions_previous_lookup on public.artifact_versions(previous_version_id) where previous_version_id is not null;
create index artifact_versions_creator_lookup on public.artifact_versions(created_by);
create index artifact_versions_approver_lookup on public.artifact_versions(approved_by) where approved_by is not null;
alter table public.artifacts add constraint artifacts_current_version_same_artifact foreign key(current_version_id,id) references public.artifact_versions(id,artifact_id) on update restrict on delete restrict;
-- Invoker preservation trigger, not an edit/approval/reopen business operation.
create function public.preserve_artifact_version_history() returns trigger language plpgsql set search_path='' as $$
begin
 if tg_op='DELETE' then raise exception 'Version history must be preserved' using errcode='23514';end if;
 if (new.id,new.artifact_id,new.version_number,new.previous_version_id,new.created_by,new.created_at)
  is distinct from (old.id,old.artifact_id,old.version_number,old.previous_version_id,old.created_by,old.created_at) then
  raise exception 'Version identity and lineage are immutable' using errcode='23514';end if;
 if old.status in ('APPROVED','CURRENT','SUPERSEDED','ARCHIVED') then
  if (new.content_snapshot,new.version_label,new.change_summary,new.approved_by,new.approved_at,new.approval_note)
   is distinct from (old.content_snapshot,old.version_label,old.change_summary,old.approved_by,old.approved_at,old.approval_note) then
   raise exception 'Historical Version snapshot is immutable' using errcode='23514';end if;
  -- A change to approved content requires a new Version, never unlocking old history.
  if new.status not in ('APPROVED','CURRENT','SUPERSEDED','ARCHIVED') then raise exception 'Historical Version cannot reopen' using errcode='23514';end if;
 end if;
 if old.status='ARCHIVED' and new is distinct from old then raise exception 'Archived Version history is immutable' using errcode='23514';end if;
 return new;
end $$;
revoke all on function public.preserve_artifact_version_history() from public,anon,authenticated,service_role;
create trigger artifact_versions_preserve_history before update or delete on public.artifact_versions for each row execute function public.preserve_artifact_version_history();
alter table public.artifact_versions enable row level security;
revoke all on public.artifact_versions from public,anon,authenticated,service_role;
grant select on public.artifact_versions to authenticated;
-- Invoker parent lookup composes Artifact RLS without another permission model.
create policy artifact_versions_parent_read on public.artifact_versions for select to authenticated using(exists(select 1 from public.artifacts a where a.id=artifact_versions.artifact_id));
create policy artifact_versions_read_guard on public.artifact_versions as restrictive for select to authenticated using(exists(select 1 from public.artifacts a where a.id=artifact_versions.artifact_id));
create policy artifact_versions_insert_deny on public.artifact_versions as restrictive for insert to authenticated with check(false);
create policy artifact_versions_update_deny on public.artifact_versions as restrictive for update to authenticated using(false) with check(false);
create policy artifact_versions_delete_deny on public.artifact_versions as restrictive for delete to authenticated using(false);
create policy artifact_versions_anon_deny on public.artifact_versions as restrictive for all to anon using(false) with check(false);
comment on table public.artifact_versions is 'M8.2 schema/security foundation. Identity and lineage preserved; approved/current and historical content protected. No public creation, Draft edit, approval or reopen operation.';
comment on column public.artifact_versions.version_number is 'Positive per-Artifact unique number. Trusted fixtures only now; monotonic server allocation belongs to M8.5.';
comment on column public.artifact_versions.content_snapshot is 'JSONB Version snapshot, never canonical Object authority. Explicit Object links belong to M8.3.';
comment on column public.artifact_versions.version_label is 'Nullable metadata; generation, uniqueness and editing policy deferred.';
comment on column public.artifact_versions.previous_version_id is 'Nullable same-Artifact lineage; self-reference denied. Arbitrary graph cycle policy deferred.';
comment on column public.artifacts.current_version_id is 'Nullable same-Artifact composite FK enforced in M8.2. No automatic pointer update; Draft eligibility and APPROVED/CURRENT transitions deferred to later controlled operations.';
commit;
