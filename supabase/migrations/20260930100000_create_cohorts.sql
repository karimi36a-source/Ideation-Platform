begin;
create type public.cohort_status as enum ('planned','active','completed','archived');
alter table public.curriculum_versions add constraint curriculum_versions_identity_program_unique unique(id,program_id);
create table public.cohorts (
 id uuid primary key default gen_random_uuid(),
 program_id uuid not null references public.programs(id) on delete restrict,
 curriculum_version_id uuid not null,
 name text not null check(length(btrim(name)) between 1 and 200),
 start_date date not null,end_date date,
 status public.cohort_status not null default 'planned',
 primary_master_id uuid not null references public.users(id) on delete restrict,
 settings jsonb not null default '{}'::jsonb check(jsonb_typeof(settings)='object'),
 -- Internal provenance: only this relationship's grant is deactivated on reassignment.
 primary_master_assignment_id uuid unique references public.role_assignments(id) on delete restrict,
 created_at timestamptz not null default now(),updated_at timestamptz not null default now(),
 foreign key(curriculum_version_id,program_id) references public.curriculum_versions(id,program_id) on delete restrict on update restrict,
 check(end_date is null or end_date>=start_date)
);
alter table public.role_assignments add constraint role_assignments_cohort_id_fkey foreign key(cohort_id) references public.cohorts(id) on delete restrict;
create function public.protect_cohort_history() returns trigger language plpgsql set search_path='' as $$
declare lifecycle public.curriculum_status;
begin
 if tg_op='DELETE' then raise exception 'Archive cohorts instead' using errcode='23514';end if;
 if tg_op='INSERT' then
  select status into lifecycle from public.curriculum_versions where id=new.curriculum_version_id and program_id=new.program_id for share;
  if lifecycle is null then raise exception 'Invalid curriculum reference' using errcode='23503';end if;
  if lifecycle<>'approved' then raise exception 'New cohorts require approved curriculum' using errcode='23514';end if;
 else
  if new.id is distinct from old.id or new.program_id is distinct from old.program_id or new.curriculum_version_id is distinct from old.curriculum_version_id or new.created_at is distinct from old.created_at then raise exception 'Cohort curriculum and identity are immutable' using errcode='23514';end if;
  new.updated_at:=pg_catalog.clock_timestamp();
 end if;return new;
end $$;
create trigger cohort_history before insert or update or delete on public.cohorts for each row execute function public.protect_cohort_history();
-- Circular cohort/grant creation completes in one transaction. The deferred check
-- prevents committing a missing or mismatched relationship provenance pointer.
create function public.validate_primary_master_relationship() returns trigger language plpgsql security definer set search_path='' as $$
declare c public.cohorts;
begin
 select * into c from public.cohorts where id=new.id;
 if not found then return null;end if;
 if c.primary_master_assignment_id is null or not exists(select 1 from public.role_assignments a join public.roles r on r.id=a.role_id
  where a.id=c.primary_master_assignment_id and a.user_id=c.primary_master_id and a.cohort_id=c.id and r.code='MASTER'
  and a.organization_id is null and a.program_id is null and a.team_id is null and a.project_id is null) then
  raise exception 'Invalid primary Master relationship' using errcode='23514';end if;
 return null;
