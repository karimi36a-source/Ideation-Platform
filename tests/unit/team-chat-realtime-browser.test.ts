import {expect,it,vi} from "vitest";
const {setAuth,channel,removeChannel,authorize,load}=vi.hoisted(()=>({setAuth:vi.fn().mockResolvedValue(undefined),channel:vi.fn(),removeChannel:vi.fn().mockResolvedValue("ok"),authorize:vi.fn(),load:vi.fn()}));
vi.mock("@/lib/db/browser",()=>({createBrowserSupabaseClient:()=>({realtime:{setAuth},channel,removeChannel})}));
vi.mock("@/features/chat/realtime-actions",()=>({authorizeTeamChatRealtime:authorize,loadTeamChatRealtimePage:load}));
import {createTeamChatRealtime} from "@/features/chat/realtime-browser";
it("Supabase adapter uses authenticated private receive-only Broadcast with no Presence",async()=>{
 const uid="00000000-0000-4000-8000-000000000001",cid="00000000-0000-4000-8000-000000000002";const topic=`team-chat:${cid}:${uid}`;
 authorize.mockResolvedValue({ok:true,data:{userId:uid,chatChannelId:cid,topic}});load.mockResolvedValue({ok:true,data:{items:[],nextCursor:null}});
 const stream={on:vi.fn(),subscribe:vi.fn()};stream.on.mockReturnValue(stream);stream.subscribe.mockReturnValue(stream);channel.mockReturnValue(stream);
 const controller=createTeamChatRealtime(uid,vi.fn(),vi.fn());await controller.connect();
 expect(setAuth).toHaveBeenCalled();expect(channel).toHaveBeenCalledWith(topic,{config:{private:true}});
 expect(stream.on).toHaveBeenCalledExactlyOnceWith("broadcast",{event:"team.message.created"},expect.any(Function));
 await controller.disconnect();expect(removeChannel).toHaveBeenCalledWith(stream);
});
