-- Canonical M8 fixture is prepended. No hosted data or test-only production path.
reset role;
-- Isolated non-SCAMPER definition: a misleading name cannot authorize writes.
insert into public.curriculum_versions(id,program_id,version_label) values('00000000-0000-4000-8000-000000920602','00000000-0000-4000-8000-000000000601','M9.2 isolated method fixture');
insert into public.session_definitions(id,curriculum_version_id,session_number,title,description,learning_goal,sequence) values('00000000-0000-4000-8000-000000920702','00000000-0000-4000-8000-000000920602',1,'Fixture','Fixture','Fixture',1);
insert into public.activity_definitions(id,session_definition_id,name,method_type,sequence) values('00000000-0000-4000-8000-000000920802','00000000-0000-4000-8000-000000920702','SCAMPER misleading fixture','custom',1);
update public.curriculum_versions set status='approved' where id='00000000-0000-4000-8000-000000920602';
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006001',true);
insert into acceptance_cohorts values('Method fixture',(public.create_cohort('00000000-0000-4000-8000-000000000601','00000000-0000-4000-8000-000000920602','Method fixture','2026-10-01',null,'00000000-0000-4000-8000-000000006002','active','{}')->>'id')::uuid);
reset role;
insert into public.enrollments(cohort_id,user_id,enrollment_role,status,joined_at) select id,'00000000-0000-4000-8000-000000006004','participant','active',now() from acceptance_cohorts where label='Method fixture';
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select public.link_project_to_program((select (payload->>'id')::uuid from logged_projects where label='Individual'),'00000000-0000-4000-8000-000000000601',(select id from acceptance_cohorts where label='Method fixture'));
reset role;
insert into public.activity_instances(id,activity_definition_id,cohort_id,project_id,workspace_id,started_by,started_at,status,configuration_snapshot)
select '00000000-0000-4000-8000-000000920902','00000000-0000-4000-8000-000000920802',(select id from acceptance_cohorts where label='Method fixture'),(payload->>'id')::uuid,(payload->>'primary_workspace_id')::uuid,'00000000-0000-4000-8000-000000006004',now(),'active','{"method_type":"custom"}' from logged_projects where label='Individual';
set local role authenticated;
do $$begin begin perform public.create_scamper_entry('00000000-0000-4000-8000-000000920902','SUBSTITUTE','','','');raise exception 'Non-SCAMPER Activity accepted';exception when invalid_parameter_value then null;end;end $$;
reset role;
create temporary table scamper_saved(label text primary key,payload jsonb);
grant select,insert,update on scamper_saved to authenticated;
create function pg_temp.output_snapshot() returns jsonb language plpgsql set search_path='' as $$
declare result jsonb:='{}';name text;rows0 jsonb;begin
 foreach name in array array['artifacts','artifact_versions','artifact_object_links','submissions','feedback_items','review_actions','project_baseline_items','development_objects','problem_details','idea_details','activity_inputs','activity_outputs','activity_instances','change_log','audit_events'] loop
  execute format('select coalesce(jsonb_agg(to_jsonb(x) order by to_jsonb(x)::text),''[]''::jsonb) from public.%I x',name) into rows0;
  result:=result||jsonb_build_object(name,rows0);
 end loop;return result;end $$;
revoke all on function pg_temp.output_snapshot() from public,authenticated,anon;
create temporary table scamper_outputs as select pg_temp.output_snapshot() payload;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into scamper_saved select lens::text,public.create_scamper_entry((select id from instances where label='Individual'),lens,'Original','Proposed','Result') from unnest(enum_range(null::public.scamper_lens)) lens;
insert into scamper_saved values('Team',public.create_scamper_entry((select id from instances where label='Team'),'COMBINE','Team original','Team change','Team result'));
select public.update_scamper_entry((select (payload->>'id')::uuid from scamper_saved where label='SUBSTITUTE'),'{"scamperType":"ADAPT","originalElement":"Updated original","proposedChange":"Updated proposal","resultText":"Updated result"}');
reset role;
do $$begin
 assert pg_temp.output_snapshot()=(select payload from scamper_outputs),'SCAMPER operations changed canonical outputs';
 assert (select count(*) from public.scamper_entries)=8;
 assert not exists(select 1 from public.scamper_entries s join scamper_saved f on s.id=(f.payload->>'id')::uuid
  where s.created_by<>'00000000-0000-4000-8000-000000006004' or s.updated_by<>s.created_by or s.activity_instance_id<>(select id from instances where label=case when f.label='Team' then 'Team' else 'Individual' end)
  or s.idea_object_id is not null or s.status<>'active' or s.archived_at is not null or (s.id,s.project_id,s.workspace_id,s.created_at) is distinct from ((f.payload->>'id')::uuid,(f.payload->>'project_id')::uuid,(f.payload->>'workspace_id')::uuid,(f.payload->>'created_at')::timestamptz));