end $$;
create constraint trigger primary_master_relationship after insert or update on public.cohorts deferrable initially deferred for each row execute function public.validate_primary_master_relationship();
revoke all on function public.protect_cohort_history(),public.validate_primary_master_relationship() from public,anon,authenticated,service_role;
alter table public.cohorts enable row level security;
revoke all on public.cohorts from public,anon,authenticated,service_role;
grant select on public.cohorts to authenticated;
create policy cohorts_scoped_read on public.cohorts for select to authenticated using(
 public.has_active_role_in_cohort('MASTER',id) or exists(select 1 from public.programs p where p.id=program_id and public.has_active_role_in_organization('ADMIN',p.organization_id))
);
-- Narrow definer commands bypass table write restrictions only after verified
-- organization Admin checks; fixed search_path and no caller identity argument.
create function public.create_cohort(target_program uuid,target_version uuid,cohort_name text,starts_on date,ends_on date,master_id uuid,lifecycle public.cohort_status,configuration jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare org uuid; actor uuid; result public.cohorts; assignment uuid; master_role uuid;
begin
 select organization_id into org from public.programs where id=target_program;
 actor:=public.current_platform_user_id();
 if org is null or not public.has_active_role_in_organization('ADMIN',org) then raise exception 'Access denied' using errcode='42501';end if;
 perform 1 from public.users where id=master_id and account_status='active' for share;
 if not found then raise exception 'Invalid primary Master' using errcode='22023';end if;
 select id into master_role from public.roles where code='MASTER' and is_system_role;
 if master_role is null then raise exception 'Access denied' using errcode='42501';end if;
 insert into public.cohorts(program_id,curriculum_version_id,name,start_date,end_date,primary_master_id,status,settings)
 values(target_program,target_version,cohort_name,starts_on,ends_on,master_id,lifecycle,configuration) returning * into result;
 insert into public.role_assignments(user_id,role_id,cohort_id,assigned_by)
 values(master_id,master_role,result.id,actor) returning id into assignment;
 update public.cohorts set primary_master_assignment_id=assignment where id=result.id returning * into result;
 return pg_catalog.to_jsonb(result);
end $$;
create function public.update_cohort(target_cohort uuid,cohort_name text,starts_on date,ends_on date,master_id uuid,lifecycle public.cohort_status,configuration jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare org uuid; actor uuid; result public.cohorts; assignment uuid; master_role uuid;
begin
 select p.organization_id into org from public.cohorts c join public.programs p on p.id=c.program_id where c.id=target_cohort;
 actor:=public.current_platform_user_id();
 if org is null or not public.has_active_role_in_organization('ADMIN',org) then raise exception 'Access denied' using errcode='42501';end if;
 select * into result from public.cohorts where id=target_cohort for update;
 if not found then raise exception 'Access denied' using errcode='42501';end if;
 -- A reassignment may wait for another cohort update. Recheck authority after
 -- acquiring that lock rather than retaining a pre-wait authorization snapshot.
 if not public.has_active_role_in_organization('ADMIN',org) then raise exception 'Access denied' using errcode='42501';end if;
 assignment:=result.primary_master_assignment_id;
 if master_id is distinct from result.primary_master_id then
  perform 1 from public.users where id=master_id and account_status='active' for share;
  if not found then raise exception 'Invalid primary Master' using errcode='22023';end if;
  select id into master_role from public.roles where code='MASTER' and is_system_role;
  if master_role is null or assignment is null then raise exception 'Access denied' using errcode='42501';end if;
  -- Deactivate only the tracked grant; unrelated grants remain untouched.
  update public.role_assignments set status='inactive' where id=assignment and user_id=result.primary_master_id and cohort_id=result.id and role_id=master_role;
  if not found then raise exception 'Access denied' using errcode='42501';end if;
  insert into public.role_assignments(user_id,role_id,cohort_id,assigned_by)
  values(master_id,master_role,result.id,actor) returning id into assignment;
 end if;
 update public.cohorts set name=cohort_name,start_date=starts_on,end_date=ends_on,primary_master_id=master_id,primary_master_assignment_id=assignment,status=lifecycle,settings=configuration
 where id=target_cohort returning * into result;
 return pg_catalog.to_jsonb(result);
end $$;
revoke all on function public.create_cohort(uuid,uuid,text,date,date,uuid,public.cohort_status,jsonb),public.update_cohort(uuid,text,date,date,uuid,public.cohort_status,jsonb) from public,anon,authenticated,service_role;
grant execute on function public.create_cohort(uuid,uuid,text,date,date,uuid,public.cohort_status,jsonb),public.update_cohort(uuid,text,date,date,uuid,public.cohort_status,jsonb) to authenticated;
commit;
