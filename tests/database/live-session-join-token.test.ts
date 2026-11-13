import {spawn} from 'node:child_process';
import {beforeEach,expect,it,vi} from 'vitest';
vi.mock('server-only',()=>({}));
const m=vi.hoisted(()=>({actor:'',auth:vi.fn(),rpc:vi.fn(),token:vi.fn()}));
vi.mock('@/lib/auth/authorization',async()=>{const actual=await vi.importActual<typeof import('@/lib/auth/authorization')>('@/lib/auth/authorization');return {...actual,getAuthorizationContext:m.auth};});
vi.mock('@/lib/db/server',()=>({createServerSupabaseClient:async()=>({rpc:m.rpc})}));
vi.mock('@/features/live-classroom/factory',()=>({createLiveClassroomProvider:()=>({createJoinToken:m.token})}));
import {getLiveSessionJoinToken} from '@/features/live-classroom/join-token';
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
 vi.clearAllMocks();m.actor=id(160401);m.auth.mockImplementation(async()=>({userId:m.actor}));
 m.rpc.mockImplementation(async(name,args)=>{
  if(!['can_join_live_session','authorize_live_session_join'].includes(name))throw Error('Unexpected RPC');
  try{return {data:result(await sql(`begin;set local role authenticated;select set_config('request.jwt.claim.sub',${lit(m.actor)},true);select 'RESULT='||coalesce(public.${name}(${lit(args.target_room)})::text,'null');commit;`)),error:null};}catch{return {data:null,error:{code:'42501'}};}
 });
 m.token.mockImplementation(async c=>({success:true,data:{token:'mock.join.token',expiresAt:c.expiresAt}}));
});
it.each([[160401,'STUDENT'],[160301,'MASTER']])('real canonical actor %s obtains minimal %s capability',async(actor,role)=>{
 m.actor=id(Number(actor));const input={liveSessionRoomId:await room()};const response=await getLiveSessionJoinToken(input);expect(response.participantRole).toBe(role);expect(m.token.mock.calls[0][0]).toMatchObject({userId:m.actor,displayName:expect.any(String)});expect(response).not.toHaveProperty('providerRoomRef');
});
it.each([160402,160403,160404,160405,160406,160407,160409,160410,160302,160303,160304,160306,160307,160308,160309])('foreign/revoked/inactive/role-only actor %s denied before provider',async actor=>{m.actor=id(actor);await expect(getLiveSessionJoinToken({liveSessionRoomId:await room()})).rejects.toMatchObject({code:'FORBIDDEN'});expect(m.token).not.toHaveBeenCalled();});
it('guessed and expired mapping cannot issue token',async()=>{for(const target of [id(999999),await room(710,'EXPIRED')])await expect(getLiveSessionJoinToken({liveSessionRoomId:target})).rejects.toMatchObject({code:'FORBIDDEN'});expect(m.token).not.toHaveBeenCalled();});
it('provider failure preserves mapping and canonical state',async()=>{const before=await sql('select row_to_json(r)::text from public.live_session_rooms r order by id;');m.token.mockResolvedValue({success:false,error:{code:'UNAVAILABLE'}});await expect(getLiveSessionJoinToken({liveSessionRoomId:await room()})).rejects.toMatchObject({code:'LIVE_JOIN_UNAVAILABLE'});expect(await sql('select row_to_json(r)::text from public.live_session_rooms r order by id;')).toBe(before);});
it('Master assignment loss during provider call withholds token',async()=>{m.actor=id(160301);m.token.mockImplementation(async c=>{await sql(`update public.role_assignments set status='inactive' where id=${lit(id(160330))};`);return {success:true,data:{token:'mock.join.token',expiresAt:c.expiresAt}};});try{await expect(getLiveSessionJoinToken({liveSessionRoomId:await room()})).rejects.toMatchObject({code:'FORBIDDEN'});}finally{await sql(`update public.role_assignments set status='active' where id=${lit(id(160330))};`);}});
it('enrollment loss during provider call withholds token without changing shared A1 fixtures',async()=>{
 // Separate actor: removed enrollments are immutable history, not cleanup state.
 m.actor=id(160501);
 await sql(`begin;insert into auth.users(id,email) values(${lit(m.actor)},'m165-removal@example.test');select public.provision_user_profile(${lit(m.actor)},'active');insert into public.enrollments(cohort_id,user_id,enrollment_role,status) values(${lit(id(160320))},${lit(m.actor)},'participant','active');commit;`);
 const input={liveSessionRoomId:await room()};
 expect((await getLiveSessionJoinToken(input)).participantRole).toBe('STUDENT');
 m.token.mockClear().mockImplementation(async c=>{await sql(`update public.enrollments set status='removed' where user_id=${lit(m.actor)} and status='active';`);return {success:true,data:{token:'mock.join.token',expiresAt:c.expiresAt}};});
 await expect(getLiveSessionJoinToken(input)).rejects.toMatchObject({code:'FORBIDDEN'});
 expect(m.token).toHaveBeenCalledTimes(1);
 expect(result(await sql(`select 'RESULT='||count(*)::text from public.enrollments where user_id=${lit(m.actor)} and status='removed';`))).toBe(1);
 m.token.mockClear();
 await expect(getLiveSessionJoinToken(input)).rejects.toMatchObject({code:'FORBIDDEN'});
 expect(m.token).not.toHaveBeenCalled();
 // Positive control: the original M16.4 A1 fixture remains eligible.
 m.actor=id(160401);
 expect(result(await sql(`begin;set local role authenticated;select set_config('request.jwt.claim.sub',${lit(m.actor)},true);select 'RESULT='||public.can_join_live_session(${lit(input.liveSessionRoomId)})::text;rollback;`))).toBe(true);
});
it('anonymous/direct client cannot forge context or mutate internal mapping',async()=>{
 await expect(sql(`set role anon;select public.authorize_live_session_join(${lit(await room())});`)).rejects.toThrow();
 await expect(sql(`begin;set local role authenticated;select set_config('request.jwt.claim.sub',${lit(m.actor)},true);update public.live_session_rooms set provider_room_ref='spoof';rollback;`)).rejects.toThrow();
 const columns=await sql("select column_name from information_schema.columns where table_schema='public' and table_name='live_session_rooms';");expect(columns).not.toMatch(/token|api_key|secret/);
});

