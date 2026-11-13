vi.mock('@/features/notifications/email-delivery',()=>({scheduleCommittedNotificationEmails:vi.fn(async()=>{})}));
import {beforeEach,expect,it,vi} from 'vitest';
vi.mock('server-only',()=>({}));
const m=vi.hoisted(()=>({rpc:vi.fn(),client:vi.fn()}));
vi.mock('@supabase/supabase-js',()=>({createClient:m.client}));
vi.mock('@/lib/validation/env-server',()=>({getServerEnv:()=>({NEXT_PUBLIC_SUPABASE_URL:'https://example.test',SUPABASE_SECRET_KEY:'test-server-only'})}));
import {createNotification,NotificationCreationError} from '@/features/notifications/service';
import {listNotificationTypeDefinitions} from '@/features/notifications/type-registry';
const id=(n:number)=>'00000000-0000-4000-8000-'+String(n).padStart(12,'0');
const input={notificationType:'MEMBER_ADDED',recipientContext:{sourceId:id(1)},formatterInput:{},entityReference:{entityType:'team',entityId:id(2)},idempotencyKey:'domain-event:1'};
const row={id:id(3),recipient_user_id:id(4),notification_type:'MEMBER_ADDED',title:'Team membership updated',body:'You have been added to a Team.',entity_type:'team',entity_id:id(2),read_at:null,created_at:'2026-11-06T00:00:00Z'};
beforeEach(()=>{m.rpc.mockReset().mockResolvedValue({data:row,error:null});m.client.mockReset().mockReturnValue({rpc:m.rpc});});
it.each(listNotificationTypeDefinitions())('uses registry formatting/strategy for $code, canonical recipient returned by database',async d=>{
 const value={...input,notificationType:d.code,entityReference:{entityType:d.targetEntityType,entityId:id(2)}};
 m.rpc.mockResolvedValue({data:{...row,notification_type:d.code,entity_type:d.targetEntityType,title:d.titleFormatter({}),body:d.bodyFormatter({})},error:null});
 const saved=await createNotification(value);expect(saved.recipient_user_id).toBe(id(4));expect(saved.read_at).toBeNull();
 expect(m.rpc).toHaveBeenCalledWith('create_domain_notification',{input:{...value,title:d.titleFormatter({}),body:d.bodyFormatter({}),recipientStrategy:d.recipientResolution.strategy}});
 expect(m.rpc.mock.calls[0][1].input).not.toHaveProperty('recipientUserId');
});
it.each([
 {...input,notificationType:'FAKE_APPROVAL'}, {...input,recipientUserId:id(9)}, {...input,recipientContext:{sourceId:id(1),recipientUserId:id(9)}},
 {...input,title:'forged'}, {...input,body:'raw private content'}, {...input,formatterInput:{artifactBody:'private'}},
 {...input,entityReference:{entityType:'share',entityId:id(2)}}, {...input,entityReference:undefined},
 {...input,entityReference:{entityType:'team',entityId:'bad'}}, {...input,id:id(8)}, {...input,read_at:'now'}, {...input,created_at:'now'},
 {...input,idempotencyKey:''}, {...input,recipientContext:{sourceId:'bad'}}, {...input,idempotencyKey:'x'.repeat(161)},
])('rejects malformed/spoofed input before privileged I/O',async value=>{
 await expect(createNotification(value)).rejects.toMatchObject({code:'INVALID_NOTIFICATION'});expect(m.client).not.toHaveBeenCalled();
});
it('maps durable identity conflict safely without database internals',async()=>{
 m.rpc.mockResolvedValue({data:null,error:{code:'23505',message:'PRIVATE_DETAIL'}});
 await expect(createNotification(input)).rejects.toMatchObject({code:'NOTIFICATION_CONFLICT',message:'Notification creation unavailable'});
});
it.each(['42501','22023','23503'])('denied canonical resolution %s returns safe failure',async code=>{
 m.rpc.mockResolvedValue({data:null,error:{code,message:'PRIVATE_DETAIL'}});await expect(createNotification(input)).rejects.toBeInstanceOf(NotificationCreationError);
});
it('rejects a transport result with a mismatched canonical target or format',async()=>{
 for(const change of [{entity_id:id(9)},{title:'raw'},{notification_type:'ARTIFACT_APPROVED'},{recipient_user_id:null}]){
  m.rpc.mockResolvedValue({data:{...row,...change},error:null});await expect(createNotification(input)).rejects.toMatchObject({code:'NOTIFICATION_UNAVAILABLE'});
 }
});
it('requires exact domain context and does not accept delivery callbacks',async()=>{
 await expect(createNotification({...input,onRealtime:()=>{throw Error('provider');}})).rejects.toMatchObject({code:'INVALID_NOTIFICATION'});
});
it('COMMENT_RECEIVED accepts exact Share navigation without accepting a Team target',async()=>{
 const d=listNotificationTypeDefinitions().find(v=>v.code==='COMMENT_RECEIVED')!;
 const value={...input,notificationType:d.code,entityReference:{entityType:'share',entityId:id(2)}};
 m.rpc.mockResolvedValue({data:{...row,notification_type:d.code,entity_type:'share',title:d.titleFormatter({}),body:d.bodyFormatter({})},error:null});
 expect((await createNotification(value)).entity_type).toBe('share');
 m.client.mockClear();await expect(createNotification({...value,entityReference:{entityType:'team',entityId:id(2)}})).rejects.toMatchObject({code:'INVALID_NOTIFICATION'});expect(m.client).not.toHaveBeenCalled();
});
