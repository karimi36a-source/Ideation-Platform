begin;
-- Additional read restriction only. Existing Project/Workspace authorization
-- remains mandatory; this boolean is never a source or output capability.
create function public.can_read_brainstorm_derived_ai_output(target_output uuid) returns boolean
language plpgsql stable security definer set search_path='' as $$
declare o record;actor uuid:=public.current_platform_user_id();begin
 if actor is null then return false;end if;
 select id,project_id,workspace_id,activity_instance_id,requested_by into o from public.ai_outputs where id=target_output;
 if o.id is null or not public.can_read_development_project(o.project_id) then return false;end if;
 if not exists(select 1 from public.workspaces w where w.id=o.workspace_id and w.workspace_type='TEAM') then return true;end if;
 if o.requested_by=actor then return true;end if;
 -- Exact indexed provenance lookup; never enumerate source Workspace content.
 -- A missing/incompatible source fails closed rather than publishing history.
 return not exists(
  select 1 from public.ai_context_references r
  left join public.brainstorm_entries b on b.id=r.entity_id
  where r.ai_output_id=o.id and r.entity_type='BRAINSTORM_ENTRY'
  and (b.id is null or b.revealed_at is null
   or (b.activity_instance_id,b.project_id,b.workspace_id) is distinct from (o.activity_instance_id,o.project_id,o.workspace_id))
 );
end$$;
revoke all on function public.can_read_brainstorm_derived_ai_output(uuid) from public,anon,authenticated,service_role;
grant execute on function public.can_read_brainstorm_derived_ai_output(uuid) to authenticated;
create policy ai_outputs_brainstorm_read_guard on public.ai_outputs as restrictive for select to authenticated
 using(public.can_read_brainstorm_derived_ai_output(id));
-- ai_context_references_parent_read already checks its parent through RLS.
-- Therefore output and provenance share the same dynamic protection, without
-- recursive policies, a second visibility flag, or historical-row rewrites.
comment on function public.can_read_brainstorm_derived_ai_output(uuid) is 'M14.19 boolean-only read restriction: Team outputs with any unrevealed Brainstorm source remain requester-only under existing current scope authority. Canonical reveal alone restores normal reads.';
-- Security-definer business RPCs must enforce the same narrow read rule.
create or replace function public.set_ai_output_disposition(target_output uuid,target_disposition public.ai_output_disposition,expected_revision bigint) returns jsonb
language plpgsql security definer set search_path='' as $$
declare o public.ai_outputs; actor uuid:=public.current_platform_user_id();
begin
 if actor is null then raise exception 'Resource unavailable' using errcode='42501';end if;
 select * into o from public.ai_outputs where id=target_output;
 if not public.can_read_brainstorm_derived_ai_output(o.id) then raise exception 'Resource unavailable' using errcode='42501';end if;
 if not found or not public.can_read_development_project(o.project_id) or not exists(select 1 from public.development_projects p where p.id=o.project_id and p.primary_workspace_id=o.workspace_id) then raise exception 'Resource unavailable' using errcode='42501';end if;
 if target_disposition is null or target_disposition='CONVERTED_TO_PROJECT_OBJECT' or expected_revision is null or expected_revision<0 then raise exception 'Invalid disposition' using errcode='22023';end if;
 select * into o from public.ai_outputs where id=target_output for update;
 if not public.can_read_development_project(o.project_id) then raise exception 'Resource unavailable' using errcode='42501';end if;
 if o.disposition='CONVERTED_TO_PROJECT_OBJECT' then raise exception 'Conversion is reserved' using errcode='22023';end if;
 if o.disposition=target_disposition then return to_jsonb(o);end if;
 if o.disposition_revision<>expected_revision then raise exception 'Disposition conflict' using errcode='40001';end if;
 update public.ai_outputs set disposition=target_disposition,disposition_revision=disposition_revision+1 where id=o.id returning * into o;
 return to_jsonb(o);
end$$;


