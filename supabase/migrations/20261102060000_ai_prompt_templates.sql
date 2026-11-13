begin;
create type public.ai_prompt_role_code as enum ('STRUCTURED_CREATIVITY_ASSISTANT','BRAINSTORMING_FACILITATOR','SYSTEM_STRUCTURE_ANALYST','PATENT_RESEARCH_ASSISTANT','COMPARATIVE_CRITICAL_ANALYST','CRITICAL_REVIEWER');
create type public.ai_prompt_template_status as enum ('inactive','active');
create function private.ai_prompt_pair_allowed(role0 public.ai_prompt_role_code,activity0 public.activity_method_type) returns boolean
language sql immutable set search_path='' as $$
 select case role0
 when 'STRUCTURED_CREATIVITY_ASSISTANT' then activity0='scamper'
 when 'BRAINSTORMING_FACILITATOR' then activity0 in ('brainstorming','problem_storming')
 when 'SYSTEM_STRUCTURE_ANALYST' then activity0 in ('affinity','mind_map')
 when 'PATENT_RESEARCH_ASSISTANT' then activity0='patent_research'
 when 'COMPARATIVE_CRITICAL_ANALYST' then activity0='comparison'
 when 'CRITICAL_REVIEWER' then activity0='review' else false end;
$$;
revoke all on function private.ai_prompt_pair_allowed(public.ai_prompt_role_code,public.activity_method_type) from public,anon,authenticated,service_role;

