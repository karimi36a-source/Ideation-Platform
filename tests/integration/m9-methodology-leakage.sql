-- Real normal-client roles against the committed canonical Session 4 scenario.
begin;
create function pg_temp.m920_state() returns jsonb language plpgsql set search_path='' as $$
declare t text; rows0 jsonb; state0 jsonb:='{}';begin
 foreach t in array array['scamper_entries','brainstorm_entries','development_objects','problem_details','idea_details','development_object_relationships','artifacts','artifact_versions','artifact_object_links','activity_inputs','activity_outputs','change_log','audit_events'] loop
 execute format('select coalesce(jsonb_agg(to_jsonb(x) order by to_jsonb(x)::text),''[]''::jsonb) from public.%I x',t) into rows0;state0:=state0||jsonb_build_object(t,rows0);end loop;return state0;end $$;
revoke all on function pg_temp.m920_state() from public,authenticated,anon;
-- Removal is canonical and precedes the snapshot of protected history.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((payload->>'teamId')::uuid,'00000000-0000-4000-8000-000000006004',null) from public.m919_fixture where label='Team';
reset role;
create temporary table m920_before as select pg_temp.m920_state() payload;
set local role authenticated;
do $$declare actor0 int;tab0 text;n0 bigint; b record; obj0 uuid; act0 uuid; entry0 uuid; msg0 text;begin
 foreach actor0 in array array[6007,6004,6003,6001,6008] loop
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(actor0::text,12,'0'),true);
 -- Scope filters/counts/joins exercise row filtering or a stronger ACL denial.
 foreach tab0 in array array['development_objects','artifacts','artifact_versions','artifact_object_links','development_object_relationships','activity_inputs','activity_outputs','brainstorm_entries','scamper_entries'] loop
 begin
 execute format('select count(*) from public.%I x join public.activity_instances a on to_jsonb(x)->>''activity_instance_id''=a.id::text where a.project_id=$1',tab0) into n0 using (select (payload->>'id')::uuid from public.m919_fixture where label='Project');
 assert n0=0,'Activity join enumeration';
 exception when insufficient_privilege then null;end;
 begin
 execute format('select count(*) from public.%I x where to_jsonb(x)->>''project_id''=$1',tab0) into n0 using (select payload->>'id' from public.m919_fixture where label='Project');assert n0=0,'Project count/filter leak';
 exception when insufficient_privilege then null;end;
 -- Actual exact-ID rows across canonical Objects/Banks/Versions/entries.
 begin
 execute format('select count(*) from public.%I x where x.id in (select (payload->>''id'')::uuid from public.m919_fixture where label like ''Problem%%'' or label like ''Solution%%'' or label like ''Entry%%'')',tab0) into n0;
 assert n0=0,'Exact ID enumeration';exception when insufficient_privilege then null;end;
 begin execute format('update public.%I set id=id',tab0);get diagnostics n0=row_count;assert n0=0,'Direct update';exception when insufficient_privilege then null;end;
 begin execute format('delete from public.%I',tab0);get diagnostics n0=row_count;assert n0=0,'Direct delete';exception when insufficient_privilege then null;end;
 end loop;
 assert not exists(select 1 from public.development_object_relationships r join public.development_objects o on o.id=r.source_object_id where o.project_id=(select (payload->>'id')::uuid from public.m919_fixture where label='Project')),'SOLVES traversal';
 select (payload->>'id')::uuid into entry0 from public.m919_fixture where label='Entry1';
 select (payload->>'id')::uuid into obj0 from public.m919_fixture where label='Problem1';
 select (payload#>>'{activity,id}')::uuid into act0 from public.m919_fixture where label='SolutionActivity';
 begin perform public.create_brainstorm_entry(act0,'Unauthorized parent','private',entry0);raise exception 'Parent attack';exception when insufficient_privilege then assert sqlerrm='Resource unavailable';end;
 begin perform public.promote_brainstorm_entry_to_idea(entry0);raise exception 'IDEA attack';exception when insufficient_privilege then null;end;
 begin perform public.promote_brainstorm_entry_to_solution(entry0,obj0);raise exception 'SOLUTION attack';exception when insufficient_privilege then null;end;
 begin perform public.add_activity_input(act0,obj0,true);raise exception 'Object input attack';exception when insufficient_privilege then null;end;
 for b in select * from public.m919_fixture where label in('ProblemBank','SolutionBank') loop
 assert not exists(select 1 from public.artifacts where id=(b.payload#>>'{artifact,id}')::uuid),'Artifact exact ID';
 assert not exists(select 1 from public.artifact_versions where id=(b.payload#>>'{version,id}')::uuid),'Version exact ID';
 assert not exists(select 1 from public.artifact_object_links where artifact_version_id=(b.payload#>>'{version,id}')::uuid),'Bank links';
 begin perform public.add_activity_artifact_input(act0,(b.payload#>>'{artifact,id}')::uuid,(b.payload#>>'{version,id}')::uuid,true);raise exception 'Bank input attack';exception when insufficient_privilege then null;end;
 end loop;
 -- Missing/known denied source predicates disclose no private row.
 assert public.can_read_brainstorm_entry(entry0)=false;
 assert public.can_read_brainstorm_entry('ffffffff-ffff-4fff-8fff-ffffffffffff')=false;
 begin insert into public.brainstorm_entries(activity_instance_id,project_id,workspace_id,created_by,content) select act0,(payload->>'id')::uuid,(payload->>'primary_workspace_id')::uuid,auth.uid(),'Forged' from public.m919_fixture where label='Project';raise exception 'Direct INSERT';exception when insufficient_privilege then null;end;
 end loop;
end $$;
reset role;
do $$begin assert pg_temp.m920_state()=(select payload from m920_before),'Unauthorized calls left partial state or rewrote history';end $$;
rollback;
\echo M9.20 cross-Team/removed/role-only enumeration/mutation/parent/promotion/input/no-partial-write PASS
