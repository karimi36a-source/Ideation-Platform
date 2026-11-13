\set ON_ERROR_STOP on
begin;
-- Session numbers below are isolated temporary metadata, never execution entities.
insert into auth.users(id,email) values
 ('00000000-0000-4000-8000-000000006004','object-reuse-owner@example.test'),
 ('00000000-0000-4000-8000-000000006005','object-reuse-other@example.test');
select public.provision_user_profile(id,'active') from auth.users where email like 'object-reuse-%@example.test';
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select public.create_personal_workspace();
create temporary table reuse_created(project jsonb,object jsonb,details jsonb);
insert into reuse_created(project) select public.create_development_project(
 'AT-PROJ-002 Project A','individual',id) from public.workspaces where workspace_type='PERSONAL';
update reuse_created set object=public.create_development_object(
 (project->>'id')::uuid,(project->>'primary_workspace_id')::uuid,'PROBLEM','AT-PROJ-002 Problem P','Initial Problem content',null);
update reuse_created set details=public.write_problem_details((object->>'id')::uuid,'{}',true);
create temporary table reuse_contexts(session_number integer primary key,project_id uuid,object_id uuid);
create temporary table reuse_observed(session_number integer primary key,project jsonb,object jsonb,details jsonb);
insert into reuse_contexts select 4,(project->>'id')::uuid,(object->>'id')::uuid from reuse_created;
insert into reuse_observed select c.session_number,to_jsonb(p),to_jsonb(o),to_jsonb(d)
 from reuse_contexts c join public.development_projects p on p.id=c.project_id
 join public.development_objects o on o.id=c.object_id and o.project_id=p.id and o.workspace_id=p.primary_workspace_id
 join public.problem_details d on d.development_object_id=o.id;
-- Session 5 references the existing object; loading it creates no log event.
insert into reuse_contexts select 5,project_id,object_id from reuse_contexts where session_number=4;
do $$declare o public.development_objects;begin
 select x.* into o from public.development_objects x join reuse_contexts c on c.object_id=x.id where c.session_number=5;
 assert to_jsonb(o)=(select object from reuse_created),'Session 5 initially loads original object';
 assert (select count(*) from public.change_log where entity_id=o.id and change_type='OBJECT_CREATED')=1,'one creation before update';
 assert not exists(select 1 from public.change_log where entity_id=o.id and change_type='OBJECT_UPDATED'),'reference is not an update';
end $$;
-- Exactly one real approved M6.6 mutation, without version-table behavior.
select public.update_development_object((select object_id from reuse_contexts where session_number=5),
 '{"content":"Refined Problem after Session 5"}');
insert into reuse_observed select c.session_number,to_jsonb(p),to_jsonb(o),to_jsonb(d)
 from reuse_contexts c join public.development_projects p on p.id=c.project_id
 join public.development_objects o on o.id=c.object_id and o.project_id=p.id and o.workspace_id=p.primary_workspace_id
 join public.problem_details d on d.development_object_id=o.id where c.session_number=5;
-- Session 6 re-queries current canonical state, not an in-memory RPC result.
insert into reuse_contexts select 6,project_id,object_id from reuse_contexts where session_number=4;
insert into reuse_observed select c.session_number,to_jsonb(p),to_jsonb(o),to_jsonb(d)
 from reuse_contexts c join public.development_projects p on p.id=c.project_id
 join public.development_objects o on o.id=c.object_id and o.project_id=p.id and o.workspace_id=p.primary_workspace_id
 join public.problem_details d on d.development_object_id=o.id where c.session_number=6;
