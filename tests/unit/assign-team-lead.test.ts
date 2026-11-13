vi.mock('@/features/notifications/email-delivery',()=>({scheduleCommittedNotificationEmails:vi.fn(async()=>{})}));
import {beforeEach,expect,it,vi} from "vitest";
vi.mock("server-only",()=>({}));
const {user,bindings,client,rpc}=vi.hoisted(()=>({user:vi.fn(),bindings:vi.fn(),client:vi.fn(),rpc:vi.fn()}));
vi.mock("@/features/users/service",()=>({requireActivePlatformUser:user}));
vi.mock("@/features/auth/role-assignments",()=>({getActiveRoleAssignments:bindings}));
vi.mock("@/lib/db/server",()=>({createServerSupabaseClient:client}));
import {assignTeamLead} from "@/features/teams/member-service";
import {AuthorizationError} from "@/lib/auth/authorization";
import {SYSTEM_ROLE_IDS} from "@/lib/auth/role-codes";
const uuid=(n:number)=>`00000000-0000-4000-8000-${String(n).padStart(12,"0")}`;
const uid=uuid(4101),cid=uuid(4102),tid=uuid(4103),wid=uuid(4104),org=uuid(501),pid=uuid(601),target=uuid(4110);
const result={teamId:tid,userId:target,membershipId:uuid(4105)};
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
 rpc.mockReset().mockImplementation(async(name:string)=>({data:name==="assign_team_lead"?result:name==="get_team_workspace_access"?membership:name==="get_team_chat_access"?chatLevel:name==="team_workspace_has_chat_access"?chatLevel!==null:null,error:null}));
 client.mockReset().mockResolvedValue({rpc,from:(table:string)=>({select:()=>({eq:(_key:string,id:string)=>({maybeSingle:async()=>({data:table==="teams"?{id,cohort_id:cid}:table==="cohorts"?{id,program_id:pid}:table==="programs"?{id,organization_id:org}:workspace,error:null})}),order:()=>({order:async()=>({data:[{id:wid}],error:null})})})})});
});
it.each(["MASTER","ADMIN"] as const)("%s assigns through one identity-bound atomic RPC",async role=>{
 bindings.mockResolvedValue([assignment(role)]);
 expect(await assignTeamLead({teamId:tid,userId:target})).toEqual(result);
 expect(rpc).toHaveBeenCalledExactlyOnceWith("assign_team_lead",{target_team:tid,target_user:target});
});
it("exact Team-scoped Master may assign in own Team",async()=>{
 bindings.mockResolvedValue([assignment("MASTER",tid,true)]);await expect(assignTeamLead({teamId:tid,userId:target})).resolves.toEqual(result);
 expect(rpc).toHaveBeenCalledWith("assign_team_lead",{target_team:tid,target_user:target});
});
it.each(["STUDENT","MENTOR"] as const)("%s or contextual Lead cannot assign or fake Admin authority",async role=>{
 bindings.mockResolvedValue([assignment(role)]);
 await expect(assignTeamLead({teamId:tid,userId:target,role:"ADMIN",actorUserId:uid})).rejects.toMatchObject({code:"FORBIDDEN",message:"Access denied."});expect(rpc).not.toHaveBeenCalled();
});
it.each(["MASTER","ADMIN"] as const)("unrelated %s denied",async role=>{
 bindings.mockResolvedValue([assignment(role,uuid(4199))]);await expect(assignTeamLead({teamId:tid,userId:target})).rejects.toMatchObject({code:"FORBIDDEN"});expect(rpc).not.toHaveBeenCalled();
});
it.each(["inactive","expired","future"])("%s assignment cannot assign",async kind=>{
 const row=assignment("MASTER");bindings.mockResolvedValue([{...row,status:kind==="inactive"?"inactive":"active",starts_at:kind==="future"?"2999-01-01T00:00:00Z":row.starts_at,ends_at:kind==="expired"?"2020-02-01T00:00:00Z":null}]);
 await expect(assignTeamLead({teamId:tid,userId:target})).rejects.toMatchObject({code:"FORBIDDEN"});expect(rpc).not.toHaveBeenCalled();
});
it("anonymous caller cannot reach provider",async()=>{
 user.mockRejectedValue(new AuthorizationError("AUTH_REQUIRED"));await expect(assignTeamLead({teamId:tid,userId:target})).rejects.toMatchObject({code:"AUTH_REQUIRED"});expect(rpc).not.toHaveBeenCalled();
});
it("actor/scope claims and invalid reason rejected",async()=>{
 for(const input of [{teamId:tid,userId:target,membershipRole:"team_lead"},{teamId:tid,userId:target,cohortId:cid},{teamId:"invalid",userId:target}])await expect(assignTeamLead(input)).rejects.toMatchObject({code:"VALIDATION_ERROR"});
 expect(rpc).not.toHaveBeenCalled();
});
it("missing/removed membership rejection is stable",async()=>{
 rpc.mockResolvedValue({data:null,error:{code:"22023",message:"private target status"}});await expect(assignTeamLead({teamId:tid,userId:target})).rejects.toMatchObject({code:"VALIDATION_ERROR"});
});
it("provider and malformed return details never leak",async()=>{
 rpc.mockRejectedValue(new Error("private removal SQL"));await expect(assignTeamLead({teamId:tid,userId:target})).rejects.toMatchObject({code:"FORBIDDEN",message:"Access denied."});
 rpc.mockResolvedValue({data:{...result,teamId:uuid(4199)},error:null});await expect(assignTeamLead({teamId:tid,userId:target})).rejects.toMatchObject({code:"FORBIDDEN"});
});
it("verified identity changing during removal is rejected safely",async()=>{
 rpc.mockImplementation(async()=>{user.mockResolvedValue({id:target});return {data:result,error:null};});
 await expect(assignTeamLead({teamId:tid,userId:target})).rejects.toMatchObject({code:"FORBIDDEN"});
});
it("different existing Lead conflict has stable approved API error",async()=>{
 rpc.mockResolvedValue({data:null,error:{code:"23505",message:"private existing Lead ID"}});
 await expect(assignTeamLead({teamId:tid,userId:target})).rejects.toMatchObject({code:"VALIDATION_ERROR",message:"Invalid authorization request."});
});
it("same Lead retry returns same membership without creating a membership",async()=>{
 expect(await assignTeamLead({teamId:tid,userId:target})).toEqual(await assignTeamLead({teamId:tid,userId:target}));
 expect(rpc.mock.calls.every(c=>c[0]==="assign_team_lead")).toBe(true);
});
