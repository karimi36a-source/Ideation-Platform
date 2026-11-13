begin;
create type public.activity_status as enum ('active','inactive','archived');
create type public.activity_method_type as enum ('teaching','reflection','scamper','brainstorming','problem_storming','voting','affinity','mind_map','patent_research','comparison','validation','roadmap','kanban','decision','review','custom');
create table public.activity_definitions (
 id uuid primary key default gen_random_uuid(),
 session_definition_id uuid not null references public.session_definitions(id) on delete restrict,
 name text not null check(length(btrim(name))>0), description text,
 method_type public.activity_method_type not null, workspace_mode text,
 sequence integer not null check(sequence>0), instructions text, ai_role_code text,
 requires_review boolean not null default false, requires_approval boolean not null default false,
 completion_rule text, configuration jsonb not null default '{}'::jsonb check(jsonb_typeof(configuration)='object'),
 status public.activity_status not null default 'active',
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 unique(session_definition_id,sequence)
);
alter table public.activity_definitions enable row level security;
revoke all on public.activity_definitions from public,anon,authenticated,service_role;
grant select on public.activity_definitions to authenticated;
create policy activities_admin_read on public.activity_definitions for select to authenticated using(exists(
 select 1 from public.session_definitions s join public.curriculum_versions v on v.id=s.curriculum_version_id join public.programs p on p.id=v.program_id
 where s.id=session_definition_id and public.has_active_role_in_organization('ADMIN',p.organization_id)
));
-- Trusted baseline only, before installation of the history guard. No runtime bypass.
create function public.seed_professional_activity() returns void language plpgsql security invoker set search_path='' as $$
declare expected jsonb:= '{"id": "00000000-0000-4000-8000-000000000801", "session_definition_id": "00000000-0000-4000-8000-000000000702", "name": "SCAMPER Example Set", "description": "Teach the seven SCAMPER lenses and the FICI holistic-to-detail method.", "method_type": "scamper", "workspace_mode": "Personal Workspace", "sequence": 1, "instructions": "Participants prepare 14 SCAMPER examples:\n\n- 7 existing examples\n- 7 participant-created examples\n\nwith an explanation of what changed.", "ai_role_code": null, "requires_review": true, "requires_approval": false, "completion_rule": null, "configuration": {}, "status": "active"}'::jsonb; actual jsonb;
begin
 if not exists(select 1 from public.session_definitions s join public.curriculum_versions v on v.id=s.curriculum_version_id join public.programs p on p.id=v.program_id join public.organizations o on o.id=p.organization_id
 where s.id=(expected->>'session_definition_id')::uuid and s.session_number=2 and v.version_label='2026 v1' and v.id='00000000-0000-4000-8000-000000000602' and p.code='PROFESSIONAL_COURSE' and o.slug='fici') then
 raise exception 'Approved activity parent unavailable' using errcode='23514';end if;
 select to_jsonb(a)-'created_at'-'updated_at' into actual from public.activity_definitions a where id=(expected->>'id')::uuid;
 if actual is not null then
  if actual is distinct from expected then raise exception 'Activity seed integrity mismatch' using errcode='23514';end if;return;
 end if;
 insert into public.activity_definitions(id,session_definition_id,name,description,method_type,workspace_mode,sequence,instructions,ai_role_code,requires_review,requires_approval,completion_rule,configuration,status)
 select id,session_definition_id,name,description,method_type,workspace_mode,sequence,instructions,ai_role_code,requires_review,requires_approval,completion_rule,configuration,status
 from pg_catalog.jsonb_populate_record(null::public.activity_definitions,expected);
end $$;
revoke all on function public.seed_professional_activity() from public,anon,authenticated,service_role;
select public.seed_professional_activity();
create function public.protect_activity_history() returns trigger language plpgsql set search_path='' as $$
declare parent uuid; lifecycle public.curriculum_status;
begin
 select curriculum_version_id into parent from public.session_definitions where id=case when tg_op='DELETE' then old.session_definition_id else new.session_definition_id end;
 select status into lifecycle from public.curriculum_versions where id=parent for share;
 if lifecycle is distinct from 'draft' then raise exception 'Approved activity definition is immutable' using errcode='23514';end if;
 if tg_op='UPDATE' then
  if new.id is distinct from old.id or new.session_definition_id is distinct from old.session_definition_id or new.created_at is distinct from old.created_at then raise exception 'Activity identity is immutable' using errcode='23514';end if;
  new.updated_at:=pg_catalog.clock_timestamp();
 end if;
 if tg_op='DELETE' then return old;end if;return new;
end $$;
create trigger activity_history before insert or update or delete on public.activity_definitions for each row execute function public.protect_activity_history();
revoke all on function public.protect_activity_history() from public,anon,authenticated,service_role;
create function public.manage_activity(target_session uuid,target_activity uuid,definition jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare org uuid; parent uuid; lifecycle public.curriculum_status; input public.activity_definitions; result public.activity_definitions;
begin
 select p.organization_id,v.id into org,parent from public.session_definitions s join public.curriculum_versions v on v.id=s.curriculum_version_id join public.programs p on p.id=v.program_id where s.id=target_session;
 if org is null or not public.has_active_role_in_organization('ADMIN',org) then raise exception 'Access denied' using errcode='42501';end if;
 select status into lifecycle from public.curriculum_versions where id=parent for update;
 if lifecycle is distinct from 'draft' then raise exception 'Access denied' using errcode='42501';end if;
 if definition is null or jsonb_typeof(definition)<>'object' or exists(select 1 from jsonb_object_keys(definition) k where k not in ('name','description','method_type','workspace_mode','sequence','instructions','ai_role_code','requires_review','requires_approval','completion_rule','configuration','status')) then raise exception 'Invalid definition' using errcode='22023';end if;
 input:=pg_catalog.jsonb_populate_record(null::public.activity_definitions,'{"requires_review":false,"requires_approval":false,"configuration":{},"status":"active"}'::jsonb||definition);
 if target_activity is null then
 insert into public.activity_definitions(session_definition_id,name,description,method_type,workspace_mode,sequence,instructions,ai_role_code,requires_review,requires_approval,completion_rule,configuration,status)
 values(target_session,input.name,input.description,input.method_type,input.workspace_mode,input.sequence,input.instructions,input.ai_role_code,input.requires_review,input.requires_approval,input.completion_rule,input.configuration,input.status) returning * into result;
 else
 update public.activity_definitions set name=input.name,description=input.description,method_type=input.method_type,workspace_mode=input.workspace_mode,sequence=input.sequence,instructions=input.instructions,ai_role_code=input.ai_role_code,requires_review=input.requires_review,requires_approval=input.requires_approval,completion_rule=input.completion_rule,configuration=input.configuration,status=input.status
 where id=target_activity and session_definition_id=target_session returning * into result;
 if not found then raise exception 'Access denied' using errcode='42501';end if;
 end if;return pg_catalog.to_jsonb(result);
end $$;
revoke all on function public.manage_activity(uuid,uuid,jsonb) from public,anon,authenticated,service_role;
grant execute on function public.manage_activity(uuid,uuid,jsonb) to authenticated;
commit;
