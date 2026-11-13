import {beforeEach,expect,it,vi} from "vitest";
vi.mock("server-only",()=>({}));
const {user,bindings,client,rpc}=vi.hoisted(()=>({user:vi.fn(),bindings:vi.fn(),client:vi.fn(),rpc:vi.fn()}));
vi.mock("@/features/users/service",()=>({requireActivePlatformUser:user}));
vi.mock("@/features/auth/role-assignments",()=>({getActiveRoleAssignments:bindings}));
vi.mock("@/lib/db/server",()=>({createServerSupabaseClient:client}));
import {createTeam} from "@/features/teams/service";
import {SYSTEM_ROLE_IDS} from "@/lib/auth/role-codes";
import {AuthorizationError} from "@/lib/auth/authorization";
const uuid=(n:number)=>`00000000-0000-4000-8000-${String(n).padStart(12,"0")}`;
const uid=uuid(3901),cid=uuid(3902),org=uuid(501),pid=uuid(601);
const result={teamId:uuid(3910),workspaceId:uuid(3911),chatChannelId:uuid(3912)};
function assignment(role:"ADMIN"|"MASTER"|"STUDENT"|"MENTOR",scope=role==="ADMIN"?org:cid){return {
 id:uuid(3913),user_id:uid,role_id:SYSTEM_ROLE_IDS[role],organization_id:role==="ADMIN"?scope:null,
 program_id:null,cohort_id:role==="ADMIN"?null:scope,team_id:null,project_id:null,
 status:"active",starts_at:"2020-01-01T00:00:00Z",ends_at:null,assigned_by:uid,
 created_at:"2026-10-01T00:00:00Z",updated_at:"2026-10-01T00:00:00Z",
};}
beforeEach(()=>{
 user.mockReset().mockResolvedValue({id:uid});bindings.mockReset().mockResolvedValue([assignment("MASTER")]);
 rpc.mockReset().mockResolvedValue({data:result,error:null});
 client.mockReset().mockResolvedValue({rpc,from:(table:string)=>({select:()=>({eq:(_key:string,id:string)=>({maybeSingle:async()=>({data:table==="cohorts"?{id,program_id:pid}:{id,organization_id:org},error:null})})})})});
});
it.each(["MASTER","ADMIN"] as const)("authorized %s calls one identity-bound atomic RPC",async role=>{
 bindings.mockResolvedValue([assignment(role)]);
 expect(await createTeam({cohortId:cid,name:" Team C "})).toEqual(result);
 expect(rpc).toHaveBeenCalledExactlyOnceWith("create_team",{target_cohort:cid,team_name:"Team C",team_description:null,lead_user:null,target_project:null});
});
it.each(["STUDENT","MENTOR"] as const)("%s cannot create Team even with fake Admin/user claims",async role=>{
 bindings.mockResolvedValue([assignment(role)]);
 await expect(createTeam({cohortId:cid,name:"Team",role:"ADMIN",userId:uuid(3999)})).rejects.toMatchObject({code:"FORBIDDEN",message:"Access denied."});
 expect(rpc).not.toHaveBeenCalled();
});
it.each(["MASTER","ADMIN"] as const)("%s outside target scope is denied",async role=>{
 bindings.mockResolvedValue([assignment(role,uuid(3999))]);
 await expect(createTeam({cohortId:cid,name:"Team"})).rejects.toMatchObject({code:"FORBIDDEN"});expect(rpc).not.toHaveBeenCalled();
});
it.each(["inactive","expired","future"])("%s assignment cannot authorize creation",async kind=>{
 const row=assignment("MASTER");bindings.mockResolvedValue([{...row,status:kind==="inactive"?"inactive":"active",starts_at:kind==="future"?"2999-01-01T00:00:00Z":row.starts_at,ends_at:kind==="expired"?"2020-02-01T00:00:00Z":null}]);
 await expect(createTeam({cohortId:cid,name:"Team"})).rejects.toMatchObject({code:"FORBIDDEN"});expect(rpc).not.toHaveBeenCalled();
});
it("Project dependency is rejected safely before writes",async()=>{
 await expect(createTeam({cohortId:cid,name:"Team",projectId:uuid(3999)})).rejects.toMatchObject({code:"DEPENDENCY_NOT_MET",message:"Required Team creation dependency is unavailable."});expect(rpc).not.toHaveBeenCalled();
});
it("optional Team Lead is validated by the same identity-bound RPC",async()=>{
 await expect(createTeam({cohortId:cid,name:"Team",teamLeadUserId:uuid(3920)})).resolves.toEqual(result);
 expect(rpc).toHaveBeenCalledExactlyOnceWith("create_team",{target_cohort:cid,team_name:"Team",team_description:null,lead_user:uuid(3920),target_project:null});
});
it("ineligible Team Lead diagnostics are normalized without disclosure",async()=>{
 rpc.mockResolvedValue({data:null,error:{code:"22023",message:"Private enrollment diagnostics"}});
 await expect(createTeam({cohortId:cid,name:"Team",teamLeadUserId:uuid(3920)})).rejects.toMatchObject({code:"VALIDATION_ERROR"});
});
it("client-provided resource bindings cannot be accepted",async()=>{
 await expect(createTeam({cohortId:cid,name:"Team",masterUserId:uid,workspaceId:uuid(3999),chatChannelId:uuid(3998)})).rejects.toMatchObject({code:"VALIDATION_ERROR"});expect(rpc).not.toHaveBeenCalled();
});
it("anonymous creation is denied before provider access",async()=>{
 user.mockRejectedValue(new AuthorizationError("AUTH_REQUIRED"));await expect(createTeam({cohortId:cid,name:"Team"})).rejects.toMatchObject({code:"AUTH_REQUIRED"});expect(rpc).not.toHaveBeenCalled();
});
it("provider diagnostics and malformed returned IDs never leak",async()=>{
 rpc.mockRejectedValue(new Error("Private SQL/owner/cohort diagnostics"));await expect(createTeam({cohortId:cid,name:"Team"})).rejects.toMatchObject({code:"FORBIDDEN",message:"Access denied."});
 rpc.mockResolvedValue({data:{...result,workspaceId:"private invalid ID"},error:null});await expect(createTeam({cohortId:cid,name:"Team"})).rejects.toMatchObject({code:"FORBIDDEN",message:"Access denied."});
});
