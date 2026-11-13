reset role;
-- Fresh executions only. No historical Definition/snapshot is rewritten.
create temporary table ab_ids(label text primary key,id uuid);
grant select,insert on ab_ids to authenticated;
alter table public.activity_definitions disable trigger activity_history;
insert into public.activity_definitions(id,session_definition_id,name,method_type,workspace_mode,sequence,ai_role_code,configuration,status)
select ('00000000-0000-4000-8000-'||lpad((141900+n)::text,12,'0'))::uuid,session_definition_id,'M14.19 Brainstorm '||n,'brainstorming','Team Workspace',141900+n,'BRAINSTORMING_FACILITATOR',jsonb_build_object('brainstorming',jsonb_build_object('visibility_mode','private_before_reveal','reveal_authority','team_lead_or_scoped_master'),'ai',jsonb_build_object('enabled',true,'requires_revealed_pool',n=2)),'active'
from public.activity_definitions cross join generate_series(1,2) n where id=(select activity_definition_id from public.activity_instances where id=pg_temp.research_context('Session9'));
alter table public.activity_definitions enable trigger activity_history;
insert into public.activity_instances(id,activity_definition_id,cohort_id,project_id,workspace_id,team_id,started_by,started_at,status,configuration_snapshot)
select ('00000000-0000-4000-8000-'||lpad((141910+n)::text,12,'0'))::uuid,('00000000-0000-4000-8000-'||lpad((141900+n)::text,12,'0'))::uuid,cohort_id,project_id,workspace_id,team_id,'00000000-0000-4000-8000-000000006004',clock_timestamp(),'active',public.activity_start_snapshot(('00000000-0000-4000-8000-'||lpad((141900+n)::text,12,'0'))::uuid)
from public.activity_instances cross join generate_series(1,2) n where id=pg_temp.research_context('Session9');
insert into ab_ids values('Self','00000000-0000-4000-8000-000000141911'),('Pool','00000000-0000-4000-8000-000000141912');
insert into public.project_memberships(project_id,user_id) select (payload->>'id')::uuid,'00000000-0000-4000-8000-000000006005' from logged_projects where label='Team' on conflict do nothing;
create function pg_temp.ab_request(entry0 text,activity0 text default 'Self') returns jsonb language sql as $$select jsonb_build_object('projectId',payload->>'id','workspaceId',payload->>'primary_workspace_id','activityInstanceId',(select id from ab_ids where label=activity0),'entityType','BRAINSTORM_ENTRY','entityId',(select id from ab_ids where label=entry0),'contextRole','BRAINSTORM') from logged_projects where label='Team'$$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
set local role authenticated;
insert into ab_ids select 'OwnSelf',(public.create_brainstorm_entry((select id from ab_ids where label='Self'),'A1_OWN_HIDDEN','private')->>'id')::uuid;
insert into ab_ids select 'OwnPool',(public.create_brainstorm_entry((select id from ab_ids where label='Pool'),'A1_POOL_HIDDEN','private')->>'id')::uuid;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
insert into ab_ids select 'PeerSelf',(public.create_brainstorm_entry((select id from ab_ids where label='Self'),'A2_PEER_HIDDEN','private')->>'id')::uuid;
insert into ab_ids select 'PeerPool',(public.create_brainstorm_entry((select id from ab_ids where label='Pool'),'A2_POOL_REVEAL','private')->>'id')::uuid;
do $$begin
 assert public.resolve_ai_context_source(pg_temp.ab_request('OwnSelf')) is null,'Lead read hidden peer';
 assert public.resolve_ai_context_source(pg_temp.ab_request('PeerSelf')) #>> '{content,content}'='A2_PEER_HIDDEN';
