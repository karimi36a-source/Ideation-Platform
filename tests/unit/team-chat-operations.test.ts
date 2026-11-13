import {beforeEach,expect,it,vi} from "vitest";
vi.mock("server-only",()=>({}));
const {user,bindings,client,rpc}=vi.hoisted(()=>({user:vi.fn(),bindings:vi.fn(),client:vi.fn(),rpc:vi.fn()}));
vi.mock("@/features/users/service",()=>({requireActivePlatformUser:user}));
vi.mock("@/features/auth/role-assignments",()=>({getActiveRoleAssignments:bindings}));
vi.mock("@/lib/db/server",()=>({createServerSupabaseClient:client}));
import {sendTeamChatMessage,listTeamChatMessages,getTeamChatChannel} from "@/features/chat/service";
import {AuthorizationError} from "@/lib/auth/authorization";
const id=(n:number)=>`00000000-0000-4000-8000-${String(n).padStart(12,"0")}`;
const uid=id(1),tid=id(2),cid=id(3),mid=id(4);
const channel={id:cid,team_id:tid,cohort_id:id(5),workspace_id:id(6),channel_type:"TEAM",name:"Private",status:"active",created_at:"2026-10-01T00:00:00Z"};
const message={id:mid,chat_channel_id:cid,sender_user_id:uid,parent_message_id:null,content:"Hello",message_type:"TEXT",created_at:"2026-10-04T01:00:00.123456Z",edited_at:null,deleted_at:null};
let level:string|null;let row:unknown;
beforeEach(()=>{
 level="read_write";row=channel;user.mockReset().mockResolvedValue({id:uid});bindings.mockReset().mockResolvedValue([]);
 rpc.mockReset().mockImplementation(async(name:string,args:Record<string,unknown>)=>({data:name==="get_team_chat_access"?level:name==="send_team_chat_message"?{...message,content:args.message_content,parent_message_id:args.reply_parent}:name==="list_team_chat_messages"?{items:[message],nextCursor:null}:null,error:null}));
 client.mockReset().mockResolvedValue({rpc,from:()=>{const q={select:()=>q,eq:()=>q,maybeSingle:async()=>({data:row,error:null})};return q;}});
});
it("verified member saves canonical TEXT and returns database sender/time",async()=>{
 expect(await sendTeamChatMessage({teamId:tid,content:" Hello "})).toEqual(message);
 expect(rpc).toHaveBeenCalledWith("send_team_chat_message",{target_team:tid,message_content:"Hello",reply_parent:null});
});
it("same-channel reply passes canonical parent",async()=>{
 expect((await sendTeamChatMessage({teamId:tid,content:"Reply",parentMessageId:id(9)})).parent_message_id).toBe(id(9));
});
it("reload returns stored canonical message with default pagination",async()=>{
 expect(await listTeamChatMessages({teamId:tid})).toEqual({items:[message],nextCursor:null});
 expect(rpc).toHaveBeenCalledWith("list_team_chat_messages",{target_channel:cid,page_limit:50,after_time:null,after_id:null});
});
it("cursor preserves timestamp precision and ID tie-breaker",async()=>{
 const cursor={createdAt:message.created_at,id:mid};await listTeamChatMessages({teamId:tid,cursor,limit:2});
 expect(rpc).toHaveBeenCalledWith("list_team_chat_messages",{target_channel:cid,page_limit:2,after_time:message.created_at,after_id:mid});
});
it("contextual Mentor can read but cannot post",async()=>{
 level="read";await expect(listTeamChatMessages({teamId:tid})).resolves.toMatchObject({items:[message]});
 await expect(sendTeamChatMessage({teamId:tid,content:"Mentor"})).rejects.toMatchObject({code:"FORBIDDEN"});
 expect(rpc.mock.calls.some(c=>c[0]==="send_team_chat_message")).toBe(false);
});
it.each(["removed","unrelated Student","unrelated Master","Admin alone","stale Chat membership"])("%s denied by authoritative access",async()=>{
 level=null;for(const operation of [()=>getTeamChatChannel(tid),()=>sendTeamChatMessage({teamId:tid,content:"Secret"}),()=>listTeamChatMessages({teamId:tid})])await expect(operation()).rejects.toMatchObject({code:"FORBIDDEN",message:"Access denied."});
 expect(rpc.mock.calls.some(c=>c[0]==="send_team_chat_message"||c[0]==="list_team_chat_messages")).toBe(false);
});
it("inaccessible and nonexistent channels have identical safe failure",async()=>{
 row=null;await expect(getTeamChatChannel(tid)).rejects.toMatchObject({code:"FORBIDDEN",message:"Access denied."});
 row=channel;level=null;await expect(getTeamChatChannel(tid)).rejects.toMatchObject({code:"FORBIDDEN",message:"Access denied."});
});
it("anonymous denied before provider",async()=>{
 user.mockRejectedValue(new AuthorizationError("AUTH_REQUIRED"));
 for(const op of [()=>getTeamChatChannel(tid),()=>sendTeamChatMessage({teamId:tid,content:"x"}),()=>listTeamChatMessages({teamId:tid})])await expect(op()).rejects.toMatchObject({code:"AUTH_REQUIRED"});
 expect(client).not.toHaveBeenCalled();
});
it.each([{senderUserId:uid},{role:"ADMIN"},{messageType:"FILE"},{attachmentIds:[id(9)]},{createdAt:message.created_at}])("client-controlled fields %j rejected",async extra=>{
 await expect(sendTeamChatMessage({teamId:tid,content:"x",...extra})).rejects.toMatchObject({code:"VALIDATION_ERROR"});expect(rpc).not.toHaveBeenCalled();
});
it("empty/invalid send and page inputs rejected",async()=>{
 for(const input of [{teamId:tid,content:" \n\t "},{teamId:tid,content:12},{teamId:tid,content:"x",parentMessageId:"bad"}])await expect(sendTeamChatMessage(input)).rejects.toMatchObject({code:"VALIDATION_ERROR"});
 for(const input of [{teamId:tid,limit:101},{teamId:tid,limit:0},{teamId:tid,messageId:mid},{teamId:tid,cursor:{id:mid}}])await expect(listTeamChatMessages(input)).rejects.toMatchObject({code:"VALIDATION_ERROR"});
});
it("spoofed canonical sender or channel denied",async()=>{
 rpc.mockImplementation(async(name:string)=>({data:name==="get_team_chat_access"?level:{...message,sender_user_id:id(99)},error:null}));
 await expect(sendTeamChatMessage({teamId:tid,content:"Hello"})).rejects.toMatchObject({code:"FORBIDDEN"});
});
it("cross-parent validation error is sanitized",async()=>{
 rpc.mockImplementation(async(name:string)=>name==="get_team_chat_access"?{data:level,error:null}:{data:null,error:{code:"22023",message:"private parent channel"}});
 await expect(sendTeamChatMessage({teamId:tid,content:"x",parentMessageId:id(9)})).rejects.toMatchObject({code:"VALIDATION_ERROR",message:"Invalid authorization request."});
});
it("provider exceptions never leak metadata",async()=>{
 rpc.mockRejectedValue(new Error("private database details"));await expect(listTeamChatMessages({teamId:tid})).rejects.toMatchObject({code:"FORBIDDEN",message:"Access denied."});
});
