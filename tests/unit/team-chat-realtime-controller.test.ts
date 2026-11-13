import {beforeEach,expect,it,vi} from "vitest";
import {createTeamChatRealtimeController,type TeamChatRealtimePorts} from "@/features/chat/realtime-controller";
const id=(n:number)=>`00000000-0000-4000-8000-${String(n).padStart(12,"0")}`;
const descriptor={chatChannelId:id(1),userId:id(2),topic:`team-chat:${id(1)}:${id(2)}`};
const message=(n:number)=>({id:id(n),chat_channel_id:id(1),sender_user_id:id(2),parent_message_id:null,content:"canonical",message_type:"TEXT",created_at:"2026-10-04T00:00:00Z",edited_at:null,deleted_at:null});
let event:(value:unknown)=>void;let ready:()=>void;let fail:()=>void;
let ports:TeamChatRealtimePorts;let saved:ReturnType<typeof message>[];let unsubscribe:ReturnType<typeof vi.fn>;
const settle=async()=>{for(let i=0;i<20;i++)await Promise.resolve();};
beforeEach(()=>{
 saved=[message(3)];unsubscribe=vi.fn().mockResolvedValue(undefined);
 ports={authorize:vi.fn().mockResolvedValue(descriptor),load:vi.fn().mockImplementation(async()=>({items:saved,nextCursor:null})),subscribe:vi.fn().mockImplementation(async(_d,e,r,f)=>{event=e;ready=r;fail=f;return unsubscribe;}),messages:vi.fn(),denied:vi.fn()};
});
it("authorizes and restores canonical history before private subscription",async()=>{
 const controller=createTeamChatRealtimeController(ports);await controller.connect();
 expect(ports.authorize).toHaveBeenCalled();expect(ports.load).toHaveBeenCalled();expect(ports.subscribe).toHaveBeenCalledWith(descriptor,expect.any(Function),expect.any(Function),expect.any(Function));
 expect(ports.messages).toHaveBeenLastCalledWith(saved);
});
it("connected canonical notification reloads stored data, never renders payload",async()=>{
 await createTeamChatRealtimeController(ports).connect();saved=[...saved,message(4)];event({chatChannelId:id(1),messageId:id(4)});await settle();
 expect(ports.messages).toHaveBeenLastCalledWith(saved);expect(ports.authorize).toHaveBeenCalledTimes(3);
});
it("duplicate deliveries deduplicate canonical IDs and never create rows",async()=>{
 await createTeamChatRealtimeController(ports).connect();saved=[message(3),message(4),message(4)];
 event({chatChannelId:id(1),messageId:id(4)});event({chatChannelId:id(1),messageId:id(4)});await settle();
 expect(ports.messages).toHaveBeenLastCalledWith([message(3),message(4)]);
 const count=vi.mocked(ports.load).mock.calls.length;event({chatChannelId:id(1),messageId:id(4)});await settle();expect(ports.load).toHaveBeenCalledTimes(count);
});
it("event identifiers from other channel, fake identity/role or arbitrary content ignored",async()=>{
 await createTeamChatRealtimeController(ports).connect();const count=vi.mocked(ports.load).mock.calls.length;
 for(const value of [{chatChannelId:id(99),messageId:id(4)},{chatChannelId:id(1),messageId:id(4),role:"ADMIN"},{chatChannelId:id(1),messageId:id(4),content:"untrusted"},{messageId:"bad"}])event(value);
 await settle();expect(ports.load).toHaveBeenCalledTimes(count);
});
it("reconnect reauthorizes and restores canonical storage",async()=>{
 const controller=createTeamChatRealtimeController(ports);await controller.connect();saved=[message(3),message(5)];await controller.reconnect();
 expect(unsubscribe).toHaveBeenCalledOnce();expect(ports.messages).toHaveBeenLastCalledWith(saved);expect(ports.subscribe).toHaveBeenCalledTimes(2);
});
it("removed while disconnected cannot reload or resume subscription",async()=>{
 const controller=createTeamChatRealtimeController(ports);await controller.connect();vi.mocked(ports.authorize).mockRejectedValue(new Error("denied"));await controller.reconnect();
 expect(ports.subscribe).toHaveBeenCalledOnce();expect(ports.messages).toHaveBeenLastCalledWith([]);expect(ports.denied).toHaveBeenCalled();
});
it("automatic SUBSCRIBED callback reauthorizes before refresh",async()=>{
 await createTeamChatRealtimeController(ports).connect();vi.mocked(ports.authorize).mockRejectedValue(new Error("removed"));ready();await settle();
 expect(ports.denied).toHaveBeenCalled();expect(unsubscribe).toHaveBeenCalledOnce();expect(ports.messages).toHaveBeenLastCalledWith([]);
});
it("anonymous/unauthorized connect does not load or subscribe",async()=>{
 vi.mocked(ports.authorize).mockRejectedValue(new Error("Auth required"));await createTeamChatRealtimeController(ports).connect();
 expect(ports.load).not.toHaveBeenCalled();expect(ports.subscribe).not.toHaveBeenCalled();expect(ports.denied).toHaveBeenCalled();
});
it("canonical load denial clears stale view and never subscribes",async()=>{
 vi.mocked(ports.load).mockRejectedValue(new Error("Access denied"));await createTeamChatRealtimeController(ports).connect();
 expect(ports.subscribe).not.toHaveBeenCalled();expect(ports.messages).toHaveBeenLastCalledWith([]);
});
it("canonical pagination deduplicates by database ID",async()=>{
 vi.mocked(ports.load).mockImplementation(async cursor=>cursor?{items:[message(4)],nextCursor:null}:{items:[message(3)],nextCursor:{createdAt:message(3).created_at,id:id(3)}});
 await createTeamChatRealtimeController(ports).connect();expect(ports.messages).toHaveBeenLastCalledWith([message(3),message(4)]);
});
it("channel identity changes or malformed canonical pages fail closed",async()=>{
 vi.mocked(ports.load).mockResolvedValue({items:[{...message(3),chat_channel_id:id(99)}],nextCursor:null});await createTeamChatRealtimeController(ports).connect();expect(ports.subscribe).not.toHaveBeenCalled();expect(ports.denied).toHaveBeenCalled();
});
it("late events after disconnect cannot restore private data",async()=>{
 const controller=createTeamChatRealtimeController(ports);await controller.connect();await controller.disconnect();event({chatChannelId:id(1),messageId:id(4)});await settle();expect(ports.messages).toHaveBeenLastCalledWith([]);
});
it("channel failure clears canonical cache and closes transport",async()=>{
 await createTeamChatRealtimeController(ports).connect();fail();await settle();expect(ports.denied).toHaveBeenCalled();expect(unsubscribe).toHaveBeenCalledOnce();
});