end $$;
-- Team contribution authority follows existing Project + Workspace membership.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
select public.update_scamper_entry((select (payload->>'id')::uuid from scamper_saved where label='Team'),'{"resultText":"Scoped collaborator update"}');
reset role;
do $$begin assert exists(select 1 from public.scamper_entries where id=(select (payload->>'id')::uuid from scamper_saved where label='Team') and created_by='00000000-0000-4000-8000-000000006004' and updated_by='00000000-0000-4000-8000-000000006005');end $$;
-- Direct RPC validation does not rely on the TypeScript contract.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$declare key text;e uuid:=(select (payload->>'id')::uuid from scamper_saved where label='SUBSTITUTE');begin
 foreach key in array array['activityInstanceId','projectId','workspaceId','createdBy','ideaObjectId','status','archivedAt','createdAt','updatedBy','role','userId','teamId'] loop
  begin perform public.update_scamper_entry(e,jsonb_build_object(key,'00000000-0000-4000-8000-000000006005'));raise exception 'Extra field accepted';exception when invalid_parameter_value then null;end;
 end loop;
 begin perform public.update_scamper_entry(e,'{}');raise exception 'Empty accepted';exception when invalid_parameter_value then null;end;
 begin perform public.update_scamper_entry(e,'{"resultText":null}');raise exception 'Null accepted';exception when invalid_parameter_value then null;end;
 begin perform public.update_scamper_entry(e,'{"scamperType":"CUSTOM"}');raise exception 'Lens accepted';exception when invalid_text_representation then null;end;
 begin perform public.create_scamper_entry((select id from instances where label='Individual'),'CUSTOM','','','');raise exception 'Lens accepted';exception when invalid_text_representation then null;end;
 begin perform public.create_scamper_entry('00000000-0000-4000-8000-000000999999','SUBSTITUTE','','','');raise exception 'Unknown Activity';exception when insufficient_privilege then null;end;
end $$;
reset role;
-- Trusted lifecycle fixtures are rolled back inside each exception block.
do $$declare state0 public.activity_instance_status;e uuid:=(select (payload->>'id')::uuid from scamper_saved where label='SUBSTITUTE');a uuid:=(select id from instances where label='Individual');begin
 foreach state0 in array array['submitted','under_review','revision_requested','completed','archived']::public.activity_instance_status[] loop
  begin
   update public.activity_instances set status=state0,completed_at=case when state0='completed' then now() else null end where id=a;
   perform public.update_scamper_entry(e,'{"resultText":"Forbidden edit"}');raise exception 'Locked Activity edited';
  exception when sqlstate '55000' then null;end;
  assert (select status='active' from public.activity_instances where id=a);
 end loop;
 begin update public.scamper_entries set status='archived',archived_at=now() where id=e;
  perform public.update_scamper_entry(e,'{"resultText":"Restore bypass"}');raise exception 'Archive edited';exception when sqlstate '55000' then null;end;
