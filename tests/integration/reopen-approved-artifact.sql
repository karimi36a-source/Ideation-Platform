\set ON_ERROR_STOP on
begin;

insert into auth.users(id,email) select ('00000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'reopen-'||n||'@example.test' from generate_series(9101,9105) n;
select public.provision_user_profile(id,'active') from auth.users where email like 'reopen-%@example.test';
insert into public.role_assignments(user_id,role_id,organization_id,assigned_by) values
 ('00000000-0000-4000-8000-000000009101','00000000-0000-4000-8000-000000000101','00000000-0000-4000-8000-000000000501','00000000-0000-4000-8000-000000009101'),
 ('00000000-0000-4000-8000-000000009105','00000000-0000-4000-8000-000000000103','00000000-0000-4000-8000-000000000501','00000000-0000-4000-8000-000000009101');

-- Canonical Personal scope.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000009103',true);
select public.create_personal_workspace();
create temporary table reopen_scope as select id workspace_id from public.workspaces where owner_user_id='00000000-0000-4000-8000-000000009103' and workspace_type='PERSONAL';
reset role;
insert into public.development_projects(id,name,project_type,owner_user_id,primary_workspace_id)
 select '00000000-0000-4000-8000-000000091001','Reopen Project','individual','00000000-0000-4000-8000-000000009103',workspace_id from reopen_scope;
insert into public.artifacts(id,project_id,workspace_id,artifact_type,title,created_by,review_required,approval_required)
 select '00000000-0000-4000-8000-000000092001','00000000-0000-4000-8000-000000091001',workspace_id,'PROBLEM_BANK','Approved Artifact','00000000-0000-4000-8000-000000009103',true,true from reopen_scope;
insert into public.artifact_versions(id,artifact_id,version_number,content_snapshot,change_summary,status,created_by,approved_by,approved_at,approval_note)
 values('00000000-0000-4000-8000-000000093001','00000000-0000-4000-8000-000000092001',1,'{"canonical":{"objectId":"00000000-0000-4000-8000-000000094001"},"nested":[1,{"kept":true}]}','Approved source','CURRENT','00000000-0000-4000-8000-000000009103','00000000-0000-4000-8000-000000009102','2026-10-07 12:00:00+00','Approved note');
update public.artifacts set current_version_id='00000000-0000-4000-8000-000000093001' where id='00000000-0000-4000-8000-000000092001';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000009103',true);
create temporary table reopen_objects as select public.create_development_object('00000000-0000-4000-8000-000000091001',(select workspace_id from reopen_scope),'PROBLEM','Canonical Problem','Never cloned',null) payload;
reset role;
insert into public.artifact_object_links(artifact_id,artifact_version_id,development_object_id,role_in_artifact,sequence)
 select '00000000-0000-4000-8000-000000092001','00000000-0000-4000-8000-000000093001',(payload->>'id')::uuid,'source',0 from reopen_objects;
create temporary table source_before as select to_jsonb(v) data from public.artifact_versions v where id='00000000-0000-4000-8000-000000093001';
create temporary table object_count_before as select count(*) n from public.development_objects;
create temporary table reopen_results(label text primary key,payload jsonb);grant select,insert on reopen_results to authenticated;

set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000009103',true);
insert into reopen_results values('First',public.reopen_approved_artifact('00000000-0000-4000-8000-000000092001'));
reset role;
do $$declare r jsonb;begin
 select payload into r from reopen_results where label='First';
 assert r->>'sourceVersionId'='00000000-0000-4000-8000-000000093001' and r->>'currentVersionId'='00000000-0000-4000-8000-000000093001';
 assert r->'version'->>'status'='DRAFT' and (r->'version'->>'version_number')::int=2 and r->'version'->>'previous_version_id'='00000000-0000-4000-8000-000000093001';
 assert r->'version'->'content_snapshot'=(select content_snapshot from public.artifact_versions where id='00000000-0000-4000-8000-000000093001');
 assert r->'version'->'version_label'='null'::jsonb and r->'version'->'change_summary'='null'::jsonb and r->'version'->'approved_by'='null'::jsonb and r->'version'->'approved_at'='null'::jsonb and r->'version'->'approval_note'='null'::jsonb;
 assert (select data from source_before)=(select to_jsonb(v) from public.artifact_versions v where id='00000000-0000-4000-8000-000000093001'),'CURRENT source changed';
 assert (select current_version_id from public.artifacts where id='00000000-0000-4000-8000-000000092001')='00000000-0000-4000-8000-000000093001';
 assert (select status from public.artifacts where id='00000000-0000-4000-8000-000000092001')='ACTIVE';
 assert (select count(*) from public.artifact_object_links where artifact_version_id=(r->'version'->>'id')::uuid)=0 and (select count(*) from public.artifact_object_links where artifact_version_id='00000000-0000-4000-8000-000000093001')=1;
 assert (select count(*) from public.development_objects)=(select n from object_count_before);
 assert not exists(select 1 from public.submissions where artifact_version_id=(r->'version'->>'id')::uuid);
 assert not exists(select 1 from public.review_actions ra join public.submissions s on s.id=ra.submission_id where s.artifact_version_id=(r->'version'->>'id')::uuid);
 assert (select count(*) from public.audit_events where event_type='ARTIFACT_REOPENED' and entity_id='00000000-0000-4000-8000-000000092001' and actor_user_id='00000000-0000-4000-8000-000000009103' and metadata='{}')=1;
end $$;

-- Numbering follows MAX while lineage always follows the exact current pointer.
insert into public.artifact_versions(id,artifact_id,version_number,content_snapshot,status,created_by,previous_version_id)
 values('00000000-0000-4000-8000-000000093009','00000000-0000-4000-8000-000000092001',9,'{"historical":true}','SUPERSEDED','00000000-0000-4000-8000-000000009103','00000000-0000-4000-8000-000000093001');
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000009103',true);
insert into reopen_results values('Historical',public.reopen_approved_artifact('00000000-0000-4000-8000-000000092001'));
reset role;
do $$begin assert (select payload->'version'->>'version_number' from reopen_results where label='Historical')='10';assert (select payload->'version'->>'previous_version_id' from reopen_results where label='Historical')='00000000-0000-4000-8000-000000093001';end$$;

-- Fail after number allocation but before Draft insertion, after Draft insertion
-- (audit BEFORE trigger), and after audit insertion. Every boundary rolls back.
create function pg_temp.fail_reopen_draft() returns trigger language plpgsql as $$begin if new.artifact_id='00000000-0000-4000-8000-000000092001' and new.status='DRAFT' then raise exception 'injected after allocation' using errcode='P0002';end if;return new;end$$;
create trigger reopen_fail_draft before insert on public.artifact_versions for each row execute function pg_temp.fail_reopen_draft();
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000009103',true);
do $$begin begin perform public.reopen_approved_artifact('00000000-0000-4000-8000-000000092001');raise exception 'injection bypass';exception when no_data_found then null;end;end$$;
reset role;drop trigger reopen_fail_draft on public.artifact_versions;
create function pg_temp.fail_reopen_audit_before() returns trigger language plpgsql as $$begin if new.event_type='ARTIFACT_REOPENED' then raise exception 'injected before audit' using errcode='P0002';end if;return new;end$$;
create trigger reopen_fail_before before insert on public.audit_events for each row execute function pg_temp.fail_reopen_audit_before();
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000009103',true);
do $$begin begin perform public.reopen_approved_artifact('00000000-0000-4000-8000-000000092001');raise exception 'injection bypass';exception when no_data_found then null;end;end$$;
reset role;drop trigger reopen_fail_before on public.audit_events;
create function pg_temp.fail_reopen_audit_after() returns trigger language plpgsql as $$begin if new.event_type='ARTIFACT_REOPENED' then raise exception 'injected after audit' using errcode='P0002';end if;return new;end$$;
create trigger reopen_fail_after after insert on public.audit_events for each row execute function pg_temp.fail_reopen_audit_after();
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000009103',true);
do $$begin begin perform public.reopen_approved_artifact('00000000-0000-4000-8000-000000092001');raise exception 'injection bypass';exception when no_data_found then null;end;end$$;
reset role;drop trigger reopen_fail_after on public.audit_events;
do $$begin assert (select count(*) from public.artifact_versions where artifact_id='00000000-0000-4000-8000-000000092001')=4;assert (select count(*) from public.audit_events where event_type='ARTIFACT_REOPENED' and entity_id='00000000-0000-4000-8000-000000092001')=2;assert (select data from source_before)=(select to_jsonb(v) from public.artifact_versions v where id='00000000-0000-4000-8000-000000093001');end$$;

-- Personal privacy and direct mutation attacks.
set local role authenticated;
do $$declare u uuid;begin
 foreach u in array array['00000000-0000-4000-8000-000000009101','00000000-0000-4000-8000-000000009102','00000000-0000-4000-8000-000000009104','00000000-0000-4000-8000-000000009105']::uuid[] loop
  perform set_config('request.jwt.claim.sub',u::text,true);begin perform public.reopen_approved_artifact('00000000-0000-4000-8000-000000092001');raise exception 'foreign actor accepted';exception when insufficient_privilege then null;end;
 end loop;
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000009103',true);
 begin insert into public.artifact_versions(artifact_id,version_number,content_snapshot,status,created_by) values('00000000-0000-4000-8000-000000092001',99,'{}','DRAFT',auth.uid());raise exception 'direct Draft accepted';exception when insufficient_privilege then null;end;
 begin update public.artifacts set current_version_id=(select (payload->'version'->>'id')::uuid from reopen_results where label='First') where id='00000000-0000-4000-8000-000000092001';raise exception 'pointer mutation accepted';exception when insufficient_privilege then null;end;
 begin update public.artifact_versions set content_snapshot='{}' where id='00000000-0000-4000-8000-000000093001';raise exception 'CURRENT mutation accepted';exception when insufficient_privilege then null;end;
 begin insert into public.audit_events(actor_user_id,event_type,entity_type,entity_id,scope_type,scope_id) values(auth.uid(),'ARTIFACT_REOPENED','artifact','00000000-0000-4000-8000-000000092001','artifact','00000000-0000-4000-8000-000000092001');raise exception 'fake audit accepted';exception when insufficient_privilege then null;end;
end$$;
reset role;

-- TEAM uses the exact existing Version-write authority: active Team + Project
-- membership is required; role labels, Master status, and history do not widen it.
create temporary table reopen_cohort(id uuid);create temporary table reopen_team(payload jsonb);grant select,insert on reopen_cohort,reopen_team to authenticated;
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000009101',true);
insert into reopen_cohort values((public.create_cohort('00000000-0000-4000-8000-000000000601','00000000-0000-4000-8000-000000000602','Reopen Cohort','2026-10-01',null,'00000000-0000-4000-8000-000000009102','active','{}')->>'id')::uuid);
reset role;insert into public.enrollments(cohort_id,user_id,enrollment_role,status) select id,'00000000-0000-4000-8000-000000009103','participant','active' from reopen_cohort;
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000009102',true);
insert into reopen_team select public.create_team(id,'Reopen Team') from reopen_cohort;
select public.add_team_member((select (payload->>'teamId')::uuid from reopen_team),'00000000-0000-4000-8000-000000009103','member');reset role;
insert into public.development_projects(id,name,project_type,owner_team_id,primary_workspace_id)
 select '00000000-0000-4000-8000-000000091010','Team Reopen','team',(payload->>'teamId')::uuid,(payload->>'workspaceId')::uuid from reopen_team;
insert into public.project_memberships(project_id,user_id) values('00000000-0000-4000-8000-000000091010','00000000-0000-4000-8000-000000009103');
insert into public.artifacts(id,project_id,workspace_id,artifact_type,title,created_by)
 select '00000000-0000-4000-8000-000000092010','00000000-0000-4000-8000-000000091010',(payload->>'workspaceId')::uuid,'PROBLEM_BANK','Team Approved','00000000-0000-4000-8000-000000009103' from reopen_team;
insert into public.artifact_versions(id,artifact_id,version_number,content_snapshot,status,created_by,approved_by,approved_at)
 values('00000000-0000-4000-8000-000000093010','00000000-0000-4000-8000-000000092010',1,'{"team":"canonical"}','CURRENT','00000000-0000-4000-8000-000000009103','00000000-0000-4000-8000-000000009102',clock_timestamp());
update public.artifacts set current_version_id='00000000-0000-4000-8000-000000093010' where id='00000000-0000-4000-8000-000000092010';
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000009103',true);
insert into reopen_results values('Team',public.reopen_approved_artifact('00000000-0000-4000-8000-000000092010'));
do $$begin assert (select payload->'version'->>'previous_version_id' from reopen_results where label='Team')='00000000-0000-4000-8000-000000093010';end$$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000009104',true);do $$begin begin perform public.reopen_approved_artifact('00000000-0000-4000-8000-000000092010');raise exception 'Team B actor accepted';exception when insufficient_privilege then null;end;end$$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000009102',true);select public.remove_team_member((select (payload->>'teamId')::uuid from reopen_team),'00000000-0000-4000-8000-000000009103');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000009103',true);do $$begin begin perform public.reopen_approved_artifact('00000000-0000-4000-8000-000000092010');raise exception 'removed Team member accepted';exception when insufficient_privilege then null;end;end$$;
reset role;