-- Deliberately bounded JSON Schema subset. No remote references, executable
-- configuration, implicit coercion, or unknown keywords. Runtime validation of
-- generated responses belongs to later tasks; this validates configuration.
create function private.valid_ai_prompt_output_schema(body jsonb,root0 boolean default true,depth0 integer default 0) returns boolean
language plpgsql immutable set search_path='' as $$
declare k text;child jsonb;kind text;required0 jsonb;
begin
 if depth0>12 or jsonb_typeof(body) is distinct from 'object' then return false;end if;
 kind:=body->>'type';
 if kind is null or kind not in ('object','array','string','number','integer','boolean','null') or (root0 and kind<>'object') then return false;end if;
 for k in select jsonb_object_keys(body) loop
  if k not in ('type','description','properties','required','additionalProperties','items','enum','const','$schema') then return false;end if;
 end loop;
 if body?'$schema' and (not root0 or body->'$schema' is distinct from '"https://json-schema.org/draft/2020-12/schema"'::jsonb) then return false;end if;
 if body?'description' and jsonb_typeof(body->'description')<>'string' then return false;end if;
 if kind in ('object','array') and (body?'enum' or body?'const') then return false;end if;
 if body?'enum' and (jsonb_typeof(body->'enum')<>'array' or jsonb_array_length(body->'enum')=0) then return false;end if;
 if kind='object' then
  if jsonb_typeof(body->'properties') is distinct from 'object' or body->'additionalProperties' is distinct from 'false'::jsonb or body?'items' then return false;end if;
  for k,child in select key,value from jsonb_each(body->'properties') loop
   if length(btrim(k))=0 or not private.valid_ai_prompt_output_schema(child,false,depth0+1) then return false;end if;
  end loop;
  if body?'required' then
   if jsonb_typeof(body->'required')<>'array' then return false;end if;
   for required0 in select value from jsonb_array_elements(body->'required') loop
    if jsonb_typeof(required0)<>'string' or not (body->'properties')?(required0#>>'{}') then return false;end if;
   end loop;
   if (select count(*) from jsonb_array_elements(body->'required'))<>(select count(distinct value) from jsonb_array_elements(body->'required')) then return false;end if;
  end if;
 elsif kind='array' then
  if not private.valid_ai_prompt_output_schema(body->'items',false,depth0+1) or body?'properties' or body?'required' or body?'additionalProperties' then return false;end if;
 elsif body?'properties' or body?'required' or body?'additionalProperties' or body?'items' then return false;
 end if;
 if body?'enum' then
  for child in select value from jsonb_array_elements(body->'enum') loop
   if jsonb_typeof(child)<>(case when kind='integer' then 'number' else kind end) or (kind='integer' and (child#>>'{}')::numeric<>trunc((child#>>'{}')::numeric)) then return false;end if;
  end loop;
 end if;
 if body?'const' then
  child:=body->'const';
  if jsonb_typeof(child)<>(case when kind='integer' then 'number' else kind end) or (kind='integer' and (child#>>'{}')::numeric<>trunc((child#>>'{}')::numeric)) then return false;end if;
  if body?'enum' and not (body->'enum')@>jsonb_build_array(child) then return false;end if;
 end if;
 return true;
exception when others then return false;
end$$;
revoke all on function private.valid_ai_prompt_output_schema(jsonb,boolean,integer) from public,anon,authenticated,service_role;
create function private.ai_prompt_contains_credentials(body text) returns boolean
language sql immutable set search_path='' as $$
 select body ~* '(sk-(proj-|svcacct-)?[a-z0-9_-]{16,}|sk_(live|test)_[a-z0-9_-]{16,}|sb_secret_[a-z0-9_-]{12,}|eyJ[a-z0-9_-]{10,}\.[a-z0-9_-]{10,}\.[a-z0-9_-]{10,}|-----BEGIN ([A-Z ]+ )?PRIVATE KEY-----|bearer\s+[a-z0-9_.-]{16,}|(api[_ -]?key|service[_ -]?role([_ -]?key)?|password|access[_ -]?token|secret)["'']?\s*[:=]\s*["'']?[a-z0-9_./+-]{8,})';
$$;
revoke all on function private.ai_prompt_contains_credentials(text) from public,anon,authenticated,service_role;
create function private.require_ai_prompt_admin() returns uuid
language plpgsql security definer set search_path='' as $$
declare actor uuid:=public.current_platform_user_id();org uuid;
begin
 if actor is null then raise exception 'Access denied' using errcode='42501';end if;
 perform 1 from public.users where id=actor for share;
 select id into org from public.organizations where slug='fici' and status='active' for share;
 if org is null then raise exception 'Access denied' using errcode='42501';end if;
 perform 1 from public.role_assignments ra join public.roles r on r.id=ra.role_id
  where ra.user_id=actor and ra.organization_id=org and r.code='ADMIN' for share of ra;
 if not public.has_active_role_in_organization('ADMIN',org) then raise exception 'Access denied' using errcode='42501';end if;
 return actor;
end$$;
revoke all on function private.require_ai_prompt_admin() from public,anon,authenticated,service_role;
create table public.ai_prompt_templates (
 id uuid primary key default gen_random_uuid(),
 role_code public.ai_prompt_role_code not null,
 activity_type public.activity_method_type not null,
 version integer not null check(version>0),
 system_instruction text not null check(length(btrim(system_instruction)) between 1 and 32000),
 task_template text not null check(length(btrim(task_template)) between 1 and 32000),
 output_schema jsonb not null,
 status public.ai_prompt_template_status not null default 'inactive',
 created_by uuid not null default public.current_platform_user_id() references public.users(id) on delete restrict,
 created_at timestamptz not null default clock_timestamp(),
 unique(role_code,activity_type,version),
 check(private.ai_prompt_pair_allowed(role_code,activity_type)),
 check(private.valid_ai_prompt_output_schema(output_schema)),
 check(octet_length(output_schema::text)<=32000),
 check(not private.ai_prompt_contains_credentials(system_instruction||E'\n'||task_template||E'\n'||output_schema::text))
);
create unique index ai_prompt_templates_one_active on public.ai_prompt_templates(role_code,activity_type) where status='active';
create index ai_prompt_templates_creator on public.ai_prompt_templates(created_by);
create function private.preserve_ai_prompt_template() returns trigger
language plpgsql set search_path='' as $$
declare actor uuid;next_version integer;
begin
 if tg_op='DELETE' then raise exception 'Prompt history is retained' using errcode='55000';end if;
 actor:=private.require_ai_prompt_admin();
 perform pg_advisory_xact_lock(hashtextextended('ai-prompt/'||new.role_code::text||'/'||new.activity_type::text,0));
 if tg_op='UPDATE' then
  if (to_jsonb(new)-'status') is distinct from (to_jsonb(old)-'status') then raise exception 'Prompt versions are immutable' using errcode='55000';end if;
 else
  if new.created_by is distinct from actor then raise exception 'Invalid creator' using errcode='42501';end if;
  if new.status<>'inactive' then raise exception 'Explicit activation required' using errcode='23514';end if;
  select coalesce(max(version),0)+1 into next_version from public.ai_prompt_templates where role_code=new.role_code and activity_type=new.activity_type;
  if new.version is not null and new.version<>next_version then raise exception 'Invalid version' using errcode='23514';end if;
  new.version:=next_version;new.created_at:=clock_timestamp();
 end if;
 return new;
end$$;
revoke all on function private.preserve_ai_prompt_template() from public,anon,authenticated,service_role;
create trigger ai_prompt_templates_preserve before insert or update or delete on public.ai_prompt_templates for each row execute function private.preserve_ai_prompt_template();
alter table public.ai_prompt_templates enable row level security;
revoke all on public.ai_prompt_templates from public,anon,authenticated,service_role;
-- Configuration bodies are not a general client-readable collection. Narrow
-- management RPCs and the private server runtime resolver are the only readers.
create policy ai_prompt_templates_no_insert on public.ai_prompt_templates as restrictive for insert to authenticated with check(false);
create policy ai_prompt_templates_no_update on public.ai_prompt_templates as restrictive for update to authenticated using(false) with check(false);
create policy ai_prompt_templates_no_delete on public.ai_prompt_templates as restrictive for delete to authenticated using(false);
create function public.create_ai_prompt_template(input jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.require_ai_prompt_admin();r public.ai_prompt_templates;
begin
 if jsonb_typeof(input) is distinct from 'object'
 or exists(select 1 from jsonb_object_keys(input) k where k not in ('roleCode','activityType','systemInstruction','taskTemplate','outputSchema'))
 or not (input ?& array['roleCode','activityType','systemInstruction','taskTemplate','outputSchema'])
 or jsonb_typeof(input->'roleCode')<>'string' or jsonb_typeof(input->'activityType')<>'string'
 or jsonb_typeof(input->'systemInstruction')<>'string' or jsonb_typeof(input->'taskTemplate')<>'string'
 then raise exception 'Invalid template' using errcode='22023';end if;
 insert into public.ai_prompt_templates(role_code,activity_type,system_instruction,task_template,output_schema,created_by)
 values((input->>'roleCode')::public.ai_prompt_role_code,(input->>'activityType')::public.activity_method_type,input->>'systemInstruction',input->>'taskTemplate',input->'outputSchema',actor) returning * into r;
 return to_jsonb(r);
end$$;
revoke all on function public.create_ai_prompt_template(jsonb) from public,anon,authenticated,service_role;
grant execute on function public.create_ai_prompt_template(jsonb) to authenticated;
create function public.set_ai_prompt_template_active(target_template uuid,activate boolean) returns jsonb
language plpgsql security definer set search_path='' as $$
declare r public.ai_prompt_templates;
begin
 perform private.require_ai_prompt_admin();
 if activate is null then raise exception 'Invalid activation' using errcode='22023';end if;
 select * into r from public.ai_prompt_templates where id=target_template;
 if not found then raise exception 'Template unavailable' using errcode='42501';end if;
 perform pg_advisory_xact_lock(hashtextextended('ai-prompt/'||r.role_code::text||'/'||r.activity_type::text,0));
 if activate then update public.ai_prompt_templates set status='inactive' where role_code=r.role_code and activity_type=r.activity_type and status='active' and id<>r.id;end if;
 update public.ai_prompt_templates set status=case when activate then 'active'::public.ai_prompt_template_status else 'inactive'::public.ai_prompt_template_status end where id=r.id returning * into r;
 return to_jsonb(r);
end$$;
revoke all on function public.set_ai_prompt_template_active(uuid,boolean) from public,anon,authenticated,service_role;
grant execute on function public.set_ai_prompt_template_active(uuid,boolean) to authenticated;
-- Future server runtime only. No authenticated/anonymous RPC or route exposes
-- raw instructions. No implicit latest selection: exactly one ACTIVE row.
create function private.resolve_active_ai_prompt_template(role0 public.ai_prompt_role_code,activity0 public.activity_method_type) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
 if not coalesce(private.ai_prompt_pair_allowed(role0,activity0),false) then raise exception 'Unsupported template' using errcode='22023';end if;
 select to_jsonb(t) into result from public.ai_prompt_templates t where role_code=role0 and activity_type=activity0 and status='active';
 if result is null then raise exception 'Active template unavailable' using errcode='55000';end if;
 return result;
end$$;
revoke all on function private.resolve_active_ai_prompt_template(public.ai_prompt_role_code,public.activity_method_type) from public,anon,authenticated,service_role;
-- No bootstrap actor is fabricated. Actual seed creation is attributed to the
-- current scoped FICI Admin; repeated runs never rewrite/activate existing pairs.
create function public.seed_ai_prompt_templates() returns integer
language plpgsql security definer set search_path='' as $$
declare pair record;made jsonb;created0 integer:=0;instruction text;
begin
 perform private.require_ai_prompt_admin();
 instruction:='You are a FICI methodology assistant. Use only supplied authorized context. Keep source facts separate from generated suggestions. Generated output is unverified and is not Evidence or an approval. Preserve human authorship. Do not invent citations or disclose unrelated private data. Do not request or include secrets or provider credentials. Do not make novelty, patentability, infringement, validity, freedom-to-operate or legal conclusions. Require human review.';
 for pair in select * from (values
  ('STRUCTURED_CREATIVITY_ASSISTANT','scamper','Support the seven SCAMPER lenses and structured idea expansion. Preserve the user''s source problem and authorship.'),
  ('BRAINSTORMING_FACILITATOR','brainstorming','Support divergent ideas and idea expansion using only the supplied authorized context.'),
  ('BRAINSTORMING_FACILITATOR','problem_storming','Support problem exploration and problem storming. Distinguish observed problems from generated hypotheses.'),
  ('SYSTEM_STRUCTURE_ANALYST','affinity','Support Affinity organization and identify missing relationships. Preserve Team-authored labels and canonical Object identity.'),
  ('SYSTEM_STRUCTURE_ANALYST','mind_map','Support system, subsystem and component analysis and missing relationships. Do not rename or restructure Team-authored content automatically.'),
  ('PATENT_RESEARCH_ASSISTANT','patent_research','Support search terms, synonyms and organization of supplied patent metadata. Separate source material from analysis. Do not imply Evidence verification or legal conclusions.'),
  ('COMPARATIVE_CRITICAL_ANALYST','comparison','Support similarity, difference and gap analysis, option comparison and challenges to assumptions using only supplied authorized material.'),
  ('CRITICAL_REVIEWER','review','Identify contradictions, unsupported claims, missing evidence and unclear reasoning. Provide review suggestions without approving, submitting or changing canonical state.')
 ) p(role0,activity0,task0) loop
  perform pg_advisory_xact_lock(hashtextextended('ai-prompt/'||pair.role0||'/'||pair.activity0,0));
  if not exists(select 1 from public.ai_prompt_templates where role_code::text=pair.role0 and activity_type::text=pair.activity0) then
   made:=public.create_ai_prompt_template(jsonb_build_object('roleCode',pair.role0,'activityType',pair.activity0,'systemInstruction',instruction,'taskTemplate',pair.task0,
    'outputSchema','{"type":"object","properties":{"response":{"type":"string"},"limitations":{"type":"array","items":{"type":"string"}},"requires_human_review":{"type":"boolean","const":true}},"required":["response","limitations","requires_human_review"],"additionalProperties":false}'::jsonb));
   perform public.set_ai_prompt_template_active((made->>'id')::uuid,true);created0:=created0+1;
  end if;
 end loop;
 return created0;
end$$;
revoke all on function public.seed_ai_prompt_templates() from public,anon,authenticated,service_role;
grant execute on function public.seed_ai_prompt_templates() to authenticated;
comment on table public.ai_prompt_templates is 'M14.3 FICI-owned immutable prompt versions; only activation status can change through scoped FICI Admin operations. No provider, context builder, usage events or client template collection.';
commit;
