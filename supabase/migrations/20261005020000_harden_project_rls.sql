begin;
-- Defense in depth: any archive timestamp makes the Project non-active.
create or replace function public.can_read_development_project(target_project uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.development_projects p join public.workspaces w on w.id=p.primary_workspace_id
 where p.id=target_project and p.status='active' and p.archived_at is null and w.status='active' and w.visibility='private' and public.current_platform_user_id() is not null and (
  (p.project_type='individual' and p.owner_user_id=public.current_platform_user_id() and p.owner_team_id is null
   and w.workspace_type='PERSONAL' and w.owner_user_id=p.owner_user_id and w.team_id is null)
  or (p.project_type='team' and w.workspace_type='TEAM' and w.team_id=p.owner_team_id and public.get_team_workspace_access(w.id) is not null and public.has_active_project_membership(p.id))
  or (p.project_type='instructor_case_study' and p.owner_user_id=public.current_platform_user_id() and p.owner_team_id is null
   and w.workspace_type='CASE_STUDY' and w.owner_user_id=p.owner_user_id and w.team_id is null
   and w.cohort_id is not null and public.has_active_role_in_cohort('MASTER',w.cohort_id))));
$$;
alter table public.development_projects enable row level security;
revoke all on public.development_projects from public,anon,authenticated,service_role;
grant select on public.development_projects to authenticated;
alter table public.project_memberships enable row level security;
revoke all on public.project_memberships from public,anon,authenticated,service_role;
alter table public.project_program_links enable row level security;
revoke all on public.project_program_links from public,anon,authenticated,service_role;
grant select on public.project_program_links to authenticated;
alter table public.development_objects enable row level security;
revoke all on public.development_objects from public,anon,authenticated,service_role;
grant select on public.development_objects to authenticated;
alter table public.development_object_relationships enable row level security;
revoke all on public.development_object_relationships from public,anon,authenticated,service_role;
grant select on public.development_object_relationships to authenticated;
alter table public.problem_details enable row level security;
revoke all on public.problem_details from public,anon,authenticated,service_role;
grant select on public.problem_details to authenticated;
alter table public.idea_details enable row level security;
revoke all on public.idea_details from public,anon,authenticated,service_role;
grant select on public.idea_details to authenticated;
alter table public.change_log enable row level security;
revoke all on public.change_log from public,anon,authenticated,service_role;
grant select on public.change_log to authenticated;
-- Existing restrictive mutation guards and scoped SELECT policies remain.
-- Definer is limited to a verified caller-bound boolean; no supplied actor.
revoke all on function public.can_read_development_project(uuid) from public,anon,authenticated,service_role;
grant execute on function public.can_read_development_project(uuid) to authenticated;
commit;
