vi.mock('@/features/notifications/email-delivery',()=>({scheduleCommittedNotificationEmails:vi.fn(async()=>{})}));
import {beforeEach,expect,it,vi} from "vitest";
vi.mock("server-only",()=>({}));
const {user,bindings,client,rpc}=vi.hoisted(()=>({user:vi.fn(),bindings:vi.fn(),client:vi.fn(),rpc:vi.fn()}));
vi.mock("@/features/users/service",()=>({requireActivePlatformUser:user}));
vi.mock("@/features/auth/role-assignments",()=>({getActiveRoleAssignments:bindings}));
vi.mock("@/lib/db/server",()=>({createServerSupabaseClient:client}));
import {GET} from "@/app/api/v1/workspaces/[workspaceId]/route";
import {getWorkspace,listMyWorkspaces} from "@/features/workspaces/service";
import {sendTeamChatMessage,listTeamChatMessages,getTeamChatChannel} from "@/features/chat/service";
import {getTeamChatSubscription} from "@/features/chat/realtime-service";
import {removeTeamMember,addTeamMember} from "@/features/teams/member-service";
import {SYSTEM_ROLE_IDS} from "@/lib/auth/role-codes";
// Actual application operations/resolvers/HTTP handler in one scenario. Only
// verified provider I/O is substituted; canonical history/RLS/side effects use SQL.
const id=(n:number)=>`00000000-0000-4000-8000-${String(n).padStart(12,"0")}`;
const a1=id(6004),a2=id(6005),master=id(6002),b1=id(6006),team=id(6301),wid=id(6302),cid=id(6303),cohort=id(6304),personal=id(6305),membership=id(6306);
const metadata={created_at:"2026-10-04T00:00:00Z",updated_at:"2026-10-04T00:00:00Z"};
const workspace={id:wid,workspace_type:"TEAM",name:"Team A",owner_user_id:null,team_id:team,cohort_id:cohort,project_id:null,status:"active",visibility:"private",settings:{private:"Team A"},created_by:master,updated_by:master,archived_at:null,...metadata};
const personalRow={...workspace,id:personal,workspace_type:"PERSONAL",name:"My Workspace",owner_user_id:a1,team_id:null,cohort_id:null,created_by:a1,updated_by:a1};
const channel={id:cid,channel_type:"TEAM",workspace_id:wid,team_id:team,cohort_id:cohort,name:"Team A Chat",status:"active",created_at:metadata.created_at};
type Message={id:string;chat_channel_id:string;sender_user_id:string;parent_message_id:null;content:string;message_type:string;created_at:string;edited_at:null;deleted_at:null};
let actor:string;let active:boolean;let messages:Message[];
const permitted=()=>actor===a2||(actor===a1&&active);
const route=(workspaceId:string)=>GET(new Request(`http://localhost/api/v1/workspaces/${workspaceId}?userId=${a1}&role=MASTER`),{params:Promise.resolve({workspaceId})});
beforeEach(()=>{
 actor=a1;active=true;messages=[];
 user.mockReset().mockImplementation(async()=>({id:actor}));
 bindings.mockReset().mockImplementation(async()=>[{id:id(6390),user_id:actor,role_id:actor===master?SYSTEM_ROLE_IDS.MASTER:SYSTEM_ROLE_IDS.STUDENT,organization_id:actor===master?null:id(501),program_id:null,cohort_id:actor===master?cohort:null,team_id:null,project_id:null,status:"active",starts_at:"2020-01-01T00:00:00Z",ends_at:null,assigned_by:master,...metadata}]);
 rpc.mockReset().mockImplementation(async(name:string,args:Record<string,unknown>)=>{
  if(name==="get_team_workspace_access")return {data:permitted()?"member":null,error:null};
  if(name==="get_team_chat_access")return {data:permitted()?"read_write":null,error:null};
  if(name==="team_workspace_has_chat_access")return {data:permitted(),error:null};
  if(name==="remove_team_member"){active=false;return {data:{teamId:team,membershipId:membership},error:null};}
  if(name==="send_team_chat_message"){const message={id:id(6400+messages.length),chat_channel_id:cid,sender_user_id:actor,parent_message_id:null,content:String(args.message_content),message_type:"TEXT",created_at:metadata.created_at,edited_at:null,deleted_at:null};messages.push(message);return {data:message,error:null};}
  return {data:{items:messages,nextCursor:null},error:null};
 });
 client.mockReset().mockResolvedValue({rpc,from:(table:string)=>{const filters=new Map<string,unknown>();const q={select:()=>q,eq:(key:string,value:unknown)=>{filters.set(key,value);return q;},maybeSingle:async()=>({data:table==="teams"?{id:team,cohort_id:cohort}:table==="chat_channels"?channel:filters.get("id")===personal?personalRow:filters.get("id")===wid?workspace:null,error:null}),order:()=>({order:async()=>({data:[{id:wid},{id:personal}],error:null})})};return q;}});
});
it("AT-E2E-MEMBER-001 M5 application scenario: send, Master removal, denial, Personal preservation and remaining-user continuity",async()=>{
 expect(await getWorkspace(wid)).toEqual(workspace);expect((await route(wid)).status).toBe(200);expect((await getTeamChatSubscription(team)).userId).toBe(a1);
 const sent=await sendTeamChatMessage({teamId:team,content:"Before removal"});expect(sent.sender_user_id).toBe(a1);expect(sent.created_at).toBeTruthy();expect((await listTeamChatMessages({teamId:team})).items).toEqual([sent]);
 actor=master;expect(await removeTeamMember({teamId:team,userId:a1})).toEqual({teamId:team,membershipId:membership});expect(rpc).toHaveBeenCalledWith("remove_team_member",{target_team:team,target_user:a1,removal_reason:null});
 actor=a1;
 await expect(getWorkspace(wid)).rejects.toMatchObject({code:"FORBIDDEN"});
 for(const op of [()=>getTeamChatChannel(team),()=>listTeamChatMessages({teamId:team}),()=>sendTeamChatMessage({teamId:team,content:"removed"}),()=>getTeamChatSubscription(team),()=>addTeamMember({teamId:team,userId:a1,membershipRole:"member"})])await expect(op()).rejects.toMatchObject({code:"FORBIDDEN"});
 const real=await route(wid),absent=await route(id(9999));expect(real.status).toBe(403);expect(absent.status).toBe(403);expect(await real.json()).toEqual(await absent.json());
 expect(await getWorkspace(personal)).toEqual(personalRow);expect((await route(personal)).status).toBe(200);expect(await listMyWorkspaces()).toEqual([personalRow]);
 expect(messages).toEqual([sent]);
 actor=a2;expect((await listTeamChatMessages({teamId:team})).items).toEqual([sent]);expect(await getWorkspace(wid)).toEqual(workspace);await expect(getWorkspace(personal)).rejects.toMatchObject({code:"FORBIDDEN"});
 const remaining=await sendTeamChatMessage({teamId:team,content:"Team A still works"});expect(remaining.sender_user_id).toBe(a2);expect(messages[0]).toEqual(sent);expect((await getTeamChatSubscription(team)).userId).toBe(a2);
 actor=master;await expect(getWorkspace(personal)).rejects.toMatchObject({code:"FORBIDDEN"});
 actor=b1;await expect(getWorkspace(wid)).rejects.toMatchObject({code:"FORBIDDEN"});await expect(getTeamChatChannel(team)).rejects.toMatchObject({code:"FORBIDDEN"});
});
