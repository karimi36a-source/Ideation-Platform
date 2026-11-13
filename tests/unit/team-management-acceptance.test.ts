import {beforeEach,expect,it,vi} from "vitest";
vi.mock("server-only",()=>({}));
const {user,assignments,client}=vi.hoisted(()=>({user:vi.fn(),assignments:vi.fn(),client:vi.fn()}));
vi.mock("@/features/users/service",()=>({requireActivePlatformUser:user}));
vi.mock("@/features/auth/role-assignments",()=>({getActiveRoleAssignments:assignments}));
vi.mock("@/lib/db/server",()=>({createServerSupabaseClient:client}));
// Real HTTP handler, retrieval/resolvers and Chat services; provider I/O only is
// substituted. Canonical operations and RLS use real PostgreSQL in integration.
import {GET} from "@/app/api/v1/workspaces/[workspaceId]/route";
import {getWorkspace,listMyWorkspaces} from "@/features/workspaces/service";
import {getTeamChatChannel,listTeamChatMessages,sendTeamChatMessage} from "@/features/chat/service";
import {getTeamChatSubscription} from "@/features/chat/realtime-service";
const uuid=(n:number)=>`00000000-0000-4000-8000-${String(n).padStart(12,"0")}`;
const a1=uuid(6004),a2=uuid(6005),b1=uuid(6006),tid=uuid(6101),wid=uuid(6102),ch=uuid(6103),personal=uuid(6104);
const meta={created_at:"2026-10-04T00:00:00Z",updated_at:"2026-10-04T00:00:00Z"};
const workspace={id:wid,workspace_type:"TEAM",name:"Private Team C",owner_user_id:null,cohort_id:uuid(6105),team_id:tid,project_id:null,status:"active",visibility:"private",settings:{confidential:"Team C only"},created_by:uuid(6002),updated_by:uuid(6002),archived_at:null,...meta};
const personalRow={...workspace,id:personal,workspace_type:"PERSONAL",name:"A2 private",owner_user_id:a2,team_id:null};
const channel={id:ch,channel_type:"TEAM",workspace_id:wid,team_id:tid,cohort_id:workspace.cohort_id,name:"Private Team C Chat",status:"active",created_at:meta.created_at};
const message={id:uuid(6106),chat_channel_id:ch,sender_user_id:a1,parent_message_id:null,content:"private authored history",message_type:"TEXT",created_at:meta.created_at,edited_at:null,deleted_at:null};
let actor:string;let active:boolean;let archived:boolean;
const allowed=()=>actor===a1&&active&&!archived;
const route=(id=wid)=>GET(new Request(`http://localhost/api/v1/workspaces/${id}?role=ADMIN&cohort_id=${workspace.cohort_id}`,{headers:{"x-user-id":a1,"x-role":"ADMIN"}}),{params:Promise.resolve({workspaceId:id})});
beforeEach(()=>{
 actor=a1;active=true;archived=false;
 user.mockReset().mockImplementation(async()=>({id:actor}));assignments.mockReset().mockResolvedValue([]);
 client.mockReset().mockResolvedValue({
  rpc:async(name:string)=>({data:name==="get_team_workspace_access"?(allowed()?"member":null):name==="get_team_chat_access"?(allowed()?"read_write":null):name==="team_workspace_has_chat_access"?allowed():name==="list_team_chat_messages"?{items:[message],nextCursor:null}:null,error:null}),
  from:(table:string)=>{const filters=new Map<string,unknown>();const q={select:()=>q,eq:(key:string,value:unknown)=>{filters.set(key,value);return q;},maybeSingle:async()=>({data:table==="chat_channels"?channel:filters.get("id")===personal?personalRow:filters.get("id")===wid?workspace:null,error:null}),order:()=>({order:async()=>({data:[{id:wid},{id:personal}],error:null})})};return q;},
 });
});
it("AT-TEAM-002: active member accesses Team Workspace route/service and canonical Chat",async()=>{
 expect(await getWorkspace(wid)).toEqual(workspace);expect(await listMyWorkspaces()).toEqual([workspace]);
 const response=await route();expect(response.status).toBe(200);expect(await response.json()).toEqual({ok:true,data:workspace});
 expect(await getTeamChatChannel(tid)).toEqual(channel);expect(await listTeamChatMessages({teamId:tid})).toEqual({items:[message],nextCursor:null});
 expect(await getTeamChatSubscription(tid)).toEqual({chatChannelId:ch,userId:a1,topic:`team-chat:${ch}:${a1}`});
 await expect(getWorkspace(personal)).rejects.toMatchObject({code:"FORBIDDEN"});
});
it("AT-TEAM-003/004: removal revokes exact-ID service/HTTP/Chat/subscription and excludes discovery",async()=>{
 active=false;await expect(getWorkspace(wid)).rejects.toMatchObject({code:"FORBIDDEN",message:"Access denied."});expect(await listMyWorkspaces()).toEqual([]);
 for(const op of [()=>getTeamChatChannel(tid),()=>listTeamChatMessages({teamId:tid}),()=>sendTeamChatMessage({teamId:tid,content:"bypass"}),()=>getTeamChatSubscription(tid)])await expect(op()).rejects.toMatchObject({code:"FORBIDDEN",message:"Access denied."});
 const exact=await route();const absent=await route(uuid(9999));expect(exact.status).toBe(403);expect(absent.status).toBe(403);
 expect(await exact.json()).toEqual(await absent.json());expect(exact.headers.get("cache-control")).toBe("private, no-store");
});
it("AT-TEAM-004: Team B user cannot obtain Team C metadata through claimed identity/scope",async()=>{
 actor=b1;const response=await route();expect(response.status).toBe(403);expect(await response.json()).toEqual({ok:false,error:{code:"FORBIDDEN",message:"Access denied."}});
 await expect(getTeamChatChannel(tid)).rejects.toMatchObject({code:"FORBIDDEN"});await expect(getTeamChatSubscription(tid)).rejects.toMatchObject({code:"FORBIDDEN"});
});
it("archive regression: active historical membership cannot authorize normal route/Chat use",async()=>{
 archived=true;expect((await route()).status).toBe(403);expect(await listMyWorkspaces()).toEqual([]);
 await expect(sendTeamChatMessage({teamId:tid,content:"archive bypass"})).rejects.toMatchObject({code:"FORBIDDEN"});
 await expect(getTeamChatSubscription(tid)).rejects.toMatchObject({code:"FORBIDDEN"});
});
