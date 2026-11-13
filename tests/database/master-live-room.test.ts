import {spawn} from 'node:child_process';
import {beforeEach,expect,it,vi} from 'vitest';
vi.mock('server-only',()=>({}));
const m=vi.hoisted(()=>({actor:'00000000-0000-4000-8000-000000160301',context:vi.fn(),user:vi.fn(),caller:vi.fn(),internal:vi.fn(),provider:vi.fn()}));
vi.mock('@/lib/auth/authorization',async original=>({...await original<typeof import('@/lib/auth/authorization')>(),getAuthorizationContext:m.context}));
vi.mock('@/features/users/service',()=>({requireActivePlatformUser:m.user}));
vi.mock('@/lib/db/server',()=>({createServerSupabaseClient:async()=>({rpc:m.caller})}));
vi.mock('@supabase/supabase-js',()=>({createClient:()=>({rpc:m.internal})}));
vi.mock('@/lib/validation/env-server',()=>({getServerEnv:()=>({NEXT_PUBLIC_SUPABASE_URL:'https://example.test',SUPABASE_SECRET_KEY:'test-server-only'})}));
vi.mock('@/features/live-classroom/factory',()=>({createLiveClassroomProvider:()=>({getOrCreateRoom:m.provider})}));
import {getOrCreateLiveSessionRoom} from '@/features/live-classroom/room';
import {DailyLiveClassroomProvider} from '@/features/live-classroom/providers/daily';
import {AuthorizationError} from '@/lib/auth/authorization';
const docker=process.env.FICI_LIVE_ROOM_DOCKER,container=process.env.FICI_LIVE_ROOM_CONTAINER;
if(!docker||!container||!/^fici-m162-[a-f0-9-]+$/.test(container))throw Error('Disposable M16 Docker context required');
const id=(n:number)=>`00000000-0000-4000-8000-${String(n).padStart(12,'0')}`;
const master=id(160301),cohortId=id(160320),input=(n:number)=>({cohortId,sessionDefinitionId:id(n)});
const lit=(v:unknown)=>v===null?'null':"'"+String(v).replaceAll("'","''")+"'";
async function sql(text:string){
 return await new Promise<string>((resolve,reject)=>{
  const child=spawn(docker!,['exec','--interactive','--env','PGOPTIONS=-c statement_timeout=50000',container!,'psql','-X','-h','127.0.0.1','-U','postgres','-d','postgres','-v','ON_ERROR_STOP=1','-qAt','-f','-'],{windowsHide:true});let out='',err='';
  const timer=setTimeout(()=>{child.kill();reject(Error('Focused SQL transport timeout'));},55000);
  child.stdout.on('data',x=>out+=x);child.stderr.on('data',x=>err+=x);
  child.on('error',e=>{clearTimeout(timer);reject(e);});child.on('close',code=>{clearTimeout(timer);if(code===0)resolve(out);else reject(Error('Focused SQL denied: '+err));});child.stdin.end(text);
 });
}
const parse=(out:string)=>{const line=out.split(/\r?\n/).find(x=>x.startsWith('RESULT='));if(!line)throw Error('SQL result missing');return JSON.parse(line.slice(7));};
const root=async(expression:string)=>parse(await sql("select 'RESULT='||("+expression+")::text;"));
async function rpc(role:string,fn:string,args:Record<string,unknown>){
 const names=fn==='authorize_master_live_room'?['target_cohort','target_session','target_activity']:['command','target_cohort','target_session','target_activity','room_reference','actor'];
 const call='public.'+fn+'('+names.map(n=>lit(args[n]??null)).join(',')+')';
 try{return {data:parse(await sql(`begin;set local role ${role};select set_config('request.jwt.claim.sub',${lit(m.actor)},true);select 'RESULT='||coalesce((${call})::text,'null');commit;`)),error:null};}
 catch{return {data:null,error:{code:'42501'}};}
}
let beforeWrite:(()=>Promise<void>)|undefined;
beforeEach(()=>{
 m.actor=master;beforeWrite=undefined;m.context.mockReset().mockImplementation(async()=>({userId:m.actor,assignments:[]}));m.user.mockReset().mockImplementation(async()=>({id:m.actor}));
 m.caller.mockReset().mockImplementation((name,args)=>rpc('authenticated',name,args));
 m.internal.mockReset().mockImplementation(async(name,args)=>{if(args.command==='REUSE_OR_CREATE'&&beforeWrite)await beforeWrite();return rpc('service_role',name,args);});
 m.provider.mockReset().mockImplementation(async({roomKey})=>({success:true,data:{providerRoomRef:roomKey,url:'https://example.daily.co/'+roomKey,secret:'must-not-return'}}));
});
const count=(n:number)=>root(`select count(*) from public.live_session_rooms where cohort_id=${lit(cohortId)} and session_definition_id=${lit(id(n))} and status='ACTIVE'`);
it('assigned Master creates an exact optional-Activity room through actual caller/internal RPCs',async()=>{
 const result=await getOrCreateLiveSessionRoom({...input(702),activityInstanceId:id(160342)});
 expect(Object.keys(result).sort()).toEqual(['cohortId','id','provider','providerRoomRef','sessionDefinitionId','status'].sort());expect(result.providerRoomRef).toMatch(/^fici-[a-f0-9]{64}$/);
 expect(await count(702)).toBe(1);expect(await root(`select to_jsonb(r.created_by) from public.live_session_rooms r where id=${lit(result.id)}`)).toBe(master);
});
it('repeat/reopen returns the same mapping without provider work or new timestamps',async()=>{
 const first=await getOrCreateLiveSessionRoom(input(703));m.provider.mockClear();expect(await getOrCreateLiveSessionRoom(input(703))).toEqual(first);expect(m.provider).not.toHaveBeenCalled();expect(await count(703)).toBe(1);
});
it.each([160302,160303,160304,160305,160307,160308,160309])('canonical DB authority denies actor %s before provider work',async actor=>{
 m.actor=id(actor);await expect(getOrCreateLiveSessionRoom(input(704))).rejects.toMatchObject({code:'FORBIDDEN'});expect(m.provider).not.toHaveBeenCalled();expect(await count(704)).toBe(0);
});
it('exact foreign Cohort/Activity IDs confer no authority',async()=>{
 await expect(getOrCreateLiveSessionRoom({cohortId:id(160321),sessionDefinitionId:id(702)})).rejects.toMatchObject({code:'FORBIDDEN'});
 await expect(getOrCreateLiveSessionRoom({...input(701),activityInstanceId:id(160342)})).rejects.toMatchObject({code:'FORBIDDEN'});expect(m.provider).not.toHaveBeenCalled();
});
it('provider failure leaves no ACTIVE row and an explicit retry succeeds',async()=>{
 m.provider.mockResolvedValueOnce({success:false,error:{code:'UNAVAILABLE',message:'private diagnostic',retryable:true}});
 await expect(getOrCreateLiveSessionRoom(input(705))).rejects.toMatchObject({code:'LIVE_ROOM_UNAVAILABLE'});expect(await count(705)).toBe(0);
 expect((await getOrCreateLiveSessionRoom(input(705))).status).toBe('ACTIVE');expect(await count(705)).toBe(1);
});
it('revocation during provider await denies persistence',async()=>{
 m.provider.mockImplementation(async({roomKey})=>{await sql(`update public.role_assignments set status='inactive' where id=${lit(id(160330))};`);return {success:true,data:{providerRoomRef:roomKey}};});
 try{await expect(getOrCreateLiveSessionRoom(input(706))).rejects.toMatchObject({code:'FORBIDDEN'});expect(await count(706)).toBe(0);}
 finally{await sql(`update public.role_assignments set status='active' where id=${lit(id(160330))};`);}
});
it('six independent concurrent requests converge on one ACTIVE row and room key',async()=>{
 const results=await Promise.all(Array.from({length:6},()=>getOrCreateLiveSessionRoom(input(707))));
 expect(new Set(results.map(r=>r.id)).size).toBe(1);expect(new Set(m.provider.mock.calls.map(c=>c[0].roomKey)).size).toBe(1);expect(await count(707)).toBe(1);
});
it('internal writer rechecks revocation even after application authorization',async()=>{
 beforeWrite=async()=>{await sql(`update public.role_assignments set status='inactive' where id=${lit(id(160330))};`);};
 try{await expect(getOrCreateLiveSessionRoom(input(708))).rejects.toMatchObject({code:'LIVE_ROOM_UNAVAILABLE'});expect(await count(708)).toBe(0);}
 finally{await sql(`update public.role_assignments set status='active' where id=${lit(id(160330))};`);}
});
it('scoped organization Admin follows existing operational Cohort authority',async()=>{m.actor=id(160306);expect((await getOrCreateLiveSessionRoom(input(709))).status).toBe('ACTIVE');});
it('known room reference and raw mapping IDs cannot widen Student access',async()=>{
 const known=await getOrCreateLiveSessionRoom(input(710));m.actor=id(160305);
 await expect(getOrCreateLiveSessionRoom(input(710))).rejects.toMatchObject({code:'FORBIDDEN'});
 await expect(getOrCreateLiveSessionRoom({...input(710),providerRoomRef:known.providerRoomRef})).rejects.toMatchObject({code:'VALIDATION_ERROR'});
 await expect(sql(`begin;set local role authenticated;select set_config('request.jwt.claim.sub',${lit(m.actor)},true);select * from public.live_session_rooms where id=${lit(known.id)};rollback;`)).rejects.toThrow('Focused SQL denied');
});
it('anonymous role cannot call the context resolver',async()=>{await expect(sql(`begin;set local role anon;select public.authorize_master_live_room(${lit(cohortId)},${lit(id(702))},null);rollback;`)).rejects.toThrow('Focused SQL denied');});
it('application authentication failure cannot query or invoke provider',async()=>{m.context.mockRejectedValue(new AuthorizationError('AUTH_REQUIRED'));await expect(getOrCreateLiveSessionRoom(input(711))).rejects.toMatchObject({code:'AUTH_REQUIRED'});expect(m.caller).not.toHaveBeenCalled();expect(m.provider).not.toHaveBeenCalled();});

