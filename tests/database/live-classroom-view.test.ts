import {spawn} from 'node:child_process';
import {expect,it} from 'vitest';
const docker=process.env.FICI_LIVE_ROOM_DOCKER,container=process.env.FICI_LIVE_ROOM_CONTAINER;
if(!docker||!container||!/^fici-m162-[a-f0-9-]+$/.test(container))throw Error('Disposable M16 Docker context required');
const id=(n:number)=>`00000000-0000-4000-8000-${String(n).padStart(12,'0')}`;
const lit=(v:string)=>"'"+v.replaceAll("'","''")+"'";
async function sql(text:string){return await new Promise<string>((resolve,reject)=>{
 const child=spawn(docker!,['exec','--interactive','--env','PGOPTIONS=-c statement_timeout=50000',container!,'psql','-X','-h','127.0.0.1','-U','postgres','-d','postgres','-v','ON_ERROR_STOP=1','-qAt','-f','-'],{windowsHide:true});let out='',err='';
 const timer=setTimeout(()=>{child.kill();reject(Error('Focused SQL transport timeout'));},55000);
 child.stdout.on('data',x=>out+=x);child.stderr.on('data',x=>err+=x);child.on('error',e=>{clearTimeout(timer);reject(e);});child.on('close',code=>{clearTimeout(timer);if(code===0)resolve(out);else reject(Error('Focused SQL denied: '+err));});child.stdin.end(text);
});}
const result=(out:string)=>{const line=out.split(/\r?\n/).find(x=>x.startsWith('RESULT='));if(!line)throw Error('SQL result missing');return JSON.parse(line.slice(7));};
async function room(session=701,status:'ACTIVE'|'EXPIRED'='ACTIVE'){return result(await sql(`select 'RESULT='||to_jsonb(id)::text from public.live_session_rooms where cohort_id=${lit(id(160320))} and session_definition_id=${lit(id(session))} and status=${lit(status)} order by created_at desc limit 1;`)) as string;}


async function context(actor:number,target:string){return result(await sql(`begin;set local role authenticated;select set_config('request.jwt.claim.sub',${lit(id(actor))},true);select 'RESULT='||public.get_live_classroom_context(${lit(target)})::text;rollback;`));}
it.each([160401,160301])('Student/Master %s receives only authorized canonical classroom headings',async actor=>{const target=await room();const output=await context(actor,target);expect(output.liveSessionRoomId).toBe(target);expect(output.cohortId).toBe(id(160320));expect(output.sessionDefinitionId).toBe(id(701));expect(Object.keys(output).sort()).toEqual(['liveSessionRoomId','cohortId','cohortName','sessionDefinitionId','sessionTitle'].sort());});
it.each([160402,160403,160404,160405,160406,160407,160409,160410,160302,160303,160304,160306,160307,160308,160309])('context projection denies foreign/inactive/revoked actor %s',async actor=>{await expect(context(actor,await room())).rejects.toThrow();});
it('unknown/expired room and anonymous context access are denied',async()=>{await expect(context(160401,id(999999))).rejects.toThrow();await expect(context(160401,await room(710,'EXPIRED'))).rejects.toThrow();await expect(sql(`set role anon;select public.get_live_classroom_context(${lit(await room())});`)).rejects.toThrow();});
it('UI context read preserves canonical room/Activity/Project state and mapping privacy',async()=>{const snapshot=()=>sql("select jsonb_build_object('rooms',(select jsonb_agg(to_jsonb(r) order by id) from public.live_session_rooms r),'activities',(select jsonb_agg(to_jsonb(a) order by id) from public.activity_instances a),'projects',(select jsonb_agg(to_jsonb(p) order by id) from public.development_projects p))::text;");const before=await snapshot();await context(160401,await room());expect(await snapshot()).toBe(before);await expect(sql(`begin;set local role authenticated;select set_config('request.jwt.claim.sub',${lit(id(160401))},true);select * from public.live_session_rooms;rollback;`)).rejects.toThrow();});