end$$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$declare r jsonb;begin
 r:=public.resolve_ai_context_source(pg_temp.ab_request('OwnSelf'));
 assert r #>> '{content,content}'='A1_OWN_HIDDEN';assert r->>'context_role'='BRAINSTORM';
 assert (select count(*) from jsonb_object_keys(r->'content'))=1;
 assert public.resolve_ai_context_source(pg_temp.ab_request('PeerSelf')) is null;
 assert public.resolve_ai_context_source(pg_temp.ab_request('OwnPool','Pool')) is null,'Pool included unrevealed own entry';
 assert public.resolve_activity_ai_configuration((select id from ab_ids where label='Pool'))->>'revealed_pool_satisfied'='false';
 assert public.resolve_ai_context_source(pg_temp.ab_request('OwnSelf','Pool')) is null,'Wrong Activity bypass';
 begin perform public.resolve_ai_context_source(pg_temp.ab_request('PeerSelf')||'{"revealed":true}');raise exception 'Spoof';exception when invalid_parameter_value then null;end;
end$$;
reset role;
-- Trusted persistence boundary still rejects hidden-peer provenance atomically.
create function pg_temp.ab_capture(entry0 text,activity0 text default 'Self',task0 text default 'BRAINSTORMING_ASSISTANCE') returns uuid language plpgsql as $$declare o uuid;begin
 insert into public.ai_outputs(project_id,workspace_id,activity_instance_id,ai_role,task_type,prompt_text,response_text,output_type)
 select project_id,workspace_id,id,'BRAINSTORMING_FACILITATOR',task0,'Fixture authorized content','Unverified suggestion','SUGGESTION' from public.activity_instances where id=(select id from ab_ids where label=activity0) returning id into o;
 insert into public.ai_context_references(ai_output_id,entity_type,entity_id,context_role,included_snapshot_hash,permission_scope)
 values(o,'BRAINSTORM_ENTRY',(select id from ab_ids where label=entry0),'BRAINSTORM','0','{"access":"SOURCE"}');return o;
end$$;
insert into ab_ids select 'OwnOutput',pg_temp.ab_capture('OwnSelf');
do $$declare n integer;begin
 select count(*) into n from public.ai_outputs;
 begin perform pg_temp.ab_capture('PeerSelf');raise exception 'Peer reference';exception when insufficient_privilege then null;end;
 begin perform pg_temp.ab_capture('OwnPool','Pool');raise exception 'Hidden pool reference';exception when insufficient_privilege then null;end;
 begin perform pg_temp.ab_capture('OwnSelf','Self','CRITICAL_REVIEW');raise exception 'Wrong Task';exception when insufficient_privilege then null;end;
 assert (select count(*) from public.ai_outputs)=n,'Orphan output';
 assert not exists(select 1 from public.ai_context_references where entity_id=(select id from ab_ids where label='PeerSelf'));
end$$;
create temporary table ab_history as select to_jsonb(r) body from public.ai_context_references r where ai_output_id=(select id from ab_ids where label='OwnOutput');
-- Team B, other Personal actor and role-only accounts cannot resolve exact IDs.
set local role authenticated;
do $$declare n integer;begin
 foreach n in array array[6001,6002,6003,6006,6007,6008] loop
 perform set_config('request.jwt.claim.sub',('00000000-0000-4000-8000-'||lpad(n::text,12,'0')),true);
 begin assert public.resolve_ai_context_source(pg_temp.ab_request('OwnSelf')) is null;exception when insufficient_privilege then null;end;
 assert not public.can_read_ai_brainstorm_entry((select id from ab_ids where label='OwnSelf'),(select id from ab_ids where label='Self'),(select (payload->>'id')::uuid from logged_projects where label='Team'),(select (payload->>'primary_workspace_id')::uuid from logged_projects where label='Team'));
 end loop;
end$$;
-- Only the accepted M9 reveal operation changes canonical reveal state.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
select public.reveal_brainstorm_entries((select id from ab_ids where label='Pool'),array[(select id from ab_ids where label='PeerPool')]);
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin
 assert public.resolve_activity_ai_configuration((select id from ab_ids where label='Pool'))->>'revealed_pool_satisfied'='true';
 assert public.resolve_ai_context_source(pg_temp.ab_request('PeerPool','Pool')) #>> '{content,content}'='A2_POOL_REVEAL';
 assert public.resolve_ai_context_source(pg_temp.ab_request('OwnPool','Pool')) is null,'Unrevealed own row entered revealed pool';
 assert public.resolve_ai_context_source(pg_temp.ab_request('PeerSelf')) is null,'Other Activity hidden peer leaked';
