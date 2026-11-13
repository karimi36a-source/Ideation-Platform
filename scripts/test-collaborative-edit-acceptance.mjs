import {spawn,spawnSync} from 'node:child_process';

// Test-only synchronization: an exclusive advisory lock holds every contender
// until pg_stat_activity proves they are waiting. Shared transaction locks then
// release together; production operations retain their own locking/CAS model.
export async function testCollaborativeEditAcceptance({run,args,binary,childEnv,root}){
 const name='fici_collaborative_edit_acceptance';
 run('psql',[...args,'-c',`create database ${name} template postgres`]);
 const db=args.map((v,i)=>args[i-1]==='-d'?name:v);
 const a1='00000000-0000-4000-8000-000000006004',a2='00000000-0000-4000-8000-000000006005',b1='00000000-0000-4000-8000-000000006007',master='00000000-0000-4000-8000-000000006002';
 const sql=x=>JSON.parse(run('psql',[...db,'-tA','-c',`select (${x})::text`]).trim());
 const quote=x=>JSON.stringify(x).replaceAll("'","''");
 let serial=0;
 const call=(actor,expression,barrier=null,before='')=>new Promise((resolve,reject)=>{
  const child=spawn(binary('psql'),[...db,'--set=VERBOSITY=verbose','-tA','-f','-'],{cwd:root,env:childEnv,windowsHide:true});let out='',err='';
  const timer=setTimeout(()=>{child.kill();reject(Error('Collaborative edit operation timeout'));},60000);
  child.stdout.on('data',x=>out+=x);child.stderr.on('data',x=>err+=x);
  child.on('error',e=>{clearTimeout(timer);reject(e);});
  child.on('close',code=>{clearTimeout(timer);if(code){const state=err.match(/ERROR:\s+([0-9A-Z]{5}):/);return state?resolve({code:state[1]}):reject(Error(err));}
   const line=out.split(/\r?\n/).find(x=>x.startsWith('RESULT='));if(!line)return reject(Error('Missing canonical result'));resolve({code:'00000',data:JSON.parse(line.slice(7))});});
  child.stdin.end(`begin;set local statement_timeout='50s';set local role authenticated;select set_config('request.jwt.claim.sub','${actor}',true);
   ${barrier?`set local application_name='${barrier.tag}';select pg_advisory_xact_lock_shared(${barrier.key});`:''}
   ${before}select 'RESULT='||(${expression})::text;commit;`);
 });
 const expression=(fn,input)=>`public.${fn}('${quote(input)}'::jsonb)`;
 const rpc=(actor,fn,input)=>call(actor,expression(fn,input));
 const ok=x=>{if(x.code!=='00000')throw Error('Unexpected SQLSTATE '+x.code);return x.data;};
 const deny=(x,code='42501')=>{if(x.code!==code||x.data!==undefined)throw Error('Expected '+code+' received '+x.code);};
 const race=async operations=>{
  const gate={key:1123000+(++serial),tag:'m1123_gate_'+serial};
  const controller=spawn(binary('psql'),[...db,'-tA','-f','-'],{cwd:root,env:childEnv,windowsHide:true});
  const timer=setTimeout(()=>controller.kill(),60000);
  let ready='',errors='';const finished=new Promise((resolve,reject)=>{controller.on('error',reject);controller.on('close',code=>{clearTimeout(timer);if(code)reject(Error(errors||'Barrier coordinator failed'));else resolve();});});
  finished.catch(()=>{});
  controller.stderr.on('data',x=>errors+=x);
  const acquired=new Promise((resolve,reject)=>{controller.stdout.on('data',x=>{ready+=x;if(ready.includes('GATE_READY'))resolve();});controller.on('error',reject);controller.on('close',()=>{if(!ready.includes('GATE_READY'))reject(Error('Barrier closed before acquisition'));});});
  controller.stdin.write(`select pg_advisory_lock(${gate.key});select 'GATE_READY';\n`);
  let pending=[];
  try{
   await acquired;
   pending=operations.map(([actor,fn,input,before])=>call(actor,fn?expression(fn,input):"'true'::jsonb",gate,before));
   // Attach immediately: an early infrastructure rejection must not become an
   // unhandled rejection while the coordinator verifies the remaining waiters.
   const results=Promise.all(pending);results.catch(()=>{});
   const deadline=Date.now()+45000;
   while(sql(`(select count(*) from pg_stat_activity where application_name='${gate.tag}' and wait_event='advisory')`)!==operations.length){
    if(Date.now()>deadline)throw Error('Contenders did not reach database barrier');
    await new Promise(resolve=>setImmediate(resolve));
   }
   controller.stdin.end(`select pg_advisory_unlock(${gate.key});\n`);
   await finished;return await results;
  }finally{
   if(!controller.stdin.writableEnded)controller.stdin.end(`select pg_advisory_unlock(${gate.key});\n`);
   await Promise.allSettled(pending);await finished;
  }
 };
 try{
  const generated=spawnSync(process.execPath,['scripts/mind-map-browser-fixture.mjs'],{cwd:root,encoding:'utf8',windowsHide:true});
  if(generated.status!==0)throw Error('Mind Map acceptance fixture unavailable');
  run('psql',[...db,'-f','-'],generated.stdout.split('update auth.users set')[0]+'commit;');
  const f=sql('(select jsonb_object_agg(key,value) from public.mind_map_browser_fixture)'),activity=f.activity.activity.id;
  const editor=async(actor=a2)=>ok(await call(actor,`public.get_mind_map_editor('${activity}')`));
  const version=id=>sql(`(select to_jsonb(v) from public.artifact_versions v where id='${id}')`);
  const history=id=>JSON.stringify(sql(`jsonb_build_object('version',(select to_jsonb(v) from public.artifact_versions v where id='${id}'),'map',(select to_jsonb(m) from public.mind_maps m where artifact_version_id='${id}'),'nodes',(select jsonb_agg(to_jsonb(n) order by n.id) from public.mind_map_nodes n join public.mind_maps m on m.id=n.mind_map_id where m.artifact_version_id='${id}'),'edges',(select jsonb_agg(to_jsonb(e) order by e.id) from public.mind_map_edges e join public.mind_maps m on m.id=e.mind_map_id where m.artifact_version_id='${id}'),'links',(select jsonb_agg(to_jsonb(l) order by l.id) from public.artifact_object_links l where artifact_version_id='${id}'))`));
  const initial=f.map;
  // Trusted M8.3 fixture composition makes link preservation non-vacuous;
  // ordinary clients still have no direct link-write permission.
  run('psql',[...db,'-c',`insert into public.artifact_object_links(artifact_id,artifact_version_id,development_object_id,sequence) values('${initial.mindMap.artifact_id}','${initial.version.id}','${f.object_component.id}',1),('${initial.mindMap.artifact_id}','${initial.version.id}','${f.object_solution.id}',2);`]);
  const links=id=>sql(`(select coalesce(jsonb_agg(development_object_id order by sequence),'[]'::jsonb) from public.artifact_object_links where artifact_version_id='${id}')`);
  ok(await rpc(a1,'save_mind_map_draft',{mindMapId:initial.mindMap.id,expectedDraftRevision:0}));
  const next=ok(await rpc(a2,'create_mind_map_version',{mindMapId:initial.mindMap.id,expectedDraftRevision:1,changeSummary:'AT-CON-001 predecessor'}));
  const frozen=history(initial.version.id),map=next.mindMap,vid=next.version.id;
  if(links(vid).length!==0)throw Error('Checkpoint unexpectedly copied Version-specific Object links');
  // M8 does not automatically inherit Version-specific composition. Populate
  // V2 separately as a trusted fixture so both historical predecessors have
  // real links to preserve; this is not a new public composition operation.
  run('psql',[...db,'-c',`insert into public.artifact_object_links(artifact_id,artifact_version_id,development_object_id,sequence) values('${map.artifact_id}','${vid}','${f.object_component.id}',1),('${map.artifact_id}','${vid}','${f.object_solution.id}',2);`]);
  let sameNodeRevision;
  for(let round=0;round<3;round++){
   const before=await editor(),n1=before.nodes.find(n=>n.development_object_id===f.object_component.id),n2=before.nodes.find(n=>n.development_object_id===f.object_solution.id);
   const a={nodeId:n1.id,expectedRevision:n1.edit_revision,positionData:{x:1000+round,y:200+round}},b={nodeId:n2.id,expectedRevision:n2.edit_revision,label:'Collaborator solution '+round,positionData:{x:2000+round,y:400+round}};
   const independent=await race([[a1,'update_mind_map_node',a],[a2,'update_mind_map_node',b],[b1,'update_mind_map_node',a],[b1,null,null,`update public.mind_map_nodes set label='Forbidden direct race' where id='${n1.id}';`]]);
   ok(independent[0]);ok(independent[1]);deny(independent[2]);deny(independent[3]);
   let fresh=await editor();const first=fresh.nodes.find(n=>n.id===n1.id),second=fresh.nodes.find(n=>n.id===n2.id);
   if(first.edit_revision!==n1.edit_revision+1||second.edit_revision!==n2.edit_revision+1||first.position_data.x!==a.positionData.x||second.position_data.x!==b.positionData.x||second.label!==b.label)throw Error('Scenario A lost independent canonical update');
   const inputs=[{nodeId:first.id,expectedRevision:first.edit_revision,positionData:{x:3000+round,y:7}},{nodeId:first.id,expectedRevision:first.edit_revision,positionData:{x:4000+round,y:9}}];
   const competing=await race([[a1,'update_mind_map_node',inputs[0]],[a2,'update_mind_map_node',inputs[1]]]);
   if(competing.filter(x=>x.code==='00000').length!==1||competing.filter(x=>x.code==='40001').length!==1)throw Error('Scenario B lacked explicit single CAS winner');
   const winner=ok(competing.find(x=>x.code==='00000'));sameNodeRevision=winner.edit_revision;
   fresh=await editor();if(sameNodeRevision!==first.edit_revision+1||JSON.stringify(fresh.nodes.find(n=>n.id===winner.id))!==JSON.stringify({...winner,product_classification:fresh.nodes.find(n=>n.id===winner.id).product_classification}))throw Error('Scenario B reload/revision invalid');
   const d=version(vid).draft_revision,input={mindMapId:map.id,expectedDraftRevision:d};
   const saved=await race([[a1,'save_mind_map_draft',input],[a2,'save_mind_map_draft',input],[b1,'save_mind_map_draft',input]]);
   deny(saved[2]);if(saved.slice(0,2).filter(x=>x.code==='00000').length!==1||saved.slice(0,2).filter(x=>x.code==='23505').length!==1)throw Error('Scenario C lacked explicit Draft conflict');
   const body=version(vid);if(body.draft_revision!==d+1||body.artifact_id!==initial.mindMap.artifact_id||body.content_snapshot.nodes.find(n=>n.id===winner.id).positionData.x!==winner.position_data.x||body.content_snapshot.nodes.find(n=>n.id===second.id).label!==b.label)throw Error('Draft lost already-committed canonical changes');
   deny(await rpc(a1,'save_mind_map_draft',{...input,nodes:before.nodes}),'22023');
   const reload=await editor();if(reload.nodes.find(n=>n.id===second.id).label!==b.label||reload.nodes.find(n=>n.id===winner.id).edit_revision!==sameNodeRevision)throw Error('Fresh canonical reload diverged');
   if(history(initial.version.id)!==frozen)throw Error('Concurrent edit rewrote historical predecessor');
  }
  console.log('M11.23 AT-CON-001 A/B/C repeated 3x / database-barrier / independent revisions / explicit node-Draft conflict / canonical save / fresh reload / TeamB PASS');
  const checkpointInput={mindMapId:map.id,expectedDraftRevision:version(vid).draft_revision,changeSummary:'Concurrent checkpoint'},predecessor=history(vid);
  const checkpoints=await race([[a1,'create_mind_map_version',checkpointInput],[a2,'create_mind_map_version',checkpointInput],[b1,'create_mind_map_version',checkpointInput]]);
  deny(checkpoints[2]);if(checkpoints.slice(0,2).filter(x=>x.code==='00000').length!==1||checkpoints.slice(0,2).filter(x=>x.code==='55000').length!==1)throw Error('Checkpoint race lacked valid winner/historical conflict');
  const third=ok(checkpoints.find(x=>x.code==='00000'));
  if(third.version.version_number!==3||third.version.previous_version_id!==vid||third.version.status!=='DRAFT'||history(vid)!==predecessor||history(initial.version.id)!==frozen)throw Error('Checkpoint lineage/history corrupted');
  if(sql(`(select count(*) from public.artifact_versions where artifact_id='${map.artifact_id}')`)!==3)throw Error('Duplicate successor Version');
  if(links(third.version.id).length!==0||sql(`(select count(*) from public.artifact_object_links where artifact_id='${map.artifact_id}')`)!==4)throw Error('Checkpoint race created partial or unexpected Artifact/Object links');
  let view=await editor(),n=view.nodes.find(n=>n.development_object_id===f.object_component.id);
  const twin=ok(await rpc(a1,'add_mind_map_node',{mindMapId:third.mindMap.id,nodeType:'COMPONENT',label:'Second C1 view',developmentObjectId:f.object_component.id,positionData:{x:300,y:300}}));
  const objectRevision=sql(`(select classification_revision from public.development_objects where id='${f.object_component.id}')`);
  const classifications=await race([[a1,'classify_mind_map_node',{nodeId:n.id,expectedRevision:n.edit_revision,expectedObjectRevision:objectRevision,classification:'CORE'}],[a2,'classify_mind_map_node',{nodeId:twin.id,expectedRevision:twin.edit_revision,expectedObjectRevision:objectRevision,classification:'SUPPORTING'}]]);
  if(classifications.filter(x=>x.code==='00000').length!==1||classifications.filter(x=>x.code==='40001').length!==1)throw Error('Classification race lost canonical Object CAS');
  const object=sql(`(select to_jsonb(o) from public.development_objects o where id='${f.object_component.id}')`);view=await editor();
  if(object.classification_revision!==objectRevision+1||view.nodes.filter(x=>x.development_object_id===object.id).some(x=>x.product_classification!==object.product_classification)||history(vid)!==predecessor||history(initial.version.id)!==frozen)throw Error('Classification split-brain/history rewrite');
  if(sql(`(select count(*) from public.mind_map_nodes n left join public.mind_map_nodes p on p.id=n.parent_node_id where n.parent_node_id is not null and (p.id is null or p.mind_map_id<>n.mind_map_id))+(select count(*) from public.mind_map_edges e left join public.mind_map_nodes s on s.id=e.source_node_id left join public.mind_map_nodes t on t.id=e.target_node_id where s.id is null or t.id is null or s.mind_map_id<>e.mind_map_id or t.mind_map_id<>e.mind_map_id)`)!==0)throw Error('Race left invalid parent/edge state');
  // A removed user's previously valid revision does not confer future authority.
  n=view.nodes.find(x=>x.id===n.id);ok(await call(master,`public.remove_team_member('${f.scope.teamId}','${a1}')`));
  const currentVersion=version(third.version.id),state=JSON.stringify(view);
  const revoked=await race([[a1,'update_mind_map_node',{nodeId:n.id,expectedRevision:n.edit_revision,label:'Forbidden'}],[a1,'save_mind_map_draft',{mindMapId:third.mindMap.id,expectedDraftRevision:currentVersion.draft_revision}],[a1,'create_mind_map_version',{mindMapId:third.mindMap.id,expectedDraftRevision:currentVersion.draft_revision,changeSummary:null}]]);
  revoked.forEach(x=>deny(x));if(JSON.stringify(await editor())!==state||JSON.stringify(version(third.version.id))!==JSON.stringify(currentVersion))throw Error('Removed member changed canonical state');
  for(const actor of [a1,b1]){
   const rows=ok(await call(actor,`jsonb_build_object('nodes',(select count(*) from public.mind_map_nodes where id='${n.id}'))`));
   if(rows.nodes!==0)throw Error('Exact-ID RLS leak after concurrency');
   deny(await call(actor,"'true'::jsonb",null,`update public.mind_map_nodes set label='Forbidden direct write' where id='${n.id}';`));
  }
  console.log('M11.23 checkpoint single successor / V1-V2 immutable / classification atomic CAS / removed stale tokens / no deadlock or partial state PASS');
  console.log('M11.23 final same-node revision='+sameNodeRevision);
 }finally{run('psql',[...args,'-c',`drop database ${name} with(force)`]);}
}
