begin;
-- RLS joins repeatedly evaluate reviewer predicates. Do not enter the expensive
-- scope validator for unrelated requesters or historical submissions. These are
-- necessary conditions already enforced by the original predicate; positive
-- authorization still requires the unchanged complete current-scope validator.
create or replace function public.can_review_submission(target_submission uuid) returns boolean
language plpgsql stable security definer set search_path='' as $$
begin
 if not exists(select 1 from public.submissions s where s.id=target_submission
  and s.reviewer_user_id=public.current_platform_user_id()
  and s.status in ('SUBMITTED','UNDER_REVIEW','REVISION_REQUESTED')) then
  return false;
 end if;
 return public.has_current_submission_reviewer(target_submission);
end$$;
revoke all on function public.can_review_submission(uuid) from public,anon,authenticated,service_role;
grant execute on function public.can_review_submission(uuid) to authenticated;
comment on function public.can_review_submission(uuid) is 'Exact original active-review authority with guaranteed cheap denial before full scope validation. No scope/status/role grant changes; approval retries still use has_current_submission_reviewer directly.';
commit;
