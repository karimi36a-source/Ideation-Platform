import {beforeEach,expect,it,vi} from 'vitest';
const m=vi.hoisted(()=>({authCallback:vi.fn(),authStop:vi.fn(),setAuth:vi.fn(),channel:vi.fn(),removeChannel:vi.fn(),authorize:vi.fn(),load:vi.fn()}));
vi.mock('@/lib/db/browser',()=>({createBrowserSupabaseClient:()=>({realtime:{setAuth:m.setAuth},channel:m.channel,removeChannel:m.removeChannel,auth:{onAuthStateChange:(cb:unknown)=>{m.authCallback=cb as typeof m.authCallback;return {data:{subscription:{unsubscribe:m.authStop}}};}}})}));
vi.mock('@/features/notifications/realtime-actions',()=>({authorizeNotificationRealtime:m.authorize,loadNotificationRealtimePage:m.load}));
import {createNotificationRealtime} from '@/features/notifications/realtime-browser';
const a='00000000-0000-4000-8000-000000006004',b='00000000-0000-4000-8000-000000006006';
beforeEach(()=>{vi.clearAllMocks();m.setAuth.mockResolvedValue(undefined);m.removeChannel.mockResolvedValue('ok');m.authorize.mockResolvedValue({ok:true,data:{userId:a,topic:'notifications:'+a}});m.load.mockResolvedValue({ok:true,data:{userId:a,page:{items:[],nextCursor:null}}});m.channel.mockImplementation(()=>{const stream={on:vi.fn(),subscribe:vi.fn()};stream.on.mockReturnValue(stream);stream.subscribe.mockReturnValue(stream);return stream;});});
it('authenticated private receive-only Supabase channel; no Postgres full-row, Presence, send or Team topic',async()=>{
 const c=createNotificationRealtime(vi.fn(),vi.fn());await c.connect();expect(m.setAuth).toHaveBeenCalledOnce();expect(m.channel).toHaveBeenCalledExactlyOnceWith('notifications:'+a,{config:{private:true}});expect(m.channel.mock.results[0].value.on).toHaveBeenCalledExactlyOnceWith('broadcast',{event:'notification.changed'},expect.any(Function));
 expect(m.load).toHaveBeenCalledWith({limit:100});await c.disconnect();expect(m.removeChannel).toHaveBeenCalledWith(m.channel.mock.results[0].value);expect(m.authStop).toHaveBeenCalledOnce();
});
it('logout immediately clears former user state and removes channel',async()=>{
 const items=vi.fn(),c=createNotificationRealtime(items,vi.fn());await c.connect();m.authCallback('SIGNED_OUT',null);expect(items).toHaveBeenLastCalledWith([]);await vi.waitFor(()=>expect(m.removeChannel).toHaveBeenCalledOnce());await c.disconnect();
});
it('identity switch removes old channel and subscribes only to server-derived new identity',async()=>{
 const c=createNotificationRealtime(vi.fn(),vi.fn());await c.connect();m.authorize.mockResolvedValue({ok:true,data:{userId:b,topic:'notifications:'+b}});m.load.mockResolvedValue({ok:true,data:{userId:b,page:{items:[],nextCursor:null}}});m.authCallback('SIGNED_IN',{});
 await vi.waitFor(()=>expect(m.channel).toHaveBeenLastCalledWith('notifications:'+b,{config:{private:true}}));expect(m.removeChannel).toHaveBeenCalledTimes(1);await c.disconnect();
});
it('failed server authorization never creates a subscription',async()=>{
 m.authorize.mockResolvedValue({ok:false});const failed=vi.fn();await createNotificationRealtime(vi.fn(),failed).connect();expect(m.channel).not.toHaveBeenCalled();expect(failed).toHaveBeenCalledOnce();
});
it('M15.26 A1/A2/B1/Master each join only their server-authorized private recipient topic',async()=>{
 const users=[a,'00000000-0000-4000-8000-000000006005',b,'00000000-0000-4000-8000-000000006002'];
 const clients=[];
 for(const user of users){m.authorize.mockResolvedValue({ok:true,data:{userId:user,topic:'notifications:'+user}});m.load.mockResolvedValue({ok:true,data:{userId:user,page:{items:[],nextCursor:null}}});const client=createNotificationRealtime(vi.fn(),vi.fn());await client.connect();clients.push(client);}
 expect(m.channel.mock.calls.map(call=>call[0])).toEqual(users.map(user=>'notifications:'+user));
 for(const call of m.channel.mock.calls)expect(call[1]).toEqual({config:{private:true}});
 for(const client of clients)await client.disconnect();expect(m.removeChannel).toHaveBeenCalledTimes(4);
});
it('M15.26 late event/ready/error callbacks after logout cannot consume new recipient events',async()=>{
 const items=vi.fn(),c=createNotificationRealtime(items,vi.fn());await c.connect();
 const stream=m.channel.mock.results[0].value,event=stream.on.mock.calls[0][2],status=stream.subscribe.mock.calls[0][0];
 m.authCallback('SIGNED_OUT',null);await vi.waitFor(()=>expect(m.removeChannel).toHaveBeenCalledOnce());
 const loads=m.load.mock.calls.length;event({payload:{id:a,read_at:null}});status('SUBSCRIBED');status('CHANNEL_ERROR');await c.refresh();
 expect(m.load).toHaveBeenCalledTimes(loads);expect(items).toHaveBeenLastCalledWith([]);await c.disconnect();
});
it('M15.26 new session cannot inherit the old channel or its in-flight callbacks',async()=>{
 const c=createNotificationRealtime(vi.fn(),vi.fn());await c.connect();
 const old=m.channel.mock.results[0].value,event=old.on.mock.calls[0][2],status=old.subscribe.mock.calls[0][0];
 m.authorize.mockResolvedValue({ok:true,data:{userId:b,topic:'notifications:'+b}});m.load.mockResolvedValue({ok:true,data:{userId:b,page:{items:[],nextCursor:null}}});m.authCallback('SIGNED_IN',{user:{id:b}});
 await vi.waitFor(()=>expect(m.channel).toHaveBeenLastCalledWith('notifications:'+b,{config:{private:true}}));
 const current=m.channel.mock.results[1].value;expect(current).not.toBe(old);expect(m.removeChannel).toHaveBeenCalledWith(old);
 const loads=m.load.mock.calls.length;event({payload:{id:a,read_at:null}});status('SUBSCRIBED');status('CLOSED');await c.refresh();
 // Only explicit current-user refresh can run; stale callbacks cannot reload A1.
 expect(m.load).toHaveBeenCalledTimes(loads+1);expect(m.removeChannel).not.toHaveBeenCalledWith(current);await c.disconnect();
});
it('M15.26 auth-event recipient claims never select a channel',async()=>{
 const c=createNotificationRealtime(vi.fn(),vi.fn());await c.connect();m.authCallback('SIGNED_IN',{user:{id:b},role:'ADMIN',teamId:b});
 await vi.waitFor(()=>expect(m.channel).toHaveBeenCalledTimes(2));expect(m.channel).toHaveBeenLastCalledWith('notifications:'+a,{config:{private:true}});await c.disconnect();
});
