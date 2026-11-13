import {beforeEach,expect,it,vi} from 'vitest';
vi.mock('server-only',()=>({}));
const {identity}=vi.hoisted(()=>({identity:vi.fn()}));
vi.mock('@/lib/auth/authorization',async original=>({...await original<typeof import('@/lib/auth/authorization')>(),getAuthorizationContext:identity}));
import {AuthorizationError} from '@/lib/auth/authorization';
import {createMasterLiveRoomOperation} from '@/features/live-classroom/room';
const id=(n:number)=>`00000000-0000-4000-8000-${String(n).padStart(12,'0')}`;
const input={cohortId:id(1),sessionDefinitionId:id(2)};
const key='fici-'+'a'.repeat(64);
const context={actorId:id(4),...input,roomKey:key};
const mapping={id:id(3),cohort_id:id(1),session_definition_id:id(2),provider:'DAILY' as const,provider_room_ref:key,status:'ACTIVE' as const,created_by:id(4),created_at:'2026-11-11T10:00:00Z',updated_at:'2026-11-11T10:00:00Z',ended_at:null};
const authorize=vi.fn(),findActive=vi.fn(),write=vi.fn(),getOrCreateRoom=vi.fn(),provider=vi.fn();
const repository=vi.fn(()=>({findActive,write}));
const operation=createMasterLiveRoomOperation({authorize,repository,provider});
beforeEach(()=>{
 identity.mockReset().mockResolvedValue({userId:id(4),assignments:[]});authorize.mockReset().mockResolvedValue(context);
 findActive.mockReset().mockResolvedValue(null);write.mockReset().mockResolvedValue(mapping);
 getOrCreateRoom.mockReset().mockResolvedValue({success:true,data:{providerRoomRef:key,url:'https://example.daily.co/'+key}});
 provider.mockReset().mockReturnValue({getOrCreateRoom});repository.mockClear();
});
it('creates through provider and canonical repository, projecting only safe metadata',async()=>{
 expect(await operation(input)).toEqual({id:id(3),provider:'DAILY',providerRoomRef:key,status:'ACTIVE',...input});
 expect(getOrCreateRoom).toHaveBeenCalledExactlyOnceWith({roomKey:key});expect(write.mock.calls[0][0]).toMatchObject({command:'REUSE_OR_CREATE',providerRoomRef:key});
});
it('reuses an active canonical mapping without any provider call or write',async()=>{
 findActive.mockResolvedValue(mapping);await operation(input);expect(provider).not.toHaveBeenCalled();expect(write).not.toHaveBeenCalled();expect(authorize).toHaveBeenCalledTimes(2);
});
it('preserves optional exact Activity identity for authorization only',async()=>{await operation({...input,activityInstanceId:id(8)});expect(authorize).toHaveBeenCalledWith({...input,activityInstanceId:id(8)});expect(getOrCreateRoom).toHaveBeenCalledWith({roomKey:key});});
it.each(['roomId','roomKey','providerRoomRef','actor','ownerId','workspaceId','provider','isOwner','role','token'])('rejects unknown/authority field %s',async field=>{
 await expect(operation({...input,[field]:'spoof'})).rejects.toMatchObject({code:'VALIDATION_ERROR'});expect(authorize).not.toHaveBeenCalled();expect(repository).not.toHaveBeenCalled();
});
it('requires authentication before any lookup',async()=>{identity.mockRejectedValue(new AuthorizationError('AUTH_REQUIRED'));await expect(operation(input)).rejects.toMatchObject({code:'AUTH_REQUIRED'});expect(authorize).not.toHaveBeenCalled();});
it.each(['unrelated Master','Student','revoked Master','inactive account','foreign session','foreign Activity'])('respects database %s denial before provider work',async()=>{
 authorize.mockRejectedValue(new AuthorizationError('FORBIDDEN'));await expect(operation(input)).rejects.toMatchObject({code:'FORBIDDEN'});expect(provider).not.toHaveBeenCalled();expect(repository).not.toHaveBeenCalled();
});
it.each([{...context,actorId:id(9)},{...context,cohortId:id(9)},{...context,sessionDefinitionId:id(9)},{...context,token:'secret'}])('fails closed on invalid context projection',async ctx=>{authorize.mockResolvedValue(ctx);await expect(operation(input)).rejects.toMatchObject({code:'FORBIDDEN'});expect(provider).not.toHaveBeenCalled();});
it.each(['TIMEOUT','NETWORK','UNAVAILABLE','RATE_LIMIT','MALFORMED_RESPONSE'])('provider %s failure never registers ACTIVE state',async code=>{
 getOrCreateRoom.mockResolvedValue({success:false,error:{code,message:'secret diagnostic',retryable:true}});await expect(operation(input)).rejects.toMatchObject({code:'LIVE_ROOM_UNAVAILABLE',message:'Live classroom room unavailable.'});expect(write).not.toHaveBeenCalled();
});
it('sanitizes thrown provider diagnostics',async()=>{getOrCreateRoom.mockRejectedValue(Error('DAILY_API_KEY=secret'));await expect(operation(input)).rejects.toThrow('Live classroom room unavailable.');expect(write).not.toHaveBeenCalled();});
it('rejects a provider reference that differs from the server-derived key',async()=>{getOrCreateRoom.mockResolvedValue({success:true,data:{providerRoomRef:'arbitrary',url:'https://example.daily.co/arbitrary'}});await expect(operation(input)).rejects.toMatchObject({code:'LIVE_ROOM_UNAVAILABLE'});expect(write).not.toHaveBeenCalled();});
it('does not persist if assignment is revoked while provider awaits',async()=>{getOrCreateRoom.mockImplementation(async()=>{authorize.mockRejectedValue(new AuthorizationError('FORBIDDEN'));return {success:true,data:{providerRoomRef:key}};});await expect(operation(input)).rejects.toMatchObject({code:'FORBIDDEN'});expect(write).not.toHaveBeenCalled();});
it('denies an identity switch after lookup',async()=>{findActive.mockImplementation(async()=>{identity.mockResolvedValue({userId:id(9)});return mapping;});await expect(operation(input)).rejects.toMatchObject({code:'FORBIDDEN'});expect(provider).not.toHaveBeenCalled();});
it('does not persist against a changed room generation',async()=>{authorize.mockResolvedValueOnce(context).mockResolvedValue({...context,roomKey:'fici-'+'b'.repeat(64)});await expect(operation(input)).rejects.toMatchObject({code:'LIVE_ROOM_UNAVAILABLE'});expect(provider).not.toHaveBeenCalled();});
it('does not expose repository failure diagnostics',async()=>{write.mockRejectedValue(Error('private database detail'));await expect(operation(input)).rejects.toThrow('Live classroom room unavailable.');});
it('concurrent calls use the same provider key and canonical mapping result',async()=>{
 const results=await Promise.all([operation(input),operation(input),operation(input)]);expect(new Set(results.map(r=>r.id)).size).toBe(1);expect(new Set(getOrCreateRoom.mock.calls.map(c=>c[0].roomKey))).toEqual(new Set([key]));
});
