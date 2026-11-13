import {beforeEach,expect,it,vi} from "vitest";
vi.mock("server-only",()=>({}));
const {user,bindings,client,rpc}=vi.hoisted(()=>({user:vi.fn(),bindings:vi.fn(),client:vi.fn(),rpc:vi.fn()}));
vi.mock("@/features/users/service",()=>({requireActivePlatformUser:user}));
vi.mock("@/features/auth/role-assignments",()=>({getActiveRoleAssignments:bindings}));
vi.mock("@/lib/db/server",()=>({createServerSupabaseClient:client}));
import {sendTeamChatMessage,listTeamChatMessages,getTeamChatChannel} from "@/features/chat/service";
import {getTeamChatSubscription} from "@/features/chat/realtime-service";
import {createTeamChatRealtimeController,type TeamChatRealtimePorts} from "@/features/chat/realtime-controller";
import {AuthorizationError} from "@/lib/auth/authorization";
// Exercise actual service/resolver/controller. Substitute verified provider I/O
// and transport only; canonical SQL/publisher/RLS are independently DB-tested.
const id=(n:number)=>`00000000-0000-4000-8000-${String(n).padStart(12,"0")}`;
const uid=id(6004),tid=id(6201),cid=id(6202);
const channel={id:cid,team_id:tid,cohort_id:id(6203),workspace_id:id(6204),channel_type:"TEAM",name:"Private Team A",status:"active",created_at:"2026-10-04T00:00:00Z"};
const message=(n:number)=>({id:id(n),chat_channel_id:cid,sender_user_id:uid,parent_message_id:null,content:`Canonical ${n}`,message_type:"TEXT",created_at:"2026-10-04T01:00:00.123456Z",edited_at:null,deleted_at:null});
let level:string|null;let canonical:ReturnType<typeof message>[];let event:(value:unknown)=>void;
let ports:TeamChatRealtimePorts;
beforeEach(()=>{
 level="read_write";canonical=[message(6210)];
 user.mockReset().mockResolvedValue({id:uid});bindings.mockReset().mockResolvedValue([]);
 rpc.mockReset().mockImplementation(async(name:string,args:Record<string,unknown>)=>{
  if(name==="get_team_chat_access")return {data:level,error:null};
  if(name==="send_team_chat_message"){const saved={...message(6211),content:args.message_content as string,parent_message_id:args.reply_parent as null};canonical.push(saved);return {data:saved,error:null};}
  return {data:{items:canonical,nextCursor:null},error:null};
 });
 client.mockReset().mockResolvedValue({rpc,from:()=>{const q={select:()=>q,eq:()=>q,maybeSingle:async()=>({data:channel,error:null})};return q;}});
 ports={authorize:()=>getTeamChatSubscription(tid),load:cursor=>listTeamChatMessages({teamId:tid,...(cursor?{cursor}:{})}),subscribe:vi.fn(async(_d,e)=>{event=e;return async()=>{};}),messages:vi.fn(),denied:vi.fn()};
});
it("AT-CHAT-001: canonical service send plus duplicate event reconciliation never duplicates storage",async()=>{
 const controller=createTeamChatRealtimeController(ports);await controller.connect();
 const saved=await sendTeamChatMessage({teamId:tid,content:"Canonical new message"});
 expect(saved.sender_user_id).toBe(uid);expect(saved.created_at).toBeTruthy();
 event({chatChannelId:cid,messageId:saved.id});event({chatChannelId:cid,messageId:saved.id});
 await vi.waitFor(()=>expect(ports.messages).toHaveBeenLastCalledWith(canonical));
 expect(canonical).toHaveLength(2);expect(new Set(canonical.map(m=>m.id)).size).toBe(2);
 expect(rpc.mock.calls.filter(c=>c[0]==="send_team_chat_message")).toHaveLength(1);
});
it("AT-CHAT-004: refresh/new controller and reconnect load canonical service history without event delivery",async()=>{
 const first=createTeamChatRealtimeController(ports);await first.connect();
 canonical.push(message(6212));await first.reconnect();expect(ports.messages).toHaveBeenLastCalledWith(canonical);
 await first.disconnect();const refreshed=createTeamChatRealtimeController(ports);await refreshed.connect();
 expect(ports.messages).toHaveBeenLastCalledWith(canonical);expect(rpc).toHaveBeenCalledWith("list_team_chat_messages",{target_channel:cid,page_limit:50,after_time:null,after_id:null});
});
it.each(["B1","B2","unrelated Master"])("AT-CHAT-002: %s cannot use exact/forged Team or Channel IDs",async label=>{
 user.mockResolvedValue({id:id(label==="B1"?6006:label==="B2"?6007:6003)});level=null;
 for(const op of [()=>getTeamChatChannel(tid),()=>listTeamChatMessages({teamId:tid}),()=>getTeamChatSubscription(tid),()=>sendTeamChatMessage({teamId:tid,content:"bypass"})])await expect(op()).rejects.toMatchObject({code:"FORBIDDEN",message:"Access denied."});
 expect(rpc.mock.calls.some(c=>c[0]==="list_team_chat_messages"||c[0]==="send_team_chat_message")).toBe(false);
 await createTeamChatRealtimeController(ports).connect();expect(ports.subscribe).not.toHaveBeenCalled();
});
it("AT-CHAT-003: removed A1 cannot send, reload or reconnect despite known IDs",async()=>{
 const controller=createTeamChatRealtimeController(ports);await controller.connect();level=null;
 await expect(sendTeamChatMessage({teamId:tid,content:"removed"})).rejects.toMatchObject({code:"FORBIDDEN"});
 await expect(listTeamChatMessages({teamId:tid})).rejects.toMatchObject({code:"FORBIDDEN"});
 await controller.reconnect();expect(ports.subscribe).toHaveBeenCalledTimes(1);expect(ports.messages).toHaveBeenLastCalledWith([]);expect(ports.denied).toHaveBeenCalled();
});
it("sender/role/channel spoofing never reaches canonical send",async()=>{
 for(const extra of [{sender_user_id:id(6005)},{senderUserId:id(6005)},{role:"ADMIN"},{chatChannelId:id(9999)}])await expect(sendTeamChatMessage({teamId:tid,content:"spoof",...extra})).rejects.toMatchObject({code:"VALIDATION_ERROR"});
 expect(rpc).not.toHaveBeenCalled();
});
it("contextual Mentor reads but cannot post; Team Lead retains read/write only",async()=>{
 level="read";expect((await listTeamChatMessages({teamId:tid})).items).toEqual(canonical);await expect(sendTeamChatMessage({teamId:tid,content:"Mentor"})).rejects.toMatchObject({code:"FORBIDDEN"});
 level="read_write";await expect(sendTeamChatMessage({teamId:tid,content:"Lead"})).resolves.toMatchObject({sender_user_id:uid,content:"Lead"});
});
it("anonymous and archived sessions cannot obtain a realtime subscription",async()=>{
 user.mockRejectedValue(new AuthorizationError("AUTH_REQUIRED"));await createTeamChatRealtimeController(ports).connect();expect(ports.subscribe).not.toHaveBeenCalled();
 user.mockResolvedValue({id:uid});level=null;await createTeamChatRealtimeController(ports).connect();expect(ports.subscribe).not.toHaveBeenCalled();await expect(sendTeamChatMessage({teamId:tid,content:"archive"})).rejects.toMatchObject({code:"FORBIDDEN"});
});
