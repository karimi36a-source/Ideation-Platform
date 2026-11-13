import {readFileSync} from "node:fs";
import {join} from "node:path";
/** AT-ACT-003: each call starts a genuinely separate psql process/request. */
export function testActivityResumeAcceptance({run,args,root}){
 const name="fici_activity_resume_acceptance";
 run("psql",[...args,"-c",`create database ${name} template postgres`]);
 const dbArgs=args.map((v,i)=>args[i-1]==="-d"?name:v);
 const sql=(query)=>run("psql",[...dbArgs,"-t","-A","-f","-"],query);
 const scalar=(query)=>sql(query).split(/\r?\n/).map(v=>v.trim()).find(v=>v.startsWith("RESULT="))?.slice(7);
 const equal=(a,b,message)=>{if(JSON.stringify(a)!==JSON.stringify(b))throw new Error(message);};
 const actor=(n)=>`00000000-0000-4000-8000-${String(n).padStart(12,"0")}`;
 const request=(n,id)=>JSON.parse(scalar(`begin read only;set local role authenticated;select set_config('request.jwt.claim.sub','${actor(n)}',true);select 'RESULT='||coalesce(public.resume_activity('${id}')::text,'null');commit;`));
 let fingerprint;
 try{
  sql(readFileSync(join(root,"tests/integration/activity-resume-acceptance-setup.sql"),"utf8"));
  const tables=JSON.parse(scalar("select 'RESULT='||jsonb_agg(tablename order by tablename)::text from pg_tables where schemaname='public';"));
  if(tables.some(t=>!/^\w+$/.test(t)))throw new Error("Unexpected table identifier");
  fingerprint=()=>scalar(`select 'RESULT='||jsonb_object_agg(name,digest)::text from (${tables.map(t=>`select '${t}' name,md5(coalesce(string_agg(to_jsonb(x)::text,'' order by to_jsonb(x)::text),'')) digest from public."${t}" x`).join(" union all ")}) f;`);
  const states=JSON.parse(scalar("select 'RESULT='||jsonb_agg(to_jsonb(a) order by a.team_id nulls first)::text from public.activity_instances a;"));
  if(states.length!==2)throw new Error("Expected Personal and Team canonical Activities");
  const personal=states.find(v=>v.team_id===null),team=states.find(v=>v.team_id!==null);
  const stable=(n,id)=>{const before=fingerprint(),v=request(n,id);equal(before,fingerprint(),"Resume changed public data/timestamps/counts");return v;};
  const originalPersonal=stable(6004,personal.id),originalTeam=stable(6005,team.id);
  for(const [n,id,v] of [[6004,personal.id,originalPersonal],[6005,team.id,originalTeam]]){
   equal(v.activity,states.find(a=>a.id===id),"Canonical identity/scope/state changed");
   if(v.inputs.length!==1||v.outputs.length!==1||v.participants.length!==1||v.inputs[0].required!==true||v.participants[0].user_id!==actor(n)||v.participants[0].participant_role!=="participant"||v.participants[0].completed_at!==null)throw new Error("Canonical I/O/participant state missing");
   if(v.inputs[0].development_object_id!==v.outputs[0].development_object_id||"content" in v.inputs[0]||"content" in v.outputs[0])throw new Error("Expected canonical references, not content copies");
   equal(v,stable(n,id),"Fresh process reconnect lost exact persisted state");
  }
  // Fixture-only revision of all eight execution fields, after initial request ends.
  sql(`begin;alter table public.activity_definitions disable trigger activity_history;
   update public.activity_definitions set instructions='Later fixture instructions',ai_role_code='later_fixture_ai',completion_rule='{"minimum_required_inputs":99,"minimum_outputs":99}',requires_review=not requires_review,requires_approval=not requires_approval,configuration='{"revision":"later"}',workspace_mode=case when workspace_mode='personal' then 'team' else 'personal' end,method_type=(case when method_type='reflection' then 'teaching' else 'reflection' end)::public.activity_method_type where id in ('${personal.activity_definition_id}','${team.activity_definition_id}');
   alter table public.activity_definitions enable trigger activity_history;commit;`);
  equal(originalPersonal,stable(6004,personal.id),"Live Definition rewrote Personal execution snapshot");
  equal(originalTeam,stable(6005,team.id),"Live Definition rewrote Team execution snapshot");
  const deny=(n,id)=>{equal(stable(n,id),null,"Unauthorized exact ID exposed Activity state");equal(stable(n,"00000000-0000-4000-8000-000000779999"),null,"Nonexistent denial differs");};
  for(const n of [6001,6002,6003,6005,6006,6008])deny(n,personal.id);
  deny(6006,team.id);deny(6003,team.id);
  // Actual approved completion, using stored snapshot rather than revised live rule.
  sql(`begin;set local role authenticated;select set_config('request.jwt.claim.sub','${actor(6004)}',true);select public.complete_activity('${personal.id}');commit;`);
  const completed=stable(6004,personal.id);
  if(completed.activity.id!==personal.id||completed.activity.status!=="completed"||!completed.activity.completed_at)throw new Error("Completed Activity was reopened or lost");
  for(const key of ["participants","inputs","outputs"])equal(completed[key],originalPersonal[key],"Completion/resume changed historical child rows");
  equal(completed.activity.configuration_snapshot,originalPersonal.activity.configuration_snapshot,"Completed snapshot changed");
  equal(completed,stable(6004,personal.id),"Completed reconnect changed canonical state");
  const historyQuery=`select 'RESULT='||jsonb_build_object('activity',(select to_jsonb(a) from public.activity_instances a where id='${team.id}'),'participants',(select jsonb_agg(to_jsonb(p) order by p.id) from public.activity_participants p where activity_instance_id='${team.id}'),'inputs',(select jsonb_agg(to_jsonb(i) order by i.id) from public.activity_inputs i where activity_instance_id='${team.id}'),'outputs',(select jsonb_agg(to_jsonb(o) order by o.id) from public.activity_outputs o where activity_instance_id='${team.id}'))::text;`;
  const history=scalar(historyQuery);
  sql(`begin;set local role authenticated;select set_config('request.jwt.claim.sub','${actor(6002)}',true);select public.remove_team_member('${team.team_id}','${actor(6005)}');select public.remove_team_member('${team.team_id}','${actor(6008)}');commit;`);
  deny(6005,team.id);deny(6008,team.id);
  equal(history,scalar(historyQuery),"Removal erased or rewrote Activity/participant/I-O history");
  const remaining=stable(6004,team.id);if(!remaining||remaining.activity.id!==team.id)throw new Error("Remaining Team member lost authorized resume");
  const beforeDirect=fingerprint();
  sql(`begin read only;set local role authenticated;select set_config('request.jwt.claim.sub','${actor(6005)}',true);do $$begin
   assert not exists(select 1 from public.activity_instances where id='${team.id}');
   assert not exists(select 1 from public.activity_participants where activity_instance_id='${team.id}');
   assert not exists(select 1 from public.activity_inputs where activity_instance_id='${team.id}');
   assert not exists(select 1 from public.activity_outputs where activity_instance_id='${team.id}');end $$;commit;`);
  equal(beforeDirect,fingerprint(),"Direct denied query mutated state");
  sql(`begin;set local role anon;do $$begin begin perform public.resume_activity('${personal.id}');raise exception 'Anonymous bypass';exception when insufficient_privilege then null;end;end $$;commit;`);
  sql(`update public.workspaces set status='inactive' where id='${personal.workspace_id}';`);deny(6004,personal.id);
  sql(`update public.development_projects set status='archived',archived_at=clock_timestamp() where id='${team.project_id}';`);deny(6004,team.id);
  console.log("AT-ACT-003 separate-process Personal/Team/I-O/participants/snapshot/completed/removal/RLS/read-only PASS");
 }finally{run("psql",[...args,"-c",`drop database ${name}`]);}
}