-- Archived, null-current, wrong-status, missing-approval, foreign and missing
-- pointers all fail closed; trusted fixture corruption is restored or rolled back.
insert into public.artifacts(id,project_id,workspace_id,artifact_type,title,created_by,status,archived_at)
 select '00000000-0000-4000-8000-000000092002','00000000-0000-4000-8000-000000091001',workspace_id,'PROBLEM_BANK','Archived','00000000-0000-4000-8000-000000009103','ARCHIVED',clock_timestamp() from reopen_scope;
insert into public.artifacts(id,project_id,workspace_id,artifact_type,title,created_by)
 select '00000000-0000-4000-8000-000000092003','00000000-0000-4000-8000-000000091001',workspace_id,'PROBLEM_BANK','No current','00000000-0000-4000-8000-000000009103' from reopen_scope;
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000009103',true);
do $$declare a uuid;begin foreach a in array array['00000000-0000-4000-8000-000000092002','00000000-0000-4000-8000-000000092003']::uuid[] loop begin perform public.reopen_approved_artifact(a);raise exception 'invalid Artifact accepted';exception when insufficient_privilege then null;end;end loop;end$$;
reset role;
update public.artifact_versions set status='SUPERSEDED' where id='00000000-0000-4000-8000-000000093001';
set local role authenticated;do $$begin begin perform public.reopen_approved_artifact('00000000-0000-4000-8000-000000092001');raise exception 'non-current pointer accepted';exception when invalid_parameter_value then null;end;end$$;reset role;
update public.artifact_versions set status='CURRENT' where id='00000000-0000-4000-8000-000000093001';
-- Flush valid final-state checks before trusted corruption-only DDL. Keep
-- deferred mode for the deliberately invalid states below, rolled back at end.
set constraints all immediate;
set constraints all deferred;
alter table public.artifact_versions drop constraint artifact_versions_approved_identity;
insert into public.artifact_versions(id,artifact_id,version_number,content_snapshot,status,created_by)
 values('00000000-0000-4000-8000-000000093003','00000000-0000-4000-8000-000000092003',1,'{}','CURRENT','00000000-0000-4000-8000-000000009103');
