vi.mock('@/features/notifications/email-delivery',()=>({scheduleCommittedNotificationEmails:vi.fn(async()=>{})}));
import {beforeEach,expect,it,vi} from "vitest";
vi.mock("server-only",()=>({}));
const {user,bindings,client,rpc}=vi.hoisted(()=>({user:vi.fn(),bindings:vi.fn(),client:vi.fn(),rpc:vi.fn()}));
vi.mock("@/features/users/service",()=>({requireActivePlatformUser:user}));
vi.mock("@/features/auth/role-assignments",()=>({getActiveRoleAssignments:bindings}));
vi.mock("@/lib/db/server",()=>({createServerSupabaseClient:client}));
import {archiveTeam} from "@/features/teams/member-service";
import {AuthorizationError} from "@/lib/auth/authorization";
import {SYSTEM_ROLE_IDS} from "@/lib/auth/role-codes";
const uuid=(n:number)=>`00000000-0000-4000-8000-${String(n).padStart(12,"0")}`;
const uid=uuid(4101),cid=uuid(4102),tid=uuid(4103),wid=uuid(4104),org=uuid(501),pid=uuid(601);
const result={teamId:tid,status:"archived",archivedAt:"2026-10-04T12:00:00+00:00"};
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
 rpc.mockReset().mockImplementation(async(name:string)=>({data:name==="archive_team"?result:name==="get_team_workspace_access"?membership:name==="get_team_chat_access"?chatLevel:name==="team_workspace_has_chat_access"?chatLevel!==null:null,error:null}));
 client.mockReset().mockResolvedValue({rpc,from:(table:string)=>({select:()=>({eq:(_key:string,id:string)=>({maybeSingle:async()=>({data:table==="teams"?{id,cohort_id:cid}:table==="cohorts"?{id,program_id:pid}:table==="programs"?{id,organization_id:org}:workspace,error:null})}),order:()=>({order:async()=>({data:[{id:wid}],error:null})})})})});
});

it.each(["MASTER","ADMIN"] as const)("%s archives through one identity-bound transaction",async role=>{
 bindings.mockResolvedValue([assignment(role)]);expect(await archiveTeam(tid)).toEqual(result);
 expect(rpc).toHaveBeenCalledExactlyOnceWith("archive_team",{target_team:tid});
});
it("Team-scoped Master may archive exactly that Team",async()=>{bindings.mockResolvedValue([assignment("MASTER",tid,true)]);await expect(archiveTeam(tid)).resolves.toEqual(result);});
it.each(["STUDENT","MENTOR"] as const)("%s/contextual Lead denied",async role=>{bindings.mockResolvedValue([assignment(role)]);await expect(archiveTeam(tid)).rejects.toMatchObject({code:"FORBIDDEN"});expect(rpc).not.toHaveBeenCalled();});
it.each(["MASTER","ADMIN"] as const)("unrelated %s denied",async role=>{bindings.mockResolvedValue([assignment(role,uuid(9999))]);await expect(archiveTeam(tid)).rejects.toMatchObject({code:"FORBIDDEN"});expect(rpc).not.toHaveBeenCalled();});
it.each(["inactive","future","expired"])("%s authority denied",async state=>{const row=assignment("MASTER");bindings.mockResolvedValue([{...row,status:state==="inactive"?"inactive":"active",starts_at:state==="future"?"2999-01-01T00:00:00Z":row.starts_at,ends_at:state==="expired"?"2020-01-02T00:00:00Z":null}]);await expect(archiveTeam(tid)).rejects.toMatchObject({code:"FORBIDDEN"});expect(rpc).not.toHaveBeenCalled();});
it("anonymous denied",async()=>{user.mockRejectedValue(new AuthorizationError("AUTH_REQUIRED"));await expect(archiveTeam(tid)).rejects.toMatchObject({code:"AUTH_REQUIRED"});expect(rpc).not.toHaveBeenCalled();});
it("invalid ID or identity/scope object cannot reach RPC",async()=>{for(const input of ["invalid",{teamId:tid,role:"ADMIN",ownerUserId:uid,cohortId:cid}])await expect(archiveTeam(input)).rejects.toMatchObject({code:"VALIDATION_ERROR"});expect(rpc).not.toHaveBeenCalled();});
it("RPC details and wrong result identity never leak",async()=>{rpc.mockResolvedValue({data:null,error:{code:"42501",message:"private Team name"}});await expect(archiveTeam(tid)).rejects.toMatchObject({code:"FORBIDDEN",message:"Access denied."});rpc.mockResolvedValue({data:{...result,teamId:uuid(9999)},error:null});await expect(archiveTeam(tid)).rejects.toMatchObject({code:"FORBIDDEN"});});
it("identity changes cannot produce a trusted result",async()=>{rpc.mockImplementation(async()=>{user.mockResolvedValue({id:uuid(9999)});return {data:result,error:null};});await expect(archiveTeam(tid)).rejects.toMatchObject({code:"FORBIDDEN"});});
it("archive retry returns same durable timestamp",async()=>{expect(await archiveTeam(tid)).toEqual(await archiveTeam(tid));});
