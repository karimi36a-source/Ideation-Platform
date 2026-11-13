vi.mock('@/features/notifications/email-delivery',()=>({scheduleCommittedNotificationEmails:vi.fn(async()=>{})}));
import {beforeEach,expect,it,vi} from "vitest";
vi.mock("server-only",()=>({}));
const {user,assignments,client}=vi.hoisted(()=>({user:vi.fn(),assignments:vi.fn(),client:vi.fn()}));
vi.mock("@/features/users/service",()=>({requireActivePlatformUser:user}));
vi.mock("@/features/auth/role-assignments",()=>({getActiveRoleAssignments:assignments}));
vi.mock("@/lib/db/server",()=>({createServerSupabaseClient:client}));
// Real HTTP handler, retrieval/resolvers and Chat services; provider I/O only is
// substituted. Canonical operations and RLS use real PostgreSQL in integration.
import {AuthorizationError} from "@/lib/auth/authorization";
import {SYSTEM_ROLE_IDS} from "@/lib/auth/role-codes";
import {addTeamMember,assignTeamLead,removeTeamMember} from "@/features/teams/member-service";
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
const assignment=(role:"MASTER"|"MENTOR"|"STUDENT")=>({id:uuid(6190),user_id:actor,role_id:SYSTEM_ROLE_IDS[role],organization_id:role==="MASTER"?null:uuid(501),program_id:null,cohort_id:role==="MASTER"?uuid(9998):null,team_id:null,project_id:null,status:"active",starts_at:"2020-01-01T00:00:00Z",ends_at:null,assigned_by:uuid(6001),...meta});
const route=(id=wid)=>GET(new Request(`http://localhost/api/v1/workspaces/${id}?role=ADMIN&cohort_id=${workspace.cohort_id}`,{headers:{"x-user-id":a1,"x-role":"ADMIN"}}),{params:Promise.resolve({workspaceId:id})});
beforeEach(()=>{
 actor=a1;active=true;archived=false;
 user.mockReset().mockImplementation(async()=>({id:actor}));assignments.mockReset().mockImplementation(async()=>[assignment(actor===uuid(6003)?"MASTER":actor===uuid(6009)?"MENTOR":"STUDENT")]);
 client.mockReset().mockResolvedValue({
  rpc:async(name:string)=>({data:name==="get_team_workspace_access"?(allowed()?"member":null):name==="get_team_chat_access"?(allowed()?"read_write":null):name==="team_workspace_has_chat_access"?allowed():name==="list_team_chat_messages"?{items:[message],nextCursor:null}:null,error:null}),
  from:(table:string)=>{const filters=new Map<string,unknown>();const q={select:()=>q,eq:(key:string,value:unknown)=>{filters.set(key,value);return q;},maybeSingle:async()=>({data:table==="teams"?{id:tid,cohort_id:workspace.cohort_id}:table==="chat_channels"?channel:filters.get("id")===personal?personalRow:filters.get("id")===wid?workspace:null,error:null}),order:()=>({order:async()=>({data:[{id:wid},{id:personal}],error:null})})};return q;},
 });
});

it.each(["B1","B2","unrelated Master","unrelated Mentor","removed member"])("M5.16 %s: exact/absent IDs and spoofed claims expose identical safe denial",async label=>{
 actor=uuid(label==="B1"?6006:label==="B2"?6007:label==="unrelated Master"?6003:label==="unrelated Mentor"?6009:6010);active=false;
 const errors=[];
 for(const resource of [wid,uuid(9999)]){const response=await route(resource);expect(response.status).toBe(403);expect(response.headers.get("cache-control")).toBe("private, no-store");errors.push(await response.json());}
 expect(errors).toEqual(Array(2).fill({ok:false,error:{code:"FORBIDDEN",message:"Access denied."}}));
 await expect(getWorkspace(wid)).rejects.toMatchObject({code:"FORBIDDEN",message:"Access denied."});expect(await listMyWorkspaces()).toEqual([]);
 for(const op of [()=>getTeamChatChannel(tid),()=>getTeamChatChannel(uuid(9999)),()=>listTeamChatMessages({teamId:tid}),()=>sendTeamChatMessage({teamId:tid,content:"known Team A"}),()=>getTeamChatSubscription(tid)])await expect(op()).rejects.toMatchObject({code:"FORBIDDEN",message:"Access denied."});
 for(const op of [()=>addTeamMember({teamId:tid,userId:actor,membershipRole:"team_lead"}),()=>assignTeamLead({teamId:tid,userId:actor}),()=>removeTeamMember({teamId:tid,userId:a1})])await expect(op()).rejects.toMatchObject({code:"FORBIDDEN"});
});
it("M5.16 forged Chat/channel/sender/membership claims never establish identity or authority",async()=>{
 actor=b1;active=false;
 for(const extra of [{workspaceId:wid},{chatChannelId:ch},{userId:a1},{sender_user_id:a1},{senderUserId:a1},{membershipRole:"team_lead"},{role:"MASTER"}])await expect(sendTeamChatMessage({teamId:tid,content:"spoof",...extra})).rejects.toMatchObject({code:"VALIDATION_ERROR"});
 await expect(addTeamMember({teamId:tid,userId:a1,membershipRole:"team_lead",actorUserId:uuid(6002)})).rejects.toMatchObject({code:"FORBIDDEN"});
});
it("M5.16 anonymous route/service fails before private provider data",async()=>{
 user.mockRejectedValue(new AuthorizationError("AUTH_REQUIRED"));const response=await route();expect(response.status).toBe(401);expect(await response.json()).toEqual({ok:false,error:{code:"AUTH_REQUIRED",message:"Authentication required."}});
 await expect(getWorkspace(wid)).rejects.toMatchObject({code:"AUTH_REQUIRED"});
});
it("M5.16 authorized Workspace/Chat behavior remains functional",async()=>{
 expect(await getWorkspace(wid)).toEqual(workspace);expect((await route()).status).toBe(200);
 expect(await getTeamChatChannel(tid)).toEqual(channel);expect((await listTeamChatMessages({teamId:tid})).items).toEqual([message]);expect((await getTeamChatSubscription(tid)).chatChannelId).toBe(ch);
});
