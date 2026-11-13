begin;
alter table public.artifact_versions add column draft_revision integer not null default 0 check(draft_revision>=0);
create function public.preserve_draft_revision_history() returns trigger language plpgsql set search_path='' as $$
begin
 if new.draft_revision is distinct from old.draft_revision then
  if old.status<>'DRAFT' or new.status<>'DRAFT' or new.draft_revision::bigint<>old.draft_revision::bigint+1 then
   raise exception 'Draft revision is controlled history' using errcode='23514';
  end if;
 end if;
 return new;
end$$;
revoke all on function public.preserve_draft_revision_history() from public,anon,authenticated,service_role;
create trigger artifact_versions_draft_revision_history before update on public.artifact_versions for each row execute function public.preserve_draft_revision_history();
create function public.update_artifact_draft(target_version uuid,expected_revision integer,snapshot jsonb,summary text default null,set_summary boolean default false) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid;a public.artifacts;v public.artifact_versions;
begin
 actor:=public.current_platform_user_id();
 if actor is null then
  if auth.uid() is null then raise exception 'Authentication required' using errcode='28000';end if;
  raise exception 'Access denied' using errcode='42501';end if;
 select * into v from public.artifact_versions where id=target_version;
 select * into a from public.artifacts where id=v.artifact_id;
 if a.id is null then raise exception 'Access denied' using errcode='42501';end if;
 perform public.require_development_object_write(a.project_id,a.workspace_id);
 -- Preserve the existing shared scope -> Artifact -> Version lock order.
 select * into a from public.artifacts where id=a.id for update;
 if a.status<>'ACTIVE' or a.archived_at is not null or public.current_platform_user_id() is distinct from actor then raise exception 'Access denied' using errcode='42501';end if;
 if expected_revision is null or expected_revision<0 or snapshot is null or set_summary is null then raise exception 'Invalid Draft input' using errcode='22023';end if;
 -- The counter condition is part of the write, never an unconditional update
 -- following a preflight read. PostgreSQL integer arithmetic fails on overflow.
 update public.artifact_versions set content_snapshot=snapshot,
  change_summary=case when set_summary then btrim(summary) else change_summary end,
  draft_revision=draft_revision+1
 where id=target_version and artifact_id=a.id and status='DRAFT' and draft_revision=expected_revision
 returning * into v;
 if found then return to_jsonb(v);end if;
 select * into v from public.artifact_versions where id=target_version and artifact_id=a.id;
 if v.id is null then raise exception 'Access denied' using errcode='42501';end if;
 if v.status<>'DRAFT' then raise exception 'Version is not a writable Draft' using errcode='55000';end if;
 raise exception 'Stale Draft' using errcode='23505';
end$$;
revoke all on function public.update_artifact_draft(uuid,integer,jsonb,text,boolean) from public,anon,authenticated,service_role;
grant execute on function public.update_artifact_draft(uuid,integer,jsonb,text,boolean) to authenticated;
comment on column public.artifact_versions.draft_revision is 'M8.20 server-controlled CAS save counter, independent of version_number. New Versions default 0; non-Draft history preserves the final counter.';
comment on function public.update_artifact_draft(uuid,integer,jsonb,text,boolean) is 'Caller-bound existing Version edit scope; ACTIVE Artifact + DRAFT + expected counter required. Only snapshot/summary/counter change. No automatic retry, merge, audit, baseline or Activity side effects.';
commit;
