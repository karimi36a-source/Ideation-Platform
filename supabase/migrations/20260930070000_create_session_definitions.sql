begin;
create type public.session_status as enum ('active','inactive','archived');
create table public.session_definitions (
 id uuid primary key default gen_random_uuid(),
 curriculum_version_id uuid not null references public.curriculum_versions(id) on delete restrict,
 session_number integer not null check(session_number>0),title text not null check(length(btrim(title))>0),
 description text not null,learning_goal text not null check(length(btrim(learning_goal))>0),
 sequence integer not null check(sequence>0),status public.session_status not null default 'active',
 created_at timestamptz not null default now(),updated_at timestamptz not null default now(),
 unique(curriculum_version_id,session_number),unique(curriculum_version_id,sequence)
);
alter table public.session_definitions enable row level security;
revoke all on public.session_definitions from public,anon,authenticated,service_role;
grant select on public.session_definitions to authenticated;
create policy sessions_admin_read on public.session_definitions for select to authenticated using(exists(
 select 1 from public.curriculum_versions v join public.programs p on p.id=v.program_id
 where v.id=curriculum_version_id and public.has_active_role_in_organization('ADMIN',p.organization_id)
));
-- One-time trusted baseline seed runs before history guard installation.
create function public.seed_professional_sessions() returns void language plpgsql security invoker set search_path='' as $$
declare seed jsonb:= '[
  {
    "id": "00000000-0000-4000-8000-000000000701",
    "session_number": 1,
    "title": "Think Like an Inventor",
    "description": "No major structured invention artifact is required.\n\nPossible stored output:\n\n- Personal Reflection / Readiness Notes\n- early problem observations",
    "learning_goal": "Build foundational understanding of:\n\n- creativity,\n- inventor mindset,\n- experimentation,\n- failure and resilience,\n- invention vs idea vs innovation.",
    "sequence": 1,
    "status": "active"
  },
  {
    "id": "00000000-0000-4000-8000-000000000702",
    "session_number": 2,
    "title": "The SCAMPER Framework",
    "description": "Teach the seven SCAMPER lenses and the FICI holistic-to-detail method.",
    "learning_goal": "Teach the seven SCAMPER lenses and the FICI holistic-to-detail method.",
    "sequence": 2,
    "status": "active"
  },
  {
    "id": "00000000-0000-4000-8000-000000000703",
    "session_number": 3,
    "title": "SCAMPER Applied Workshop",
    "description": "Turn one selected SCAMPER idea into a developed invention concept.",
    "learning_goal": "Turn one selected SCAMPER idea into a developed invention concept.",
    "sequence": 3,
    "status": "active"
  },
  {
    "id": "00000000-0000-4000-8000-000000000704",
    "session_number": 4,
    "title": "Brainstorming & Problem Storming",
    "description": "Expand the concept before evaluation.",
    "learning_goal": "Expand the concept before evaluation.",
    "sequence": 4,
    "status": "active"
  },
  {
    "id": "00000000-0000-4000-8000-000000000705",
    "session_number": 5,
    "title": "Idea Evaluation & Voting",
    "description": "Convert multiple options and disagreement into a structured team decision.",
    "learning_goal": "Convert multiple options and disagreement into a structured team decision.",
    "sequence": 5,
    "status": "active"
  },
  {
    "id": "00000000-0000-4000-8000-000000000706",
    "session_number": 6,
    "title": "Affinity Diagram",
    "description": "Organize accumulated information into an early invention structure.",
    "learning_goal": "Organize accumulated information into an early invention structure.",
    "sequence": 6,
    "status": "active"
  },
  {
    "id": "00000000-0000-4000-8000-000000000707",
    "session_number": 7,
    "title": "Mind Mapping",
    "description": "Visualize the entire invention and identify the minimum essential invention structure.",
    "learning_goal": "Visualize the entire invention and identify the minimum essential invention structure.",
    "sequence": 7,
    "status": "active"
  },
  {
    "id": "00000000-0000-4000-8000-000000000708",
    "session_number": 8,
    "title": "Patent Document & Reading Basics",
    "description": "Teach participants how to understand and navigate patent documents.",
    "learning_goal": "Teach participants how to understand and navigate patent documents.",
    "sequence": 8,
    "status": "active"
  },
  {
    "id": "00000000-0000-4000-8000-000000000709",
    "session_number": 9,
    "title": "Patent Search & Comparative Analysis",
    "description": "Build an evidence-based picture of what already exists and identify potential technical gaps.",
    "learning_goal": "Build an evidence-based picture of what already exists and identify potential technical gaps.",
    "sequence": 9,
    "status": "active"
  },
  {
    "id": "00000000-0000-4000-8000-000000000710",
    "session_number": 10,
    "title": "AI-Assisted Invention Refinement",
    "description": "Connect all previous work into a structured, evidence-based refinement process.",
    "learning_goal": "Connect all previous work into a structured, evidence-based refinement process.",
    "sequence": 10,
    "status": "active"
  }
]'::jsonb; version_id uuid:='00000000-0000-4000-8000-000000000602';
begin
 if not exists(select 1 from public.curriculum_versions v join public.programs p on p.id=v.program_id join public.organizations o on o.id=p.organization_id
  where v.id=version_id and v.version_label='2026 v1' and p.code='PROFESSIONAL_COURSE' and o.slug='fici') then
  raise exception 'Approved curriculum seed unavailable' using errcode='23514';end if;
 if exists(select 1 from public.session_definitions where curriculum_version_id=version_id) then
  if (select count(*) from public.session_definitions where curriculum_version_id=version_id)<>10 or exists(
   select e.id::uuid,e.session_number,e.title,e.description,e.learning_goal,e.sequence,e.status::public.session_status
   from pg_catalog.jsonb_to_recordset(seed) as e(id text,session_number integer,title text,description text,learning_goal text,sequence integer,status text)
   except select id,session_number,title,description,learning_goal,sequence,status from public.session_definitions where curriculum_version_id=version_id
  ) then raise exception 'Session seed integrity mismatch' using errcode='23514';end if;
  return;
 end if;
 insert into public.session_definitions(id,curriculum_version_id,session_number,title,description,learning_goal,sequence,status)
 select e.id::uuid,version_id,e.session_number,e.title,e.description,e.learning_goal,e.sequence,e.status::public.session_status
 from pg_catalog.jsonb_to_recordset(seed) as e(id text,session_number integer,title text,description text,learning_goal text,sequence integer,status text);
