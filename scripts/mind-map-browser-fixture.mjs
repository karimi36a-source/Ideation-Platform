import {affinityOperationFixture} from "./affinity-operation-fixture.mjs";

const root = process.cwd();
const definitions = `insert into public.activity_definitions(id,session_definition_id,name,method_type,workspace_mode,sequence) values
 ('00000000-0000-4000-8000-000001119001','00000000-0000-4000-8000-000000950702','Browser Team Mind Map','mind_map','Team Workspace',301),
 ('00000000-0000-4000-8000-000001119002','00000000-0000-4000-8000-000000950702','Browser Read-only Mind Map','mind_map','Team Workspace',302);`;

const fixture = affinityOperationFixture(root).replace(
  "update public.curriculum_versions set status='approved'",
  definitions + "update public.curriculum_versions set status='approved'",
);

process.stdout.write(fixture + String.raw`
create extension if not exists pgcrypto;
create table public.mind_map_browser_fixture(key text primary key,value jsonb not null);
grant select,insert,update on public.mind_map_browser_fixture to authenticated;
insert into public.mind_map_browser_fixture values
 ('scope',jsonb_build_object(
   'projectId',(select payload->>'id' from logged_projects where label='Team'),
   'workspaceId',(select payload->>'primary_workspace_id' from logged_projects where label='Team'),
   'teamId',(select payload->>'teamId' from acceptance_teams where label='A'),
   'teamBId',(select payload->>'teamId' from acceptance_teams where label='B')));

set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
insert into public.mind_map_browser_fixture
select 'activity',public.start_activity(
 '00000000-0000-4000-8000-000001119001',
 (select value->>'projectId' from public.mind_map_browser_fixture where key='scope')::uuid,
 (select value->>'workspaceId' from public.mind_map_browser_fixture where key='scope')::uuid,
 (select value->>'teamId' from public.mind_map_browser_fixture where key='scope')::uuid);
insert into public.mind_map_browser_fixture
select 'readonlyActivity',public.start_activity(
 '00000000-0000-4000-8000-000001119002',
 (select value->>'projectId' from public.mind_map_browser_fixture where key='scope')::uuid,
 (select value->>'workspaceId' from public.mind_map_browser_fixture where key='scope')::uuid,
 (select value->>'teamId' from public.mind_map_browser_fixture where key='scope')::uuid);

insert into public.mind_map_browser_fixture
select 'map',public.create_mind_map(jsonb_build_object(
 'activityInstanceId',(select value#>>'{activity,id}' from public.mind_map_browser_fixture where key='activity'),
 'idempotencyKey','browser-map'));
insert into public.mind_map_browser_fixture
select 'readonlyMap',public.create_mind_map(jsonb_build_object(
 'activityInstanceId',(select value#>>'{activity,id}' from public.mind_map_browser_fixture where key='readonlyActivity'),
 'idempotencyKey','browser-readonly-map'));

insert into public.mind_map_browser_fixture
select 'object_'||lower(kind),public.create_development_object(
 (select value->>'projectId' from public.mind_map_browser_fixture where key='scope')::uuid,
 (select value->>'workspaceId' from public.mind_map_browser_fixture where key='scope')::uuid,
 kind::public.development_object_type,'Canonical '||kind,'Canonical browser content','manual','{}')
from unnest(array['SYSTEM','SUBSYSTEM','COMPONENT','FUNCTION','PROBLEM','SOLUTION','GAP']) kind;

insert into public.mind_map_browser_fixture
select 'node_system',public.add_mind_map_node(jsonb_build_object(
 'mindMapId',(select value#>>'{mindMap,id}' from public.mind_map_browser_fixture where key='map'),
 'nodeType','SYSTEM','label','System Alpha','positionData',jsonb_build_object('x',220,'y',140),
 'parentNodeId',(select value#>>'{rootNode,id}' from public.mind_map_browser_fixture where key='map'),
 'developmentObjectId',(select value->>'id' from public.mind_map_browser_fixture where key='object_system')));
insert into public.mind_map_browser_fixture
select 'node_subsystem',public.add_mind_map_node(jsonb_build_object(
 'mindMapId',(select value#>>'{mindMap,id}' from public.mind_map_browser_fixture where key='map'),
 'nodeType','SUBSYSTEM','label','Subsystem Alpha','positionData',jsonb_build_object('x',450,'y',140),
 'parentNodeId',(select value->>'id' from public.mind_map_browser_fixture where key='node_system'),
 'developmentObjectId',(select value->>'id' from public.mind_map_browser_fixture where key='object_subsystem')));
insert into public.mind_map_browser_fixture
select 'node_component',public.add_mind_map_node(jsonb_build_object(
 'mindMapId',(select value#>>'{mindMap,id}' from public.mind_map_browser_fixture where key='map'),
 'nodeType','COMPONENT','label','Component Alpha','positionData',jsonb_build_object('x',680,'y',140),
 'parentNodeId',(select value->>'id' from public.mind_map_browser_fixture where key='node_subsystem'),
 'developmentObjectId',(select value->>'id' from public.mind_map_browser_fixture where key='object_component')));
insert into public.mind_map_browser_fixture
select 'node_function',public.add_mind_map_node(jsonb_build_object(
 'mindMapId',(select value#>>'{mindMap,id}' from public.mind_map_browser_fixture where key='map'),
 'nodeType','FUNCTION','label','Function Alpha','positionData',jsonb_build_object('x',900,'y',140),
 'parentNodeId',(select value->>'id' from public.mind_map_browser_fixture where key='node_component')));
insert into public.mind_map_browser_fixture
select 'node_'||lower(kind),public.add_mind_map_node(jsonb_build_object(
 'mindMapId',(select value#>>'{mindMap,id}' from public.mind_map_browser_fixture where key='map'),
 'nodeType',kind,'label',initcap(kind)||' Alpha',
 'positionData',jsonb_build_object('x',220+(ordinality*230),'y',380),
 'developmentObjectId',case when kind='GAP' then null else (select value->>'id' from public.mind_map_browser_fixture where key='object_'||lower(kind)) end))
from unnest(array['PROBLEM','SOLUTION','GAP']) with ordinality as x(kind,ordinality);
insert into public.mind_map_browser_fixture
select 'crossEdge',public.connect_mind_map_nodes(jsonb_build_object(
 'mindMapId',(select value#>>'{mindMap,id}' from public.mind_map_browser_fixture where key='map'),
 'sourceNodeId',(select value->>'id' from public.mind_map_browser_fixture where key='node_problem'),
 'targetNodeId',(select value->>'id' from public.mind_map_browser_fixture where key='node_solution'),
 'edgeType','CROSS_CONNECTION','label','Problem to solution'));
reset role;
update public.artifact_versions set status='SUBMITTED'
where id=(select (value#>>'{version,id}')::uuid from public.mind_map_browser_fixture where key='readonlyMap');

update auth.users set
 instance_id='00000000-0000-0000-0000-000000000000',aud='authenticated',role='authenticated',
 encrypted_password=crypt('M11.12-browser-password!',gen_salt('bf')),email_confirmed_at=clock_timestamp(),
 raw_app_meta_data='{"provider":"email","providers":["email"]}',raw_user_meta_data='{}',
 confirmation_token='',recovery_token='',email_change_token_new='',email_change='',phone_change='',
 phone_change_token='',email_change_token_current='',reauthentication_token='',
 created_at=coalesce(created_at,clock_timestamp()),updated_at=clock_timestamp()
where id between '00000000-0000-4000-8000-000000006001' and '00000000-0000-4000-8000-000000006008';
insert into auth.identities(id,provider_id,user_id,identity_data,provider,last_sign_in_at,created_at,updated_at)
select id,id::text,id,jsonb_build_object('sub',id::text,'email',email,'email_verified',true),'email',clock_timestamp(),clock_timestamp(),clock_timestamp()
from auth.users where id between '00000000-0000-4000-8000-000000006001' and '00000000-0000-4000-8000-000000006008'
on conflict do nothing;
commit;
`);
