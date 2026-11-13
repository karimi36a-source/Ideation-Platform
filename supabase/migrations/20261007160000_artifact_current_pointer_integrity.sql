begin;
-- Validate existing data without rewriting immutable history or choosing a winner.
do $$begin
 if exists(select 1 from public.artifacts a left join public.artifact_versions v
  on v.id=a.current_version_id and v.artifact_id=a.id
  where a.current_version_id is not null and (v.id is null or v.status<>'CURRENT')) then
  raise exception 'Invalid Artifact current Version state' using errcode='23514';
 end if;
end $$;

-- Deferred because approval supersedes the old Version, promotes the new one,
-- then updates the pointer in one transaction. Check final state, not intermediate
-- trigger NEW records. SECURITY DEFINER is required to validate hidden rows under
-- caller RLS; no caller identity/ownership input or public execution is accepted.
create function public.enforce_artifact_current_pointer() returns trigger
language plpgsql security definer set search_path='' as $$
declare target_id uuid; pointer_id uuid;
begin
 if tg_table_name='artifacts' then target_id:=new.id;
 else target_id:=new.artifact_id; end if;
 select a.current_version_id into pointer_id from public.artifacts a
  where a.id=target_id for update;
 if pointer_id is not null and not exists(select 1 from public.artifact_versions v
  where v.id=pointer_id and v.artifact_id=target_id and v.status='CURRENT') then
  raise exception 'Invalid Artifact current Version state' using errcode='23514';
 end if;
 return null;
end $$;
revoke all on function public.enforce_artifact_current_pointer() from public,anon,authenticated,service_role;
create constraint trigger artifacts_current_pointer_integrity
 after insert or update of current_version_id on public.artifacts
 deferrable initially deferred for each row
 execute function public.enforce_artifact_current_pointer();
create constraint trigger artifact_versions_current_pointer_integrity
 after update of status on public.artifact_versions
 deferrable initially deferred for each row
 execute function public.enforce_artifact_current_pointer();
comment on function public.enforce_artifact_current_pointer() is
 'Private deferred final-state invariant: a nonnull Artifact pointer references its own CURRENT Version. Does not select latest Draft or confer content access.';
commit;
