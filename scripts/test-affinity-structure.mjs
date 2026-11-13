import {spawn} from "node:child_process";
import {affinityItemFixture} from "./affinity-item-fixture.mjs";

export async function testAffinityStructure({run,args,binary,childEnv,root}) {
 const name="fici_affinity_structure";
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
  const fixture=affinityItemFixture(root).replace("update public.curriculum_versions set status='approved'",`update public.activity_definitions set configuration='{"outputs":{"artifact_types":["INVENTION_STRUCTURE"]}}',requires_review=true,requires_approval=true where id='00000000-0000-4000-8000-000001113803';update public.curriculum_versions set status='approved'`);
  const setup=run('psql',[...db,'-t','-A','-f','-'],fixture+`
   set local role authenticated;select set_config('request.jwt.claim.sub','${actors[0]}',true);
   insert into ai_sources select 'COMPONENT',(public.create_development_object((payload->>'id')::uuid,(payload->>'primary_workspace_id')::uuid,'COMPONENT','Existing C1','Original content','USER')->>'id')::uuid from logged_projects where label='Team';
   insert into ai_sources select 'PROBLEM2',(public.create_development_object((payload->>'id')::uuid,(payload->>'primary_workspace_id')::uuid,'PROBLEM','Earlier P2','Preserve P2',null)->>'id')::uuid from logged_projects where label='Team';
   insert into ai_sources select 'SOLUTION2',(public.create_development_object((payload->>'id')::uuid,(payload->>'primary_workspace_id')::uuid,'SOLUTION','Earlier S2','Preserve S2',null)->>'id')::uuid from logged_projects where label='Team';
   select public.add_affinity_item(jsonb_build_object('affinityGroupId',(select payload->>'id' from ai_groups where label='Team'),'developmentObjectId',id)) from ai_sources where label in('PROBLEM','PROBLEM2','SOLUTION','SOLUTION2','COMPONENT');
   reset role;
   select 'TARGET='||jsonb_build_object('a',(select id from af_activities where label='Team'),'team',(select payload->>'teamId' from acceptance_teams where label='A'),'g',(select payload->>'id' from ai_groups where label='Team'),'p',(select id from ai_sources where label='PROBLEM'),'s',(select id from ai_sources where label='SOLUTION'),'c',(select id from ai_sources where label='COMPONENT'),'outputActivity',(select id from ai_sources where label='Other Activity'),'outputGroup',(select payload->>'id' from ai_groups where label='Other'),'foreign',(select id from ai_sources where label='Team B Object'))::text;commit;`);
  const t=JSON.parse(setup.split(/\r?\n/).find(x=>x.startsWith('TARGET=')).slice(7));
  const snapshot=()=>sql(`jsonb_build_object('objects',(select jsonb_agg(to_jsonb(o) order by id) from public.development_objects o),'baseline',(select jsonb_agg(to_jsonb(o)) from public.project_baseline_items o),'activity',(select to_jsonb(o) from public.activity_instances o where id='${t.a}'))`);
  const before=JSON.stringify(snapshot());
  // Isolated session-context references only: no M7 execution entities or clones.
  const originalProblem=sql(`(select to_jsonb(o) from public.development_objects o where id='${t.p}')`);
  for(const sessionNumber of [4,5,6]) {
   const context={sessionNumber,objectId:t.p,projectId:originalProblem.project_id,workspaceId:originalProblem.workspace_id};
   const reloaded=sql(`(select to_jsonb(o) from public.development_objects o where id='${context.objectId}')`);
   if(JSON.stringify(reloaded)!==JSON.stringify(originalProblem)||reloaded.project_id!==context.projectId||reloaded.workspace_id!==context.workspaceId)throw Error('Session continuity lost');
  }
  const input={activityInstanceId:t.a,affinityGroupId:t.g,mode:'LINK_EXISTING',targetObjectId:t.c,idempotencyKey:'link-1',relationships:[{sourceObjectId:t.s,targetObjectId:t.p,relationshipType:'SOLVES'},{sourceObjectId:t.c,targetObjectId:t.p,relationshipType:'IDENTIFIED_IN'}]};
  const confirm=(actor,x)=>rpc(actor,'confirm_affinity_structure',x);
  const first=ok(await confirm(actors[0],input));
  if(first.resolvedDevelopmentObjectId!==t.c||first.version.status!=='DRAFT'||first.artifact.current_version_id!==null||first.activityOutputId!==null||first.relationshipIds.length!==2)throw Error('Invalid structure result');
  if(before!==JSON.stringify(snapshot()))throw Error('Reused source/baseline/Activity changed');
  console.log('AFFINITY_STRUCTURE_RESULT='+JSON.stringify(first));
  const retry=ok(await confirm(actors[0],{...input,relationships:[...input.relationships].reverse()}));
  if(!retry.replayed||retry.version.id!==first.version.id)throw Error('Retry duplicated');
  const alias=ok(await confirm(actors[0],{...input,relationships:input.relationships.map(e=>({...e,sourceObjectId:e.sourceObjectId===t.c?'CONFIRMED_OBJECT':e.sourceObjectId}))}));
  if(!alias.replayed||alias.version.id!==first.version.id)throw Error('Equivalent target reference duplicated');
  deny(await confirm(actors[0],{...input,targetObjectId:t.p}),'23505');
  deny(await confirm(actors[0],{...input,idempotencyKey:'bad-type',targetObjectId:t.p}),'22023');
  deny(await confirm(actors[0],{...input,idempotencyKey:'foreign',targetObjectId:t.foreign}));
  for(const actor of [b,master,'00000000-0000-4000-8000-000000006001','00000000-0000-4000-8000-000000006003',''])deny(await confirm(actor,input),actor?'42501':'28000');
  for(const key of ['actor','projectId','workspaceId','teamId','status','createdBy'])deny(await confirm(actors[0],{...input,[key]:t.a}),'22023');
  const create={activityInstanceId:t.a,affinityGroupId:t.g,mode:'CREATE_NEW',newObject:{objectType:'SYSTEM',title:'Control System'},idempotencyKey:'create-1',relationships:[{sourceObjectId:t.c,targetObjectId:'CONFIRMED_OBJECT',relationshipType:'BELONGS_TO'}]};
  const pair=(await Promise.all([confirm(actors[0],create),confirm(actors[0],create)])).map(ok);
  if(pair[0].resolvedDevelopmentObjectId!==pair[1].resolvedDevelopmentObjectId||pair[0].version.id!==pair[1].version.id||pair.filter(v=>v.replayed).length!==1)throw Error('Concurrent duplicate');
  if(sql(`(select count(*) from public.development_objects where origin_type='AFFINITY' and origin_reference_id='${t.g}')`)!==1
   ||sql(`(select count(*) from public.artifacts where activity_instance_id='${t.a}' and artifact_type='INVENTION_STRUCTURE')`)!==1
   ||sql(`(select count(*) from public.artifact_versions where artifact_id='${first.artifact.id}')`)!==2)throw Error('Hidden concurrent duplicate rows');
  const obj=sql(`(select to_jsonb(o) from public.development_objects o where id='${pair[0].resolvedDevelopmentObjectId}')`);
  if(obj.origin_type!=='AFFINITY'||obj.origin_reference_id!==t.g||obj.metadata.sourceActivityInstanceId!==t.a||obj.created_by!==actors[0])throw Error('Missing provenance');
  const later=ok(await confirm(actors[0],{...input,idempotencyKey:'link-2'}));
  if(later.artifact.id!==first.artifact.id||later.version.id===first.version.id||later.relationshipIds.join()!==first.relationshipIds.join())throw Error('Revision/reuse failed');
  const links=sql(`(select count(*) from public.artifact_object_links where artifact_version_id='${first.version.id}')`);
  if(links!==5||sql(`(select count(*) from public.development_objects where id='${t.p}')`)!==1||sql(`(select count(*) from public.artifacts where id='${first.artifact.id}')`)!==1)throw Error('Object continuity/links failed');
  if(JSON.stringify(sql(`(select to_jsonb(o) from public.development_objects o where id='${t.p}')`))!==JSON.stringify(originalProblem))throw Error('Historical Problem changed');
  const hidden=async actor=>{
   const count=ok(await call(actor,`(select count(*) from public.artifacts a join public.artifact_versions v on v.artifact_id=a.id join public.artifact_object_links l on l.artifact_version_id=v.id where a.id='${first.artifact.id}')`));
   if(count!==0)throw Error('Exact Artifact/Version/Object join leaked');
  };
  await hidden(b);
  if(first.version.content_snapshot.affinityGroupId!==t.g||first.version.content_snapshot.items.length!==5||first.version.content_snapshot.confirmedBy!==actors[0])throw Error('Missing Version provenance');
  const noEdges=ok(await confirm(actors[0],{...create,relationships:[],idempotencyKey:'no-edges'}));
  if(noEdges.relationshipIds.length!==0)throw Error('Inferred relationships');
  const sourceIds=[t.p,t.s,t.c];
  for(const objectId of sourceIds)if(sql(`(select count(*) from public.development_objects where id='${objectId}')`)!==1)throw Error('Canonical identity duplicated');
  // Fail after core composition, before receipt: every effect must roll back.
  run('psql',[...db,'-c',`create function private.structure_fault() returns trigger language plpgsql as $$begin raise exception 'fixture fault' using errcode='ZX115';end $$;create trigger structure_fault before insert on private.affinity_structure_confirmations for each row execute function private.structure_fault();`]);
  const counts=()=>sql(`jsonb_build_array((select count(*) from public.development_objects),(select count(*) from public.development_object_relationships),(select count(*) from public.artifacts),(select count(*) from public.artifact_versions),(select count(*) from public.artifact_object_links),(select count(*) from public.activity_outputs),(select count(*) from public.change_log))`);
  const prior=JSON.stringify(counts());deny(await confirm(actors[0],{...create,idempotencyKey:'fault'}),'ZX115');if(prior!==JSON.stringify(counts()))throw Error('Partial transaction');
  deny(await confirm(actors[0],{...create,activityInstanceId:t.outputActivity,affinityGroupId:t.outputGroup,idempotencyKey:'output-fault'}),'ZX115');if(prior!==JSON.stringify(counts()))throw Error('Partial output transaction');
  run('psql',[...db,'-c','drop trigger structure_fault on private.affinity_structure_confirmations;drop function private.structure_fault();']);
  const configured=ok(await confirm(actors[0],{...input,activityInstanceId:t.outputActivity,affinityGroupId:t.outputGroup,idempotencyKey:'configured'}));
  if(!configured.activityOutputId||!configured.artifact.review_required||!configured.artifact.approval_required||configured.artifact.current_version_id!==null||configured.version.status!=='DRAFT')throw Error('Configured output/flags failed');
  if(sql(`(select count(*) from public.activity_outputs where id='${configured.activityOutputId}' and artifact_id='${configured.artifact.id}')`)!==1)throw Error('Missing canonical output');
  const configuredRetry=ok(await confirm(actors[0],{...input,activityInstanceId:t.outputActivity,affinityGroupId:t.outputGroup,idempotencyKey:'configured'}));
  if(configuredRetry.activityOutputId!==configured.activityOutputId||configuredRetry.version.id!==configured.version.id||!configuredRetry.replayed)throw Error('Output replay duplicated');
  for(const table of ['development_objects','development_object_relationships','artifacts','artifact_versions','artifact_object_links'])deny(await call(actors[0],`'null'::jsonb`,`delete from public.${table};`));
  deny(await call(actors[0],`'null'::jsonb`,'delete from private.affinity_structure_confirmations;'));
  run('psql',[...db,'-c',`update public.activity_instances set status='completed',completed_at=clock_timestamp() where id='${t.outputActivity}';`]);
  deny(await confirm(actors[0],{...input,activityInstanceId:t.outputActivity,affinityGroupId:t.outputGroup,idempotencyKey:'completed'}),'55000');
  ok(await call(master,`public.remove_team_member('${t.team}','${actors[0]}',null)`));deny(await confirm(actors[0],input));deny(await confirm(actors[0],{...create,idempotencyKey:'removed'}));
  await hidden(actors[0]);
  console.log('M11.5 explicit reuse/create/provenance/Draft/link/history/retry/concurrency/rollback/TeamB/removal/privacy PASS');
 } finally {run('psql',[...args,'-c',`drop database ${name} with(force)`]);}
}
