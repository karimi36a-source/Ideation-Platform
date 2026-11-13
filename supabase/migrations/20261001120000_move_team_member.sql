begin;
-- One transaction composes the existing narrow removal/addition operations.
-- Fixed path, verified identity and resource-only inputs; no new client grants.
create function public.move_team_member(target_user uuid,source_team uuid,destination_team uuid,move_reason text default null)
 returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid; src public.teams; dst public.teams; source_membership public.team_memberships;
 locked_cohort uuid; kind public.team_membership_role; removed jsonb; added jsonb; source_org uuid; target_org uuid;
begin
 actor:=public.current_platform_user_id();
 if actor is null then
  if auth.uid() is null then raise exception 'Authentication required' using errcode='28000';end if;
  raise exception 'Access denied' using errcode='42501';
 end if;
 if not public.can_manage_team(source_team) or not public.can_manage_team(destination_team) then raise exception 'Access denied' using errcode='42501';end if;
 if source_team=destination_team then raise exception 'Invalid move' using errcode='22023';end if;
 select * into src from public.teams where id=source_team;
 select * into dst from public.teams where id=destination_team;
 select p.organization_id into source_org from public.cohorts c join public.programs p on p.id=c.program_id where c.id=src.cohort_id;
 select p.organization_id into target_org from public.cohorts c join public.programs p on p.id=c.program_id where c.id=dst.cohort_id;
 if not ((public.has_active_role_in_organization('ADMIN',source_org) and public.has_active_role_in_organization('ADMIN',target_org))
  or ((public.has_active_role_in_cohort('MASTER',src.cohort_id) or public.has_active_role_in_team('MASTER',src.id))
   and (public.has_active_role_in_cohort('MASTER',dst.cohort_id) or public.has_active_role_in_team('MASTER',dst.id)))) then
  raise exception 'Access denied' using errcode='42501';end if;
 if src.cohort_id<>dst.cohort_id then raise exception 'Cross-Cohort move unavailable' using errcode='22023';end if;
 -- Same-cohort membership operations serialize here. Team locks are ordered so
 -- opposite-direction moves cannot lock the two Teams in opposite order.
 locked_cohort:=src.cohort_id;
 perform 1 from public.cohorts where id=locked_cohort for update;
 perform 1 from public.teams where id in (source_team,destination_team) order by id for update;
 select * into src from public.teams where id=source_team;
 select * into dst from public.teams where id=destination_team;
 if src.cohort_id<>locked_cohort or dst.cohort_id<>locked_cohort then raise exception 'Invalid move' using errcode='22023';end if;
 select p.organization_id into source_org from public.programs p join public.cohorts c on c.program_id=p.id where c.id=locked_cohort for share of p;
 target_org:=source_org;
 perform 1 from public.users where id=actor and account_status='active' for share;
 if not found then raise exception 'Access denied' using errcode='42501';end if;
 perform 1 from public.role_assignments a join public.roles r on r.id=a.role_id
 where a.user_id=actor and a.status='active' and a.starts_at<=statement_timestamp() and (a.ends_at is null or a.ends_at>statement_timestamp())
  and a.program_id is null and a.project_id is null and (
   (r.code='ADMIN' and a.organization_id=source_org and a.cohort_id is null and a.team_id is null)
   or (r.code='MASTER' and a.organization_id is null and a.cohort_id=locked_cohort and a.team_id is null)
   or (r.code='MASTER' and a.organization_id is null and a.cohort_id is null and a.team_id in (src.id,dst.id))) for share of a;
 if not ((public.has_active_role_in_organization('ADMIN',source_org) and public.has_active_role_in_organization('ADMIN',target_org))
  or ((public.has_active_role_in_cohort('MASTER',src.cohort_id) or public.has_active_role_in_team('MASTER',src.id))
   and (public.has_active_role_in_cohort('MASTER',dst.cohort_id) or public.has_active_role_in_team('MASTER',dst.id)))) then
  raise exception 'Access denied' using errcode='42501';end if;
 select * into source_membership from public.team_memberships where team_id=src.id and user_id=target_user and status='active' for update;
 if not found then raise exception 'No active membership' using errcode='22023';end if;
 kind:=case when source_membership.membership_role='mentor' then 'mentor'::public.team_membership_role else 'member'::public.team_membership_role end;
 -- Both nested functions recheck scope/eligibility under the held locks and
 -- retain history. Any error escapes, rolling back all source/target changes.
 removed:=public.remove_team_member(src.id,target_user,move_reason);
 added:=public.add_team_member(dst.id,target_user,kind);
 return jsonb_build_object('fromTeamId',src.id,'toTeamId',dst.id,
  'sourceMembershipId',removed->>'membershipId','targetMembershipId',added->>'membershipId','chatMembershipId',added->>'chatMembershipId');
 -- Audit/reason persistence and notifications remain deferred to M5.12.
end $$;
revoke all on function public.move_team_member(uuid,uuid,uuid,text) from public,anon,authenticated,service_role;
grant execute on function public.move_team_member(uuid,uuid,uuid,text) to authenticated;
commit;
