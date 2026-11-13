import {spawn} from "node:child_process";
import {artifactReviewSecurityFixture} from "./artifact-review-security-fixture.mjs";
// Disposable local database only; independent PostgreSQL transactions.
export async function testArtifactDraftConcurrency({run,args,binary,childEnv,root}){
 const database="fici_draft_conflicts";const children=[];
 run("psql",[...args,"-c",`create database ${database} template postgres`]);
 const db=args.map((x,i)=>args[i-1]==="-d"?database:x);
 const claims="set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);";
 const query=sql=>run("psql",[...db,"-t","-A","-c",sql]).trim();
 function session(sql,name,hold=false){
  let signal;const ready=new Promise(resolve=>signal=resolve);let child;
  const done=new Promise((resolve,reject)=>{
   child=spawn(binary("psql"),[...db,"-t","-A","-f","-"],{cwd:root,env:childEnv,windowsHide:true});children.push(child);let out="",err="";
   const timer=setTimeout(()=>{child.kill();reject(new Error("Draft race timeout"));},45000);
   child.stdout.on("data",x=>{out+=x;if(out.includes("READY"))signal();});child.stderr.on("data",x=>err+=x);
   child.on("error",reject);child.on("close",code=>{clearTimeout(timer);signal();if(code===0)resolve(out);else reject(new Error(err));});
   child.stdin.write(`begin;set local statement_timeout='40s';set local application_name='${name}';${claims}${sql}\n\\echo READY\n`);
   if(!hold)child.stdin.end("commit;\n");
  });return {ready,done,finish:(end="commit")=>child.stdin.end(`${end};\n`)};
 }
 async function blocked(name){for(let i=0;i<100;i++){
  if(query(`select exists(select 1 from pg_stat_activity where application_name='${name}' and wait_event_type='Lock' and cardinality(pg_blocking_pids(pid))>0);`)==="t")return;
  await new Promise(resolve=>setTimeout(resolve,20));
 }throw new Error("No actual overlapping lock wait");}
 try{
  const output=run("psql",[...db,"-t","-A","-f","-"],artifactReviewSecurityFixture(root)+`reset role;select 'META='||jsonb_build_object('project',(select payload->>'id' from logged_projects where label='Individual'),'workspace',(select payload->>'primary_workspace_id' from logged_projects where label='Individual'),'activity',(select id from instances where label='Individual'))::text;commit;`);
  const ctx=JSON.parse(output.split(/\r?\n/).find(x=>x.startsWith("META=")).slice(5));
  for(const value of Object.values(ctx))if(!/^[a-f0-9-]{36}$/.test(value))throw new Error("Invalid local fixture");
  function fresh(){const out=query(`begin;${claims}select 'ART='||public.create_artifact('${ctx.project}','${ctx.workspace}','PROBLEM_BANK','Draft conflict fixture',null,false,false)::text;commit;`);return JSON.parse(out.split(/\r?\n/).find(x=>x.startsWith("ART=")).slice(4));}
  function save(v,writer,token=0){return `public.update_artifact_draft('${v}',${token},'{"writer":"${writer}"}')`;}
  function attempt(call,expected){return `do $$begin begin perform ${call};raise exception 'Expected denial';exception when sqlstate '${expected}' then null;end;end$$;`;}
  function state(v){return JSON.parse(query(`select to_jsonb(v)::text from public.artifact_versions v where id='${v}';`));}
  for(const winner of ["A","B"]){
   const a=fresh(),v=a.initialVersionId;const before=state(v);
   const first=session(`select ${save(v,winner)};`,"draft_first",true);await first.ready;
   const second=session(attempt(save(v,winner==="A"?"B":"A"),"23505"),"draft_second");await blocked("draft_second");
   if(JSON.stringify(state(v))!==JSON.stringify(before))throw new Error("Uncommitted save became visible");
   first.finish();await Promise.all([first.done,second.done]);
   const after=state(v);if(after.draft_revision!==1||after.content_snapshot.writer!==winner)throw new Error("Draft winner lost");
  }
  // Simultaneous independent requests: exactly one winner and one CAS conflict.
  for(let i=0;i<3;i++){
   const a=fresh(),v=a.initialVersionId;
   const gate=session(`reset role;select id from public.artifacts where id='${a.artifactId}' for update;`,"natural_gate",true);await gate.ready;
   const sql=writer=>`do $$begin begin perform ${save(v,writer)};raise notice 'SAVE_WON';exception when unique_violation then null;end;end$$;`;
   const first=session(sql("A"),"natural_a"),second=session(sql("B"),"natural_b");
   await blocked("natural_a");await blocked("natural_b");gate.finish();
   await Promise.all([gate.done,first.done,second.done]);
   if(state(v).draft_revision!==1)throw new Error("Simultaneous CAS failed");
  }
  for(const action of ["submit","archive"]){for(const saveFirst of [true,false]){
   const a=fresh(),v=a.initialVersionId;
   const terminal=action==="submit"?`public.submit_artifact('${a.artifactId}','${v}','${ctx.activity}')`:`public.archive_artifact('${a.artifactId}')`;
   const first=session(`select ${saveFirst?save(v,"A"):terminal};`,"terminal_first",true);await first.ready;
   const second=session(saveFirst?`select ${terminal};`:attempt(save(v,"B"),action==="submit"?"55000":"42501"),"terminal_second");await blocked("terminal_second");
   first.finish();await Promise.all([first.done,second.done]);
   const row=state(v);if(row.draft_revision!==(saveFirst?1:0))throw new Error("Terminal counter changed");
   if(action==="submit"&&row.status!=="SUBMITTED")throw new Error("Submit race state");
   if(action==="archive"&&query(`select status from public.artifacts where id='${a.artifactId}'`)!=="ARCHIVED")throw new Error("Archive race state");
  }}
  const a=fresh(),v=a.initialVersionId;
  const rolled=session(`select ${save(v,"rolled")};`,"rollback_first",true);await rolled.ready;
  const survivor=session(`select ${save(v,"survivor")};`,"rollback_second");await blocked("rollback_second");rolled.finish("rollback");await Promise.all([rolled.done,survivor.done]);
  if(state(v).draft_revision!==1||state(v).content_snapshot.writer!=="survivor")throw new Error("Rollback lost write");
  console.log("M8.20 independent-session CAS A/B + simultaneous + submit/archive both orders + rollback PASS");
 }finally{for(const child of children)if(child.exitCode===null)child.kill();run("psql",[...args,"-c",`drop database ${database} with (force)`]);}
}
