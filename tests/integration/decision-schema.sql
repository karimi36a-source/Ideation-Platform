reset role;
-- Trusted structural fixtures only. There is no public Decision creation command.
create temporary table ds_context as select (p.payload->>'id')::uuid project_id,(p.payload->>'primary_workspace_id')::uuid workspace_id,(select id from vc_activities where n=1) activity_id from logged_projects p where p.label='Team';
insert into public.decisions(id,project_id,workspace_id,activity_instance_id,title,question,method,status,decision_owner_user_id)
select ('00000000-0000-4000-8000-'||lpad((1021800+n)::text,12,'0'))::uuid,c.project_id,c.workspace_id,case when n=1 then c.activity_id else null end,'M10.8 fixture','Which approach?',method::public.decision_method,status::public.decision_status,'00000000-0000-4000-8000-000000006004'
from ds_context c cross join (values(1,'DOT_VOTE','DRAFT'),(2,'DISCUSSION','FINALIZED'),(3,'CONSENSUS','SUPERSEDED'),(4,'OTHER','ARCHIVED')) v(n,method,status);
create temporary table ds_ids as select id,status from public.decisions;
grant select on ds_ids to authenticated;
insert into public.decision_options(decision_id,label) select id,'Label only' from ds_ids where status='DRAFT';
insert into public.decision_options(decision_id,label,development_object_id) select d.id,'Canonical Object',o.id from ds_ids d cross join vc_objects o where d.status='DRAFT' and o.kind='PROBLEM';
insert into public.decision_participants(decision_id,user_id,role) select id,'00000000-0000-4000-8000-000000006004','participant' from ds_ids where status='DRAFT';
insert into public.artifacts(project_id,workspace_id,artifact_type,title,created_by) select project_id,workspace_id,'PROBLEM_BANK','Isolated target fixture','00000000-0000-4000-8000-000000006004' from ds_context;
insert into public.decision_links(decision_id,linked_entity_type,linked_entity_id,relationship_type)
select d.id,'VOTING_SESSION',(v.payload#>>'{session,id}')::uuid,'context' from ds_ids d cross join vc_results v where d.status='DRAFT' and jsonb_array_length(v.payload->'options')=3;
insert into public.decision_links(decision_id,linked_entity_type,linked_entity_id,relationship_type)
select d.id,'DEVELOPMENT_OBJECT',o.id,'context' from ds_ids d cross join vc_objects o where d.status='DRAFT' and o.kind='PROBLEM';
insert into public.decision_links(decision_id,linked_entity_type,linked_entity_id,relationship_type)
select d.id,'ARTIFACT',a.id,'context' from ds_ids d join public.artifacts a on a.title='Isolated target fixture' where d.status='DRAFT';
do $$declare d public.decisions;o public.decision_options;t text;kind public.decision_link_entity_type;fake uuid:='ffffffff-ffff-4fff-8fff-ffffffffffff';p uuid;w uuid;e uuid;begin
 select * into d from public.decisions where status='DRAFT';
 assert d.outcome is null and d.reasoning is null and d.decided_at is null;
 assert (select count(distinct status) from public.decisions)=4;assert (select count(distinct method) from public.decisions)=4;
 assert (select count(*) from public.decisions)=4;
 begin insert into public.decisions(project_id,workspace_id,title,question,method,decision_owner_user_id) values(d.project_id,d.workspace_id,'Default fixture','Q','OTHER',d.decision_owner_user_id);
 assert (select status from public.decisions where title='Default fixture')='DRAFT';
 raise exception 'Discard default fixture' using errcode='P0002';exception when no_data_found then null;end;
 assert not exists(select 1 from public.decision_options where selected);
 assert (select count(*) from public.decision_options where development_object_id is null)=1;
 assert (select position is null and comment is null from public.decision_participants where decision_id=d.id);
 foreach t in array array['decisions','decision_options','decision_participants','decision_links'] loop
 assert (select relrowsecurity from pg_class where oid=('public.'||t)::regclass);
 assert has_table_privilege('authenticated','public.'||t,'select');
 assert not has_table_privilege('authenticated','public.'||t,'insert,update,delete');
 assert not has_table_privilege('anon','public.'||t,'select,insert,update,delete');
 assert not exists(select 1 from pg_policy where polrelid=('public.'||t)::regclass and polpermissive and polcmd<>'r');
 end loop;
 begin insert into public.decisions(project_id,workspace_id,title,question,method,decision_owner_user_id) values(fake,d.workspace_id,'X','Q','OTHER',d.decision_owner_user_id);raise exception 'Project FK';exception when foreign_key_violation then null;end;
 begin insert into public.decisions(project_id,workspace_id,title,question,method,decision_owner_user_id) values(d.project_id,fake,'X','Q','OTHER',d.decision_owner_user_id);raise exception 'Workspace FK';exception when foreign_key_violation then null;end;
 begin insert into public.decisions(project_id,workspace_id,activity_instance_id,title,question,method,decision_owner_user_id) values(d.project_id,d.workspace_id,fake,'X','Q','OTHER',d.decision_owner_user_id);raise exception 'Activity FK';exception when foreign_key_violation then null;end;
 begin insert into public.decisions(project_id,workspace_id,title,question,method,decision_owner_user_id) values(d.project_id,d.workspace_id,'X','Q','OTHER',fake);raise exception 'Owner FK';exception when foreign_key_violation then null;end;
 begin update public.decisions set status='OPEN' where id=d.id;raise exception 'Invalid status';exception when invalid_text_representation then null;end;
 begin update public.decisions set method='PLANNING_POKER' where id=d.id;raise exception 'Invalid method';exception when invalid_text_representation then null;end;
 begin update public.decisions set title=' ' where id=d.id;raise exception 'Blank title';exception when check_violation then null;end;
 begin update public.decisions set question='' where id=d.id;raise exception 'Blank question';exception when check_violation then null;end;
 select (payload->>'id')::uuid,(payload->>'primary_workspace_id')::uuid into p,w from logged_projects where label<>'Team' limit 1;
 assert p is not null and w is not null;
 insert into public.artifacts(project_id,workspace_id,artifact_type,title,created_by) values(p,w,'PROBLEM_BANK','Foreign isolated target',d.decision_owner_user_id) returning id into e;
 begin insert into public.decision_links(decision_id,linked_entity_type,linked_entity_id,relationship_type) values(d.id,'ARTIFACT',e,'context');raise exception 'Foreign Artifact link';exception when check_violation then null;end;
 insert into public.voting_sessions(activity_instance_id,voting_type,vote_limit,created_by) values((select id from vc_foreign_activities limit 1),'DOT_VOTE',0,d.decision_owner_user_id) returning id into e;
 begin insert into public.decision_links(decision_id,linked_entity_type,linked_entity_id,relationship_type) values(d.id,'VOTING_SESSION',e,'context');raise exception 'Foreign Voting link';exception when check_violation then null;end;

 begin insert into public.decisions(project_id,workspace_id,title,question,method,decision_owner_user_id) values(d.project_id,w,'X','Q','OTHER',d.decision_owner_user_id);raise exception 'Project/Workspace mismatch';exception when foreign_key_violation then null;end;
 begin insert into public.decisions(project_id,workspace_id,activity_instance_id,title,question,method,decision_owner_user_id) values(p,w,d.activity_instance_id,'X','Q','OTHER',d.decision_owner_user_id);raise exception 'Activity scope mismatch';exception when foreign_key_violation then null;end;
 begin insert into public.decision_options(decision_id,label) values(d.id,' ');raise exception 'Blank label';exception when check_violation then null;end;
 begin insert into public.decision_participants(decision_id,user_id,role) values(fake,d.decision_owner_user_id,'participant');raise exception 'Participant parent';exception when foreign_key_violation then null;end;
 begin insert into public.decision_links(decision_id,linked_entity_type,linked_entity_id,relationship_type) values(fake,'DEVELOPMENT_OBJECT',(select id from vc_objects vo where vo.kind='PROBLEM'),'context');raise exception 'Link parent';exception when foreign_key_violation then null;end;
 begin insert into public.decision_links(decision_id,linked_entity_type,linked_entity_id,relationship_type) values(d.id,'DEVELOPMENT_OBJECT',(select id from vc_objects vo where vo.kind='PROBLEM'),' ');raise exception 'Blank relationship';exception when check_violation then null;end;
 begin insert into public.decision_options(decision_id,label) values(fake,'X');raise exception 'Option parent';exception when foreign_key_violation then null;end;
 begin insert into public.decision_options(decision_id,label,development_object_id) values(d.id,'X',fake);raise exception 'Object FK';exception when foreign_key_violation then null;end;
 begin insert into public.decision_options(decision_id,label,development_object_id) values(d.id,'Foreign',(select id from vc_foreign_objects limit 1));raise exception 'Foreign Object';exception when check_violation then null;end;
 begin insert into public.decision_participants(decision_id,user_id,role) values(d.id,fake,'participant');raise exception 'Participant user';exception when foreign_key_violation then null;end;
 begin insert into public.decision_participants(decision_id,user_id,role) values(d.id,d.decision_owner_user_id,'Master');raise exception 'Duplicate human';exception when unique_violation then null;end;
 begin insert into public.decision_participants(decision_id,user_id,role) values(d.id,'00000000-0000-4000-8000-000000006005',' ');raise exception 'Blank role';exception when check_violation then null;end;
 foreach kind in array array['VOTING_SESSION','ARTIFACT','DEVELOPMENT_OBJECT']::public.decision_link_entity_type[] loop
 begin insert into public.decision_links(decision_id,linked_entity_type,linked_entity_id,relationship_type) values(d.id,kind,fake,'context');raise exception 'Missing polymorphic target';exception when foreign_key_violation then null;end;end loop;
 foreach kind in array array['EVIDENCE','AI_OUTPUT']::public.decision_link_entity_type[] loop
 begin insert into public.decision_links(decision_id,linked_entity_type,linked_entity_id,relationship_type) values(d.id,kind,fake,'context');raise exception 'Future target fabricated';exception when check_violation then null;end;end loop;
 begin insert into public.decision_links(decision_id,linked_entity_type,linked_entity_id,relationship_type) values(d.id,'DEVELOPMENT_OBJECT',(select id from vc_foreign_objects limit 1),'context');raise exception 'Foreign link';exception when check_violation then null;end;
 begin insert into public.decision_links(decision_id,linked_entity_type,linked_entity_id,relationship_type) select decision_id,linked_entity_type,linked_entity_id,relationship_type from public.decision_links limit 1;raise exception 'Duplicate link';exception when unique_violation then null;end;
 insert into public.decision_links(decision_id,linked_entity_type,linked_entity_id,relationship_type) select decision_id,linked_entity_type,linked_entity_id,'different context' from public.decision_links limit 1;
 -- Multiple selected Options are structurally supported, not auto-selected/finalized.
 update public.decision_options set selected=true where decision_id=d.id;assert (select count(*) from public.decision_options where selected)=2;
 assert (select status from public.decisions where id=d.id)='DRAFT';
 begin update public.decisions set decision_owner_user_id='00000000-0000-4000-8000-000000006005' where id=d.id;raise exception 'Owner transfer';exception when check_violation then null;end;
 foreach t in array array['decisions','decision_options','decision_participants','decision_links'] loop
 begin execute format('delete from public.%I',t);raise exception 'History delete';exception when check_violation then null;end;end loop;
 begin delete from public.voting_sessions where id=(select linked_entity_id from public.decision_links where linked_entity_type='VOTING_SESSION' limit 1);raise exception 'Linked Session deletion';exception when foreign_key_violation then null;end;
 begin update public.voting_sessions set activity_instance_id=(select id from vc_foreign_activities limit 1) where id=(select linked_entity_id from public.decision_links where linked_entity_type='VOTING_SESSION' limit 1);raise exception 'Linked Session scope changed';exception when foreign_key_violation then null;end;
 assert has_function_privilege('authenticated','public.supersede_decision(jsonb)','execute');
 assert not has_function_privilege('anon','public.supersede_decision(jsonb)','execute');
 assert not has_function_privilege('service_role','public.supersede_decision(jsonb)','execute');
 assert not exists(select 1 from public.evidence) and not exists(select 1 from public.ai_outputs);
 assert not exists(select 1 from information_schema.columns where table_schema='public' and table_name='decisions' and column_name in ('vote_count','winner_id','top_option_id','team_id'));
 assert not exists(select 1 from pg_trigger where tgrelid='public.voting_sessions'::regclass and not tgisinternal and tgfoid<>'public.restrict_decision_link_target_change()'::regprocedure);
end $$;
update public.decision_participants set role='ADMIN';
-- Even hypothetical future broad grants cannot turn contextual participant metadata
-- into authorization. No permissive policy exists and restrictive guards remain.
grant select,insert,update,delete on public.decisions,public.decision_options,public.decision_participants,public.decision_links to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$declare d uuid;t text;begin
 select id into d from ds_ids where status='DRAFT';
 foreach t in array array['decisions','decision_options','decision_participants','decision_links'] loop
 execute format('select exists(select 1 from public.%I where not public.can_read_decision(%I))',t,case when t='decisions' then 'id' else 'decision_id' end) into strict t;
 assert t='false';end loop;
 begin insert into public.decisions(project_id,workspace_id,title,question,method,decision_owner_user_id) values('ffffffff-ffff-4fff-8fff-ffffffffffff','ffffffff-ffff-4fff-8fff-ffffffffffff','Spoof','Q','OTHER','00000000-0000-4000-8000-000000006002');raise exception 'Forged Decision';exception when insufficient_privilege then null;end;
 update public.decisions set status='FINALIZED',decided_at=clock_timestamp();assert not found;
 update public.decision_options set selected=false;assert not found;
 begin insert into public.decision_participants(decision_id,user_id,role) values(d,'00000000-0000-4000-8000-000000006004','ADMIN');raise exception 'Forged participant';exception when insufficient_privilege then null;end;
 begin insert into public.decision_links(decision_id,linked_entity_type,linked_entity_id,relationship_type) values(d,'VOTING_SESSION','ffffffff-ffff-4fff-8fff-ffffffffffff','context');raise exception 'Forged link';exception when insufficient_privilege or foreign_key_violation then null;end;
 delete from public.decisions;assert not found;
end $$;
reset role;
-- AT-VOTE-003: real open/cast/close leaves Decision storage unchanged.
create temporary table ds_before as select jsonb_agg(to_jsonb(d) order by id) payload from public.decisions d;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.open_voting_session((payload#>>'{session,id}')::uuid) from vc_results where jsonb_array_length(payload->'options')=3;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select public.cast_vote(s.id,o.id,1) from public.get_voting_results((select (payload#>>'{session,id}')::uuid from vc_results where jsonb_array_length(payload->'options')=3)) r cross join lateral (select (r#>>'{session,id}')::uuid id) s cross join lateral (select (r#>>'{options,0,id}')::uuid id) o;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.close_voting_session((payload#>>'{session,id}')::uuid) from vc_results where jsonb_array_length(payload->'options')=3;
reset role;
do $$begin assert (select payload from ds_before)=(select jsonb_agg(to_jsonb(d) order by id) from public.decisions d);assert (select count(*) from public.decision_options where selected)=2;end $$;
\pset format unaligned
select 'M108_DECISION='||row_to_json(d)::text from public.decisions d where status='DRAFT';
select 'M108_OPTION='||row_to_json(o)::text from public.decision_options o where development_object_id is null;
select 'M108_PARTICIPANT='||row_to_json(p)::text from public.decision_participants p;
select 'M108_LINK='||row_to_json(l)::text from public.decision_links l where linked_entity_type='ARTIFACT';
select 'M10.8 schema/status/method/FK/scope/links/history/default-deny/type-parity/AT-VOTE-003 PASS';
rollback;
