import {spawn} from "node:child_process";
import {readFileSync} from "node:fs";
import {join} from "node:path";
import {activityArtifactFixture} from "./activity-artifact-fixture.mjs";

/** AT-CON-002: disposable DB, independent READ COMMITTED sessions, observed waits. */
export async function testReviewTerminalConcurrency({run,args,binary,childEnv,root}){
 const name="fici_terminal_acceptance";const children=[];let serial=0;
 run("psql",[...args,"-c",`create database ${name} template postgres`]);
 const dbArgs=args.map((v,i)=>args[i-1]==="-d"?name:v);
 const sql=statement=>run("psql",[...dbArgs,"-t","-A","-f","-"],statement);
 const json=statement=>JSON.parse(sql(statement).trim());
 const actor=n=>`set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-${String(n).padStart(12,"0")}',true);`;
 const marker=(out,key)=>{const line=out.split(/\r?\n/).find(x=>x.startsWith(key+"="));if(!line)throw new Error("Missing "+key);return JSON.parse(line.slice(key.length+1));};
 function session(statement,hold=false){
  const app=`m819_${++serial}`;let output="",error="",signal;let completed=false;
  const ready=new Promise(resolve=>signal=resolve);
  const child=spawn(binary("psql"),[...dbArgs,"-t","-A","-f","-"],{cwd:root,env:childEnv,windowsHide:true});children.push(child);
  const promise=new Promise((resolve,reject)=>{
   const timer=setTimeout(()=>{child.kill();reject(new Error("AT-CON-002 session timeout"));},60000);
   child.stdout.on("data",x=>{output+=x;if(output.includes("SESSION_READY"))signal();});child.stderr.on("data",x=>error+=x);
   child.on("error",e=>{clearTimeout(timer);signal();reject(e);});
   child.on("close",code=>{completed=true;clearTimeout(timer);signal();if(code===0)resolve(output);else reject(new Error("AT-CON-002 SQL failed: "+error));});
  });
  // Attach a rejection handler immediately while the lock observer is running.
  promise.catch(()=>{});
  child.stdin.write(`set application_name='${app}';begin isolation level read committed;set local statement_timeout='45s';${statement}\n\\echo SESSION_READY\n`);
  if(!hold)child.stdin.end("commit;\n");
  return {app,ready,promise,release:(commit=true)=>{if(completed)throw new Error("Session exited before release");child.stdin.end(commit?"commit;\n":"rollback;\n");}};
 }
 async function blocked(sessions){
  const deadline=Date.now()+15000;
  while(Date.now()<deadline){
   const count=Number(sql(`select count(*) from pg_stat_activity where application_name in (${sessions.map(s=>`'${s.app}'`).join(",")}) and wait_event_type='Lock' and cardinality(pg_blocking_pids(pid))>0;`).trim());
   if(count===sessions.length)return;
   await new Promise(resolve=>setTimeout(resolve,75));
  }
  throw new Error("Independent transaction overlap was not observed");
 }
 const call=(kind,sid,note)=>`public.${kind==="approve"?"approve_artifact":"request_revision"}('${sid}','${note}')`;
 // NOTICE results go to stderr, so use a transaction-local result table instead.
 const operation=expression=>`create temporary table outcome(data jsonb);do $$declare r jsonb;c text;begin begin r:=${expression};insert into outcome values(jsonb_build_object('ok',true,'row',r));exception when invalid_parameter_value or insufficient_privilege or no_data_found then get stacked diagnostics c=returned_sqlstate;insert into outcome values(jsonb_build_object('ok',false,'code',c));end;end$$;select 'OUTCOME='||data::text from outcome;`;
 const snapshot=c=>json(`select jsonb_build_object('artifact',(select to_jsonb(a) from public.artifacts a where id='${c.artifact}'),'versions',(select jsonb_agg(to_jsonb(v) order by version_number) from public.artifact_versions v where artifact_id='${c.artifact}'),'submissions',(select jsonb_agg(to_jsonb(s) order by id) from public.submissions s where artifact_id='${c.artifact}'),'actions',(select jsonb_agg(to_jsonb(r) order by r.id) from public.review_actions r join public.submissions s on s.id=r.submission_id where s.artifact_id='${c.artifact}'),'feedback',(select jsonb_agg(to_jsonb(f) order by f.id) from public.feedback_items f join public.submissions s on s.id=f.submission_id where s.artifact_id='${c.artifact}'),'audit',(select jsonb_agg(to_jsonb(e) order by e.id) from public.audit_events e join public.submissions s on s.id=e.entity_id where s.artifact_id='${c.artifact}'),'baseline',(select jsonb_agg(to_jsonb(b) order by id) from public.project_baseline_items b),'activities',(select jsonb_agg(to_jsonb(i) order by id) from public.activity_instances i));`);
 let meta;
 function prepare(two=false){
  const out=sql(`begin;${actor(6005)}select public.archive_artifact(id) from public.artifacts where project_id='${meta.project}' and status='ACTIVE';create temporary table fixture(data jsonb);insert into fixture values(public.create_artifact('${meta.project}','${meta.workspace}','PITCH_DECK_RECORD','AT-CON-002 ${serial}','${meta.activity}',true,true));create temporary table cycles(data jsonb);insert into cycles select public.submit_artifact((data->>'artifactId')::uuid,(data->>'initialVersionId')::uuid,'${meta.activity}') from fixture;${two?`create temporary table draft(data jsonb);insert into draft select public.create_artifact_version((data->>'artifactId')::uuid,'{"second":true}','Second race Version') from fixture;insert into cycles select public.submit_artifact((data->>'artifact_id')::uuid,(data->>'id')::uuid,'${meta.activity}') from draft;`:""}${actor(6002)}select public.start_review((data->>'id')::uuid) from cycles;select public.add_feedback('ARTIFACT',(select (data->>'artifactId')::uuid from fixture),(data->>'artifact_version_id')::uuid,'COMMENT','Preserved before race') from cycles;select 'FIXTURE='||jsonb_build_object('artifact',(select data->>'artifactId' from fixture),'cycles',(select jsonb_agg(data order by data->>'artifact_version_id') from cycles))::text;commit;`);
  return marker(out,"FIXTURE");
 }
 function equal(a,b,message){if(JSON.stringify(a)!==JSON.stringify(b))throw new Error(message);}
 function verify(c,before){
  const after=snapshot(c);equal(after.baseline,before.baseline,"Race changed manual baseline");equal(after.activities,before.activities,"Race changed Activity");
  equal((after.actions??[]).filter(x=>!['APPROVED','REQUESTED_REVISION'].includes(x.action_type)),before.actions,"Prior Review Action changed");
  equal((after.feedback??[]).filter(x=>x.feedback_type!=="REVISION_REQUEST"),before.feedback,"Prior Feedback changed");
  const current=after.versions.filter(x=>x.status==="CURRENT");if(current.length>1||after.artifact.current_version_id!==(current[0]?.id??null))throw new Error("Current pointer/uniqueness failure");
  for(const s of after.submissions){
   const v=after.versions.find(v=>v.id===s.artifact_version_id);const actions=(after.actions??[]).filter(x=>x.submission_id===s.id&&['APPROVED','REQUESTED_REVISION'].includes(x.action_type));const audit=(after.audit??[]).filter(x=>x.entity_id===s.id&&['ARTIFACT_APPROVED','REVISION_REQUESTED'].includes(x.event_type));const feedback=(after.feedback??[]).filter(x=>x.submission_id===s.id&&x.feedback_type==='REVISION_REQUEST');
   if(actions.length!==1||audit.length!==1)throw new Error("Duplicate/missing terminal history");
   if(s.status==='APPROVED'){
    if(!['CURRENT','SUPERSEDED'].includes(v.status)||!v.approved_at||v.approved_by!=="00000000-0000-4000-8000-000000006002"||actions[0].action_type!=='APPROVED'||actions[0].note!==v.approval_note||actions[0].created_at!==v.approved_at||audit[0].event_type!=='ARTIFACT_APPROVED'||audit[0].created_at!==v.approved_at||feedback.length)throw new Error("Mixed approval outcome");
   }else if(s.status==='REVISION_REQUESTED'){
    if(v.status!=='REVISION_REQUESTED'||v.approved_at!==null||v.approved_by!==null||v.approval_note!==null||actions[0].action_type!=='REQUESTED_REVISION'||audit[0].event_type!=='REVISION_REQUESTED'||feedback.length!==1||feedback[0].status!=='OPEN'||feedback[0].content!==actions[0].note||feedback[0].target_version_id!==v.id)throw new Error("Mixed revision outcome");
   }else throw new Error("Unfinished terminal race");
   if(audit[0].actor_user_id!=="00000000-0000-4000-8000-000000006002"||JSON.stringify(audit[0].metadata)!=='{}')throw new Error("Audit attribution failure");
   const old=before.versions.find(x=>x.id===v.id);for(const k of ['content_snapshot','version_number','version_label','change_summary','created_by','created_at','previous_version_id'])equal(v[k],old[k],"Historical Version changed: "+k);
  }
  const deps=marker(sql(`begin;${actor(6005)}select 'DEPS='||jsonb_build_object('evaluation',public.evaluate_activity_dependencies('00000000-0000-4000-8000-000000740803','${meta.project}','${meta.workspace}','${meta.team}'),'candidates',public.list_activity_artifact_candidates('00000000-0000-4000-8000-000000740803','${meta.project}','${meta.workspace}','${meta.team}'))::text;commit;`),"DEPS");
  if(deps.evaluation.satisfied!==(current.length===1)||deps.candidates.length!==current.length||(current.length&&deps.candidates[0].artifactVersionId!==current[0].id))throw new Error("Dependency did not follow committed winner");
  // Opposite stale action must fail, preserve exact state, and expose only code.
  for(const s of after.submissions){
   const result=marker(sql(`begin;${actor(6002)}${operation(call(s.status==='APPROVED'?'revise':'approve',s.id,'Stale opposite'))}commit;`),"OUTCOME");
   if(result.ok||result.code!=='22023')throw new Error("Stale opposite accepted");
  }
  equal(snapshot(c),after,"Stale action changed canonical state");return after;
 }
 async function race(c,firstKind,secondKind,firstNote="Same",secondNote="Same",natural=false){
  const before=snapshot(c);const sid=c.cycles[0].id;let a,b;
  if(natural){
   const gate=session(`select id from public.submissions where id='${sid}' for update;`,true);await gate.ready;
   a=session(actor(6002)+operation(call(firstKind,sid,firstNote)));b=session(actor(6002)+operation(call(secondKind,sid,secondNote)));
   await blocked([a,b]);equal(snapshot(c),before,"Uncommitted race became visible");gate.release();await gate.promise;
  }else{
   a=session(actor(6002)+operation(call(firstKind,sid,firstNote)),true);await a.ready;
   b=session(actor(6002)+operation(call(secondKind,sid,secondNote)));await blocked([b]);equal(snapshot(c),before,"Uncommitted winner became visible");a.release();
  }
  const results=(await Promise.all([a.promise,b.promise])).map(x=>marker(x,"OUTCOME"));
  if(firstKind!==secondKind||firstNote!==secondNote){if(results.filter(x=>x.ok).length!==1||results.find(x=>!x.ok)?.code!=='22023'||(!natural&&!results[0].ok))throw new Error("Wrong terminal winner/conflict");}
  else{if(results.some(x=>!x.ok))throw new Error("Canonical same-note retry failed");equal(results[0].row,results[1].row,"Retry returned different state");}
  const after=verify(c,before);const winning=after.actions.find(x=>['APPROVED','REQUESTED_REVISION'].includes(x.action_type));
  const expectedNote=results[0].ok?firstNote:secondNote;if(winning.note!==expectedNote)throw new Error("Winning note overwritten");
 }
 try{
  const handoff=readFileSync(join(root,"tests/integration/activity-artifact-handoff.sql"),"utf8").split("select public.approve_artifact((data->>'id')::uuid) from artifact_handoff where label='submission';")[0];
  const out=sql(activityArtifactFixture(root).replaceAll("'PROBLEM_BANK'","'PITCH_DECK_RECORD'")+handoff.replaceAll("'PROBLEM_BANK'","'PITCH_DECK_RECORD'")+`reset role;select 'META='||jsonb_build_object('project',project,'workspace',workspace,'team',team,'activity',upstream,'cohort',(select cohort_id from public.activity_instances where id=upstream))::text from artifact_handoff_context;commit;`);
  meta=marker(out,"META");for(const value of Object.values(meta))if(!/^[a-f0-9-]{36}$/.test(value))throw new Error("Invalid local fixture UUID");
  for(let n=0;n<3;n++){await race(prepare(),'approve','revise');await race(prepare(),'revise','approve');await race(prepare(),'approve','revise','Natural approval','Natural revision',true);}
  console.log("M8.19 approval-first x3 / revision-first x3 / natural x3 observed lock overlap + committed visibility PASS");
  await race(prepare(),'approve','approve');await race(prepare(),'revise','revise');
  await race(prepare(),'approve','approve','Approval A','Approval B');await race(prepare(),'revise','revise','Revision A','Revision B');
  console.log("M8.19 double approval/revision canonical retry + different-note safe conflicts PASS");
  const c=prepare(true);const before=snapshot(c);const a=session(actor(6002)+operation(call('approve',c.cycles[0].id,'First Version')),true);await a.ready;const b=session(actor(6002)+operation(call('approve',c.cycles[1].id,'Second Version')));await blocked([b]);a.release();const results=(await Promise.all([a.promise,b.promise])).map(x=>marker(x,'OUTCOME'));if(results.some(x=>!x.ok))throw new Error("Competing Version approval failed");verify(c,before);
  sql(`do $$begin begin insert into public.artifact_versions(artifact_id,version_number,content_snapshot,status,created_by,approved_by,approved_at) select artifact_id,999,'{}','CURRENT',created_by,approved_by,approved_at from public.artifact_versions where artifact_id='${c.artifact}' and status='CURRENT';raise exception 'Two CURRENT allowed';exception when unique_violation then null;end;end$$;`);
  console.log("M8.19 competing Versions / one-CURRENT database backstop / pointer coherence PASS");
  // M8.18 AFTER-audit failure pattern; an outer test-only row lock retains the
  // overlap while the failed RPC subtransaction restores UNDER_REVIEW.
  const rollback=prepare();const rollbackBefore=snapshot(rollback);const failedSid=rollback.cycles[0].id;
  sql(`create function public.m819_test_fault() returns trigger language plpgsql set search_path='' as $$begin if new.entity_id='${failedSid}' and new.event_type='ARTIFACT_APPROVED' then assert exists(select 1 from public.submissions where id='${failedSid}' and status='APPROVED');assert exists(select 1 from public.artifact_versions v join public.artifacts a on a.current_version_id=v.id where a.id='${rollback.artifact}' and v.status='CURRENT');raise exception 'M8.18 final audit injected failure' using errcode='P0002';end if;return new;end$$;revoke all on function public.m819_test_fault() from public,anon,authenticated,service_role;create trigger m819_test_fault after insert on public.audit_events for each row execute function public.m819_test_fault();do $$begin assert not has_function_privilege('authenticated','public.m819_test_fault()','EXECUTE');assert not has_function_privilege('anon','public.m819_test_fault()','EXECUTE');end$$;`);
  const held=session(`select id from public.submissions where id='${failedSid}' for update;`+actor(6002)+operation(call('approve',failedSid,'Rolled back')),true);await held.ready;const waiting=session(actor(6002)+operation(call('revise',failedSid,'After rollback')));await blocked([waiting]);equal(snapshot(rollback),rollbackBefore,'Injected approval left visible partial state');held.release();const failed=marker(await held.promise,'OUTCOME');if(failed.ok||failed.code!=='P0002')throw new Error('Fault did not fire after approval audit');const recovered=marker(await waiting.promise,'OUTCOME');if(!recovered.ok)throw new Error("Waiting revision did not recover rollback");verify(rollback,rollbackBefore);
  sql('drop trigger m819_test_fault on public.audit_events;drop function public.m819_test_fault();');
  console.log("M8.19 rollback releases lock / waiting reviewer uses restored UNDER_REVIEW PASS");
  // Revocation and archive commit while terminal actions wait on canonical
  // Cohort/Artifact locks. Both operations must revalidate after waiting.
  for(const kind of ['approve','revise']){
   for(const change of ['revoke','archive']){
    const c=prepare();const before=snapshot(c);
    const mutation=change==='revoke'?`${actor(6001)}select public.assign_master_to_cohort('${meta.cohort}','00000000-0000-4000-8000-000000006003');`:`${actor(6005)}select public.archive_artifact('${c.artifact}');`;
    const gate=session(mutation,true);await gate.ready;const pending=session(actor(6002)+operation(call(kind,c.cycles[0].id,'Denied after wait')));await blocked([pending]);gate.release();await gate.promise;const result=marker(await pending.promise,'OUTCOME');if(result.ok||result.code!=='42501')throw new Error("Stale authority/archive accepted");
    const after=snapshot(c);for(const key of ['versions','submissions','actions','feedback','audit','baseline','activities'])equal(after[key],before[key],"Denied waiting actor changed "+key);
    if(change==='revoke')sql(`begin;${actor(6001)}select public.assign_master_to_cohort('${meta.cohort}','00000000-0000-4000-8000-000000006002');commit;`);
   }
  }
  console.log("M8.19 reviewer revocation/archive during wait both operations PASS");
  console.log("M8.19 AT-CON-002 BLOCKER PASS; history/Feedback/audit/baseline/Activity/dependency/stale-action/deadlock invariants PASS");
 }finally{
  for(const child of children)if(child.exitCode===null)child.kill();
  run("psql",[...args,"-c",`drop database ${name} with (force)`]);
 }
}
