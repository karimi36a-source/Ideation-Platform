import {beforeEach,expect,it,vi} from 'vitest';
vi.mock('server-only',()=>({}));
const m=vi.hoisted(()=>({auth:vi.fn(),rpc:vi.fn(),from:vi.fn(),select:vi.fn(),eq:vi.fn(),order:vi.fn(),is:vi.fn(),limit:vi.fn()}));
vi.mock('@/lib/auth/authorization',async original=>({...await original<typeof import('@/lib/auth/authorization')>(),getAuthorizationContext:m.auth}));
vi.mock('@/lib/db/server',()=>({createServerSupabaseClient:async()=>m}));
import {AuthorizationError} from '@/lib/auth/authorization';
import {markNotificationRead} from '@/features/notifications/read';
import {listMyNotifications} from '@/features/notifications/list';
const actor='00000000-0000-4000-8000-000000006004',other='00000000-0000-4000-8000-000000006006',id='aaaaaaaa-0000-4000-8000-000000000001';
const state={id,read_at:'2026-11-06T01:00:00.123456+00:00'};
beforeEach(()=>{vi.resetAllMocks();m.auth.mockResolvedValue({userId:actor});m.rpc.mockResolvedValue({data:state,error:null});});
it('uses only the exact canonical notification ID and user-scoped RPC',async()=>{
 expect(await markNotificationRead(id.toUpperCase())).toEqual(state);
 expect(m.rpc).toHaveBeenCalledExactlyOnceWith('mark_notification_read',{target_notification:id});expect(m.from).not.toHaveBeenCalled();
});
it('returns the original canonical timestamp on repeated read',async()=>{
 expect(await markNotificationRead(id)).toEqual(state);expect(await markNotificationRead(id)).toEqual(state);
});
it.each([null,undefined,'bad','',[],{notificationId:id},{notificationId:id,recipientUserId:other},{id,read_at:null},{id,read_at:'2000-01-01'},{id,title:'rewrite'},{id,notification_type:'ARTIFACT_APPROVED'},{id,entity_id:other}])('rejects malformed ID or arbitrary patch %#',async value=>{
 await expect(markNotificationRead(value)).rejects.toMatchObject({code:'VALIDATION_ERROR'});expect(m.rpc).not.toHaveBeenCalled();
});
it('fails unauthenticated with standard semantics',async()=>{
 m.auth.mockRejectedValue(new AuthorizationError('AUTH_REQUIRED'));await expect(markNotificationRead(id)).rejects.toMatchObject({code:'AUTH_REQUIRED'});expect(m.rpc).not.toHaveBeenCalled();
});
it.each(['ADMIN','MASTER','MENTOR','team_lead','member'])('does not infer mutation authority from role %s',async role=>{
 m.auth.mockResolvedValue({userId:other,assignments:[{roleCode:role}]});m.rpc.mockResolvedValue({data:null,error:{code:'42501',message:'PRIVATE_DETAIL'}});
 await expect(markNotificationRead(id)).rejects.toMatchObject({code:'NOT_FOUND',message:'Resource unavailable.'});expect(m.from).not.toHaveBeenCalled();
});
it('uses the same safe failure for nonexistent or inaccessible records',async()=>{
 m.rpc.mockResolvedValue({data:null,error:{code:'42501'}});await expect(markNotificationRead(id)).rejects.toMatchObject({code:'NOT_FOUND'});
});
it.each([{...state,id:other},{...state,read_at:null},{...state,recipient_user_id:actor},{...state,title:'source'},null])('rejects malformed/mismatched or excessive response %#',async data=>{
 m.rpc.mockResolvedValue({data,error:null});await expect(markNotificationRead(id)).rejects.toMatchObject({code:'NOT_FOUND'});
});
it('withholds mutation request on pre-RPC identity switch',async()=>{
 m.auth.mockResolvedValueOnce({userId:actor}).mockResolvedValue({userId:other});await expect(markNotificationRead(id)).rejects.toMatchObject({code:'NOT_FOUND'});expect(m.rpc).not.toHaveBeenCalled();
});
it('withholds response after an in-flight identity switch',async()=>{
 m.auth.mockResolvedValueOnce({userId:actor}).mockResolvedValueOnce({userId:actor}).mockResolvedValueOnce({userId:other});await expect(markNotificationRead(id)).rejects.toMatchObject({code:'NOT_FOUND'});
});
it('listing reflects read state and unread-only omits the marked record',async()=>{
 const row={id,recipient_user_id:actor,notification_type:'MEMBER_ADDED',title:'Notification',body:'A safe summary.',entity_type:'share',entity_id:other,read_at:null as string|null,created_at:'2026-11-06T00:00:00Z'};
 let unread=false;
 m.from.mockImplementation(()=>{unread=false;return m;});for(const name of ['select','eq','order'] as const)m[name].mockReturnValue(m);
 m.is.mockImplementation(()=>{unread=true;return m;});m.limit.mockImplementation(async()=>({data:unread&&row.read_at!==null?[]:[{...row}],error:null}));
 m.rpc.mockImplementation(async()=>{row.read_at=state.read_at;return {data:state,error:null};});
 expect((await listMyNotifications({unreadOnly:true})).items).toHaveLength(1);
 await markNotificationRead(id);
 expect((await listMyNotifications()).items[0].read_at).toBe(state.read_at);
 expect((await listMyNotifications({unreadOnly:true})).items).toHaveLength(0);
});