end $$;
-- Actual submitted/reviewed/current outputs never lock or synchronize source data.
set local role authenticated;
insert into scamper_saved select 'S1',public.submit_artifact((payload->>'artifactId')::uuid,(payload->>'initialVersionId')::uuid,(select id from instances where label='Individual')) from submitted_fixtures where label='Personal';
reset role;
update scamper_outputs set payload=pg_temp.output_snapshot();
set local role authenticated;
select public.update_scamper_entry((select (payload->>'id')::uuid from scamper_saved where label='SUBSTITUTE'),'{"resultText":"After submission"}');
reset role;
do $$begin assert pg_temp.output_snapshot()=(select payload from scamper_outputs);end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.start_review((select (payload->>'id')::uuid from scamper_saved where label='S1'));
reset role;
update scamper_outputs set payload=pg_temp.output_snapshot();
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select public.update_scamper_entry((select (payload->>'id')::uuid from scamper_saved where label='SUBSTITUTE'),'{"resultText":"During review"}');
reset role;
do $$begin assert pg_temp.output_snapshot()=(select payload from scamper_outputs);end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.request_revision((select (payload->>'id')::uuid from scamper_saved where label='S1'),'Revision fixture');
reset role;
update scamper_outputs set payload=pg_temp.output_snapshot();
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select public.update_scamper_entry((select (payload->>'id')::uuid from scamper_saved where label='SUBSTITUTE'),'{"resultText":"After revision request"}');
reset role;
do $$begin assert pg_temp.output_snapshot()=(select payload from scamper_outputs),'Revision-requested outputs changed';end $$;
set local role authenticated;
insert into scamper_saved select 'V2',to_jsonb(public.create_revision_draft((payload->>'id')::uuid,'{"immutable":"revision"}','Explicit revision fixture')) from scamper_saved where label='S1';
insert into scamper_saved select 'S2',public.submit_artifact((select (payload->>'artifactId')::uuid from submitted_fixtures where label='Personal'),(payload->>'id')::uuid,(select id from instances where label='Individual')) from scamper_saved where label='V2';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.start_review((select (payload->>'id')::uuid from scamper_saved where label='S2'));
select public.approve_artifact((select (payload->>'id')::uuid from scamper_saved where label='S2'),'Approved fixture');
reset role;
update scamper_outputs set payload=pg_temp.output_snapshot();
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select public.update_scamper_entry((select (payload->>'id')::uuid from scamper_saved where label='SUBSTITUTE'),'{"resultText":"After approval"}');
reset role;
do $$begin assert pg_temp.output_snapshot()=(select payload from scamper_outputs),'Approved bodies/current pointer/inputs/baseline changed';end $$;
-- Real auth contexts: Personal non-owner, Team B, Master, Mentor, Admin and exact guessed IDs.
set local role authenticated;
do $$declare actor0 text;e uuid;begin
 foreach actor0 in array array['00000000-0000-4000-8000-000000006001','00000000-0000-4000-8000-000000006002','00000000-0000-4000-8000-000000006003','00000000-0000-4000-8000-000000006006','00000000-0000-4000-8000-000000006008'] loop
  perform set_config('request.jwt.claim.sub',actor0,true);
  for e in select (payload->>'id')::uuid from scamper_saved where label in ('SUBSTITUTE','Team') loop
   begin perform public.update_scamper_entry(e,'{"resultText":"Stolen"}');raise exception 'Foreign edit';exception when insufficient_privilege then null;end;
  end loop;
 end loop;
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
 begin perform public.update_scamper_entry((select (payload->>'id')::uuid from scamper_saved where label='SUBSTITUTE'),'{"resultText":"Personal stolen"}');raise exception 'Personal peer edit';exception when insufficient_privilege then null;end;
 begin perform public.update_scamper_entry('00000000-0000-4000-8000-000000999999','{"resultText":"Unknown"}');raise exception 'Unknown entry';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006004');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin
 begin perform public.update_scamper_entry((select (payload->>'id')::uuid from scamper_saved where label='Team'),'{"resultText":"Stale member"}');raise exception 'Removal bypass';exception when insufficient_privilege then null;end;
 begin perform public.create_scamper_entry((select id from instances where label='Team'),'SUBSTITUTE','','','');raise exception 'Removal create bypass';exception when insufficient_privilege then null;end;
 begin perform * from public.scamper_entries;raise exception 'Direct read';exception when insufficient_privilege then null;end;
 begin update public.scamper_entries set created_by='00000000-0000-4000-8000-000000006005';raise exception 'Direct update';exception when insufficient_privilege then null;end;
end $$;
select public.update_scamper_entry((select (payload->>'id')::uuid from scamper_saved where label='SUBSTITUTE'),'{"resultText":"Personal remains editable"}');
set local role anon;
do $$begin
 begin perform public.create_scamper_entry((select id from instances where label='Individual'),'SUBSTITUTE','','','');raise exception 'Anonymous';exception when insufficient_privilege then null;end;
end $$;
reset role;
do $$declare f regprocedure;begin
 foreach f in array array['public.create_scamper_entry(uuid,public.scamper_lens,text,text,text)'::regprocedure,'public.update_scamper_entry(uuid,jsonb)'::regprocedure] loop
  assert (select prosecdef and proconfig=array['search_path=""'] from pg_proc where oid=f);
  assert has_function_privilege('authenticated',f,'EXECUTE');
  assert not has_function_privilege('anon',f,'EXECUTE');assert not has_function_privilege('service_role',f,'EXECUTE');
 end loop;
 assert not has_function_privilege('authenticated','private.require_scamper_write(uuid)','EXECUTE');
 assert not has_table_privilege('authenticated','public.scamper_entries','INSERT');
end $$;
rollback;
\echo M9.2 AT-SCAMPER-001 create/update/seven lenses/identity/Personal-Team privacy/removal/lifecycle/output immutability PASS
