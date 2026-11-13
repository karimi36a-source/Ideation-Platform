import {afterEach,expect,it,vi} from 'vitest';
vi.mock('server-only',()=>({}));
import {DailyLiveClassroomProvider} from '@/features/live-classroom/providers/daily';
import {createLiveClassroomProvider} from '@/features/live-classroom/factory';
const key='daily_test_management_secret',name='fici-test-room';
const room={name,privacy:'private',url:'https://example.daily.co/'+name,config:{}};
const json=(data:unknown,status=200)=>new Response(JSON.stringify(data),{status});
const setup=()=>{const transport=vi.fn<typeof fetch>();return {transport,provider:new DailyLiveClassroomProvider({apiKey:key,timeoutMs:20},transport)};};
const join=()=>({providerRoomRef:name,userId:'00000000-0000-4000-8000-000000000001',expiresAt:Math.floor(Date.now()/1000)+60});
afterEach(()=>vi.unstubAllEnvs());
it('creates a private named room only after a missing lookup, projecting metadata only',async()=>{
 const {transport,provider}=setup();transport.mockResolvedValueOnce(json({},404)).mockResolvedValueOnce(json({...room,admin_details:{private:true}}));
 expect(await provider.getOrCreateRoom({roomKey:name})).toEqual({success:true,data:{providerRoomRef:name,url:room.url}});
 expect(transport.mock.calls[0][0]).toBe('https://api.daily.co/v1/rooms/'+name);
 expect(JSON.parse(transport.mock.calls[1][1]!.body as string)).toEqual({name,privacy:'private'});
 expect(transport.mock.calls[1][1]).toMatchObject({method:'POST',redirect:'error',cache:'no-store',headers:{Authorization:'Bearer '+key}});
});
it('reuses a matching private room without a write',async()=>{
 const {transport,provider}=setup();transport.mockResolvedValue(json(room));
 expect((await provider.getOrCreateRoom({roomKey:name})).success).toBe(true);expect(transport).toHaveBeenCalledTimes(1);
});
it('re-reads a concurrent creation conflict without replacing the room',async()=>{
 const {transport,provider}=setup();transport.mockResolvedValueOnce(json({},404)).mockResolvedValueOnce(json({},409)).mockResolvedValueOnce(json(room));
 expect((await provider.getOrCreateRoom({roomKey:name})).success).toBe(true);expect(transport).toHaveBeenCalledTimes(3);
});
it('creates a room-bound, expiring non-owner join capability without reflecting extra fields',async()=>{
 const {transport,provider}=setup();transport.mockResolvedValue(json({token:'mock.join.token',extra:'private'}));const input=join();
 expect(await provider.createJoinToken(input)).toEqual({success:true,data:{token:'mock.join.token',expiresAt:input.expiresAt}});
 expect(JSON.parse(transport.mock.calls[0][1]!.body as string)).toEqual({properties:{room_name:name,user_id:input.userId,exp:input.expiresAt,eject_at_token_exp:true,is_owner:false}});
});
it.each(['available','missing','expired'] as const)('normalizes %s configuration status',async status=>{
 const {transport,provider}=setup();transport.mockResolvedValue(status==='missing'?json({},404):json({...room,config:status==='expired'?{exp:1}:{}}));
 expect(await provider.getRoomStatus(name)).toEqual({success:true,data:{status,...(status==='available'?{url:room.url}:{})}});
});
it.each([[401,'AUTHENTICATION'],[403,'AUTHENTICATION'],[429,'RATE_LIMIT'],[408,'TIMEOUT'],[504,'TIMEOUT'],[500,'UNAVAILABLE'],[400,'REJECTED']] as const)('normalizes HTTP %s without diagnostics',async(status,code)=>{
 const {transport,provider}=setup();transport.mockResolvedValue(json({secret:key,info:'private diagnostic'},status));
 const result=await provider.getOrCreateRoom({roomKey:name});expect(result).toMatchObject({success:false,error:{code}});expect(JSON.stringify(result)).not.toContain(key);
 expect(transport).toHaveBeenCalledTimes(1);
});
it.each([new TypeError(key),new Error(key)])('sanitizes transport exceptions',async error=>{
 const {transport,provider}=setup();transport.mockRejectedValue(error);const result=await provider.createJoinToken(join());
 expect(result.success).toBe(false);expect(JSON.stringify(result)).not.toContain(key);
});
it('bounds an unresponsive transport and aborts without leaking credentials',async()=>{
 const {transport,provider}=setup();transport.mockImplementation(()=>new Promise(()=>{}));
 expect(await provider.getRoomStatus(name)).toMatchObject({success:false,error:{code:'TIMEOUT'}});
 expect((transport.mock.calls[0][1]!.signal as AbortSignal).aborted).toBe(true);
});
it.each([{...room,privacy:'public'},{...room,name:'other'},{...room,url:'https://evil.example/room'},{...room,url:room.url+'?token=private'},{...room,url:'https://example.daily.co/'+key},{...room,config:{exp:1}}])('rejects unsafe room responses',async data=>{
 const {transport,provider}=setup();transport.mockResolvedValue(json(data));expect((await provider.getOrCreateRoom({roomKey:name})).success).toBe(false);
});
it('rejects management credentials reflected in successful token responses',async()=>{
 const {transport,provider}=setup();transport.mockResolvedValue(json({token:key}));const result=await provider.createJoinToken(join());
 expect(result).toMatchObject({success:false,error:{code:'MALFORMED_RESPONSE'}});expect(JSON.stringify(result)).not.toContain(key);
});
it('rejects malformed JSON and token responses',async()=>{
 const {transport,provider}=setup();transport.mockResolvedValueOnce(new Response('not-json')).mockResolvedValueOnce(json({token:123}));
 expect(await provider.getRoomStatus(name)).toMatchObject({success:false,error:{code:'MALFORMED_RESPONSE'}});
 expect(await provider.createJoinToken(join())).toMatchObject({success:false,error:{code:'MALFORMED_RESPONSE'}});
});
it('rejects path injection, unknown authority fields, expired tokens and secret reflection before transport',async()=>{
 const {transport,provider}=setup();
 for(const input of [{roomKey:'../rooms'},{roomKey:name,projectId:'spoof'},{roomKey:key}])expect((await provider.getOrCreateRoom(input)).success).toBe(false);
 expect((await provider.createJoinToken({...join(),expiresAt:1})).success).toBe(false);
 expect((await provider.createJoinToken({...join(),isOwner:true} as ReturnType<typeof join>)).success).toBe(false);
 expect(transport).not.toHaveBeenCalled();
});
it('loads configuration only at the server composition root and fails closed when missing',async()=>{
 vi.stubEnv('DAILY_API_KEY',undefined);const transport=vi.fn<typeof fetch>();
 expect(await createLiveClassroomProvider(transport).getRoomStatus(name)).toMatchObject({success:false,error:{code:'CONFIGURATION'}});expect(transport).not.toHaveBeenCalled();
 vi.stubEnv('DAILY_API_KEY',key);transport.mockResolvedValue(json(room));expect((await createLiveClassroomProvider(transport).getRoomStatus(name)).success).toBe(true);
});