end$$;
reset role;
insert into ab_ids select 'RevealedOutput',pg_temp.ab_capture('PeerPool','Pool');

-- Saved-output privacy uses a distinct ordinary Team peer and current Lead.
insert into auth.users(id,email) values('00000000-0000-4000-8000-000000006019','m1419-peer@example.test');
select public.provision_user_profile('00000000-0000-4000-8000-000000006019','active');
insert into public.enrollments(cohort_id,user_id,enrollment_role,status) select id,'00000000-0000-4000-8000-000000006019','participant','active' from acceptance_cohorts where label='Test';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.add_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006019','member');
insert into public.project_memberships(project_id,user_id) select (payload->>'id')::uuid,'00000000-0000-4000-8000-000000006019' from logged_projects where label='Team';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
set local role authenticated;
insert into ab_ids select 'SavedFirst',(public.create_brainstorm_entry((select id from ab_ids where label='Self'),'A1_SAVED_PRIVATE_ONE','private')->>'id')::uuid;
insert into ab_ids select 'SavedSecond',(public.create_brainstorm_entry((select id from ab_ids where label='Self'),'A1_SAVED_PRIVATE_TWO','private')->>'id')::uuid;
reset role;
insert into ab_ids select 'SavedSingle',pg_temp.ab_capture('SavedFirst');
insert into ab_ids select 'SavedMixed',pg_temp.ab_capture('SavedFirst');
insert into public.ai_context_references(ai_output_id,entity_type,entity_id,context_role,included_snapshot_hash,permission_scope)
values((select id from ab_ids where label='SavedMixed'),'BRAINSTORM_ENTRY',(select id from ab_ids where label='SavedSecond'),'BRAINSTORM','0','{"access":"SOURCE"}');
with o as (insert into public.ai_outputs(project_id,workspace_id,ai_role,task_type,prompt_text,response_text,output_type)
 select (payload->>'id')::uuid,(payload->>'primary_workspace_id')::uuid,'CRITICAL_REVIEWER','UNRELATED_FIXTURE','Non-Brainstorm prompt','Normal Team result','ANALYSIS' from logged_projects where label='Team' returning id)
 insert into ab_ids select 'UnrelatedOutput',id from o;
with o as (insert into public.ai_outputs(project_id,workspace_id,ai_role,task_type,prompt_text,response_text,output_type)
 select (payload->>'id')::uuid,(payload->>'primary_workspace_id')::uuid,'CRITICAL_REVIEWER','PERSONAL_FIXTURE','Personal prompt','Personal result','ANALYSIS' from logged_projects where label='Individual' returning id)
 insert into ab_ids select 'PersonalOutput',id from o;
create temporary table ab_saved_refs as select id,ai_output_id from public.ai_context_references where ai_output_id in(select id from ab_ids where label in('SavedSingle','SavedMixed'));
grant select on ab_saved_refs to authenticated;
grant select on ab_ids,submitted_fixtures to service_role;
create function pg_temp.ab_output_read(label0 text,allowed0 boolean) returns void language plpgsql as $$declare out0 uuid;begin
 select id into out0 from ab_ids where label=label0;
 assert exists(select 1 from public.ai_outputs where id=out0)=allowed0,'Exact output ID read mismatch';
 assert (select count(*) from public.ai_context_references where ai_output_id=out0)=case when allowed0 then (select count(*) from ab_saved_refs where ai_output_id=out0) else 0 end,'Reference enumeration mismatch';
 assert not exists(select 1 from public.ai_context_references r join ab_saved_refs known on known.id=r.id where known.ai_output_id=out0 and not allowed0),'Exact Reference ID exposed';
 assert public.can_read_brainstorm_derived_ai_output(out0)=allowed0,'Boolean guard mismatch';
