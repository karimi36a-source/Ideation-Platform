import {beforeEach,expect,it,vi} from 'vitest';
import {readFileSync} from 'node:fs';
vi.mock('server-only',()=>({}));
const m=vi.hoisted(()=>({account:vi.fn(),select:vi.fn(),eq:vi.fn(),single:vi.fn(),from:vi.fn(),client:vi.fn()}));
vi.mock('@/features/users/service',()=>({requireActivePlatformUser:m.account}));
vi.mock('@/lib/db/server',()=>({createServerSupabaseClient:m.client}));
import {createEmailEligibilityPolicy,pilotEmailDefaults} from '@/features/notifications/email-policy-config';
import {createNotificationEmailPolicy,pilotNotificationEmailPolicy} from '@/features/notifications/email-policy';
import {listNotificationTypeDefinitions} from '@/features/notifications/type-registry';
const id=(n:number)=>'00000000-0000-4000-8000-'+String(n).padStart(12,'0');
const row=Object.freeze({id:id(1),recipient_user_id:id(2),notification_type:'MEMBER_ADDED'});
const account=Object.freeze({id:id(2),email:'canonical@example.test',account_status:'active'});
beforeEach(()=>{
 vi.resetAllMocks();m.account.mockResolvedValue(account);m.single.mockResolvedValue({data:row,error:null});
 const query={select:m.select,eq:m.eq,maybeSingle:m.single};m.select.mockReturnValue(query);m.eq.mockReturnValue(query);m.from.mockReturnValue(query);m.client.mockResolvedValue({from:m.from});
});
it.each(['MEMBER_ADDED','MEMBER_REMOVED','MEMBER_MOVED','SUBMISSION_RECEIVED','REVISION_REQUESTED','ARTIFACT_APPROVED'])('approved default %s is eligible only after canonical notification read',async type=>{
 expect(createEmailEligibilityPolicy().isEligible(type)).toBe(true);
 m.single.mockResolvedValue({data:{...row,notification_type:type},error:null});
 expect(await pilotNotificationEmailPolicy.evaluate({notificationId:row.id})).toEqual({eligible:true,notificationId:row.id,notificationType:type,recipientUserId:account.id,recipientEmail:account.email});
 expect(m.from).toHaveBeenCalledWith('notifications');expect(m.select).toHaveBeenCalledWith('id,recipient_user_id,notification_type');expect(m.eq.mock.calls).toEqual([['id',row.id],['recipient_user_id',account.id]]);
});
it.each(['ARTIFACT_SHARED','COMMENT_RECEIVED','STATUS_REFRESH','notification.changed','AI_OUTPUT','CHAT_MESSAGE','FUTURE_EVENT','MEMBERSHIP_CHANGED','__proto__','constructor','',null,{},42])('disabled/unknown/noise type fails closed %j',type=>{expect(createEmailEligibilityPolicy().isEligible(type)).toBe(false);expect(pilotNotificationEmailPolicy.isEligible(type)).toBe(false);});
it.each(['ARTIFACT_SHARED','COMMENT_RECEIVED','AI_OUTPUT','CHAT_MESSAGE','FUTURE_EVENT'])('stored disabled type %s returns no recipient email or content',async type=>{m.single.mockResolvedValue({data:{...row,notification_type:type},error:null});expect(await pilotNotificationEmailPolicy.evaluate({notificationId:row.id})).toEqual({eligible:false});});
it('trusted config can opt Artifact sharing in or disable an approved type without changing defaults',()=>{
 const policy=createNotificationEmailPolicy({ARTIFACT_SHARED:true,SUBMISSION_RECEIVED:false});expect(policy.isEligible('ARTIFACT_SHARED')).toBe(true);expect(policy.isEligible('SUBMISSION_RECEIVED')).toBe(false);expect(pilotNotificationEmailPolicy.isEligible('ARTIFACT_SHARED')).toBe(false);expect(pilotNotificationEmailPolicy.isEligible('SUBMISSION_RECEIVED')).toBe(true);expect(Object.isFrozen(pilotEmailDefaults)).toBe(true);
});
it.each([{COMMENT_RECEIVED:true},{UNKNOWN:true},{CHAT_MESSAGE:true},{AI_OUTPUT:true},{MEMBER_ADDED:'true'},{enabled:true},null])('invalid/unapproved server config fails closed %j',config=>{expect(()=>createNotificationEmailPolicy(config as never)).toThrow('Invalid notification email policy configuration');});
it.each([{eligible:true},{emailEligible:true},{recipientEmail:'attacker@example.test'},{to:'attacker@example.test'},{recipientUserId:id(9)},{notificationType:'ARTIFACT_APPROVED'},{policy:{ARTIFACT_SHARED:true}},{overrides:{COMMENT_RECEIVED:true}},{template:'OVERRIDE'}])('client overrides rejected before account or database access %j',override=>{
 return expect(pilotNotificationEmailPolicy.evaluate({notificationId:row.id,...override})).rejects.toMatchObject({code:'INVALID_INPUT'}).then(()=>{expect(m.account).not.toHaveBeenCalled();expect(m.client).not.toHaveBeenCalled();});
});
it.each([{},null,{notificationId:'bad'},{notificationId:row.id,recipient:{email:'attacker@example.test'}}])('malformed input is denied %j',async input=>{await expect(pilotNotificationEmailPolicy.evaluate(input)).rejects.toMatchObject({code:'INVALID_INPUT'});expect(m.client).not.toHaveBeenCalled();});
it.each([{data:null,error:null},{data:row,error:{message:'PRIVATE_DATABASE_SECRET'}},{data:{...row,id:id(9)},error:null},{data:{...row,recipient_user_id:id(9)},error:null}])('missing/uncommitted/inaccessible/mismatched notification cannot become eligible %#',async result=>{m.single.mockResolvedValue(result);await expect(pilotNotificationEmailPolicy.evaluate({notificationId:row.id})).rejects.toMatchObject({code:'UNAVAILABLE',message:'Notification email eligibility unavailable'});});
it('email comes from current canonical account, never notification payload or client',async()=>{
 m.single.mockResolvedValue({data:{...row,recipient_email:'attacker@example.test',email:'attacker@example.test'},error:null});
 m.account.mockResolvedValueOnce(account).mockResolvedValueOnce({...account,email:'updated@example.test'});
 expect(await pilotNotificationEmailPolicy.evaluate({notificationId:row.id})).toMatchObject({recipientEmail:'updated@example.test'});
});
it.each([{...account,id:id(9)},{...account,email:null},{...account,email:'bad'}])('changed identity or unavailable account email denies evaluation %#',async next=>{m.account.mockResolvedValueOnce(account).mockResolvedValueOnce(next);await expect(pilotNotificationEmailPolicy.evaluate({notificationId:row.id})).rejects.toMatchObject({code:'UNAVAILABLE'});});
it('inactive/unauthenticated account failure is safe and cannot read notifications',async()=>{m.account.mockRejectedValue(Error('PRIVATE_ACCOUNT_SECRET'));await expect(pilotNotificationEmailPolicy.evaluate({notificationId:row.id})).rejects.toMatchObject({code:'UNAVAILABLE',message:'Notification email eligibility unavailable'});expect(m.client).not.toHaveBeenCalled();});
it('pure evaluation cannot mutate notification/domain state, persist email, or invoke delivery',async()=>{
 const before=JSON.stringify({row,account});const result=await pilotNotificationEmailPolicy.evaluate({notificationId:row.id});expect(result.eligible).toBe(true);expect(Object.isFrozen(result)).toBe(true);expect(JSON.stringify({row,account})).toBe(before);expect(m.from).toHaveBeenCalledTimes(1);expect(m.single).toHaveBeenCalledTimes(1);
});
it('registry metadata matches approved defaults, independently of realtime eligibility',()=>{for(const d of listNotificationTypeDefinitions())expect(d.emailPolicy).toBe(pilotEmailDefaults[d.code]?'PILOT_ELIGIBLE':'DISABLED');expect(listNotificationTypeDefinitions().find(d=>d.code==='COMMENT_RECEIVED')?.realtimeEligible).toBe(true);expect(pilotNotificationEmailPolicy.isEligible('COMMENT_RECEIVED')).toBe(false);});
it('server-only provider-independent policy has no provider/secret/mutation/dispatch dependency',()=>{
 for(const file of ['email-policy.ts','email-policy-config.ts']){const source=readFileSync('features/notifications/'+file,'utf8');expect(source).toContain("import 'server-only'");expect(source).not.toMatch(/Resend|resend|EmailProvider|RESEND_API_KEY|SUPABASE_SECRET_KEY|process\.env|\.send\(|\.insert\(|\.update\(|\.delete\(|\.rpc\(|use server/);}
});
