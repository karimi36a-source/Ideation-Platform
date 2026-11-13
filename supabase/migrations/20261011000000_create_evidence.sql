begin;
create type public.evidence_type as enum (
 'PATENT','PATENT_CLAIM','STANDARD','DATASHEET','PAPER','CALCULATION',
 'MEASUREMENT','TEST_RESULT','CUSTOMER_INTERVIEW','MARKET_SOURCE','SECONDARY_SOURCE','OTHER'
);
create type public.evidence_verification_status as enum (
 'UNVERIFIED','PARTIALLY_VERIFIED','VERIFIED','CONTRADICTED','NEEDS_REVIEW'
);
create table public.evidence (
 id uuid primary key default gen_random_uuid(),
 project_id uuid not null,
 workspace_id uuid not null references public.workspaces(id) on update restrict on delete restrict,
 evidence_type public.evidence_type not null,
 title text not null check(length(btrim(title))>0),
 description text not null check(length(btrim(description))>0),
 source_name text not null check(length(btrim(source_name))>0),
 source_url text check(source_url is null or source_url ~* '^https?://[^/[:space:]?#]+([/?#][^[:space:]]*)?$'),
 file_id uuid,
 verification_status public.evidence_verification_status not null default 'UNVERIFIED',
 verified_by uuid references public.users(id) on update restrict on delete restrict,
 verified_at timestamptz,
 created_by uuid not null default public.current_platform_user_id() references public.users(id) on update restrict on delete restrict,
 captured_at timestamptz not null default now(),
 metadata jsonb not null default '{}' check(jsonb_typeof(metadata)='object'),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 updated_by uuid not null default public.current_platform_user_id() references public.users(id) on update restrict on delete restrict,
 archived_at timestamptz,
 constraint evidence_project_workspace foreign key(project_id,workspace_id)
  references public.development_projects(id,primary_workspace_id) on update restrict on delete restrict,
 constraint evidence_unverified_fields check(verification_status<>'UNVERIFIED' or (verified_by is null and verified_at is null)),
 constraint evidence_update_time check(updated_at>=created_at),
 constraint evidence_archive_time check(archived_at is null or archived_at>=captured_at)
);
comment on column public.evidence.file_id is 'Deferred canonical Files FK: Files does not exist in M12.1. No file access, upload, or arbitrary reference authorization is provided here.';
comment on column public.evidence.verification_status is 'Confidence/review state only; not approval, scientific certainty, or a patentability conclusion. Verification operations/authority are deferred.';
comment on column public.evidence.captured_at is 'Project capture/recording time, independent of any later verification timestamp.';
comment on column public.evidence.archived_at is 'Archive marker preserving identity/history. No restore operation in M12.1.';

-- Scope/filter and provenance/FK lookups. No speculative JSON or file indexes.
create index evidence_project_lookup on public.evidence(project_id);
create index evidence_workspace_lookup on public.evidence(workspace_id);
create index evidence_creator_lookup on public.evidence(created_by);
create index evidence_type_lookup on public.evidence(evidence_type);
create index evidence_verification_lookup on public.evidence(verification_status);

-- Invoker integrity guard, not a creation/verification API. A later trusted
-- operation must still authorize its exact write capability before inserting.
create function private.preserve_evidence_history() returns trigger
language plpgsql set search_path='' as $$
declare actor uuid;
begin
 if tg_op='DELETE' then raise exception 'Evidence history is preserved' using errcode='55000';end if;
 actor:=public.current_platform_user_id();
 if actor is null then raise exception 'Authentication required' using errcode='28000';end if;
 if tg_op='INSERT' then
  if new.created_by is distinct from actor or new.updated_by is distinct from actor then
   raise exception 'Creator must match authenticated actor' using errcode='42501';
  end if;
  if new.verification_status<>'UNVERIFIED' or new.verified_by is not null or new.verified_at is not null then
   raise exception 'New Evidence must be unverified' using errcode='42501';
  end if;
 else
  if (new.id,new.project_id,new.workspace_id,new.created_by,new.captured_at,new.created_at)
   is distinct from (old.id,old.project_id,old.workspace_id,old.created_by,old.captured_at,old.created_at) then
   raise exception 'Evidence identity and capture history are immutable' using errcode='23514';
  end if;
  if old.archived_at is not null then
   if new is distinct from old then raise exception 'Archived Evidence is immutable' using errcode='55000';end if;
   return old;
  end if;
  new.updated_by:=actor;
  new.updated_at:=statement_timestamp();
 end if;
 return new;
end $$;
revoke all on function private.preserve_evidence_history() from public,anon,authenticated,service_role;
create trigger evidence_history_guard before insert or update or delete on public.evidence
 for each row execute function private.preserve_evidence_history();

alter table public.evidence enable row level security;
revoke all on public.evidence from public,anon,authenticated,service_role;
grant select on public.evidence to authenticated;
-- This authoritative helper already checks the compatible Workspace, current
-- Team + explicit Project participation, Personal owner, or Case Study owner.
-- Neither provenance nor a public source URL grants content access.
create policy evidence_scoped_read on public.evidence for select to authenticated
 using(public.can_read_development_project(project_id));
create policy evidence_no_client_insert on public.evidence as restrictive for insert to authenticated with check(false);
create policy evidence_no_client_update on public.evidence as restrictive for update to authenticated using(false) with check(false);
create policy evidence_no_client_delete on public.evidence as restrictive for delete to authenticated using(false);
comment on table public.evidence is 'M12.1 source-backed schema. Client reads inherit canonical Project privacy; all client writes denied. No creation, verification, sharing, or Files workflow.';
commit;
