\set ON_ERROR_STOP on
begin;
-- Isolated context labels are test metadata, not Activity/Session execution rows.
insert into auth.users(id,email) values
 ('00000000-0000-4000-8000-000000006004','continuity-owner@example.test'),
 ('00000000-0000-4000-8000-000000006005','continuity-other@example.test');
select public.provision_user_profile(id,'active') from auth.users where email like 'continuity-%@example.test';
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select public.create_personal_workspace();
create temporary table continuity_created(project jsonb,object jsonb);
insert into continuity_created(project) select public.create_development_project(
 'AT-PROJ-001 Project A','individual',id) from public.workspaces where workspace_type='PERSONAL';
update continuity_created set object=public.create_development_object(
 (project->>'id')::uuid,(project->>'primary_workspace_id')::uuid,'PROBLEM','AT-PROJ-001 Problem','Continuity fixture',null);
create temporary table continuity_contexts(context_label text primary key,project_id uuid,object_id uuid);
create temporary table continuity_observations(context_label text primary key,project jsonb,object jsonb);
insert into continuity_contexts select 'early-course context',(project->>'id')::uuid,(object->>'id')::uuid from continuity_created;
-- Fresh RLS-governed database load, independent of the RPC return object.
insert into continuity_observations select c.context_label,to_jsonb(p),to_jsonb(o)
 from continuity_contexts c join public.development_projects p on p.id=c.project_id
 join public.development_objects o on o.id=c.object_id and o.project_id=p.id and o.workspace_id=p.primary_workspace_id;
-- Later use references existing identities only: no Project/Object creation call.
insert into continuity_contexts select 'later-course context',project_id,object_id
 from continuity_contexts where context_label='early-course context';
insert into continuity_observations select c.context_label,to_jsonb(p),to_jsonb(o)
 from continuity_contexts c join public.development_projects p on p.id=c.project_id
 join public.development_objects o on o.id=c.object_id and o.project_id=p.id and o.workspace_id=p.primary_workspace_id
 where c.context_label='later-course context';
do $$declare early record;later record;begin
 select * into early from continuity_observations where context_label='early-course context';
 select * into later from continuity_observations where context_label='later-course context';
 assert early.project is not null and later.project is not null,'both contexts load canonical Project';
 assert early.project=later.project,'Project identity/type/owner/Workspace/status and metadata unchanged';
 assert early.object=later.object,'existing Object ID/Project/Workspace and metadata unchanged';
 assert early.project->>'id'=early.object->>'project_id','Object remains attached to canonical Project';
 assert (select count(*) from public.development_projects where name='AT-PROJ-001 Project A')=1,'actual canonical Project count';
 assert (select count(*) from public.development_objects where project_id=(early.project->>'id')::uuid)=1,'no later-context Object duplicate';
 assert (select count(*) from public.change_log where project_id=(early.project->>'id')::uuid and change_type='PROJECT_CREATED')=1,'reuse creates no fake creation event';
 assert (select count(*) from public.change_log where project_id=(early.project->>'id')::uuid)=2,'reads create no Change Log entries';
 assert not exists(select 1 from public.project_program_links where project_id=(early.project->>'id')::uuid),'no unnecessary Program link';
end $$;
-- Known fixture references never establish another Student's authority.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
do $$declare p uuid;o uuid;begin
 select project_id,object_id into p,o from continuity_contexts where context_label='later-course context';
 assert not exists(select 1 from public.development_projects where id=p),'another Student exact Project ID denied';
 assert not exists(select 1 from public.development_objects where id=o),'another Student exact Object ID denied';
 assert not exists(select 1 from public.change_log where project_id=p),'another Student history denied';
 begin perform public.update_project_metadata(p,'{"name":"Claimed"}');raise exception 'foreign context mutation';exception when insufficient_privilege then null;end;
end $$;
reset role;
-- Trusted row-count verification detects clones even if RLS could hide a duplicate.
do $$declare p uuid;begin
 select (project->>'id')::uuid into p from continuity_created;
 assert (select count(*) from public.development_projects where name='AT-PROJ-001 Project A')=1,'trusted duplicate detection';
 assert (select count(*) from public.development_objects where project_id=p)=1,'trusted Object count';
 assert (select count(*) from public.change_log where project_id=p and change_type='PROJECT_CREATED')=1,'trusted creation event count';
 assert (select to_jsonb(x) from public.development_projects x where id=p)=(select project from continuity_created),'canonical ownership unchanged after attempted access';
 assert not exists(select 1 from public.activity_instances) and not exists(select 1 from public.activity_participants),'M7 entities remain absent';
end $$;
select 'M6_13_CONTINUITY='||jsonb_build_object(
 'earlyProjectId',e.project->>'id','laterProjectId',l.project->>'id',
 'projectType',l.project->>'project_type','ownerUserId',l.project->>'owner_user_id',
 'ownerTeamId',l.project->>'owner_team_id','workspaceId',l.project->>'primary_workspace_id',
 'status',l.project->>'status','earlyObjectId',e.object->>'id','laterObjectId',l.object->>'id',
 'projectCount',(select count(*) from public.development_projects where name='AT-PROJ-001 Project A'),
 'objectCount',(select count(*) from public.development_objects where project_id=(l.project->>'id')::uuid),
 'creationLogCount',(select count(*) from public.change_log where project_id=(l.project->>'id')::uuid and change_type='PROJECT_CREATED'))::text
 from continuity_observations e cross join continuity_observations l
 where e.context_label='early-course context' and l.context_label='later-course context';
rollback;
\echo M6.13 AT-PROJ-001 PostgreSQL identity/context/ownership/Object/count/log/privacy PASS
