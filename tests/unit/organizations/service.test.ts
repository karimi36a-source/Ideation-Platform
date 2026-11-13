import {beforeEach,expect,it,vi} from "vitest";
vi.mock("server-only",()=>({}));
const {user,bindings,client}=vi.hoisted(()=>({user:vi.fn(),bindings:vi.fn(),client:vi.fn()}));
vi.mock("@/features/users/service",()=>({requireActivePlatformUser:user}));
vi.mock("@/features/auth/role-assignments",()=>({getActiveRoleAssignments:bindings}));
vi.mock("@/lib/db/server",()=>({createServerSupabaseClient:client}));
import {updateOrganization} from "@/features/organizations/service";
import {SYSTEM_ROLE_IDS} from "@/lib/auth/role-codes";
const id="00000000-0000-4000-8000-000000000501";
const subject="00000000-0000-4000-8000-000000000502";
const row={id,name:"FICI",slug:"fici",status:"active",settings:{},created_at:"2026-09-01T00:00:00Z",updated_at:"2026-09-01T00:00:00Z"};
const rpc=vi.fn();
beforeEach(()=>{
 user.mockReset().mockResolvedValue({id:subject,account_status:"active"});
 bindings.mockReset().mockResolvedValue([{id:"00000000-0000-4000-8000-000000000503",user_id:subject,role_id:SYSTEM_ROLE_IDS.ADMIN,organization_id:id,program_id:null,cohort_id:null,team_id:null,project_id:null,starts_at:"2020-01-01T00:00:00Z",ends_at:null,status:"active",assigned_by:subject,created_at:row.created_at,updated_at:row.updated_at}]);
 rpc.mockReset().mockResolvedValue({data:{...row,name:"New name",status:"inactive"},error:null});
 client.mockReset().mockResolvedValue({from:()=>({select:()=>({eq:()=>({maybeSingle:async()=>({data:row,error:null})})})}),rpc});
});
it("exact organization Admin uses the narrow rename/lifecycle command",async()=>{
 const result=await updateOrganization(id,{name:" New name ",status:"inactive"});
 expect(result.name).toBe("New name"); expect(rpc).toHaveBeenCalledWith("update_organization",{organization_id:id,new_name:"New name",new_status:"inactive"});
});
it("Student cannot reach the mutation command",async()=>{
 const rows=await bindings();bindings.mockResolvedValue([{...rows[0],role_id:SYSTEM_ROLE_IDS.STUDENT}]);
 await expect(updateOrganization(id,{name:"Attack",status:"active"})).rejects.toMatchObject({code:"FORBIDDEN"});expect(rpc).not.toHaveBeenCalled();
});
it("Admin assigned elsewhere cannot mutate this organization",async()=>{
 const rows=await bindings();bindings.mockResolvedValue([{...rows[0],organization_id:"00000000-0000-4000-8000-000000000599"}]);
 await expect(updateOrganization(id,{name:"Attack",status:"active"})).rejects.toMatchObject({code:"FORBIDDEN"});expect(rpc).not.toHaveBeenCalled();
});
it("settings and identity claims are not accepted as update fields",async()=>{
 await expect(updateOrganization(id,{name:"New name",status:"active",settings:{},userId:subject})).rejects.toMatchObject({code:"VALIDATION_ERROR"});expect(rpc).not.toHaveBeenCalled();
});
it("database revocation remains authoritative and provider details stay private",async()=>{
 rpc.mockResolvedValue({data:null,error:{code:"42501",message:"private diagnostics"}});
 await expect(updateOrganization(id,{name:"New name",status:"active"})).rejects.toMatchObject({code:"FORBIDDEN",message:"Access denied."});
});
