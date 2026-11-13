import {spawn} from "node:child_process";
import {affinityOperationFixture} from "./affinity-operation-fixture.mjs";
export async function testMindMapNodes({run,args,binary,childEnv,root}){
 const name="fici_mind_map_nodes";run("psql",[...args,"-c",`create database ${name} template postgres`]);
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
 const add=(actor,map,type,patch={})=>rpc(actor,'add_mind_map_node',{mindMapId:map,nodeType:type,label:type+' visual',positionData:{x:1,y:2},...patch});
 const update=(actor,n,patch={},rev=n.edit_revision)=>rpc(actor,'update_mind_map_node',{nodeId:n.id,expectedRevision:rev,...patch});
 try{
  const definitions=`insert into public.activity_definitions(id,session_definition_id,name,method_type,workspace_mode,sequence) values
   ('00000000-0000-4000-8000-000001119001','00000000-0000-4000-8000-000000950702','Nodes Team','mind_map','Team Workspace',301),
   ('00000000-0000-4000-8000-000001119002','00000000-0000-4000-8000-000000950702','Nodes other Map','mind_map','Team Workspace',302),
   ('00000000-0000-4000-8000-000001119003','00000000-0000-4000-8000-000000950702','Nodes Personal','mind_map','Personal Workspace',303);`;
  const fixture=affinityOperationFixture(root).replace("update public.curriculum_versions set status='approved'",definitions+"update public.curriculum_versions set status='approved'");
  const setup=run("psql",[...db,"-t","-A","-f","-"],fixture+`select 'TARGET='||jsonb_build_object('project',(select payload->>'id' from logged_projects where label='Team'),'workspace',(select payload->>'primary_workspace_id' from logged_projects where label='Team'),'team',(select payload->>'teamId' from acceptance_teams where label='A'),'personalProject',(select payload->>'id' from logged_projects where label='Individual'),'personalWorkspace',(select payload->>'primary_workspace_id' from logged_projects where label='Individual'))::text;commit;`);
  const t=JSON.parse(setup.split(/\r?\n/).find(x=>x.startsWith('TARGET=')).slice(7));
  const start=async(i,personal=false)=>{const x=ok(await call(personal?a1:a2,`public.start_activity('00000000-0000-4000-8000-00000111900${i}','${personal?t.personalProject:t.project}','${personal?t.personalWorkspace:t.workspace}',${personal?'null':`'${t.team}'`})`));if(!x.started)throw Error('Start denied '+x.reasonCode);return x.activity.id;};
  const active=await start(1),other=await start(2),personal=await start(3,true);
  const init=async(id,actor=a1)=>ok(await rpc(actor,'create_mind_map',{activityInstanceId:id,idempotencyKey:'nodes'}));
  const map=await init(active),foreign=await init(other),own=await init(personal);
  const kinds=['SYSTEM','SUBSYSTEM','COMPONENT','FUNCTION','PROBLEM','SOLUTION','GAP'],objects={},nodes={};
  for(const kind of kinds)objects[kind]=ok(await call(a1,`public.create_development_object('${t.project}','${t.workspace}','${kind}','Canonical ${kind}','Canonical content','manual','{}')`));
  ok(await call(a1,`public.relate_development_objects('${objects.COMPONENT.id}','${objects.SYSTEM.id}','BELONGS_TO','Preserved canonical relation')`));
  const foreignObject=ok(await call(a1,`public.create_development_object('${t.personalProject}','${t.personalWorkspace}','COMPONENT','Private Component','Private content','manual','{}')`));
  const snapshot=()=>sql(`jsonb_build_object('objects',(select jsonb_agg(to_jsonb(x) order by id) from public.development_objects x),'relationships',(select jsonb_agg(to_jsonb(x) order by id) from public.development_object_relationships x),'versions',(select jsonb_agg(to_jsonb(x) order by id) from public.artifact_versions x),'artifacts',(select jsonb_agg(to_jsonb(x) order by id) from public.artifacts x),'activity',(select to_jsonb(x) from public.activity_instances x where id='${active}'),'baseline',(select jsonb_agg(to_jsonb(x)) from public.project_baseline_items x),'project',(select to_jsonb(x) from public.development_projects x where id='${t.project}'))`);
  const before=JSON.stringify(snapshot());let parent=map.rootNode.id;
  for(const kind of kinds){const n=ok(await add(a1,map.mindMap.id,kind,{developmentObjectId:objects[kind].id,parentNodeId:parent}));if(n.edit_revision!==0||n.created_by!==a1||n.development_object_id!==objects[kind].id||n.node_type!==kind||n.mind_map_id!==map.mindMap.id||n.parent_node_id!==parent||n.label!==kind+' visual'||n.position_data.x!==1||n.position_data.y!==2)throw Error('Invalid added node');nodes[kind]=n;parent=n.id;}
  // Seven types reuse exact canonical Objects; no automatic relationships or Version writes.
  if(JSON.stringify(snapshot())!==before)throw Error('Node add changed canonical history');
  const stored=ok(await call(a2,`(select jsonb_agg(to_jsonb(n) order by node_type) from public.mind_map_nodes n where mind_map_id='${map.mindMap.id}' and node_type<>'CENTRAL_INVENTION')`));
  if(stored.length!==7||kinds.some(kind=>!stored.some(n=>n.id===nodes[kind].id&&n.node_type===kind&&n.development_object_id===objects[kind].id)))throw Error('Fresh authenticated type/identity reload failed');
  console.log('M11.9 AT-MM-001 seven structural types / AT-MM-002 exact Object reuse and no clones PASS');
  const repeat=ok(await add(a2,map.mindMap.id,'COMPONENT',{developmentObjectId:objects.COMPONENT.id}));
  let component=ok(await update(a1,nodes.COMPONENT,{label:' Different visual label ',positionData:{x:12,y:-3},metadata:{color:'blue'},parentNodeId:map.rootNode.id}));
  if(component.edit_revision!==1||component.label!=='Different visual label'||component.created_by!==a1)throw Error('Controlled edit failed');
  component=ok(await update(a2,component,{developmentObjectId:null,parentNodeId:null}));if(component.development_object_id!==null||component.node_type!=='COMPONENT'||component.parent_node_id!==null)throw Error('Unlink failed');
  if(sql(`(select to_jsonb(development_object_id) from public.mind_map_nodes where id='${repeat.id}')`)!==objects.COMPONENT.id)throw Error('Unlink affected another node');
  component=ok(await update(a1,component,{developmentObjectId:objects.COMPONENT.id,parentNodeId:nodes.SUBSYSTEM.id}));
  deny(await update(a1,component,{developmentObjectId:objects.GAP.id}),'22023');deny(await update(a1,component,{developmentObjectId:foreignObject.id}));
  const noop=ok(await update(a2,component,{label:component.label}));if(JSON.stringify(noop)!==JSON.stringify(component))throw Error('No-op increments revision');
  const revision3=component;
  component=ok(await update(a1,component,{positionData:{x:77,y:44}}));if(component.edit_revision!==4)throw Error('Expected revision4');
  deny(await update(a2,revision3,{label:'Stale label'}),'40001');
  component=ok(await update(a2,component,{label:'Reloaded winner'}));if(component.edit_revision!==5||component.position_data.x!==77)throw Error('Retry lost winner');
  // Root is limited visual state. Reserved role is always server-preserved.
  let rootNode=ok(await update(a1,map.rootNode,{label:'Visual invention title',positionData:{x:5,y:6},metadata:{role:'spoof',color:'gold'}}));
  if(rootNode.metadata.role!=='central_invention'||rootNode.edit_revision!==1||rootNode.development_object_id!==null||rootNode.parent_node_id!==null)throw Error('Root identity changed');
  deny(await update(a2,map.rootNode,{label:'Stale root'}),'40001');
  deny(await update(a1,rootNode,{parentNodeId:nodes.SYSTEM.id}),'22023');deny(await update(a1,rootNode,{parentNodeId:null}),'22023');deny(await update(a1,rootNode,{developmentObjectId:objects.SYSTEM.id}),'22023');
  rootNode=ok(await update(a1,rootNode,{developmentObjectId:null}));if(rootNode.edit_revision!==1)throw Error('Root null link mutated');
  if(JSON.stringify(snapshot())!==before)throw Error('Root/unlink/edit changed Objects/Versions/Project/relationships');
  // Parent integrity, including transitive cycles; hierarchy reload is actual PostgreSQL.
  const hierarchy=sql(`(select jsonb_agg(jsonb_build_object('id',id,'parent',parent_node_id) order by id) from public.mind_map_nodes where id in('${nodes.SYSTEM.id}','${nodes.SUBSYSTEM.id}','${nodes.FUNCTION.id}'))`);
  if(!hierarchy.some(x=>x.id===nodes.SYSTEM.id&&x.parent===map.rootNode.id)||!hierarchy.some(x=>x.id===nodes.SUBSYSTEM.id&&x.parent===nodes.SYSTEM.id)||!hierarchy.some(x=>x.id===nodes.FUNCTION.id&&x.parent===nodes.COMPONENT.id))throw Error('Hierarchy lost');
  deny(await update(a1,nodes.SYSTEM,{parentNodeId:nodes.FUNCTION.id}),'22023');deny(await update(a1,component,{parentNodeId:component.id}),'22023');
  deny(await add(a1,map.mindMap.id,'SYSTEM',{parentNodeId:foreign.rootNode.id}));
  for(const bad of ['CENTRAL_INVENTION','IDEA','CUSTOM',''])deny(await add(a1,map.mindMap.id,bad),'22023');
  for(const field of ['createdBy','actor','projectId','workspaceId','teamId','artifactId','artifactVersionId','rootNodeId','status','nodeType','mindMapId','editRevision']){
   deny(await rpc(a1,'update_mind_map_node',{nodeId:component.id,expectedRevision:component.edit_revision,label:'spoof',[field]:t.project}),'22023');
  }
  for(const patch of [{expectedRevision:undefined,label:'x'},{expectedRevision:-1,label:'x'},{expectedRevision:0.5,label:'x'},{label:' '},{positionData:[]},{metadata:{projectId:t.project}},{metadata:{created_by:a2}}])deny(await update(a1,component,patch),'22023');
  deny(await update(a1,component,{}),'22023');deny(await add(a1,map.mindMap.id,'COMPONENT',{developmentObjectId:objects.GAP.id}),'22023');
  write(`update public.development_objects set archived_at=clock_timestamp() where id='${objects.GAP.id}'`);
  deny(await add(a1,map.mindMap.id,'GAP',{developmentObjectId:objects.GAP.id}));write(`update public.development_objects set archived_at=null where id='${objects.GAP.id}'`);
  // Real competing writers load one revision, with exactly one committed winner.
  const race=ok(await add(a1,map.mindMap.id,'FUNCTION'));
  const competed=await Promise.all([update(a1,race,{label:'A winner'}),update(a2,race,{positionData:{x:99,y:99}})]);
  if(competed.filter(x=>x.code==='00000').length!==1||competed.filter(x=>x.code==='40001').length!==1)throw Error('Silent overwrite');
  const winner=competed.find(x=>x.code==='00000').data;
  const fresh=ok(await update(a2,winner,{metadata:{color:'fresh'}}));if(fresh.edit_revision!==2)throw Error('Reload retry failed');
  // Rollback real AFTER-trigger failures for both atomic operations.
  const count=()=>sql(`(select to_jsonb(count(*)) from public.mind_map_nodes)`);
  for(const event of ['insert','update']){
   const n0=count(),row0=sql(`(select to_jsonb(n) from public.mind_map_nodes n where id='${fresh.id}')`);
   write(`create function public.mm_node_fault() returns trigger language plpgsql as $$begin raise exception 'Injected node failure' using errcode='P0001';end $$;create trigger mm_node_fault after ${event} on public.mind_map_nodes for each row execute function public.mm_node_fault();`);
   deny(event==='insert'?await add(a1,map.mindMap.id,'SYSTEM'):await update(a2,fresh,{label:'Must rollback'}),'P0001');
   write('drop trigger mm_node_fault on public.mind_map_nodes;drop function public.mm_node_fault();');
   if(count()!==n0||JSON.stringify(row0)!==JSON.stringify(sql(`(select to_jsonb(n) from public.mind_map_nodes n where id='${fresh.id}')`)))throw Error('Partial mutation after failure');
  }
  // Personal privacy and role-only callers cannot bypass M7/M4 scope.
  ok(await add(a1,own.mindMap.id,'PROBLEM'));
  for(const actor of [a2,master])deny(await add(actor,own.mindMap.id,'SYSTEM'));
  for(const actor of ['00000000-0000-4000-8000-000000006007',master,'00000000-0000-4000-8000-000000006001','00000000-0000-4000-8000-000000006003','00000000-0000-4000-8000-000000006008','']){
   deny(await add(actor,map.mindMap.id,'SYSTEM'),actor?'42501':'28000');deny(await update(actor,component,{developmentObjectId:null}),actor?'42501':'28000');
  }
  for(const statement of [`update public.mind_map_nodes set edit_revision=edit_revision+1 where id='${component.id}'`,`delete from public.mind_map_nodes where id='${component.id}'`,`insert into public.mind_map_nodes(mind_map_id,node_type,label,created_by) values('${map.mindMap.id}','SYSTEM','Forged','${a1}')`,`select private.require_mind_map_node_edit('${map.mindMap.id}')`])deny(await call(a1,'null::jsonb',statement+';'));
  if(!sql(`(select to_jsonb(bool_and(prosecdef and proconfig @> array['search_path=""'])) from pg_proc where oid in('public.add_mind_map_node(jsonb)'::regprocedure,'public.update_mind_map_node(jsonb)'::regprocedure))`))throw Error('Unsafe definer');
  if(sql(`to_jsonb(has_function_privilege('anon','public.add_mind_map_node(jsonb)','execute') or has_function_privilege('service_role','public.update_mind_map_node(jsonb)','execute'))`))throw Error('Excess execute');
  // Freeze conditions hold even for currently authorized actors.
  write(`update public.artifact_versions set status='SUBMITTED' where id='${foreign.version.id}'`);
  deny(await add(a1,foreign.mindMap.id,'SYSTEM'),'55000');deny(await update(a1,foreign.rootNode,{label:'Locked'}),'55000');
  write(`update public.activity_instances set status='completed',completed_at=clock_timestamp() where id='${personal}'`);
  deny(await add(a1,own.mindMap.id,'SYSTEM'),'55000');
  ok(await call(master,`public.remove_team_member('${t.team}','${a1}')`));
  deny(await add(a1,map.mindMap.id,'SYSTEM'));deny(await update(a1,component,{developmentObjectId:null}));
  const reload=ok(await rpc(a2,'create_mind_map',{activityInstanceId:active,idempotencyKey:'after-node-edits'}));
  if(reload.rootNode.id!==rootNode.id||reload.rootNode.label!==rootNode.label||reload.rootNode.edit_revision!==1)throw Error('Initialization retry rewrote edited root');
  if(sql(`(select to_jsonb(count(*)) from public.mind_map_nodes where mind_map_id='${map.mindMap.id}' and node_type='CENTRAL_INVENTION')`)!==1)throw Error('Duplicate root');
  console.log('M11.22 AT-MM-001 seven exact persisted types/Team labels/positions/parents/server creator/revision PASS');
  console.log('M11.22 AT-MM-002 exact existing Objects/full-row preservation/no duplication/compatibility PASS');
  console.log('MIND_MAP_NODE_RESULT='+JSON.stringify(fresh));
  console.log('M11.9 hierarchy/root-visual-CAS/3-4-5/noop/unlink-relink/repeated-reference/compatibility/no-canonical-effects/two-session-conflict/rollback/TeamB/Personal/removal/direct-client/frozen-Version PASS');
 }finally{run('psql',[...args,'-c',`drop database ${name} with (force)`]);}
}
