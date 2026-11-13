begin;
-- Narrow definer RPC writes protected tables. Uses caller auth, never a supplied
-- actor or service key; the shared M6 validator locks and rechecks write scope.
create function public.create_artifact(target_project uuid,target_workspace uuid,kind public.artifact_type,artifact_title text,target_activity uuid,needs_review boolean,needs_approval boolean) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid;a public.artifacts;v public.artifact_versions;i public.activity_instances;p public.development_projects;
begin
 perform public.require_development_object_write(target_project,target_workspace);
 actor:=public.current_platform_user_id();
 if kind is null or artifact_title is null or length(btrim(artifact_title))=0 or needs_review is null or needs_approval is null then raise exception 'Invalid Artifact input' using errcode='22023';end if;
 select * into p from public.development_projects where id=target_project;
 if p.status<>'active' or p.archived_at is not null then raise exception 'Access denied' using errcode='42501';end if;
 if target_activity is not null then
  select * into i from public.activity_instances where id=target_activity for share;
  if i.id is null or i.project_id is distinct from target_project or i.workspace_id is distinct from target_workspace or i.team_id is distinct from p.owner_team_id or i.status not in ('active','completed') then raise exception 'Access denied' using errcode='42501';end if;
  perform 1 from public.cohorts where id=i.cohort_id for share;
  perform 1 from public.project_program_links l join public.cohorts c on c.id=l.cohort_id where l.project_id=p.id and l.cohort_id=i.cohort_id and l.program_id=c.program_id and l.completed_at is null for share of l;
  if not found or not public.can_read_activity_instance(i.id) then raise exception 'Access denied' using errcode='42501';end if;
 end if;
 if public.current_platform_user_id() is distinct from actor then raise exception 'Access denied' using errcode='42501';end if;
 insert into public.artifacts(project_id,workspace_id,artifact_type,title,status,current_version_id,created_by,activity_instance_id,review_required,approval_required,archived_at)
 values(target_project,target_workspace,kind,btrim(artifact_title),'ACTIVE',null,actor,target_activity,needs_review,needs_approval,null) returning * into a;
 insert into public.artifact_versions(artifact_id,version_number,version_label,content_snapshot,change_summary,status,created_by,previous_version_id,approved_by,approved_at,approval_note)
 values(a.id,1,null,'{}',null,'DRAFT',actor,null,null,null,null) returning * into v;
 return jsonb_build_object('artifactId',a.id,'initialVersionId',v.id,'versionNumber',v.version_number,'versionStatus',v.status,'artifactStatus',a.status,'currentVersionId',a.current_version_id);
end $$;
revoke all on function public.create_artifact(uuid,uuid,public.artifact_type,text,uuid,boolean,boolean) from public,anon,authenticated,service_role;
grant execute on function public.create_artifact(uuid,uuid,public.artifact_type,text,uuid,boolean,boolean) to authenticated;
comment on function public.create_artifact(uuid,uuid,public.artifact_type,text,uuid,boolean,boolean) is 'M8.4 caller-bound atomic Artifact + empty V1 Draft. Active/completed provenance requires current canonical access. No current pointer, Object links, Activity output, approval or generic mutation workflow. Artifact audit event deferred until approved vocabulary.';
commit;
