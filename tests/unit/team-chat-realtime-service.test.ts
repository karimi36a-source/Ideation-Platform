import {beforeEach,expect,it,vi} from "vitest";
vi.mock("server-only",()=>({}));
const {user,bindings,client,rpc}=vi.hoisted(()=>({user:vi.fn(),bindings:vi.fn(),client:vi.fn(),rpc:vi.fn()}));
vi.mock("@/features/users/service",()=>({requireActivePlatformUser:user}));
vi.mock("@/features/auth/role-assignments",()=>({getActiveRoleAssignments:bindings}));
vi.mock("@/lib/db/server",()=>({createServerSupabaseClient:client}));
import {getTeamChatSubscription} from "@/features/chat/realtime-service";
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
it("server creates only identity-bound authorized topic",async()=>{
 expect(await getTeamChatSubscription(tid)).toEqual({chatChannelId:cid,userId:uid,topic:`team-chat:${cid}:${uid}`});
});
it("read-only Mentor subscription allowed without changing send authority",async()=>{
 level="read";await expect(getTeamChatSubscription(tid)).resolves.toMatchObject({userId:uid});
});
it.each(["Team B","removed","unrelated Master","Admin alone","stale Chat membership"])("%s cannot obtain subscription",async()=>{
 level=null;await expect(getTeamChatSubscription(tid)).rejects.toMatchObject({code:"FORBIDDEN"});
});
it("anonymous and browser identity claims cannot establish subscription",async()=>{
 user.mockRejectedValue(new AuthorizationError("AUTH_REQUIRED"));await expect(getTeamChatSubscription(tid)).rejects.toMatchObject({code:"AUTH_REQUIRED"});
 user.mockResolvedValue({id:uid});await expect(getTeamChatSubscription({teamId:tid,userId:uid,role:"ADMIN"})).rejects.toMatchObject({code:"VALIDATION_ERROR"});
});
