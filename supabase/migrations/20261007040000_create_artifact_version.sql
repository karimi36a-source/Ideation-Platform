begin;
-- Definer needed only for protected Version insertion. Caller identity and
-- current write scope remain canonical; parent row serializes numbering.
create function public.create_artifact_version(target_artifact uuid,snapshot jsonb,summary text,decision_ids uuid[] default '{}',evidence_ids uuid[] default '{}',ai_output_ids uuid[] default '{}') returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid;a public.artifacts;prior public.artifact_versions;v public.artifact_versions;next_number bigint;
begin
 actor:=public.current_platform_user_id();
 if actor is null then
  if auth.uid() is null then raise exception 'Authentication required' using errcode='28000';end if;
  raise exception 'Access denied' using errcode='42501';end if;
 select * into a from public.artifacts where id=target_artifact;
 if a.id is null then raise exception 'Access denied' using errcode='42501';end if;
 perform public.require_development_object_write(a.project_id,a.workspace_id);
 select * into a from public.artifacts where id=target_artifact for update;
 if a.id is null or a.status<>'ACTIVE' or a.archived_at is not null or public.current_platform_user_id() is distinct from actor then raise exception 'Access denied' using errcode='42501';end if;
 if snapshot is null or decision_ids is null or evidence_ids is null or ai_output_ids is null then raise exception 'Invalid Version input' using errcode='22023';end if;
 if cardinality(decision_ids)>0 or cardinality(evidence_ids)>0 or cardinality(ai_output_ids)>0 then raise exception 'Source references deferred until canonical integrations exist' using errcode='22023';end if;
 select * into prior from public.artifact_versions where artifact_id=a.id order by version_number desc limit 1;
 next_number:=coalesce(prior.version_number::bigint,0)+1;
 if next_number>2147483647 then raise exception 'Version number capacity exhausted' using errcode='22023';end if;
 insert into public.artifact_versions(artifact_id,version_number,version_label,content_snapshot,change_summary,status,created_by,previous_version_id,approved_by,approved_at,approval_note)
 values(a.id,next_number::integer,null,snapshot,summary,'DRAFT',actor,prior.id,null,null,null) returning * into v;
 return to_jsonb(v);
end $$;
revoke all on function public.create_artifact_version(uuid,jsonb,text,uuid[],uuid[],uuid[]) from public,anon,authenticated,service_role;
grant execute on function public.create_artifact_version(uuid,jsonb,text,uuid[],uuid[],uuid[]) to authenticated;
comment on function public.create_artifact_version(uuid,jsonb,text,uuid[],uuid[],uuid[]) is 'M8.5 append-only Draft creation, Artifact row lock + unique number constraint, latest predecessor, caller-bound shared write validator. No Artifact/pointer/predecessor/Object/link/Activity mutation. Future source references fail closed.';
commit;
