import {beforeEach,expect,it,vi} from "vitest";
vi.mock("server-only",()=>({}));
const {user,bindings,client}=vi.hoisted(()=>({user:vi.fn(),bindings:vi.fn(),client:vi.fn()}));
vi.mock("@/features/users/service",()=>({requireActivePlatformUser:user}));
vi.mock("@/features/auth/role-assignments",()=>({getActiveRoleAssignments:bindings}));
vi.mock("@/lib/db/server",()=>({createServerSupabaseClient:client}));
import {createCohort,getCohort,listAuthorizedCohorts,updateCohort,assignMasterToCohort} from "@/features/cohorts/service";
import {createCohortSchema,updateCohortSchema,cohortStatusSchema} from "@/features/cohorts/schema";
import {SYSTEM_ROLE_IDS} from "@/lib/auth/role-codes";
const uuid=(n:number)=>`00000000-0000-4000-8000-${String(n).padStart(12,"0")}`;
const org=uuid(501),programId=uuid(601),curriculumVersionId=uuid(602),uid=uuid(1001),master=uuid(1002),cid=uuid(1015);
const meta={created_at:"2026-09-01T00:00:00Z",updated_at:"2026-09-01T00:00:00Z"};
const input={programId,curriculumVersionId,name:"Professional Course fixture",startDate:"2026-10-01",endDate:null,primaryMasterId:master,status:"planned",settings:{}};
const cohort={id:cid,program_id:programId,curriculum_version_id:curriculumVersionId,name:input.name,start_date:input.startDate,end_date:null,primary_master_id:master,primary_master_assignment_id:uuid(1016),status:"planned",settings:{},...meta};
const update={id:cid,name:input.name,startDate:input.startDate,endDate:null,primaryMasterId:master,status:"active",settings:{}};
const rpc=vi.fn();let row:typeof cohort|null=cohort;
function binding(role:"ADMIN"|"MASTER"|"STUDENT",scope:string=org){return {id:uuid(1017),user_id:uid,role_id:SYSTEM_ROLE_IDS[role],organization_id:role==="MASTER"?null:scope,program_id:null,cohort_id:role==="MASTER"?scope:null,team_id:null,project_id:null,starts_at:"2020-01-01T00:00:00Z",ends_at:null,status:"active",assigned_by:uid,...meta};}
beforeEach(()=>{
 row=cohort;user.mockReset().mockResolvedValue({id:uid,account_status:"active"});bindings.mockReset().mockResolvedValue([binding("ADMIN")]);rpc.mockReset().mockResolvedValue({data:cohort,error:null});
 client.mockReset().mockResolvedValue({rpc,from:(table:string)=>({select:()=>({eq:(_key:string,id:string)=>({maybeSingle:async()=>({data:table==="cohorts"?(row&&id===cid?row:null):{id:programId,organization_id:org,name:"Professional Course",code:"PROFESSIONAL_COURSE",description:"",program_type:"professional_course",status:"active",current_curriculum_version_id:curriculumVersionId,current_curriculum_required_status:"approved",...meta},error:null})}),order:async()=>({data:row?[row]:[],error:null})})})});
});
it("Admin creates cohort using one atomic database command",async()=>{
 expect(await createCohort(input)).toMatchObject(cohort);expect(rpc).toHaveBeenCalledWith("create_cohort",expect.objectContaining({target_program:programId,target_version:curriculumVersionId,master_id:master}));
});
it("Admin reads and lists authorized cohorts",async()=>{expect((await getCohort(cid)).id).toBe(cid);expect(await listAuthorizedCohorts()).toEqual([cohort]);});
it("assigned Master reads with exact cohort scope",async()=>{bindings.mockResolvedValue([binding("MASTER",cid)]);expect((await getCohort(cid)).id).toBe(cid);expect(await listAuthorizedCohorts()).toEqual([cohort]);});
it("unrelated Master cannot retrieve cohort",async()=>{bindings.mockResolvedValue([binding("MASTER",uuid(1999))]);await expect(getCohort(cid)).rejects.toMatchObject({code:"FORBIDDEN",message:"Access denied."});});
it.each(["MASTER","STUDENT"] as const)("%s cannot create or update cohorts",async role=>{
 bindings.mockResolvedValue([binding(role,role==="MASTER"?cid:org)]);await expect(createCohort(input)).rejects.toMatchObject({code:"FORBIDDEN"});await expect(updateCohort(update)).rejects.toMatchObject({code:"FORBIDDEN"});expect(rpc).not.toHaveBeenCalled();
});
it("organization Admin cannot cross organization scope",async()=>{bindings.mockResolvedValue([binding("ADMIN",uuid(1999))]);await expect(createCohort(input)).rejects.toMatchObject({code:"FORBIDDEN"});await expect(updateCohort(update)).rejects.toMatchObject({code:"FORBIDDEN"});expect(rpc).not.toHaveBeenCalled();});
it("Admin update/reassignment uses one atomic command",async()=>{rpc.mockResolvedValue({data:{...cohort,primary_master_id:uuid(1003),status:"active"},error:null});expect((await updateCohort({...update,primaryMasterId:uuid(1003)})).primary_master_id).toBe(uuid(1003));expect(rpc).toHaveBeenCalledWith("update_cohort",expect.objectContaining({target_cohort:cid,master_id:uuid(1003)}));});
it("input cannot rewrite fixed curriculum or trusted identity",async()=>{
 await expect(updateCohort({...update,curriculumVersionId:uuid(1999)})).rejects.toMatchObject({code:"VALIDATION_ERROR"});await expect(createCohort({...input,userId:uid,role:"ADMIN"})).rejects.toMatchObject({code:"VALIDATION_ERROR"});expect(rpc).not.toHaveBeenCalled();
});
it("date validation and lifecycle vocabulary match approved policy",()=>{
 expect(cohortStatusSchema.options).toEqual(["planned","active","completed","archived"]);expect(createCohortSchema.parse({...input,endDate:undefined})).toMatchObject({endDate:null});expect(createCohortSchema.safeParse({...input,endDate:"2026-09-30"}).success).toBe(false);expect(createCohortSchema.safeParse({...input,primaryMasterId:"fake"}).success).toBe(false);expect(updateCohortSchema.safeParse({...update,status:undefined}).success).toBe(false);
});
it.each(["23503","22023"])("%s invalid pairing/Master uses stable validation errors",async code=>{rpc.mockResolvedValue({data:null,error:{code,message:"Private database detail"}});await expect(createCohort(input)).rejects.toMatchObject({code:"VALIDATION_ERROR",message:"Invalid authorization request."});});
it("missing and inaccessible cohort do not expose existence",async()=>{row=null;await expect(getCohort(cid)).rejects.toMatchObject({code:"FORBIDDEN",message:"Access denied."});});
it("expired role cannot grant access",async()=>{bindings.mockResolvedValue([{...binding("MASTER",cid),ends_at:"2020-01-02T00:00:00Z"}]);await expect(getCohort(cid)).rejects.toMatchObject({code:"FORBIDDEN"});});
it("response cannot silently change historical curriculum",async()=>{rpc.mockResolvedValue({data:{...cohort,curriculum_version_id:uuid(1999)},error:null});await expect(updateCohort(update)).rejects.toMatchObject({code:"FORBIDDEN"});});

it("explicit assignment uses identity-bound atomic RPC",async()=>{expect(await assignMasterToCohort({cohortId:cid,primaryMasterId:master})).toEqual(cohort);expect(rpc).toHaveBeenCalledWith("assign_master_to_cohort",{target_cohort:cid,master_id:master});});
it.each(["STUDENT","MASTER"] as const)("%s cannot assign a Primary Master",async role=>{bindings.mockResolvedValue([binding(role,cid)]);await expect(assignMasterToCohort({cohortId:cid,primaryMasterId:master})).rejects.toMatchObject({code:"FORBIDDEN"});expect(rpc).not.toHaveBeenCalled();});
it("assignment rejects spoofed identity and role",async()=>{await expect(assignMasterToCohort({cohortId:cid,primaryMasterId:master,userId:uid,role:"ADMIN"})).rejects.toMatchObject({code:"VALIDATION_ERROR"});expect(rpc).not.toHaveBeenCalled();});
it("assignment cannot cross organization scope",async()=>{bindings.mockResolvedValue([binding("ADMIN",uuid(1999))]);await expect(assignMasterToCohort({cohortId:cid,primaryMasterId:master})).rejects.toMatchObject({code:"FORBIDDEN"});expect(rpc).not.toHaveBeenCalled();});
