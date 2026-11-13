import {readFileSync} from "node:fs";
import {join} from "node:path";
import {problemBankFixture} from "./problem-bank-fixture.mjs";
import {solutionBankFixture} from "./solution-bank-fixture.mjs";
// M9 feature reload composes generic resume and existing RLS-backed M6/M8 reads.
export function testM9BankReconnect({run,args,root}){
 for(const [kind,fixture] of [["problem",problemBankFixture],["solution",solutionBankFixture]]){
  const definitionIds=kind==="problem"?[980801,980802]:[960801,970801];
  const definitions=definitionIds.map(id=>`'00000000-0000-4000-8000-${String(id).padStart(12,"0")}'`).join(",");
  const name=`fici_m9_${kind}_reconnect`;
  run("psql",[...args,"-c",`create database ${name} template postgres`]);
  const dbArgs=args.map((v,i)=>args[i-1]==="-d"?name:v);
  try{
   const accepted=readFileSync(join(root,`tests/integration/${kind}-bank.sql`),"utf8").split(/\r?\nreset role;/)[0];
   run("psql",[...dbArgs,"-f","-"],fixture(root)+readFileSync(join(root,`tests/integration/${kind}-bank-setup.sql`),"utf8")+accepted+"\nreset role;select set_config('request.jwt.claim.sub','',true);commit;");
   const request=()=>{
    const out=run("psql",[...dbArgs,"-t","-A","-f","-"],`begin read only;set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select 'BANK_STATE='||jsonb_build_object('resume',public.resume_activity(a.id),'objects',(select coalesce(jsonb_agg(to_jsonb(o) order by o.id),'[]') from public.development_objects o join public.activity_outputs x on x.development_object_id=o.id where x.activity_instance_id=a.id),'details',(select coalesce(jsonb_agg(to_jsonb(d) order by d.development_object_id),'[]') from public.problem_details d join public.activity_outputs x on x.development_object_id=d.development_object_id where x.activity_instance_id=a.id),'artifacts',(select coalesce(jsonb_agg(to_jsonb(b) order by b.id),'[]') from public.artifacts b where b.activity_instance_id=a.id),'versions',(select coalesce(jsonb_agg(to_jsonb(v) order by v.artifact_id,v.version_number),'[]') from public.artifact_versions v join public.artifacts b on b.id=v.artifact_id where b.activity_instance_id=a.id),'entries',(select coalesce(jsonb_agg(to_jsonb(e) order by e.id),'[]') from public.brainstorm_entries e where e.activity_instance_id=a.id))::text from public.activity_instances a where a.activity_definition_id in(${definitions}) and exists(select 1 from public.artifacts b where b.activity_instance_id=a.id and b.artifact_type='${kind.toUpperCase()}_BANK') order by a.id;commit;`);
    return out.split(/\r?\n/).filter(x=>x.startsWith("BANK_STATE=")).map(x=>JSON.parse(x.slice(11)));
   };
   const counts=()=>run("psql",[...dbArgs,"-t","-A","-c","select count(*) from public.activity_outputs;select count(*) from public.development_objects;select count(*) from public.artifacts;select count(*) from public.artifact_versions;select count(*) from public.artifact_object_links;"]);
   const before=counts(),first=request(),second=request();
   if(first.length!==2||JSON.stringify(first)!==JSON.stringify(second)||counts()!==before)throw new Error(`Bank reconnect changed persisted state/counts (${kind}, rows=${first.length})`);
   if(first.some(x=>x.artifacts.length!==1||x.versions.length<2||x.objects.length<3||x.resume.outputs.filter(o=>o.output_type==="artifact").length!==1))throw new Error("Bank reconnect lost canonical output/history");
   if(kind==="problem"&&first.some(x=>x.details.length!==x.objects.length))throw new Error("Problem reload lost typed details");
   console.log(`M9.14 ${kind} Bank committed reconnect/canonical feature+Version reload/no clones PASS`);
  }finally{run("psql",[...args,"-c",`drop database ${name}`]);}
 }
}
