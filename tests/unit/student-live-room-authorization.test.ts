import {beforeEach,expect,it,vi} from 'vitest';
vi.mock('server-only',()=>({}));
const m=vi.hoisted(()=>({context:vi.fn(),rpc:vi.fn(),client:vi.fn()}));
vi.mock('@/lib/auth/authorization',()=>({getAuthorizationContext:m.context}));
vi.mock('@/lib/db/server',()=>({createServerSupabaseClient:m.client}));
import {canJoinLiveSession} from '@/features/live-classroom/join-authorization';
const room='00000000-0000-4000-8000-000000160401';
beforeEach(()=>{m.context.mockReset().mockResolvedValue({userId:'student-a1'});m.rpc.mockReset().mockResolvedValue({data:true,error:null});m.client.mockReset().mockResolvedValue({rpc:m.rpc});});
it('uses caller-bound boolean RPC and freshly rechecks eligibility',async()=>{
 expect(await canJoinLiveSession({liveSessionRoomId:room})).toBe(true);expect(m.rpc).toHaveBeenCalledTimes(2);expect(m.rpc).toHaveBeenNthCalledWith(1,'can_join_live_session',{target_room:room});expect(m.rpc).toHaveBeenNthCalledWith(2,'can_join_live_session',{target_room:room});
});
it.each(['userId','currentUser','role','cohortId','sessionDefinitionId','providerRoomRef','provider','token','isOwner'])('rejects spoofed %s without DB access',async field=>{
 expect(await canJoinLiveSession({liveSessionRoomId:room,[field]:'spoof'})).toBe(false);expect(m.rpc).not.toHaveBeenCalled();
});
it.each([null,undefined,{},room,{providerRoomRef:'known-daily-room'},{liveSessionRoomId:'known-daily-room'}])('rejects malformed/reference-only input %j',async input=>{expect(await canJoinLiveSession(input)).toBe(false);expect(m.rpc).not.toHaveBeenCalled();});
it.each([false,null,{},'true',1,{canJoin:true}])('requires literal authorized boolean %j',async data=>{m.rpc.mockResolvedValue({data,error:null});expect(await canJoinLiveSession({liveSessionRoomId:room})).toBe(false);});
it('denies missing/inactive authentication before querying',async()=>{m.context.mockRejectedValue(Error('Account unavailable'));expect(await canJoinLiveSession({liveSessionRoomId:room})).toBe(false);expect(m.client).not.toHaveBeenCalled();});
it('denies database errors without exposing diagnostics',async()=>{m.rpc.mockResolvedValue({data:true,error:{message:'secret diagnostic'}});expect(await canJoinLiveSession({liveSessionRoomId:room})).toBe(false);});
it('denies thrown database failures',async()=>{m.rpc.mockRejectedValue(Error('private credential'));expect(await canJoinLiveSession({liveSessionRoomId:room})).toBe(false);});
it('does not reuse a prior true after enrollment revocation',async()=>{m.rpc.mockResolvedValueOnce({data:true,error:null}).mockResolvedValueOnce({data:false,error:null});expect(await canJoinLiveSession({liveSessionRoomId:room})).toBe(false);});
it('denies identity switch during eligibility resolution',async()=>{m.context.mockResolvedValueOnce({userId:'a1'}).mockResolvedValueOnce({userId:'a2'});expect(await canJoinLiveSession({liveSessionRoomId:room})).toBe(false);expect(m.rpc).toHaveBeenCalledTimes(1);});
it('does not cache permission between requests',async()=>{expect(await canJoinLiveSession({liveSessionRoomId:room})).toBe(true);m.rpc.mockResolvedValue({data:false,error:null});expect(await canJoinLiveSession({liveSessionRoomId:room})).toBe(false);});
