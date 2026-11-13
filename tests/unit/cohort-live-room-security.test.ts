import {afterEach,beforeEach,expect,it,vi} from 'vitest';
vi.mock('server-only',()=>({}));
const m=vi.hoisted(()=>({auth:vi.fn(),rpc:vi.fn()}));
vi.mock('@/lib/auth/authorization',async()=>{const actual=await vi.importActual<typeof import('@/lib/auth/authorization')>('@/lib/auth/authorization');return {...actual,getAuthorizationContext:m.auth};});
vi.mock('@/lib/db/server',()=>({createServerSupabaseClient:async()=>({rpc:m.rpc})}));
import {AuthorizationError} from '@/lib/auth/authorization';
import {getLiveClassroomJoin} from '@/features/live-classroom/classroom';
import {getLiveSessionJoinToken} from '@/features/live-classroom/join-token';
import {DailyLiveClassroomProvider} from '@/features/live-classroom/providers/daily';
import {POST} from '@/app/api/live-classroom/join/route';
const id=(n:number)=>`00000000-0000-4000-8000-${String(n).padStart(12,'0')}`;
const room=id(160501),actor=id(160401),key='m168_mock_server_secret',name='canonical-private-room';
let account:boolean,enrolled:boolean,authenticated:boolean,role:'STUDENT'|'MASTER',transport:ReturnType<typeof vi.fn<typeof fetch>>;
const calls=()=>transport.mock.calls.filter(([url])=>String(url).endsWith('/meeting-tokens'));
const request=(input:unknown)=>new Request('https://fici.test/api/live-classroom/join',{method:'POST',headers:{origin:'https://fici.test','Content-Type':'application/json'},body:JSON.stringify(input)});
beforeEach(()=>{
 vi.clearAllMocks();vi.useFakeTimers();vi.setSystemTime(new Date('2026-11-11T18:00:00Z'));account=true;enrolled=true;authenticated=true;role='STUDENT';
 vi.stubEnv('DAILY_API_KEY',key);
 m.auth.mockImplementation(async()=>{if(!authenticated||!account)throw Error('Private authentication diagnostic');return {userId:actor,assignments:[]};});
 m.rpc.mockImplementation(async(fn,args)=>{
  if(!authenticated||!account||!enrolled||args.target_room!==room)return {data:null,error:{code:'42501'}};
  if(fn==='can_join_live_session')return {data:true,error:null};
  if(fn!=='authorize_live_session_join')throw Error('Unexpected RPC');
  return {data:{liveSessionRoomId:room,providerRoomRef:name,userId:actor,displayName:'Canonical identity',participantRole:role},error:null};
 });
 transport=vi.fn<typeof fetch>().mockImplementation(async url=>new Response(JSON.stringify(String(url).endsWith('/meeting-tokens')?{token:'mock.scoped.token'}:{name,privacy:'private',url:'https://pilot.daily.co/'+name})));
 vi.stubGlobal('fetch',transport);
});
afterEach(()=>{vi.useRealTimers();vi.unstubAllGlobals();vi.unstubAllEnvs();});
it.each(['STUDENT','MASTER'] as const)('real service/adapter pipeline binds canonical %s to private exact room without owner privilege',async canonicalRole=>{
 role=canonicalRole;const response=await POST(request({liveSessionRoomId:room}));expect(response.status).toBe(200);const output=await response.json();expect(output.token).toBe('mock.scoped.token');expect(output.expiresAt).toBe(Math.floor(Date.now()/1000)+60);
 expect(JSON.parse(calls()[0][1]!.body as string)).toEqual({properties:{room_name:name,user_id:actor,user_name:'Canonical identity',exp:output.expiresAt,eject_at_token_exp:true,is_owner:false}});
 expect(JSON.stringify(output)).not.toContain(key);expect(response.headers.get('Cache-Control')).toContain('no-store');
});
it('unauthenticated endpoint denies before any provider lookup/issuance',async()=>{authenticated=false;const response=await POST(request({liveSessionRoomId:room}));expect(response.status).toBe(403);expect(transport).not.toHaveBeenCalled();expect(m.rpc).not.toHaveBeenCalled();expect(await response.text()).not.toContain('diagnostic');});
it('cross-Cohort caller denied by canonical resolver before provider',async()=>{enrolled=false;expect((await POST(request({liveSessionRoomId:room}))).status).toBe(403);expect(transport).not.toHaveBeenCalled();});
it.each(['cohortId','userId','role','participantRole','is_owner','isOwner','moderator','providerRoomRef','roomName','expiresAt','ttl','token','eject_at_token_exp'])('endpoint rejects forged %s without invoking provider',async field=>{expect((await POST(request({liveSessionRoomId:room,[field]:'MASTER'}))).status).toBe(403);expect(transport).not.toHaveBeenCalled();expect(m.rpc).not.toHaveBeenCalled();});
it.each([{providerRoomRef:name},{roomName:name},{liveSessionRoomId:name},{liveSessionRoomId:id(999999)}])('guessed provider/mapping identifiers do not authorize %j',async input=>{expect((await POST(request(input))).status).toBe(403);expect(transport).not.toHaveBeenCalled();});
it('inactive account receives no capability',async()=>{account=false;expect((await POST(request({liveSessionRoomId:room}))).status).toBe(403);expect(transport).not.toHaveBeenCalled();});
it('every new token request rechecks enrollment after a prior success',async()=>{expect((await POST(request({liveSessionRoomId:room}))).status).toBe(200);enrolled=false;transport.mockClear();expect((await POST(request({liveSessionRoomId:room}))).status).toBe(403);expect(transport).not.toHaveBeenCalled();});
it('revocation during provider call withholds token from requester',async()=>{transport.mockImplementation(async url=>{if(String(url).endsWith('/meeting-tokens')){enrolled=false;return new Response(JSON.stringify({token:'must.not.return'}));}return new Response(JSON.stringify({name,privacy:'private',url:'https://pilot.daily.co/'+name}));});const response=await POST(request({liveSessionRoomId:room}));expect(response.status).toBe(403);expect(await response.text()).not.toContain('must.not.return');});
it('expired provider token cannot be returned even if issuance consumed its whole lifetime',async()=>{transport.mockImplementation(async url=>{if(String(url).endsWith('/meeting-tokens')){vi.setSystemTime(Date.now()+61000);return new Response(JSON.stringify({token:'expired.capability'}));}return new Response(JSON.stringify({name,privacy:'private',url:'https://pilot.daily.co/'+name}));});const response=await POST(request({liveSessionRoomId:room}));expect(response.status).toBe(403);expect(await response.text()).not.toContain('expired.capability');});
it('exact expiry boundary is rejected before provider transport',async()=>{const provider=new DailyLiveClassroomProvider({apiKey:key},transport);expect(await provider.createJoinToken({providerRoomRef:name,userId:actor,expiresAt:Math.floor(Date.now()/1000)})).toMatchObject({success:false,error:{code:'INVALID_INPUT'}});expect(transport).not.toHaveBeenCalled();});
it('expired/known token cannot be submitted as a capability to bypass fresh FICI authorization',async()=>{enrolled=false;await expect(getLiveSessionJoinToken({liveSessionRoomId:room,token:'old.expired.token'})).rejects.toMatchObject({code:'VALIDATION_ERROR'});expect(transport).not.toHaveBeenCalled();expect(m.rpc).not.toHaveBeenCalled();});
it('public provider room drift fails closed before issuance in classroom transport',async()=>{transport.mockResolvedValue(new Response(JSON.stringify({name,privacy:'public',url:'https://pilot.daily.co/'+name})));await expect(getLiveClassroomJoin({liveSessionRoomId:room})).rejects.toThrow();expect(calls()).toHaveLength(0);});
it('provider failure diagnostics and reflected management credentials never reach client',async()=>{transport.mockResolvedValue(new Response(JSON.stringify({private:key}),{status:500}));const response=await POST(request({liveSessionRoomId:room}));expect(response.status).toBe(403);expect(await response.text()).not.toContain(key);expect(calls()).toHaveLength(0);});

