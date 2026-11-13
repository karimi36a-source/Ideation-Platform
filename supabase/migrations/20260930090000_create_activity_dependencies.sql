begin;
create type public.activity_dependency_type as enum ('completion','approved_output','artifact_available','gate_passed');
create table public.activity_dependencies (
 id uuid primary key default gen_random_uuid(),
 activity_definition_id uuid not null references public.activity_definitions(id) on delete restrict,
 required_activity_definition_id uuid not null references public.activity_definitions(id) on delete restrict,
 dependency_type public.activity_dependency_type not null,
 required_artifact_type text check(required_artifact_type is null or length(btrim(required_artifact_type))>0),
 is_mandatory boolean not null,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 check(activity_definition_id<>required_activity_definition_id),
 unique nulls not distinct(activity_definition_id,required_activity_definition_id,dependency_type,required_artifact_type)
);
alter table public.activity_dependencies enable row level security;
revoke all on public.activity_dependencies from public,anon,authenticated,service_role;
grant select on public.activity_dependencies to authenticated;
create policy dependencies_admin_read on public.activity_dependencies for select to authenticated using(exists(
 select 1 from public.activity_definitions a join public.session_definitions s on s.id=a.session_definition_id
 join public.curriculum_versions v on v.id=s.curriculum_version_id join public.programs p on p.id=v.program_id
 where a.id=activity_definition_id and public.has_active_role_in_organization('ADMIN',p.organization_id)
));
-- The two referenced activity parents are immutable. Lock their common curriculum
-- against approval while validating changes; no runtime execution/gating occurs.
create function public.protect_dependency_history() returns trigger language plpgsql set search_path='' as $$
declare source_id uuid; prerequisite_id uuid; parent uuid; required_parent uuid; lifecycle public.curriculum_status;
begin
 if tg_op='DELETE' then source_id:=old.activity_definition_id;prerequisite_id:=old.required_activity_definition_id;
 else source_id:=new.activity_definition_id;prerequisite_id:=new.required_activity_definition_id;end if;
 select s.curriculum_version_id into parent from public.activity_definitions a join public.session_definitions s on s.id=a.session_definition_id where a.id=source_id;
 select s.curriculum_version_id into required_parent from public.activity_definitions a join public.session_definitions s on s.id=a.session_definition_id where a.id=prerequisite_id;
 if parent is null or required_parent is null then raise exception 'Invalid activity reference' using errcode='23503';end if;
 if parent<>required_parent then raise exception 'Dependencies require one curriculum version' using errcode='23514';end if;
 select status into lifecycle from public.curriculum_versions where id=parent for share;
 if lifecycle is distinct from 'draft' then raise exception 'Approved dependency definition is immutable' using errcode='23514';end if;
 if tg_op='UPDATE' then
  if new.id is distinct from old.id or new.activity_definition_id is distinct from old.activity_definition_id or new.created_at is distinct from old.created_at then raise exception 'Dependency identity is immutable' using errcode='23514';end if;
  new.updated_at:=pg_catalog.clock_timestamp();
 end if;
 if tg_op='DELETE' then return old;end if;return new;
end $$;
create trigger dependency_history before insert or update or delete on public.activity_dependencies for each row execute function public.protect_dependency_history();
revoke all on function public.protect_dependency_history() from public,anon,authenticated,service_role;
-- Definer permits one narrowly authorized command despite no client table writes.
-- Identity comes only from the existing authenticated-context role helper.
create function public.manage_activity_dependency(target_activity uuid,target_dependency uuid,required_activity uuid,kind public.activity_dependency_type,artifact_type text,mandatory boolean)
returns jsonb language plpgsql security definer set search_path='' as $$
declare org uuid; parent uuid; required_parent uuid; lifecycle public.curriculum_status; result public.activity_dependencies;
begin
 select p.organization_id,v.id into org,parent from public.activity_definitions a join public.session_definitions s on s.id=a.session_definition_id
 join public.curriculum_versions v on v.id=s.curriculum_version_id join public.programs p on p.id=v.program_id where a.id=target_activity;
 if org is null or not public.has_active_role_in_organization('ADMIN',org) then raise exception 'Access denied' using errcode='42501';end if;
 select s.curriculum_version_id into required_parent from public.activity_definitions a join public.session_definitions s on s.id=a.session_definition_id where a.id=required_activity;
 if required_parent is null or required_parent<>parent then raise exception 'Access denied' using errcode='42501';end if;
 select status into lifecycle from public.curriculum_versions where id=parent for update;
 if lifecycle is distinct from 'draft' then raise exception 'Access denied' using errcode='42501';end if;
 if target_dependency is null then
  insert into public.activity_dependencies(activity_definition_id,required_activity_definition_id,dependency_type,required_artifact_type,is_mandatory)
  values(target_activity,required_activity,kind,artifact_type,mandatory) returning * into result;
 else
  update public.activity_dependencies set required_activity_definition_id=required_activity,dependency_type=kind,required_artifact_type=artifact_type,is_mandatory=mandatory
  where id=target_dependency and activity_definition_id=target_activity returning * into result;
  if not found then raise exception 'Access denied' using errcode='42501';end if;
 end if;return pg_catalog.to_jsonb(result);
end $$;
revoke all on function public.manage_activity_dependency(uuid,uuid,uuid,public.activity_dependency_type,text,boolean) from public,anon,authenticated,service_role;
grant execute on function public.manage_activity_dependency(uuid,uuid,uuid,public.activity_dependency_type,text,boolean) to authenticated;
-- No seed rows: Session 4/5, 6/7, 8/9 and 9/10 activity definitions are absent.
commit;
