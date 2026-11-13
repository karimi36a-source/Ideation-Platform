import {expect,it,vi} from 'vitest';
import {readFileSync} from 'node:fs';
vi.mock('server-only',()=>({}));
import {getNotificationTypeDefinition,listNotificationTypeDefinitions,notificationTypeSchema,NotificationTypeError} from '@/features/notifications/type-registry';
const codes=['MEMBER_ADDED','MEMBER_REMOVED','MEMBER_MOVED','ARTIFACT_SHARED','SUBMISSION_RECEIVED','REVISION_REQUESTED','ARTIFACT_APPROVED','COMMENT_RECEIVED'];
it('contains exactly the pilot types, preserving all three M5 membership codes without aliases',()=>{
 const entries=listNotificationTypeDefinitions();expect(entries.map(v=>v.code)).toEqual(codes);
 expect(new Set(entries.map(v=>v.code)).size).toBe(entries.length);
 expect(notificationTypeSchema.options).toEqual(codes);
 const legacy=readFileSync('supabase/migrations/20261004130000_m5_audit_notifications.sql','utf8');
 for(const code of codes.slice(0,3))expect(legacy).toContain("'"+code+"'");
});
it.each(codes)('%s produces deterministic bounded generic summaries and explicit policy metadata',code=>{
 const entry=getNotificationTypeDefinition(code);
 for(const [formatter,max] of [[entry.titleFormatter,160],[entry.bodyFormatter,500]] as const){
  const text=formatter({});expect(text.trim()).toBe(text);expect(text.length).toBeGreaterThan(0);expect(text.length).toBeLessThanOrEqual(max);expect(formatter({})).toBe(text);
  expect(text).not.toMatch(/https?:|eyJ|sk_|Bearer|stack|00000000/i);
 }
 expect(entry.emailPolicy).toBe(['ARTIFACT_SHARED','COMMENT_RECEIVED'].includes(code)?'DISABLED':'PILOT_ELIGIBLE');expect(entry.realtimeEligible).toBe(true);
 expect(entry.recipientResolution.authority).toBe('SERVER_CANONICAL_CURRENT_AUTHORIZATION');
 expect(entry.recipientResolution.strategy.length).toBeGreaterThan(0);
});
it('uses actual M5/M8/M13 entity vocabulary and targets shared context rather than private Artifact',()=>{
 const m5=readFileSync('supabase/migrations/20261004130000_m5_audit_notifications.sql','utf8');
 const m8=readFileSync('supabase/migrations/20261007080000_request_revision.sql','utf8');
 const m13=readFileSync('supabase/migrations/20261012030000_share_entity.sql','utf8');
 for(const e of listNotificationTypeDefinitions())expect([m5,m8,m13].some(s=>s.includes("entity_type='"+e.targetEntityType+"'"))).toBe(true);
 expect(getNotificationTypeDefinition('ARTIFACT_SHARED').targetEntityType).toBe('share');
 expect(getNotificationTypeDefinition('SUBMISSION_RECEIVED').recipientResolution.strategy).toBe('CURRENT_ASSIGNED_SUBMISSION_REVIEWER');
});
it('matches M15.1 persisted code, text and navigation-reference constraints',()=>{
 for(const e of listNotificationTypeDefinitions()){
  expect(e.code).toMatch(/^[A-Z][A-Z0-9_]{0,63}$/);
  expect(e.targetEntityType).toMatch(/^[A-Za-z][A-Za-z0-9_]{0,63}$/);
 }
});
it('deeply freezes the definitions and returned collection',()=>{
 const entries=listNotificationTypeDefinitions();expect(Object.isFrozen(entries)).toBe(true);
 for(const e of entries){
  for(const v of [e,e.recipientResolution,e.titleFormatter,e.bodyFormatter])expect(Object.isFrozen(v)).toBe(true);
  expect(Reflect.set(e,'realtimeEligible',false)).toBe(false);expect(Reflect.set(e.recipientResolution,'strategy','CLIENT_SELECTED')).toBe(false);
 }
 expect(Reflect.set(entries,'0',null)).toBe(false);
});
it.each(['FEEDBACK_RECEIVED','SHARE_REVOKED','CHAT_MENTION','ASSIGNMENT_DUE','INSTRUCTOR_ANNOUNCEMENT','TEAM_DECISION_PENDING','TEAM_MEMBERSHIP_CHANGED','__proto__','constructor','member_added','',null,undefined,{},1])('rejects unsupported code safely: %j',code=>{
 expect(()=>getNotificationTypeDefinition(code)).toThrow(NotificationTypeError);
 try{getNotificationTypeDefinition(code);}catch(e){expect((e as Error).message).toBe('Notification type unavailable');}
});
it.each(['artifactBody','evidenceContent','aiOutput','chatBody','patentStrategy','secret','stack','recipientUserId','entityId','actorName'])('rejects arbitrary formatter input %s',key=>{
 for(const e of listNotificationTypeDefinitions()){
  const input={[key]:'CONFIDENTIAL_SENTINEL'};
  // Runtime attack deliberately crosses the typed boundary.
  expect(()=>e.titleFormatter(input as never)).toThrow();expect(()=>e.bodyFormatter(input as never)).toThrow();
 }
});
it('rejects malformed formatter inputs',()=>{
 const entry=getNotificationTypeDefinition('ARTIFACT_SHARED');
 for(const value of [null,undefined,'raw body',[]])expect(()=>entry.bodyFormatter(value as never)).toThrow();
});

it('COMMENT_RECEIVED uses canonical Submission or Share navigation only',()=>{const d=getNotificationTypeDefinition('COMMENT_RECEIVED');expect(d.targetEntityTypes).toEqual(['submission','share']);expect(Object.isFrozen(d.targetEntityTypes)).toBe(true);});
