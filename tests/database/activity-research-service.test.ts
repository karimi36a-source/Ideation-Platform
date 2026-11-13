import {spawnSync} from 'node:child_process';
import {join} from 'node:path';
import {expect,it,vi} from 'vitest';
vi.mock('server-only',()=>({}));
const state=vi.hoisted(()=>({userId:'00000000-0000-4000-8000-000000006004'}));
vi.mock('@/lib/auth/authorization',async original=>({...await original<typeof import('@/lib/auth/authorization')>(),getAuthorizationContext:async()=>({...state})}));
vi.mock('@/lib/db/server',()=>({createServerSupabaseClient:async()=>({
 rpc:async(name:string,args:Record<string,unknown>)=>{try{
 const functions:Record<string,string>={add_activity_research_reference:`public.add_activity_research_reference(${literal(String(args.target_instance))},${literal(String(args.target_type))},${literal(String(args.target_entity))})`,add_activity_evidence_input:`public.add_activity_evidence_input(${literal(String(args.target_instance))},${literal(String(args.target_evidence))},${args.is_required?'true':'false'})`,add_activity_evidence_output:`public.add_activity_evidence_output(${literal(String(args.target_instance))},${literal(String(args.target_evidence))})`,can_read_activity_instance:`to_jsonb(public.can_read_activity_instance(${literal(String(args.target_instance))}))`};
 if(!functions[name])throw Error('Unexpected RPC');return {data:asUser(functions[name]),error:null};}catch{return {data:null,error:{code:'42501'}};}},
 from:(table:string)=>({select:()=>({eq:(key:string,value:string)=>({order:()=>({order:async()=>{if(table!=='activity_research_links'||key!=='activity_instance_id')throw Error('Unexpected query');return {data:asUser(`(select coalesce(jsonb_agg(to_jsonb(l) order by created_at,id),'[]'::jsonb) from public.activity_research_links l where activity_instance_id=${literal(value)})`),error:null};}})})})})
})}));
import {addActivityResearchReference,listActivityResearchReferences} from '@/features/activities/research';
import {addActivityInput} from '@/features/activities/inputs';
import {addActivityOutput} from '@/features/activities/outputs';
function literal(v:string){return "'"+v.replaceAll("'","''")+"'";}
function query(sql:string){const port=process.env.FICI_ACTIVITY_RESEARCH_PORT;if(!port||!/^\d+$/.test(port)||!process.env.POSTGRES_BIN)throw Error('Disposable database required');const r=spawnSync(join(process.env.POSTGRES_BIN,process.platform==='win32'?'psql.exe':'psql'),['-X','-h','127.0.0.1','-p',port,'-U','postgres','-d','fici_activity_research','-v','ON_ERROR_STOP=1','-t','-A','-f','-'],{input:sql,encoding:'utf8',windowsHide:true,timeout:45000});if(r.error||r.status!==0)throw Error('SQL denied');return r.stdout.trim();}
function asUser(expression:string){return JSON.parse(query(`begin;set local role authenticated;select set_config('request.jwt.claim.sub',${literal(state.userId)},true);select 'RESULT='||(${expression})::text;commit;`).split(/\r?\n/).find(s=>s.startsWith('RESULT='))!.slice(7));}
it('M12.19 real services return canonical reference/Evidence rows and deny foreign/removed users',async()=>{
 const ctx=JSON.parse(query('select row_to_json(x)::text from public.research_test_ids x limit 1'));
 const input={activityInstanceId:ctx.activity,entityType:'PATENT_RECORD',entityId:ctx.patent};
 const before=query('select jsonb_agg(to_jsonb(e) order by id)::text from public.evidence e');
 const row=await addActivityResearchReference(input);expect(await addActivityResearchReference(input)).toEqual(row);
 expect(await listActivityResearchReferences(ctx.activity)).toContainEqual(row);
 expect((await addActivityInput({activityInstanceId:ctx.activity,evidenceId:ctx.evidence,required:true})).evidence_id).toBe(ctx.evidence);
 expect((await addActivityOutput({activityInstanceId:ctx.activity,evidenceId:ctx.evidence})).evidence_id).toBe(ctx.evidence);
 expect(query('select jsonb_agg(to_jsonb(e) order by id)::text from public.evidence e')).toBe(before);
 for(const n of [6001,6002,6003,6006,6008]){state.userId='00000000-0000-4000-8000-'+String(n).padStart(12,'0');await expect(addActivityResearchReference(input)).rejects.toMatchObject({code:'NOT_FOUND'});await expect(listActivityResearchReferences(ctx.activity)).rejects.toMatchObject({code:'NOT_FOUND'});}
 const team=query(`select team_id from public.activity_instances where id=${literal(ctx.activity)}`);
 query(`begin;set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);select public.remove_team_member(${literal(team)},'00000000-0000-4000-8000-000000006004');commit;`);
 state.userId='00000000-0000-4000-8000-000000006004';await expect(addActivityResearchReference(input)).rejects.toMatchObject({code:'NOT_FOUND'});await expect(listActivityResearchReferences(ctx.activity)).rejects.toMatchObject({code:'NOT_FOUND'});
},90000);
