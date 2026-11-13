import {spawn} from "node:child_process";
import {readFileSync} from "node:fs";
import {join} from "node:path";
/** Local independent sessions prove serialization and revocation winners. */
export async function testArtifactApprovalConcurrency({run,args,binary,childEnv,root}){
 const name="fici_artifact_approval_concurrency";const children=[];
 run("psql",[...args,"-c",`create database ${name} template postgres`]);
 const dbArgs=args.map((v,i)=>args[i-1]==="-d"?name:v);

 function request(sql){
  let signal;const ready=new Promise(resolve=>signal=resolve);
  const promise=new Promise((resolve,reject)=>{
   const child=spawn(binary("psql"),[...dbArgs,"-t","-A","-f","-"],{cwd:root,env:childEnv,windowsHide:true});children.push(child);let out="",err="";
   const timer=setTimeout(()=>{child.kill();reject(new Error("Version race timeout"));},60000);
   child.stdout.on("data",x=>{out+=x;if(out.includes("RACE_READY"))signal();});child.stderr.on("data",x=>err+=x);
   child.on("error",e=>{clearTimeout(timer);signal();reject(e);});child.on("close",code=>{clearTimeout(timer);signal();if(code===0){resolve(out);}else{reject(new Error("Version race failed: "+err));}});child.stdin.end(sql);
  });return {promise,ready};
 }
 try{


  const setup=readFileSync(join(root,"tests/integration/start-review-feedback.sql"),"utf8").split('create temporary table review_before')[0];
  const out=run("psql",[...dbArgs,"-t","-A","-f","-"],setup+`\nselect 'REVIEW_FIXTURE='||jsonb_build_object('submission',(select payload->>'id' from review_fixtures where label='Personal'),'artifact',(select payload->>'artifactId' from submitted_fixtures where label='Personal'),'version',(select payload->>'initialVersionId' from submitted_fixtures where label='Personal'),'cohort',(select id from acceptance_cohorts where label='Test'))::text;commit;`);
  const line=out.split(/\r?\n/).find(x=>x.startsWith("REVIEW_FIXTURE="));if(!line)throw new Error("Missing review fixture");const ctx=JSON.parse(line.slice(15));
  for(const id of Object.values(ctx))if(!/^[a-f0-9-]{36}$/.test(id))throw new Error("Invalid fixture UUID");
  const reviewer="set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);";

  const owner="set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);";
  const meta=JSON.parse(run("psql",[...dbArgs,"-t","-A","-c",`select json_build_object('project',a.project_id,'workspace',a.workspace_id,'activity',s.activity_instance_id) from public.artifacts a join public.submissions s on s.artifact_id=a.id where s.id='${ctx.submission}';`]).trim());
  function prepare(label,two=false){
   const sql=`begin;${owner}create temporary table approval_fixture(data jsonb);insert into approval_fixture values(public.create_artifact('${meta.project}','${meta.workspace}','PITCH_DECK_RECORD','${label}','${meta.activity}',false,false));create temporary table cycles(data jsonb);insert into cycles select public.submit_artifact((data->>'artifactId')::uuid,(data->>'initialVersionId')::uuid,'${meta.activity}') from approval_fixture;${two?`create temporary table next_draft(data jsonb);insert into next_draft select public.create_artifact_version((data->>'artifactId')::uuid,'{}','Second') from approval_fixture;insert into cycles select public.submit_artifact((data->>'artifact_id')::uuid,(data->>'id')::uuid,'${meta.activity}') from next_draft;`:""}${reviewer}select public.start_review((data->>'id')::uuid) from cycles;select 'APPROVAL_FIXTURE='||jsonb_build_object('artifact',(select data->>'artifactId' from approval_fixture),'cycles',(select jsonb_agg(data order by data->>'artifact_version_id') from cycles))::text;commit;`;
   const out=run("psql",[...dbArgs,"-t","-A","-f","-"],sql);return JSON.parse(out.split(/\r?\n/).find(x=>x.startsWith('APPROVAL_FIXTURE=')).slice(17));
  }
  async function race(first,second){const a=request(`begin;${reviewer}select ${first};select 'RACE_READY';select pg_sleep(0.7);commit;`);await a.ready;const b=request(`begin;${reviewer}${second};commit;`);await Promise.all([a.promise,b.promise]);}
  const conflict=call=>`do $$begin begin perform ${call};raise exception 'Competing terminal transition accepted';exception when invalid_parameter_value then null;end;end$$`;
  const cases=[];
  const same=prepare('Double approval');const sameId=same.cycles[0].id;
  await race(`public.approve_artifact('${sameId}','Same')`,`select public.approve_artifact('${sameId}','Same')`);cases.push({...same,approved:1,revised:0});
  const aw=prepare('Approval wins');const aid=aw.cycles[0].id;
  await race(`public.approve_artifact('${aid}')`,conflict(`public.request_revision('${aid}','Too late')`));cases.push({...aw,approved:1,revised:0});
  const rw=prepare('Revision wins');const rid=rw.cycles[0].id;
  await race(`public.request_revision('${rid}','Revise')`,conflict(`public.approve_artifact('${rid}')`));cases.push({...rw,approved:0,revised:1});
  const versions=prepare('Competing Versions',true);const [s1,s2]=versions.cycles;
  await race(`public.approve_artifact('${s1.id}')`,`select public.approve_artifact('${s2.id}')`);cases.push({...versions,approved:2,revised:0,current:s2.artifact_version_id});
  for(const c of cases){
   const stats=JSON.parse(run("psql",[...dbArgs,"-t","-A","-c",`select json_build_object('current',(select count(*) from public.artifact_versions where artifact_id='${c.artifact}' and status='CURRENT'),'pointer',(select current_version_id from public.artifacts where id='${c.artifact}'),'approved',(select count(*) from public.review_actions ra join public.submissions s on s.id=ra.submission_id where s.artifact_id='${c.artifact}' and ra.action_type='APPROVED'),'audit',(select count(*) from public.audit_events e join public.submissions s on s.id=e.entity_id where s.artifact_id='${c.artifact}' and e.event_type='ARTIFACT_APPROVED'),'revision',(select count(*) from public.review_actions ra join public.submissions s on s.id=ra.submission_id where s.artifact_id='${c.artifact}' and ra.action_type='REQUESTED_REVISION'),'bad',(select count(*) from public.submissions s join public.artifact_versions v on v.id=s.artifact_version_id where s.artifact_id='${c.artifact}' and ((s.status='APPROVED' and v.status not in ('CURRENT','SUPERSEDED')) or (s.status='REVISION_REQUESTED' and v.status<>'REVISION_REQUESTED'))));`]).trim());
   if(stats.approved!==c.approved||stats.audit!==c.approved||stats.revision!==c.revised||stats.bad!==0||stats.current!==(c.approved?1:0)||(c.current&&stats.pointer!==c.current)||(!c.approved&&stats.pointer!==null))throw new Error('Approval race invariant failed');
  }
  console.log("M8.11 double approval / both approval-revision winners / competing Versions PASS");
 }finally{for(const child of children)if(child.exitCode===null)child.kill();run("psql",[...args,"-c",`drop database ${name} with (force)`]);}
}
