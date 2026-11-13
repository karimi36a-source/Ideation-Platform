begin;
-- M15.17 metadata projection through existing M7/M6 self-scope authority.
-- Curriculum administration remains Admin-only. No table grants/policies change.
create function public.get_my_current_work_catalog(target_project uuid,target_workspace uuid,target_cohort uuid,target_team uuid default null)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare actor uuid;p public.development_projects;w public.workspaces;c public.cohorts;t public.teams;
 program public.programs;cv public.curriculum_versions;d record;answer jsonb;defs jsonb:='[]';sess jsonb;
begin
 actor:=public.current_platform_user_id();
 if actor is null then
  if auth.uid() is null then raise exception 'Authentication required' using errcode='28000';end if;
  return null;
 end if;
 select * into p from public.development_projects where id=target_project;
 select * into w from public.workspaces where id=target_workspace;
 select * into c from public.cohorts where id=target_cohort;
 if p.id is null or w.id is null or c.id is null or p.primary_workspace_id<>w.id
  or p.status<>'active' or p.archived_at is not null or w.status<>'active' or w.visibility<>'private'
  or c.status not in ('planned','active') or not public.can_read_development_project(p.id)
  or not exists(select 1 from public.enrollments e where e.user_id=actor and e.cohort_id=c.id and e.status='active' and e.enrollment_role='participant')
 then return null;end if;
 if p.project_type='individual' then
  if p.owner_user_id is distinct from actor or p.owner_team_id is not null or w.workspace_type<>'PERSONAL'
   or w.owner_user_id is distinct from actor or w.team_id is not null or target_team is not null then return null;end if;
 elsif p.project_type='team' then
  select * into t from public.teams where id=p.owner_team_id;
  if t.id is null or target_team is distinct from t.id or t.workspace_id<>w.id or w.team_id is distinct from t.id
   or t.cohort_id<>c.id or w.cohort_id is distinct from c.id or t.status<>'active' or t.archived_at is not null
   or coalesce(public.get_team_workspace_access(w.id),'') not in ('member','team_lead') then return null;end if;
 else return null;end if;
 select * into program from public.programs where id=c.program_id;
 select * into cv from public.curriculum_versions where id=c.curriculum_version_id and program_id=program.id;
 if program.id is null or program.status<>'active' or cv.id is null or cv.status<>'approved'
  or not exists(select 1 from public.project_program_links l where l.project_id=p.id and l.cohort_id=c.id and l.program_id=program.id and l.completed_at is null)
 then return null;end if;
 for d in select a.* from public.activity_definitions a join public.session_definitions s on s.id=a.session_definition_id
  where s.curriculum_version_id=cv.id and s.status='active' and a.status='active'
   and a.workspace_mode=case when t.id is null then 'Personal Workspace' else 'Team Workspace' end
  order by s.sequence,a.sequence
 loop
  answer:=public.resolve_activity_availability(d.id,p.id,w.id,t.id);
  if answer->>'available'='true' or exists(select 1 from public.activity_instances i
   where i.activity_definition_id=d.id and i.project_id=p.id and i.workspace_id=w.id and i.cohort_id=c.id
    and i.team_id is not distinct from t.id and i.status<>'archived' and public.can_read_activity_instance(i.id)) then
   defs:=defs||jsonb_build_array(jsonb_build_object('id',d.id,'session_definition_id',d.session_definition_id,'name',d.name,'workspace_mode',d.workspace_mode,'sequence',d.sequence,'status',d.status,'availability',answer));
  end if;
 end loop;
 select coalesce(jsonb_agg(jsonb_build_object('id',s.id,'curriculum_version_id',s.curriculum_version_id,'title',s.title,'session_number',s.session_number,'sequence',s.sequence,'status',s.status) order by s.sequence),'[]') into sess
 from public.session_definitions s where s.curriculum_version_id=cv.id and s.status='active' and exists(select 1 from jsonb_array_elements(defs) x where x->>'session_definition_id'=s.id::text);
 return jsonb_build_object('course',jsonb_build_object('id',program.id,'name',program.name,'status',program.status),
  'cohort',jsonb_build_object('id',c.id,'name',c.name,'program_id',c.program_id,'curriculum_version_id',cv.id,'status',c.status),
  'curriculum',jsonb_build_object('id',cv.id,'program_id',cv.program_id,'status',cv.status),'sessions',sess,'definitions',defs);
end $$;
revoke all on function public.get_my_current_work_catalog(uuid,uuid,uuid,uuid) from public,anon,authenticated,service_role;
grant execute on function public.get_my_current_work_catalog(uuid,uuid,uuid,uuid) to authenticated;
comment on function public.get_my_current_work_catalog(uuid,uuid,uuid,uuid) is 'M15.17 read-only self execution metadata; existing Project/Workspace/enrollment/M7 gates. No role-only authority, catalog administration, locked future metadata, private bodies, state mutation or progress model.';
commit;