create or replace function public.convert_ai_output_to_candidate(input jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid;s public.ai_outputs;o public.development_objects;kind0 public.development_object_type;fingerprint text;audit0 public.change_log;
begin
 if input is null or jsonb_typeof(input)<>'object' or (select count(*) from jsonb_object_keys(input))<>7
 or exists(select 1 from jsonb_object_keys(input) k where k not in ('actorId','aiOutputId','targetObjectType','candidateTitle','candidateContent','confirmed','sourceResponseHash'))
 or input->'confirmed' is distinct from 'true'::jsonb
 or jsonb_typeof(input->'candidateTitle') is distinct from 'string' or length(btrim(input->>'candidateTitle'))=0 or length(input->>'candidateTitle')>1000000
 or jsonb_typeof(input->'candidateContent') is distinct from 'string' or length(input->>'candidateContent')>1000000
 or (input->>'sourceResponseHash') is null or (input->>'sourceResponseHash')!~'^[a-f0-9]{64}$'
 then raise exception 'Invalid conversion' using errcode='22023';end if;
 actor:=(input->>'actorId')::uuid;perform private.ai_task_actor(actor);
 if actor is null or public.current_platform_user_id() is distinct from actor then raise exception 'Resource unavailable' using errcode='42501';end if;
 select * into s from public.ai_outputs where id=(input->>'aiOutputId')::uuid;
 if not public.can_read_brainstorm_derived_ai_output(s.id) then raise exception 'Resource unavailable' using errcode='42501';end if;
 if not found or not public.can_read_development_project(s.project_id) then raise exception 'Resource unavailable' using errcode='42501';end if;
 perform public.require_development_object_write(s.project_id,s.workspace_id);
 select * into s from public.ai_outputs where id=s.id for update;
 perform public.require_development_object_write(s.project_id,s.workspace_id);
 if not public.can_read_development_project(s.project_id) then raise exception 'Resource unavailable' using errcode='42501';end if;
 if not exists(select 1 from public.ai_task_operations t where t.output_id=s.id and t.status='completed' and t.requested_by=s.requested_by and t.project_id=s.project_id and t.workspace_id=s.workspace_id and t.activity_instance_id=s.activity_instance_id and t.task_type=s.task_type and t.ai_role=s.ai_role)
 or encode(sha256(convert_to(s.response_text,'UTF8')),'hex') is distinct from input->>'sourceResponseHash'
 or jsonb_typeof(s.response_text::jsonb)<>'object' then raise exception 'Invalid saved AI Output' using errcode='22000';end if;
 kind0:=(input->>'targetObjectType')::public.development_object_type;
 if not private.ai_conversion_pair(s.task_type,kind0) then if s.disposition='CONVERTED_TO_PROJECT_OBJECT' then raise exception 'Conversion conflict' using errcode='23505';end if;raise exception 'Target type not allowed' using errcode='22023';end if;
 fingerprint:=encode(sha256(convert_to(jsonb_build_object('source',s.id,'type',kind0,'title',input->>'candidateTitle','content',input->>'candidateContent')::text,'UTF8')),'hex');
 if s.disposition='CONVERTED_TO_PROJECT_OBJECT' then
  select * into o from public.development_objects where origin_type='AI' and origin_reference_id=s.id for share;
  select * into audit0 from public.change_log where entity_type='DEVELOPMENT_OBJECT' and change_type='OBJECT_CREATED' and related_ai_output_id=s.id;
  if o.id is null or audit0.id is null or audit0.entity_id<>o.id or o.project_id<>s.project_id or o.workspace_id<>s.workspace_id or o.object_type<>kind0 or (audit0.reason::jsonb->>'request_hash') is distinct from fingerprint then raise exception 'Conversion conflict' using errcode='23505';end if;
  return to_jsonb(o);
 end if;
 if s.disposition<>'ACCEPT_AS_CANDIDATE' then raise exception 'Human review required' using errcode='55000';end if;
 insert into public.development_objects(project_id,workspace_id,object_type,title,content,origin_type,origin_reference_id,created_by)
 values(s.project_id,s.workspace_id,kind0,input->>'candidateTitle',input->>'candidateContent','AI',s.id,actor) returning * into o;
 if kind0='IDEA' then perform public.write_idea_details(o.id,'{"acceptance_state":"candidate"}',true);end if;
 insert into public.change_log(project_id,entity_type,entity_id,change_type,change_summary,reason,changed_by,related_ai_output_id,created_at)
 values(s.project_id,'DEVELOPMENT_OBJECT',o.id,'OBJECT_CREATED','Human-confirmed AI candidate created',jsonb_build_object('request_hash',fingerprint,'ai_output_id',s.id,'original_requested_by',s.requested_by,'ai_role',s.ai_role,'task_type',s.task_type,'output_type',s.output_type,'human_confirmed_by',actor,'workspace_id',s.workspace_id)::text,actor,s.id,clock_timestamp());
 update public.ai_outputs set disposition='CONVERTED_TO_PROJECT_OBJECT',disposition_revision=disposition_revision+1 where id=s.id;
 return to_jsonb(o);
end$$;


create or replace function public.apply_ai_artifact_revision(input jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid;s public.ai_outputs;a public.artifacts;head public.artifact_versions;draft public.artifact_versions;current0 public.artifact_versions;prior public.audit_events;fingerprint text;made jsonb;
begin
 if input is null or jsonb_typeof(input)<>'object' or (select count(*) from jsonb_object_keys(input))<>10
 or exists(select 1 from jsonb_object_keys(input) k where k not in ('actorId','aiOutputId','artifactId','expectedVersionId','expectedDraftRevision','contentSnapshot','changeSummary','confirmed','idempotencyKey','sourceResponseHash'))
 or input->'confirmed' is distinct from 'true'::jsonb or not(input?'contentSnapshot') or octet_length(input::text)>4000000
 or (input->>'sourceResponseHash') is null or (input->>'sourceResponseHash')!~'^[a-f0-9]{64}$'
 or jsonb_typeof(input->'changeSummary') not in ('string','null') then raise exception 'Invalid revision' using errcode='22023';end if;
 actor:=(input->>'actorId')::uuid;perform private.ai_task_actor(actor);
 select * into s from public.ai_outputs where id=(input->>'aiOutputId')::uuid;
 if not public.can_read_brainstorm_derived_ai_output(s.id) then raise exception 'Resource unavailable' using errcode='42501';end if;
 select * into a from public.artifacts where id=(input->>'artifactId')::uuid;
 if actor is null or s.id is null or a.id is null or not public.can_read_development_project(s.project_id) or (a.project_id,a.workspace_id) is distinct from (s.project_id,s.workspace_id) then raise exception 'Resource unavailable' using errcode='42501';end if;
 perform public.require_development_object_write(a.project_id,a.workspace_id);
 select * into a from public.artifacts where id=a.id for update;
 perform public.require_development_object_write(a.project_id,a.workspace_id);
 if not public.can_read_development_project(s.project_id) or a.status<>'ACTIVE' or a.archived_at is not null then raise exception 'Resource unavailable' using errcode='42501';end if;
 -- Existing composition contracts own these subtypes; never patch their JSON.
 if a.artifact_type in ('MIND_MAP','INVENTION_STRUCTURE','GAP_LIST','MINIMUM_ESSENTIAL_STRUCTURE','INVENTION_CONCEPT','PROBLEM_BANK','SOLUTION_BANK','TEAM_DECISION_RECORD','PATENT_READING_FRAMEWORK') then raise exception 'Specialized revision required' using errcode='0A000';end if;
 if not exists(select 1 from public.ai_task_operations t where t.output_id=s.id and t.status='completed' and t.project_id=s.project_id and t.workspace_id=s.workspace_id and t.requested_by=s.requested_by and t.activity_instance_id=s.activity_instance_id and t.task_type=s.task_type and t.ai_role=s.ai_role)
 or encode(sha256(convert_to(s.response_text,'UTF8')),'hex') is distinct from input->>'sourceResponseHash' or jsonb_typeof(s.response_text::jsonb)<>'object' then raise exception 'Invalid AI Output' using errcode='22000';end if;
 -- The existing Artifact lock serializes same-target retries; the audit unique
 -- index rejects a key reused concurrently against a different target.
 fingerprint:=encode(sha256(convert_to((input-'actorId'-'idempotencyKey'-'sourceResponseHash')::text,'UTF8')),'hex');
 select * into prior from public.audit_events where event_type='AI_ARTIFACT_DRAFT_APPLIED' and actor_user_id=actor and metadata->>'idempotencyKey'=input->>'idempotencyKey';
 if found then
  if prior.entity_id<>a.id or prior.metadata->>'requestHash' is distinct from fingerprint then raise exception 'Revision conflict' using errcode='23505';end if;
  select * into draft from public.artifact_versions where id=(prior.metadata->>'draftVersionId')::uuid and artifact_id=a.id;return to_jsonb(draft);
 end if;
 select * into current0 from public.artifact_versions where id=a.current_version_id;
 if current0.id is null or current0.artifact_id<>a.id or current0.status not in ('APPROVED','CURRENT') or current0.approved_by is null or current0.approved_at is null then raise exception 'Approved source required' using errcode='55000';end if;
 select * into head from public.artifact_versions where artifact_id=a.id order by version_number desc limit 1;
 if head.id is distinct from (input->>'expectedVersionId')::uuid then raise exception 'Revision conflict' using errcode='23505';end if;
 if head.status='DRAFT' then
  if jsonb_typeof(input->'expectedDraftRevision') is distinct from 'number' or input->>'expectedDraftRevision' !~ '^[0-9]+$' then raise exception 'Expected Draft revision required' using errcode='22023';end if;
  made:=public.update_artifact_draft(head.id,(input->>'expectedDraftRevision')::integer,input->'contentSnapshot',input->>'changeSummary',true);
 else
  if input->'expectedDraftRevision' is distinct from 'null'::jsonb then raise exception 'Invalid Draft revision' using errcode='22023';end if;
  -- M8 permits a successor of a noneditable head. Never unlock or rewrite it;
  -- existing submission/resubmission checks still govern any later submission.
  made:=public.create_artifact_version(a.id,input->'contentSnapshot',input->>'changeSummary');
 end if;
 select * into draft from public.artifact_versions where id=(made->>'id')::uuid;
 insert into public.audit_events(actor_user_id,event_type,entity_type,entity_id,scope_type,scope_id,metadata)
 values(actor,'AI_ARTIFACT_DRAFT_APPLIED','artifact',a.id,'artifact',a.id,jsonb_build_object('aiOutputId',s.id,'draftVersionId',draft.id,'draftRevision',draft.draft_revision,'idempotencyKey',(input->>'idempotencyKey')::uuid,'requestHash',fingerprint));
 return to_jsonb(draft);
end$$;


commit;
