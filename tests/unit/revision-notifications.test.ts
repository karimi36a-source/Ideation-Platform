import {beforeEach,expect,it,vi} from 'vitest';
vi.mock('server-only',()=>({}));
const m=vi.hoisted(()=>({rpc:vi.fn(),client:vi.fn(),create:vi.fn()}));
vi.mock('@supabase/supabase-js',()=>({createClient:m.client}));
vi.mock('@/lib/validation/env-server',()=>({getServerEnv:()=>({NEXT_PUBLIC_SUPABASE_URL:'https://example.test',SUPABASE_SECRET_KEY:'test-private'})}));
vi.mock('@/features/notifications/service',()=>({createNotification:m.create}));
import {notifyRevisionRequested} from '@/features/notifications/revision';
const id=(n:number)=>'00000000-0000-4000-8000-'+String(n).padStart(12,'0');
beforeEach(()=>{vi.restoreAllMocks();vi.resetAllMocks();m.client.mockReturnValue({rpc:m.rpc});m.rpc.mockResolvedValue({data:[{recipientContext:{sourceId:id(2),teamMembershipId:id(3)},idempotencyKey:'revision-requested:'+id(2)+':'+id(3)},{recipientContext:{sourceId:id(2),teamMembershipId:id(4)},idempotencyKey:'revision-requested:'+id(2)+':'+id(4)}],error:null});vi.spyOn(console,'warn').mockImplementation(()=>{});});
it('uses committed canonical selectors and existing registry service per recipient',async()=>{
 await notifyRevisionRequested(id(1));expect(m.rpc).toHaveBeenCalledExactlyOnceWith('revision_notification_contexts',{target_submission:id(1)});
 expect(m.create).toHaveBeenCalledTimes(2);
 expect(m.create).toHaveBeenCalledWith({notificationType:'REVISION_REQUESTED',recipientContext:{sourceId:id(2),teamMembershipId:id(3)},formatterInput:{},entityReference:{entityType:'submission',entityId:id(1)},idempotencyKey:'revision-requested:'+id(2)+':'+id(3)});
});
it('supports Personal owner selector without a client user ID',async()=>{m.rpc.mockResolvedValue({data:[{recipientContext:{sourceId:id(2)},idempotencyKey:'revision-requested:'+id(2)+':'+id(3)}],error:null});await notifyRevisionRequested(id(1));expect(m.create.mock.calls[0][0].recipientContext).toEqual({sourceId:id(2)});});
it('empty audience emits nothing',async()=>{m.rpc.mockResolvedValue({data:[],error:null});await notifyRevisionRequested(id(1));expect(m.create).not.toHaveBeenCalled();});
it('one recipient failure does not prevent others or undo committed revision',async()=>{m.create.mockRejectedValueOnce(new Error('private diagnostics'));await expect(notifyRevisionRequested(id(1))).resolves.toBeUndefined();expect(m.create).toHaveBeenCalledTimes(2);expect(vi.mocked(console.warn).mock.calls.map(([line])=>JSON.parse(String(line))).filter(event=>event.event==='NOTIFICATION_FALLBACK')).toEqual([expect.objectContaining({event:'NOTIFICATION_FALLBACK',operation:'NOTIFICATION_REVISION',code:'UNAVAILABLE',phase:'DELIVERY'})]);});
it.each([{error:{message:'private'},data:null},{error:null,data:[{sourceId:id(2),recipientId:id(9)}]},{error:null,data:null}])('fails closed on invalid selector response %#',async result=>{m.rpc.mockResolvedValue(result);await notifyRevisionRequested(id(1));expect(m.create).not.toHaveBeenCalled();expect(vi.mocked(console.warn).mock.calls.map(([line])=>JSON.parse(String(line))).filter(event=>event.event==='NOTIFICATION_FALLBACK')).toHaveLength(1);});
it('rejects malformed Submission ID before privileged I/O',async()=>{await notifyRevisionRequested('bad');expect(m.client).not.toHaveBeenCalled();});
