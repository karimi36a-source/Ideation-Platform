import {beforeEach,expect,it,vi} from 'vitest';
import {readFileSync} from 'node:fs';
vi.mock('server-only',()=>({}));
const m=vi.hoisted(()=>({after:vi.fn(),read:vi.fn(),send:vi.fn(),provider:vi.fn(),log:vi.fn(),rpc:vi.fn(),client:vi.fn()}));
vi.mock('next/server',()=>({after:m.after}));
vi.mock('@supabase/supabase-js',()=>({createClient:m.client}));
vi.mock('@/lib/validation/env-server',()=>({getServerEnv:()=>({NEXT_PUBLIC_SUPABASE_URL:'https://example.test',SUPABASE_SECRET_KEY:'test-private-infrastructure'})}));
vi.mock('@/features/email/factory',()=>({createEmailProvider:m.provider}));
import {createNotificationEmailDelivery,scheduleCommittedNotificationEmails} from '@/features/notifications/email-delivery';
import {createEmailTemplateRegistry} from '@/features/email/templates';
import {notificationEmailTemplate} from '@/features/notifications/email-template';
import {createNotification} from '@/features/notifications/service';
import {ResendEmailProvider} from '@/features/email/providers/resend';
const id=(n:number)=>'00000000-0000-4000-8000-'+String(n).padStart(12,'0');
const row=Object.freeze({notificationId:id(1),notificationType:'MEMBER_ADDED',recipientUserId:id(2),recipientEmail:'canonical@example.test',accountStatus:'active'});
let callbacks:(()=>Promise<void>)[]=[];
const ports=()=>({read:m.read,provider:m.provider,schedule:m.after,log:m.log});
beforeEach(()=>{vi.resetAllMocks();callbacks=[];m.read.mockResolvedValue([row]);m.rpc.mockResolvedValue({data:[row],error:null});m.client.mockReturnValue({rpc:m.rpc});m.send.mockResolvedValue({success:true,messageId:id(3)});m.provider.mockReturnValue({send:m.send});m.after.mockImplementation(work=>{callbacks.push(work);});});
it.each(['SUBMISSION_RECEIVED','REVISION_REQUESTED','ARTIFACT_APPROVED','MEMBER_ADDED','MEMBER_REMOVED','MEMBER_MOVED'])('%s attempts email only when framework after callback runs',async notificationType=>{
 m.read.mockResolvedValue([{...row,notificationType}]);const d=createNotificationEmailDelivery(ports());await d.schedule({notificationId:row.notificationId});expect(callbacks).toHaveLength(1);expect(m.send).not.toHaveBeenCalled();await callbacks[0]();expect(m.read).toHaveBeenCalledTimes(2);expect(m.send).toHaveBeenCalledWith({to:row.recipientEmail,template:'FICI_NOTIFICATION',variables:{notificationType},idempotencyKey:'notification-email:'+row.notificationId+':'+row.recipientUserId});expect(m.log).toHaveBeenCalledWith({notificationId:row.notificationId,outcome:'ACCEPTED',messageId:id(3)});
});
it.each(['ARTIFACT_SHARED','COMMENT_RECEIVED','UNKNOWN','notification.changed','AI_OUTPUT','CHAT_MESSAGE'])('disabled %s does not even schedule',async notificationType=>{m.read.mockResolvedValue([{...row,notificationType}]);await createNotificationEmailDelivery(ports()).schedule({notificationId:row.notificationId});expect(m.after).not.toHaveBeenCalled();expect(m.provider).not.toHaveBeenCalled();});
it('missing/rolled-back/uncommitted notification does not schedule',async()=>{m.read.mockResolvedValue([]);await createNotificationEmailDelivery(ports()).schedule({notificationId:row.notificationId});expect(m.after).not.toHaveBeenCalled();});
it('accepted crash semantics: losing callback loses email; committed notification remains authoritative',async()=>{const before=JSON.stringify(row);await createNotificationEmailDelivery(ports()).schedule({notificationId:row.notificationId});expect(callbacks).toHaveLength(1);callbacks=[];expect(m.send).not.toHaveBeenCalled();expect(JSON.stringify(row)).toBe(before);});
it.each(['TIMEOUT','UNAVAILABLE','NETWORK','RATE_LIMIT','CONFIGURATION'])('failure %s does not throw/mutate state/retry or log provider diagnostics',async code=>{m.send.mockResolvedValue({success:false,error:{code,message:'PRIVATE_KEY Bearer SECRET_BODY',retryable:true}});const before=JSON.stringify(row);await createNotificationEmailDelivery(ports()).schedule({notificationId:row.notificationId});await expect(callbacks[0]()).resolves.toBeUndefined();expect(m.send).toHaveBeenCalledTimes(1);expect(JSON.stringify(row)).toBe(before);expect(m.log).toHaveBeenCalledWith({notificationId:row.notificationId,outcome:code});expect(JSON.stringify(m.log.mock.calls)).not.toMatch(/PRIVATE_KEY|Bearer|SECRET_BODY|canonical@example/);});
it('provider exception/logging exception cannot escape callback',async()=>{m.send.mockRejectedValue(Error('SECRET'));m.log.mockImplementation(()=>{throw Error('SECRET');});await createNotificationEmailDelivery(ports()).schedule({notificationId:row.notificationId});await expect(callbacks[0]()).resolves.toBeUndefined();});
it('retry uses same key; distinct notification and recipient use distinct keys',async()=>{const d=createNotificationEmailDelivery(ports());for(const entry of [row,row,{...row,notificationId:id(4)},{...row,recipientUserId:id(5)}]){m.read.mockResolvedValue([entry]);await d.schedule({notificationId:entry.notificationId});await callbacks.at(-1)!();}const keys=m.send.mock.calls.map(c=>c[0].idempotencyKey);expect(keys[0]).toBe(keys[1]);expect(new Set(keys).size).toBe(3);});
it('recipient is re-read inside callback, not captured from request/client',async()=>{await createNotificationEmailDelivery(ports()).schedule({notificationId:row.notificationId});m.read.mockResolvedValue([{...row,recipientEmail:'updated@example.test'}]);await callbacks[0]();expect(m.send.mock.calls[0][0].to).toBe('updated@example.test');});
it('account loss or record disappearance before callback prevents send',async()=>{await createNotificationEmailDelivery(ports()).schedule({notificationId:row.notificationId});m.read.mockResolvedValue([]);await callbacks[0]();expect(m.send).not.toHaveBeenCalled();});
it.each([{to:'attacker@example.test'},{recipientEmail:'attacker@example.test'},{recipientUserId:id(9)},{eligible:true},{notificationType:'ARTIFACT_APPROVED'},{storagePath:'secret'},{template:'RAW'}])('client spoof fields rejected %j',async extra=>{await createNotificationEmailDelivery(ports()).schedule({notificationId:row.notificationId,...extra});expect(m.read).not.toHaveBeenCalled();expect(m.after).not.toHaveBeenCalled();});
it.each([{...row,accountStatus:'suspended'},{...row,recipientEmail:'bad'},{...row,notificationId:id(9)}])('malformed/mismatched context fails closed %#',async invalid=>{m.read.mockResolvedValue([invalid]);await createNotificationEmailDelivery(ports()).schedule({notificationId:row.notificationId});expect(m.after).not.toHaveBeenCalled();});
it('safe scheduling failure preserves caller success',async()=>{m.after.mockImplementation(()=>{throw Error('PRIVATE_RUNTIME_STACK');});await expect(createNotificationEmailDelivery(ports()).schedule({notificationId:row.notificationId})).resolves.toBeUndefined();expect(m.log).toHaveBeenCalledWith({notificationId:row.notificationId,outcome:'SCHEDULING_UNAVAILABLE'});});
it('production composition uses framework after and only M15.14 abstraction',async()=>{await scheduleCommittedNotificationEmails({notificationId:row.notificationId});expect(m.rpc).toHaveBeenCalledWith('notification_email_contexts',{input:{notificationId:row.notificationId}});expect(m.send).not.toHaveBeenCalled();await callbacks[0]();expect(m.provider).toHaveBeenCalledWith([notificationEmailTemplate]);expect(m.send).toHaveBeenCalledTimes(1);});
it('canonical creation commits before eligibility read and after registration; failed creation never schedules',async()=>{
 const notification={id:row.notificationId,recipient_user_id:row.recipientUserId,notification_type:'MEMBER_ADDED',title:'Team membership updated',body:'You have been added to a Team.',entity_type:'team',entity_id:id(8),read_at:null,created_at:'2026-11-06T00:00:00Z'};
 const order:string[]=[];m.rpc.mockImplementation(async(name:string)=>{order.push(name);return name==='create_domain_notification'?{data:notification,error:null}:{data:[row],error:null};});m.after.mockImplementation(work=>{order.push('after');callbacks.push(work);});
 const input={notificationType:'MEMBER_ADDED',recipientContext:{sourceId:id(7)},formatterInput:{},entityReference:{entityType:'team',entityId:id(8)}};
 expect(await createNotification(input)).toEqual(notification);expect(order).toEqual(['create_domain_notification','notification_email_contexts','after']);expect(m.send).not.toHaveBeenCalled();
 callbacks=[];m.after.mockClear();m.rpc.mockResolvedValue({data:null,error:{code:'42501',message:'PRIVATE'}});await expect(createNotification(input)).rejects.toMatchObject({code:'NOTIFICATION_UNAVAILABLE'});expect(m.after).not.toHaveBeenCalled();
});
it.each(['SUBMISSION_RECEIVED','REVISION_REQUESTED','ARTIFACT_APPROVED','MEMBER_ADDED','MEMBER_REMOVED','MEMBER_MOVED'])('generic template %s contains only fixed wording and authenticated route',notificationType=>{const rendered=createEmailTemplateRegistry([notificationEmailTemplate])('FICI_NOTIFICATION',{notificationType});expect(rendered?.relativePath).toBe('/account');expect(JSON.stringify(rendered)).not.toMatch(/token|Bearer|SECRET|canonical@example|00000000|https?:/);});
it('template rejects confidential variables and disabled types',()=>{const render=createEmailTemplateRegistry([notificationEmailTemplate]);expect(render('FICI_NOTIFICATION',{notificationType:'MEMBER_ADDED',body:'PRIVATE'})).toBeNull();expect(render('FICI_NOTIFICATION',{notificationType:'COMMENT_RECEIVED'})).toBeNull();});
it('delivery modules are server-only; no direct adapter imports, durable queue, detached retries or canonical mutations',()=>{for(const file of ['email-delivery.ts','email-template.ts']){const s=readFileSync('features/notifications/'+file,'utf8');expect(s).toContain("import 'server-only'");expect(s).not.toMatch(/providers\/resend|api\.resend|setInterval|setTimeout|\.insert\(|\.update\(|\.delete\(/);}expect(readFileSync('features/notifications/email-delivery.ts','utf8')).toContain('after(work)');});

it.each(['role','teamId','cohortId','relativePath','redirectUrl','provider','headers','accessToken'])('M15.27 rejects client-controlled %s before canonical lookup',async field=>{
 await createNotificationEmailDelivery(ports()).schedule({notificationId:row.notificationId,[field]:'UNTRUSTED'});
 expect(m.read).not.toHaveBeenCalled();expect(m.after).not.toHaveBeenCalled();expect(m.send).not.toHaveBeenCalled();
});
it.each(['SUBMISSION_RECEIVED','REVISION_REQUESTED','ARTIFACT_APPROVED','MEMBER_ADDED','MEMBER_REMOVED','MEMBER_MOVED'])('M15.27 %s actual adapter payload contains only canonical recipient, generic copy and authenticated account route',async notificationType=>{
 const transport=vi.fn<typeof fetch>().mockResolvedValue(new Response(JSON.stringify({id:id(3)})));
 const provider=new ResendEmailProvider({apiKey:'re_mock_M1527_credential',from:'notices@example.test',siteOrigin:'https://fici.example.test'},[notificationEmailTemplate],transport);
 m.read.mockResolvedValue([{...row,notificationType}]);
 const d=createNotificationEmailDelivery({...ports(),provider:()=>provider});
 await d.schedule({notificationId:row.notificationId});await callbacks[0]();
 expect(transport).toHaveBeenCalledTimes(1);
 const body=JSON.parse(String(transport.mock.calls[0][1]!.body));
 expect(Object.keys(body).sort()).toEqual(['from','subject','text','to']);
 expect(body.to).toEqual([row.recipientEmail]);
 expect(body.text).toContain('https://fici.example.test/account');
 expect(body.text.match(/https:\/\/\S+/g)).toEqual(['https://fici.example.test/account']);
 expect(JSON.stringify(body)).not.toMatch(/re_mock|access_token|refresh_token|Bearer|storage|SELECT |stack|PRIVATE|00000000/);
 expect(JSON.stringify(m.log.mock.calls)).not.toContain(row.recipientEmail);
});
it('M15.27 dispatch rechecks active account even after eligible scheduling',async()=>{
 await createNotificationEmailDelivery(ports()).schedule({notificationId:row.notificationId});
 m.read.mockResolvedValue([{...row,accountStatus:'suspended'}]);await callbacks[0]();
 expect(m.send).not.toHaveBeenCalled();expect(m.log).toHaveBeenCalledWith({notificationId:row.notificationId,outcome:'UNAVAILABLE'});
});
