import {spawn,spawnSync} from "node:child_process";
export async function testMindMapRls({run,args,binary,childEnv,root}){
 const name="fici_mind_map_rls";run("psql",[...args,"-c",`create database ${name} template postgres`]);
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
  if(generated.status!==0)throw Error('RLS fixture unavailable');
  const personalDef="insert into public.activity_definitions(id,session_definition_id,name,method_type,workspace_mode,sequence) values('00000000-0000-4000-8000-000001120001','00000000-0000-4000-8000-000000950702','Personal RLS map','mind_map','Personal Workspace',320);";
  const setup=generated.stdout.split('update auth.users set')[0].replace("update public.curriculum_versions set status='approved'",personalDef+"update public.curriculum_versions set status='approved'");
  run('psql',[...db,'-f','-'],setup+`set local role authenticated;select set_config('request.jwt.claim.sub','${a1}',true);
   insert into public.mind_map_browser_fixture select 'personalActivity',public.start_activity('00000000-0000-4000-8000-000001120001',(payload->>'id')::uuid,(payload->>'primary_workspace_id')::uuid) from logged_projects where label='Individual';
   insert into public.mind_map_browser_fixture select 'personalMap',public.create_mind_map(jsonb_build_object('activityInstanceId',value#>>'{activity,id}','idempotencyKey','personal-rls')) from public.mind_map_browser_fixture where key='personalActivity';commit;`);
  const f=sql('(select jsonb_object_agg(key,value) from public.mind_map_browser_fixture)'),m=f.map.mindMap,scope=f.scope,activity=f.activity.activity.id,b='00000000-0000-4000-8000-000000006007';
  write(`begin;set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006001',true);
   insert into public.mind_map_browser_fixture select 'foreignProject',public.create_development_project('RLS foreign Team','team',workspace_id,null,null,id) from public.teams where id='${scope.teamBId}';reset role;
   insert into public.project_memberships(project_id,user_id) select (value->>'id')::uuid,'${b}' from public.mind_map_browser_fixture where key='foreignProject';
   set local role authenticated;select set_config('request.jwt.claim.sub','${b}',true);
   insert into public.mind_map_browser_fixture select 'foreignObject',public.create_development_object((value->>'id')::uuid,(value->>'primary_workspace_id')::uuid,'COMPONENT','Foreign private component','Foreign body',null) from public.mind_map_browser_fixture where key='foreignProject';commit;`);
  const foreign=sql("(select value from public.mind_map_browser_fixture where key='foreignObject')"),node=f.node_component,edge=f.crossEdge;
  // M11.26: genuine second Team map, not a forged scope or synthetic ID.
  write(`insert into public.project_program_links(project_id,program_id,cohort_id) select '${foreign.project_id}',c.program_id,c.id from public.teams t join public.cohorts c on c.id=t.cohort_id where t.id='${scope.teamBId}';`);
  ok(await call('00000000-0000-4000-8000-000000006001',`public.assign_team_lead('${scope.teamBId}','${b}')`));
  const foreignActivity=ok(await call(b,`public.start_activity('00000000-0000-4000-8000-000001119001','${foreign.project_id}','${foreign.workspace_id}','${scope.teamBId}')`));
  if(!foreignActivity.started)throw Error('M11.26 TeamB control unavailable: '+foreignActivity.reasonCode);
  const foreignMap=ok(await rpc(b,'create_mind_map',{activityInstanceId:foreignActivity.activity.id,idempotencyKey:'cross-team-control'}));
  const foreignNode=ok(await rpc(b,'add_mind_map_node',{mindMapId:foreignMap.mindMap.id,nodeType:'COMPONENT',label:'TeamB private component',developmentObjectId:foreign.id,positionData:{x:1,y:1}}));
  deny(await update(b,foreignNode,{developmentObjectId:f.object_component.id}));
  deny(await update(a1,node,{developmentObjectId:foreign.id}));
  for(const [actor,mapId,sourceId,targetId] of [[a1,m.id,node.id,foreignNode.id],[b,foreignMap.mindMap.id,foreignNode.id,node.id]])deny(await rpc(actor,'connect_mind_map_nodes',{mindMapId:mapId,sourceNodeId:sourceId,targetNodeId:targetId,edgeType:'CROSS_CONNECTION'}));
  console.log('M11.26 bidirectional cross-Team Object-link and cross-map endpoint denial / authorized TeamB control PASS');
  const rows=(actor,table,id)=>call(actor,`(select coalesce(jsonb_agg(to_jsonb(t)),'[]') from public.${table} t where id='${id}')`);
  for(const [table,id] of [['mind_maps',m.id],['mind_map_nodes',node.id],['mind_map_edges',edge.id]]){
   if(ok(await rows(a1,table,id)).length!==1)throw Error('Authorized direct read missing');
   for(const actor of [b,master,'00000000-0000-4000-8000-000000006001','00000000-0000-4000-8000-000000006003',''])if(ok(await rows(actor,table,id)).length)throw Error('Private exact-ID leak');
   deny(await call(a1,'null::jsonb',`set local role anon;select * from public.${table};`));
   for(const actor of [a1,b])for(const statement of [`insert into public.${table} default values`,`update public.${table} set id=id where id='${id}'`,`delete from public.${table} where id='${id}'`])deny(await call(actor,'null::jsonb',statement+';'));
  }
  for(const actor of [a2,b,master,'00000000-0000-4000-8000-000000006001'])if(ok(await rows(actor,'mind_maps',f.personalMap.mindMap.id)).length)throw Error('Personal leak');
  if(ok(await rows(a1,'mind_maps',f.personalMap.mindMap.id)).length!==1)throw Error('Personal owner denied');
  deny(await update(a1,node,{developmentObjectId:foreign.id}));
  for(const patch of [{createdBy:a2},{mindMapId:f.readonlyMap.mindMap.id},{projectId:foreign.project_id}])deny(await update(a1,node,patch),'22023');
  deny(await update(a1,node,{parentNodeId:f.readonlyMap.rootNode.id}));
  deny(await rpc(a1,'connect_mind_map_nodes',{mindMapId:m.id,sourceNodeId:node.id,targetNodeId:f.readonlyMap.rootNode.id,edgeType:'CROSS_CONNECTION'}));
  for(const statement of [`update public.mind_maps set artifact_id='${f.readonlyMap.artifact.id}',artifact_version_id='${f.readonlyMap.version.id}',root_node_id='${f.readonlyMap.rootNode.id}' where id='${m.id}'`,`update public.mind_map_nodes set created_by='${a2}',development_object_id='${foreign.id}',mind_map_id='${f.readonlyMap.mindMap.id}' where id='${node.id}'`,`update public.mind_map_edges set target_node_id='${f.readonlyMap.rootNode.id}',edit_revision=99 where id='${edge.id}'`,`update public.development_objects set product_classification='CORE' where id='${f.object_component.id}'`])deny(await call(a1,'null::jsonb',statement+';'));
  const guardedEdge=ok(await rpc(a1,'connect_mind_map_nodes',{mindMapId:m.id,sourceNodeId:node.id,targetNodeId:f.node_solution.id,edgeType:'CROSS_CONNECTION'}));
  // Trusted malformed persisted reference: both RLS and elevated editor must fail closed.
  write(`update public.mind_map_nodes set development_object_id='${foreign.id}' where id='${node.id}'`);
  if(ok(await rows(a1,'mind_map_nodes',node.id)).length)throw Error('Foreign Object leaked through node RLS');
  const malformed=ok(await call(a1,`public.get_mind_map_editor('${activity}')`));
  if(ok(await rows(a1,'mind_map_edges',guardedEdge.id)).length||malformed.edges.some(e=>e.id===guardedEdge.id))throw Error('Hidden source endpoint leaked through edge');
  if(JSON.stringify(malformed).includes(foreign.id))throw Error('Foreign Object identity leaked through SECURITY DEFINER editor');
  write(`update public.mind_map_nodes set development_object_id='${f.object_component.id}' where id='${node.id}'`);
  const saved=ok(await rpc(a1,'save_mind_map_draft',{mindMapId:m.id,expectedDraftRevision:0}));
  if(saved.draftRevision!==1)throw Error('Save failed');
  const next=ok(await rpc(a1,'create_mind_map_version',{mindMapId:m.id,expectedDraftRevision:1,changeSummary:'RLS checkpoint'}));
  for(const actor of [a1,a2])if(ok(await rows(actor,'mind_maps',m.id)).length!==1||ok(await rows(actor,'mind_maps',next.mindMap.id)).length!==1)throw Error('History read denied');
  deny(await rpc(a1,'save_mind_map_draft',{mindMapId:m.id,expectedDraftRevision:1}),'55000');
  const history=()=>sql(`jsonb_build_object('maps',(select jsonb_agg(to_jsonb(x) order by id) from public.mind_maps x),'nodes',(select jsonb_agg(to_jsonb(x) order by id) from public.mind_map_nodes x),'edges',(select jsonb_agg(to_jsonb(x) order by id) from public.mind_map_edges x))`),before=JSON.stringify(history());
  ok(await call(master,`public.remove_team_member('${scope.teamId}','${a1}',null)`));
  for(const [table,id] of [['mind_maps',m.id],['mind_maps',next.mindMap.id],['mind_map_nodes',node.id],['mind_map_edges',edge.id]])if(ok(await rows(a1,table,id)).length)throw Error('Removed exact-ID access');
  for(const [operation,input] of [['update_mind_map_node',{nodeId:node.id,expectedRevision:node.edit_revision,label:'removed'}],['update_mind_map_edge',{edgeId:edge.id,expectedRevision:0,label:'removed'}],['save_mind_map_draft',{mindMapId:next.mindMap.id,expectedDraftRevision:0}],['create_mind_map_version',{mindMapId:next.mindMap.id,expectedDraftRevision:0,changeSummary:'removed'}]])deny(await rpc(a1,operation,input));
  deny(await call(a1,`public.get_mind_map_editor('${activity}')`));
  if(JSON.stringify(history())!==before)throw Error('Removal rewrote map history');
  if(ok(await rows(a1,'mind_maps',f.personalMap.mindMap.id)).length!==1)throw Error('Team removal damaged Personal map');
  if(!sql(`(select bool_and(relrowsecurity) from pg_class where oid in ('public.mind_maps'::regclass,'public.mind_map_nodes'::regclass,'public.mind_map_edges'::regclass))`))throw Error('RLS disabled');
  for(const table of ['mind_maps','mind_map_nodes','mind_map_edges'])if(sql(`has_table_privilege('authenticated','public.${table}','INSERT,UPDATE,DELETE')`)||sql(`has_table_privilege('anon','public.${table}','SELECT')`))throw Error('Unsafe table grant');
  if(!sql(`(select bool_and(prosecdef and proconfig=array['search_path=""']) from pg_proc where oid in ('public.can_read_mind_map(uuid)'::regprocedure,'public.can_read_mind_map_node(uuid)'::regprocedure,'public.can_read_mind_map_edge(uuid)'::regprocedure))`))throw Error('Unsafe predicates');
  if(sql("has_function_privilege('authenticated','private.mind_map_source_compatible(uuid)','EXECUTE')"))throw Error('Private source guard exposed');
  console.log('M11.20 Mind Map RLS exact-ID/history/source/CRUD/binding/spoof/Personal/lifecycle/removal/grants/authorized-operations PASS');
 }finally{run('psql',[...args,'-c',`drop database ${name} with(force)`]);}
}
