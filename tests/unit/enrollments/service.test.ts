import {beforeEach,expect,it,vi} from "vitest";
vi.mock("server-only",()=>({}));
const {user,bindings,client}=vi.hoisted(()=>({user:vi.fn(),bindings:vi.fn(),client:vi.fn()}));
vi.mock("@/features/users/service",()=>({requireActivePlatformUser:user}));
vi.mock("@/features/auth/role-assignments",()=>({getActiveRoleAssignments:bindings}));
vi.mock("@/lib/db/server",()=>({createServerSupabaseClient:client}));
import {enrollUser,removeEnrollment,listCohortEnrollments,listMyEnrollments,transitionEnrollment} from "@/features/enrollments/service";
import {enrollUserSchema,enrollmentRoleSchema,enrollmentStatusSchema} from "@/features/enrollments/schema";
import {requireEnrollmentRead} from "@/lib/auth/enrollment-access";
import {getCohort} from "@/features/cohorts/service";
import {SYSTEM_ROLE_IDS} from "@/lib/auth/role-codes";
const uuid=(n:number)=>`00000000-0000-4000-8000-${String(n).padStart(12,"0")}`;
const uid=uuid(1101),org=uuid(501),pid=uuid(601),cid=uuid(1110),eid=uuid(1111),target=uuid(1104);
const meta={created_at:"2026-09-01T00:00:00Z",updated_at:"2026-09-01T00:00:00Z"};
const enrollment={id:eid,cohort_id:cid,user_id:target,enrollment_role:"participant",status:"active",joined_at:"2026-09-01T00:00:00Z",completed_at:null as string|null,...meta};
const cohort={id:cid,program_id:pid,curriculum_version_id:uuid(602),name:"Fixture",start_date:"2026-10-01",end_date:null,status:"planned",primary_master_id:uid,primary_master_assignment_id:uuid(1112),settings:{},...meta};
const input={cohortId:cid,userId:target,enrollmentRole:"participant"};
const rpc=vi.fn();let primaryMaster=uid;let row={...enrollment};let rows=[row];
function binding(role:"ADMIN"|"MASTER"|"STUDENT",scope:string=org){return {id:uuid(1113),user_id:uid,role_id:SYSTEM_ROLE_IDS[role],organization_id:role==="MASTER"?null:scope,program_id:null,cohort_id:role==="MASTER"?scope:null,team_id:null,project_id:null,starts_at:"2020-01-01T00:00:00Z",ends_at:null,status:"active",assigned_by:uid,...meta};}
beforeEach(()=>{
 primaryMaster=uid;row={...enrollment};rows=[row];user.mockReset().mockResolvedValue({id:uid,account_status:"active"});bindings.mockReset().mockResolvedValue([binding("ADMIN")]);
 rpc.mockReset().mockImplementation(async(name:string)=>({data:name==="has_enrollment_read_access"?false:name==="remove_enrollment"?{...row,status:"removed"}:row,error:null}));
 client.mockReset().mockResolvedValue({rpc,from:(table:string)=>({select:()=>({eq:()=>({maybeSingle:async()=>({data:table==="cohorts"?{...cohort,primary_master_id:primaryMaster}:table==="enrollments"?row:{id:pid,organization_id:org,name:"Professional Course",code:"PROFESSIONAL_COURSE",description:"",program_type:"professional_course",status:"active",current_curriculum_version_id:uuid(602),current_curriculum_required_status:"approved",...meta},error:null}),order:async()=>({data:rows,error:null})})})})});
});
it("Admin creates active enrollment through narrow command",async()=>{expect(await enrollUser(input)).toEqual(enrollment);expect(rpc).toHaveBeenCalledWith("enroll_user",{target_cohort:cid,target_user:target,kind:"participant",initial_status:"active"});});
it("Primary Master may enroll/remove only participants",async()=>{bindings.mockResolvedValue([binding("MASTER",cid)]);expect((await enrollUser(input)).id).toBe(eid);expect((await removeEnrollment({enrollmentId:eid})).status).toBe("removed");});
it("Primary Master cannot create instructor enrollment",async()=>{bindings.mockResolvedValue([binding("MASTER",cid)]);await expect(enrollUser({...input,enrollmentRole:"instructor"})).rejects.toMatchObject({code:"FORBIDDEN"});expect(rpc).not.toHaveBeenCalled();});
it("Primary Master cannot remove instructor enrollment",async()=>{bindings.mockResolvedValue([binding("MASTER",cid)]);row={...row,enrollment_role:"instructor"};await expect(removeEnrollment({enrollmentId:eid})).rejects.toMatchObject({code:"FORBIDDEN"});expect(rpc).not.toHaveBeenCalled();});
it("nonprimary scoped Master cannot mutate participants",async()=>{bindings.mockResolvedValue([binding("MASTER",cid)]);primaryMaster=uuid(1199);await expect(enrollUser(input)).rejects.toMatchObject({code:"FORBIDDEN"});await expect(removeEnrollment({enrollmentId:eid})).rejects.toMatchObject({code:"FORBIDDEN"});});
it("unrelated Master cannot mutate another cohort",async()=>{bindings.mockResolvedValue([binding("MASTER",uuid(1199))]);await expect(enrollUser(input)).rejects.toMatchObject({code:"FORBIDDEN"});await expect(removeEnrollment({enrollmentId:eid})).rejects.toMatchObject({code:"FORBIDDEN"});});
it("Student cannot self-enroll or remove records",async()=>{bindings.mockResolvedValue([binding("STUDENT")]);await expect(enrollUser({...input,userId:uid})).rejects.toMatchObject({code:"FORBIDDEN"});await expect(removeEnrollment({enrollmentId:eid})).rejects.toMatchObject({code:"FORBIDDEN"});expect(rpc).not.toHaveBeenCalled();});
it("Admin outside organization is denied",async()=>{bindings.mockResolvedValue([binding("ADMIN",uuid(1199))]);await expect(enrollUser(input)).rejects.toMatchObject({code:"FORBIDDEN"});});
it("cohort roster is scoped to Admin or assigned Master",async()=>{bindings.mockResolvedValue([binding("MASTER",cid)]);expect(await listCohortEnrollments(cid)).toEqual([enrollment]);bindings.mockResolvedValue([binding("MASTER",uuid(1199))]);await expect(listCohortEnrollments(cid)).rejects.toMatchObject({code:"FORBIDDEN"});});
it("own history derives identity from verified server session",async()=>{bindings.mockResolvedValue([]);rows=[{...row,user_id:uid,status:"removed"}];expect(await listMyEnrollments()).toEqual(rows);rows=[{...row,user_id:target}];await expect(listMyEnrollments()).rejects.toMatchObject({code:"FORBIDDEN"});});
it("browser identity, status escalation and fake role are invalid input",async()=>{await expect(enrollUser({...input,role:"ADMIN",actorId:uid})).rejects.toMatchObject({code:"VALIDATION_ERROR"});expect(enrollUserSchema.safeParse({...input,status:"completed"}).success).toBe(false);});
it("duplicate active failure is stable without SQL detail leakage",async()=>{rpc.mockResolvedValue({data:null,error:{code:"23505",message:"Private SQL detail"}});await expect(enrollUser(input)).rejects.toMatchObject({code:"VALIDATION_ERROR",message:"Invalid authorization request."});});
it("removal preserves completion timestamps",async()=>{row={...row,status:"completed",completed_at:"2026-09-02T00:00:00Z"};expect((await removeEnrollment({enrollmentId:eid})).completed_at).toBe(row.completed_at);});
it("timestamp overwrite from provider fails closed",async()=>{rpc.mockResolvedValue({data:{...row,status:"removed",joined_at:"2026-09-02T00:00:00Z"},error:null});await expect(removeEnrollment({enrollmentId:eid})).rejects.toMatchObject({code:"FORBIDDEN"});});
it("explicit trusted transitions remain Admin-only",async()=>{rpc.mockResolvedValue({data:{...row,status:"completed",completed_at:"2026-09-02T00:00:00Z"},error:null});expect((await transitionEnrollment({enrollmentId:eid,status:"completed"})).status).toBe("completed");bindings.mockResolvedValue([binding("MASTER",cid)]);await expect(transitionEnrollment({enrollmentId:eid,status:"active"})).rejects.toMatchObject({code:"FORBIDDEN"});});
it("approved role/status vocabulary is represented",()=>{expect(enrollmentRoleSchema.options).toEqual(["participant","instructor"]);expect(enrollmentStatusSchema.options).toEqual(["invited","active","completed","withdrawn","removed"]);});
it("enrollment read access grants cohort read without manufacturing a platform role",async()=>{bindings.mockResolvedValue([]);rpc.mockResolvedValue({data:true,error:null});expect(await requireEnrollmentRead(cid)).toBe(cid);expect((await getCohort(cid)).id).toBe(cid);expect(rpc).toHaveBeenCalledWith("has_enrollment_read_access",{scope_id:cid});});
it("revoked enrollment access cannot reuse a snapshot",async()=>{bindings.mockResolvedValue([]);rpc.mockResolvedValueOnce({data:true,error:null}).mockResolvedValue({data:false,error:null});await expect(requireEnrollmentRead(cid)).rejects.toMatchObject({code:"FORBIDDEN"});});

it.each(["ADMIN","MASTER"] as const)("M3.10 %s enrolls four participants using server authorization",async role=>{
 bindings.mockResolvedValue([binding(role,role==="MASTER"?cid:org)]);
 const students=[uuid(1304),uuid(1305),uuid(1306),uuid(1307)];
 rpc.mockImplementation(async(_name:string,args:{target_user:string})=>({data:{...enrollment,user_id:args.target_user},error:null}));
 for(const student of students){expect((await enrollUser({...input,userId:student})).user_id).toBe(student);}
 expect(rpc).toHaveBeenCalledTimes(4);
});
