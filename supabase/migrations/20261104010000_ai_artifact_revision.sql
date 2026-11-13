begin;
-- Extend the existing immutable, default-deny audit; no content copy, new ACL,
-- generic origin support, or parallel provenance table.
do $$declare expression0 text;begin
 select pg_get_expr(conbin,conrelid) into expression0 from pg_constraint where conrelid='public.audit_events'::regclass and conname='audit_events_context_check';
 if expression0 is null then raise exception 'Audit foundation missing';end if;
 alter table public.audit_events drop constraint audit_events_context_check;
 execute 'alter table public.audit_events add constraint audit_events_context_check check (('||expression0||') or (event_type=''AI_ARTIFACT_DRAFT_APPLIED'' and entity_type=''artifact'' and scope_type=''artifact'' and entity_id=scope_id and jsonb_typeof(metadata)=''object'' and metadata ?& array[''aiOutputId'',''draftVersionId'',''draftRevision'',''idempotencyKey'',''requestHash''] and metadata - array[''aiOutputId'',''draftVersionId'',''draftRevision'',''idempotencyKey'',''requestHash'']=''{}''::jsonb and (metadata->>''requestHash'') ~ ''^[a-f0-9]{64}$''))';
end$$;
create unique index audit_ai_artifact_request_once on public.audit_events(actor_user_id,(metadata->>'idempotencyKey')) where event_type='AI_ARTIFACT_DRAFT_APPLIED';
create function private.validate_ai_artifact_audit() returns trigger language plpgsql set search_path='' as $$begin
 if new.event_type='AI_ARTIFACT_DRAFT_APPLIED' and not exists(
  select 1 from public.ai_outputs s join public.artifacts a on a.project_id=s.project_id and a.workspace_id=s.workspace_id join public.artifact_versions v on v.artifact_id=a.id
  where a.id=new.entity_id and s.id=(new.metadata->>'aiOutputId')::uuid and v.id=(new.metadata->>'draftVersionId')::uuid and v.status='DRAFT'
   and v.draft_revision=(new.metadata->>'draftRevision')::integer and new.actor_user_id=public.current_platform_user_id()
   and (new.metadata->>'idempotencyKey')::uuid is not null)
 then raise exception 'Invalid AI revision provenance' using errcode='23514';end if;return new;
end$$;
revoke all on function private.validate_ai_artifact_audit() from public,anon,authenticated,service_role;
create trigger audit_ai_artifact_integrity before insert on public.audit_events for each row execute function private.validate_ai_artifact_audit();
create function public.apply_ai_artifact_revision(input jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid;s public.ai_outputs;a public.artifacts;head public.artifact_versions;draft public.artifact_versions;current0 public.artifact_versions;prior public.audit_events;fingerprint text;made jsonb;
begin
 if input is null or jsonb_typeof(input)<>'object' or (select count(*) from jsonb_object_keys(input))<>10
 or exists(select 1 from jsonb_object_keys(input) k where k not in ('actorId','aiOutputId','artifactId','expectedVersionId','expectedDraftRevision','contentSnapshot','changeSummary','confirmed','idempotencyKey','sourceResponseHash'))
 or input->'confirmed' is distinct from 'true'::jsonb or not(input?'contentSnapshot') or octet_length(input::text)>4000000
 or (input->>'sourceResponseHash') is null or (input->>'sourceResponseHash')!~'^[a-f0-9]{64}$'
 or jsonb_typeof(input->'changeSummary') not in ('string','null') then raise exception 'Invalid revision' using errcode='22023';end if;
 actor:=(input->>'actorId')::uuid;perform private.ai_task_actor(actor);
 select * into s from public.ai_outputs where id=(input->>'aiOutputId')::uuid;
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
revoke all on function public.apply_ai_artifact_revision(jsonb) from public,anon,authenticated,service_role;
grant execute on function public.apply_ai_artifact_revision(jsonb) to service_role;
commit;
