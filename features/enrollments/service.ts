import "server-only";
import {z} from "zod";
import {createServerSupabaseClient} from "@/lib/db/server";
import {AuthorizationError,defineScopedRolePolicy,requireAdminScope,requireScopedRole,getAuthorizationContext} from "@/lib/auth/authorization";
import {cohortSchema} from "@/features/cohorts/schema";
import {programSchema} from "@/features/programs/schema";
import {enrollmentSchema,enrollUserSchema,removeEnrollmentSchema,transitionEnrollmentSchema,type Enrollment} from "./schema";
async function cohort(id:string){const client=await createServerSupabaseClient();const r=await client.from("cohorts").select("*").eq("id",id).maybeSingle();const c=cohortSchema.safeParse(r.data);return r.error||!c.success||c.data.id!==id?null:c.data;}
const admin=defineScopedRolePolicy({role:"ADMIN",scopeType:"organization",access:"operational"},async id=>{
 const c=await cohort(id);if(!c)return null;const client=await createServerSupabaseClient();const r=await client.from("programs").select("*").eq("id",c.program_id).maybeSingle();const p=programSchema.safeParse(r.data);
 return r.error||!p.success||p.data.id!==c.program_id?null:{id,scope:{type:"organization",id:p.data.organization_id},access:"operational",resourcePolicyAllows:true};
});
const master=defineScopedRolePolicy({role:"MASTER",scopeType:"cohort",access:"educational"},async id=>{const c=await cohort(id);return c?{id,scope:{type:"cohort",id},access:"educational",resourcePolicyAllows:true}:null;});
const primary=defineScopedRolePolicy({role:"MASTER",scopeType:"cohort",access:"educational"},async(id,context)=>{const c=await cohort(id);return c&&c.primary_master_id===context.userId?{id,scope:{type:"cohort",id},access:"educational",resourcePolicyAllows:true}:null;});
async function authorize(id:string,kind:"participant"|"instructor"|"read"){
 try{return await requireAdminScope(admin,id);}catch(error){if(!(error instanceof AuthorizationError)||error.code!=="FORBIDDEN"||kind==="instructor")throw error;return requireScopedRole(kind==="read"?master:primary,id);}
}
function parse<T>(schema:z.ZodType<T>,input:unknown){const p=schema.safeParse(input);if(!p.success)throw new AuthorizationError("VALIDATION_ERROR");return p.data;}
function result(data:unknown,error:{code?:string}|null):Enrollment{if(error)throw new AuthorizationError(["22023","23514","23503","23505","23502","22P02"].includes(error.code??"")?"VALIDATION_ERROR":"FORBIDDEN");const p=enrollmentSchema.safeParse(data);if(!p.success)throw new AuthorizationError("FORBIDDEN");return p.data;}
async function load(id:string){const client=await createServerSupabaseClient();const r=await client.from("enrollments").select("*").eq("id",id).maybeSingle();const e=enrollmentSchema.safeParse(r.data);if(r.error||!e.success||e.data.id!==id)throw new AuthorizationError("FORBIDDEN");return e.data;}
export async function enrollUser(input:unknown){
 await getAuthorizationContext();const v=parse(enrollUserSchema,input);await authorize(v.cohortId,v.enrollmentRole);
 const client=await createServerSupabaseClient();const r=await client.rpc("enroll_user",{target_cohort:v.cohortId,target_user:v.userId,kind:v.enrollmentRole,initial_status:v.status});const e=result(r.data,r.error);
 if(e.cohort_id!==v.cohortId||e.user_id!==v.userId||e.enrollment_role!==v.enrollmentRole||e.status!==v.status)throw new AuthorizationError("FORBIDDEN");return e;
}
export async function removeEnrollment(input:unknown){
 await getAuthorizationContext();const v=parse(removeEnrollmentSchema,input);const before=await load(v.enrollmentId);await authorize(before.cohort_id,before.enrollment_role);
 const client=await createServerSupabaseClient();const r=await client.rpc("remove_enrollment",{target_enrollment:before.id});const e=result(r.data,r.error);
 if(e.id!==before.id||e.cohort_id!==before.cohort_id||e.user_id!==before.user_id||e.enrollment_role!==before.enrollment_role||e.status!=="removed"||e.joined_at!==before.joined_at||e.completed_at!==before.completed_at)throw new AuthorizationError("FORBIDDEN");return e;
}
export async function listCohortEnrollments(cohortId:unknown){
 await getAuthorizationContext();const id=parse(z.uuid(),cohortId);await authorize(id,"read");const client=await createServerSupabaseClient();const r=await client.from("enrollments").select("*").eq("cohort_id",id).order("created_at");
 const rows=z.array(enrollmentSchema).safeParse(r.data);if(r.error||!rows.success||rows.data.some(e=>e.cohort_id!==id))throw new AuthorizationError("FORBIDDEN");await authorize(id,"read");return rows.data;
}
export async function listMyEnrollments(){
 const before=await getAuthorizationContext();const client=await createServerSupabaseClient();const r=await client.from("enrollments").select("*").eq("user_id",before.userId).order("created_at");const rows=z.array(enrollmentSchema).safeParse(r.data);
 const after=await getAuthorizationContext();if(after.userId!==before.userId||r.error||!rows.success||rows.data.some(e=>e.user_id!==before.userId))throw new AuthorizationError("FORBIDDEN");return rows.data;
}
/** Explicit trusted lifecycle transition, with no email/certificate workflow. */
export async function transitionEnrollment(input:unknown){
 await getAuthorizationContext();const v=parse(transitionEnrollmentSchema,input);const before=await load(v.enrollmentId);await requireAdminScope(admin,before.cohort_id);const client=await createServerSupabaseClient();
 const r=await client.rpc("transition_enrollment",{target_enrollment:before.id,next_status:v.status});const e=result(r.data,r.error);if(e.id!==before.id||e.user_id!==before.user_id||e.cohort_id!==before.cohort_id||e.enrollment_role!==before.enrollment_role||e.status!==v.status)throw new AuthorizationError("FORBIDDEN");return e;
}
