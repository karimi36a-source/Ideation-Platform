import {spawn} from "node:child_process";
import {affinityItemFixture} from "./affinity-item-fixture.mjs";

export async function testGapCapture({run,args,binary,childEnv,root}) {
 const name="fici_gap_capture";
 run("psql",[...args,"-c",`create database ${name} template postgres`]);
 const db=args.map((v,i)=>args[i-1]==="-d"?name:v);
 const actors=['00000000-0000-4000-8000-000000006004','00000000-0000-4000-8000-000000006005'];
 const b='00000000-0000-4000-8000-000000006007';
 const master='00000000-0000-4000-8000-000000006002';
 const call=(actor,expression,before="")=>new Promise((resolve,reject)=>{
  const child=spawn(binary("psql"),[...db,"--set=VERBOSITY=verbose","-t","-A","-f","-"],{cwd:root,env:childEnv,windowsHide:true});let out="",err="";
  const timer=setTimeout(()=>{child.kill();reject(new Error("Gap capture timeout"));},60000);
  child.stdout.on("data",x=>out+=x);child.stderr.on("data",x=>err+=x);
  child.on("error",e=>{clearTimeout(timer);reject(e);});
  child.on("close",code=>{clearTimeout(timer);if(code!==0){const state=err.match(/ERROR:\s+([0-9A-Z]{5}):/);if(!state)return reject(new Error("Unclassified Gap capture SQL failure"));return resolve({code:state[1]});}const line=out.split(/\r?\n/).find(x=>x.startsWith("RESULT="));if(!line)return reject(new Error("Missing Gap capture result"));resolve({code:"00000",data:JSON.parse(line.slice(7))});});
  child.stdin.end(`begin;set local statement_timeout='50s';set local role authenticated;select set_config('request.jwt.claim.sub','${actor}',true);${before}select 'RESULT='||(${expression})::text;select pg_sleep(0.15);commit;`);
 });
 const rpc=(actor,operation,input)=>call(actor,`public.${operation}('${JSON.stringify(input)}'::jsonb)`);
 const ok=x=>{if(x.code!=="00000")throw new Error(`Unexpected SQLSTATE ${x.code}`);return x.data;};
 const deny=(x,code="42501")=>{if(x.code!==code||x.data!==undefined)throw new Error("Expected safe rejection "+code+" received "+x.code);};
 const sql=expression=>JSON.parse(run("psql",[...db,"-t","-A","-c",`select (${expression})::text;`]).trim());
 try {
  const fixture=affinityItemFixture(root).replace("update public.curriculum_versions set status='approved'",`update public.activity_definitions set configuration='{"outputs":{"artifact_types":["GAP_LIST"]}}',requires_review=true,requires_approval=true where id='00000000-0000-4000-8000-000001113803';update public.curriculum_versions set status='approved'`);
  const setup=run('psql',[...db,'-t','-A','-f','-'],fixture+`
   set local role authenticated;select set_config('request.jwt.claim.sub','${actors[0]}',true);
   insert into ai_sources select 'COMPONENT',(public.create_development_object((payload->>'id')::uuid,(payload->>'primary_workspace_id')::uuid,'COMPONENT','Earlier C1','Preserved Component','USER')->>'id')::uuid from logged_projects where label='Team';
   insert into ai_sources select gap_label,(public.create_development_object((payload->>'id')::uuid,(payload->>'primary_workspace_id')::uuid,'GAP',gap_label,'Earlier canonical Gap','USER','{"earlier":true}')->>'id')::uuid from logged_projects cross join unnest(array['G3','G4','G5','G6']) as gaps(gap_label) where logged_projects.label='Team';
   reset role;
   select 'TARGET='||jsonb_build_object('a',(select id from af_activities where label='Team'),'personal',(select id from af_activities where label='Personal'),'team',(select payload->>'teamId' from acceptance_teams where label='A'),'c',(select id from ai_sources where label='COMPONENT'),'g3',(select id from ai_sources where label='G3'),'g4',(select id from ai_sources where label='G4'),'g5',(select id from ai_sources where label='G5'),'g6',(select id from ai_sources where label='G6'),'configured',(select id from ai_sources where label='Other Activity'),'foreign',(select id from ai_sources where label='Team B Object'),'problem',(select id from ai_sources where label='PROBLEM'))::text;commit;`);
  const t=JSON.parse(setup.split(/\r?\n/).find(x=>x.startsWith('TARGET=')).slice(7));
  const capture=(actor,x)=>rpc(actor,'capture_gap',x);
  const create=(key,title=key,activity=t.a)=>({activityInstanceId:activity,mode:'CREATE_NEW',newGap:{title},idempotencyKey:key});
  const add=(id,key,activity=t.a)=>({activityInstanceId:activity,mode:'ADD_EXISTING',gapObjectId:id,idempotencyKey:key});
  const objects=()=>sql(`(select jsonb_agg(to_jsonb(o) order by id) from public.development_objects o)`);
  const count=(table,where='true')=>sql(`(select count(*) from ${table} where ${where})`);
  const members=version=>sql(`(select coalesce(jsonb_agg(development_object_id order by sequence),'[]') from public.artifact_object_links where artifact_version_id='${version}')`);
  const versionRow=id=>sql(`(select to_jsonb(v) from public.artifact_versions v where id='${id}')`);
  const sourceBefore=objects();const baselineBefore=sql(`(select coalesce(jsonb_agg(to_jsonb(x)),'[]') from public.project_baseline_items x)`);
  const firstInput={...create('g1'),relationships:[{sourceObjectId:'CONFIRMED_OBJECT',targetObjectId:t.c,relationshipType:'IDENTIFIED_IN'}]};
  const first=ok(await capture(actors[0],firstInput));
  if(first.gap.object_type!=='GAP'||first.gap.origin_reference_id!==t.a||first.gap.origin_type!=='GAP_CAPTURE'||first.gap.created_by!==actors[0]||first.gap.metadata.sourceActivityInstanceId!==t.a||first.version.version_number!==1||first.version.status!=='DRAFT'||first.artifact.artifact_type!=='GAP_LIST'||first.artifact.current_version_id!==null||first.activityOutputId!==null||!first.membershipChanged||first.relationshipIds.length!==1)throw Error('Invalid G1 composition');
  console.log('GAP_CAPTURE_RESULT='+JSON.stringify(first));
  const retry=ok(await capture(actors[0],firstInput));if(!retry.replayed||retry.gap.id!==first.gap.id||retry.version.id!==first.version.id)throw Error('Duplicate retry');
  deny(await capture(actors[0],{...firstInput,newGap:{title:'Different intent'}}),'23505');
  const v1=JSON.stringify(versionRow(first.version.id)),l1=JSON.stringify(members(first.version.id));
  const second=ok(await capture(actors[0],create('g2')));
  const v2=JSON.stringify(versionRow(second.version.id)),l2=JSON.stringify(members(second.version.id));
  const priorGap=sql(`(select to_jsonb(o) from public.development_objects o where id='${t.g3}')`);
  const third=ok(await capture(actors[0],add(t.g3,'g3')));
  if(new Set([first.artifact.id,second.artifact.id,third.artifact.id]).size!==1||JSON.stringify(members(first.version.id))!==JSON.stringify([first.gap.id])||JSON.stringify(members(second.version.id))!==JSON.stringify([first.gap.id,second.gap.id])||JSON.stringify(members(third.version.id))!==JSON.stringify([first.gap.id,second.gap.id,t.g3]))throw Error('Non-cumulative list');
  if(JSON.stringify(third.gap)!==JSON.stringify(priorGap)||JSON.stringify(versionRow(first.version.id))!==v1||JSON.stringify(versionRow(second.version.id))!==v2||JSON.stringify(members(first.version.id))!==l1||JSON.stringify(members(second.version.id))!==l2)throw Error('History/provenance overwritten');
  const versionsBefore=count('public.artifact_versions',`artifact_id='${first.artifact.id}'`);
  const noop=ok(await capture(actors[0],add(t.g3,'g3-noop')));
  if(noop.membershipChanged||noop.version.id!==third.version.id||count('public.artifact_versions',`artifact_id='${first.artifact.id}'`)!==versionsBefore)throw Error('No-op Version duplicate');
  const relationshipsOnly=ok(await capture(actors[0],{...add(t.g3,'edge-only'),relationships:[{sourceObjectId:'CONFIRMED_OBJECT',targetObjectId:t.c,relationshipType:'DEPENDS_ON'}]}));
  if(relationshipsOnly.membershipChanged||relationshipsOnly.version.id!==third.version.id||relationshipsOnly.relationshipIds.length!==1||JSON.stringify(versionRow(third.version.id))!==JSON.stringify(third.version))throw Error('Relationship-only action rewrote checkpoint');
  const alias=ok(await capture(actors[0],{...add(t.g3,'edge-only'),relationships:[{sourceObjectId:t.g3,targetObjectId:t.c,relationshipType:'DEPENDS_ON'}]}));
  if(!alias.replayed||alias.relationshipIds[0]!==relationshipsOnly.relationshipIds[0])throw Error('Equivalent retry failed');
  const race=(await Promise.all([capture(actors[0],add(t.g4,'g4')),capture(actors[1],add(t.g5,'g5'))])).map(ok);
  const latest=()=>sql(`(select to_jsonb(id) from public.artifact_versions where artifact_id='${first.artifact.id}' order by version_number desc limit 1)`);
  let current=members(latest());if(current.length!==5||new Set(current).size!==5||!current.includes(t.g4)||!current.includes(t.g5)||current.slice(0,3).join()!==[first.gap.id,second.gap.id,t.g3].join())throw Error('Lost concurrent addition');
  if(!race.every(x=>x.membershipChanged))throw Error('Different Gap race lost intent');
  const sameBefore=count('public.artifact_versions',`artifact_id='${first.artifact.id}'`);
  const same=(await Promise.all([capture(actors[0],add(t.g6,'same-gap-a')),capture(actors[1],add(t.g6,'same-gap-b'))])).map(ok);
  if(same.filter(x=>x.membershipChanged).length!==1||same[0].version.id!==same[1].version.id||count('public.artifact_versions',`artifact_id='${first.artifact.id}'`)!==sameBefore+1)throw Error('Duplicate same-Gap checkpoint');
  const objectCount=count('public.development_objects'),versionCount=count('public.artifact_versions',`artifact_id='${first.artifact.id}'`);
  const sameKey=(await Promise.all([capture(actors[0],create('same-key')),capture(actors[0],create('same-key'))])).map(ok);
  if(sameKey[0].gap.id!==sameKey[1].gap.id||sameKey[0].version.id!==sameKey[1].version.id||sameKey.filter(x=>x.replayed).length!==1||count('public.development_objects')!==objectCount+1||count('public.artifact_versions',`artifact_id='${first.artifact.id}'`)!==versionCount+1)throw Error('Same-key duplicate side effects');
  current=members(latest());if(current.length!==7||new Set(current).size!==7||count('public.artifacts',`artifact_type='GAP_LIST' and activity_instance_id='${t.a}'`)!==1)throw Error('Duplicate Gap membership/Artifact');
  // A later view is only isolated test metadata, not a Mind Map entity.
  const laterView={objectId:first.gap.id,projectId:first.gap.project_id,workspaceId:first.gap.workspace_id};
  const laterObject=sql(`(select to_jsonb(o) from public.development_objects o where id='${laterView.objectId}')`);
  if(JSON.stringify(laterObject)!==JSON.stringify(first.gap)||count('public.development_objects',`id='${first.gap.id}'`)!==1||laterObject.project_id!==laterView.projectId||laterObject.workspace_id!==laterView.workspaceId)throw Error('Stable-ID view reuse failed');
  for(const row of sourceBefore)if(JSON.stringify(sql(`(select to_jsonb(o) from public.development_objects o where id='${row.id}')`))!==JSON.stringify(row))throw Error('Earlier source changed');
  const captureCounts=()=>sql(`jsonb_build_array((select count(*) from public.development_objects),(select count(*) from public.development_object_relationships),(select count(*) from public.artifacts),(select count(*) from public.artifact_versions),(select count(*) from public.artifact_object_links),(select count(*) from public.activity_outputs),(select count(*) from public.change_log),(select count(*) from private.gap_captures))`);
  // Fail at each required downstream boundary; first capture must leave nothing.
  for(const table of ['public.development_objects','public.development_object_relationships','public.artifacts','public.artifact_versions','public.artifact_object_links','public.activity_outputs','private.gap_captures']){
   run('psql',[...db,'-c',`create function private.gap_fault() returns trigger language plpgsql as $$begin raise exception 'fixture fault' using errcode='ZX116';end $$;create trigger gap_fault before insert on ${table} for each row execute function private.gap_fault();`]);
   const before=JSON.stringify(captureCounts());
   deny(await capture(actors[0],{...create('fault-'+table,'Fail safely',t.configured),relationships:[{sourceObjectId:'CONFIRMED_OBJECT',targetObjectId:t.c,relationshipType:'IDENTIFIED_IN'}]}),'ZX116');
   if(JSON.stringify(captureCounts())!==before)throw Error('Partial Gap capture at '+table);
   run('psql',[...db,'-c',`drop trigger gap_fault on ${table};drop function private.gap_fault();`]);
  }
  const configured=ok(await capture(actors[0],create('configured','Configured Gap',t.configured)));
  if(!configured.activityOutputId||!configured.artifact.review_required||!configured.artifact.approval_required||configured.version.status!=='DRAFT')throw Error('Immutable configuration/output failed');
  const submission=ok(await call(actors[1],`public.submit_artifact('${configured.artifact.id}','${configured.version.id}','${t.configured}')`));
  ok(await call(master,`public.start_review('${submission.id}')`));ok(await call(master,`public.approve_artifact('${submission.id}','Reviewed explicit Gap List')`));
  const approved=JSON.stringify(versionRow(configured.version.id)),approvedLinks=JSON.stringify(members(configured.version.id));
  const approvedNoop=ok(await capture(actors[0],{...add(configured.gap.id,'current-noop',t.configured),relationships:[{sourceObjectId:'CONFIRMED_OBJECT',targetObjectId:t.c,relationshipType:'DEPENDS_ON'}]}));
  if(approvedNoop.membershipChanged||approvedNoop.version.id!==configured.version.id||approvedNoop.version.status!=='CURRENT'||approvedNoop.relationshipIds.length!==1||JSON.stringify(versionRow(configured.version.id))!==approved||JSON.stringify(members(configured.version.id))!==approvedLinks)throw Error('Current no-op/edge action rewrote history');
  const afterApproval=ok(await capture(actors[0],create('after-approval','Next Gap',t.configured)));
  if(afterApproval.version.status!=='DRAFT'||afterApproval.version.previous_version_id!==configured.version.id||afterApproval.artifact.current_version_id!==configured.version.id||afterApproval.activityOutputId!==configured.activityOutputId||JSON.stringify(versionRow(configured.version.id))!==approved||JSON.stringify(members(configured.version.id))!==approvedLinks||members(afterApproval.version.id).join()!==[configured.gap.id,afterApproval.gap.id].join())throw Error('Approval/revision history changed');
  deny(await call(actors[0],`public.update_artifact_draft('${configured.version.id}',0,'{}',null,false)`),'55000');
  const hidden=async actor=>{
   for(const [table,predicate] of [['artifacts',`id='${first.artifact.id}'`],['artifact_versions',`id='${first.version.id}'`],['artifact_object_links',`artifact_id='${first.artifact.id}'`],['development_objects',`id='${first.gap.id}'`]])if(ok(await call(actor,`(select count(*) from public.${table} where ${predicate})`))!==0)throw Error('Exact-ID metadata leak');
   if(ok(await call(actor,`(select count(*) from public.artifacts a join public.artifact_versions v on v.artifact_id=a.id join public.artifact_object_links l on l.artifact_version_id=v.id where a.id='${first.artifact.id}')`))!==0)throw Error('Exact-ID join leak');
  };
  await hidden(b);
  for(const actor of [b,master,'00000000-0000-4000-8000-000000006001','00000000-0000-4000-8000-000000006003','']){
   deny(await capture(actor,create('spoof')),actor?'42501':'28000');deny(await capture(actor,add(first.gap.id,'claim')),actor?'42501':'28000');
  }
  for(const field of ['actor','createdBy','projectId','workspaceId','teamId','artifactId','artifactVersionId','status','baselineId','approvalStatus'])deny(await capture(actors[0],{...create('unknown'),[field]:t.a}),'22023');
  deny(await capture(actors[0],add(t.problem,'non-gap')),'22023');deny(await capture(actors[0],add(t.foreign,'foreign')));
  deny(await capture(actors[0],{...create('self'),relationships:[{sourceObjectId:'CONFIRMED_OBJECT',targetObjectId:'CONFIRMED_OBJECT',relationshipType:'DEPENDS_ON'}]}),'22023');
  deny(await capture(actors[0],{...create('foreign-edge'),relationships:[{sourceObjectId:'CONFIRMED_OBJECT',targetObjectId:t.foreign,relationshipType:'DEPENDS_ON'}]}));
  for(const table of ['public.development_objects','public.development_object_relationships','public.artifacts','public.artifact_versions','public.artifact_object_links','private.gap_captures']){
   const column=table.startsWith('private.')?'actor_id':'id';
   for(const statement of [`insert into ${table} default values;`,`delete from ${table};`,`update ${table} set ${column}=${column};`])deny(await call(actors[0],`'null'::jsonb`,statement));
  }
  const personal=ok(await capture(actors[0],create('personal','Private Gap',t.personal)));
  if(personal.gap.project_id===first.gap.project_id)throw Error('Personal scope incorrect');
  for(const actor of [actors[1],master,b])deny(await capture(actor,add(personal.gap.id,'private',t.personal)));
  deny(await capture(actors[0],add(personal.gap.id,'cross-workspace')));
  // A caller may forge a plausible empty body through the generic M8 Version
  // operation, but that must not establish a new canonical list checkpoint.
  ok(await call(actors[0],`public.create_artifact_version('${personal.artifact.id}','${JSON.stringify({activityInstanceId:t.personal,gapObjectIds:[]})}',null)`));
  const beforeUnbound=count('public.development_objects');
  deny(await capture(actors[0],create('unbound','Do not lose prior members',t.personal)),'55000');
  if(count('public.development_objects')!==beforeUnbound)throw Error('Unbound Version lost/created canonical membership');
  run('psql',[...db,'-c',`update public.activity_instances set status='completed',completed_at=clock_timestamp() where id='${t.configured}';`]);
  deny(await capture(actors[0],create('completed','No mutation',t.configured)),'55000');
  run('psql',[...db,'-c',`update public.activity_instances set status='archived' where id='${t.configured}';`]);
  deny(await capture(actors[0],create('archived','No mutation',t.configured)),'55000');
  const beforeInvalid=JSON.stringify(captureCounts());
  ok(await call(actors[0],`public.archive_development_object('${first.gap.id}')`));
  deny(await capture(actors[0],create('archived-member')));
  if(count('public.development_objects')!==JSON.parse(beforeInvalid)[0])throw Error('Archived prior member caused partial mutation');
  ok(await call(master,`public.remove_team_member('${t.team}','${actors[0]}',null)`));
  deny(await capture(actors[0],firstInput));deny(await capture(actors[0],create('removed')));await hidden(actors[0]);
  if(JSON.stringify(sql(`(select coalesce(jsonb_agg(to_jsonb(x)),'[]') from public.project_baseline_items x)`))!==JSON.stringify(baselineBefore))throw Error('Baseline changed');
  console.log('M11.6 explicit GAP/create/reuse/cumulative/history/noop/relationships/CAS-free-serialized-concurrency/retry/rollback/approval/output/privacy/AT-PROJ-002 PASS');
 } finally {run('psql',[...args,'-c',`drop database ${name} with(force)`]);}
}
