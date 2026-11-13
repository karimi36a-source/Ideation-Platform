-- Canonical isolated Brainstorm fixture prepended; trusted setup only.
reset role;
select set_config('request.jwt.claim.sub','',true);
create temporary table bs_context as select x.label,i.* from instances x join public.activity_instances i on i.id=x.id;
create temporary table bs_saved(label text primary key,id uuid);
grant select on bs_context,bs_saved to authenticated,anon;
create function pg_temp.bs_insert(a uuid,p uuid,w uuid,u uuid,o uuid default null,parent uuid default null) returns uuid language sql as $$
 insert into public.brainstorm_entries(activity_instance_id,project_id,workspace_id,created_by,content,development_object_id,parent_entry_id)
 values(a,p,w,u,'Private brainstorm',o,parent) returning id $$;
insert into bs_saved select label,pg_temp.bs_insert(id,project_id,workspace_id,started_by) from bs_context;
insert into bs_saved select 'Child',pg_temp.bs_insert(c.id,c.project_id,c.workspace_id,c.started_by,null,s.id) from bs_context c join bs_saved s on s.label=c.label where c.label='Individual';
insert into bs_saved select 'Peer',pg_temp.bs_insert(id,project_id,workspace_id,'00000000-0000-4000-8000-000000006005') from bs_context where label='Team';
create temporary table bs_before as select * from public.brainstorm_entries;
do $$declare c record;t record;e uuid;begin
 select * into strict c from bs_context where label='Individual';select * into strict t from bs_context where label='Team';
 assert (select count(*) from public.brainstorm_entries)=5;
 assert not exists(select 1 from public.brainstorm_entries where status<>'active' or archived_at is not null or revealed_at is not null or updated_by<>created_by);
 foreach e in array array[(select (payload->>'id')::uuid from logged_objects where label='Individual Idea'),(select (payload->>'id')::uuid from logged_objects where label='Solution')] loop
  perform pg_temp.bs_insert(c.id,c.project_id,c.workspace_id,c.started_by,e);
 end loop;
 begin perform pg_temp.bs_insert(c.id,c.project_id,c.workspace_id,c.started_by,(select (payload->>'id')::uuid from logged_objects where label='Problem'));raise exception 'Invalid Object type';exception when check_violation then null;end;
 begin perform pg_temp.bs_insert(c.id,c.project_id,c.workspace_id,c.started_by,(select (payload->>'id')::uuid from logged_objects where label='Team Idea'));raise exception 'Foreign Object';exception when check_violation or foreign_key_violation then null;end;
 begin perform pg_temp.bs_insert(c.id,t.project_id,c.workspace_id,c.started_by);raise exception 'Foreign Project';exception when check_violation or foreign_key_violation then null;end;
 begin perform pg_temp.bs_insert(c.id,c.project_id,t.workspace_id,c.started_by);raise exception 'Foreign Workspace';exception when check_violation or foreign_key_violation then null;end;
 begin perform pg_temp.bs_insert(c.id,c.project_id,c.workspace_id,c.started_by,null,(select id from bs_saved where label='Team'));raise exception 'Cross Team parent';exception when foreign_key_violation then null;end;
 begin perform pg_temp.bs_insert(c.id,c.project_id,c.workspace_id,c.started_by,null,gen_random_uuid());raise exception 'Missing parent';exception when foreign_key_violation then null;end;
 select id into e from bs_saved where label='Individual';
 begin update public.brainstorm_entries set parent_entry_id=id where id=e;raise exception 'Self parent';exception when check_violation then null;end;
 begin update public.brainstorm_entries set created_by=t.started_by,id=gen_random_uuid() where id=e;raise exception 'Identity changed';exception when check_violation then null;end;
 begin update public.brainstorm_entries set status='archived' where id=e;raise exception 'No archive time';exception when check_violation then null;end;
 begin update public.brainstorm_entries set archived_at=now() where id=e;raise exception 'Active archive time';exception when check_violation then null;end;
 update public.brainstorm_entries set status='archived',archived_at=now() where id=e;
 assert exists(select 1 from public.brainstorm_entries b join bs_before a using(id) where b.id=e and b.created_by=a.created_by and b.content=a.content and b.created_at=a.created_at);
 begin update public.brainstorm_entries set status='active',archived_at=null where id=e;raise exception 'Restored history';exception when check_violation then null;end;
 begin delete from public.brainstorm_entries where id=e;raise exception 'Deleted history';exception when check_violation then null;end;
 begin perform 'private'::public.brainstorm_entry_status;raise exception 'Reveal status accepted';exception when invalid_text_representation then null;end;
