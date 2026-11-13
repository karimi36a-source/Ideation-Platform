begin;
-- Owner AND exact current cohort MASTER scope; no global ownership fallback.
create policy workspaces_master_owner_read on public.workspaces for select to authenticated using(
 workspace_type in ('MASTER','CASE_STUDY') and status='active' and visibility='private'
 and owner_user_id=public.current_platform_user_id() and cohort_id is not null
 and public.has_active_role_in_cohort('MASTER',cohort_id)
);
-- No mutation grants, TEAM membership, SHARED publication or archive access.
commit;
