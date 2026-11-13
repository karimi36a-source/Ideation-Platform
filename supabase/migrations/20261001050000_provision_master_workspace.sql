begin;
-- Cohort-scoped idempotency, never one Workspace per Master globally.
create unique index workspaces_one_active_master_per_cohort on public.workspaces(owner_user_id,cohort_id)
 where workspace_type='MASTER' and status='active' and cohort_id is not null;
create function public.create_master_workspace(target_cohort uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid; w public.workspaces;
begin
 actor:=auth.uid();
 if actor is null then raise exception 'Authentication required' using errcode='28000';end if;
 if not public.has_active_role_in_cohort('MASTER',target_cohort) then raise exception 'Access denied' using errcode='42501';end if;
 -- Existing cohort commands also lock cohort before changing its primary grant.
 perform 1 from public.cohorts where id=target_cohort for update;
 if not found then raise exception 'Access denied' using errcode='42501';end if;
 perform 1 from public.users where id=actor and account_status='active' for share;
 if not found or not public.has_active_role_in_cohort('MASTER',target_cohort) then raise exception 'Access denied' using errcode='42501';end if;
 select * into w from public.workspaces where workspace_type='MASTER' and owner_user_id=actor and cohort_id=target_cohort and status='active';
 if found then return pg_catalog.to_jsonb(w);end if;
 insert into public.workspaces(workspace_type,name,owner_user_id,cohort_id,status,visibility,created_by,updated_by)
 values('MASTER','Master Workspace',actor,target_cohort,'active','private',actor,actor)
 on conflict(owner_user_id,cohort_id) where workspace_type='MASTER' and status='active' and cohort_id is not null do nothing returning * into w;
 if not found then select * into w from public.workspaces where workspace_type='MASTER' and owner_user_id=actor and cohort_id=target_cohort and status='active';end if;
 if w.id is null then raise exception 'Access denied' using errcode='42501';end if;
 return pg_catalog.to_jsonb(w);
end $$;
revoke all on function public.create_master_workspace(uuid) from public,anon,authenticated,service_role;
grant execute on function public.create_master_workspace(uuid) to authenticated;
-- Existing M4.3 RLS/resolver and M4.5 mutation denials remain authoritative.
commit;
