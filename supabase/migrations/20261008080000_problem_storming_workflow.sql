begin;
-- Existing caller-bound M7/M8 contribution locks provide canonical identity,
-- profile, enrollment, Project/Workspace/Team and temporal authorization.
-- Definer needed only for atomic writes to existing SELECT-only tables.
create function public.create_problem_storming_problem(target_instance uuid,problem_content text,category text,problem_perspective text default null)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare a public.activity_instances;o public.development_objects;d public.problem_details;
 input0 public.activity_inputs;artifact0 public.artifacts;version0 public.artifact_versions;
 concept_required boolean;concept_versions uuid[]:='{}';concept_metadata jsonb:='{}';
begin
 a:=public.lock_activity_artifact_contribution(target_instance);
 if not exists(select 1 from public.activity_definitions ad where ad.id=a.activity_definition_id and ad.method_type='problem_storming')
  or a.configuration_snapshot->>'method_type' is distinct from 'problem_storming' then raise exception 'Invalid Activity method' using errcode='22023';end if;
 if not exists(select 1 from public.workspaces w where w.id=a.workspace_id and w.workspace_type in('PERSONAL','TEAM')) then raise exception 'Resource unavailable' using errcode='42501';end if;
 if problem_content is null or category is null or category not in('user','functional','technical','cost','safety','environmental','accessibility','maintenance')
  or (problem_perspective is not null and length(btrim(problem_perspective))=0) then raise exception 'Invalid input' using errcode='22023';end if;
 -- Session identity is canonical curriculum metadata, never its display title.
 select exists(select 1 from public.activity_definitions ad join public.session_definitions s on s.id=ad.session_definition_id
  join public.curriculum_versions cv on cv.id=s.curriculum_version_id join public.programs p on p.id=cv.program_id
  where ad.id=a.activity_definition_id and p.program_type='professional_course' and s.session_number=4)
 or exists(select 1 from public.activity_dependencies dep where dep.activity_definition_id=a.activity_definition_id and dep.is_mandatory and dep.required_artifact_type='DEVELOPED_CONCEPT')
 into concept_required;
 -- No new configuration key. Resolve exact existing registered references and
 -- lock their canonical rows against archive/current-pointer changes.
 for input0 in select * from public.activity_inputs where activity_instance_id=a.id order by id for share loop
  if input0.artifact_id is null then continue;end if;
  select * into artifact0 from public.artifacts where id=input0.artifact_id for share;
  if artifact0.artifact_type<>'DEVELOPED_CONCEPT' then continue;end if;
  concept_required:=concept_required or input0.required;
  if artifact0.project_id<>a.project_id or artifact0.workspace_id<>a.workspace_id or not public.can_read_development_project(artifact0.project_id) then raise exception 'Resource unavailable' using errcode='42501';end if;
  select * into version0 from public.artifact_versions where id=coalesce(input0.artifact_version_id,artifact0.current_version_id) for share;
  if artifact0.status='ACTIVE' and artifact0.archived_at is null and version0.artifact_id=artifact0.id and version0.id=artifact0.current_version_id and version0.status='CURRENT' and version0.approved_by is not null and version0.approved_at is not null then
   if not version0.id=any(concept_versions) then
    concept_versions:=array_append(concept_versions,version0.id);
    concept_metadata:=jsonb_build_object('concept_input_id',input0.id,'concept_artifact_id',artifact0.id,'concept_artifact_version_id',version0.id);
   end if;
  end if;
 end loop;
 if cardinality(concept_versions)>1 then raise exception 'Activity input integrity conflict' using errcode='23505';end if;
 if concept_required and cardinality(concept_versions)<>1 then raise exception 'Required Activity input unavailable' using errcode='0A000';end if;
 -- Revalidate current contribution after any input/Artifact row lock wait.
 a:=public.lock_activity_artifact_contribution(target_instance);
 insert into public.development_objects(project_id,workspace_id,object_type,title,content,origin_type,origin_reference_id,created_by,metadata)
 values(a.project_id,a.workspace_id,'PROBLEM',case when length(btrim(problem_content))>0 then problem_content else 'Problem' end,problem_content,'PROBLEM_STORMING',a.id,public.current_platform_user_id(),concept_metadata) returning * into o;
 insert into public.problem_details(development_object_id,problem_category,perspective) values(o.id,category,problem_perspective) returning * into d;
 perform public.add_activity_output(a.id,o.id);
 perform public.append_project_change(o.project_id,'DEVELOPMENT_OBJECT',o.id,'OBJECT_CREATED','Problem Storming Activity '||a.id::text);
 return to_jsonb(o)||jsonb_build_object('problem_details',to_jsonb(d));
end $$;
revoke all on function public.create_problem_storming_problem(uuid,text,text,text) from public,anon,authenticated,service_role;
grant execute on function public.create_problem_storming_problem(uuid,text,text,text) to authenticated;
comment on function public.create_problem_storming_problem(uuid,text,text,text) is 'M9.10 one explicit call creates one canonical Problem/details/output/log. Current registered Developed Concept input required for Professional Session 4. No Problem Bank, solutions, ranking or content deduplication.';
commit;
