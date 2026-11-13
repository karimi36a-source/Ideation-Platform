import {spawn} from "node:child_process";
import {affinityItemFixture} from "./affinity-item-fixture.mjs";

/** Exercises accepted composition/output/dependency RPCs against committed PostgreSQL state. */
export async function testSession6Outputs({run,args,binary,childEnv,root}) {
 const name="fici_session6_outputs";
 run("psql",[...args,"-c",`create database ${name} template postgres`]);
 const db=args.map((v,i)=>args[i-1]==="-d"?name:v);
 const a1="00000000-0000-4000-8000-000000006004",a2="00000000-0000-4000-8000-000000006005",master="00000000-0000-4000-8000-000000006002",b="00000000-0000-4000-8000-000000006007";
 const call=(actor,expression,before="")=>new Promise((resolve,reject)=>{
  const child=spawn(binary("psql"),[...db,"--set=VERBOSITY=verbose","-t","-A","-f","-"],{cwd:root,env:childEnv,windowsHide:true});let out="",err="";
  const timer=setTimeout(()=>{child.kill();reject(Error("Session 6 output fixture timeout"));},60000);
  child.stdout.on("data",x=>out+=x);child.stderr.on("data",x=>err+=x);child.on("error",e=>{clearTimeout(timer);reject(e);});
  child.on("close",code=>{clearTimeout(timer);if(code!==0){const state=err.match(/ERROR:\s+([0-9A-Z]{5}):/);return state?resolve({code:state[1]}):reject(Error("Unclassified Session 6 SQL failure: "+err));}const line=out.split(/\r?\n/).find(x=>x.startsWith("RESULT="));if(!line)return reject(Error("Missing Session 6 result"));resolve({code:"00000",data:JSON.parse(line.slice(7))});});
  child.stdin.end(`begin;set local statement_timeout='50s';set local role authenticated;select set_config('request.jwt.claim.sub','${actor}',true);${before}select 'RESULT='||coalesce((${expression})::text,'null');commit;`);
 });
 const ok=x=>{if(x.code!=="00000")throw Error("Unexpected SQLSTATE "+x.code);return x.data;};
 const deny=(x,code="42501")=>{if(x.code!==code||x.data!==undefined)throw Error("Expected "+code+" got "+x.code);};
 const unavailable=x=>{if(x.code!=="00000"||x.data!==null)throw Error("Inaccessible resume exposed state");};
 const sql=x=>JSON.parse(run("psql",[...db,"-t","-A","-c",`select (${x})::text;`]).trim());
 const write=x=>run("psql",[...db,"-c",x]);
 const rpc=(actor,operation,input)=>call(actor,`public.${operation}('${JSON.stringify(input)}'::jsonb)`);
 const defs=Array.from({length:3},(_,i)=>`00000000-0000-4000-8000-${String(1117701+i).padStart(12,'0')}`);
 try {
  const definitions=`
   update public.session_definitions set session_number=6,sequence=6,title='Isolated Session 6' where id='00000000-0000-4000-8000-000000950702';
   insert into public.session_definitions(id,curriculum_version_id,session_number,title,description,learning_goal,sequence) values('00000000-0000-4000-8000-000001117700','00000000-0000-4000-8000-000000950602',7,'Isolated Session 7','Isolated handoff fixture','Identity continuity only',7);
   update public.activity_definitions set configuration='{"outputs":{"artifact_types":["INVENTION_STRUCTURE","GAP_LIST"]}}',requires_review=(id='00000000-0000-4000-8000-000001112801'),requires_approval=(id='00000000-0000-4000-8000-000001112801') where id in('00000000-0000-4000-8000-000001112801','00000000-0000-4000-8000-000001113803');
   insert into public.activity_definitions(id,session_definition_id,name,method_type,workspace_mode,sequence) values
   ${defs.map((id,i)=>`('${id}','00000000-0000-4000-8000-000001117700','Isolated Session 7 handoff ${i}','mind_map','Team Workspace',400+${i})`).join(',')};
   insert into public.activity_dependencies(activity_definition_id,required_activity_definition_id,dependency_type,required_artifact_type,is_mandatory)
   select id,case when id='${defs[1]}' then '00000000-0000-4000-8000-000001113803'::uuid else '00000000-0000-4000-8000-000001112801'::uuid end,(case when id='${defs[1]}' then 'artifact_available' else 'approved_output' end)::public.activity_dependency_type,kind,true
   from public.activity_definitions cross join unnest(array['INVENTION_STRUCTURE','GAP_LIST']) kind where id in(${defs.map(id=>`'${id}'`).join(',')});`;
  const fixture=affinityItemFixture(root).replace("update public.curriculum_versions set status='approved'",definitions+"update public.curriculum_versions set status='approved'");
  const setup=run("psql",[...db,"-t","-A","-f","-"],fixture+`
   set local role authenticated;select set_config('request.jwt.claim.sub','${a1}',true);
   insert into ai_sources select kind,(public.create_development_object((payload->>'id')::uuid,(payload->>'primary_workspace_id')::uuid,kind::public.development_object_type,'Earlier '||kind,'Preserve original content','USER')->>'id')::uuid from logged_projects cross join unnest(array['FUNCTION','COMPONENT']) kind where label='Team';
   select public.add_affinity_item(jsonb_build_object('affinityGroupId',(select payload->>'id' from ai_groups where label='Team'),'developmentObjectId',id)) from ai_sources where label in('PROBLEM','SOLUTION','FUNCTION','COMPONENT');
   reset role;
   update public.development_objects set product_classification='SUPPORTING' where id=(select id from ai_sources where label='COMPONENT');
   select 'TARGET='||jsonb_build_object('activity',(select id from af_activities where label='Team'),'other',(select id from ai_sources where label='Other Activity'),'group',(select payload->>'id' from ai_groups where label='Team'),'otherGroup',(select payload->>'id' from ai_groups where label='Other'),'personal',(select id from af_activities where label='Personal'),'personalGroup',(select payload->>'id' from ai_groups where label='Personal'),'project',(select payload->>'id' from logged_projects where label='Team'),'workspace',(select payload->>'primary_workspace_id' from logged_projects where label='Team'),'team',(select payload->>'teamId' from acceptance_teams where label='A'),'p',(select id from ai_sources where label='PROBLEM'),'s',(select id from ai_sources where label='SOLUTION'),'f',(select id from ai_sources where label='FUNCTION'),'c',(select id from ai_sources where label='COMPONENT'))::text;commit;`);
  const t=JSON.parse(setup.split(/\r?\n/).find(x=>x.startsWith('TARGET=')).slice(7));
  const unconfigured=ok(await rpc(a1,'confirm_affinity_structure',{activityInstanceId:t.personal,affinityGroupId:t.personalGroup,mode:'CREATE_NEW',newObject:{objectType:'SYSTEM',title:'Unconfigured private fixture'},idempotencyKey:'unconfigured'}));
  if(unconfigured.activityOutputId!==null)throw Error('Unconfigured Activity auto-registered output');
  deny(await call(a1,`public.add_activity_artifact_output('${t.personal}','${unconfigured.artifact.id}')`));
  const sources=()=>sql(`(select jsonb_agg(to_jsonb(x) order by id) from public.development_objects x where id in('${t.p}','${t.s}','${t.f}','${t.c}'))`);
  const original=JSON.stringify(sources());
  const guards=()=>sql(`jsonb_build_object('baseline',(select jsonb_agg(to_jsonb(x) order by id) from public.project_baseline_items x),'maps',(select jsonb_agg(to_jsonb(x) order by id) from public.mind_maps x),'nodes',(select jsonb_agg(to_jsonb(x) order by id) from public.mind_map_nodes x),'edges',(select jsonb_agg(to_jsonb(x) order by id) from public.mind_map_edges x),'activity',(select to_jsonb(x) from public.activity_instances x where id='${t.activity}'))`);
  const guardBefore=JSON.stringify(guards());
  const input={activityInstanceId:t.activity,affinityGroupId:t.group,mode:'LINK_EXISTING',targetObjectId:t.c,idempotencyKey:'session6-structure',relationships:[{sourceObjectId:t.s,targetObjectId:t.p,relationshipType:'SOLVES'},{sourceObjectId:t.c,targetObjectId:t.f,relationshipType:'IDENTIFIED_IN'}]};
  const relationshipCount=sql(`(select count(*) from public.development_object_relationships)`);
  const objectCount=sql(`(select count(*) from public.development_objects)`);
  const structure=ok(await rpc(a1,'confirm_affinity_structure',input));
  const gapInput={activityInstanceId:t.activity,mode:'CREATE_NEW',newGap:{title:'Human identified G1'},idempotencyKey:'session6-gap'};
  const gap1=ok(await rpc(a1,'capture_gap',gapInput));
  const gap2=ok(await rpc(a1,'capture_gap',{...gapInput,newGap:{title:'Human identified G2'},idempotencyKey:'session6-gap2'}));
  if(gap1.artifact.id!==gap2.artifact.id||gap1.version.id===gap2.version.id||gap2.version.previous_version_id!==gap1.version.id)throw Error('Gap List identity/lineage lost');
  if(sql(`(select count(*) from public.development_objects)`)!==objectCount+2||sql(`(select count(*) from public.development_object_relationships)`)!==relationshipCount+2)throw Error('Unexpected Object clones or inferred relationships');
  const outputs=[structure,gap2];
  for(const [i,x] of outputs.entries())if(x.artifact.artifact_type!==['INVENTION_STRUCTURE','GAP_LIST'][i]||!x.activityOutputId||!x.artifact.review_required||!x.artifact.approval_required||x.version.status!=='DRAFT'||x.artifact.current_version_id!==null)throw Error('Configured output/flags/Draft separation failed');
  if(original!==JSON.stringify(sources())||guardBefore!==JSON.stringify(guards()))throw Error('Source Objects/classification/Activity/baseline/map changed');
  const links=id=>sql(`(select jsonb_agg(development_object_id order by sequence) from public.artifact_object_links where artifact_version_id='${id}')`);
  if(![t.p,t.s,t.f,t.c].every(id=>links(structure.version.id).includes(id))||JSON.stringify(links(gap1.version.id))!==JSON.stringify([gap1.gap.id])||JSON.stringify(links(gap2.version.id))!==JSON.stringify([gap1.gap.id,gap2.gap.id]))throw Error('Stable Object links/cumulative Gap snapshot lost');
  const history=()=>sql(`jsonb_build_object('versions',(select jsonb_agg(to_jsonb(x) order by id) from public.artifact_versions x where artifact_id in('${structure.artifact.id}','${gap2.artifact.id}')),'links',(select jsonb_agg(to_jsonb(x) order by id) from public.artifact_object_links x),'relationships',(select jsonb_agg(to_jsonb(x) order by id) from public.development_object_relationships x),'objects',(select jsonb_agg(to_jsonb(x) order by id) from public.development_objects x),'outputs',(select jsonb_agg(to_jsonb(x) order by id) from public.activity_outputs x where activity_instance_id='${t.activity}'))`);
  const beforeRetry=JSON.stringify(history());
  const retries=await Promise.all([rpc(a1,'confirm_affinity_structure',input),rpc(a1,'confirm_affinity_structure',input),rpc(a1,'capture_gap',gapInput)]);
  for(const r of retries)if(!ok(r).replayed)throw Error('Retry not replayed');
  for(const x of outputs){const r=ok(await call(a2,`public.add_activity_artifact_output('${t.activity}','${x.artifact.id}')`));if(r.id!==x.activityOutputId||r.output_type!=='artifact'||r.artifact_id!==x.artifact.id)throw Error('Output registration duplicate/mapping');}
  if(beforeRetry!==JSON.stringify(history()))throw Error('Retry changed history');
  if(sql(`(select count(*) from public.activity_outputs where activity_instance_id='${t.activity}')`)!==2)throw Error('Expected exactly two configured outputs');
  const start=i=>call(a2,`public.start_activity('${defs[i]}','${t.project}','${t.workspace}','${t.team}')`);
  const blocked=x=>{const v=ok(x);if(v.started||v.reasonCode!=='DEPENDENCY_NOT_MET')throw Error('Unsatisfied dependency started');};
  blocked(await start(0));
  // Output insertion is part of the composition transaction, not a later best-effort write.
  const counts=()=>sql(`jsonb_build_array(${['artifacts','artifact_versions','artifact_object_links','development_objects','development_object_relationships','activity_outputs','change_log'].map(table=>`(select count(*) from public.${table})`).join(',')})`);
  const priorCounts=JSON.stringify(counts());
  write(`create function private.s6_fault() returns trigger language plpgsql as $$begin raise exception 'fixture output failure' using errcode='ZX117';end$$;create trigger s6_fault after insert on public.activity_outputs for each row execute function private.s6_fault();`);
  const otherInput={...input,activityInstanceId:t.other,affinityGroupId:t.otherGroup,idempotencyKey:'no-review',relationships:[]};
  deny(await rpc(a1,'confirm_affinity_structure',otherInput),'ZX117');
  deny(await rpc(a1,'capture_gap',{...gapInput,activityInstanceId:t.other,idempotencyKey:'fault-gap'}),'ZX117');
  write('drop trigger s6_fault on public.activity_outputs;drop function private.s6_fault();');
  if(priorCounts!==JSON.stringify(counts()))throw Error('Partial composition after output failure');
  const noReviewStructure=ok(await rpc(a1,'confirm_affinity_structure',otherInput));
  const noReviewGap=ok(await rpc(a1,'capture_gap',{activityInstanceId:t.other,mode:'ADD_EXISTING',gapObjectId:gap1.gap.id,idempotencyKey:'existing-gap'}));
  for(const x of [noReviewStructure,noReviewGap])if(x.artifact.review_required||x.artifact.approval_required||x.version.status!=='DRAFT'||x.artifact.current_version_id!==null||!x.activityOutputId)throw Error('No-review availability invented approval');
  const available=ok(await start(1));if(!available.started)throw Error('Configured no-review artifacts unavailable');
  for(const x of [noReviewStructure,noReviewGap])ok(await call(a2,`public.add_activity_artifact_input('${available.activity.id}','${x.artifact.id}',null,true)`));
  for(const [i,x] of outputs.entries()){
   const sub=ok(await call(a2,`public.submit_artifact('${x.artifact.id}','${x.version.id}','${t.activity}')`));
   ok(await call(master,`public.start_review('${sub.id}')`));ok(await call(master,`public.approve_artifact('${sub.id}','Session 6 output reviewed')`));
   if(i===0)blocked(await start(0));
  }
  const approved=ok(await start(0));if(!approved.started)throw Error('Approved outputs did not unblock Session 7');
  for(const x of outputs)ok(await call(a2,`public.add_activity_artifact_input('${approved.activity.id}','${x.artifact.id}','${x.version.id}',true)`));
  // Every call creates a fresh connection/transaction: reset anonymous context then
  // re-authenticate to prove durable reload, not an in-memory session cache.
  const resumed=ok(await call(a1,`public.resume_activity('${t.activity}')`));
  unavailable(await call('',`public.resume_activity('${t.activity}')`));
  const reloaded=ok(await call(a1,`public.resume_activity('${t.activity}')`));
  if(JSON.stringify(resumed)!==JSON.stringify(reloaded)||resumed.outputs.length!==2)throw Error('Logout/re-authenticated reload lost identity');
  const downstream=ok(await call(a2,`public.resume_activity('${approved.activity.id}')`));
  if(downstream.inputs.length!==2||!outputs.every(x=>downstream.inputs.some(v=>v.artifact_id===x.artifact.id&&v.artifact_version_id===x.version.id)))throw Error('Exact approved input identity lost');
  const preserved=JSON.stringify(history());
  for(const actor of [b,master]){
   unavailable(await call(actor,`public.resume_activity('${t.activity}')`));
   deny(await call(actor,`public.add_activity_artifact_output('${t.activity}','${structure.artifact.id}')`));
   deny(await rpc(actor,'confirm_affinity_structure',input));deny(await rpc(actor,'capture_gap',gapInput));
  }
  const hidden=actor=>call(actor,`jsonb_build_array((select count(*) from public.activity_outputs where activity_instance_id='${t.activity}'),(select count(*) from public.artifacts a join public.artifact_versions v on v.artifact_id=a.id join public.artifact_object_links l on l.artifact_version_id=v.id where a.id in('${structure.artifact.id}','${gap2.artifact.id}')),(select count(*) from public.development_objects where id in('${t.p}','${gap1.gap.id}')))`);
  if(JSON.stringify(ok(await hidden(b)))!=='[0,0,0]')throw Error('Team B exact-ID/join leak');
  ok(await call(master,`public.remove_team_member('${t.team}','${a1}',null)`));
  unavailable(await call(a1,`public.resume_activity('${t.activity}')`));deny(await rpc(a1,'capture_gap',gapInput));deny(await rpc(a1,'confirm_affinity_structure',input));
  deny(await call(a1,`public.add_activity_artifact_output('${t.activity}','${structure.artifact.id}')`));
  if(JSON.stringify(ok(await hidden(a1)))!=='[0,0,0]')throw Error('Removed-member exact-ID/join leak');
  if(preserved!==JSON.stringify(history())||original!==JSON.stringify(sources()))throw Error('Revocation/reload rewrote history');
  ok(await call(a2,`public.resume_activity('${t.activity}')`));
  ok(await call(a2,`public.archive_artifact('${gap2.artifact.id}')`));blocked(await start(2));
  if(sql(`(select count(*) from public.activity_outputs where activity_instance_id='${t.activity}')`)!==2)throw Error('Unavailable output erased history');
  console.log('M11.17 Session6 stable-artifacts/canonical-objects/cumulative-links/explicit-relations/configured-outputs/retry/atomic-rollback/review/Session7-approved-and-available/re-authenticated-reload/TeamB/removal/exact-ID/history PASS');
 } finally {run("psql",[...args,"-c",`drop database ${name} with(force)`]);}
}