end$$;
set local role authenticated;
do $$begin
 perform pg_temp.ab_output_read('SavedSingle',true);perform pg_temp.ab_output_read('SavedMixed',true);
 assert exists(select 1 from public.ai_outputs where id=(select id from ab_ids where label='PersonalOutput'));
end$$;
-- Neither completion, disposition nor a forged metadata/reveal flag publishes.
select public.set_ai_output_disposition((select id from ab_ids where label='SavedSingle'),'MODIFIED',0);
reset role;
create temporary table ab_saved_output_history as select id,to_jsonb(o) body from public.ai_outputs o where id in(select id from ab_ids where label in('SavedSingle','SavedMixed'));
create temporary table ab_saved_ref_history as select r.id,to_jsonb(r) body from public.ai_context_references r join ab_saved_refs known on known.id=r.id;
set local role authenticated;
do $$declare n integer;begin
 foreach n in array array[6019,6005,6001,6002,6003,6006,6007,6008] loop
  perform set_config('request.jwt.claim.sub',('00000000-0000-4000-8000-'||lpad(n::text,12,'0')),true);
  perform pg_temp.ab_output_read('SavedSingle',false);perform pg_temp.ab_output_read('SavedMixed',false);
  begin perform public.set_ai_output_disposition((select id from ab_ids where label='SavedSingle'),'MODIFIED',1);raise exception 'Disposition retry exposed private output';exception when insufficient_privilege then null;end;
  begin perform public.set_ai_output_disposition((select id from ab_ids where label='SavedMixed'),'REJECTED',0);raise exception 'Disposition mutation exposed private output';exception when insufficient_privilege then null;end;
  assert not exists(select 1 from public.ai_outputs where id=(select id from ab_ids where label='PersonalOutput'));
  assert not exists(select 1 from public.brainstorm_entries where id in(select id from ab_ids where label in('SavedFirst','SavedSecond'))),'Source entry exposed';
  assert not public.can_read_brainstorm_derived_ai_output('00000000-0000-4000-8000-999999999999');
  if n in(6019,6005) then
   assert exists(select 1 from public.ai_outputs where id=(select id from ab_ids where label='UnrelatedOutput')),'Unrelated Team output visibility changed';
  end if;
 end loop;
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006019',true);
 begin update public.ai_outputs set metadata='{"revealed":true}' where id=(select id from ab_ids where label='SavedSingle');raise exception 'Client output mutation';exception when insufficient_privilege then null;end;
 begin update public.ai_context_references set entity_id=(select id from ab_ids where label='PeerPool') where id=(select id from ab_saved_refs limit 1);raise exception 'Client provenance mutation';exception when insufficient_privilege then null;end;
end$$;

-- Even trusted RPC entry points must enforce the current actor's private read.
reset role;
set local role service_role;
do $$begin
 begin
  perform public.convert_ai_output_to_candidate(jsonb_build_object('actorId','00000000-0000-4000-8000-000000006019','aiOutputId',(select id from ab_ids where label='SavedSingle'),'targetObjectType','IDEA','candidateTitle','Guessed private output','candidateContent','Not authorized','confirmed',true,'sourceResponseHash',repeat('a',64)));
  raise exception 'Conversion bypassed saved-output privacy';
 exception when insufficient_privilege then assert sqlerrm='Resource unavailable';end;
 begin
  perform public.apply_ai_artifact_revision(jsonb_build_object('actorId','00000000-0000-4000-8000-000000006019','aiOutputId',(select id from ab_ids where label='SavedSingle'),'artifactId',(select (payload->>'artifactId')::uuid from submitted_fixtures where label='Team'),'expectedVersionId',(select (payload->>'initialVersionId')::uuid from submitted_fixtures where label='Team'),'expectedDraftRevision',0,'contentSnapshot','{"notes":"Not authorized"}'::jsonb,'changeSummary','No access','confirmed',true,'idempotencyKey','m1419-hidden-revision','sourceResponseHash',repeat('a',64)));
  raise exception 'Artifact revision bypassed saved-output privacy';
 exception when insufficient_privilege then assert sqlerrm='Resource unavailable';end;
