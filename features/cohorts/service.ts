import "server-only";
import {z} from "zod";
import {createServerSupabaseClient} from "@/lib/db/server";
import {AuthorizationError,defineScopedRolePolicy,requireAdminScope,requireScopedRole,getAuthorizationContext} from "@/lib/auth/authorization";
import {programSchema} from "@/features/programs/schema";
import {cohortSchema,createCohortSchema,updateCohortSchema,assignMasterToCohortSchema,type Cohort} from "./schema";
import {requireEnrollmentRead} from "@/lib/auth/enrollment-access";

async function programOrganization(id:string){
 const client=await createServerSupabaseClient();const {data,error}=await client.from("programs").select("*").eq("id",id).maybeSingle();const p=programSchema.safeParse(data);
 return error||!p.success||p.data.id!==id?null:p.data.organization_id;
}
async function loadCohort(id:string){
 const client=await createServerSupabaseClient();const {data,error}=await client.from("cohorts").select("*").eq("id",id).maybeSingle();const c=cohortSchema.safeParse(data);
 return error||!c.success||c.data.id!==id?null:c.data;
}
const programPolicy=defineScopedRolePolicy({role:"ADMIN",scopeType:"organization",access:"operational"},async id=>{
 const org=await programOrganization(id);return org?{id,scope:{type:"organization",id:org},access:"operational",resourcePolicyAllows:true}:null;
});
const adminPolicy=defineScopedRolePolicy({role:"ADMIN",scopeType:"organization",access:"operational"},async id=>{
 const c=await loadCohort(id);const org=c?await programOrganization(c.program_id):null;return org?{id,scope:{type:"organization",id:org},access:"operational",resourcePolicyAllows:true}:null;
});
const masterPolicy=defineScopedRolePolicy({role:"MASTER",scopeType:"cohort",access:"educational"},async id=>{
 const c=await loadCohort(id);return c?{id,scope:{type:"cohort",id:c.id},access:"educational",resourcePolicyAllows:true}:null;
});
function parse<T>(schema:z.ZodType<T>,input:unknown){const p=schema.safeParse(input);if(!p.success)throw new AuthorizationError("VALIDATION_ERROR");return p.data;}
function result(data:unknown,error:{code?:string}|null):Cohort{
 if(error)throw new AuthorizationError(["22023","23514","23503","23505","23502","22P02"].includes(error.code??"")?"VALIDATION_ERROR":"FORBIDDEN");
 const p=cohortSchema.safeParse(data);if(!p.success)throw new AuthorizationError("FORBIDDEN");return p.data;
}
export async function createCohort(input:unknown){
 const context=await getAuthorizationContext();if(!context.assignments.some(a=>a.roleCode==="ADMIN"&&a.organization_id!==null))throw new AuthorizationError("FORBIDDEN");
 const v=parse(createCohortSchema,input);const gate=await requireAdminScope(programPolicy,v.programId);
 const client=await createServerSupabaseClient();const {data,error}=await client.rpc("create_cohort",{target_program:gate.resource.id,target_version:v.curriculumVersionId,cohort_name:v.name,starts_on:v.startDate,ends_on:v.endDate,master_id:v.primaryMasterId,lifecycle:v.status,configuration:v.settings});
 const c=result(data,error);if(c.program_id!==v.programId||c.curriculum_version_id!==v.curriculumVersionId||c.primary_master_id!==v.primaryMasterId)throw new AuthorizationError("FORBIDDEN");return c;
}
export async function getCohort(id:unknown){
 // Both policies re-resolve verified identity. Missing and inaccessible IDs match.
 try{await requireAdminScope(adminPolicy,id);}catch(error){if(!(error instanceof AuthorizationError)||error.code!=="FORBIDDEN")throw error;
  try{await requireScopedRole(masterPolicy,id);}catch(masterError){if(!(masterError instanceof AuthorizationError)||masterError.code!=="FORBIDDEN")throw masterError;await requireEnrollmentRead(id);}
 }
 const c=await loadCohort(parse(z.uuid(),id));if(!c)throw new AuthorizationError("FORBIDDEN");return c;
}
export async function listAuthorizedCohorts(){
 await getAuthorizationContext();const client=await createServerSupabaseClient();const {data,error}=await client.from("cohorts").select("*").order("created_at");
 const rows=z.array(cohortSchema).safeParse(data);if(error||!rows.success)throw new AuthorizationError("FORBIDDEN");
 // RLS filters the query, and the reusable authorization layer checks every row.
 return Promise.all(rows.data.map(row=>getCohort(row.id)));
}
export async function updateCohort(input:unknown){
 const v=parse(updateCohortSchema,input);await requireAdminScope(adminPolicy,v.id);
 const before=await loadCohort(v.id);if(!before)throw new AuthorizationError("FORBIDDEN");
 const client=await createServerSupabaseClient();const {data,error}=await client.rpc("update_cohort",{target_cohort:v.id,cohort_name:v.name,starts_on:v.startDate,ends_on:v.endDate,master_id:v.primaryMasterId,lifecycle:v.status,configuration:v.settings});
 const c=result(data,error);if(c.id!==v.id||c.program_id!==before.program_id||c.curriculum_version_id!==before.curriculum_version_id||c.primary_master_id!==v.primaryMasterId)throw new AuthorizationError("FORBIDDEN");return c;
}

export async function assignMasterToCohort(input:unknown){
 const v=parse(assignMasterToCohortSchema,input);await requireAdminScope(adminPolicy,v.cohortId);
 const before=await loadCohort(v.cohortId);if(!before)throw new AuthorizationError("FORBIDDEN");
 const client=await createServerSupabaseClient();const {data,error}=await client.rpc("assign_master_to_cohort",{target_cohort:v.cohortId,master_id:v.primaryMasterId});
 const c=result(data,error);if(c.id!==before.id||c.program_id!==before.program_id||c.curriculum_version_id!==before.curriculum_version_id||c.primary_master_id!==v.primaryMasterId)throw new AuthorizationError("FORBIDDEN");return c;
}
