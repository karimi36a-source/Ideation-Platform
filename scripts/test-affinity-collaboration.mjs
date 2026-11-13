import {spawn,spawnSync} from "node:child_process";
import {writeFileSync,unlinkSync} from "node:fs";
import {join} from "node:path";
import {tmpdir} from "node:os";
import {affinityItemFixture} from "./affinity-item-fixture.mjs";

export async function testAffinityCollaboration({run,args,binary,childEnv,root}) {
 const name="fici_affinity_collaboration";
 run("psql",[...args,"-c",`create database ${name} template postgres`]);
 const db=args.map((v,i)=>args[i-1]==="-d"?name:v);
 const actors=['00000000-0000-4000-8000-000000006004','00000000-0000-4000-8000-000000006005'];
 const b='00000000-0000-4000-8000-000000006007';
 const master='00000000-0000-4000-8000-000000006002';
 const call=(actor,expression,before="")=>new Promise((resolve,reject)=>{
  const child=spawn(binary("psql"),[...db,"--set=VERBOSITY=verbose","-t","-A","-f","-"],{cwd:root,env:childEnv,windowsHide:true});let out="",err="";
  const timer=setTimeout(()=>{child.kill();reject(new Error("Affinity collaboration timeout"));},60000);
  child.stdout.on("data",x=>out+=x);child.stderr.on("data",x=>err+=x);
  child.on("error",e=>{clearTimeout(timer);reject(e);});
  child.on("close",code=>{clearTimeout(timer);if(code!==0){const state=err.match(/ERROR:\s+([0-9A-Z]{5}):/);if(!state)return reject(new Error("Unclassified collaboration SQL failure"));return resolve({code:state[1]});}const line=out.split(/\r?\n/).find(x=>x.startsWith("RESULT="));if(!line)return reject(new Error("Missing collaboration result"));resolve({code:"00000",data:JSON.parse(line.slice(7))});});
  child.stdin.end(`begin;set local statement_timeout='50s';set local role authenticated;select set_config('request.jwt.claim.sub','${actor}',true);${before}select 'RESULT='||(${expression})::text;select pg_sleep(0.15);commit;`);
 });
 const rpc=(actor,operation,input)=>call(actor,`public.${operation}('${JSON.stringify(input)}'::jsonb)`);
 const ok=x=>{if(x.code!=="00000")throw new Error(`Unexpected SQLSTATE ${x.code}`);return x.data;};
 const deny=(x,code="42501")=>{if(x.code!==code||x.data!==undefined)throw new Error("Expected safe rejection "+code+" received "+x.code);};
 const sql=expression=>JSON.parse(run("psql",[...db,"-t","-A","-c",`select (${expression})::text;`]).trim());
 try {
  const setup=run("psql",[...db,"-t","-A","-f","-"],affinityItemFixture(root)+`
   set local role authenticated;select set_config('request.jwt.claim.sub','${actors[1]}',true);
   insert into ai_groups select 'Third',public.create_affinity_group(jsonb_build_object('activityInstanceId',id,'name','Third')) from af_activities where label='Team';
   select public.reveal_brainstorm_entries((select id from ai_sources where label='Brainstorm Activity'),array[(select id from ai_sources where label='Team Entry'),(select id from ai_sources where label='Peer Entry')]);
   insert into ai_sources select kind||'2',(public.create_development_object((payload->>'id')::uuid,(payload->>'primary_workspace_id')::uuid,kind::public.development_object_type,'Acceptance '||kind||'2','Canonical acceptance source',null)->>'id')::uuid from logged_projects cross join unnest(array['PROBLEM','SOLUTION']) kind where label='Team';
   reset role;
   select 'TARGET='||jsonb_build_object('a',(select id from af_activities where label='Team'),'team',(select payload->>'teamId' from acceptance_teams where label='A'),'g1',(select payload->>'id' from ai_groups where label='Team'),'g2',(select payload->>'id' from ai_groups where label='Second'),'g3',(select payload->>'id' from ai_groups where label='Third'),'o1',(select id from ai_sources where label='PROBLEM'),'o2',(select id from ai_sources where label='SOLUTION'),'o3',(select id from ai_sources where label='PROBLEM2'),'o4',(select id from ai_sources where label='SOLUTION2'),'entry',(select id from ai_sources where label='Peer Entry'))::text;commit;`);
  const t=JSON.parse(setup.split(/\r?\n/).find(x=>x.startsWith('TARGET=')).slice(7));
  for(const id of Object.values(t))if(!/^[a-f0-9-]{36}$/.test(id))throw new Error("Invalid fixture identity");
  if(process.argv.includes('--liveblocks')) {
   const fixtureFile=join(tmpdir(),`fici-liveblocks-${process.pid}.json`);
   writeFileSync(fixtureFile,JSON.stringify({...t,args:db,binary:binary('psql')}));
   try {
    const result=spawnSync(process.execPath,['node_modules/vitest/vitest.mjs','run','--config','vitest.liveblocks.config.mts'],{cwd:root,env:{...childEnv,FICI_LIVEBLOCKS_FIXTURE:fixtureFile},encoding:'utf8',windowsHide:true,timeout:150000});
    // Never forward provider errors/tokens from test output; only fixed success markers.
    if(result.status!==0||result.error){
     process.loadEnvFile(join(root,'.env.local'));
     const secret=process.env.LIVEBLOCKS_SECRET_KEY;
     let diagnostic=(result.stdout??'')+(result.stderr??'');
     if(secret)for(const value of [secret,encodeURIComponent(secret)])diagnostic=diagnostic.split(value).join('[REDACTED]');
     diagnostic=diagnostic.replace(/eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+/g,'[REDACTED TOKEN]');
     writeFileSync(join(tmpdir(),'fici-liveblocks-sanitized.log'),diagnostic);
     throw new Error('Liveblocks provider verification failed; inspect sanitized local diagnostics');
    }
    console.log('M11.4 real-provider isolated room/auth/events/CAS/removal/failure PASS');
    console.log('M11.4 existing open session not immediately revoked; new auth denied');
   } finally {unlinkSync(fixtureFile);}
   return;
  }
  const board=actor=>call(actor,`public.get_affinity_collaboration_board('${t.a}')`);
  const preserve=()=>sql(`jsonb_build_object('objects',(select jsonb_agg(to_jsonb(x) order by id) from public.development_objects x),'brainstorm',(select jsonb_agg(to_jsonb(x) order by id) from public.brainstorm_entries x),'activities',(select jsonb_agg(to_jsonb(x) order by id) from public.activity_instances x),'baselines',(select jsonb_agg(to_jsonb(x) order by id) from public.project_baseline_items x))`);
  const sources=JSON.stringify(preserve());
  const objectCounts=()=>sql(`(select jsonb_object_agg(kind,n) from (select object_type::text kind,count(*) n from public.development_objects where project_id=(select project_id from public.development_objects where id='${t.o1}') and object_type in ('PROBLEM','SOLUTION') group by object_type) c)`);
  const countsBefore=objectCounts();
  const relationshipsBefore=sql(`(select coalesce(jsonb_agg(to_jsonb(r) order by id),'[]') from public.development_object_relationships r)`);
  let x=ok(await rpc(actors[0],'add_affinity_item',{affinityGroupId:t.g1,developmentObjectId:t.o1}));
  let y=ok(await rpc(actors[1],'add_affinity_item',{affinityGroupId:t.g1,developmentObjectId:t.o2}));
  const p2=ok(await rpc(actors[0],'add_affinity_item',{affinityGroupId:t.g1,developmentObjectId:t.o3}));
  const s2=ok(await rpc(actors[1],'add_affinity_item',{affinityGroupId:t.g1,developmentObjectId:t.o4}));
  const initial=[x,y,p2,s2];
  if(new Set(initial.map(i=>i.development_object_id)).size!==4)throw new Error('Acceptance sources not distinct');
  const move=(actor,item,g,position)=>rpc(actor,'move_affinity_item',{itemId:item.id,targetGroupId:g,position,expectedRevision:item.move_revision});
  const reload=async()=>{
   // Each call starts a fresh PostgreSQL connection after the original movers exited.
   const a=ok(await board(actors[0])),c=ok(await board(actors[1]));
   if(JSON.stringify(a)!==JSON.stringify(c)||a.roomId!==`affinity:${t.a}`)throw new Error("Reconnect divergence");
   if(a.items.length!==4||new Set(a.items.map(i=>i.id)).size!==4)throw new Error("Duplicate/lost item");
   for(const g of a.groups){const items=a.items.filter(i=>i.affinity_group_id===g.id);if(items.some((i,n)=>i.position!==n+1))throw new Error("Corrupt order");}
   for(const i of a.items){const origin=initial.find(v=>v.id===i.id);if(!origin||i.development_object_id!==origin.development_object_id)throw new Error("Source changed");}
   return a;
  };
  ok(await board(actors[0]));ok(await board(actors[1]));
  for(const actor of [b,'00000000-0000-4000-8000-000000006001','00000000-0000-4000-8000-000000006003','00000000-0000-4000-8000-000000006006',''])deny(await board(actor),actor?'42501':'28000');
  [x,y]=await Promise.all([move(actors[0],x,t.g2,1),move(actors[1],y,t.g3,1)]).then(v=>v.map(ok));
  let saved=await reload();if(saved.items.find(i=>i.id===x.id).affinity_group_id!==t.g2||saved.items.find(i=>i.id===y.id).affinity_group_id!==t.g3)throw new Error("Non-conflicting move lost");
  [x,y]=await Promise.all([move(actors[0],x,t.g1,1),move(actors[1],y,t.g1,1)]).then(v=>v.map(ok));await reload();
  // Same target/position from same source: both accepted, serialized canonical order.
  [x,y]=await Promise.all([move(actors[0],x,t.g2,1),move(actors[1],y,t.g2,1)]).then(v=>v.map(ok));await reload();
  // Same target/different positions, with stale sibling positions but fresh own revisions.
  [x,y]=await Promise.all([move(actors[0],x,t.g2,2),move(actors[1],y,t.g2,1)]).then(v=>v.map(ok));await reload();
  const stale={...x};
  const contenders=await Promise.all([move(actors[0],stale,t.g2,1),move(actors[1],stale,t.g3,1)]);
  if(contenders.filter(v=>v.code==='00000').length!==1||contenders.filter(v=>v.code==='40001').length!==1)throw new Error("Same-item CAS did not conflict");
  x=ok(contenders.find(v=>v.code==='00000'));saved=await reload();
  if(saved.items.find(i=>i.id===x.id).affinity_group_id!==x.affinity_group_id)throw new Error("Winner overwritten");
  // ABA: returning to former position cannot make old intent valid again.
  x=ok(await move(actors[0],x,stale.affinity_group_id,stale.position));deny(await move(actors[1],stale,t.g2,1),'40001');await reload();
  deny(await rpc(actors[0],'move_affinity_item',{itemId:x.id,targetGroupId:t.g2,position:1}),'22023');
  const before=JSON.stringify(await reload());
  const attack=await Promise.all([move(b,x,t.g2,1),move(actors[1],y,t.g3,1)]);deny(attack[0]);y=ok(attack[1]);await reload();
  // Forced save failure after position shifts: whole transaction, including revision, rolls back.
  run('psql',[...db,'-c',`create function public.affinity_fault_fixture() returns trigger language plpgsql as $$begin if new.move_revision<>old.move_revision then raise exception 'fixture failure' using errcode='ZX114';end if;return new;end $$;create trigger affinity_fault_fixture after update on public.affinity_group_items for each row execute function public.affinity_fault_fixture();`]);
  const rollbackBefore=JSON.stringify(await reload());deny(await move(actors[0],x,t.g3,1),'ZX114');if(JSON.stringify(await reload())!==rollbackBefore)throw new Error("Partial save remained");
  run('psql',[...db,'-c','drop trigger affinity_fault_fixture on public.affinity_group_items;drop function public.affinity_fault_fixture();']);
  if(!before||JSON.stringify(preserve())!==sources)throw new Error("Canonical sources mutated");
  for(const actor of [actors[0],b]){
   // M11.19 permits canonical scoped reads; exact Team A IDs still deny Team B.
   const rows=ok(await call(actor,`(select coalesce(jsonb_agg(i),'[]'::jsonb) from public.affinity_group_items i where affinity_group_id in ('${t.g1}','${t.g2}','${t.g3}'))`));
   const expected=actor===actors[0]?(await reload()).items.map(i=>i.id).sort():[];
   if(JSON.stringify(rows.map(i=>i.id).sort())!==JSON.stringify(expected))throw new Error('Affinity scoped read mismatch');
   deny(await call(actor,`'null'::jsonb`, 'update public.affinity_group_items set move_revision=0;'));
  }
  for(const table of ['affinity_groups','affinity_group_items']){
   const predicate=table==='affinity_groups'?`activity_instance_id='${t.a}'`:`affinity_group_id in ('${t.g1}','${t.g2}','${t.g3}')`;
   if(ok(await call(b,`(select coalesce(jsonb_agg(t),'[]') from public.${table} t where ${predicate})`)).length)throw new Error('Team B source enumeration');
  }
  deny(await rpc(b,'add_affinity_item',{affinityGroupId:t.g1,developmentObjectId:t.o1}));
  if(JSON.stringify(objectCounts())!==JSON.stringify(countsBefore))throw new Error('Grouping duplicated canonical Objects');
  if(JSON.stringify(sql('(select coalesce(jsonb_agg(to_jsonb(r) order by id),\'[]\') from public.development_object_relationships r)'))!==JSON.stringify(relationshipsBefore))throw new Error('Grouping created canonical relationships');
  console.log('M11.21 AT-AFF-001 P1-P2-S1-S2 / stable IDs / full source preservation / unchanged counts / no relationships / scoped TeamB denial PASS');
  console.log('M1121_OBJECT_COUNTS='+JSON.stringify({before:countsBefore,after:objectCounts()}));
  // No direct-client revision/ownership/source update access.
  const update=await call(actors[0],`public.move_affinity_item('${JSON.stringify({itemId:x.id,targetGroupId:t.g2,position:1,expectedRevision:x.move_revision,addedBy:actors[1]})}'::jsonb)`);deny(update,'22023');
  const history=sql(`(select jsonb_agg(to_jsonb(i) order by id) from public.affinity_group_items i)`);
  ok(await call(master,`public.remove_team_member('${t.team}','${actors[0]}',null)`));
  deny(await board(actors[0]));deny(await move(actors[0],x,t.g2,1));
  deny(await rpc(actors[0],'add_affinity_item',{affinityGroupId:t.g1,developmentObjectId:t.o1}));
  deny(await rpc(actors[0],'rename_affinity_group',{affinityGroupId:t.g1,name:'Removed edit'}));
  if(JSON.stringify(history)!==JSON.stringify(sql(`(select jsonb_agg(to_jsonb(i) order by id) from public.affinity_group_items i)`)))throw new Error("Removal rewrote history");
  ok(await board(actors[1]));
  console.log('M11.21 AT-AFF-002 two-users / both moves survive / one CAS winner / fresh-session reload / rollback / removed read-add-move-rename denial / preserved attribution PASS');
  console.log('M11.4 AT-AFF-002 real-session different-item/same-item CAS/ABA/order/reconnect/rollback/source privacy/removal PASS');
  console.log('M11.4 provider-live delivery DEFERRED: Liveblocks adapter/credentials absent; no socket/event isolation PASS claimed');
 } finally {run('psql',[...args,'-c',`drop database ${name} with(force)`]);}
}
