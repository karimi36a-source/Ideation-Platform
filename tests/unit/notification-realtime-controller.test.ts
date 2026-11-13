import {beforeEach,expect,it,vi} from 'vitest';
import {createNotificationRealtimeController} from '@/features/notifications/realtime-controller';
import type {NotificationRealtimePorts} from '@/features/notifications/realtime-controller';
const a='00000000-0000-4000-8000-000000006004',b='00000000-0000-4000-8000-000000006006';
const id='aaaaaaaa-0000-4000-8000-000000000001',other='aaaaaaaa-0000-4000-8000-000000000002';
const row=(key=id,read:string|null=null)=>({id:key,notification_type:'MEMBER_ADDED',title:'Safe notice',body:'Summary',entity_type:null,entity_id:null,read_at:read,created_at:'2026-11-06T01:00:00.123456+00:00'});
let event:(v:unknown)=>void,ready:()=>void,failed:()=>void,ports:NotificationRealtimePorts;
const authorize=vi.fn(),load=vi.fn(),subscribe=vi.fn(),stop=vi.fn(),items=vi.fn(),unavailable=vi.fn();
beforeEach(()=>{vi.resetAllMocks();authorize.mockResolvedValue({userId:a,topic:'notifications:'+a});load.mockResolvedValue({userId:a,page:{items:[row()],nextCursor:null}});stop.mockResolvedValue(undefined);
 subscribe.mockImplementation(async(_d,e,r,f)=>{event=e;ready=r;failed=f;return stop;});ports={authorize,load,subscribe,items,unavailable};});
