begin;
-- A review cycle belongs permanently to one submitted Version.
create unique index submissions_one_cycle_per_version on public.submissions(artifact_version_id);
create function public.preserve_submission_context() returns trigger language plpgsql set search_path='' as $$
begin
 if (new.id,new.activity_instance_id,new.artifact_id,new.artifact_version_id,new.submitted_by,new.submitted_at,new.reviewer_user_id)
 is distinct from (old.id,old.activity_instance_id,old.artifact_id,old.artifact_version_id,old.submitted_by,old.submitted_at,old.reviewer_user_id)
 then raise exception 'Submission context is immutable' using errcode='23514';end if;
 return new;
end $$;
create trigger submissions_preserve_context before update on public.submissions for each row execute function public.preserve_submission_context();
-- Lineage itself identifies resubmission. No duplicate lifecycle/marker fields.
-- Applies inside the existing submit RPC, so a failure rolls back its Version update.
create function public.validate_resubmission_context() returns trigger language plpgsql set search_path='' as $$
declare previous_id uuid;source public.submissions;begin
 select previous_version_id into previous_id from public.artifact_versions where id=new.artifact_version_id;
 select * into source from public.submissions where artifact_version_id=previous_id and status='REVISION_REQUESTED' for share;
 if found and (new.activity_instance_id is distinct from source.activity_instance_id or new.artifact_id is distinct from source.artifact_id
 or not exists(select 1 from public.artifact_versions where id=previous_id and status='REVISION_REQUESTED'))
 then raise exception 'Invalid revision context' using errcode='22023';end if;
 return new;
end $$;
create trigger submissions_revision_context before insert on public.submissions for each row execute function public.validate_resubmission_context();
revoke all on function public.preserve_submission_context(),public.validate_resubmission_context() from public,anon,authenticated,service_role;

create function public.create_revision_draft(target_submission uuid,snapshot jsonb,summary text) returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid;s public.submissions;a public.artifacts;v public.artifact_versions;result jsonb;begin
 actor:=public.current_platform_user_id();
 if actor is null then
 if auth.uid() is null then raise exception 'Authentication required' using errcode='28000';end if;
 raise exception 'Access denied' using errcode='42501';end if;
 select * into s from public.submissions where id=target_submission;
 select * into a from public.artifacts where id=s.artifact_id;
 if a.id is null then raise exception 'Access denied' using errcode='42501';end if;
 -- Keep the established scope -> Artifact -> Version -> Submission lock order.
 -- Authorization is current edit scope, never historical submitter/reviewer status.
 perform public.require_development_object_write(a.project_id,a.workspace_id);
 select * into a from public.artifacts where id=a.id for update;
 select * into v from public.artifact_versions where id=s.artifact_version_id for update;
 select * into s from public.submissions where id=target_submission for update;
 if a.status<>'ACTIVE' or a.archived_at is not null or actor is distinct from public.current_platform_user_id() then raise exception 'Access denied' using errcode='42501';end if;
 if s.status<>'REVISION_REQUESTED' or v.status<>'REVISION_REQUESTED' or v.artifact_id<>a.id or s.artifact_version_id<>v.id
 or snapshot is null then raise exception 'Invalid revision source' using errcode='22023';end if;
 -- Artifact lock serializes against generic Version creation too. No retry key:
 -- every repeated/conflicting formal request fails rather than guessing intent.
 if v.id is distinct from (select id from public.artifact_versions where artifact_id=a.id order by version_number desc limit 1)
 then raise exception 'Revision source is no longer latest' using errcode='22023';end if;
 result:=public.create_artifact_version(a.id,snapshot,summary);
 if (result->>'previous_version_id')::uuid is distinct from v.id then raise exception 'Invalid revision lineage' using errcode='22023';end if;
 return result;
end $$;
revoke all on function public.create_revision_draft(uuid,jsonb,text) from public,anon,authenticated,service_role;
grant execute on function public.create_revision_draft(uuid,jsonb,text) to authenticated;
comment on function public.create_revision_draft(uuid,jsonb,text) is 'M8.10 exact latest REVISION_REQUESTED Submission/Version source. Reuses M8.5 creation under the Artifact lock; conflicting retries fail. No implicit link copy or new authorization.';
commit;
