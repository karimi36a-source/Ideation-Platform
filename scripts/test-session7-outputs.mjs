import {spawn,spawnSync} from "node:child_process";

export async function testSession7Outputs({run,args,binary,childEnv,root}) {
 const name="fici_session7_outputs";run("psql",[...args,"-c",`create database ${name} template postgres`]);
 const db=args.map((v,i)=>args[i-1]==="-d"?name:v);
 const a1="00000000-0000-4000-8000-000000006004",a2="00000000-0000-4000-8000-000000006005",master="00000000-0000-4000-8000-000000006002",b="00000000-0000-4000-8000-000000006007";
 const call=(actor,expression,before="")=>new Promise((resolve,reject)=>{
  const child=spawn(binary("psql"),[...db,"--set=VERBOSITY=verbose","-t","-A","-f","-"],{cwd:root,env:childEnv,windowsHide:true});let out="",err="";
  const timer=setTimeout(()=>{child.kill();reject(Error("Session 7 fixture timeout"));},60000);
  child.stdout.on("data",x=>out+=x);child.stderr.on("data",x=>err+=x);child.on("error",e=>{clearTimeout(timer);reject(e);});
  child.on("close",code=>{clearTimeout(timer);if(code!==0){const state=err.match(/ERROR:\s+([0-9A-Z]{5}):/);return state?resolve({code:state[1]}):reject(Error("Unclassified Session 7 SQL failure: "+err));}const line=out.split(/\r?\n/).find(x=>x.startsWith("RESULT="));if(!line)return reject(Error("Missing Session 7 result"));resolve({code:"00000",data:JSON.parse(line.slice(7))});});
  child.stdin.end(`begin;set local statement_timeout='50s';set local role authenticated;select set_config('request.jwt.claim.sub','${actor}',true);${before}select 'RESULT='||coalesce((${expression})::text,'null');commit;`);
 });
 const ok=x=>{if(x.code!=="00000")throw Error("Unexpected SQLSTATE "+x.code);return x.data;};
 const deny=(x,code="42501")=>{if(x.code!==code||x.data!==undefined)throw Error("Expected "+code+" got "+x.code);};
 const sql=x=>JSON.parse(run("psql",[...db,"-t","-A","-c",`select (${x})::text;`]).trim());
 const write=x=>run("psql",[...db,"-c",x]);
 const rpc=(actor,fn,input)=>call(actor,`public.${fn}('${JSON.stringify(input).replaceAll("'","''")}'::jsonb)`);
 const defs=Array.from({length:5},(_,i)=>`00000000-0000-4000-8000-${String(1118801+i).padStart(12,'0')}`);
 try {
  const generated=spawnSync(process.execPath,['scripts/mind-map-browser-fixture.mjs'],{cwd:root,encoding:'utf8',windowsHide:true});
  if(generated.status!==0)throw Error('Saved map fixture unavailable');
  const definitions=`
   update public.activity_definitions set configuration='{"outputs":{"artifact_types":["INVENTION_STRUCTURE","GAP_LIST"]}}' where id='00000000-0000-4000-8000-000001112801';
   update public.activity_definitions set configuration='{"outputs":{"artifact_types":["MIND_MAP","MINIMUM_ESSENTIAL_STRUCTURE","INVENTION_CONCEPT"]}}',requires_review=(id='00000000-0000-4000-8000-000001119001'),requires_approval=(id='00000000-0000-4000-8000-000001119001') where id in('00000000-0000-4000-8000-000001119001','00000000-0000-4000-8000-000001119002');
   insert into public.activity_definitions(id,session_definition_id,name,method_type,workspace_mode,sequence) values
   ${defs.slice(0,3).map((id,i)=>`('${id}','00000000-0000-4000-8000-000000950702','Isolated Session 8 dependency ${i}','teaching','Team Workspace',500+${i})`).join(',')};
   insert into public.activity_dependencies(activity_definition_id,required_activity_definition_id,dependency_type,required_artifact_type,is_mandatory)
   select id,case when id='${defs[1]}' then '00000000-0000-4000-8000-000001119002'::uuid else '00000000-0000-4000-8000-000001119001'::uuid end,
   (case when id='${defs[1]}' then 'artifact_available' else 'approved_output' end)::public.activity_dependency_type,kind,true
   from public.activity_definitions cross join unnest(array['MIND_MAP','MINIMUM_ESSENTIAL_STRUCTURE','INVENTION_CONCEPT']) kind where id in(${defs.slice(0,3).map(x=>`'${x}'`).join(',')});
   insert into public.activity_dependencies(activity_definition_id,required_activity_definition_id,dependency_type,required_artifact_type,is_mandatory)
   select '00000000-0000-4000-8000-000001119001','00000000-0000-4000-8000-000001112801','artifact_available',kind,true from unnest(array['INVENTION_STRUCTURE','GAP_LIST']) kind;
   insert into public.activity_definitions(id,session_definition_id,name,method_type,workspace_mode,sequence) values('${defs[3]}','00000000-0000-4000-8000-000000950702','Unconfigured map','mind_map','Team Workspace',504);
   insert into public.activity_definitions(id,session_definition_id,name,method_type,workspace_mode,sequence,configuration) values('${defs[4]}','00000000-0000-4000-8000-000000950702','Generic Version race control','mind_map','Team Workspace',505,'{"outputs":{"artifact_types":["MIND_MAP","MINIMUM_ESSENTIAL_STRUCTURE","INVENTION_CONCEPT"]}}');
  `;
  let setup=generated.stdout.split('update auth.users set')[0].replace(/update public\.artifact_versions set status='SUBMITTED'[\s\S]*?;/,'');
  setup=setup.replace("update public.curriculum_versions set status='approved'",definitions+"update public.curriculum_versions set status='approved'");
  const sources=`
   insert into public.mind_map_browser_fixture select 'session6Structure',public.confirm_affinity_structure(jsonb_build_object('activityInstanceId',(select id from af_activities where label='Team'),'affinityGroupId',public.create_affinity_group(jsonb_build_object('activityInstanceId',(select id from af_activities where label='Team'),'name','Human Session 6 structure'))->>'id','mode','CREATE_NEW','newObject',jsonb_build_object('objectType','SYSTEM','title','Team-authored System S1'),'idempotencyKey','session6-system'));
   insert into public.mind_map_browser_fixture select 'session6Gap',public.capture_gap(jsonb_build_object('activityInstanceId',(select id from af_activities where label='Team'),'mode','CREATE_NEW','newGap',jsonb_build_object('title','Team-authored unresolved G1'),'idempotencyKey','session6-gap'));
  `;
  setup=setup.replace("insert into public.mind_map_browser_fixture\nselect 'activity',",sources+"insert into public.mind_map_browser_fixture\nselect 'activity',");
  setup=setup.replace("select 'object_'||lower(kind),public.create_development_object(","select 'object_'||lower(kind),case when kind='SYSTEM' then (select to_jsonb(o) from public.development_objects o where id=(select (value->>'resolvedDevelopmentObjectId')::uuid from public.mind_map_browser_fixture where key='session6Structure')) when kind='GAP' then (select value->'gap' from public.mind_map_browser_fixture where key='session6Gap') else public.create_development_object(");
  setup=setup.replace("'manual','{}')\nfrom unnest", "'manual','{}') end\nfrom unnest");
  setup=setup.replace("case when kind='GAP' then null else (select value->>'id' from public.mind_map_browser_fixture where key='object_'||lower(kind)) end", "(select value->>'id' from public.mind_map_browser_fixture where key='object_'||lower(kind))");
  run('psql',[...db,'-f','-'],setup+'commit;');
  const fixture=sql(`(select jsonb_object_agg(key,value) from public.mind_map_browser_fixture)`);
  const m=fixture.map.mindMap,scope=fixture.scope,activity=fixture.activity.activity.id;
  const start=(actor,i)=>call(actor,`public.start_activity('${defs[i]}','${scope.projectId}','${scope.workspaceId}','${scope.teamId}')`);
  const blocked=x=>{const r=ok(x);if(r.started||r.reasonCode!=='DEPENDENCY_NOT_MET')throw Error('Draft/unavailable output bypassed dependency');};
  const compose=(actor,map,revision,key='compose',extra={})=>rpc(actor,'finalize_session7_outputs',{activityInstanceId:activity,mindMapId:map,expectedDraftRevision:revision,idempotencyKey:key,...extra});
  const sourceHistory=()=>sql(`(select jsonb_agg(to_jsonb(v) order by v.id) from public.artifact_versions v where artifact_id in('${fixture.session6Structure.artifact.id}','${fixture.session6Gap.artifact.id}'))`);
  const originalSources=JSON.stringify(sourceHistory());
  for(const s of [fixture.session6Structure,fixture.session6Gap])ok(await call(a1,`public.add_activity_artifact_input('${activity}','${s.artifact.id}',null,true)`));
  const view=async()=>ok(await call(a1,`public.get_mind_map_editor('${activity}')`));
  const object=id=>sql(`(select to_jsonb(o) from public.development_objects o where id='${id}')`);
  const version=id=>sql(`(select to_jsonb(v) from public.artifact_versions v where id='${id}')`);
  const classify=async(id,value)=>{const editor=await view(),node=editor.nodes.find(n=>n.development_object_id===id);return ok(await rpc(a1,'classify_mind_map_node',{nodeId:node.id,expectedRevision:node.edit_revision,expectedObjectRevision:object(id).classification_revision,classification:value}));};
  let editor=await view();const fn=editor.nodes.find(n=>n.node_type==='FUNCTION');
  ok(await rpc(a1,'update_mind_map_node',{nodeId:fn.id,expectedRevision:fn.edit_revision,developmentObjectId:fixture.object_function.id}));
  for(const kind of ['system','subsystem','component'])await classify(fixture['object_'+kind].id,'CORE');
  const contextObject=ok(await call(a1,`public.create_development_object('${scope.projectId}','${scope.workspaceId}','SYSTEM','Human-authored context','Context only',null)`));
  const contextNode=ok(await rpc(a1,'add_mind_map_node',{mindMapId:m.id,nodeType:'SYSTEM',label:'Necessary parent context',developmentObjectId:contextObject.id,parentNodeId:fixture.map.rootNode.id,positionData:{x:100,y:100}}));
  await classify(contextObject.id,'SUPPORTING');
  editor=await view();const originalSystem=editor.nodes.find(n=>n.development_object_id===fixture.object_system.id);
  ok(await rpc(a1,'update_mind_map_node',{nodeId:originalSystem.id,expectedRevision:originalSystem.edit_revision,parentNodeId:contextNode.id}));
  const more=[];
  for(const [title,classification] of [['C2','SUPPORTING'],['C3','OPTIONAL_FUTURE']]){
   const o=ok(await call(a1,`public.create_development_object('${scope.projectId}','${scope.workspaceId}','COMPONENT','${title}','Human work',null)`));
   ok(await rpc(a1,'add_mind_map_node',{mindMapId:m.id,nodeType:'COMPONENT',label:title,developmentObjectId:o.id,parentNodeId:fixture.node_subsystem.id,positionData:{x:400,y:700+more.length*100}}));
   await classify(o.id,classification);more.push(o);
  }
  for(const [source,target,type] of [[fixture.object_subsystem.id,fixture.object_system.id,'BELONGS_TO'],[fixture.object_component.id,fixture.object_subsystem.id,'BELONGS_TO'],[fixture.object_solution.id,fixture.object_problem.id,'SOLVES'],[fixture.object_function.id,fixture.object_component.id,'IDENTIFIED_IN']])ok(await call(a1,`public.relate_development_objects('${source}','${target}','${type}',null)`));
  const countObjects=sql(`(select count(*) from public.development_objects)`);
  const canonical=()=>sql(`jsonb_build_object('objects',(select jsonb_agg(to_jsonb(o) order by id) from public.development_objects o),'relationships',(select jsonb_agg(to_jsonb(r) order by id) from public.development_object_relationships r))`);
  const canonicalBefore=JSON.stringify(canonical());
  const baselines=()=>sql(`(select coalesce(jsonb_agg(to_jsonb(b) order by id),'[]'::jsonb) from public.project_baseline_items b)`);
  const baselineBefore=JSON.stringify(baselines());
  deny(await compose(a1,m.id,0,'unsaved'),'23505');
  ok(await rpc(a1,'save_mind_map_draft',{mindMapId:m.id,expectedDraftRevision:0}));
  const counts=()=>sql(`jsonb_build_array(${['artifacts','artifact_versions','artifact_object_links','mind_maps','mind_map_nodes','mind_map_edges','development_objects','development_object_relationships','activity_outputs','change_log'].map(t=>`(select count(*) from public.${t})`).concat(['session7_compositions','session7_composition_requests','session7_output_artifacts'].map(t=>`(select count(*) from private.${t})`)).join(',')})`);
  // Fail every durable boundary, including the Mind Map checkpoint and receipt.
  for(const [table,event] of [['public.artifacts','after insert'],['private.session7_output_artifacts','after insert'],['public.artifact_versions','after insert'],['public.artifact_object_links','after insert'],['public.activity_outputs','after insert'],['public.mind_maps','after insert'],['public.mind_map_nodes','after insert'],['private.session7_compositions','after insert'],['private.session7_composition_requests','after insert']]){
   const before=JSON.stringify(counts());
   write(`create function private.s7_fault() returns trigger language plpgsql as $$begin raise exception 'fixture rollback' using errcode='ZX718';end$$;create trigger s7_fault ${event} on ${table} for each row execute function private.s7_fault();`);
   deny(await compose(a1,m.id,1,'first'),'ZX718');
   write(`drop trigger s7_fault on ${table};drop function private.s7_fault();`);
   if(before!==JSON.stringify(counts()))throw Error('Partial Session 7 composition after '+table);
  }
  const transient={label:'Unsaved provider-only preview',classification:'OPTIONAL_FUTURE'};
  const pair=(await Promise.all([compose(a1,m.id,1,'first'),compose(a2,m.id,1,'peer')])).map(ok);
  const first=pair[0];
  if(pair.filter(x=>x.replayed).length!==1||first.essentialStructure.version.id!==pair[1].essentialStructure.version.id||first.inventionConcept.version.id!==pair[1].inventionConcept.version.id)throw Error('Concurrent compositions diverged');
  if(JSON.stringify(first).includes(transient.label))throw Error('Transient state entered composition');
  const core=[fixture.object_system.id,fixture.object_subsystem.id,fixture.object_component.id];
  if(JSON.stringify(first.essentialStructure.version.content_snapshot.objects.map(o=>o.id).sort())!==JSON.stringify(core.sort()))throw Error('Essential set inferred wrong membership');
  if(first.essentialStructure.version.content_snapshot.objects.some(o=>o.productClassification!=='CORE')||more.some(o=>first.essentialStructure.version.content_snapshot.objects.some(x=>x.id===o.id)))throw Error('Non-CORE promoted');
  if(!first.essentialStructure.version.content_snapshot.contextObjects.some(o=>o.id===contextObject.id&&o.productClassification==='SUPPORTING'&&o.essential===false))throw Error('Necessary non-essential ancestor context lost');
  const conceptIds=first.inventionConcept.version.content_snapshot.objects.map(o=>o.id);
  for(const kind of ['system','subsystem','component','function','problem','solution','gap'])if(!conceptIds.includes(fixture['object_'+kind].id))throw Error('Concept lost canonical '+kind);
  if(first.inventionConcept.version.content_snapshot.relationships.length!==4||first.essentialStructure.version.content_snapshot.relationships.length!==3)throw Error('Explicit relationships lost/invented');
  const sets=x=>[x.mindMap,x.essentialStructure,x.inventionConcept];
  for(const x of sets(first))if(x.version.status!=='DRAFT'||x.artifact.current_version_id!==null||!x.artifact.review_required||!x.artifact.approval_required||!x.activityOutputId)throw Error('Flags/approval/output incorrect');
  const links=id=>sql(`(select jsonb_agg(development_object_id order by development_object_id) from public.artifact_object_links where artifact_version_id='${id}')`);
  for(const id of core)if(!links(first.essentialStructure.version.id).includes(id))throw Error('Essential Object link lost');
  for(const id of conceptIds)if(!links(first.inventionConcept.version.id).includes(id)||!links(first.mindMap.version.id).includes(id))throw Error('Map/Concept Object link lost');
  console.log('SESSION7_COMPOSITION_RESULT='+JSON.stringify(first));
  const beforeRetry=counts();
  if(!ok(await compose(a1,m.id,1,'first')).replayed||!ok(await compose(a1,m.id,1,'different-key')).replayed)throw Error('Idempotency failed');
  const afterRetry=counts();
  if(afterRetry.some((n,i)=>i!==11&&n!==beforeRetry[i])||afterRetry[11]!==beforeRetry[11]+1)throw Error('Retry changed product/history rows');
  if(JSON.stringify(canonical())!==canonicalBefore)throw Error('Composition rewrote canonical product semantics');
  // Only a new receipt may be added for a distinct key; no product rows change.
  if(sql(`(select count(*) from public.activity_outputs where activity_instance_id='${activity}')`)!==3||sql(`(select count(*) from public.development_objects)`)!==countObjects)throw Error('Duplicate outputs/Objects');
  deny(await compose(a1,m.id,1,'first',{changeSummary:'changed intent'}),'23505');
  const v1=sets(first).map(o=>version(o.version.id));
  deny(await rpc(a1,'save_mind_map_draft',{mindMapId:m.id,expectedDraftRevision:1}),'55000');
  await classify(fixture.object_component.id,'SUPPORTING');
  deny(await compose(a1,first.successorMindMapId,0,'second-unsaved'),'23505');
  editor=await view();const systemNode=editor.nodes.find(n=>n.development_object_id===fixture.object_system.id);
  ok(await rpc(a1,'update_mind_map_node',{nodeId:systemNode.id,expectedRevision:systemNode.edit_revision,label:'Team-authored revised System label'}));
  ok(await rpc(a2,'save_mind_map_draft',{mindMapId:first.successorMindMapId,expectedDraftRevision:0}));
  const second=ok(await compose(a2,first.successorMindMapId,1,'second'));
  if(sets(second).some(o=>o.artifact.current_version_id!==null))throw Error('Composition moved current pointer to Draft');
  if(second.inventionConcept.artifact.id!==first.inventionConcept.artifact.id||second.essentialStructure.artifact.id!==first.essentialStructure.artifact.id||second.inventionConcept.version.previous_version_id!==first.inventionConcept.version.id)throw Error('Stable output lineage failed');
  if(second.inventionConcept.version.content_snapshot.objects.find(o=>o.id===fixture.object_component.id).productClassification!=='SUPPORTING'||second.essentialStructure.version.content_snapshot.objects.some(o=>o.id===fixture.object_component.id))throw Error('V2 classification/essential membership stale');
  if(JSON.stringify(sets(first).map(o=>version(o.version.id)))!==JSON.stringify(v1))throw Error('V1 history rewritten');
  ok(await rpc(a2,'create_mind_map_version',{mindMapId:second.successorMindMapId,expectedDraftRevision:0,changeSummary:'Explicit later map checkpoint'}));
  deny(await compose(a2,second.successorMindMapId,0,'stale-map'),'23505');
  deny(await call(a1,`public.update_artifact_draft('${first.inventionConcept.version.id}',0,'{}')`),'55000');
  blocked(await start(a2,0));
  for(const actor of [b,master])if(ok(await call(actor,`(select count(*) from public.artifact_versions where id in('${first.mindMap.version.id}','${first.essentialStructure.version.id}','${first.inventionConcept.version.id}'))`))!==0)throw Error('Role-only Version ID leak before explicit review');
  for(const x of sets(first)){const sub=ok(await call(a2,`public.submit_artifact('${x.artifact.id}','${x.version.id}','${activity}')`));ok(await call(master,`public.start_review('${sub.id}')`));ok(await call(master,`public.approve_artifact('${sub.id}','Human review')`));}
  const ready=ok(await start(a2,0));if(!ready.started)throw Error('Approved outputs did not unblock Session 8');
  for(const x of sets(first))ok(await call(a2,`public.add_activity_artifact_input('${ready.activity.id}','${x.artifact.id}','${x.version.id}',true)`));
  const resumed=ok(await call(a1,`public.resume_activity('${activity}')`));
  if(ok(await call('',`public.resume_activity('${activity}')`))!==null||JSON.stringify(ok(await call(a1,`public.resume_activity('${activity}')`)))!==JSON.stringify(resumed)||resumed.outputs.length!==3||resumed.activity.status!=='active')throw Error('Reload lost outputs or composition completed Activity');
  // No-review output availability remains a separate existing M8 dependency type.
  const noActivity=fixture.readonlyActivity.activity.id,noMap=fixture.readonlyMap.mindMap;
  const noNode=ok(await rpc(a1,'add_mind_map_node',{mindMapId:noMap.id,nodeType:'SYSTEM',label:'No-review saved System',developmentObjectId:fixture.object_system.id,positionData:{x:90,y:100}}));
  ok(await rpc(a1,'save_mind_map_draft',{mindMapId:noMap.id,expectedDraftRevision:0}));
  const noInput={activityInstanceId:noActivity,mindMapId:noMap.id,expectedDraftRevision:1,idempotencyKey:'no-review'};
  const editRace=await Promise.all([rpc(a1,'finalize_session7_outputs',noInput),rpc(a2,'update_mind_map_node',{nodeId:noNode.id,expectedRevision:noNode.edit_revision,label:'Explicit concurrent human edit'})]);
  let available;
  if(editRace[0].code==='00000'){deny(editRace[1],'55000');available=ok(editRace[0]);}
  else {deny(editRace[0],'23505');ok(editRace[1]);ok(await rpc(a1,'save_mind_map_draft',{mindMapId:noMap.id,expectedDraftRevision:1}));available=ok(await rpc(a1,'finalize_session7_outputs',{...noInput,expectedDraftRevision:2}));}
  for(const x of sets(available))if(x.artifact.review_required||x.artifact.approval_required||x.artifact.current_version_id!==null||x.version.status!=='DRAFT')throw Error('No-review inferred approval');
  if(!ok(await start(a2,1)).started)throw Error('No-review availability failed');
  const unc=ok(await call(a2,`public.start_activity('${defs[3]}','${scope.projectId}','${scope.workspaceId}','${scope.teamId}')`));
  if(!unc.started)throw Error('Unconfigured control Activity did not start: '+unc.reasonCode);
  const uncMap=ok(await rpc(a1,'create_mind_map',{activityInstanceId:unc.activity.id,idempotencyKey:'unconfigured'}));
  deny(await rpc(a1,'finalize_session7_outputs',{activityInstanceId:unc.activity.id,mindMapId:uncMap.mindMap.id,expectedDraftRevision:0,idempotencyKey:'unconfigured'}),'55000');
  deny(await call(a1,`public.add_activity_artifact_output('${unc.activity.id}','${uncMap.artifact.id}')`));
  // Generic M8 appends lock the Artifact before inserting. Force the overlap:
  // composition must not bind an older map while that newer Version commits.
  const genericActivity=ok(await start(a2,4));if(!genericActivity.started)throw Error('Generic race Activity unavailable');
  const genericMap=ok(await rpc(a2,'create_mind_map',{activityInstanceId:genericActivity.activity.id,idempotencyKey:'generic-race'}));
  ok(await rpc(a2,'save_mind_map_draft',{mindMapId:genericMap.mindMap.id,expectedDraftRevision:0}));
  write(`create function private.s7_append_barrier() returns trigger language plpgsql as $$begin perform pg_sleep(2);return new;end$$;create trigger s7_append_barrier before insert on public.artifact_versions for each row when(new.artifact_id='${genericMap.artifact.id}') execute function private.s7_append_barrier();`);
  const genericAppend=call(a2,`public.create_artifact_version('${genericMap.artifact.id}','{"generic":"isolated race control"}',null)`);
  let observed=false;
  for(let attempt=0;attempt<20;attempt++){if(sql(`exists(select 1 from pg_stat_activity where datname=current_database() and wait_event='PgSleep' and query like '%create_artifact_version%')`)){observed=true;break;}await new Promise(resolve=>setTimeout(resolve,20));}
  if(!observed)throw Error('Generic append overlap was not observed');
  const racedComposition=await rpc(a1,'finalize_session7_outputs',{activityInstanceId:genericActivity.activity.id,mindMapId:genericMap.mindMap.id,expectedDraftRevision:1,idempotencyKey:'generic-overlap'});
  ok(await genericAppend);deny(racedComposition,'23505');
  write('drop trigger s7_append_barrier on public.artifact_versions;drop function private.s7_append_barrier();');
  const hidden=actor=>call(actor,`jsonb_build_array((select count(*) from public.artifacts a join public.artifact_versions v on v.artifact_id=a.id join public.artifact_object_links l on l.artifact_version_id=v.id where a.id in('${first.essentialStructure.artifact.id}','${first.inventionConcept.artifact.id}')),(select count(*) from public.activity_outputs where activity_instance_id='${activity}'))`);
  for(const actor of [b,master,'00000000-0000-4000-8000-000000006001','00000000-0000-4000-8000-000000006003']){
   deny(await compose(actor,m.id,1,'first'));if(JSON.stringify(ok(await hidden(actor)))!=='[0,0]')throw Error('Role-only/exact-ID leakage');
   deny(await call(actor,`public.create_artifact_version('${first.inventionConcept.artifact.id}','{}',null)`));
   deny(await call(actor,`public.update_artifact_draft('${second.inventionConcept.version.id}',0,'{}')`));
   deny(await call(actor,`public.archive_artifact('${first.inventionConcept.artifact.id}')`));
  }
  deny(await compose(a1,uncMap.mindMap.id,0,'wrong-context'));
  for(const field of ['actor','projectId','workspaceId','classification','nodes','force'])deny(await compose(a2,second.successorMindMapId,0,'spoof',{[field]:scope.projectId}),'22023');
  for(const table of ['session7_output_artifacts','session7_compositions','session7_composition_requests'])deny(await call(a1,`'null'::jsonb`,`select * from private.${table};`));
  deny(await call(a1,`'null'::jsonb`,`insert into public.activity_outputs default values;`));
  if(sql(`has_function_privilege('anon','public.finalize_session7_outputs(jsonb)','execute')`)||sql(`has_function_privilege('service_role','public.finalize_session7_outputs(jsonb)','execute')`)||sql(`(select not prosecdef or not proconfig @> array['search_path=""'] from pg_proc where oid='public.finalize_session7_outputs(jsonb)'::regprocedure)`))throw Error('Unsafe grants/search_path');
  ok(await call(master,`public.remove_team_member('${scope.teamId}','${a1}',null)`));
  deny(await compose(a1,m.id,1,'first'));deny(await compose(a1,second.successorMindMapId,0,'removed-new'));
  if(JSON.stringify(ok(await hidden(a1)))!=='[0,0]')throw Error('Removed-member leakage');
  ok(await call(a2,`public.resume_activity('${activity}')`));
  if(originalSources!==JSON.stringify(sourceHistory())||sql(`(select count(*) from public.development_objects)`)!==countObjects)throw Error('Session 6 rewritten or Objects cloned');
  if(baselineBefore!==JSON.stringify(baselines()))throw Error('Composition changed Project baselines');
  for(const o of more)if(object(o.id).archived_at!==null||object(o.id).product_classification!==({C2:'SUPPORTING',C3:'OPTIONAL_FUTURE'}[o.title]))throw Error('Excluded Object altered');
  ok(await call(a2,`public.archive_artifact('${first.inventionConcept.artifact.id}')`));blocked(await start(a2,2));
  console.log('M11.18 stable-three-outputs/CORE-not-inferred/context/Objects/links/relations/saved-state/checkpoint/history/atomic-rollback/concurrency/retry/approval/Session8/availability/reload/TeamB/Master/removal/exact-ID/M11.17-preservation PASS');
 }finally{run("psql",[...args,"-c",`drop database ${name} with(force)`]);}
}