it('direct M16.5 operation rejects missing authentication without canonical lookup or provider request',async()=>{m.auth.mockRejectedValue(new AuthorizationError('AUTH_REQUIRED'));await expect(getLiveSessionJoinToken({liveSessionRoomId:room})).rejects.toMatchObject({code:'AUTH_REQUIRED'});expect(m.rpc).not.toHaveBeenCalled();expect(transport).not.toHaveBeenCalled();});
it('account revocation after a successful join blocks every new capability request',async()=>{expect((await POST(request({liveSessionRoomId:room}))).status).toBe(200);account=false;transport.mockClear();expect((await POST(request({liveSessionRoomId:room}))).status).toBe(403);expect(transport).not.toHaveBeenCalled();});

it('M16.15 enrollment revocation denies new access before old expiry and at its exact expiry boundary',async()=>{
 const issuedAt=Date.now();const response=await POST(request({liveSessionRoomId:room}));expect(response.status).toBe(200);
 const capability=await response.json();
 const claims=JSON.parse(calls()[0][1]!.body as string).properties;
 expect(claims.exp).toBe(issuedAt/1000+60);expect(claims.eject_at_token_exp).toBe(true);expect(claims.room_name).toBe(name);
 enrolled=false;transport.mockClear();m.rpc.mockClear();
 vi.setSystemTime(issuedAt+59000);
 expect((await POST(request({liveSessionRoomId:room}))).status).toBe(403);
 expect(m.rpc).toHaveBeenCalledWith('authorize_live_session_join',{target_room:room});
 expect(transport).not.toHaveBeenCalled();
 // No provider revocation is fabricated: old immutable claims still expire
 // at their original exp. Daily enforces expiry/ejection under its contract.
 expect(capability.expiresAt).toBe(claims.exp);
 vi.setSystemTime(issuedAt+60000);
 expect((await POST(request({liveSessionRoomId:room,token:capability.token}))).status).toBe(403);
 expect((await POST(request({liveSessionRoomId:room}))).status).toBe(403);
 expect(transport).not.toHaveBeenCalled();
});
it('M16.15 account loss during provider issuance withholds the capability',async()=>{
 transport.mockImplementation(async url=>{
  if(String(url).endsWith('/meeting-tokens')){account=false;return new Response(JSON.stringify({token:'must.not.escape'}));}
  return new Response(JSON.stringify({name,privacy:'private',url:'https://pilot.daily.co/'+name}));
 });
 const response=await POST(request({liveSessionRoomId:room}));expect(response.status).toBe(403);
 expect(await response.text()).not.toContain('must.not.escape');
});
it.each(['teamId','userId','role','providerRoomRef'])('M16.15 client %s cannot override revoked canonical scope',async field=>{
 enrolled=false;expect((await POST(request({liveSessionRoomId:room,[field]:'MASTER'}))).status).toBe(403);
 expect(m.rpc).not.toHaveBeenCalled();expect(transport).not.toHaveBeenCalled();
});
it('M16.15 successful token issuance invokes only existing read authorization RPCs and never persists capability',async()=>{
 const response=await POST(request({liveSessionRoomId:room}));expect(response.status).toBe(200);
 const capability=await response.json();
 expect(m.rpc.mock.calls.length).toBeGreaterThan(0);
 expect(m.rpc.mock.calls.every(([fn])=>['authorize_live_session_join','can_join_live_session'].includes(fn))).toBe(true);
 expect(JSON.stringify(m.rpc.mock.calls)).not.toContain(capability.token);
});
