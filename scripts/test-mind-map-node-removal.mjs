import {spawn} from "node:child_process";
import {affinityOperationFixture} from "./affinity-operation-fixture.mjs";
export async function testMindMapNodeRemoval({run,args,binary,childEnv,root}){
 const name="fici_mind_map_node_removal";run("psql",[...args,"-c",`create database ${name} template postgres`]);
 const db=args.map((v,i)=>args[i-1]==="-d"?name:v);
 const a1="00000000-0000-4000-8000-000000006004",a2="00000000-0000-4000-8000-000000006005",master="00000000-0000-4000-8000-000000006002";
 const call=(actor,expression,before="")=>new Promise((resolve,reject)=>{
  const child=spawn(binary("psql"),[...db,"--set=VERBOSITY=verbose","-t","-A","-f","-"],{cwd:root,env:childEnv,windowsHide:true});let out="",err="";
  const timer=setTimeout(()=>{child.kill();reject(Error("Node fixture timeout"));},120000);
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
  const kinds=['SYSTEM','SUBSYSTEM','COMPONENT','FUNCTION','PROBLEM','SOLUTION','GAP'],objects={};
  for(const kind of kinds)objects[kind]=ok(await call(a1,`public.create_development_object('${t.project}','${t.workspace}','${kind}','Canonical ${kind}','Canonical content','manual','{}')`));
  ok(await call(a1,`public.relate_development_objects('${objects.COMPONENT.id}','${objects.SYSTEM.id}','BELONGS_TO','Preserved canonical relation')`));
  ok(await call(a1,`public.create_development_object('${t.personalProject}','${t.personalWorkspace}','COMPONENT','Private Component','Private content','manual','{}')`));

  const remove=(actor,n,revision=n.edit_revision)=>rpc(actor,'remove_mind_map_node',{nodeId:n.id,expectedRevision:revision});
  const edge=(a,b,type='CROSS_CONNECTION')=>rpc(a1,'connect_mind_map_nodes',{mindMapId:map.mindMap.id,sourceNodeId:a.id,targetNodeId:b.id,edgeType:type});
  const snapshot=()=>JSON.stringify(sql(`jsonb_build_object('objects',(select jsonb_agg(to_jsonb(x) order by id) from public.development_objects x),'relationships',(select jsonb_agg(to_jsonb(x) order by id) from public.development_object_relationships x),'versions',(select jsonb_agg(to_jsonb(x) order by id) from public.artifact_versions x),'artifacts',(select jsonb_agg(to_jsonb(x) order by id) from public.artifacts x),'activities',(select jsonb_agg(to_jsonb(x) order by id) from public.activity_instances x),'baselines',(select jsonb_agg(to_jsonb(x)) from public.project_baseline_items x),'links',(select jsonb_agg(to_jsonb(x) order by id) from public.artifact_object_links x))`));
  const visual=()=>JSON.stringify(sql(`jsonb_build_object('nodes',(select jsonb_agg(to_jsonb(x) order by id) from public.mind_map_nodes x),'edges',(select jsonb_agg(to_jsonb(x) order by id) from public.mind_map_edges x),'maps',(select jsonb_agg(to_jsonb(x) order by id) from public.mind_maps x))`));
  const loaded=ok(await call(a1,`public.get_mind_map_editor('${active}')`));
  if(loaded.mindMap.id!==map.mindMap.id||loaded.nodes.length!==1||loaded.edges.length!==0||loaded.editable!==true)throw Error('Invalid initial editor payload');
  deny(await call('00000000-0000-4000-8000-000000006007',`public.get_mind_map_editor('${active}')`));
  const parent=ok(await add(a1,map.mindMap.id,'SYSTEM',{parentNodeId:map.rootNode.id}));
  let leaf=ok(await add(a1,map.mindMap.id,'COMPONENT',{parentNodeId:parent.id,developmentObjectId:objects.COMPONENT.id}));
  leaf=ok(await rpc(a1,'classify_mind_map_node',{nodeId:leaf.id,expectedRevision:leaf.edit_revision,expectedObjectRevision:0,classification:'SUPPORTING'}));
  const canonicalBefore=ok(await call(a2,`(select to_jsonb(o) from public.development_objects o where id='${objects.COMPONENT.id}')`));
  const preserved=snapshot();
  const twin=ok(await add(a1,map.mindMap.id,'COMPONENT',{developmentObjectId:objects.COMPONENT.id}));
  const spare=ok(await add(a1,map.mindMap.id,'FUNCTION'));
  ok(await edge(parent,leaf,'HIERARCHY'));ok(await edge(leaf,twin));ok(await edge(spare,leaf));const kept=ok(await edge(twin,spare));
  for(const n of [map.rootNode,parent]){const before=visual();deny(await remove(a1,n),'22023');if(visual()!==before)throw Error('Guard changed visual state');}
  const removed=ok(await remove(a1,leaf));if(JSON.stringify(removed)!==JSON.stringify(leaf))throw Error('Removed row mismatch');
  if(sql(`(select to_jsonb(count(*)) from public.mind_map_nodes where id='${leaf.id}')`)!==0||sql(`(select to_jsonb(count(*)) from public.mind_map_edges where source_node_id='${leaf.id}' or target_node_id='${leaf.id}')`)!==0)throw Error('Leaf or incident edges survived');
  if(sql(`(select to_jsonb(count(*)) from public.mind_map_edges where id='${kept.id}')`)!==1)throw Error('Unrelated edge deleted');
  ok(await remove(a2,parent));deny(await remove(a1,leaf));
  if(snapshot()!==preserved)throw Error('Canonical history mutated');
  const canonicalAfter=ok(await call(a2,`(select to_jsonb(o) from public.development_objects o where id='${objects.COMPONENT.id}')`));
  if(JSON.stringify(canonicalAfter)!==JSON.stringify(canonicalBefore)||canonicalAfter.product_classification!=='SUPPORTING')throw Error('Fresh authenticated Object/classification survival failed');
  const relinked=ok(await call(a2,`public.get_mind_map_editor('${active}')`));
  if(relinked.nodes.find(n=>n.id===twin.id)?.product_classification!=='SUPPORTING')throw Error('Remaining view lost canonical classification');
  let cas=ok(await add(a1,map.mindMap.id,'FUNCTION'));for(let i=1;i<=5;i++)cas=ok(await update(a1,cas,{label:'Revision '+i}));
  const six=ok(await update(a1,cas,{label:'Revision 6'}));deny(await remove(a2,cas),'40001');ok(await remove(a2,six));
  for(const table of ['mind_map_edges','mind_map_nodes']){
   const before=visual();write(`create function public.mm_remove_fault() returns trigger language plpgsql as $$begin raise exception 'Injected failure' using errcode='P0001';end $$;create trigger mm_remove_fault after delete on public.${table} for each row execute function public.mm_remove_fault();`);
   deny(await remove(a1,twin),'P0001');write(`drop trigger mm_remove_fault on public.${table};drop function public.mm_remove_fault();`);if(before!==visual())throw Error('Partial delete after failure');
  }
  const system=ok(await add(a1,map.mindMap.id,'SYSTEM',{parentNodeId:map.rootNode.id}));
  const subsystem=ok(await add(a1,map.mindMap.id,'SUBSYSTEM',{parentNodeId:system.id}));
  const component=ok(await add(a1,map.mindMap.id,'COMPONENT',{parentNodeId:subsystem.id}));
  deny(await remove(a1,system),'22023');deny(await remove(a1,subsystem),'22023');
  ok(await remove(a1,component));ok(await remove(a1,subsystem));ok(await remove(a1,system));
  const branch=ok(await add(a1,map.mindMap.id,'SYSTEM'));
  const child1=ok(await add(a1,map.mindMap.id,'COMPONENT',{parentNodeId:branch.id}));
  const child2=ok(await add(a1,map.mindMap.id,'FUNCTION',{parentNodeId:branch.id}));
  deny(await remove(a1,branch),'22023');ok(await remove(a1,child1));deny(await remove(a1,branch),'22023');
  ok(await update(a1,child2,{parentNodeId:map.rootNode.id}));ok(await remove(a1,branch));
  const raced=ok(await add(a1,map.mindMap.id,'FUNCTION'));const results=await Promise.all([remove(a1,raced),remove(a2,raced)]);
  if(results.filter(x=>x.code==='00000').length!==1||results.filter(x=>x.code==='42501').length!==1)throw Error('Double removal race');
  const edited=ok(await add(a1,map.mindMap.id,'FUNCTION'));const edits=await Promise.all([update(a1,edited,{label:'Concurrent edit'}),remove(a2,edited)]);
  if(edits.filter(x=>x.code==='00000').length!==1||!edits.some(x=>['40001','42501'].includes(x.code)))throw Error('Update/remove race');
  const p=ok(await add(a1,map.mindMap.id,'SYSTEM'));const children=await Promise.all([add(a1,map.mindMap.id,'COMPONENT',{parentNodeId:p.id}),remove(a2,p)]);
  if(children[0].code==='00000'){deny(children[1],'22023');ok(await remove(a1,children[0].data));ok(await remove(a1,p));}else{deny(children[0]);ok(children[1]);}
  const e=ok(await add(a1,map.mindMap.id,'FUNCTION'));const connected=await Promise.all([edge(twin,e),remove(a2,e)]);ok(connected[1]);if(connected[0].code!=='00000')deny(connected[0]);
  if(sql(`(select to_jsonb(count(*)) from public.mind_map_edges e left join public.mind_map_nodes s on s.id=e.source_node_id left join public.mind_map_nodes t on t.id=e.target_node_id where s.id is null or t.id is null)`)!==0)throw Error('Dangling edge');
  const personalLeaf=ok(await add(a1,own.mindMap.id,'COMPONENT'));for(const actor of [a2,master])deny(await remove(actor,personalLeaf));ok(await remove(a1,personalLeaf));
  for(const actor of ['00000000-0000-4000-8000-000000006007',master,'00000000-0000-4000-8000-000000006001','00000000-0000-4000-8000-000000006003','00000000-0000-4000-8000-000000006008',''])deny(await remove(actor,twin),actor?'42501':'28000');
  for(const field of ['projectId','workspaceId','createdBy','force','mindMapId','status'])deny(await rpc(a1,'remove_mind_map_node',{nodeId:twin.id,expectedRevision:0,[field]:t.project}),'22023');
  for(const statement of [`delete from public.mind_map_nodes where id='${twin.id}'`,`update public.mind_map_nodes set edit_revision=1 where id='${twin.id}'`,`insert into public.mind_map_nodes(mind_map_id,node_type,label,created_by) values('${map.mindMap.id}','SYSTEM','Forged','${a1}')`])deny(await call(a1,'null::jsonb',statement+';'));
  if(!sql(`(select to_jsonb(prosecdef and proconfig @> array['search_path=""']) from pg_proc where oid='public.remove_mind_map_node(jsonb)'::regprocedure)`))throw Error('Unsafe definer');
  if(sql(`to_jsonb(has_function_privilege('anon','public.remove_mind_map_node(jsonb)','execute') or has_function_privilege('service_role','public.remove_mind_map_node(jsonb)','execute'))`))throw Error('Excess execute');
  const frozen=ok(await add(a1,foreign.mindMap.id,'COMPONENT'));write(`update public.artifact_versions set status='SUBMITTED' where id='${foreign.version.id}'`);deny(await remove(a1,frozen),'55000');
  const completed=ok(await add(a1,own.mindMap.id,'FUNCTION'));write(`update public.activity_instances set status='completed',completed_at=clock_timestamp() where id='${personal}'`);deny(await remove(a1,completed),'55000');write(`update public.activity_instances set status='archived' where id='${personal}'`);deny(await remove(a1,completed),'55000');
  ok(await call(master,`public.remove_team_member('${t.team}','${a1}')`));deny(await remove(a1,twin));ok(await remove(a2,twin));
  deny(await call(a1,`public.get_mind_map_editor('${active}')`));
  const current=ok(await call(a2,`public.get_mind_map_editor('${active}')`));if(current.mindMap.id!==map.mindMap.id||current.nodes.some(n=>n.id===twin.id))throw Error('Editor reload not canonical');
  console.log('MIND_MAP_REMOVED_NODE_RESULT='+JSON.stringify(removed));
  console.log('M11.11 AT-MM-003 root/children/leaf/incident-edges/Object-history/CAS/races/rollback/TeamB/removed/Personal/RLS PASS');
  console.log('M11.12 authorized editor load/reload/TeamB exact-ID/removed-member PASS');
  console.log('M11.22 AT-MM-003 visual leaf/incident edges removed/Object full-row/fresh auth reload/relationships/classification/history preserved PASS');
 }finally{run('psql',[...args,'-c',`drop database ${name} with (force)`]);}
}