it('connected committed INSERT invalidates and renders only canonical list',async()=>{
 const c=createNotificationRealtimeController(ports);await c.connect();expect(items).toHaveBeenLastCalledWith([row()]);
 load.mockResolvedValue({userId:a,page:{items:[row(other),row()],nextCursor:null}});event({id:other,read_at:null});await c.refresh();expect(items).toHaveBeenLastCalledWith([row(other),row()]);
});
it('duplicate/out-of-order events retain unique database ordered identities, not event order',async()=>{
 const c=createNotificationRealtimeController(ports);await c.connect();event({id,read_at:null});event({id,read_at:null});await c.refresh();expect(items).toHaveBeenLastCalledWith([row()]);
});
it('read-state update and stale duplicate reload canonical read_at',async()=>{
 const c=createNotificationRealtimeController(ports);await c.connect();const read='2026-11-06T02:00:00Z';load.mockResolvedValue({userId:a,page:{items:[row(id,read)],nextCursor:null}});
 event({id,read_at:read});event({id,read_at:null});await c.refresh();expect(items).toHaveBeenLastCalledWith([row(id,read)]);
});
it('reconnect recovers missed notifications, removes old subscription, reloads on SUBSCRIBED',async()=>{
 const c=createNotificationRealtimeController(ports);await c.connect();await c.disconnect();load.mockResolvedValue({userId:a,page:{items:[row(other),row()],nextCursor:null}});
 await c.reconnect();expect(stop).toHaveBeenCalledTimes(1);expect(items).toHaveBeenLastCalledWith([row(other),row()]);const n=load.mock.calls.length;ready();await c.refresh();expect(load.mock.calls.length).toBeGreaterThan(n);
});
it('disconnect clears visible state synchronously and ignores former callbacks',async()=>{
 const c=createNotificationRealtimeController(ports);await c.connect();const old=event;await c.disconnect();const n=load.mock.calls.length;old({id,read_at:null});ready();await c.refresh();expect(items).toHaveBeenLastCalledWith([]);expect(load).toHaveBeenCalledTimes(n);expect(stop).toHaveBeenCalledOnce();
});
it('identity switch cannot publish a prior user in-flight response',async()=>{
 const c=createNotificationRealtimeController(ports);await c.connect();let resolve!:(v:unknown)=>void;load.mockImplementationOnce(()=>new Promise(r=>{resolve=r;}));const pending=c.refresh();await vi.waitFor(()=>expect(resolve).toBeTypeOf('function'));
 const clearing=c.disconnect();authorize.mockResolvedValue({userId:b,topic:'notifications:'+b});load.mockResolvedValue({userId:b,page:{items:[],nextCursor:null}});resolve({userId:a,page:{items:[row()],nextCursor:null}});await pending;await clearing;await c.connect();expect(items).toHaveBeenLastCalledWith([]);
});
it('rejects account switching inside paginated canonical reload',async()=>{
 const c=createNotificationRealtimeController(ports);load.mockResolvedValue({userId:b,page:{items:[row()],nextCursor:null}});await c.connect();expect(items).toHaveBeenLastCalledWith([]);expect(subscribe).not.toHaveBeenCalled();expect(unavailable).toHaveBeenCalledOnce();
});
it('rejects supplied topic belonging to another recipient before subscribing',async()=>{
 authorize.mockResolvedValue({userId:a,topic:'notifications:'+b});await createNotificationRealtimeController(ports).connect();expect(subscribe).not.toHaveBeenCalled();expect(unavailable).toHaveBeenCalledOnce();
});
it.each([{id,read_at:null,metadata:{secret:'hidden'}},{id,read_at:null,recipient_user_id:a},{id:'bad',read_at:null},{teamId:a},{id,read_at:null,idempotency_digest:'hidden'}])('rejects malformed/nonminimal event %#',async value=>{
 const c=createNotificationRealtimeController(ports);await c.connect();const n=load.mock.calls.length;event(value);expect(load).toHaveBeenCalledTimes(n);
});
it('reloads all canonical pages and deduplicates IDs without client sorting',async()=>{
 load.mockResolvedValueOnce({userId:a,page:{items:[row(other)],nextCursor:{createdAt:row().created_at,id:other}}}).mockResolvedValueOnce({userId:a,page:{items:[row(other),row()],nextCursor:null}});
 const c=createNotificationRealtimeController(ports);await c.connect();expect(items).toHaveBeenLastCalledWith([row(other),row()]);expect(load).toHaveBeenNthCalledWith(2,{createdAt:row().created_at,id:other});
});
it('failed or timed-out channel clears state, reconnect remains possible',async()=>{
 const c=createNotificationRealtimeController(ports);await c.connect();failed();await vi.waitFor(()=>expect(unavailable).toHaveBeenCalledOnce());expect(items).toHaveBeenLastCalledWith([]);await c.reconnect();expect(items).toHaveBeenLastCalledWith([row()]);
});
it('unsubscribe returned after logout is still removed',async()=>{
 let resolve!:(s:()=>Promise<void>)=>void;subscribe.mockImplementation(()=>new Promise(r=>{resolve=r;}));const c=createNotificationRealtimeController(ports);const pending=c.connect();await vi.waitFor(()=>expect(resolve).toBeTypeOf('function'));await c.disconnect();resolve(stop);await pending;expect(stop).toHaveBeenCalledOnce();expect(items).toHaveBeenLastCalledWith([]);
});
it('concurrent starts cannot leave duplicate subscriptions',async()=>{
 const c=createNotificationRealtimeController(ports);await Promise.all([c.connect(),c.connect()]);expect(subscribe).toHaveBeenCalledTimes(1);
});
it('M15.26 a known foreign notification ID is an invalidation hint, never rendered data',async()=>{
 const c=createNotificationRealtimeController(ports);await c.connect();event({id:other,read_at:null});await c.refresh();
 expect(items).toHaveBeenLastCalledWith([row()]);expect(items.mock.calls.flatMap(call=>call[0]).some(value=>value.id===other)).toBe(false);
});
it.each(['body','title','email','access_token','claims','route','artifactContent','feedback','chat','recipientUserId'])('M15.26 rejects confidential or scope-bearing transport field %s',async key=>{
 const c=createNotificationRealtimeController(ports);await c.connect();const loads=load.mock.calls.length;
 event({id,read_at:null,[key]:'PRIVATE_TEST_CONTENT'});await Promise.resolve();expect(load).toHaveBeenCalledTimes(loads);await c.disconnect();
});
