begin;
-- Shared private write validator retains M6.6 ownership/Workspace/Team/Project
-- policy. Only the metadata-edit path permits paused state; no RLS read widening.
create function public.require_development_project_write(target_project uuid,allow_paused boolean) returns public.development_projects
 language plpgsql security definer set search_path='' as $$
declare actor uuid;p public.development_projects;w public.workspaces;source_cohort uuid;
begin
 actor:=public.current_platform_user_id();
 if actor is null then
  if auth.uid() is null then raise exception 'Authentication required' using errcode='28000';end if;
  raise exception 'Access denied' using errcode='42501';end if;

 select * into p from public.development_projects where id=target_project;
 select cohort_id into source_cohort from public.workspaces where id=p.primary_workspace_id;
 perform 1 from public.cohorts where id=source_cohort for share;
 if p.owner_team_id is not null then perform 1 from public.teams where id=p.owner_team_id for share;end if;
 if coalesce(allow_paused,false) then select * into p from public.development_projects where id=target_project for update;
 else select * into p from public.development_projects where id=target_project for share;end if;
 select * into w from public.workspaces where id=p.primary_workspace_id for share;
 if w.id is null or w.status<>'active' or w.visibility<>'private' or w.cohort_id is distinct from source_cohort then raise exception 'Access denied' using errcode='42501';end if;
 perform 1 from public.users where id=actor and account_status='active' for share;
 if not found then raise exception 'Access denied' using errcode='42501';end if;
 perform 1 from public.role_assignments where user_id=actor order by id for share;
 perform 1 from public.enrollments where user_id=actor order by id for share;
 perform 1 from public.project_memberships where project_id=p.id and user_id=actor order by id for share;
 if p.owner_team_id is not null then perform 1 from public.team_memberships where team_id=p.owner_team_id and user_id=actor order by id for share;end if;
 if public.current_platform_user_id() is distinct from actor or p.archived_at is not null or p.status not in ('active','paused') or (p.status='paused' and not coalesce(allow_paused,false)) then raise exception 'Access denied' using errcode='42501';end if;
 if p.project_type='team' then
  if w.workspace_type<>'TEAM' or w.team_id is distinct from p.owner_team_id or not public.has_active_project_membership(p.id) or coalesce(public.get_team_workspace_access(w.id)::text,'') not in ('member','team_lead') then raise exception 'Access denied' using errcode='42501';end if;
 elsif p.project_type='individual' then
  if p.owner_team_id is not null or w.team_id is not null or p.owner_user_id is distinct from actor or w.workspace_type<>'PERSONAL' or w.owner_user_id is distinct from actor then raise exception 'Access denied' using errcode='42501';end if;
 else
  if p.owner_team_id is not null or w.team_id is not null or p.owner_user_id is distinct from actor or w.workspace_type<>'CASE_STUDY' or w.owner_user_id is distinct from actor or w.cohort_id is null or not public.has_active_role_in_cohort('MASTER',w.cohort_id) then raise exception 'Access denied' using errcode='42501';end if;
 end if;
 return p;
end $$;

revoke all on function public.require_development_project_write(uuid,boolean) from public,anon,authenticated,service_role;
create or replace function public.require_development_object_write(target_project uuid,target_workspace uuid) returns void
 language plpgsql security definer set search_path='' as $$
declare p public.development_projects;
begin
 p:=public.require_development_project_write(target_project,false);
 if p.primary_workspace_id is distinct from target_workspace then raise exception 'Access denied' using errcode='42501';end if;
end $$;
-- Narrow authorized metadata lookup enables paused -> active while ordinary
-- Project/Object/Relationship RLS continues to require active Project state.
create function public.get_development_project_metadata_for_edit(target_project uuid) returns jsonb
 language plpgsql security definer set search_path='' as $$
begin return to_jsonb(public.require_development_project_write(target_project,true));end $$;
create function public.update_project_metadata(target_project uuid,changes jsonb) returns jsonb
 language plpgsql security definer set search_path='' as $$
declare p public.development_projects;next_name text;next_description text;next_stage text;next_status public.development_project_status;
begin
 p:=public.require_development_project_write(target_project,true);
 select * into p from public.development_projects where id=target_project for update;
 -- Concurrent metadata updates serialize on the same canonical row.
 if p.archived_at is not null or p.status not in ('active','paused') then raise exception 'Access denied' using errcode='42501';end if;
 if changes is null or jsonb_typeof(changes)<>'object' or changes='{}' or exists(select 1 from jsonb_object_keys(changes) k where k not in ('name','description','status','current_stage')) then raise exception 'Invalid metadata input' using errcode='22023';end if;
 if (changes ? 'name' and (jsonb_typeof(changes->'name')<>'string' or length(regexp_replace(changes->>'name','^\s+|\s+$','','g'))=0 or length(regexp_replace(changes->>'name','^\s+|\s+$','','g'))>200))
 or (changes ? 'description' and jsonb_typeof(changes->'description') not in ('string','null'))
 or (changes ? 'current_stage' and (jsonb_typeof(changes->'current_stage') not in ('string','null') or (jsonb_typeof(changes->'current_stage')='string' and length(regexp_replace(changes->>'current_stage','^\s+|\s+$','','g'))=0)))
 or (changes ? 'status' and (jsonb_typeof(changes->'status')<>'string' or changes->>'status' not in ('active','paused','completed'))) then raise exception 'Invalid metadata input' using errcode='22023';end if;
 next_name:=case when changes ? 'name' then regexp_replace(changes->>'name','^\s+|\s+$','','g') else p.name end;
 next_description:=case when changes ? 'description' then changes->>'description' else p.description end;
 next_stage:=case when changes ? 'current_stage' then regexp_replace(changes->>'current_stage','^\s+|\s+$','','g') else p.current_stage end;
 next_status:=case when changes ? 'status' then (changes->>'status')::public.development_project_status else p.status end;
 if (next_name,next_description,next_stage,next_status) is not distinct from (p.name,p.description,p.current_stage,p.status) then return to_jsonb(p);end if;
 -- Only the four approved columns plus update metadata are written. M6.10 will
 -- retrofit atomic PROJECT_METADATA_UPDATED/PROJECT_STAGE_CHANGED history here.
 update public.development_projects set name=next_name,description=next_description,current_stage=next_stage,status=next_status,updated_at=clock_timestamp() where id=p.id returning * into p;
 return to_jsonb(p);
end $$;
revoke all on function public.get_development_project_metadata_for_edit(uuid) from public,anon,authenticated,service_role;
revoke all on function public.update_project_metadata(uuid,jsonb) from public,anon,authenticated,service_role;
grant execute on function public.get_development_project_metadata_for_edit(uuid) to authenticated;
grant execute on function public.update_project_metadata(uuid,jsonb) to authenticated;
commit;