end $$;
-- A real Team B context proves cross-Team parent rejection and direct-ID isolation.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006001',true);
set local role authenticated;
insert into logged_projects values('Brainstorm Team B',public.create_development_project('Brainstorm Team B','team',(select (payload->>'workspaceId')::uuid from acceptance_teams where label='B'),null,null,(select (payload->>'teamId')::uuid from acceptance_teams where label='B')));
reset role;
select set_config('request.jwt.claim.sub','',true);
insert into public.project_memberships(project_id,user_id) select (payload->>'id')::uuid,'00000000-0000-4000-8000-000000006006' from logged_projects where label='Brainstorm Team B';
insert into public.project_program_links(project_id,program_id,cohort_id) select (payload->>'id')::uuid,'00000000-0000-4000-8000-000000000601',(select id from acceptance_cohorts where label='Test') from logged_projects where label='Brainstorm Team B';
insert into public.activity_instances(id,activity_definition_id,cohort_id,project_id,workspace_id,team_id,started_by,started_at,status,configuration_snapshot)
select '00000000-0000-4000-8000-000000950903','00000000-0000-4000-8000-000000950801',(select id from acceptance_cohorts where label='Test'),(p.payload->>'id')::uuid,(p.payload->>'primary_workspace_id')::uuid,(t.payload->>'teamId')::uuid,'00000000-0000-4000-8000-000000006006',now(),'active','{"method_type":"brainstorming"}' from logged_projects p cross join acceptance_teams t where p.label='Brainstorm Team B' and t.label='B';
insert into bs_context select 'Team B',i.* from public.activity_instances i where id='00000000-0000-4000-8000-000000950903';
insert into bs_saved select 'Team B',pg_temp.bs_insert(id,project_id,workspace_id,started_by) from bs_context where label='Team B';
do $$declare c record;begin select * into c from bs_context where label='Team';
 begin perform pg_temp.bs_insert(c.id,c.project_id,c.workspace_id,c.started_by,null,(select id from bs_saved where label='Team B'));raise exception 'Team B parent accepted in Team A';exception when foreign_key_violation then null;end;
end $$;
-- Same Project/Workspace but different Activity is still not a compatible parent.
insert into public.activity_instances(id,activity_definition_id,cohort_id,project_id,workspace_id,started_by,started_at,completed_at,status,configuration_snapshot)
select '00000000-0000-4000-8000-000000950901',activity_definition_id,cohort_id,project_id,workspace_id,started_by,started_at,now(),'completed',configuration_snapshot from bs_context where label='Individual';
do $$declare c record;begin select * into c from bs_context where label='Individual';
 begin perform pg_temp.bs_insert('00000000-0000-4000-8000-000000950901',c.project_id,c.workspace_id,c.started_by,null,(select id from bs_saved where label='Child'));raise exception 'Unrelated Activity parent';exception when foreign_key_violation then null;end;
end $$;
insert into public.activity_instances(id,activity_definition_id,cohort_id,project_id,workspace_id,started_by,started_at,status,configuration_snapshot)
select '00000000-0000-4000-8000-000000950902','00000000-0000-4000-8000-000000950802',cohort_id,project_id,workspace_id,started_by,started_at,status,'{"method_type":"brainstorming"}' from bs_context where label='Individual';
do $$declare c record;begin select * into c from bs_context where label='Individual';
 begin perform pg_temp.bs_insert('00000000-0000-4000-8000-000000950902',c.project_id,c.workspace_id,c.started_by);raise exception 'Name/snapshot authorized custom method';exception when check_violation then null;end;
