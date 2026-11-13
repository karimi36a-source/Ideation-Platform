import {beforeEach,expect,it,vi} from "vitest";
vi.mock("server-only",()=>({}));
const {user,bindings,client}=vi.hoisted(()=>({user:vi.fn(),bindings:vi.fn(),client:vi.fn()}));
vi.mock("@/features/users/service",()=>({requireActivePlatformUser:user}));
vi.mock("@/features/auth/role-assignments",()=>({getActiveRoleAssignments:bindings}));
vi.mock("@/lib/db/server",()=>({createServerSupabaseClient:client}));
import {manageProgram,manageCurriculum,setCurrentCurriculum,transitionCurriculum} from "@/features/programs/service";
import {programTypeSchema,curriculumInputSchema} from "@/features/programs/schema";
import {SYSTEM_ROLE_IDS} from "@/lib/auth/role-codes";
const org="00000000-0000-4000-8000-000000000501",pid="00000000-0000-4000-8000-000000000601",vid="00000000-0000-4000-8000-000000000602",uid="00000000-0000-4000-8000-000000000603";
const meta={created_at:"2026-09-01T00:00:00Z",updated_at:"2026-09-01T00:00:00Z"};
const input={name:"Professional Course",code:"PROFESSIONAL_COURSE",description:"",program_type:"professional_course",status:"active"};
const p={...input,id:pid,organization_id:org,current_curriculum_version_id:vid,current_curriculum_required_status:"approved",...meta};
const v={id:vid,program_id:pid,version_label:"2026 v1",status:"approved",effective_from:null,effective_to:null,notes:"",...meta};
const rpc=vi.fn();
beforeEach(()=>{
 user.mockReset().mockResolvedValue({id:uid,account_status:"active"});bindings.mockReset().mockResolvedValue([{id:vid,user_id:uid,role_id:SYSTEM_ROLE_IDS.ADMIN,organization_id:org,program_id:null,cohort_id:null,team_id:null,project_id:null,starts_at:"2020-01-01T00:00:00Z",ends_at:null,status:"active",assigned_by:uid,...meta}]);
 rpc.mockReset().mockImplementation(async name=>({data:name==="manage_program"||name==="set_current_curriculum"?p:v,error:null}));
 client.mockReset().mockResolvedValue({rpc,from:(table:string)=>({select:()=>({eq:()=>({maybeSingle:async()=>({data:table==="programs"?p:table==="curriculum_versions"?v:{id:org,name:"FICI",slug:"fici",status:"active",settings:{},...meta},error:null})})})})});
});
it("approved vocabulary supports all three types and rejects arbitrary type",()=>{
 for(const kind of ["workshop","professional_course","advanced_course"])expect(programTypeSchema.safeParse(kind).success).toBe(true);
 expect(programTypeSchema.safeParse("custom").success).toBe(false);
});
it("exact organization Admin uses narrow Program command",async()=>{
 expect((await manageProgram(org,pid,input)).id).toBe(pid);expect(rpc).toHaveBeenCalledWith("manage_program",expect.objectContaining({target_organization:org,target_program:pid}));
});
it("Student cannot mutate Program or curriculum",async()=>{
 const rows=await bindings();bindings.mockResolvedValue([{...rows[0],role_id:SYSTEM_ROLE_IDS.STUDENT}]);
 await expect(manageProgram(org,pid,input)).rejects.toMatchObject({code:"FORBIDDEN"});await expect(manageCurriculum(pid,null,{version_label:"v2",effective_from:null,effective_to:null,notes:""})).rejects.toMatchObject({code:"FORBIDDEN"});expect(rpc).not.toHaveBeenCalled();
});
it("Admin from another organization cannot reach command",async()=>{
 const rows=await bindings();bindings.mockResolvedValue([{...rows[0],organization_id:"00000000-0000-4000-8000-000000000699"}]);await expect(setCurrentCurriculum(pid,vid)).rejects.toMatchObject({code:"FORBIDDEN"});expect(rpc).not.toHaveBeenCalled();
});
it("curriculum and pointer operations resolve actual parent organization",async()=>{
 await manageCurriculum(pid,null,{version_label:"v2",effective_from:null,effective_to:null,notes:""});await transitionCurriculum(vid,"retired");await setCurrentCurriculum(pid,vid);expect(rpc).toHaveBeenCalledTimes(3);
});
it("direct database failures have stable errors without provider details",async()=>{
 rpc.mockResolvedValue({data:null,error:{code:"23503",message:"private parent details"}});await expect(setCurrentCurriculum(pid,vid)).rejects.toMatchObject({code:"VALIDATION_ERROR",message:"Invalid authorization request."});
});
it("invalid date windows and caller identity claims are rejected",()=>{
 expect(curriculumInputSchema.safeParse({version_label:"v",effective_from:"2026-09-02T00:00:00Z",effective_to:"2026-09-01T00:00:00Z",notes:""}).success).toBe(false);
 expect(curriculumInputSchema.safeParse({version_label:"v",effective_from:null,effective_to:null,notes:"",userId:uid}).success).toBe(false);
});
