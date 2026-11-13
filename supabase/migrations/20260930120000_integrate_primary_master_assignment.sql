begin;
-- Narrow identity-bound definer: no user/role proof from caller, no table CRUD.
create function public.assign_master_to_cohort(target_cohort uuid,master_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare org uuid; actor uuid; c public.cohorts; a public.role_assignments; rid uuid; grant_id uuid;
begin
 select p.organization_id into org from public.cohorts co join public.programs p on p.id=co.program_id where co.id=target_cohort;
 if org is null or not public.has_active_role_in_organization('ADMIN',org) then raise exception 'Access denied' using errcode='42501';end if;
 select * into c from public.cohorts where id=target_cohort for update;
 if not found or not public.has_active_role_in_organization('ADMIN',org) then raise exception 'Access denied' using errcode='42501';end if;
 actor:=public.current_platform_user_id();
 perform 1 from public.users where id=master_id and account_status='active' for share;
 if not found then raise exception 'Invalid primary Master' using errcode='22023';end if;
 select id into rid from public.roles where code='MASTER' and is_system_role;
 select * into a from public.role_assignments where id=c.primary_master_assignment_id for update;
 if rid is null or a.id is null or a.role_id<>rid or a.user_id<>c.primary_master_id or a.cohort_id<>c.id
  or a.organization_id is not null or a.program_id is not null or a.team_id is not null or a.project_id is not null
 then raise exception 'Access denied' using errcode='42501';end if;
 -- A valid same-Master retry does not touch timestamps or create another grant.
 if master_id=c.primary_master_id and a.status='active' and a.starts_at<=pg_catalog.statement_timestamp()
  and (a.ends_at is null or a.ends_at>pg_catalog.statement_timestamp()) then return pg_catalog.to_jsonb(c);end if;
 -- Only relationship provenance is changed; expired/revoked history is retained.
 update public.role_assignments set status='inactive' where id=a.id;
 insert into public.role_assignments(user_id,role_id,cohort_id,assigned_by)
 values(master_id,rid,c.id,actor) returning id into grant_id;
 update public.cohorts set primary_master_id=master_id,primary_master_assignment_id=grant_id where id=c.id returning * into c;
 return pg_catalog.to_jsonb(c);
end $$;
revoke all on function public.assign_master_to_cohort(uuid,uuid) from public,anon,authenticated,service_role;
grant execute on function public.assign_master_to_cohort(uuid,uuid) to authenticated;
create or replace function public.update_cohort(target_cohort uuid,cohort_name text,starts_on date,ends_on date,master_id uuid,lifecycle public.cohort_status,configuration jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare org uuid; actor uuid; result public.cohorts; assignment uuid; master_role uuid;
begin
 select p.organization_id into org from public.cohorts co join public.programs p on p.id=co.program_id where co.id=target_cohort;
 actor:=public.current_platform_user_id();
 if org is null or not public.has_active_role_in_organization('ADMIN',org) then raise exception 'Access denied' using errcode='42501';end if;
 select * into result from public.cohorts where id=target_cohort for update;
 if not found then raise exception 'Access denied' using errcode='42501';end if;
 -- A reassignment may wait for another cohort update. Recheck authority after
 -- acquiring that lock rather than retaining a pre-wait authorization snapshot.
 if not public.has_active_role_in_organization('ADMIN',org) then raise exception 'Access denied' using errcode='42501';end if;
 result:=(pg_catalog.jsonb_populate_record(null::public.cohorts,public.assign_master_to_cohort(target_cohort,master_id)));
 assignment:=result.primary_master_assignment_id;
 update public.cohorts set name=cohort_name,start_date=starts_on,end_date=ends_on,primary_master_id=master_id,primary_master_assignment_id=assignment,status=lifecycle,settings=configuration
 where id=target_cohort returning * into result;
 return pg_catalog.to_jsonb(result);
end $$;
commit;

