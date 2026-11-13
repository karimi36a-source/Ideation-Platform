import "server-only";
import {z} from "zod";
import {createServerSupabaseClient} from "@/lib/db/server";
import {AuthorizationError,defineScopedRolePolicy,requireAdminScope} from "@/lib/auth/authorization";
import {organizationSchema} from "@/features/organizations/schema";
import {programSchema,programInputSchema,curriculumSchema,curriculumInputSchema,curriculumStatusSchema} from "./schema";
const configuration={role:"ADMIN",scopeType:"organization",access:"operational"} as const;
const descriptor=(id:string,org:string)=>({id,scope:{type:"organization" as const,id:org},access:"operational" as const,resourcePolicyAllows:true});
const organizationPolicy=defineScopedRolePolicy(configuration,async id=>{
 const client=await createServerSupabaseClient();const {data,error}=await client.from("organizations").select("*").eq("id",id).maybeSingle();
 const parsed=organizationSchema.safeParse(data);return error||!parsed.success||parsed.data.id!==id?null:descriptor(id,id);
});
const programPolicy=defineScopedRolePolicy(configuration,async id=>{
 const client=await createServerSupabaseClient();const {data,error}=await client.from("programs").select("*").eq("id",id).maybeSingle();
 const parsed=programSchema.safeParse(data);return error||!parsed.success||parsed.data.id!==id?null:descriptor(id,parsed.data.organization_id);
});
const curriculumPolicy=defineScopedRolePolicy(configuration,async id=>{
 const client=await createServerSupabaseClient();const version=await client.from("curriculum_versions").select("*").eq("id",id).maybeSingle();
 const v=curriculumSchema.safeParse(version.data);if(version.error||!v.success||v.data.id!==id)return null;
 const program=await client.from("programs").select("*").eq("id",v.data.program_id).maybeSingle();const p=programSchema.safeParse(program.data);
 return program.error||!p.success||p.data.id!==v.data.program_id?null:descriptor(id,p.data.organization_id);
});
function parse<T>(schema:z.ZodType<T>,input:unknown):T{const value=schema.safeParse(input);if(!value.success)throw new AuthorizationError("VALIDATION_ERROR");return value.data;}
function result<T>(schema:z.ZodType<T>,data:unknown,error:{code?:string}|null):T{
 if(error)throw new AuthorizationError(["22023","23514","23503","23505"].includes(error.code??"")?"VALIDATION_ERROR":"FORBIDDEN");
 const value=schema.safeParse(data);if(!value.success)throw new AuthorizationError("FORBIDDEN");return value.data;
}
export async function manageProgram(organizationId:unknown,programId:unknown,input:unknown){
 const gate=await requireAdminScope(organizationPolicy,organizationId);const values=parse(programInputSchema,input);const id=parse(z.uuid().nullable(),programId);
 const client=await createServerSupabaseClient();const {data,error}=await client.rpc("manage_program",{target_organization:gate.resource.scope.id,target_program:id,program_name:values.name,program_code:values.code,program_description:values.description,kind:values.program_type,lifecycle:values.status});
 const p=result(programSchema,data,error);if(p.organization_id!==gate.resource.scope.id||(id!==null&&p.id!==id))throw new AuthorizationError("FORBIDDEN");return p;
}
export async function manageCurriculum(programId:unknown,versionId:unknown,input:unknown){
 const gate=await requireAdminScope(programPolicy,programId);const values=parse(curriculumInputSchema,input);const id=parse(z.uuid().nullable(),versionId);
 const client=await createServerSupabaseClient();const {data,error}=await client.rpc("manage_curriculum",{target_program:gate.resource.id,target_version:id,label:values.version_label,starts_at:values.effective_from,ends_at:values.effective_to,version_notes:values.notes});
 const v=result(curriculumSchema,data,error);if(v.program_id!==gate.resource.id||(id!==null&&v.id!==id))throw new AuthorizationError("FORBIDDEN");return v;
}
export async function transitionCurriculum(versionId:unknown,nextStatus:unknown){
 const gate=await requireAdminScope(curriculumPolicy,versionId);const status=parse(curriculumStatusSchema,nextStatus);
 const client=await createServerSupabaseClient();const {data,error}=await client.rpc("transition_curriculum",{target_version:gate.resource.id,next_status:status});
 const v=result(curriculumSchema,data,error);if(v.id!==gate.resource.id)throw new AuthorizationError("FORBIDDEN");return v;
}
export async function setCurrentCurriculum(programId:unknown,versionId:unknown){
 const gate=await requireAdminScope(programPolicy,programId);const id=parse(z.uuid().nullable(),versionId);
 const client=await createServerSupabaseClient();const {data,error}=await client.rpc("set_current_curriculum",{target_program:gate.resource.id,target_version:id});
 const p=result(programSchema,data,error);if(p.id!==gate.resource.id)throw new AuthorizationError("FORBIDDEN");return p;
}
