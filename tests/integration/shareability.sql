reset role;
create function pg_temp.share_request(kind text default 'PATENT_RECORD',source uuid default null,dest text default 'TEAM',target uuid default null,permission0 text default 'VIEW',mode0 text default 'SNAPSHOT') returns jsonb language sql as $$
 select jsonb_build_object('entityType',kind,'entityId',coalesce(source,pg_temp.research_source('Patent')),'destinationType',dest,'destinationId',coalesce(target,(select (payload->>'teamId')::uuid from acceptance_teams where label='B')),'permissionLevel',permission0,'shareMode',mode0)
$$;
create function pg_temp.share_denied(request jsonb,reason text) returns void language plpgsql as $$declare r jsonb;begin
 r:=public.resolve_shareability(request);assert r=jsonb_build_object('allowed',false,'deniedReason',reason),r::text;
end$$;
-- Known creator/member is not a Lead yet.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select pg_temp.share_denied(pg_temp.share_request(),'SHARE_AUTHORITY_DENIED');
do $$begin assert (public.resolve_shareability(pg_temp.share_request(source=>pg_temp.research_source('PersonalPatent'),target=>(select (payload->>'teamId')::uuid from acceptance_teams where label='A')))->>'allowed')::boolean;end$$;
select pg_temp.share_denied(pg_temp.share_request(source=>pg_temp.research_source('PersonalPatent')),'DESTINATION_SCOPE_DENIED');
select pg_temp.share_denied(pg_temp.share_request(source=>pg_temp.research_source('PersonalPatent'),target=>'ffffffff-ffff-4fff-8fff-ffffffffffff'),'DESTINATION_SCOPE_DENIED');
-- The canonical management operation appoints the Lead; no new SHARE grant table.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member(t.id,t.team_lead_user_id,'M13.3 isolated Lead transition') from public.teams t where t.id=(select (payload->>'teamId')::uuid from acceptance_teams where label='A') and t.team_lead_user_id is not null;
select public.assign_team_lead((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006004');
select public.assign_team_lead((select (payload->>'teamId')::uuid from acceptance_teams where label='B'),'00000000-0000-4000-8000-000000006007');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$declare r jsonb;k text;source uuid;begin
 foreach k in array array['PATENT_RECORD','EVIDENCE','DEVELOPMENT_OBJECT','ARTIFACT'] loop
  source:=pg_temp.research_source(case k when 'PATENT_RECORD' then 'Patent' when 'EVIDENCE' then 'Evidence' when 'DEVELOPMENT_OBJECT' then 'Gap' else 'Landscape' end);
  r:=public.resolve_shareability(pg_temp.share_request(k,source));assert (r->>'allowed')::boolean,r::text;
  assert r->'allowedModes'='["SNAPSHOT"]'::jsonb and r->'allowedPermissionLevels'='["VIEW","COMMENT"]'::jsonb;
  assert (select count(*) from jsonb_object_keys(r))=6;
 end loop;
 assert (public.resolve_shareability(pg_temp.share_request(permission0=>'COMMENT'))->>'allowed')::boolean;
end$$;
select 'SHAREABILITY_ROW='||public.resolve_shareability(pg_temp.share_request())::text;
reset role;
-- Remaining canonical entity families, without exposing File storage metadata.
do $$declare p jsonb;r jsonb;f jsonb;entry uuid;begin
 select payload into p from logged_projects where label='Team';
 r:=public.request_file_upload((p->>'primary_workspace_id')::uuid,(p->>'id')::uuid,'shareability.txt','text/plain',3);
 insert into storage.objects(bucket_id,name,metadata) values('fici-private-files',r->>'storage_reference','{"size":3,"mimetype":"text/plain"}');
 f:=public.register_uploaded_file((r->>'id')::uuid);
 assert (public.resolve_shareability(pg_temp.share_request('FILE',(f->>'id')::uuid))->>'allowed')::boolean;
 select payload into p from logged_projects where label='Individual';
 insert into public.scamper_entries(activity_instance_id,project_id,workspace_id,created_by,scamper_type,original_element,proposed_change,result_text)
 select id,(p->>'id')::uuid,(p->>'primary_workspace_id')::uuid,public.current_platform_user_id(),'SUBSTITUTE','Original','Proposed','Result' from instances where label='Individual' returning id into entry;
 assert (public.resolve_shareability(pg_temp.share_request('SCAMPER_ENTRY',entry,target=>(select (payload->>'teamId')::uuid from acceptance_teams where label='A')))->>'allowed')::boolean;
end$$;
set local role authenticated;
select pg_temp.share_denied(pg_temp.share_request(mode0=>'LIVE_REFERENCE'),'MODE_NOT_ALLOWED');
select pg_temp.share_denied(pg_temp.share_request(permission0=>'COLLABORATE'),'PERMISSION_NOT_ALLOWED');
select pg_temp.share_denied(pg_temp.share_request(dest=>'COHORT'),'DESTINATION_SCOPE_DENIED');
select pg_temp.share_denied(pg_temp.share_request(dest=>'USER'),'DESTINATION_SCOPE_DENIED');
select pg_temp.share_denied(pg_temp.share_request(dest=>'WORKSPACE'),'DESTINATION_SCOPE_DENIED');
select pg_temp.share_denied(pg_temp.share_request(target=>'ffffffff-ffff-4fff-8fff-ffffffffffff'),'DESTINATION_INVALID');
select pg_temp.share_denied(pg_temp.share_request(source=>'ffffffff-ffff-4fff-8fff-ffffffffffff'),'SOURCE_ACCESS_DENIED');
select pg_temp.share_denied(pg_temp.share_request(kind=>'SEARCH_LOG'),'ENTITY_NOT_SHAREABLE');
select pg_temp.share_denied(pg_temp.share_request()||'{"sharedBy":"forged"}','VALIDATION_ERROR');
select pg_temp.share_denied(pg_temp.share_request()||'{"entityId":null}','VALIDATION_ERROR');
reset role;
-- Source Lead identity must agree with the canonical Team pointer.
update public.teams set team_lead_user_id=null where id=(select (payload->>'teamId')::uuid from acceptance_teams where label='A');
set local role authenticated;
select pg_temp.share_denied(pg_temp.share_request(),'SHARE_AUTHORITY_DENIED');
reset role;
update public.teams set team_lead_user_id='00000000-0000-4000-8000-000000006004' where id=(select (payload->>'teamId')::uuid from acceptance_teams where label='A');
create temporary table resolver_master as select ra.id from public.role_assignments ra join public.roles r on r.id=ra.role_id
 where r.code='MASTER' and ra.user_id='00000000-0000-4000-8000-000000006002' and ra.cohort_id=(select id from acceptance_cohorts where label='Test');
grant select on resolver_master to authenticated;
set local role authenticated;
do $$begin assert (public.resolve_shareability(pg_temp.share_request(dest=>'MASTER',target=>(select id from resolver_master)))->>'allowed')::boolean;end$$;
select pg_temp.share_denied(pg_temp.share_request(dest=>'MASTER',target=>'00000000-0000-4000-8000-000000006002'),'DESTINATION_INVALID');
reset role;
update public.role_assignments set status='inactive' where id=(select id from resolver_master);
set local role authenticated;
select pg_temp.share_denied(pg_temp.share_request(dest=>'MASTER',target=>(select id from resolver_master)),'DESTINATION_INVALID');
reset role;
update public.role_assignments set status='active',starts_at=statement_timestamp()-interval '2 days',ends_at=statement_timestamp()-interval '1 day' where id=(select id from resolver_master);
set local role authenticated;
select pg_temp.share_denied(pg_temp.share_request(dest=>'MASTER',target=>(select id from resolver_master)),'DESTINATION_INVALID');
reset role;
update public.role_assignments set starts_at=statement_timestamp()-interval '1 day',ends_at=null where id=(select id from resolver_master);
-- VIEW/COMMENT recipient records are inert, never source SHARE authority.
insert into public.shares(shared_entity_type,shared_entity_id,destination_type,destination_id,permission_level,share_mode)
 select 'PATENT_RECORD',pg_temp.research_source('Patent'),'TEAM',(payload->>'teamId')::uuid,p,'SNAPSHOT' from acceptance_teams cross join unnest(array['VIEW','COMMENT']::public.share_permission_level[]) p where label='B';
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006007',true);
select pg_temp.share_denied(pg_temp.share_request(),'SOURCE_ACCESS_DENIED');
reset role;
do $$declare actor text;begin foreach actor in array array['00000000-0000-4000-8000-000000006001','00000000-0000-4000-8000-000000006002','00000000-0000-4000-8000-000000006008'] loop
 perform set_config('request.jwt.claim.sub',actor,true);
 assert not (public.resolve_shareability(pg_temp.share_request())->>'allowed')::boolean;
end loop;end$$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
-- Withdraw current enrollment without erasing membership/authorship.
update public.enrollments set status='withdrawn' where user_id='00000000-0000-4000-8000-000000006004' and cohort_id=(select id from acceptance_cohorts where label='Test');
set local role authenticated;
select pg_temp.share_denied(pg_temp.share_request(),'SOURCE_ACCESS_DENIED');
reset role;
insert into public.enrollments(cohort_id,user_id,enrollment_role,status)
 select id,'00000000-0000-4000-8000-000000006004','participant','active' from acceptance_cohorts where label='Test';
-- Archived Evidence source remains private and non-shareable.
update public.evidence set archived_at=clock_timestamp() where id=pg_temp.research_source('Evidence');
set local role authenticated;
select pg_temp.share_denied(pg_temp.share_request('EVIDENCE',pg_temp.research_source('Evidence')),'SOURCE_RESTRICTED');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006004','M13.3 current authority regression');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select pg_temp.share_denied(pg_temp.share_request(),'SOURCE_ACCESS_DENIED');
select pg_temp.share_denied(pg_temp.share_request(source=>pg_temp.research_source('PersonalPatent'),target=>(select (payload->>'teamId')::uuid from acceptance_teams where label='A')),'DESTINATION_SCOPE_DENIED');
reset role;
-- Future membership is a new trusted fixture row, never a rewrite of history.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
insert into public.team_memberships(team_id,user_id,membership_role,joined_at,status,added_by)
 select (payload->>'teamId')::uuid,'00000000-0000-4000-8000-000000006004','team_lead',statement_timestamp()+interval '1 day','active',public.current_platform_user_id() from acceptance_teams where label='A';
update public.teams set team_lead_user_id='00000000-0000-4000-8000-000000006004' where id=(select (payload->>'teamId')::uuid from acceptance_teams where label='A');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select pg_temp.share_denied(pg_temp.share_request(),'SOURCE_ACCESS_DENIED');
reset role;
select set_config('request.jwt.claim.sub','',true);
select pg_temp.share_denied(pg_temp.share_request(),'UNAUTHENTICATED');
do $$begin
 assert not has_function_privilege('anon','public.resolve_shareability(jsonb)','EXECUTE');
 assert not has_function_privilege('service_role','public.resolve_shareability(jsonb)','EXECUTE');
 assert has_function_privilege('authenticated','public.resolve_shareability(jsonb)','EXECUTE');
 assert exists(select 1 from pg_proc where oid='public.resolve_shareability(jsonb)'::regprocedure and prosecdef and proconfig=array['search_path=""']);
 assert (select count(*) from public.shares)=2,'Resolver must not create Shares';
 assert not exists(select 1 from public.share_snapshots);
end$$;
select 'M13.3 exact-current-Lead/Personal/source-scope/destination/scoped-MASTER/SNAPSHOT/VIEW-COMMENT/deferred/re-share/privacy/no-writes PASS';
rollback;
