import {spawn} from "node:child_process";
import {affinityOperationFixture} from "./affinity-operation-fixture.mjs";

export async function testMindMapCreation({run,args,binary,childEnv,root}){
 const name="fici_mind_map_creation";
 run("psql",[...args,"-c",`create database ${name} template postgres`]);
 const db=args.map((v,i)=>args[i-1]==="-d"?name:v);
 const a1="00000000-0000-4000-8000-000000006004",a2="00000000-0000-4000-8000-000000006005",master="00000000-0000-4000-8000-000000006002";
 const call=(actor,expression,before="")=>new Promise((resolve,reject)=>{
  const child=spawn(binary("psql"),[...db,"--set=VERBOSITY=verbose","-t","-A","-f","-"],{cwd:root,env:childEnv,windowsHide:true});let out="",err="";
  const timer=setTimeout(()=>{child.kill();reject(Error("Mind Map fixture timeout"));},60000);
  child.stdout.on("data",x=>out+=x);child.stderr.on("data",x=>err+=x);child.on("error",e=>{clearTimeout(timer);reject(e);});
  child.on("close",code=>{clearTimeout(timer);if(code!==0){const state=err.match(/ERROR:\s+([0-9A-Z]{5}):/);return state?resolve({code:state[1]}):reject(Error("Unclassified Mind Map SQL failure: "+err));}const line=out.split(/\r?\n/).find(x=>x.startsWith("RESULT="));if(!line)return reject(Error("Missing result"));resolve({code:"00000",data:JSON.parse(line.slice(7))});});
  child.stdin.end(`begin;set local statement_timeout='50s';set local role authenticated;select set_config('request.jwt.claim.sub','${actor}',true);${before}select 'RESULT='||(${expression})::text;select pg_sleep(0.1);commit;`);
 });
 const ok=x=>{if(x.code!=="00000")throw Error("Unexpected SQLSTATE "+x.code);return x.data;};
 const deny=(x,code="42501")=>{if(x.code!==code||x.data!==undefined)throw Error("Expected "+code+" got "+x.code);};
 const sql=x=>JSON.parse(run("psql",[...db,"-t","-A","-c",`select (${x})::text;`]).trim());
 const write=x=>run("psql",[...db,"-c",x]);
 const defs=Array.from({length:9},(_,i)=>`'00000000-0000-4000-8000-${String(1118801+i).padStart(12,'0')}'`);
 const create=(actor,id,key="initialize")=>call(actor,`public.create_mind_map('${JSON.stringify({activityInstanceId:id,idempotencyKey:key})}'::jsonb)`);
 try{
  const definitions=`
   update public.activity_definitions set requires_review=true,requires_approval=true where id='00000000-0000-4000-8000-000001112801';
   insert into public.activity_definitions(id,session_definition_id,name,method_type,workspace_mode,sequence,configuration,requires_review,requires_approval) values
   ${defs.map((id,i)=>`(${id},'00000000-0000-4000-8000-000000950702','Isolated Mind Map ${i}','mind_map','${i===3?'Personal':'Team'} Workspace',${200+i},'${JSON.stringify(i===1?{}:{outputs:{artifact_types:["MIND_MAP"]}})}',true,true)`).join(',')};
   insert into public.activity_dependencies(activity_definition_id,required_activity_definition_id,dependency_type,required_artifact_type,is_mandatory)
   select id,'00000000-0000-4000-8000-000001112801',(case when id=${defs[2]} then 'approved_output' else 'artifact_available' end)::public.activity_dependency_type,kind,true
   from public.activity_definitions cross join unnest(array['INVENTION_STRUCTURE','GAP_LIST']) kind where id in(${defs[0]},${defs[1]},${defs[2]},${defs[7]});
  `;
  const fixture=affinityOperationFixture(root).replace("update public.curriculum_versions set status='approved'",definitions+"update public.curriculum_versions set status='approved'");
  const setup=run("psql",[...db,"-t","-A","-f","-"],fixture+`
   set local role authenticated;select set_config('request.jwt.claim.sub','${a1}',true);
   select 'STRUCTURE='||public.confirm_affinity_structure(jsonb_build_object('activityInstanceId',(select id from af_activities where label='Team'),'affinityGroupId',public.create_affinity_group(jsonb_build_object('activityInstanceId',(select id from af_activities where label='Team'),'name','Source systems'))->>'id','mode','CREATE_NEW','newObject',jsonb_build_object('objectType','SYSTEM','title','Existing canonical system'),'idempotencyKey','source'))::text;
   select 'GAP='||public.capture_gap(jsonb_build_object('activityInstanceId',(select id from af_activities where label='Team'),'mode','CREATE_NEW','newGap',jsonb_build_object('title','Existing canonical gap'),'idempotencyKey','source'))::text;
   select 'TARGET='||jsonb_build_object('project',(select payload->>'id' from logged_projects where label='Team'),'workspace',(select payload->>'primary_workspace_id' from logged_projects where label='Team'),'team',(select payload->>'teamId' from acceptance_teams where label='A'),'personalProject',(select payload->>'id' from logged_projects where label='Individual'),'personalWorkspace',(select payload->>'primary_workspace_id' from logged_projects where label='Individual'),'sourceActivity',(select id from af_activities where label='Team'))::text;
   commit;`);
  const marker=x=>JSON.parse(setup.split(/\r?\n/).find(y=>y.startsWith(x+'=')).slice(x.length+1));
  const t=marker('TARGET'),structure=marker('STRUCTURE'),gap=marker('GAP');
  const start=async(i,personal=false)=>{const r=ok(await call(personal?a1:a2,`public.start_activity(${defs[i]},'${personal?t.personalProject:t.project}','${personal?t.personalWorkspace:t.workspace}',${personal?'null':`'${t.team}'`})`));if(!r.started||!r.activity?.id)throw Error('Mind Map Activity '+i+' did not start: '+r.reasonCode);return r.activity.id;};
  const active=await start(0),unconfigured=await start(1),personal=await start(3,true),race=await start(4),fault=await start(5),late=await start(6),blocked=await start(7),sameKeyRace=await start(8);
  for(const source of [structure,gap])ok(await call(a1,`public.add_activity_artifact_input('${active}','${source.artifact.id}',null,true)`));
  const preserve=()=>sql(`jsonb_build_object('objects',(select jsonb_agg(to_jsonb(x) order by id) from public.development_objects x),'relationships',(select jsonb_agg(to_jsonb(x) order by id) from public.development_object_relationships x),'sources',(select jsonb_agg(to_jsonb(x) order by id) from public.artifact_versions x where artifact_id in('${structure.artifact.id}','${gap.artifact.id}')),'activity',(select to_jsonb(x) from public.activity_instances x where id='${active}'),'baseline',(select jsonb_agg(to_jsonb(x)) from public.project_baseline_items x))`);
  const before=JSON.stringify(preserve());
  const first=ok(await create(a1,active));
  const assertInitial=(x,actor)=>{if(x.artifact.artifact_type!=='MIND_MAP'||x.version.status!=='DRAFT'||x.version.version_number!==1||x.version.draft_revision!==0||x.artifact.current_version_id!==null||x.mindMap.artifact_id!==x.artifact.id||x.mindMap.artifact_version_id!==x.version.id||x.mindMap.root_node_id!==x.rootNode.id||x.rootNode.mind_map_id!==x.mindMap.id||x.rootNode.node_type!=='CENTRAL_INVENTION'||x.rootNode.development_object_id!==null||x.rootNode.parent_node_id!==null||x.rootNode.created_by!==actor||x.rootNode.position_data.x!==0||x.rootNode.position_data.y!==0||x.rootNode.metadata.role!=='central_invention')throw Error('Invalid initial canonical result');};
  assertInitial(first,a1);
  if(first.rootNode.label!==sql(`(select to_jsonb(name) from public.development_projects where id='${t.project}')`)||!first.activityOutputId||!first.artifact.review_required||!first.artifact.approval_required)throw Error('Root label/output/flags incorrect');
  if(JSON.stringify(preserve())!==before)throw Error('Source/Activity/baseline mutated');
  if(first.version.content_snapshot.sources.length!==2||first.version.content_snapshot.sources.some(x=>x.artifactVersionId!==null)||![structure.artifact.id,gap.artifact.id].every(id=>first.version.content_snapshot.sources.some(x=>x.artifactId===id)))throw Error('Availability references lost or approval invented');
  console.log('MIND_MAP_CREATED_RESULT='+JSON.stringify(first));
  const ids=x=>[x.artifact.id,x.version.id,x.mindMap.id,x.rootNode.id,x.activityOutputId].join();
  for(const [actor,key] of [[a1,'initialize'],[a1,'new-key'],[a2,'peer-key']]){const retry=ok(await create(actor,active,key));if(!retry.replayed||ids(retry)!==ids(first)||retry.rootNode.created_by!==a1)throw Error('Singleton replay duplicated/rewrote creator');}
  // A trusted corruption fixture proves the receipt cannot authorize a changed
  // canonical context. Ordinary clients cannot modify either receipt table.
  write(`update private.mind_map_creation_requests set context=context||'{"projectId":"00000000-0000-4000-8000-000000999999"}' where actor_id='${a1}' and activity_instance_id='${active}' and idempotency_key='initialize';`);
  deny(await create(a1,active),'23505');
  write(`update private.mind_map_creation_requests r set context=i.context from private.mind_map_initializations i where r.activity_instance_id=i.activity_instance_id and r.activity_instance_id='${active}';`);
  write(`update public.development_projects set name='Renamed Project' where id='${t.project}';`);
  if(ok(await create(a2,active,'after-rename')).rootNode.label!==first.rootNode.label)throw Error('Retry resynchronized root');
  const noOutput=ok(await create(a1,unconfigured));if(noOutput.activityOutputId!==null)throw Error('Invented output');
  const own=ok(await create(a1,personal));assertInitial(own,a1);for(const actor of [a2,master])deny(await create(actor,personal));
  for(const actor of ['00000000-0000-4000-8000-000000006007',master,'00000000-0000-4000-8000-000000006001','00000000-0000-4000-8000-000000006003','00000000-0000-4000-8000-000000006008',''])deny(await create(actor,active),actor?'42501':'28000');
  for(const key of ['title','actor','userId','createdBy','projectId','workspaceId','teamId','artifactId','artifactVersionId','rootNodeId','rootType','rootLabel','developmentObjectId','reviewRequired','approvalRequired','status','baseline'])deny(await call(a1,`public.create_mind_map('${JSON.stringify({activityInstanceId:active,idempotencyKey:'spoof',[key]:t.project})}')`),'22023');
  deny(await call(a1,`public.create_mind_map('{"activityInstanceId":"${active}","idempotencyKey":" "}')`),'22023');
  deny(await create(a1,t.sourceActivity),'22023');
  const beforeApproval=ok(await call(a2,`public.start_activity(${defs[2]},'${t.project}','${t.workspace}','${t.team}')`));
  if(beforeApproval.started||beforeApproval.reasonCode!=='DEPENDENCY_NOT_MET')throw Error('Draft source treated as approved');
  const samePair=(await Promise.all([create(a1,sameKeyRace,'same'),create(a1,sameKeyRace,'same')])).map(ok);
  if(ids(samePair[0])!==ids(samePair[1])||samePair.filter(x=>x.replayed).length!==1)throw Error('Same-key concurrent retry duplicated');
  const pair=(await Promise.all([create(a1,race,'parallel-a'),create(a2,race,'parallel-b')])).map(ok);
  if(ids(pair[0])!==ids(pair[1])||pair.filter(x=>x.replayed).length!==1)throw Error('Concurrent initialization duplicated');
  const counts=id=>sql(`jsonb_build_array((select count(*) from public.artifacts where activity_instance_id='${id}' and artifact_type='MIND_MAP'),(select count(*) from public.artifact_versions where artifact_id in(select id from public.artifacts where activity_instance_id='${id}' and artifact_type='MIND_MAP')),(select count(*) from public.mind_maps where artifact_id in(select id from public.artifacts where activity_instance_id='${id}' and artifact_type='MIND_MAP')),(select count(*) from public.mind_map_nodes where mind_map_id in(select m.id from public.mind_maps m join public.artifacts b on b.id=m.artifact_id where b.activity_instance_id='${id}')),(select count(*) from public.activity_outputs where activity_instance_id='${id}' and artifact_id in(select id from public.artifacts where artifact_type='MIND_MAP')))`);
  if(JSON.stringify(counts(race))!=='[1,1,1,1,1]'||JSON.stringify(counts(active))!=='[1,1,1,1,1]')throw Error('Hidden duplicate initial rows');
  // Real approved_output path uses the established formal M8 transaction.
  for(const source of [structure,gap]){const s=ok(await call(a2,`public.submit_artifact('${source.artifact.id}','${source.version.id}','${t.sourceActivity}')`));ok(await call(master,`public.start_review('${s.id}')`));ok(await call(master,`public.approve_artifact('${s.id}','Source review')`));}
  const approved=await start(2);
  for(const source of [structure,gap])ok(await call(a1,`public.add_activity_artifact_input('${approved}','${source.artifact.id}','${source.version.id}',true)`));
  const approvedMap=ok(await create(a1,approved));
  if(![structure.version.id,gap.version.id].every(id=>approvedMap.version.content_snapshot.sources.some(x=>x.artifactVersionId===id)))throw Error('Approved Version references not fixed');
  // Foreign scope is rejected by the canonical M8 input operation; no
  // client-supplied source IDs enter createMindMap's two-field contract.
  deny(await call(a1,`public.add_activity_artifact_input('${personal}','${structure.artifact.id}',null,true)`));
  const sourceSnapshot=JSON.stringify(sql(`(select jsonb_agg(to_jsonb(x) order by id) from public.artifact_versions x where id in('${structure.version.id}','${gap.version.id}'))`));
  ok(await create(a2,approved,'peer-approved'));
  if(sourceSnapshot!==JSON.stringify(sql(`(select jsonb_agg(to_jsonb(x) order by id) from public.artifact_versions x where id in('${structure.version.id}','${gap.version.id}'))`)))throw Error('Approved source Version rewritten');
  // Every transactional boundary is exercised with a real PostgreSQL exception.
  const allCounts=()=>sql(`jsonb_build_array(${['artifacts','artifact_versions','mind_maps','mind_map_nodes','mind_map_edges','activity_outputs','development_objects','development_object_relationships','change_log','project_baseline_items'].map(t=>`(select count(*) from public.${t})`).concat(['mind_map_initializations','mind_map_creation_requests'].map(t=>`(select count(*) from private.${t})`)).join(',')})`);
  for(const [table,event] of [['public.artifacts','after insert'],['public.artifact_versions','after insert'],['public.mind_maps','after insert'],['public.mind_map_nodes','after insert'],['public.mind_maps','after update of root_node_id'],['public.artifact_versions','after update of content_snapshot'],['public.activity_outputs','after insert'],['private.mind_map_initializations','after insert'],['private.mind_map_creation_requests','after insert']]){
   const prior=JSON.stringify(allCounts());
   write(`create function private.mm_fault() returns trigger language plpgsql as $$begin raise exception 'fixture fault' using errcode='ZX118';end $$;create trigger mm_fault ${event} on ${table} for each row execute function private.mm_fault();`);
   deny(await create(a1,fault),'ZX118');
   write(`drop trigger mm_fault on ${table};drop function private.mm_fault();`);
   if(JSON.stringify(allCounts())!==prior)throw Error('Partial initialization after '+table+' '+event);
  }
  assertInitial(ok(await create(a1,fault)),a1);
  const actual=sql(`jsonb_build_object('map',(select to_jsonb(x) from public.mind_maps x where id='${first.mindMap.id}'),'node',(select to_jsonb(x) from public.mind_map_nodes x where id='${first.rootNode.id}'))`);
  if(actual.map.root_node_id!==first.rootNode.id||JSON.stringify(actual.node)!==JSON.stringify(first.rootNode))throw Error('Canonical reload lost root');
  for(const table of ['mind_maps','mind_map_nodes','mind_map_edges'])for(const stmt of [`insert into public.${table} default values`,`update public.${table} set id=id`,`delete from public.${table}`])deny(await call(a1,`'null'::jsonb`,stmt+';'));
  for(const table of ['mind_map_initializations','mind_map_creation_requests'])deny(await call(a1,`'null'::jsonb`,`delete from private.${table};`));
  deny(await call(a1,`private.require_mind_map_write('${active}')`));
  if(sql(`has_function_privilege('anon','public.create_mind_map(jsonb)','execute')`)||sql(`has_function_privilege('service_role','public.create_mind_map(jsonb)','execute')`)||sql(`(select not prosecdef or not proconfig @> array['search_path=""'] from pg_proc where oid='public.create_mind_map(jsonb)'::regprocedure)`))throw Error('Unsafe execute exposure/search_path');
  write(`update public.activity_instances set status='completed',completed_at=clock_timestamp() where id='${late}';`);deny(await create(a1,late),'55000');
  write(`update public.activity_instances set status='archived' where id='${late}';`);deny(await create(a1,late),'55000');
  ok(await call(a1,`public.archive_artifact('${gap.artifact.id}')`));
  deny(await create(a1,blocked),'55000');
  const historicalRetry=ok(await create(a2,active,'source-archived-retry'));if(ids(historicalRetry)!==ids(first)||!historicalRetry.replayed)throw Error('Existing initialization depended on later source availability');
  if(JSON.stringify(counts(blocked))!=='[0,0,0,0,0]')throw Error('Revoked dependency left partial map');
  ok(await call(master,`public.remove_team_member('${t.team}','${a1}',null)`));deny(await create(a1,active));deny(await create(a1,race,'removed-new'));
  const hidden=ok(await call(a1,`(select count(*) from public.artifacts x join public.artifact_versions y on y.artifact_id=x.id where x.id='${first.artifact.id}')`));if(hidden!==0)throw Error('Removed-member metadata leaked');
  if(sql(`(select count(*) from public.development_objects where object_type::text='CENTRAL_INVENTION')`)!==0)throw Error('Root became canonical Object');
  console.log('M11.8 root/singleton/actor-key/peer-retry/source-availability/approved-output/zero-clones/flags/output/no-baseline/concurrency/9-boundary-rollback/privacy/removal/PASS');
 }finally{run("psql",[...args,"-c",`drop database ${name} with(force)`]);}
}
