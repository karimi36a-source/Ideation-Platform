import {readFileSync} from "node:fs";
import {beforeEach,expect,it,vi} from "vitest";
vi.mock("server-only",()=>({}));
const {user,bindings,client}=vi.hoisted(()=>({user:vi.fn(),bindings:vi.fn(),client:vi.fn()}));
vi.mock("@/features/users/service",()=>({requireActivePlatformUser:user}));
vi.mock("@/features/auth/role-assignments",()=>({getActiveRoleAssignments:bindings}));
vi.mock("@/lib/db/server",()=>({createServerSupabaseClient:client}));
import catalog from "../../fixtures/professional-sessions.json";
import {manageSession} from "@/features/sessions/service";
import {SYSTEM_ROLE_IDS} from "@/lib/auth/role-codes";
const org="00000000-0000-4000-8000-000000000501",pid="00000000-0000-4000-8000-000000000601",vid="00000000-0000-4000-8000-000000000712",uid="00000000-0000-4000-8000-000000000711";
const meta={created_at:"2026-09-01T00:00:00Z",updated_at:"2026-09-01T00:00:00Z"};
const input={session_number:1,title:"Draft fixture",description:"Fixture description",learning_goal:"Fixture goal",sequence:1,status:"active"};
let status="draft";const rpc=vi.fn();
beforeEach(()=>{
 status="draft";user.mockReset().mockResolvedValue({id:uid,account_status:"active"});bindings.mockReset().mockResolvedValue([{id:vid,user_id:uid,role_id:SYSTEM_ROLE_IDS.ADMIN,organization_id:org,program_id:null,cohort_id:null,team_id:null,project_id:null,starts_at:"2020-01-01T00:00:00Z",ends_at:null,status:"active",assigned_by:uid,...meta}]);
 rpc.mockReset().mockResolvedValue({data:{...input,id:catalog[0].id,curriculum_version_id:vid,...meta},error:null});
 client.mockReset().mockResolvedValue({rpc,from:(table:string)=>({select:()=>({eq:()=>({maybeSingle:async()=>({data:table==="curriculum_versions"?{id:vid,program_id:pid,version_label:"Fixture",status,effective_from:null,effective_to:null,notes:"",...meta}:{id:pid,organization_id:org,name:"Professional Course",code:"PROFESSIONAL_COURSE",description:"",program_type:"professional_course",status:"active",current_curriculum_version_id:null,current_curriculum_required_status:"approved",...meta},error:null})})})})});
});
it("seed goals and descriptions are exact supported workflow extracts",()=>{
 const source=readFileSync("docs/06_COURSE_ACTIVITY_WORKFLOWS.md","utf8").replace(/\r\n/g,"\n");
 const sections=[...source.matchAll(/^# \d+\. Professional Session (\d+) — ([^\n]+)\n([\s\S]*?)(?=^# \d+\.|(?![\s\S]))/gm)];
 expect(sections).toHaveLength(10);
 for(const [index,section] of sections.entries()){
  const goal=section[3].match(/^## Goal\n([\s\S]*?)(?=^## |(?![\s\S]))/m)![1].trim();
  const output=section[3].match(/^## Primary Output\n([\s\S]*?)(?=^## |(?![\s\S]))/m)?.[1].trim();
  expect(catalog[index]).toMatchObject({session_number:index+1,sequence:index+1,title:section[2],learning_goal:goal,description:output||goal,status:"active"});
 }
});
it("exact-scope Admin may manage draft sessions",async()=>{
 expect((await manageSession(vid,null,input)).curriculum_version_id).toBe(vid);expect(rpc).toHaveBeenCalledWith("manage_session",expect.objectContaining({target_version:vid,target_session:null}));
});
it.each(["approved","retired"])("%s session definitions cannot reach mutation",async parentStatus=>{
 status=parentStatus;await expect(manageSession(vid,null,input)).rejects.toMatchObject({code:"FORBIDDEN"});expect(rpc).not.toHaveBeenCalled();
});
it("Student cannot manage a draft session",async()=>{
 const rows=await bindings();bindings.mockResolvedValue([{...rows[0],role_id:SYSTEM_ROLE_IDS.STUDENT}]);await expect(manageSession(vid,null,input)).rejects.toMatchObject({code:"FORBIDDEN"});expect(rpc).not.toHaveBeenCalled();
});
it("Admin in unrelated organization cannot mutate session",async()=>{
 const rows=await bindings();bindings.mockResolvedValue([{...rows[0],organization_id:"00000000-0000-4000-8000-000000000799"}]);await expect(manageSession(vid,null,input)).rejects.toMatchObject({code:"FORBIDDEN"});expect(rpc).not.toHaveBeenCalled();
});
it("runtime validation rejects browser identity and invalid numbering",async()=>{
 await expect(manageSession(vid,null,{...input,session_number:0,userId:uid})).rejects.toMatchObject({code:"VALIDATION_ERROR"});expect(rpc).not.toHaveBeenCalled();
});

