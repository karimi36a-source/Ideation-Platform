import {activityMethodSchema,activityInputSchema} from "@/features/activities/schema";
import {readFileSync} from "node:fs";
import {beforeEach,expect,it,vi} from "vitest";
vi.mock("server-only",()=>({}));
const {user,bindings,client}=vi.hoisted(()=>({user:vi.fn(),bindings:vi.fn(),client:vi.fn()}));
vi.mock("@/features/users/service",()=>({requireActivePlatformUser:user}));
vi.mock("@/features/auth/role-assignments",()=>({getActiveRoleAssignments:bindings}));
vi.mock("@/lib/db/server",()=>({createServerSupabaseClient:client}));
import catalog from "../../fixtures/professional-activities.json";
import {manageActivity} from "@/features/activities/service";
import {SYSTEM_ROLE_IDS} from "@/lib/auth/role-codes";
const org="00000000-0000-4000-8000-000000000501",pid="00000000-0000-4000-8000-000000000601",vid="00000000-0000-4000-8000-000000000712",uid="00000000-0000-4000-8000-000000000711";
const meta={created_at:"2026-09-01T00:00:00Z",updated_at:"2026-09-01T00:00:00Z"};
const input={name:"Draft fixture",description:null,method_type:"scamper",workspace_mode:null,sequence:1,instructions:null,ai_role_code:null,requires_review:false,requires_approval:false,completion_rule:null,configuration:{},status:"active"};
let status="draft";const rpc=vi.fn();
beforeEach(()=>{
 status="draft";user.mockReset().mockResolvedValue({id:uid,account_status:"active"});bindings.mockReset().mockResolvedValue([{id:vid,user_id:uid,role_id:SYSTEM_ROLE_IDS.ADMIN,organization_id:org,program_id:null,cohort_id:null,team_id:null,project_id:null,starts_at:"2020-01-01T00:00:00Z",ends_at:null,status:"active",assigned_by:uid,...meta}]);
 rpc.mockReset().mockResolvedValue({data:{...input,id:catalog[0].id,session_definition_id:vid,...meta},error:null});
 client.mockReset().mockResolvedValue({rpc,from:(table:string)=>({select:()=>({eq:()=>({maybeSingle:async()=>({data:table==="session_definitions"?{id:vid,curriculum_version_id:vid,session_number:1,title:"Fixture",description:"",learning_goal:"Fixture",sequence:1,status:"active",...meta}:table==="curriculum_versions"?{id:vid,program_id:pid,version_label:"Fixture",status,effective_from:null,effective_to:null,notes:"",...meta}:{id:pid,organization_id:org,name:"Professional Course",code:"PROFESSIONAL_COURSE",description:"",program_type:"professional_course",status:"active",current_curriculum_version_id:null,current_curriculum_required_status:"approved",...meta},error:null})})})})});
});
it("single seed is supported by the Session 2 curriculum",()=>{
 const source=readFileSync("docs/06_COURSE_ACTIVITY_WORKFLOWS.md","utf8").replace(/\r\n/g,"\n");
 const section=source.split("# 9. Professional Session 2")[1].split("# 10.")[0];
 expect(catalog).toHaveLength(1);expect(section).toContain(catalog[0].name);expect(section).toContain(catalog[0].description);expect(section).toContain(catalog[0].instructions);expect(section).toContain(catalog[0].workspace_mode);expect(section).toContain("review examples");
 expect(catalog[0]).toMatchObject({requires_review:true,requires_approval:false,ai_role_code:null,completion_rule:null,configuration:{},status:"active",method_type:"scamper"});
});
it("exact-scope Admin may manage draft sessions",async()=>{
 expect((await manageActivity(vid,null,input)).session_definition_id).toBe(vid);expect(rpc).toHaveBeenCalledWith("manage_activity",expect.objectContaining({target_session:vid,target_activity:null}));
});
it.each(["approved","retired"])("%s session definitions cannot reach mutation",async parentStatus=>{
 status=parentStatus;await expect(manageActivity(vid,null,input)).rejects.toMatchObject({code:"FORBIDDEN"});expect(rpc).not.toHaveBeenCalled();
});
it("Student cannot manage a draft session",async()=>{
 const rows=await bindings();bindings.mockResolvedValue([{...rows[0],role_id:SYSTEM_ROLE_IDS.STUDENT}]);await expect(manageActivity(vid,null,input)).rejects.toMatchObject({code:"FORBIDDEN"});expect(rpc).not.toHaveBeenCalled();
});
it("Admin in unrelated organization cannot mutate session",async()=>{
 const rows=await bindings();bindings.mockResolvedValue([{...rows[0],organization_id:"00000000-0000-4000-8000-000000000799"}]);await expect(manageActivity(vid,null,input)).rejects.toMatchObject({code:"FORBIDDEN"});expect(rpc).not.toHaveBeenCalled();
});
it("runtime validation rejects browser identity and invalid numbering",async()=>{
 await expect(manageActivity(vid,null,{...input,sequence:0,userId:uid})).rejects.toMatchObject({code:"VALIDATION_ERROR"});expect(rpc).not.toHaveBeenCalled();
});


it("controlled methods and nullable/default metadata",()=>{
 expect(activityMethodSchema.options).toHaveLength(16);
 expect(activityInputSchema.parse({name:"Fixture",method_type:"scamper",sequence:1})).toMatchObject({description:null,workspace_mode:null,instructions:null,ai_role_code:null,completion_rule:null,configuration:{},requires_review:false,requires_approval:false,status:"active"});
 expect(activityInputSchema.safeParse({name:"Fixture",method_type:"invented",sequence:1}).success).toBe(false);
});
