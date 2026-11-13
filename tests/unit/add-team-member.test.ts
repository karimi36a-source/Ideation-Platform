vi.mock('@/features/notifications/email-delivery',()=>({scheduleCommittedNotificationEmails:vi.fn(async()=>{})}));
import {beforeEach,expect,it,vi} from "vitest";
vi.mock("server-only",()=>({}));
const {user,bindings,client,rpc}=vi.hoisted(()=>({user:vi.fn(),bindings:vi.fn(),client:vi.fn(),rpc:vi.fn()}));
vi.mock("@/features/users/service",()=>({requireActivePlatformUser:user}));
vi.mock("@/features/auth/role-assignments",()=>({getActiveRoleAssignments:bindings}));
vi.mock("@/lib/db/server",()=>({createServerSupabaseClient:client}));
import {addTeamMember} from "@/features/teams/member-service";
import {getWorkspaceAccess} from "@/features/workspaces/access";
import {getWorkspace,listMyWorkspaces} from "@/features/workspaces/service";
import {getTeamChatAccess} from "@/features/chat/access";
import {AuthorizationError} from "@/lib/auth/authorization";
import {SYSTEM_ROLE_IDS} from "@/lib/auth/role-codes";
const uuid=(n:number)=>`00000000-0000-4000-8000-${String(n).padStart(12,"0")}`;
const uid=uuid(4101),cid=uuid(4102),tid=uuid(4103),wid=uuid(4104),org=uuid(501),pid=uuid(601),target=uuid(4110),channel=uuid(4107);
const result={teamId:tid,membershipId:uuid(4105),chatMembershipId:uuid(4106)};
const meta={created_at:"2026-10-01T00:00:00Z",updated_at:"2026-10-01T00:00:00Z"};
function assignment(role:"ADMIN"|"MASTER"|"STUDENT"|"MENTOR",scope=role==="ADMIN"?org:cid,team=false){return {
 id:uuid(4111),user_id:uid,role_id:SYSTEM_ROLE_IDS[role],organization_id:role==="ADMIN"?scope:null,
 program_id:null,cohort_id:role==="ADMIN"||team?null:scope,team_id:team?scope:null,project_id:null,
 status:"active",starts_at:"2020-01-01T00:00:00Z",ends_at:null,assigned_by:uid,...meta,
};}
const workspace={id:wid,workspace_type:"TEAM",name:"Private Team",owner_user_id:null,team_id:tid,cohort_id:cid,project_id:null,status:"active",visibility:"private",settings:{private:true},created_by:uid,updated_by:uid,archived_at:null,...meta};
let membership:string|null;let chatLevel:string|null;
beforeEach(()=>{
 membership="member";chatLevel="read_write";
 user.mockReset().mockResolvedValue({id:uid});bindings.mockReset().mockResolvedValue([assignment("MASTER")]);
 rpc.mockReset().mockImplementation(async(name:string)=>({data:name==="add_team_member"?result:name==="get_team_workspace_access"?membership:name==="get_team_chat_access"?chatLevel:name==="team_workspace_has_chat_access"?chatLevel!==null:null,error:null}));
 client.mockReset().mockResolvedValue({rpc,from:(table:string)=>({select:()=>({eq:(_key:string,id:string)=>({maybeSingle:async()=>({data:table==="teams"?{id,cohort_id:cid}:table==="cohorts"?{id,program_id:pid}:table==="programs"?{id,organization_id:org}:workspace,error:null})}),order:()=>({order:async()=>({data:[{id:wid}],error:null})})})})});
});
it.each(["MASTER","ADMIN"] as const)("%s uses one verified scoped add RPC",async role=>{
 bindings.mockResolvedValue([assignment(role)]);
 await expect(addTeamMember({teamId:tid,userId:target,membershipRole:"member"})).resolves.toEqual(result);
 expect(rpc).toHaveBeenCalledExactlyOnceWith("add_team_member",{target_team:tid,target_user:target,kind:"member"});
});
it("exact Team-scoped Master can administer that Team",async()=>{
 bindings.mockResolvedValue([assignment("MASTER",tid,true)]);
 await expect(addTeamMember({teamId:tid,userId:target,membershipRole:"member"})).resolves.toEqual(result);
});
it.each(["member","team_lead","mentor"] as const)("%s target context passes without changing platform authority",async membershipRole=>{
 await expect(addTeamMember({teamId:tid,userId:target,membershipRole})).resolves.toEqual(result);
 expect(rpc).toHaveBeenCalledWith("add_team_member",{target_team:tid,target_user:target,kind:membershipRole});
});
it.each(["STUDENT","MENTOR"] as const)("%s and contextual Lead cannot self-add or spoof Admin",async role=>{
 bindings.mockResolvedValue([assignment(role)]);
 await expect(addTeamMember({teamId:tid,userId:uid,membershipRole:"team_lead",role:"ADMIN",actorUserId:target})).rejects.toMatchObject({code:"FORBIDDEN",message:"Access denied."});expect(rpc).not.toHaveBeenCalled();
});
it.each(["MASTER","ADMIN"] as const)("unrelated %s cannot add by known Team ID",async role=>{
 bindings.mockResolvedValue([assignment(role,uuid(4199))]);
 await expect(addTeamMember({teamId:tid,userId:target,membershipRole:"member"})).rejects.toMatchObject({code:"FORBIDDEN"});expect(rpc).not.toHaveBeenCalled();
});
it.each(["inactive","expired","future"])("%s actor assignment denied",async kind=>{
 const row=assignment("MASTER");bindings.mockResolvedValue([{...row,status:kind==="inactive"?"inactive":"active",starts_at:kind==="future"?"2999-01-01T00:00:00Z":row.starts_at,ends_at:kind==="expired"?"2020-02-01T00:00:00Z":null}]);
 await expect(addTeamMember({teamId:tid,userId:target,membershipRole:"member"})).rejects.toMatchObject({code:"FORBIDDEN"});expect(rpc).not.toHaveBeenCalled();
});
it("invalid role or actor/scope claims are rejected",async()=>{
 for(const input of [{teamId:tid,userId:target,membershipRole:"ADMIN"},{teamId:tid,userId:target,membershipRole:"member",cohortId:cid}])await expect(addTeamMember(input)).rejects.toMatchObject({code:"VALIDATION_ERROR"});
 expect(rpc).not.toHaveBeenCalled();
});
it.each(["22023","23505"])("database rejection %s returns stable validation error",async code=>{
 rpc.mockResolvedValue({data:null,error:{code,message:"private target enrollment details"}});
 await expect(addTeamMember({teamId:tid,userId:target,membershipRole:"member"})).rejects.toMatchObject({code:"VALIDATION_ERROR"});
});
it("anonymous caller denied",async()=>{
 user.mockRejectedValue(new AuthorizationError("AUTH_REQUIRED"));await expect(addTeamMember({teamId:tid,userId:target,membershipRole:"member"})).rejects.toMatchObject({code:"AUTH_REQUIRED"});expect(rpc).not.toHaveBeenCalled();
});
it("provider diagnostics cannot expose target or existence metadata",async()=>{
 rpc.mockRejectedValue(new Error("private Team enrollment SQL"));await expect(addTeamMember({teamId:tid,userId:target,membershipRole:"member"})).rejects.toMatchObject({code:"FORBIDDEN",message:"Access denied."});
});
it.each(["member","team_lead","mentor"])("Workspace %s capabilities come from current database membership",async role=>{
 membership=role;chatLevel=role==="mentor"?"read":"read_write";bindings.mockResolvedValue([]);
 expect(await getWorkspaceAccess(wid)).toEqual({canView:true,canCreate:role!=="mentor",canEdit:role!=="mentor",canComment:false,canShare:false,canReview:false,canApprove:false,canManageMembers:false,canAccessChat:true});
 expect(await getWorkspace(wid)).toEqual(workspace);expect(await listMyWorkspaces()).toEqual([workspace]);
 expect(await getTeamChatAccess(channel)).toEqual({canView:true,canPost:role!=="mentor"});
});
it("role/ownership or enrollment alone cannot replace Team membership",async()=>{
 membership=null;chatLevel=null;await expect(getWorkspaceAccess(wid)).rejects.toMatchObject({code:"FORBIDDEN"});expect(await listMyWorkspaces()).toEqual([]);await expect(getTeamChatAccess(channel)).rejects.toMatchObject({code:"FORBIDDEN"});
});
it("Chat membership closure removes Chat capability without inventing Workspace revocation",async()=>{
 chatLevel=null;expect((await getWorkspaceAccess(wid)).canAccessChat).toBe(false);await expect(getTeamChatAccess(channel)).rejects.toMatchObject({code:"FORBIDDEN"});
});
it("membership revoked during resolution fails closed",async()=>{
 let loads=0;rpc.mockImplementation(async(name:string)=>({data:name==="get_team_workspace_access"?(++loads===1?"member":null):true,error:null}));
 await expect(getWorkspaceAccess(wid)).rejects.toMatchObject({code:"FORBIDDEN",message:"Access denied."});
});
it("Chat revocation between checks fails closed",async()=>{
 rpc.mockResolvedValueOnce({data:"read_write",error:null}).mockResolvedValueOnce({data:null,error:null});await expect(getTeamChatAccess(channel)).rejects.toMatchObject({code:"FORBIDDEN"});
});
it("client role and cohort claims cannot resolve Team or Chat access",async()=>{
 await expect(getWorkspaceAccess({id:wid,role:"MASTER",cohortId:cid})).rejects.toMatchObject({code:"VALIDATION_ERROR"});await expect(getTeamChatAccess({id:channel,userId:uid})).rejects.toMatchObject({code:"VALIDATION_ERROR"});
});

import {scheduleCommittedNotificationEmails} from '@/features/notifications/email-delivery';
it('M15.16 schedules only after successful canonical membership commit',async()=>{
 const schedule=vi.mocked(scheduleCommittedNotificationEmails);schedule.mockClear();
 await addTeamMember({teamId:tid,userId:target,membershipRole:"member"});expect(schedule).toHaveBeenCalledExactlyOnceWith({membershipId:result.membershipId,membershipType:'MEMBER_ADDED'});expect(rpc.mock.invocationCallOrder[0]).toBeLessThan(schedule.mock.invocationCallOrder[0]);
 schedule.mockClear();rpc.mockResolvedValue({data:null,error:{code:'42501'}});await expect(addTeamMember({teamId:tid,userId:target,membershipRole:"member"})).rejects.toMatchObject({code:'FORBIDDEN'});expect(schedule).not.toHaveBeenCalled();
});