end$$;
reset role;
set local role authenticated;

-- A partial canonical reveal restores only outputs with all sources revealed.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
select public.reveal_brainstorm_entries((select id from ab_ids where label='Self'),array[(select id from ab_ids where label='SavedFirst')]);
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006019',true);
do $$begin
 perform pg_temp.ab_output_read('SavedSingle',true);perform pg_temp.ab_output_read('SavedMixed',false);
 assert not exists(select 1 from public.brainstorm_entries where id=(select id from ab_ids where label='SavedSecond'));
end$$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
select public.reveal_brainstorm_entries((select id from ab_ids where label='Self'),array[(select id from ab_ids where label='SavedSecond')]);
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006019',true);
do $$begin perform pg_temp.ab_output_read('SavedSingle',true);perform pg_temp.ab_output_read('SavedMixed',true);end$$;
-- Team B and unauthorized role-only actors remain denied after publication.
do $$declare n integer;begin
 foreach n in array array[6001,6002,6003,6006,6007,6008] loop
  perform set_config('request.jwt.claim.sub',('00000000-0000-4000-8000-'||lpad(n::text,12,'0')),true);
  perform pg_temp.ab_output_read('SavedSingle',false);perform pg_temp.ab_output_read('SavedMixed',false);
 end loop;
end$$;
reset role;
do $$begin
 assert not exists(select 1 from ab_saved_output_history h join public.ai_outputs o on o.id=h.id where h.body<>to_jsonb(o)),'Reveal rewrote output';
 assert not exists(select 1 from ab_saved_ref_history h join public.ai_context_references r on r.id=h.id where h.body<>to_jsonb(r)),'Reveal rewrote provenance';
 assert (select count(*) from ab_saved_ref_history)=(select count(*) from public.ai_context_references where ai_output_id in(select id from ab_ids where label in('SavedSingle','SavedMixed')));
 assert not has_function_privilege('anon','public.can_read_brainstorm_derived_ai_output(uuid)','EXECUTE');
 assert not has_function_privilege('service_role','public.can_read_brainstorm_derived_ai_output(uuid)','EXECUTE');
end$$;
select 'M14.19 saved-output/reference requester-only/direct-ID/role-only/mixed-context/canonical-reveal/unchanged-history/normal-Team/Personal/privacy PASS' result;

-- Current membership is authoritative; retained provenance is not a capability.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006004','M14.19 removal');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
set local role authenticated;
do $$begin
 assert not exists(select 1 from public.ai_outputs where id in(select id from ab_ids where label in('OwnOutput','SavedSingle','SavedMixed'))),'Requester bypassed current membership';
  begin assert public.resolve_ai_context_source(pg_temp.ab_request('OwnSelf')) is null;exception when insufficient_privilege then null;end;
 begin assert public.resolve_ai_context_source(pg_temp.ab_request('PeerPool','Pool')) is null;exception when insufficient_privilege then null;end;
 begin update public.ai_context_references set entity_id=(select id from ab_ids where label='PeerSelf') where ai_output_id=(select id from ab_ids where label='OwnOutput');exception when insufficient_privilege then null;end;
end$$;
reset role;
do $$begin
 assert (select body from ab_history)=(select to_jsonb(r) from public.ai_context_references r where ai_output_id=(select id from ab_ids where label='OwnOutput'));
 assert not exists(select 1 from public.brainstorm_entries where id in(select id from ab_ids where label in('OwnSelf','PeerSelf','OwnPool')) and revealed_at is not null);
 assert not has_function_privilege('anon','public.can_read_ai_brainstorm_entry(uuid,uuid,uuid,uuid)','EXECUTE');
end$$;
select 'M14.19 Brainstorm AI privacy, exact-entry provenance, canonical reveal and membership PASS' result;
rollback;
