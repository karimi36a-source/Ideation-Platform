-- M10.20 integrated attack fixture; only trusted setup captures known IDs.
reset role;
-- Explicit role-only and same-Cohort/non-Team controls avoid relying on an
-- identity that happens to lack active enrollment.
insert into auth.users(id,email) values('00000000-0000-4000-8000-000000006020','m1020-non-team@example.test'),('00000000-0000-4000-8000-000000006021','m1020-role-only-mentor@example.test');
select public.provision_user_profile(id,'active') from auth.users where id in('00000000-0000-4000-8000-000000006020','00000000-0000-4000-8000-000000006021');
insert into public.role_assignments(user_id,role_id,organization_id,assigned_by)
select ('00000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,(select id from public.roles where code=case n when 6020 then 'STUDENT' else 'MENTOR' end),'00000000-0000-4000-8000-000000000501','00000000-0000-4000-8000-000000006001' from generate_series(6020,6021) n;
insert into public.enrollments(cohort_id,user_id,enrollment_role,status) select id,'00000000-0000-4000-8000-000000006020','participant','active' from acceptance_cohorts where label='Test';
do $$begin
 assert exists(select 1 from public.enrollments where user_id='00000000-0000-4000-8000-000000006020' and status='active');
 assert not exists(select 1 from public.team_memberships where user_id in('00000000-0000-4000-8000-000000006020','00000000-0000-4000-8000-000000006021'));
 assert (select count(distinct program_id)=1 from public.cohorts where id in(select id from acceptance_cohorts));
 assert exists(select 1 from public.session_definitions where id='00000000-0000-4000-8000-000000950702' and session_number=5);
end $$;
create temporary table m20_sessions(label text primary key,id uuid);
create temporary table m20_decisions(label text primary key,id uuid);
create temporary table m20_record(payload jsonb);
grant select,insert on m20_sessions,m20_decisions,m20_record to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
insert into m20_sessions select f.label,(public.create_voting_session(a.id,'DOT_VOTE',3,f.anonymous,f.mode,jsonb_build_array(jsonb_build_object('label','Private A choice','developmentObjectId',(select id from vc_objects where kind='PROBLEM')),jsonb_build_object('label','Second private A choice','developmentObjectId',(select id from vc_objects where kind='SOLUTION'))))#>>'{session,id}')::uuid
from vc_activities a cross join (values('live',false,'LIVE'),('hidden_named',false,'HIDDEN_UNTIL_REVEAL'),('hidden_anonymous',true,'HIDDEN_UNTIL_REVEAL')) f(label,anonymous,mode) where a.n=2;
select public.open_voting_session(id) from m20_sessions;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select public.cast_vote(s.id,o.id,1) from m20_sessions s join public.voting_options o on o.voting_session_id=s.id and o.sequence=1;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006009',true);
insert into m20_record select public.create_team_decision_record_artifact(pg_temp.da_id('Team'));
insert into m20_decisions values('old',pg_temp.da_id('Team')),('draft',pg_temp.da_id('Conflict race')),('personal',pg_temp.da_id('Personal'));
insert into m20_decisions select 'new',(public.create_decision(jsonb_build_object('projectId',payload->>'id','workspaceId',payload->>'primary_workspace_id','activityInstanceId',(select id from vc_activities where n=2),'title','M10.20 replacement','question','Why?','method','DISCUSSION','options','[{"label":"Explicit alternative"}]'::jsonb))#>>'{decision,id}')::uuid from logged_projects where label='Team';
select public.finalize_decision(jsonb_build_object('decisionId',id,'outcome','Explicit later outcome','reasoning','Explicit later reason')) from m20_decisions where label='new';
select public.supersede_decision(jsonb_build_object('oldDecisionId',(select id from m20_decisions where label='old'),'newDecisionId',(select id from m20_decisions where label='new')));
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006007',true);
insert into m20_decisions select 'foreign',(public.create_decision(jsonb_build_object('projectId',payload->>'id','workspaceId',payload->>'primary_workspace_id','title','B only','question','B question','method','DISCUSSION','options','[{"label":"B choice"}]'::jsonb))#>>'{decision,id}')::uuid from logged_projects where label='Brainstorm Team B';
select public.finalize_decision(jsonb_build_object('decisionId',id,'outcome','B outcome','reasoning','B reason')) from m20_decisions where label='foreign';
create temporary table m20_foreign_voting as
select public.create_voting_session((public.start_activity('00000000-0000-4000-8000-000001020802',(p.payload->>'id')::uuid,(p.payload->>'primary_workspace_id')::uuid,(t.payload->>'teamId')::uuid)#>>'{activity,id}')::uuid,'DOT_VOTE',3,false,'LIVE','[{"label":"B canonical option"}]'::jsonb) payload
from logged_projects p cross join acceptance_teams t where p.label='Brainstorm Team B' and t.label='B';
select public.open_voting_session((payload#>>'{session,id}')::uuid) from m20_foreign_voting;
select public.get_voting_results((payload#>>'{session,id}')::uuid) from m20_foreign_voting;
grant select on m20_foreign_voting to authenticated;

reset role;
-- A participant's own user_id is not an independent read grant. Historical
-- rows are legitimate trusted fixtures because there is no participant-write API.
insert into public.decision_participants(decision_id,user_id,role)
select id,u,'OBSERVER' from m20_decisions cross join unnest(array['00000000-0000-4000-8000-000000006004'::uuid,'00000000-0000-4000-8000-000000006007'::uuid]) u where label='old';
create temporary table m20_targets(table_name text,key_name text,id uuid);
insert into m20_targets select 'voting_sessions','id',id from m20_sessions;
insert into m20_targets select 'voting_options','id',id from public.voting_options where voting_session_id in(select id from m20_sessions);
insert into m20_targets select 'votes','id',id from public.votes where voting_session_id in(select id from m20_sessions);
insert into m20_targets select 'decisions','id',id from m20_decisions where label in('old','new','draft','future');
insert into m20_targets select 'decision_options','id',id from public.decision_options where decision_id in(select id from m20_decisions where label in('old','new','draft','future'));
insert into m20_targets select 'decision_participants','id',id from public.decision_participants where decision_id in(select id from m20_decisions where label in('old','new','draft','future'));
insert into m20_targets select 'decision_links','id',id from public.decision_links where decision_id in(select id from m20_decisions where label in('old','new','draft','future'));
insert into m20_targets select 'artifact_decision_sources','artifact_id',artifact_id from public.artifact_decision_sources where decision_id=(select id from m20_decisions where label='old');
grant select on m20_targets to authenticated;
create function pg_temp.m20_denied(command text,safe_message boolean default false) returns void language plpgsql as $$begin
 begin execute command;exception when insufficient_privilege then
  if safe_message then assert sqlerrm='Resource unavailable','Unsafe resource error';end if;return;
 end;
 raise exception 'M10.20 unauthorized command succeeded';
end $$;
-- Invoker only: no privilege elevation or caller-supplied identity helper.
create function pg_temp.m20_attacks() returns void language plpgsql as $$
declare s uuid;o uuid;d uuid;t record;c record;visible boolean;target uuid;entity_kind text;
begin
 for t in select * from m20_targets where table_name<>'votes' loop
  execute format('select exists(select 1 from public.%I where %I=%L)',t.table_name,t.key_name,t.id) into visible;assert not visible,'Exact-ID metadata leak';
  perform pg_temp.m20_denied(format('delete from public.%I where %I=%L',t.table_name,t.key_name,t.id));
  for c in select column_name from information_schema.columns where table_schema='public' and table_name=t.table_name loop
   perform pg_temp.m20_denied(format('update public.%I set %I=%I where %I=%L',t.table_name,c.column_name,c.column_name,t.key_name,t.id));
  end loop;
 end loop;
 foreach entity_kind in array array['voting_sessions','voting_options','votes','decisions','decision_options','decision_participants','decision_links','artifact_decision_sources'] loop
  perform pg_temp.m20_denied(format('insert into public.%I default values',entity_kind));
 end loop;
 for s in select id from m20_sessions union all select '00000000-0000-4000-8000-ffffffffffff'::uuid loop
  perform pg_temp.m20_denied(format('select public.get_voting_results(%L)',s),true);
  perform pg_temp.m20_denied(format('select public.reveal_voting_session(%L)',s),true);
  perform pg_temp.m20_denied(format('select public.close_voting_session(%L)',s),true);
  for o in select id from m20_targets where table_name='voting_options' loop
   perform pg_temp.m20_denied(format('select public.cast_vote(%L,%L,1)',s,o),true);
  end loop;
  perform pg_temp.m20_denied(format('select * from public.votes where voting_session_id=%L and user_id=auth.uid()',s));
 end loop;
 perform pg_temp.m20_denied('select * from public.votes');
 perform pg_temp.m20_denied(format('insert into public.votes(voting_session_id,voting_option_id,user_id,value) values(%L,%L,%L,1)',(select id from m20_sessions where label='live'),(select id from m20_targets where table_name='voting_options' limit 1),auth.uid()));
 perform pg_temp.m20_denied(format('update public.decisions set status=''FINALIZED'',outcome=''Forged'',reasoning=''Forged'',decision_owner_user_id=auth.uid(),decided_at=clock_timestamp() where id=%L',(select id from m20_decisions where label='draft')));
 perform pg_temp.m20_denied(format('update public.decisions set status=''SUPERSEDED'' where id=%L',(select id from m20_decisions where label='new')));
 perform pg_temp.m20_denied(format('update public.decision_options set selected=true,development_object_id=%L where id=%L',(select id from vc_foreign_objects limit 1),(select id from m20_targets where table_name='decision_options' limit 1)));
 perform pg_temp.m20_denied(format('insert into public.decision_participants(decision_id,user_id,role) values(%L,%L,''FINALIZER'')',(select id from m20_decisions where label='draft'),auth.uid()));
 perform pg_temp.m20_denied(format('insert into public.decision_links(decision_id,linked_entity_type,linked_entity_id,relationship_type) values(%L,''DECISION'',%L,''SUPERSEDES'')',(select id from m20_decisions where label='new'),(select id from m20_decisions where label='foreign')));

 perform pg_temp.m20_denied(format('select public.cast_vote(%L,%L,1)',(select payload#>>'{session,id}' from m20_foreign_voting),(select id from m20_targets where table_name='voting_options' limit 1)),true);
 perform pg_temp.m20_denied(format('select public.cast_vote(%L,%L,1)',(select id from m20_sessions where label='live'),(select payload#>>'{options,0,id}' from m20_foreign_voting)),true);
 perform pg_temp.m20_denied(format('select public.create_decision(%L::jsonb)',jsonb_build_object('projectId',(select payload->>'id' from logged_projects where label='Team'),'workspaceId',(select payload->>'primary_workspace_id' from logged_projects where label='Brainstorm Team B'),'title','Forged mismatch','question','Q','method','OTHER','options',jsonb_build_array(jsonb_build_object('label','Input choice')))),true);
 perform pg_temp.m20_denied(format('select public.create_decision(%L::jsonb)',jsonb_build_object('projectId',(select payload->>'id' from logged_projects where label='Brainstorm Team B'),'workspaceId',(select payload->>'primary_workspace_id' from logged_projects where label='Team'),'title','Forged mismatch','question','Q','method','OTHER','options',jsonb_build_array(jsonb_build_object('label','Input choice')))),true);
 perform pg_temp.m20_denied(format('select public.create_decision(%L::jsonb)',jsonb_build_object('projectId',(select payload->>'id' from logged_projects where label='Team'),'workspaceId',(select payload->>'primary_workspace_id' from logged_projects where label='Team'),'activityInstanceId',(select payload#>>'{session,activity_instance_id}' from m20_foreign_voting),'title','Foreign Activity','question','Q','method','OTHER','options',jsonb_build_array(jsonb_build_object('label','Input choice')))),true);

 perform pg_temp.m20_denied(format('select public.create_decision(%L::jsonb)',jsonb_build_object('projectId',(select payload->>'id' from logged_projects where label='Brainstorm Team B'),'workspaceId',(select payload->>'primary_workspace_id' from logged_projects where label='Brainstorm Team B'),'activityInstanceId',(select id from vc_activities where n=2),'title','Foreign Activity in valid own B scope','question','Q','method','OTHER','options',jsonb_build_array(jsonb_build_object('label','Input choice')))),true);
 perform pg_temp.m20_denied('select v.* from public.votes v join public.users u on u.id=v.user_id');
 assert not exists(select 1 from public.voting_options v join public.development_objects o on o.id=v.development_object_id where v.id in(select id from m20_targets where table_name='voting_options'));
 assert not exists(select 1 from public.voting_sessions v join public.activity_instances a on a.id=v.activity_instance_id where v.id in(select id from m20_sessions));
 assert not exists(select 1 from public.decision_options v join public.development_objects o on o.id=v.development_object_id where v.decision_id in(select id from m20_decisions where label in('old','new','draft','future')));
 assert not exists(select 1 from public.decision_participants p join public.users u on u.id=p.user_id where p.decision_id in(select id from m20_decisions where label in('old','new','draft','future')));
 assert not exists(select 1 from public.decision_participants where user_id=auth.uid() and decision_id=(select id from m20_decisions where label='old'));
 assert not exists(select 1 from public.decision_links l left join public.artifacts a on l.linked_entity_id=a.id left join public.development_objects o on l.linked_entity_id=o.id left join public.voting_sessions v on l.linked_entity_id=v.id where l.decision_id in(select id from m20_decisions where label in('old','new','draft','future')));
 assert not exists(select 1 from public.decision_links where linked_entity_id in(select id from public.development_objects) and decision_id=(select id from m20_decisions where label='old'));
 assert not exists(select 1 from public.decision_links l join public.decisions d on d.id=l.linked_entity_id where l.relationship_type='SUPERSEDES' and l.decision_id=(select id from m20_decisions where label='new'));
 assert not exists(select 1 from public.change_log where entity_id in(select id from m20_decisions where label in('old','new','draft','future')));
 assert not exists(select 1 from public.artifact_decision_sources x join public.artifacts a on a.id=x.artifact_id join public.artifact_versions v on v.id=x.artifact_version_id where x.decision_id=(select id from m20_decisions where label='old'));
 assert not exists(select 1 from public.artifacts where id=(select (payload#>>'{artifact,id}')::uuid from m20_record));
 assert not exists(select 1 from public.artifact_versions where id=(select (payload#>>'{version,id}')::uuid from m20_record));
 assert exists(select 1 from public.decisions where id=(select id from m20_decisions where label='personal'))=(auth.uid()='00000000-0000-4000-8000-000000006004'::uuid);
 for d in select id from m20_decisions where label in('old','new','draft','future') union all select '00000000-0000-4000-8000-ffffffffffff'::uuid loop
  select id into o from m20_targets where table_name='decision_options' limit 1;
  perform pg_temp.m20_denied(format('select public.finalize_decision(%L::jsonb)',jsonb_build_object('decisionId',d,'selectedOptionId',o,'outcome','Forged outcome','reasoning','Forged reason','linkedObjectIds',jsonb_build_array((select id from vc_objects where kind='SOLUTION')))),true);
  perform pg_temp.m20_denied(format('select public.create_team_decision_record_artifact(%L)',d),true);
  for target in select id from m20_decisions where label in('old','new','foreign','personal') loop
   if target<>d then perform pg_temp.m20_denied(format('select public.supersede_decision(%L::jsonb)',jsonb_build_object('oldDecisionId',d,'newDecisionId',target)),true);end if;
  end loop;
  foreach entity_kind in array array['DEVELOPMENT_OBJECT','ARTIFACT','VOTING_SESSION'] loop
   for target in select id from m20_targets where table_name=case entity_kind when 'DEVELOPMENT_OBJECT' then '' when 'ARTIFACT' then 'artifact_decision_sources' else 'voting_sessions' end
     union all select id from vc_objects where entity_kind='DEVELOPMENT_OBJECT'
     union all select id from vc_foreign_objects where entity_kind='DEVELOPMENT_OBJECT' loop
    perform pg_temp.m20_denied(format('select public.link_decision_entity(%L::jsonb)',jsonb_build_object('decisionId',d,'linkedEntityType',entity_kind,'linkedEntityId',target,'relationshipType',case when entity_kind='VOTING_SESSION' then 'INFORMED_BY' else 'CONSIDERED_IN_DECISION' end)),true);
   end loop;
  end loop;
 end loop;
end $$;
-- Full canonical snapshots detect any losing/unauthorized side effect. Run only
-- as trusted fixture owner, not as a client-access writer or read bypass.
create function pg_temp.m20_snapshot() returns jsonb language plpgsql as $$
declare result jsonb:='{}';t text;rows0 jsonb;begin
 foreach t in array array['voting_sessions','voting_options','votes','decisions','decision_options','decision_participants','decision_links','artifact_decision_sources','artifacts','artifact_versions','development_objects','activity_instances','project_baseline_items'] loop
  execute format('select coalesce(jsonb_agg(to_jsonb(x) order by to_jsonb(x)::text),''[]''::jsonb) from public.%I x',t) into rows0;result:=result||jsonb_build_object(t,rows0);
 end loop;
 select coalesce(jsonb_agg(to_jsonb(x) order by id),'[]'::jsonb) into rows0 from public.change_log x;
 return result||jsonb_build_object('change_log',rows0);
end $$;
create temporary table m20_before as select pg_temp.m20_snapshot() payload;
set local role authenticated;
do $$declare n int;begin
 foreach n in array array[6007,6006,6003,6001,6008,6020,6021] loop
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(n::text,12,'0'),true);
  perform pg_temp.m20_attacks();
 end loop;
end $$;
reset role;
do $$begin assert pg_temp.m20_snapshot()=(select payload from m20_before),'Unauthorized mutation left side effects';end $$;
select 'M10.20 TeamB/unrelated-Master/Mentor/Admin/same-Cohort exact-ID/joins/CRUD/RPC/errors/source/supersession PASS';
-- Positive controls: ordinary member reads canonical scope and aggregate-only
-- hidden DTO; instructional role facilitates through current authority.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
do $$begin
 assert exists(select 1 from public.decisions where id=(select id from m20_decisions where label='new'));
 assert (public.get_voting_results((select id from m20_sessions where label='live'))->>'totalVotes')::int=1;
 perform pg_temp.m20_denied('select * from public.votes');
 assert public.get_voting_results((select id from m20_sessions where label='hidden_named'))->'totalVotes'='null'::jsonb;
 assert public.get_voting_results((select id from m20_sessions where label='hidden_anonymous'))->'totalVotes'='null'::jsonb;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.close_voting_session(id) from m20_sessions where label like 'hidden%';
select public.reveal_voting_session(id) from m20_sessions where label like 'hidden%';
reset role;
update m20_before set payload=pg_temp.m20_snapshot();
set local role authenticated;
do $$declare n int;begin foreach n in array array[6007,6006,6003,6001,6008,6020,6021] loop
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(n::text,12,'0'),true);perform pg_temp.m20_attacks();end loop;end $$;
reset role;
do $$begin assert pg_temp.m20_snapshot()=(select payload from m20_before);end $$;
select 'M10.20 hidden-named/anonymous before-after reveal/LIVE scope/authorized controls PASS';
-- Current exact Master may retry canonical finalization. Scope revocation
-- denies elevated mutation; independent member read rights are not rewritten.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.finalize_decision(jsonb_build_object('decisionId',id,'outcome','Explicit later outcome','reasoning','Explicit later reason')) from m20_decisions where label='new';
reset role;
savepoint m20_scope;
do $$declare mode0 text;begin
 foreach mode0 in array array['inactive','expired','unrelated'] loop
  -- Restore within each test branch using an exception subtransaction that is
  -- intentionally rolled back only after all denial assertions have passed.
  begin
   if mode0='inactive' then update public.role_assignments set status='inactive' where user_id='00000000-0000-4000-8000-000000006002' and role_id=(select id from public.roles where code='MASTER');
   elsif mode0='expired' then update public.role_assignments set starts_at=clock_timestamp()-interval '2 hours',ends_at=clock_timestamp()-interval '1 hour' where user_id='00000000-0000-4000-8000-000000006002' and role_id=(select id from public.roles where code='MASTER');
   else update public.role_assignments set cohort_id=null,team_id=(select (payload->>'teamId')::uuid from acceptance_teams where label='B') where user_id='00000000-0000-4000-8000-000000006002' and role_id=(select id from public.roles where code='MASTER');end if;
   execute 'set local role authenticated';perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
   perform pg_temp.m20_denied(format('select public.close_voting_session(%L)',(select id from m20_sessions where label='live')),true);
   perform pg_temp.m20_denied(format('select public.finalize_decision(%L::jsonb)',jsonb_build_object('decisionId',(select id from m20_decisions where label='draft'),'outcome','No authority','reasoning','No authority')),true);
   assert exists(select 1 from public.decisions where id=(select id from m20_decisions where label='new')),'Independent member reads must retain accepted semantics';
   execute 'reset role';
   -- Now isolate role-only claims from independently valid membership.
   update public.team_memberships set status='removed',left_at=clock_timestamp(),removed_by='00000000-0000-4000-8000-000000006009' where user_id='00000000-0000-4000-8000-000000006002' and status='active';
   execute 'set local role authenticated';perform pg_temp.m20_attacks();
   raise exception 'rollback successful scope fixture' using errcode='ZX020';
  exception when sqlstate 'ZX020' then null;end;
 end loop;
end $$;
reset role;
rollback to m20_scope;
do $$begin assert pg_temp.m20_snapshot()=(select payload from m20_before);end $$;
select 'M10.20 inactive/expired/unrelated Master authority denied/role-only reads denied/independent membership semantics preserved PASS';
-- Remove the historical contributor and owner through the approved operation.
create temporary table m20_membership_history as select * from public.team_memberships where team_id=(select (payload->>'teamId')::uuid from acceptance_teams where label='A') and user_id in('00000000-0000-4000-8000-000000006004','00000000-0000-4000-8000-000000006009') and status='active';
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006004',null);
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006009',null);
do $$declare n int;begin foreach n in array array[6004,6009] loop
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(n::text,12,'0'),true);perform pg_temp.m20_attacks();end loop;end $$;
reset role;
do $$begin assert pg_temp.m20_snapshot()=(select payload from m20_before),'Removal or attacks rewrote protected history';end $$;
do $$begin
 assert not exists(select 1 from m20_membership_history h left join public.team_memberships m using(id) where m.id is null or m.joined_at is distinct from h.joined_at or m.status<>'removed' or m.left_at is null or m.removed_by is distinct from '00000000-0000-4000-8000-000000006002'::uuid);
end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
do $$begin
 assert exists(select 1 from public.decisions where id=(select id from m20_decisions where label='old'));
 assert exists(select 1 from public.artifact_decision_sources where decision_id=(select id from m20_decisions where label='old'));
 assert (public.get_voting_results((select id from m20_sessions where label='live'))->>'totalVotes')::int=1;
 assert (public.get_voting_results((select id from m20_sessions where label='hidden_named'))->>'totalVotes')::int=1;
 assert (public.get_voting_results((select id from m20_sessions where label='hidden_anonymous'))->>'totalVotes')::int=1;
 perform pg_temp.m20_denied('select * from public.votes');
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.finalize_decision(jsonb_build_object('decisionId',id,'outcome','Explicit later outcome','reasoning','Explicit later reason')) from m20_decisions where label='new';
reset role;
do $$begin assert pg_temp.m20_snapshot()=(select payload from m20_before),'Authorized retries rewrote preserved history';end $$;

-- Fresh executions created after removal must not inherit old participation.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
insert into m20_sessions select 'future',(public.create_voting_session(id,'DOT_VOTE',3,false,'LIVE','[{"label":"Post-removal Team A only"}]'::jsonb)#>>'{session,id}')::uuid from vc_activities where n=2;
select public.open_voting_session(id) from m20_sessions where label='future';
insert into m20_decisions select 'future',(public.create_decision(jsonb_build_object('projectId',payload->>'id','workspaceId',payload->>'primary_workspace_id','activityInstanceId',(select id from vc_activities where n=2),'title','Post-removal Team A Decision','question','Future scope?','method','DISCUSSION','options','[{"label":"Future only"}]'::jsonb))#>>'{decision,id}')::uuid from logged_projects where label='Team';
reset role;
do $$declare pair record;after0 jsonb:=pg_temp.m20_snapshot();begin
 for pair in select * from jsonb_each((select payload from m20_before)) loop
  assert after0->pair.key @> pair.value,'New execution rewrote historical rows';
 end loop;
end $$;
insert into m20_targets select 'voting_sessions','id',id from m20_sessions where label='future';
insert into m20_targets select 'voting_options','id',id from public.voting_options where voting_session_id=(select id from m20_sessions where label='future');
insert into m20_targets select 'decisions','id',id from m20_decisions where label='future';
insert into m20_targets select 'decision_options','id',id from public.decision_options where decision_id=(select id from m20_decisions where label='future');
update m20_before set payload=pg_temp.m20_snapshot();
set local role authenticated;
do $$declare n int;begin foreach n in array array[6004,6009,6007,6020,6021] loop
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(n::text,12,'0'),true);perform pg_temp.m20_attacks();end loop;end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
do $$begin
 assert exists(select 1 from public.decisions where id=(select id from m20_decisions where label='future'));
 assert (public.get_voting_results((select id from m20_sessions where label='future'))->>'totalVotes')::int=0;
end $$;
reset role;
do $$begin assert pg_temp.m20_snapshot()=(select payload from m20_before),'Future exact-ID attack altered rows';end $$;
select 'M10.20 post-removal fresh Voting/Decision IDs denied/remaining Team allowed/history retained PASS';
do $$declare f regprocedure;begin
 foreach f in array array['private.require_decision_creation(uuid,uuid,uuid)'::regprocedure,'private.require_decision_finalization(uuid,uuid,uuid,boolean)'::regprocedure] loop
  assert (select prosecdef and proconfig=array['search_path=""'] from pg_proc where oid=f);
  assert not has_function_privilege('authenticated',f,'execute');
  assert not has_function_privilege('anon',f,'execute');
  assert not has_function_privilege('service_role',f,'execute');
 end loop;
end $$;
set local role authenticated;
select pg_temp.m20_denied('select private.require_decision_creation(''00000000-0000-4000-8000-000000007201'',''00000000-0000-4000-8000-000000007101'',null)');
select pg_temp.m20_denied('select private.require_decision_finalization(''00000000-0000-4000-8000-000000007201'',''00000000-0000-4000-8000-000000007101'',null,true)');
reset role;
select 'M10.20 exact/nonexistent generic 42501/normalized delegated denial/private-helper grants PASS';
select 'M10.20 removed-contributor/former-owner/historical-participant denial/full-history preservation PASS';
rollback;
