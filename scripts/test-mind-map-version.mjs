import {spawn,spawnSync} from "node:child_process";
export async function testMindMapVersion({run,args,binary,childEnv,root}){
 const name="fici_mind_map_version";run("psql",[...args,"-c",`create database ${name} template postgres`]);
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
 try{
  const generated=spawnSync(process.execPath,['scripts/mind-map-browser-fixture.mjs'],{cwd:root,encoding:'utf8',windowsHide:true});
  if(generated.status!==0)throw Error('Checkpoint fixture unavailable');
  const setup=generated.stdout.split('update auth.users set')[0].replace(/update public\.artifact_versions set status='SUBMITTED'[\s\S]*?;/,'');
  run('psql',[...db,'-f','-'],setup+'commit;');
  const fixture=sql(`(select jsonb_object_agg(key,value) from public.mind_map_browser_fixture)`);
  const m=fixture.map.mindMap,v=fixture.map.version,scope=fixture.scope;
  const snapshot=()=>sql(`jsonb_build_object('v',(select to_jsonb(x) from public.artifact_versions x where id='${v.id}'),'map',(select to_jsonb(x) from public.mind_maps x where id='${m.id}'),'nodes',(select jsonb_agg(to_jsonb(x) order by id) from public.mind_map_nodes x where mind_map_id='${m.id}'),'edges',(select jsonb_agg(to_jsonb(x) order by id) from public.mind_map_edges x where mind_map_id='${m.id}'),'links',(select jsonb_agg(to_jsonb(x) order by id) from public.artifact_object_links x where artifact_version_id='${v.id}'))`);
  const objectBefore=sql(`(select to_jsonb(x) from public.development_objects x where id='${fixture.object_component.id}')`);
  write(`insert into public.artifact_object_links(artifact_id,artifact_version_id,development_object_id,sequence) values('${m.artifact_id}','${v.id}','${fixture.object_component.id}',1);`);
  const save=ok(await rpc(a1,'save_mind_map_draft',{mindMapId:m.id,expectedDraftRevision:0}));
  const before=JSON.stringify(snapshot());
  const input={mindMapId:m.id,expectedDraftRevision:save.draftRevision,changeSummary:'Team authored checkpoint'};
  deny(await rpc(master,'create_mind_map_version',input));
  deny(await call(master,`public.create_artifact_version('${m.artifact_id}','{}'::jsonb,null)`));
  deny(await call(master,`public.update_artifact_draft('${v.id}',1,'{}'::jsonb)`));

  deny(await rpc('00000000-0000-4000-8000-000000006007','create_mind_map_version',input));
  deny(await rpc(a1,'create_mind_map_version',{...input,ownerUserId:a2}),'22023');
  deny(await rpc(a1,'create_mind_map_version',{...input,expectedDraftRevision:0}),'23505');
  const race=await Promise.all([rpc(a1,'create_mind_map_version',input),rpc(a2,'create_mind_map_version',input)]);
  if(race.filter(x=>x.code==='00000').length!==1)throw Error('Checkpoint race did not have exactly one winner: '+JSON.stringify(race));
  const next=race.find(x=>x.code==='00000').data;
  if(JSON.stringify(snapshot())!==before)throw Error('Predecessor mutated');
  if(next.version.previous_version_id!==v.id||next.version.version_number!==2||next.version.status!=='DRAFT'||next.version.draft_revision!==0||next.mindMap.id===m.id||next.version.id===v.id)throw Error('Invalid M8 lineage');
  const body=next.version.content_snapshot;
  const old=snapshot();
  if(body.nodes.length!==old.nodes.length||body.edges.length!==old.edges.length)throw Error('Graph count lost');
  for(const n of old.nodes){const copy=body.nodes.find(x=>x.label===n.label);if(!copy||copy.developmentObjectId!==n.development_object_id||JSON.stringify(copy.positionData)!==JSON.stringify(n.position_data)||JSON.stringify(copy.metadata)!==JSON.stringify(n.metadata)||copy.createdBy!==n.created_by)throw Error('Team structure/authorship changed');
   if(n.parent_node_id){const p=old.nodes.find(x=>x.id===n.parent_node_id);if(body.nodes.find(x=>x.id===copy.parentNodeId)?.label!==p.label)throw Error('Hierarchy changed');}}
  for(const edge of old.edges){
   const source=old.nodes.find(n=>n.id===edge.source_node_id).label,target=old.nodes.find(n=>n.id===edge.target_node_id).label;
   if(!body.edges.some(e=>e.edgeType===edge.edge_type&&e.label===edge.label&&JSON.stringify(e.metadata)===JSON.stringify(edge.metadata)&&body.nodes.find(n=>n.id===e.sourceNodeId)?.label===source&&body.nodes.find(n=>n.id===e.targetNodeId)?.label===target))throw Error('Cross-connection/edge changed');
  }
  if(body.initializedBy!==old.v.content_snapshot.initializedBy||body.initializedAt!==old.v.content_snapshot.initializedAt)throw Error('Initialization provenance changed');
  if(JSON.stringify(sql(`(select to_jsonb(x) from public.development_objects x where id='${fixture.object_component.id}')`))!==JSON.stringify(objectBefore))throw Error('Object changed');
  const activity=sql(`(select to_jsonb(activity_instance_id) from public.artifacts where id='${m.artifact_id}')`);
  const editor=ok(await call(a1,`public.get_mind_map_editor('${activity}')`));
  if(editor.mindMap.id!==next.mindMap.id||!editor.editable)throw Error('Editor did not resolve current map');
  const component=body.nodes.find(x=>x.developmentObjectId===fixture.object_component.id);
  ok(await rpc(a1,'update_mind_map_node',{nodeId:component.id,expectedRevision:0,label:'Our team branch: unchanged by platform'}));
  deny(await rpc(a1,'create_mind_map_version',{mindMapId:next.mindMap.id,expectedDraftRevision:0,changeSummary:null}),'55000');
  ok(await rpc(a1,'save_mind_map_draft',{mindMapId:next.mindMap.id,expectedDraftRevision:0}));
  if(JSON.stringify(snapshot())!==before)throw Error('Later edits rewrote V1');
  deny(await rpc(a1,'update_mind_map_node',{nodeId:fixture.node_component.id,expectedRevision:fixture.node_component.edit_revision,label:'Historical overwrite'}),'55000');
  deny(await call(a1,`public.update_artifact_draft('${v.id}',1,'{}'::jsonb)`),'55000');
  const counts=sql(`jsonb_build_object('maps',(select count(*) from public.mind_maps where artifact_id='${m.artifact_id}'),'versions',(select count(*) from public.artifact_versions where artifact_id='${m.artifact_id}'),'pointer',(select current_version_id from public.artifacts where id='${m.artifact_id}'))`);
  if(counts.maps!==2||counts.versions!==2||counts.pointer!==null)throw Error('Duplicate/pointer mutation');
  for(const actor of [master,'00000000-0000-4000-8000-000000006007']){
   const rows=ok(await call(actor,`jsonb_build_object('artifacts',(select count(*) from public.artifacts where id='${m.artifact_id}'),'versions',(select count(*) from public.artifact_versions where artifact_id='${m.artifact_id}'))`));
   if(rows.artifacts!==0||rows.versions!==0)throw Error('Private history leaked');
   deny(await call(actor,`public.get_mind_map_editor('${activity}')`));
  }
  const otherArtifact=ok(await call(a1,`(select to_jsonb(id) from public.artifacts where artifact_type<>'MIND_MAP' order by id limit 1)`));
  if(!otherArtifact)throw Error('Other-Artifact privacy fixture missing');
  const helper=ok(await call(a1,`jsonb_build_object('other',public.can_read_private_mind_map('${otherArtifact}'),'missing',public.can_read_private_mind_map('00000000-0000-4000-8000-000000999999'),'own',public.can_read_private_mind_map('${m.artifact_id}'),'otherVersions',(select count(*) from public.artifact_versions where artifact_id='${otherArtifact}'))`));
  if(helper.other!==false||helper.missing!==false||helper.own!==true||helper.otherVersions<1)throw Error('Helper leaks existence or changes M8 parent reads');
  deny(await rpc('','create_mind_map_version',input),'28000');
  if(!sql(`(select to_jsonb(prosecdef and proconfig @> array['search_path=""']) from pg_proc where oid='public.create_mind_map_version(jsonb)'::regprocedure)`))throw Error('Unsafe definer');
  if(sql(`to_jsonb(has_function_privilege('anon','public.create_mind_map_version(jsonb)','execute') or has_function_privilege('service_role','public.create_mind_map_version(jsonb)','execute'))`))throw Error('Excess grant');
  const state=()=>JSON.stringify(sql(`jsonb_build_object('maps',(select jsonb_agg(to_jsonb(x) order by id) from public.mind_maps x),'nodes',(select jsonb_agg(to_jsonb(x) order by id) from public.mind_map_nodes x),'edges',(select jsonb_agg(to_jsonb(x) order by id) from public.mind_map_edges x),'versions',(select jsonb_agg(to_jsonb(x) order by id) from public.artifact_versions x),'links',(select jsonb_agg(to_jsonb(x) order by id) from public.artifact_object_links x),'logs',(select jsonb_agg(to_jsonb(x) order by id) from public.change_log x))`));
  const preFailure=state();
  write(`create function public.fail_checkpoint_test() returns trigger language plpgsql as $$begin raise exception 'forced checkpoint failure' using errcode='P0001';end$$;create constraint trigger checkpoint_rollback_test after insert on public.mind_map_edges deferrable initially deferred for each row execute function public.fail_checkpoint_test();`);
  deny(await rpc(a2,'create_mind_map_version',{mindMapId:next.mindMap.id,expectedDraftRevision:1,changeSummary:null}),'P0001');
  if(state()!==preFailure)throw Error('Deferred failure left partial checkpoint');
  write('drop trigger checkpoint_rollback_test on public.mind_map_edges;drop function public.fail_checkpoint_test();');
  ok(await call(master,`public.remove_team_member('${scope.teamId}','${a1}')`));
  deny(await rpc(a1,'create_mind_map_version',{mindMapId:next.mindMap.id,expectedDraftRevision:1,changeSummary:null}));
  // Existing effective Version stays CURRENT while another Draft checkpoint is created.
  write(`update public.artifact_versions set status='CURRENT',approved_by='${master}',approved_at=clock_timestamp() where id='${v.id}';update public.artifacts set current_version_id='${v.id}' where id='${m.artifact_id}';`);
  const currentBefore=JSON.stringify(snapshot());
  const third=ok(await rpc(a2,'create_mind_map_version',{mindMapId:next.mindMap.id,expectedDraftRevision:1,changeSummary:'Next team checkpoint'}));
  if(third.version.version_number!==3||third.version.previous_version_id!==next.version.id||third.version.status!=='DRAFT')throw Error('Third lineage invalid');
  if(JSON.stringify(snapshot())!==currentBefore||sql(`(select to_jsonb(current_version_id) from public.artifacts where id='${m.artifact_id}')`)!==v.id)throw Error('Effective Version/current pointer changed');
  console.log('M11.15 V1 preservation / V2 M8 lineage / canonical graph / stable Objects / CAS race / TeamB / Master / removed / current editor PASS');
 }finally{run('psql',[...args,'-c',`drop database ${name} with (force)`]);}
}
