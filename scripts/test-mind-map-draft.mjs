import {spawn,spawnSync} from "node:child_process";
export async function testMindMapDraft({run,args,binary,childEnv,root}){
 const name="fici_mind_map_draft";run("psql",[...args,"-c",`create database ${name} template postgres`]);
 const db=args.map((v,i)=>args[i-1]==="-d"?name:v);
 const a1="00000000-0000-4000-8000-000000006004",a2="00000000-0000-4000-8000-000000006005",master="00000000-0000-4000-8000-000000006002";
 const call=(actor,expression,before="")=>new Promise((resolve,reject)=>{
  const child=spawn(binary("psql"),[...db,"--set=VERBOSITY=verbose","-t","-A","-f","-"],{cwd:root,env:childEnv,windowsHide:true});let out="",err="";
  const timer=setTimeout(()=>{child.kill();reject(Error("Node fixture timeout"));},60000);
  child.stdout.on("data",x=>out+=x);child.stderr.on("data",x=>err+=x);child.on("error",e=>{clearTimeout(timer);reject(e);});
  child.on("close",code=>{clearTimeout(timer);if(code!==0){const state=err.match(/ERROR:\s+([0-9A-Z]{5}):/);return state?resolve({code:state[1]}):reject(Error(err));}const line=out.split(/\r?\n/).find(x=>x.startsWith("RESULT="));if(!line)return reject(Error("Missing result"));resolve({code:"00000",data:JSON.parse(line.slice(7))});});
  child.stdin.end(`begin;set local statement_timeout='50s';set local role authenticated;select set_config('request.jwt.claim.sub','${actor}',true);${before}select 'RESULT='||(${expression})::text;select pg_sleep(0.05);commit;`);
 });
 const ok=x=>{if(x.code!=="00000")throw Error("Unexpected SQLSTATE "+x.code);return x.data;};
 const deny=(x,code="42501")=>{if(x.code!==code||x.data!==undefined)throw Error("Expected "+code+" got "+x.code);};
 const sql=x=>JSON.parse(run("psql",[...db,"-t","-A","-c",`select (${x})::text;`]).trim());
 const write=x=>run("psql",[...db,"-c",x]);
 const rpc=(actor,fn,input)=>call(actor,`public.${fn}('${JSON.stringify(input).replaceAll("'","''")}'::jsonb)`);
 const update=(actor,n,patch={},rev=n.edit_revision)=>rpc(actor,'update_mind_map_node',{nodeId:n.id,expectedRevision:rev,...patch});
 try{
  const generated=spawnSync(process.execPath,['scripts/mind-map-browser-fixture.mjs'],{cwd:root,encoding:'utf8',windowsHide:true});
  if(generated.status!==0)throw Error('Checkpoint fixture unavailable');
  const setup=generated.stdout.split('update auth.users set')[0].replace(/update public\.artifact_versions set status='SUBMITTED'[\s\S]*?;/,'');
  run('psql',[...db,'-f','-'],setup+'commit;');
  const fixture=sql(`(select jsonb_object_agg(key,value) from public.mind_map_browser_fixture)`);
  const m=fixture.map.mindMap,v=fixture.map.version,scope=fixture.scope;
  const save=(actor,expected,patch={})=>rpc(actor,'save_mind_map_draft',{mindMapId:m.id,expectedDraftRevision:expected,...patch});
  const read=()=>sql(`(select to_jsonb(x) from public.artifact_versions x where id='${v.id}')`);
  const unchanged=()=>JSON.stringify(sql(`jsonb_build_object('nodes',(select jsonb_agg(to_jsonb(n) order by id) from public.mind_map_nodes n),
   'edges',(select jsonb_agg(to_jsonb(e) order by id) from public.mind_map_edges e),'objects',(select jsonb_agg(to_jsonb(o) order by id) from public.development_objects o),
   'relationships',(select jsonb_agg(to_jsonb(o) order by id) from public.development_object_relationships o),'links',(select jsonb_agg(to_jsonb(o) order by id) from public.artifact_object_links o),
   'artifacts',(select jsonb_agg(to_jsonb(o) order by id) from public.artifacts o),'activity',(select jsonb_agg(to_jsonb(o) order by id) from public.activity_instances o),
   'baselines',(select jsonb_agg(to_jsonb(o) order by id) from public.project_baseline_items o),'versions', (select count(*) from public.artifact_versions))`));
  // Existing Version membership is preserved, including references beyond the
  // visible map. This is fixture-only composition, not a new link-write API.
  write(`insert into public.artifact_object_links(artifact_id,artifact_version_id,development_object_id,sequence) values('${m.artifact_id}','${v.id}','${fixture.object_gap.id}',1);`);
  const before=unchanged();const first=ok(await save(a1,0));let current=read();
  if(first.artifactVersionId!==v.id||first.draftRevision!==1||current.status!=='DRAFT'||current.version_number!==1||current.content_snapshot.nodes.length!==8||!current.content_snapshot.edges.some(e=>e.edgeType==='CROSS_CONNECTION'))throw Error('Basic checkpoint invalid');
  if(unchanged()!==before)throw Error('Checkpoint changed normalized state/history');
  const objectId=fixture.object_component.id;
  if(current.content_snapshot.nodes.find(n=>n.id===fixture.node_component.id).developmentObjectId!==objectId)throw Error('Object identity lost');
  const body=JSON.stringify(current.content_snapshot);ok(await save(a2,1));current=read();
  if(current.draft_revision!==2||JSON.stringify(current.content_snapshot)!==body)throw Error('M8 explicit no-op semantics/determinism diverged');
  ok(await call(a2,`public.save_mind_map_draft('${JSON.stringify({mindMapId:m.id,expectedDraftRevision:2})}'::jsonb)`,"set local timezone='America/New_York';"));
  if(JSON.stringify(read().content_snapshot)!==body)throw Error('Session timezone changed canonical checkpoint content');
  const p1=ok(await update(a1,fixture.node_component,{positionData:{x:712,y:321}}));
  ok(await update(a2,fixture.node_solution,{label:'Team authored collaborative solution',positionData:{x:910,y:511},metadata:{color:'green'}}));
  const addedEdge=ok(await rpc(a2,'connect_mind_map_nodes',{mindMapId:m.id,sourceNodeId:fixture.node_component.id,targetNodeId:fixture.node_solution.id,edgeType:'CROSS_CONNECTION',label:'Team authored connection'}));
  deny(await update(a2,fixture.node_component,{positionData:{x:999,y:999}}),'40001');
  const race=await Promise.all([save(a1,3),save(a2,3)]);
  if(race.filter(r=>r.code==='00000').length!==1||race.filter(r=>r.code==='23505').length!==1)throw Error('Whole Draft race silently overwrote');
  current=read();if(current.draft_revision!==4||current.content_snapshot.nodes.find(n=>n.id===p1.id).positionData.x!==712||current.content_snapshot.nodes.find(n=>n.id===fixture.node_solution.id).positionData.x!==910)throw Error('Lost canonical peer position');
  const winner=JSON.stringify(current);deny(await save(a2,3),'23505');if(JSON.stringify(read())!==winner)throw Error('Stale save mutated winner');
  const reloaded=ok(await call(a2,`public.get_mind_map_editor('${fixture.activity.activity.id}')`));
  const savedSolution=current.content_snapshot.nodes.find(n=>n.id===fixture.node_solution.id);
  if(reloaded.mindMap.id!==m.id||reloaded.mindMap.artifact_id!==m.artifact_id||savedSolution.label!=='Team authored collaborative solution'||savedSolution.metadata.color!=='green'||!current.content_snapshot.edges.some(e=>e.id===addedEdge.id&&e.label==='Team authored connection')||!reloaded.edges.some(e=>e.id===addedEdge.id)||reloaded.nodes.find(n=>n.id===p1.id)?.position_data.x!==712)throw Error('Collaborative snapshot/fresh authenticated reload lost canonical state');
  if(reloaded.nodes.length!==current.content_snapshot.nodes.length||reloaded.edges.length!==current.content_snapshot.edges.length)throw Error('Snapshot graph count differs from canonical reload');
  for(const node of reloaded.nodes){const captured=current.content_snapshot.nodes.find(n=>n.id===node.id);
   for(const [savedKey,rowKey] of Object.entries({nodeType:'node_type',label:'label',developmentObjectId:'development_object_id',parentNodeId:'parent_node_id',positionData:'position_data',metadata:'metadata',createdBy:'created_by',editRevision:'edit_revision',productClassification:'product_classification'})){
    if(JSON.stringify(captured[savedKey])!==JSON.stringify(node[rowKey]))throw Error('Snapshot lost canonical node field '+savedKey);
   }
  }
  // The same M8 token is authoritative across generic Draft and tool checkpoint writes.
  ok(await call(a2,`public.update_artifact_draft('${v.id}',4,'${JSON.stringify(current.content_snapshot).replaceAll("'","''")}'::jsonb)`));
  deny(await save(a1,4),'23505');let revision=5;
  for(const actor of ['00000000-0000-4000-8000-000000006001','00000000-0000-4000-8000-000000006003','00000000-0000-4000-8000-000000006007','00000000-0000-4000-8000-000000006008',''])deny(await save(actor,revision),actor?'42501':'28000');
  for(const field of ['actor','projectId','workspaceId','teamId','artifactVersionId','roomId','nodes','edges','contentSnapshot','status'])deny(await save(a1,revision,{[field]:m.id}),'22023');
  // Corruption is rejected, never silently repaired. Trusted fixture changes roll back.
  for(const statement of [
   `update public.mind_maps set root_node_id=null where id='${m.id}'`,
   `update public.development_objects set archived_at=clock_timestamp() where id='${objectId}'`,
   `update public.mind_map_nodes set node_type='UNSUPPORTED' where id='${fixture.node_problem.id}'`,
   `update public.mind_map_nodes set parent_node_id=id where id='${fixture.node_gap.id}'`,
  ]){
   const all0=unchanged(),version0=JSON.stringify(read());
   // Fixture corruption and failed save are in one transaction; no production hooks.
   const bad=await call(a1,`public.save_mind_map_draft('${JSON.stringify({mindMapId:m.id,expectedDraftRevision:revision})}'::jsonb)`,`reset role;${statement};set local role authenticated;`);
   if(bad.code==='00000')throw Error('Corrupt map accepted');
   if(unchanged()!==all0||JSON.stringify(read())!==version0)throw Error('Failed validation left state');
  }
  // Real BEFORE, AFTER and deferred-before-COMMIT trigger failures. Snapshot and
  // draft_revision are a single M8 row write, never separately committed.
  for(const phase of ['before','after','deferred']){
   const all0=unchanged(),version0=JSON.stringify(read());
   write(`create function public.mm_checkpoint_fault() returns trigger language plpgsql as $$begin raise exception 'Injected checkpoint failure' using errcode='P0001';end $$;
    create ${phase==='deferred'?'constraint ':''}trigger mm_checkpoint_fault ${phase==='deferred'?'after':phase} update on public.artifact_versions ${phase==='deferred'?'deferrable initially deferred ':''}for each row execute function public.mm_checkpoint_fault();`);
   deny(await save(a1,revision),'P0001');
   write('drop trigger mm_checkpoint_fault on public.artifact_versions;drop function public.mm_checkpoint_fault();');
   if(unchanged()!==all0||JSON.stringify(read())!==version0)throw Error('Partial checkpoint after injected failure');
  }
  ok(await save(a1,revision++));
  for(const statement of [`update public.artifact_versions set content_snapshot='{}' where id='${v.id}'`,`update public.artifact_versions set draft_revision=99 where id='${v.id}'`])deny(await call(a1,'null::jsonb',statement+';'));
  // Frozen bound Versions preserve exact snapshot/pointer/approval data.
  for(const status of ['SUBMITTED','UNDER_REVIEW','REVISION_REQUESTED','APPROVED','CURRENT','SUPERSEDED','ARCHIVED']){
   const frozen=fixture.readonlyMap.version.id,other=fixture.readonlyMap.mindMap.id;
   // State variants are independent transactional trusted fixtures.
   const result=await call(a1,`public.save_mind_map_draft('${JSON.stringify({mindMapId:other,expectedDraftRevision:0})}'::jsonb)`,
    `reset role;update public.artifact_versions set status='${status}',approved_by='${master}',approved_at=clock_timestamp() where id='${frozen}';set local role authenticated;`);
   deny(result,'55000');
  }
  ok(await call(master,`public.remove_team_member('${scope.teamId}','${a1}')`));
  const version0=JSON.stringify(read());deny(await save(a1,revision));if(JSON.stringify(read())!==version0)throw Error('Removed save mutated Draft');
  ok(await save(a2,revision));
  if(!sql(`(select to_jsonb(prosecdef and proconfig @> array['search_path=""']) from pg_proc where oid='public.save_mind_map_draft(jsonb)'::regprocedure)`))throw Error('Unsafe definer');
  if(sql(`to_jsonb(has_function_privilege('anon','public.save_mind_map_draft(jsonb)','execute') or has_function_privilege('service_role','public.save_mind_map_draft(jsonb)','execute'))`))throw Error('Excess execute grant');
  console.log('M11.14 canonical/basic/Object/no-clone/determinism/noop/live-position/node-CAS/whole-Draft-race/M8-CAS/TeamB/removal/frozen-Version/direct-client/rollback/definer PASS');
  console.log('M11.22 AT-MM-004 two actors/movement/label/edge/same Artifact/Draft revision 3-4/one CAS winner/fresh auth reload PASS');
 }finally{run('psql',[...args,'-c',`drop database ${name} with (force)`]);}
}
