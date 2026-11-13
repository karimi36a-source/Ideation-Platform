begin;
create function public.create_team(target_cohort uuid,team_name text,team_description text default null,lead_user uuid default null,target_project uuid default null)
 returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid; org uuid; c public.cohorts; master_id uuid; wid uuid; tid uuid; chid uuid;
begin
 actor:=public.current_platform_user_id();
 if actor is null then
  if auth.uid() is null then raise exception 'Authentication required' using errcode='28000';end if;
  raise exception 'Access denied' using errcode='42501';
 end if;
 select p.organization_id into org from public.cohorts co join public.programs p on p.id=co.program_id where co.id=target_cohort;
 if org is null or not(public.has_active_role_in_organization('ADMIN',org) or public.has_active_role_in_cohort('MASTER',target_cohort)) then
  raise exception 'Access denied' using errcode='42501';end if;
 select * into c from public.cohorts where id=target_cohort for update;
 -- Re-resolve and lock the current parent scope after any wait on the cohort.
 select organization_id into org from public.programs where id=c.program_id for share;
 if not found or not(public.has_active_role_in_organization('ADMIN',org) or public.has_active_role_in_cohort('MASTER',target_cohort)) then
  raise exception 'Access denied' using errcode='42501';end if;
 perform 1 from public.users where id=actor and account_status='active' for share;
 if not found then raise exception 'Access denied' using errcode='42501';end if;
 perform 1 from public.role_assignments a join public.roles r on r.id=a.role_id
  where a.user_id=actor and a.status='active' and a.starts_at<=now() and (a.ends_at is null or a.ends_at>now())
   and a.program_id is null and a.team_id is null and a.project_id is null
   and ((r.code='ADMIN' and a.organization_id=org and a.cohort_id is null)
    or (r.code='MASTER' and a.cohort_id=c.id and a.organization_id is null)) for share of a;
 if not found then raise exception 'Access denied' using errcode='42501';end if;
 if target_project is not null then raise exception 'Project dependency unavailable' using errcode='0A000';end if;
 if team_name is null or length(btrim(team_name)) not between 1 and 200 then raise exception 'Invalid Team input' using errcode='22023';end if;
 -- One Primary Master is already defined by M3; never accept a caller Master ID.
 master_id:=c.primary_master_id;
 perform 1 from public.users where id=master_id and account_status='active' for share;
 if not found then raise exception 'Invalid Team Master' using errcode='22023';end if;
 perform 1 from public.role_assignments a join public.roles r on r.id=a.role_id
  where a.user_id=master_id and r.code='MASTER' and a.cohort_id=c.id and a.status='active'
   and a.starts_at<=now() and (a.ends_at is null or a.ends_at>now())
   and a.organization_id is null and a.program_id is null and a.team_id is null and a.project_id is null
  for share of a;
 if not found then raise exception 'Invalid Team Master' using errcode='22023';end if;
 if lead_user is not null then
  perform 1 from public.users where id=lead_user and account_status='active' for share;
  if not found then raise exception 'Invalid Team Lead' using errcode='22023';end if;
  perform 1 from public.enrollments where user_id=lead_user and cohort_id=c.id
   and status='active' and enrollment_role='participant' for share;
  if not found then raise exception 'Invalid Team Lead' using errcode='22023';end if;
 end if;
 insert into public.workspaces(workspace_type,name,cohort_id,status,visibility,created_by,updated_by)
  values('TEAM',btrim(team_name),c.id,'active','private',actor,actor) returning id into wid;
 insert into public.teams(cohort_id,name,description,master_user_id,workspace_id,created_by)
  values(c.id,btrim(team_name),team_description,master_id,wid,actor) returning id into tid;
 update public.workspaces set team_id=tid where id=wid;
 insert into public.chat_channels(channel_type,workspace_id,team_id,cohort_id,name,status)
  values('TEAM',wid,tid,c.id,btrim(team_name),'active') returning id into chid;
 if lead_user is not null then
  if exists(select 1 from public.team_memberships where team_id=tid and user_id=lead_user and status='active') then
   raise exception 'Duplicate active membership' using errcode='23505';end if;
  insert into public.team_memberships(team_id,user_id,membership_role,status,joined_at,left_at,removed_by,added_by)
   values(tid,lead_user,'team_lead','active',pg_catalog.statement_timestamp(),null,null,actor);
  update public.teams set team_lead_user_id=lead_user where id=tid;
 end if;
 -- Automatic Master Chat membership awaits policy. Audit/notifications: M5.12.
 return pg_catalog.jsonb_build_object('teamId',tid,'workspaceId',wid,'chatChannelId',chid);
end $$;
revoke all on function public.create_team(uuid,text,text,uuid,uuid) from public,anon,authenticated,service_role;
grant execute on function public.create_team(uuid,text,text,uuid,uuid) to authenticated;
commit;
