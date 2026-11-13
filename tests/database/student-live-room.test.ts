import {spawn} from 'node:child_process';
import {beforeEach,expect,it,vi} from 'vitest';
vi.mock('server-only',()=>({}));
const m=vi.hoisted(()=>({actor:'00000000-0000-4000-8000-000000160401',context:vi.fn(),rpc:vi.fn()}));
vi.mock('@/lib/auth/authorization',()=>({getAuthorizationContext:m.context}));
vi.mock('@/lib/db/server',()=>({createServerSupabaseClient:async()=>({rpc:m.rpc})}));
import {canJoinLiveSession} from '@/features/live-classroom/join-authorization';
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
beforeEach(()=>{
 m.actor=id(160401);m.context.mockReset().mockImplementation(async()=>({userId:m.actor}));
 m.rpc.mockReset().mockImplementation(async(name,args)=>{
  if(name!=='can_join_live_session')throw Error('Unexpected RPC');
  try{return {data:result(await sql(`begin;set local role authenticated;select set_config('request.jwt.claim.sub',${lit(m.actor)},true);select 'RESULT='||public.can_join_live_session(${lit(args.target_room)})::text;commit;`)),error:null};}
  catch{return {data:null,error:{code:'42501'}};}
 });
});
it('enrolled A1 is allowed through real caller-bound database eligibility',async()=>{expect(await canJoinLiveSession({liveSessionRoomId:await room()})).toBe(true);expect(m.rpc).toHaveBeenCalledTimes(2);});
it.each([160402,160403,160404,160405,160406,160407,160409,160410])('denies unrelated/inactive/removed actor %s despite exact room knowledge',async actor=>{m.actor=id(actor);expect(await canJoinLiveSession({liveSessionRoomId:await room()})).toBe(false);});
it('expired mapping and guessed IDs are denied',async()=>{expect(await canJoinLiveSession({liveSessionRoomId:await room(710,'EXPIRED')})).toBe(false);expect(await canJoinLiveSession({liveSessionRoomId:id(999999)})).toBe(false);});
it('provider reference, client identity and Cohort overrides never reach the DB',async()=>{
 const known=await room();for(const input of [{providerRoomRef:'known-room'},{liveSessionRoomId:known,userId:id(160401)},{liveSessionRoomId:known,cohortId:id(160320)}])expect(await canJoinLiveSession(input)).toBe(false);expect(m.rpc).not.toHaveBeenCalled();
});
it('fresh enrollment removal invalidates the next check without deleting history',async()=>{
 m.actor=id(160408);const input={liveSessionRoomId:await room()};expect(await canJoinLiveSession(input)).toBe(true);
 await sql(`update public.enrollments set status='removed' where user_id=${lit(m.actor)} and status='active';`);
 expect(await canJoinLiveSession(input)).toBe(false);
 expect(result(await sql(`select 'RESULT='||count(*)::text from public.enrollments where user_id=${lit(m.actor)} and status='removed';`))).toBe(1);
});
it('even a permitted Student cannot directly browse the internal room mapping',async()=>{await expect(sql(`begin;set local role authenticated;select set_config('request.jwt.claim.sub',${lit(m.actor)},true);select * from public.live_session_rooms where id=${lit(await room())};rollback;`)).rejects.toThrow('Focused SQL denied');});
