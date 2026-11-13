begin;
-- One canonical converted Object per historical AI Output. Ordinary AI-labelled
-- objects without an origin reference remain descriptive, not conversions.
create unique index development_objects_ai_conversion_once on public.development_objects(origin_reference_id) where origin_type='AI' and origin_reference_id is not null;
create unique index change_log_ai_conversion_once on public.change_log(related_ai_output_id) where entity_type='DEVELOPMENT_OBJECT' and change_type='OBJECT_CREATED' and related_ai_output_id is not null;
create function private.ai_conversion_pair(task0 text,kind0 public.development_object_type) returns boolean language sql immutable set search_path='' as $$
 select coalesce(case task0
 when 'SCAMPER_ASSISTANCE' then kind0='IDEA'
 when 'BRAINSTORMING_ASSISTANCE' then kind0='IDEA'
 when 'SYSTEM_STRUCTURE_ANALYSIS' then kind0 in ('SYSTEM','SUBSYSTEM','COMPONENT','FUNCTION')
 when 'GAP_ANALYSIS' then kind0 in ('GAP','OPEN_QUESTION','REQUIREMENT','RISK')
 when 'PATENT_RESEARCH_ASSISTANCE' then kind0 in ('GAP','OPEN_QUESTION','RISK')
 when 'COMPARATIVE_ANALYSIS' then kind0 in ('GAP','REQUIREMENT','RISK','OPEN_QUESTION')
 when 'CRITICAL_REVIEW' then kind0 in ('GAP','RISK','OPEN_QUESTION','REQUIREMENT')
 when 'SESSION10_GAP_REFINEMENT' then kind0 in ('GAP','SOLUTION','REQUIREMENT','OPEN_QUESTION') end,false);
$$;
revoke all on function private.ai_conversion_pair(text,public.development_object_type) from public,anon,authenticated,service_role;
create function public.convert_ai_output_to_candidate(input jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
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
revoke all on function public.convert_ai_output_to_candidate(jsonb) from public,anon,authenticated,service_role;
grant execute on function public.convert_ai_output_to_candidate(jsonb) to service_role;
create function private.preserve_ai_candidate_origin() returns trigger language plpgsql set search_path='' as $$
begin
 if old.origin_type='AI' and old.origin_reference_id is not null and (new.origin_type,new.origin_reference_id,new.object_type) is distinct from (old.origin_type,old.origin_reference_id,old.object_type) then raise exception 'AI conversion origin is immutable' using errcode='23514';end if;
 return new;
end$$;
revoke all on function private.preserve_ai_candidate_origin() from public,anon,authenticated,service_role;
create trigger development_objects_ai_origin_immutable before update on public.development_objects for each row execute function private.preserve_ai_candidate_origin();

create or replace function private.preserve_ai_output() returns trigger
language plpgsql set search_path='' as $$
declare actor uuid:=public.current_platform_user_id();
begin
 if tg_op='UPDATE' and current_user=pg_catalog.pg_get_userbyid((select proowner from pg_catalog.pg_proc where oid='public.set_ai_output_disposition(uuid,public.ai_output_disposition,bigint)'::regprocedure))
 and (to_jsonb(new)-'disposition'-'disposition_revision')=(to_jsonb(old)-'disposition'-'disposition_revision')
 and new.disposition<>old.disposition and old.disposition<>'CONVERTED_TO_PROJECT_OBJECT'
 and (new.disposition<>'CONVERTED_TO_PROJECT_OBJECT' or (old.disposition='ACCEPT_AS_CANDIDATE' and exists(
  select 1 from public.development_objects o join public.change_log c on c.entity_id=o.id and c.related_ai_output_id=old.id and c.entity_type='DEVELOPMENT_OBJECT' and c.change_type='OBJECT_CREATED'
  where o.origin_type='AI' and o.origin_reference_id=old.id and o.project_id=old.project_id and o.workspace_id=old.workspace_id and o.created_by=actor and c.changed_by=actor
  -- PostgreSQL savepoints assign subtransaction XIDs. Own exclusive XID
  -- locks prove that both inserts belong to this backend's active transaction
  -- without incorrectly comparing a child XID with the top-level XID.
  and exists(select 1 from pg_catalog.pg_locks l where l.locktype='transactionid' and l.pid=pg_backend_pid() and l.mode='ExclusiveLock' and l.granted and l.transactionid=o.xmin)
  and exists(select 1 from pg_catalog.pg_locks l where l.locktype='transactionid' and l.pid=pg_backend_pid() and l.mode='ExclusiveLock' and l.granted and l.transactionid=c.xmin)
  and private.ai_conversion_pair(old.task_type,o.object_type)
  and (o.object_type<>'IDEA' or exists(select 1 from public.idea_details d where d.development_object_id=o.id and d.acceptance_state='candidate'))
  )))
 and new.disposition_revision=old.disposition_revision+1
 and actor is not null and public.can_read_development_project(old.project_id)
 then return new;end if;
 if tg_op<>'INSERT' then raise exception 'Generated AI history is immutable' using errcode='55000';end if;
 if new.disposition_revision<>0 or new.disposition<>'KEEP_FOR_REVIEW' then raise exception 'Invalid initial disposition' using errcode='23514';end if;
 if actor is null then raise exception 'Authentication required' using errcode='28000';end if;
 if new.requested_by is distinct from actor then raise exception 'Invalid requester' using errcode='42501';end if;
 perform public.require_development_object_write(new.project_id,new.workspace_id);
 if new.activity_instance_id is not null and not exists(select 1 from public.activity_instances a where a.id=new.activity_instance_id and a.project_id=new.project_id and a.workspace_id=new.workspace_id and public.can_read_activity_instance(a.id)) then
  raise exception 'Incompatible Activity scope' using errcode='23514';end if;
 if new.verification_status<>'UNVERIFIED' then raise exception 'Human verification is deferred' using errcode='23514';end if;
 -- Reject credential-bearing keys at any depth; runtime must additionally avoid
 -- placing secrets in values or in the generated prompt/response themselves.
 if exists(with recursive nodes(body) as (
  select new.metadata union all
  select child.body from nodes n cross join lateral (
   select value body from jsonb_each(case when jsonb_typeof(n.body)='object' then n.body else '{}'::jsonb end)
   union all
   select value body from jsonb_array_elements(case when jsonb_typeof(n.body)='array' then n.body else '[]'::jsonb end)
  ) child
 ) select 1 from nodes n cross join lateral jsonb_each(case when jsonb_typeof(n.body)='object' then n.body else '{}'::jsonb end) e
  where e.key ~* '^(api[_-]?key|provider[_-]?api[_-]?key|secret|password|authorization|access[_-]?token|refresh[_-]?token|service[_-]?role([_-]?key)?|private[_-]?key)$') then
  raise exception 'Credential metadata is forbidden' using errcode='23514';end if;
 new.created_at:=clock_timestamp();
 return new;
end$$;


commit;