do $$declare before0 jsonb;after0 jsonb;k text;p uuid;o uuid;begin
 select object into before0 from reuse_observed where session_number=4;
 select object into after0 from reuse_observed where session_number=6;
 assert before0 is not null and after0 is not null and (select count(*) from reuse_observed)=3,'all contexts load canonical rows';
 foreach k in array array['id','project_id','workspace_id','created_by','created_at','object_type','current_version_number','archived_at','title'] loop
 assert before0->k=after0->k,'immutable continuity: '||k;
 assert (select count(distinct object->k) from reuse_observed)=1,'same identity across 4/5/6: '||k;
 end loop;
 assert before0->>'content'='Initial Problem content','recorded initial state';
 assert after0->>'content'='Refined Problem after Session 5','updated state persists';
 assert after0=(select object from reuse_observed where session_number=5),'Session 6 reuse preserves updated state and timestamp';
 assert (after0->>'updated_at')::timestamptz>(before0->>'updated_at')::timestamptz,'real update timestamp';
 assert after0->>'current_version_number'='1' and after0->'archived_at'='null'::jsonb,'active object; formal versioning deferred';
 assert (select count(distinct project) from reuse_observed)=1,'Project and ownership unchanged';
 assert (select count(distinct details) from reuse_observed)=1,'typed extension unchanged';
 p:=(after0->>'project_id')::uuid;o:=(after0->>'id')::uuid;
 assert (select count(*) from public.development_projects where name='AT-PROJ-002 Project A')=1,'one Project';
 assert (select count(*) from public.development_objects where project_id=p)=1,'one canonical Object';
 assert (select count(*) from public.problem_details where development_object_id=o)=1,'one typed Problem extension';
 assert (select count(*) from public.change_log where entity_id=o and change_type='OBJECT_CREATED')=1,'one object creation';
 assert (select count(*) from public.change_log where entity_id=o and change_type='OBJECT_UPDATED')=1,'one actual update';
 assert exists(select 1 from public.change_log where entity_id=o and project_id=p and entity_type='DEVELOPMENT_OBJECT' and change_type='OBJECT_UPDATED' and changed_by=auth.uid()),'verified update attribution';
 assert (select count(*) from public.change_log where project_id=p)=3,'Project creation, Object creation and real update only';
end $$;
-- Another Student cannot recover exact-ID object/detail/history access or modify P.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
do $$declare o uuid;p uuid;begin
 select object_id,project_id into o,p from reuse_contexts where session_number=6;
 assert not exists(select 1 from public.development_objects where id=o),'exact Object ID privacy';
 assert not exists(select 1 from public.problem_details where development_object_id=o),'typed privacy';
 assert not exists(select 1 from public.development_projects where id=p),'Project privacy';
 assert not exists(select 1 from public.change_log where entity_id=o),'log privacy';
 begin perform public.update_development_object(o,'{"content":"Unauthorized"}');raise exception 'context spoof';exception when insufficient_privilege then null;end;
end $$;
reset role;
-- Trusted counts also catch duplicates that authenticated RLS could hide.
do $$declare p uuid;o uuid;begin
 select (project->>'id')::uuid,(object->>'id')::uuid into p,o from reuse_created;
 assert (select count(*) from public.development_projects where name='AT-PROJ-002 Project A')=1,'trusted Project count';
 assert (select count(*) from public.development_objects where project_id=p)=1,'trusted Object count';
 assert (select count(*) from public.problem_details d join public.development_objects x on x.id=d.development_object_id where x.project_id=p)=1,'trusted typed count';
 assert (select to_jsonb(x) from public.development_objects x where id=o)=(select object from reuse_observed where session_number=6),'unauthorized attempt cannot mutate canonical Object';
 assert not exists(select 1 from public.change_log where entity_id=o and change_type='OBJECT_ARCHIVED'),'Object not archived';
 assert not exists(select 1 from public.activity_instances) and to_regclass('public.project_baselines') is null,'later entities remain absent';
end $$;
select 'M6_14_REUSE='||jsonb_build_object(
 'session4ObjectId',a.object->>'id','session5ObjectId',b.object->>'id','session6ObjectId',c.object->>'id',
 'projectId',c.object->>'project_id','workspaceId',c.object->>'workspace_id','createdBy',c.object->>'created_by',
 'currentVersionNumber',(c.object->>'current_version_number')::integer,
 'objectCount',(select count(*) from public.development_objects where project_id=(c.project->>'id')::uuid),
 'typedProblemCount',(select count(*) from public.problem_details where development_object_id=(c.object->>'id')::uuid),
 'objectCreatedCount',(select count(*) from public.change_log where entity_id=(c.object->>'id')::uuid and change_type='OBJECT_CREATED'),
 'objectUpdatedCount',(select count(*) from public.change_log where entity_id=(c.object->>'id')::uuid and change_type='OBJECT_UPDATED'))::text
 from reuse_observed a cross join reuse_observed b cross join reuse_observed c
 where a.session_number=4 and b.session_number=5 and c.session_number=6;
rollback;
\echo M6.14 AT-PROJ-002 PostgreSQL reuse/identity/typed-count/update/log/privacy PASS