update public.artifacts set current_version_id='00000000-0000-4000-8000-000000093003' where id='00000000-0000-4000-8000-000000092003';
set local role authenticated;do $$begin begin perform public.reopen_approved_artifact('00000000-0000-4000-8000-000000092003');raise exception 'missing approval accepted';exception when invalid_parameter_value then null;end;end$$;reset role;
set constraints all immediate;
set constraints all deferred;
alter table public.artifacts drop constraint artifacts_current_version_same_artifact;
update public.artifacts set current_version_id='00000000-0000-4000-8000-000000093009' where id='00000000-0000-4000-8000-000000092003';
set local role authenticated;do $$begin begin perform public.reopen_approved_artifact('00000000-0000-4000-8000-000000092003');raise exception 'foreign pointer accepted';exception when invalid_parameter_value then null;end;end$$;reset role;
update public.artifacts set current_version_id='ffffffff-ffff-4fff-8fff-ffffffffffff' where id='00000000-0000-4000-8000-000000092003';
set local role authenticated;do $$begin begin perform public.reopen_approved_artifact('00000000-0000-4000-8000-000000092003');raise exception 'missing pointer accepted';exception when invalid_parameter_value then null;end;end$$;reset role;

set local role anon;select set_config('request.jwt.claim.sub','',true);do $$begin begin perform public.reopen_approved_artifact('00000000-0000-4000-8000-000000092001');raise exception 'anonymous accepted';exception when insufficient_privilege then null;end;end$$;reset role;
do $$begin assert (select prosecdef and proconfig @> array['search_path=""'] from pg_proc where oid='public.reopen_approved_artifact(uuid)'::regprocedure);assert not has_function_privilege('anon','public.reopen_approved_artifact(uuid)','EXECUTE');assert not has_function_privilege('service_role','public.reopen_approved_artifact(uuid)','EXECUTE');end$$;

rollback;
\echo M8.12 AT-VER-001/002 reopen/current-copy/lineage/audit/rollback/privacy/corruption PASS
