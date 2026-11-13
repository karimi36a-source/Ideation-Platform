begin;
-- M8.6 approved archive read policy: history retains CURRENT scope checks.
alter policy artifacts_scoped_read on public.artifacts using(public.can_read_development_project(project_id) and exists(select 1 from public.development_projects p where p.id=artifacts.project_id and p.primary_workspace_id=artifacts.workspace_id));
alter policy artifacts_read_guard on public.artifacts using(public.can_read_development_project(project_id) and exists(select 1 from public.development_projects p where p.id=artifacts.project_id and p.primary_workspace_id=artifacts.workspace_id));
-- Same shared-scope-before-Artifact locking order as M8.5. Definer writes the
-- two lifecycle fields only; no actor override or generic update API.
create function public.archive_artifact(target_artifact uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare a public.artifacts;actor uuid;
begin
 actor:=public.current_platform_user_id();
 if actor is null then
  if auth.uid() is null then raise exception 'Authentication required' using errcode='28000';end if;
  raise exception 'Access denied' using errcode='42501';end if;
 select * into a from public.artifacts where id=target_artifact;
 if a.id is null then raise exception 'Access denied' using errcode='42501';end if;
 perform public.require_development_object_write(a.project_id,a.workspace_id);
 select * into a from public.artifacts where id=target_artifact for update;
 if a.id is null or public.current_platform_user_id() is distinct from actor then raise exception 'Access denied' using errcode='42501';end if;
 if a.status='ARCHIVED' then return to_jsonb(a);end if;
 if a.status<>'ACTIVE' or a.archived_at is not null then raise exception 'Access denied' using errcode='42501';end if;
 update public.artifacts set status='ARCHIVED',archived_at=clock_timestamp() where id=a.id returning * into a;
 return to_jsonb(a);
end $$;
revoke all on function public.archive_artifact(uuid) from public,anon,authenticated,service_role;
grant execute on function public.archive_artifact(uuid) to authenticated;
comment on function public.archive_artifact(uuid) is 'M8.6 caller-bound idempotent archive only, preserving original timestamp/current pointer/Version/Object/link history. No restore or review workflow.';
comment on table public.artifacts is 'Stable Artifact identity. M8.6 active and archived reads require CURRENT canonical Project/Workspace authorization. Archive blocks normal mutations; no restore, public visibility or former-member access.';
commit;
