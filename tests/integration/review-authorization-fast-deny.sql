reset role;
create temporary table review_candidates(label text primary key,id uuid);
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into review_candidates select 'Personal',(public.submit_artifact((f.payload->>'artifactId')::uuid,(f.payload->>'initialVersionId')::uuid,i.id)->>'id')::uuid from submitted_fixtures f cross join instances i where f.label='Personal' and i.label='Individual';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
insert into review_candidates select 'Team',(public.submit_artifact((f.payload->>'artifactId')::uuid,(f.payload->>'initialVersionId')::uuid,i.id)->>'id')::uuid from submitted_fixtures f cross join instances i where f.label='Team' and i.label='Team';
create function pg_temp.review_equivalence() returns void language plpgsql as $$declare actor integer;s record;expected boolean;begin
 for actor in 6001..6008 loop
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(actor::text,12,'0'),true);
  for s in select id from review_candidates loop
   expected:=public.has_current_submission_reviewer(s.id) and exists(select 1 from public.submissions where id=s.id and status in ('SUBMITTED','UNDER_REVIEW','REVISION_REQUESTED'));
   assert public.can_review_submission(s.id)=expected,'Review authority changed';
  end loop;
 end loop;
end$$;
select pg_temp.review_equivalence();
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
do $$begin assert public.can_review_submission((select id from review_candidates where label='Team'));assert not public.can_review_submission('ffffffff-ffff-4fff-8fff-ffffffffffff');end$$;
select public.start_review(id) from review_candidates;
select pg_temp.review_equivalence();
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.approve_artifact((select id from review_candidates where label='Personal'),'Reviewed fixture');
select pg_temp.review_equivalence();
-- Current assignment loss still invalidates an otherwise active reviewer target.
update public.role_assignments set status='inactive' where user_id='00000000-0000-4000-8000-000000006002' and role_id=(select id from public.roles where code='MASTER');
select pg_temp.review_equivalence();
update public.role_assignments set status='active' where user_id='00000000-0000-4000-8000-000000006002' and role_id=(select id from public.roles where code='MASTER');
-- A fail-closed sentinel proves the full validator is never entered for cheap
-- denials, but is still mandatory for a positive candidate. Rolled back below.
create or replace function public.has_current_submission_reviewer(target_submission uuid) returns boolean language plpgsql stable security definer set search_path='' as $$begin raise exception 'Full validator entered' using errcode='P1401';end$$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006007',true);
do $$begin assert not public.can_review_submission((select id from review_candidates where label='Team'));end$$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
do $$begin
 assert not public.can_review_submission((select id from review_candidates where label='Personal'));
 begin perform public.can_review_submission((select id from review_candidates where label='Team'));raise exception 'Full validator bypassed';exception when sqlstate 'P1401' then null;end;
end$$;
select 'Review authorization exact-equivalence/current-role-loss/approved-history/cheap-denial/mandatory-positive-scope-validator PASS';
rollback;