end $$;
revoke all on function public.seed_professional_sessions() from public,anon,authenticated,service_role;
select public.seed_professional_sessions();
create function public.protect_session_history() returns trigger language plpgsql set search_path='' as $$
declare parent uuid; lifecycle public.curriculum_status;
begin
 parent:=case when tg_op='DELETE' then old.curriculum_version_id else new.curriculum_version_id end;
 select status into lifecycle from public.curriculum_versions where id=parent for share;
 if lifecycle is distinct from 'draft' then raise exception 'Approved session definition is immutable' using errcode='23514';end if;
 if tg_op='UPDATE' then
  if new.id is distinct from old.id or new.curriculum_version_id is distinct from old.curriculum_version_id or new.created_at is distinct from old.created_at then
   raise exception 'Session identity is immutable' using errcode='23514';end if;
  new.updated_at:=pg_catalog.clock_timestamp();
 end if;
 if tg_op='DELETE' then return old;end if;return new;
end $$;
create trigger session_history before insert or update or delete on public.session_definitions for each row execute function public.protect_session_history();
revoke all on function public.protect_session_history() from public,anon,authenticated,service_role;
create function public.manage_session(target_version uuid,target_session uuid,number integer,session_title text,session_description text,goal text,session_position integer,lifecycle public.session_status)
returns jsonb language plpgsql security definer set search_path='' as $$
declare org uuid; parent_status public.curriculum_status; result public.session_definitions;
begin
 select p.organization_id into org from public.programs p join public.curriculum_versions v on v.program_id=p.id where v.id=target_version;
 if org is null or not public.has_active_role_in_organization('ADMIN',org) then raise exception 'Access denied' using errcode='42501';end if;
 select status into parent_status from public.curriculum_versions where id=target_version for update;
 if parent_status is distinct from 'draft' then raise exception 'Access denied' using errcode='42501';end if;
 if target_session is null then
  insert into public.session_definitions(curriculum_version_id,session_number,title,description,learning_goal,sequence,status)
  values(target_version,number,session_title,session_description,goal,session_position,lifecycle) returning * into result;
 else
  update public.session_definitions set session_number=number,title=session_title,description=session_description,learning_goal=goal,sequence=session_position,status=lifecycle
  where id=target_session and curriculum_version_id=target_version returning * into result;
  if not found then raise exception 'Access denied' using errcode='42501';end if;
 end if;return pg_catalog.to_jsonb(result);
end $$;
revoke all on function public.manage_session(uuid,uuid,integer,text,text,text,integer,public.session_status) from public,anon,authenticated,service_role;
grant execute on function public.manage_session(uuid,uuid,integer,text,text,text,integer,public.session_status) to authenticated;
commit;

