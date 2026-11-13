reset role;
-- Canonical current Team Lead also needs independent explicit Project access.
insert into public.project_memberships(project_id,user_id)
 select (payload->>'id')::uuid,'00000000-0000-4000-8000-000000006005' from logged_projects p where label='Team' and not exists(select 1 from public.project_memberships m where m.project_id=(p.payload->>'id')::uuid and m.user_id='00000000-0000-4000-8000-000000006005' and m.status='active');
create temporary table de_decisions(label text primary key,payload jsonb);
create temporary table de_evidence(label text primary key,id uuid);
grant select,insert on de_decisions,de_evidence to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
insert into de_decisions select f.label,public.create_decision(jsonb_build_object('projectId',p.payload->>'id','workspaceId',p.payload->>'primary_workspace_id','title','Evidence-backed human decision','question','Which approach should we investigate?','method','DISCUSSION','options','[{"label":"Human alternative"},{"label":"Other option"}]'::jsonb)) from logged_projects p cross join unnest(array['Main','One','Invalid','Foreign','Link failure','Log failure','Participant failure','Existing','New','Denied','Archive','Same race','Different race','Link race','Service']) f(label) where p.label='Team';
do $$declare v text;made uuid;begin
 foreach v in array array['UNVERIFIED','PARTIALLY_VERIFIED','VERIFIED','CONTRADICTED','NEEDS_REVIEW','Extra'] loop
  made:=(public.create_evidence((select (payload->>'id')::uuid from logged_projects where label='Team'),(select (payload->>'primary_workspace_id')::uuid from logged_projects where label='Team'),'MEASUREMENT','Source '||v,'Recorded human source facts','Offline lab notebook')->>'id')::uuid;
  insert into de_evidence values(v,made);
  if v not in ('UNVERIFIED','Extra') then perform public.verify_evidence(made,v::public.evidence_verification_status,'Explicit human review');end if;
 end loop;
end$$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into de_evidence values('Personal',(public.create_evidence((select (payload->>'id')::uuid from logged_projects where label='Individual'),(select (payload->>'primary_workspace_id')::uuid from logged_projects where label='Individual'),'MEASUREMENT','Private source','Private research facts','Personal lab notes')->>'id')::uuid);
insert into de_decisions select 'Personal',public.create_decision(jsonb_build_object('projectId',payload->>'id','workspaceId',payload->>'primary_workspace_id','title','Personal human decision','question','Personal question?','method','OTHER','options','[{"label":"Own choice"}]'::jsonb)) from logged_projects where label='Individual';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006001',true);
insert into logged_projects values('Evidence B',public.create_development_project('Decision Evidence B','team',(select (payload->>'workspaceId')::uuid from acceptance_teams where label='B'),null,null,(select (payload->>'teamId')::uuid from acceptance_teams where label='B')));
insert into logged_projects values('Other Project',public.create_development_project('Same Workspace other Project','team',(select (payload->>'workspaceId')::uuid from acceptance_teams where label='A'),null,null,(select (payload->>'teamId')::uuid from acceptance_teams where label='A')));
reset role;
insert into public.project_memberships(project_id,user_id) select (payload->>'id')::uuid,case when label='Evidence B' then '00000000-0000-4000-8000-000000006006'::uuid else '00000000-0000-4000-8000-000000006005'::uuid end from logged_projects where label in ('Evidence B','Other Project');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.assign_team_lead((select (payload->>'teamId')::uuid from acceptance_teams where label='B'),'00000000-0000-4000-8000-000000006006');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006006',true);
insert into de_evidence select 'Team B',(public.create_evidence((payload->>'id')::uuid,(payload->>'primary_workspace_id')::uuid,'MEASUREMENT','B private source','B facts','B lab')->>'id')::uuid from logged_projects where label='Evidence B';
insert into de_decisions select 'Team B',public.create_decision(jsonb_build_object('projectId',payload->>'id','workspaceId',payload->>'primary_workspace_id','title','B Decision','question','B private question','method','OTHER','options','[{"label":"B choice"}]'::jsonb)) from logged_projects where label='Evidence B';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
insert into de_evidence select 'Other Project',(public.create_evidence((payload->>'id')::uuid,(payload->>'primary_workspace_id')::uuid,'MEASUREMENT','Other source','Other facts','Other lab')->>'id')::uuid from logged_projects where label='Other Project';
reset role;
create function pg_temp.de_args(label0 text,ids uuid[]) returns jsonb language sql as $$select jsonb_build_object('decisionId',payload#>>'{decision,id}','selectedOptionId',payload#>>'{options,0,id}','outcome','Investigate human alternative','reasoning','Human assessment of source confidence and uncertainty','linkedEvidenceIds',to_jsonb(ids)) from de_decisions where label=$1$$;
create function pg_temp.de_id(label0 text) returns uuid language sql as $$select (payload#>>'{decision,id}')::uuid from de_decisions where label=$1$$;
create function pg_temp.de_source(label0 text) returns uuid language sql as $$select id from de_evidence where label=$1$$;
create function pg_temp.de_snapshot(did uuid) returns jsonb language sql as $$select jsonb_build_object('decision',to_jsonb(d),'options',(select jsonb_agg(to_jsonb(o) order by id) from public.decision_options o where decision_id=d.id),'participants',(select jsonb_agg(to_jsonb(p) order by id) from public.decision_participants p where decision_id=d.id),'links',(select jsonb_agg(to_jsonb(l) order by id) from public.evidence_links l where linked_entity_type='DECISION' and linked_entity_id=d.id),'log',(select jsonb_agg(to_jsonb(c) order by id) from public.change_log c where entity_id=d.id and change_type='DECISION_FINALIZED')) from public.decisions d where id=did$$;
create function pg_temp.de_bad(v jsonb,expected text default '42501') returns void language plpgsql as $$begin perform public.finalize_decision(v);raise exception 'Unauthorized finalization succeeded';exception when others then if sqlstate<>expected then raise;end if;end$$;
