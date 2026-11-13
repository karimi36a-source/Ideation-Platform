import {spawn} from "node:child_process";
import {affinityOperationFixture} from "./affinity-operation-fixture.mjs";
export async function testMindMapEdges({run,args,binary,childEnv,root}){
 const name="fici_mind_map_edges";run("psql",[...args,"-c",`create database ${name} template postgres`]);
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
  ok(await call(a1,`public.create_development_object('${t.personalProject}','${t.personalWorkspace}','COMPONENT','Private Component','Private content','manual','{}')`));

  ok(await call(a1,`public.relate_development_objects('${objects.COMPONENT.id}','${objects.FUNCTION.id}','CONNECTED_TO','Preserved C-F relation')`));
  let parent=map.rootNode.id;
  for(const kind of kinds){nodes[kind]=ok(await add(a1,map.mindMap.id,kind,{parentNodeId:parent,developmentObjectId:objects[kind].id}));parent=nodes[kind].id;}
  const unlinked=ok(await add(a2,map.mindMap.id,'SYSTEM'));
  const state=()=>sql(`jsonb_build_object('objects',(select jsonb_agg(to_jsonb(x) order by id) from public.development_objects x),'relationships',(select jsonb_agg(to_jsonb(x) order by id) from public.development_object_relationships x),'versions',(select jsonb_agg(to_jsonb(x) order by id) from public.artifact_versions x),'artifacts',(select jsonb_agg(to_jsonb(x) order by id) from public.artifacts x),'nodes',(select jsonb_agg(to_jsonb(x) order by id) from public.mind_map_nodes x),'baselines',(select jsonb_agg(to_jsonb(x)) from public.project_baseline_items x),'log',(select jsonb_agg(to_jsonb(x) order by id) from public.change_log x))`);
  const original=JSON.stringify(state());const c=nodes.COMPONENT,f=nodes.FUNCTION;
  const connect=(actor,source,target,type='CROSS_CONNECTION',patch={})=>rpc(actor,'connect_mind_map_nodes',{mindMapId:map.mindMap.id,sourceNodeId:source,targetNodeId:target,edgeType:type,...patch});
  const edit=(actor,e,patch={},rev=e.edit_revision)=>rpc(actor,'update_mind_map_edge',{edgeId:e.id,expectedRevision:rev,...patch});
  const remove=(actor,e,rev=e.edit_revision)=>rpc(actor,'remove_mind_map_edge',{edgeId:e.id,expectedRevision:rev});
  const row=id=>sql(`coalesce((select to_jsonb(x) from public.mind_map_edges x where id='${id}'),'null'::jsonb)`);
  let hierarchy=ok(await connect(a1,c.id,f.id,'HIERARCHY',{label:'  C to F  '}));
  if(hierarchy.label!=='C to F'||hierarchy.edit_revision!==0||hierarchy.mind_map_id!==map.mindMap.id)throw Error('Basic edge persistence failed');
  const rootEdge=ok(await connect(a2,map.rootNode.id,nodes.SYSTEM.id,'HIERARCHY'));
  if(rootEdge.label!==null)throw Error('Omitted label not null');
  const cross=ok(await connect(a1,c.id,f.id));
  ok(await connect(a1,f.id,c.id));ok(await connect(a1,map.rootNode.id,unlinked.id));
  const cycle=ok(await connect(a1,unlinked.id,map.rootNode.id));
  ok(await connect(a1,unlinked.id,nodes.PROBLEM.id));ok(await connect(a2,nodes.PROBLEM.id,map.rootNode.id));
  if(cycle.edge_type!=='CROSS_CONNECTION')throw Error('Cross connection cycle forbidden');
  deny(await connect(a1,c.id,f.id,'HIERARCHY'),'23505');deny(await connect(a1,c.id,f.id,'CROSS_CONNECTION',{label:'different label'}),'23505');
  for(const type of ['HIERARCHY','CROSS_CONNECTION'])deny(await connect(a1,c.id,c.id,type),'22023');
  for(const type of ['VISUAL_LINK','BELONGS_TO','CONNECTED_TO',''])deny(await connect(a1,c.id,f.id,type),'22023');
  deny(await connect(a1,c.id,nodes.SYSTEM.id,'HIERARCHY'),'22023');
  deny(await connect(a1,c.id,foreign.rootNode.id));
  deny(await call(a1,`public.connect_mind_map_nodes('${JSON.stringify({mindMapId:foreign.mindMap.id,sourceNodeId:c.id,targetNodeId:f.id,edgeType:'CROSS_CONNECTION'})}')`));
  // Direct trusted SQL demonstrates retained FK and new integrity constraints.
  const directReject=(statement,expected)=>write(`do $$begin begin ${statement};exception when sqlstate '${expected}' then return;end;raise exception 'Expected database rejection';end $$;`);
  directReject(`insert into public.mind_map_edges(mind_map_id,source_node_id,target_node_id,edge_type) values('${map.mindMap.id}','${c.id}','${foreign.rootNode.id}','CROSS_CONNECTION')`,'23503');
  directReject(`insert into public.mind_map_edges(mind_map_id,source_node_id,target_node_id,edge_type) values('${map.mindMap.id}','${c.id}','${c.id}','CROSS_CONNECTION')`,'23514');
  directReject(`insert into public.mind_map_edges(mind_map_id,source_node_id,target_node_id,edge_type) values('${map.mindMap.id}','${c.id}','${f.id}','HIERARCHY')`,'23505');
  if(JSON.stringify(state())!==original)throw Error('Visual edges changed canonical data');
  // Existing hierarchy edges cannot drift when an M11.9 parent is changed.
  deny(await update(a1,f,{parentNodeId:nodes.SYSTEM.id}),'22023');
  ok(await remove(a1,hierarchy));
  if(JSON.stringify(state())!==original)throw Error('Hierarchy removal changed parent/nodes/history');
  let e=ok(await edit(a1,cross,{edgeType:'HIERARCHY'}));
  e=ok(await edit(a1,e,{edgeType:'CROSS_CONNECTION'}));if(e.edit_revision!==2)throw Error('Expected revision2');
  const revision2=e;e=ok(await edit(a1,e,{label:'Revision three'}));if(e.edit_revision!==3)throw Error('Revision3 missing');
  deny(await edit(a2,revision2,{metadata:{color:'stale'}}),'40001');e=ok(await edit(a2,e,{metadata:{color:'new'}}));if(e.edit_revision!==4)throw Error('Revision4 missing');
  const unchanged=ok(await edit(a1,e,{label:e.label}));if(JSON.stringify(unchanged)!==JSON.stringify(e))throw Error('No-op changed revision');
  deny(await remove(a2,e,3),'40001');
  console.log('MIND_MAP_EDGE_RESULT='+JSON.stringify(e));
  const removed=ok(await remove(a1,e));if(removed.id!==e.id||removed.edit_revision!==4||row(e.id)!==null)throw Error('Remove result invalid');
  deny(await edit(a2,e,{label:'Resurrect'}));deny(await remove(a2,e));
  let cleared=ok(await connect(a1,c.id,f.id,'CROSS_CONNECTION',{label:'clear me'}));
  cleared=ok(await edit(a2,cleared,{label:null}));if(cleared.label!==null||cleared.edit_revision!==1)throw Error('Label null not distinguished');
  deny(await edit(a1,cleared,{edgeType:'HIERARCHY',metadata:{projectId:t.project}}),'22023');
  const badHierarchy=ok(await connect(a1,c.id,nodes.SYSTEM.id));deny(await edit(a1,badHierarchy,{edgeType:'HIERARCHY'}),'22023');
  for(const field of ['mindMapId','sourceNodeId','targetNodeId','createdBy','actor','projectId','workspaceId','teamId','artifactId','artifactVersionId','developmentObjectRelationshipId','status','baseline','editRevision']){
   deny(await rpc(a1,'update_mind_map_edge',{edgeId:cleared.id,expectedRevision:cleared.edit_revision,label:'spoof',[field]:c.id}),'22023');
   deny(await connect(a1,c.id,f.id,'CROSS_CONNECTION',{[field]:t.project}),['mindMapId','sourceNodeId','targetNodeId'].includes(field)?'42501':'22023');
  }
  for(const patch of [{label:' '},{label:'x'.repeat(201)},{metadata:[]},{metadata:{sourceNodeId:c.id}},{metadata:{baseline_state:'fake'}},{metadata:{relationship_type:'BELONGS_TO'}}])deny(await edit(a1,cleared,patch),'22023');
  deny(await edit(a1,cleared,{}),'22023');deny(await rpc(a1,'remove_mind_map_edge',{edgeId:cleared.id}),'22023');
  if(JSON.stringify(state())!==original)throw Error('Edits/removal affected nodes/Objects/relationships/Artifacts/baseline/log');
  // Independent database sessions: duplicates, stale update and update/remove.
  const unique=await Promise.all([connect(a1,unlinked.id,c.id),connect(a2,unlinked.id,c.id)]);
  if(unique.filter(x=>x.code==='00000').length!==1||unique.filter(x=>x.code==='23505').length!==1)throw Error('Concurrent duplicate accepted');
  const raced=unique.find(x=>x.code==='00000').data;
  const writers=await Promise.all([edit(a1,raced,{label:'writer1'}),edit(a2,raced,{metadata:{color:'writer2'}})]);
  if(writers.filter(x=>x.code==='00000').length!==1||writers.filter(x=>x.code==='40001').length!==1)throw Error('Silent stale overwrite');
  const winner=writers.find(x=>x.code==='00000').data;
  const pair=await Promise.all([remove(a1,winner),remove(a2,winner)]);
  if(pair.filter(x=>x.code==='00000').length!==1||pair.filter(x=>x.code==='42501').length!==1||row(winner.id)!==null)throw Error('Remove race resurrected edge');
  const mixed=ok(await connect(a1,unlinked.id,f.id));
  const mix=await Promise.all([edit(a1,mixed,{label:'racing update'}),remove(a2,mixed)]);
  if(mix.filter(x=>x.code==='00000').length!==1||!mix.some(x=>['40001','42501'].includes(x.code)))throw Error('Update/remove race inconsistent');
  // Forced exceptions prove atomic create/update/delete with full rollback.
  for(const event of ['insert','update','delete']){
   const prior=sql('(select coalesce(jsonb_agg(to_jsonb(x) order by id),\'[]\') from public.mind_map_edges x)');
   write(`create function public.mm_edge_fault() returns trigger language plpgsql as $$begin raise exception 'Injected edge failure' using errcode='P0001';end $$;create trigger mm_edge_fault after ${event} on public.mind_map_edges for each row execute function public.mm_edge_fault();`);
   deny(event==='insert'?await connect(a1,unlinked.id,nodes.GAP.id):event==='update'?await edit(a1,cleared,{label:'rollback'}):await remove(a1,cleared),'P0001');
   write('drop trigger mm_edge_fault on public.mind_map_edges;drop function public.mm_edge_fault();');
   if(JSON.stringify(prior)!==JSON.stringify(sql('(select coalesce(jsonb_agg(to_jsonb(x) order by id),\'[]\') from public.mind_map_edges x)')))throw Error('Partial edge mutation');
  }
  for(const actor of ['00000000-0000-4000-8000-000000006007',master,'00000000-0000-4000-8000-000000006001','00000000-0000-4000-8000-000000006003','00000000-0000-4000-8000-000000006008','']){
   for(const action of [()=>connect(actor,c.id,f.id),()=>edit(actor,cleared,{label:'foreign'}),()=>remove(actor,cleared)])deny(await action(),actor?'42501':'28000');
  }
  // Personal access remains owner-only; endpoints can be unlinked visual nodes.
  const personalNode=ok(await add(a1,own.mindMap.id,'SYSTEM'));
  const personalInput={mindMapId:own.mindMap.id,sourceNodeId:own.rootNode.id,targetNodeId:personalNode.id,edgeType:'CROSS_CONNECTION'};
  ok(await rpc(a1,'connect_mind_map_nodes',personalInput));for(const actor of [a2,master])deny(await rpc(actor,'connect_mind_map_nodes',personalInput));
  for(const stmt of [`update public.mind_map_edges set edit_revision=99 where id='${cleared.id}'`,`delete from public.mind_map_edges where id='${cleared.id}'`,`insert into public.mind_map_edges(mind_map_id,source_node_id,target_node_id,edge_type) values('${map.mindMap.id}','${c.id}','${f.id}','CROSS_CONNECTION')`,`select private.mutate_mind_map_edge('{}','connect')`])deny(await call(a1,'null::jsonb',stmt+';'));
  if(!sql(`(select to_jsonb(bool_and(prosecdef and proconfig @> array['search_path=""'])) from pg_proc where oid in('public.connect_mind_map_nodes(jsonb)'::regprocedure,'public.update_mind_map_edge(jsonb)'::regprocedure,'public.remove_mind_map_edge(jsonb)'::regprocedure))`))throw Error('Unsafe definer');
  if(sql(`to_jsonb(has_function_privilege('anon','public.connect_mind_map_nodes(jsonb)','execute') or has_function_privilege('service_role','public.remove_mind_map_edge(jsonb)','execute'))`))throw Error('Excess execute');
  // Frozen Version state rejects every edge operation without changing it.
  write(`update public.artifact_versions set status='SUBMITTED' where id='${map.version.id}'`);
  for(const action of [()=>connect(a1,c.id,f.id),()=>edit(a1,cleared,{label:'frozen'}),()=>remove(a1,cleared)])deny(await action(),'55000');
  // Use the independent still-editable map to exercise removal revocation.
  const otherNode=ok(await add(a1,foreign.mindMap.id,'SYSTEM'));
  const otherEdge=ok(await rpc(a1,'connect_mind_map_nodes',{mindMapId:foreign.mindMap.id,sourceNodeId:foreign.rootNode.id,targetNodeId:otherNode.id,edgeType:'CROSS_CONNECTION'}));
  ok(await call(master,`public.remove_team_member('${t.team}','${a1}')`));
  deny(await rpc(a1,'connect_mind_map_nodes',{mindMapId:foreign.mindMap.id,sourceNodeId:otherNode.id,targetNodeId:foreign.rootNode.id,edgeType:'CROSS_CONNECTION'}));deny(await edit(a1,otherEdge,{label:'stale member'}));deny(await remove(a1,otherEdge));
  console.log('M11.10 Component-Function/root/hierarchy-parent/no-self/directional-unique/parallel/cycle/label-null/CAS-2-3-4/remove-races/three-boundary-rollback/no-canonical-sync/TeamB/Personal/removal/direct-denial/frozen-Version PASS');
 }finally{run('psql',[...args,'-c',`drop database ${name} with (force)`]);}
}
