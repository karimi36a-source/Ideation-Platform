reset role;
create temporary table da_results(label text primary key,payload jsonb);
create temporary table da_cases(n integer primary key,activity uuid,decision uuid);
grant select,insert on da_results to authenticated;
grant select,insert on da_cases to authenticated;
create function pg_temp.da_id(label text) returns uuid language sql as $$select (payload#>>'{decision,id}')::uuid from df_drafts where df_drafts.label=$1$$;
grant execute on function pg_temp.da_id(text) to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006009',true);
insert into da_cases select n,(public.start_activity(('00000000-0000-4000-8000-'||lpad((1013000+n)::text,12,'0'))::uuid,(p.payload->>'id')::uuid,(p.payload->>'primary_workspace_id')::uuid,(t.payload->>'teamId')::uuid)#>>'{activity,id}')::uuid,null
from generate_series(1,9) n cross join logged_projects p cross join acceptance_teams t where p.label='Team' and t.label='A';
reset role;
do $$declare c record;r jsonb;begin
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006009',true);
 for c in select * from da_cases order by n loop
  r:=public.create_decision(jsonb_build_object('projectId',(select payload->>'id' from logged_projects where label='Team'),'workspaceId',(select payload->>'primary_workspace_id' from logged_projects where label='Team'),'activityInstanceId',c.activity,'title','Configured fixture','question','Q','method','OTHER','options',case when c.n=7 then jsonb_build_array(jsonb_build_object('label','Feature','developmentObjectId',(select id from vc_objects where kind='FEATURE'))) else '[{"label":"Option"}]'::jsonb end));
  update da_cases set decision=(r#>>'{decision,id}')::uuid where n=c.n;
  perform public.finalize_decision(jsonb_build_object('decisionId',r#>>'{decision,id}','selectedOptionId',r#>>'{options,0,id}','outcome','Explicit outcome','reasoning','Explicit reason'));
 end loop;
end $$;
set local role authenticated;
select public.finalize_decision(jsonb_build_object('decisionId',payload#>>'{decision,id}','selectedOptionId',case when label='Master different' then payload#>>'{options,1,id}' else payload#>>'{options,0,id}' end,'outcome','Human outcome','reasoning','Human reasoning')) from df_drafts where label in ('Team','Same race','Participant failure','Link failure','Log failure','Master different');
select public.link_decision_entity(jsonb_build_object('decisionId',pg_temp.da_id('Team'),'linkedEntityType','VOTING_SESSION','linkedEntityId',payload#>>'{session,id}','relationshipType','INFORMED_BY')) from vc_results where jsonb_array_length(payload->'options')=3;
reset role;
