import {beforeEach,expect,it,vi} from 'vitest';
vi.mock('server-only',()=>({}));
const m=vi.hoisted(()=>({create:vi.fn()}));
vi.mock('@/features/notifications/service',()=>({createNotification:m.create}));
import {notifySubmissionReceived} from '@/features/notifications/submission';
const id='00000000-0000-4000-8000-000000006004';
beforeEach(()=>{vi.restoreAllMocks();m.create.mockReset();vi.spyOn(console,'warn').mockImplementation(()=>{});});
it('passes only canonical Submission identity to registry-backed service',async()=>{
 await notifySubmissionReceived(id);
 expect(m.create).toHaveBeenCalledExactlyOnceWith({notificationType:'SUBMISSION_RECEIVED',recipientContext:{sourceId:id},formatterInput:{},entityReference:{entityType:'submission',entityId:id},idempotencyKey:'submission-received:'+id});
});
it('replay uses the same stable event identity without client recipient authority',async()=>{await notifySubmissionReceived(id);await notifySubmissionReceived(id);expect(m.create.mock.calls[0]).toEqual(m.create.mock.calls[1]);});
it('distinct Submissions have distinct identities despite identical safe summaries',async()=>{await notifySubmissionReceived(id);await notifySubmissionReceived(id.replace(/4$/,'5'));expect(m.create.mock.calls[0][0].idempotencyKey).not.toEqual(m.create.mock.calls[1][0].idempotencyKey);});
it('post-commit notification/assignment failure is safe and does not throw',async()=>{m.create.mockRejectedValue(new Error('private scope/credential diagnostic'));await expect(notifySubmissionReceived(id)).resolves.toBeUndefined();expect(vi.mocked(console.warn).mock.calls.map(([line])=>JSON.parse(String(line))).filter(event=>event.event==='NOTIFICATION_FALLBACK')).toEqual([expect.objectContaining({event:'NOTIFICATION_FALLBACK',operation:'NOTIFICATION_SUBMISSION',code:'UNAVAILABLE',phase:'DELIVERY'})]);});
it('unknown or spoofed identity cannot reach privileged notification service',async()=>{await notifySubmissionReceived('bad');expect(m.create).not.toHaveBeenCalled();});

it('normalizes UUID spelling for one stable event identity',async()=>{const uuid='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';await notifySubmissionReceived(uuid.toUpperCase());await notifySubmissionReceived(uuid);expect(m.create.mock.calls[0]).toEqual(m.create.mock.calls[1]);});
