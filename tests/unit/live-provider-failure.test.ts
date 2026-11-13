import {afterEach,beforeEach,expect,it,vi} from 'vitest';
vi.mock('server-only',()=>({}));
const m=vi.hoisted(()=>({auth:vi.fn()}));
vi.mock('@/lib/auth/authorization',async()=>{const a=await vi.importActual<typeof import('@/lib/auth/authorization')>('@/lib/auth/authorization');return {...a,getAuthorizationContext:m.auth};});
import {createMasterLiveRoomOperation} from '@/features/live-classroom/room';
import {DailyLiveClassroomProvider} from '@/features/live-classroom/providers/daily';
import {recordLiveClassroomFailure} from '@/features/live-classroom/diagnostics';
const id=(n:number)=>`00000000-0000-4000-8000-${String(n).padStart(12,'0')}`;
const input={cohortId:id(1),sessionDefinitionId:id(2)},key='fici-'+'a'.repeat(64),secret='mock_server_secret';
const context={actorId:id(4),...input,roomKey:key};
const row={id:id(3),cohort_id:id(1),session_definition_id:id(2),provider:'DAILY' as const,provider_room_ref:key,status:'ACTIVE' as const,created_by:id(4),created_at:'2026-11-11T00:00:00Z',updated_at:'2026-11-11T00:00:00Z',ended_at:null};
let persisted:typeof row|null,rooms:Set<string>,transport:ReturnType<typeof vi.fn<typeof fetch>>,write:ReturnType<typeof vi.fn<()=>Promise<typeof row>>>,warn:ReturnType<typeof vi.spyOn>;
const education=Object.freeze({project:'unchanged',activity:'active',artifactVersion:'DRAFT',workspace:'private',chat:'available'});
beforeEach(()=>{
 persisted=null;rooms=new Set();m.auth.mockReset().mockResolvedValue({userId:id(4)});warn=vi.spyOn(console,'warn').mockImplementation(()=>{});
 transport=vi.fn<typeof fetch>().mockImplementation(async(url,options)=>{
  if(options?.method==='POST'){const body=JSON.parse(options.body as string);expect(body).toEqual({name:key,privacy:'private'});rooms.add(body.name);return new Response(JSON.stringify({name:key,privacy:'private',url:'https://pilot.daily.co/'+key}));}
  return rooms.has(key)?new Response(JSON.stringify({name:key,privacy:'private',url:'https://pilot.daily.co/'+key})):new Response('{}',{status:404});
 });
 write=vi.fn().mockImplementation(async()=>{persisted=row;return row;});
});
afterEach(()=>{vi.restoreAllMocks();});
function operation(){return createMasterLiveRoomOperation({authorize:async()=>context,repository:()=>({findActive:async()=>persisted,write}) ,provider:()=>new DailyLiveClassroomProvider({apiKey:secret,timeoutMs:10},transport)});}
const posts=()=>transport.mock.calls.filter(c=>c[1]?.method==='POST');
it('provider-created room + failed mapping save reconciles on explicit retry without duplicate provider room',async()=>{
 write.mockRejectedValueOnce(Error(secret+' database diagnostic'));
 const call=operation();await expect(call(input)).rejects.toThrow('Live classroom room unavailable.');expect(persisted).toBeNull();expect(rooms.size).toBe(1);
 expect((await call(input)).id).toBe(row.id);expect(posts()).toHaveLength(1);expect(rooms.size).toBe(1);expect(persisted).toEqual(row);expect(education.activity).toBe('active');
 expect(warn.mock.calls.map(([line])=>JSON.parse(String(line)))).toContainEqual(expect.objectContaining({event:'LIVE_FAILURE',phase:'MAPPING_SAVE',code:'UNAVAILABLE'}));expect(JSON.stringify(warn.mock.calls)).not.toContain(secret);
});
it('lost mapping commit response retries FICI first and does not call or replace provider room',async()=>{
 write.mockImplementationOnce(async()=>{persisted=row;throw Error('commit response lost '+secret);});const call=operation();await expect(call(input)).rejects.toThrow('Live classroom room unavailable.');transport.mockClear();expect((await call(input)).id).toBe(row.id);expect(transport).not.toHaveBeenCalled();expect(write).toHaveBeenCalledTimes(1);
});
it('room-create response timeout after provider creation reuses same deterministic room on retry',async()=>{
 const normal=transport.getMockImplementation()!;let lost=true;
 transport.mockImplementation(async(url,options)=>{if(options?.method==='POST'&&lost){lost=false;rooms.add(key);return new Promise(()=>{});}return normal(url,options);});
 const call=operation();await expect(call(input)).rejects.toThrow('Live classroom room unavailable.');expect(write).not.toHaveBeenCalled();expect(persisted).toBeNull();expect((await call(input)).id).toBe(row.id);expect(posts()).toHaveLength(1);expect(rooms.size).toBe(1);expect(warn.mock.calls.map(([line])=>JSON.parse(String(line)))).toContainEqual(expect.objectContaining({event:'LIVE_FAILURE',phase:'PROVIDER',code:'TIMEOUT'}));
});
it.each(['5xx','malformed-json','invalid-room'])('provider %s leaves canonical state untouched and permits explicit retry',async mode=>{
 const normal=transport.getMockImplementation()!;let failed=false;
 transport.mockImplementation(async(url,options)=>{if(options?.method==='POST'&&!failed){failed=true;return mode==='5xx'?new Response(secret,{status:503}):mode==='malformed-json'?new Response('not JSON '+secret):new Response(JSON.stringify({name:'wrong',privacy:'private',url:'https://pilot.daily.co/wrong'}));}return normal(url,options);});
 const before=JSON.stringify(education),call=operation();await expect(call(input)).rejects.toThrow('Live classroom room unavailable.');expect(write).not.toHaveBeenCalled();expect(persisted).toBeNull();expect(JSON.stringify(education)).toBe(before);expect((await call(input)).id).toBe(row.id);expect(JSON.stringify(warn.mock.calls)).not.toContain(secret);
});
it('safe diagnostics reject raw exception, URL, token and unverified identity/content',()=>{recordLiveClassroomFailure('https://secret.example/?token=private',{message:secret});recordLiveClassroomFailure('PROVIDER','TIMEOUT');expect(warn.mock.calls.map(([line])=>{const event=JSON.parse(String(line));expect(event.actorId).toBeUndefined();expect(event.correlationId).toMatch(/^[a-f0-9-]{36}$/);return {phase:event.phase,code:event.code};})).toEqual([{phase:'PROVIDER',code:'UNKNOWN'},{phase:'PROVIDER',code:'TIMEOUT'}]);expect(JSON.stringify(warn.mock.calls)).not.toContain(secret);});
it('logging failure cannot override original operation failure or corrupt state',async()=>{warn.mockImplementation(()=>{throw Error('logging unavailable');});write.mockRejectedValueOnce(Error(secret));await expect(operation()(input)).rejects.toThrow('Live classroom room unavailable.');expect(persisted).toBeNull();});

