import {spawn} from "node:child_process";
import {activityArtifactFixture} from "./activity-artifact-fixture.mjs";

export async function testActivityArtifactConcurrency({run,args,binary,childEnv,root}){
 const name="fici_activity_artifact_concurrency";const children=[];
 run("psql",[...args,"-c",`create database ${name} template postgres`]);
 const dbArgs=args.map((value,index)=>args[index-1]==="-d"?name:value);
 const owner="set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);";
 const master="set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);";
 function request(sql){let signal;const ready=new Promise(resolve=>signal=resolve);const promise=new Promise((resolve,reject)=>{const child=spawn(binary("psql"),[...dbArgs,"-t","-A","-f","-"],{cwd:root,env:childEnv,windowsHide:true});children.push(child);let out="",err="";const timer=setTimeout(()=>{child.kill();reject(new Error("Activity Artifact race timeout"));},60000);child.stdout.on("data",chunk=>{out+=chunk;if(out.includes("RACE_READY"))signal();});child.stderr.on("data",chunk=>err+=chunk);child.on("error",error=>{clearTimeout(timer);signal();reject(error);});child.on("close",code=>{clearTimeout(timer);signal();if(code===0)resolve(out);else reject(new Error("Activity Artifact race failed: "+err));});child.stdin.end(sql);});return {ready,promise};}
 const value=(out,prefix)=>{const line=out.split(/\r?\n/).find(x=>x.startsWith(prefix));if(!line)throw new Error("Missing "+prefix);return JSON.parse(line.slice(prefix.length));};
 try{
  const setup=activityArtifactFixture(root)+`
  create temporary table race(data jsonb);grant all on race to authenticated;
  ${owner}insert into race select public.create_artifact(c.project,c.workspace,'PROBLEM_BANK','Race Artifact',f.id,true,true) from av_context c join resumed_fixture f on f.label=c.label where c.label='Team';
  update race set data=data||jsonb_build_object('submission',public.submit_artifact((data->>'artifactId')::uuid,(data->>'initialVersionId')::uuid,(select id from resumed_fixture where label='Team')));
  ${master}select public.start_review((select (data->'submission'->>'id')::uuid from race));reset role;
  select 'CTX='||jsonb_build_object('project',c.project,'workspace',c.workspace,'team',c.team,'activity',f.id,'artifact',r.data->>'artifactId','version',r.data->>'initialVersionId','submission',r.data->'submission'->>'id')::text from av_context c join resumed_fixture f on f.label=c.label cross join race r where c.label='Team';commit;`;
  const c=value(run("psql",[...dbArgs,"-t","-A","-f","-"],setup),"CTX=");for(const id of Object.values(c))if(!/^[0-9a-f-]{36}$/.test(id))throw new Error("Invalid fixture UUID");
  const evalSql=`public.evaluate_activity_dependencies('00000000-0000-4000-8000-000000740803','${c.project}','${c.workspace}','${c.team}')`;
  const first=request(`begin;${master}select public.approve_artifact('${c.submission}');select 'RACE_READY';select pg_sleep(1.5);commit;`);await first.ready;
  const pending=request(`begin;${owner}do $$begin if (${evalSql}->>'satisfied')<>'false' then raise exception 'Uncommitted approval consumed';end if;end$$;commit;`);await Promise.all([first.promise,pending.promise]);
  const downstream=value(run("psql",[...dbArgs,"-t","-A","-f","-"],`begin;${owner}do $$begin if (${evalSql}->>'satisfied')<>'true' then raise exception 'Committed approval unavailable';end if;end$$;select 'DOWN='||public.start_activity('00000000-0000-4000-8000-000000740803','${c.project}','${c.workspace}','${c.team}')::text;commit;`),"DOWN=");
  const target=downstream.activity.id;if(!/^[0-9a-f-]{36}$/.test(target))throw new Error("Start failed");
  const link=version=>`public.add_activity_artifact_input('${target}','${c.artifact}','${version}',true)`;
  const one=request(`begin;${owner}select 'LINK='||${link(c.version)}::text;select 'RACE_READY';select pg_sleep(0.7);commit;`);await one.ready;
  const two=request(`begin;${owner}select 'LINK='||${link(c.version)}::text;commit;`);const links=(await Promise.all([one.promise,two.promise])).map(out=>value(out,"LINK="));if(links[0].id!==links[1].id)throw new Error("Concurrent input retry duplicated");
  const next=value(run("psql",[...dbArgs,"-t","-A","-f","-"],`begin;${owner}create temporary table n(data jsonb);insert into n values(public.create_artifact_version('${c.artifact}','{"next":true}','Next'));update n set data=public.submit_artifact('${c.artifact}',(data->>'id')::uuid,'${c.activity}');${master}select public.start_review((select (data->>'id')::uuid from n));select 'NEXT='||data::text from n;commit;`),"NEXT=");
  const replace=request(`begin;${master}select public.approve_artifact('${next.id}');select 'RACE_READY';select pg_sleep(1.5);commit;`);await replace.ready;
  const stale=request(`begin;${owner}do $$begin begin perform public.add_activity_artifact_input('${target}','${c.artifact}','${c.version}',false);raise exception 'Stale candidate admitted';exception when insufficient_privilege then null;end;end$$;commit;`);await Promise.all([replace.promise,stale.promise]);
  run("psql",[...dbArgs,"-c",`begin;${owner}select ${link(next.artifact_version_id)};commit;`]);
  const stats=JSON.parse(run("psql",[...dbArgs,"-t","-A","-c",`select json_build_object('links',(select count(*) from public.activity_inputs where artifact_id='${c.artifact}'),'old',(select count(*) from public.activity_inputs where artifact_version_id='${c.version}'),'current',(select current_version_id from public.artifacts where id='${c.artifact}'),'baselines',(select count(*) from public.project_baseline_items),'versions',(select count(*) from public.artifact_versions where artifact_id='${c.artifact}'));`]).trim());
  if(stats.links!==2||stats.old!==1||stats.current!==next.artifact_version_id||stats.baselines!==0||stats.versions!==2)throw new Error("Handoff concurrency/history failed");
  console.log("M8.14 committed approval / concurrent input idempotency / supersession TOCTOU / fixed history PASS");
 }finally{for(const child of children)if(child.exitCode===null)child.kill();run("psql",[...args,"-c",`drop database ${name} with (force)`]);}
}