// M16.14: actual PostgreSQL uniqueness/transactions and the real Daily adapter.
// Only remote HTTP and request identity are substituted.
if(process.env.FICI_LIVE_ROOM_IDEMPOTENCY==='1'){
 function dailyHarness(barrier=false){
  const rooms=new Set<string>();let created=0,reads=0,release!:()=>void;
  const gate=new Promise<void>(resolve=>{release=resolve;});
  const transport=vi.fn<typeof fetch>().mockImplementation(async(url,options)=>{
   const name=String(url).split('/').at(-1)!;
   if(options?.method==='POST'){
    const body=JSON.parse(options.body as string);expect(body.privacy).toBe('private');
    if(rooms.has(body.name))return new Response('{}',{status:409});
    rooms.add(body.name);created++;
    return new Response(JSON.stringify({name:body.name,privacy:'private',url:'https://example.daily.co/'+body.name}));
   }
   if(rooms.has(name))return new Response(JSON.stringify({name,privacy:'private',url:'https://example.daily.co/'+name}));
   if(barrier&&reads<2){reads++;if(reads===2)release();await gate;}
   return new Response('{}',{status:404});
  });
  const adapter=new DailyLiveClassroomProvider({apiKey:'m1614-mock-server-only'},transport);
  m.provider.mockImplementation(context=>adapter.getOrCreateRoom(context));
  return {rooms,transport,created:()=>created,posts:()=>transport.mock.calls.filter(c=>c[1]?.method==='POST')};
 }
 it('M16.14 double start races provider POSTs through 409 recovery into one real ACTIVE mapping',async()=>{
  const h=dailyHarness(true);
  const [a,b]=await Promise.all([getOrCreateLiveSessionRoom(input(704)),getOrCreateLiveSessionRoom(input(704))]);
  expect(a).toEqual(b);expect(await count(704)).toBe(1);expect(h.posts()).toHaveLength(2);expect(h.created()).toBe(1);expect(h.rooms).toEqual(new Set([a.providerRoomRef]));
  expect(await root(`select count(*) from public.live_session_rooms where cohort_id=${lit(cohortId)} and session_definition_id=${lit(id(704))}`)).toBe(1);
 });
 it('M16.14 provider-created lost response reconciles exact name without another POST',async()=>{
  const h=dailyHarness(),normal=h.transport.getMockImplementation()!;let drop=true;
  h.transport.mockImplementation(async(url,options)=>{const response=await normal(url,options);if(drop&&options?.method==='POST'){drop=false;throw new TypeError('Simulated response loss');}return response;});
  await expect(getOrCreateLiveSessionRoom(input(706))).rejects.toMatchObject({code:'LIVE_ROOM_UNAVAILABLE'});
  expect(await count(706)).toBe(0);expect(h.created()).toBe(1);expect(h.rooms.size).toBe(1);
  const resolved=await getOrCreateLiveSessionRoom(input(706));
  expect(await count(706)).toBe(1);expect(h.posts()).toHaveLength(1);expect(h.created()).toBe(1);expect(h.rooms).toEqual(new Set([resolved.providerRoomRef]));
  h.transport.mockClear();expect(await getOrCreateLiveSessionRoom(input(706))).toEqual(resolved);expect(h.transport).not.toHaveBeenCalled();
 });
 it('M16.14 uncertain commit resolves committed mapping without any provider work',async()=>{
  const h=dailyHarness(),normal=m.internal.getMockImplementation()!;let drop=true;
  m.internal.mockImplementation(async(name,args)=>{const response=await normal(name,args);if(drop&&args.command==='REUSE_OR_CREATE'&&!response.error){drop=false;return {data:null,error:{code:'SIMULATED_RESPONSE_LOSS'}};}return response;});
  await expect(getOrCreateLiveSessionRoom(input(708))).rejects.toMatchObject({code:'LIVE_ROOM_UNAVAILABLE'});expect(await count(708)).toBe(1);expect(h.created()).toBe(1);
  const snapshot=await root(`select to_jsonb(r) from public.live_session_rooms r where cohort_id=${lit(cohortId)} and session_definition_id=${lit(id(708))} and status='ACTIVE'`);
  h.transport.mockClear();const resolved=await getOrCreateLiveSessionRoom(input(708));expect(resolved.id).toBe(snapshot.id);expect(h.transport).not.toHaveBeenCalled();expect(await count(708)).toBe(1);
  expect(await root(`select to_jsonb(r) from public.live_session_rooms r where id=${lit(resolved.id)}`)).toEqual(snapshot);
 });
 it('M16.14 expired generation is retained while replacement/retries preserve one ACTIVE mapping',async()=>{
  const old=await getOrCreateLiveSessionRoom(input(704));const h=dailyHarness();h.rooms.add(old.providerRoomRef);
  await sql(`begin;set local role service_role;select public.manage_live_room_mapping('EXPIRE',${lit(cohortId)},${lit(id(704))},'DAILY',null,${lit(master)},${lit(old.id)});commit;`);
  const history=await root(`select to_jsonb(r) from public.live_session_rooms r where id=${lit(old.id)}`);expect(history.status).toBe('EXPIRED');expect(history.provider_room_ref).toBe(old.providerRoomRef);
  const next=await getOrCreateLiveSessionRoom(input(704));expect(next.id).not.toBe(old.id);expect(next.providerRoomRef).not.toBe(old.providerRoomRef);expect(await count(704)).toBe(1);
  expect(await getOrCreateLiveSessionRoom(input(704))).toEqual(next);expect(h.created()).toBe(1);expect(h.rooms.size).toBe(2);
  expect(await root(`select to_jsonb(r) from public.live_session_rooms r where id=${lit(old.id)}`)).toEqual(history);
  expect(await root(`select count(*) from public.live_session_rooms where cohort_id=${lit(cohortId)} and session_definition_id=${lit(id(704))}`)).toBe(2);
 });
}