end $$;
-- Integrity guards also reject spoofed creator/reveal even under trusted DB role with auth context.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$declare c record;begin select * into c from bs_context where label='Team';
 begin perform pg_temp.bs_insert(c.id,c.project_id,c.workspace_id,'00000000-0000-4000-8000-000000006005');raise exception 'Creator spoof';exception when insufficient_privilege then null;end;
 begin update public.brainstorm_entries set revealed_at=now() where id=(select id from bs_saved where label='Team');raise exception 'Reveal spoof';exception when insufficient_privilege then null;end;
 begin perform pg_temp.bs_insert(c.id,c.project_id,c.workspace_id,c.started_by,null,(select id from bs_saved where label='Peer'));raise exception 'Invisible parent';exception when insufficient_privilege then null;end;
end $$;
set local role authenticated;
do $$begin
 assert exists(select 1 from public.brainstorm_entries where id=(select id from bs_saved where label='Team')),'Creator own Team read';
 assert exists(select 1 from public.brainstorm_entries where id=(select id from bs_saved where label='Child')),'Creator Personal read';
 assert not exists(select 1 from public.brainstorm_entries where id=(select id from bs_saved where label='Peer')),'Peer exact ID leaked';
 begin insert into public.brainstorm_entries(activity_instance_id,project_id,workspace_id,content) select id,project_id,workspace_id,'Forged' from bs_context where label='Team';raise exception 'Client insert';exception when insufficient_privilege then null;end;
 begin update public.brainstorm_entries set revealed_at=now();raise exception 'Client update';exception when insufficient_privilege then null;end;
 begin delete from public.brainstorm_entries;raise exception 'Client delete';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
do $$begin
 assert public.can_read_activity_instance((select id from bs_context where label='Team')),'Peer has Activity access';
 assert not exists(select 1 from public.brainstorm_entries where created_by='00000000-0000-4000-8000-000000006004'),'Private rows leaked via creator filter';
 assert not exists(select 1 from public.brainstorm_entries where id=(select id from bs_saved where label='Team')),'Exact ID leaked';
 assert exists(select 1 from public.brainstorm_entries where id=(select id from bs_saved where label='Peer'));
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006006',true);
do $$begin
 assert exists(select 1 from public.brainstorm_entries where id=(select id from bs_saved where label='Team B')),'Team B creator read';
 assert not exists(select 1 from public.brainstorm_entries where id=(select id from bs_saved where label='Team')),'Cross Team exact ID';
end $$;
-- Admin/Master/Mentor/Team B never gain private creator content merely through role.
do $$declare n int;begin for n in select unnest(array[6001,6002,6003,6006,6008]) loop
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(n::text,12,'0'),true);
 assert not exists(select 1 from public.brainstorm_entries where created_by='00000000-0000-4000-8000-000000006004'),'Unrelated role leaked entries';end loop;end $$;
reset role;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
set local role authenticated;
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006004');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin assert not exists(select 1 from public.brainstorm_entries where id=(select id from bs_saved where label='Team')),'Removed author access';assert exists(select 1 from public.brainstorm_entries where id=(select id from bs_saved where label='Child')),'Personal affected';end $$;
reset role;
set local role anon;
do $$begin begin perform * from public.brainstorm_entries;raise exception 'Anonymous read';exception when insufficient_privilege then null;end;end $$;
reset role;
do $$begin
 assert (select relrowsecurity from pg_class where oid='public.brainstorm_entries'::regclass);
 assert not exists(select 1 from information_schema.role_table_grants where table_name='brainstorm_entries' and grantee in ('anon','authenticated','service_role') and privilege_type<>'SELECT');
 assert not (select prosecdef from pg_proc where oid='public.validate_brainstorm_entry()'::regprocedure);
 assert not has_function_privilege('authenticated','public.validate_brainstorm_entry()','EXECUTE');
 assert (select count(*) from public.brainstorm_entries)>=7;
end $$;
select 'M95_STATUSES='||to_json(enum_range(null::public.brainstorm_entry_status))::text;
select 'M95_COLUMNS='||json_agg(column_name order by column_name)::text from information_schema.columns where table_schema='public' and table_name='brainstorm_entries';
select 'M9.5 Brainstorm schema / parent scope / private creator reads / hostile CRUD / removal / history PASS';
rollback;
