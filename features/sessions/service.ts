import "server-only";
import {z} from "zod";
import {createServerSupabaseClient} from "@/lib/db/server";
import {AuthorizationError,defineScopedRolePolicy,requireAdminScope} from "@/lib/auth/authorization";
import {curriculumSchema,programSchema} from "@/features/programs/schema";
import {sessionSchema,sessionInputSchema} from "./schema";
const policy=defineScopedRolePolicy({role:"ADMIN",scopeType:"organization",access:"operational"},async id=>{
 const client=await createServerSupabaseClient();const v=await client.from("curriculum_versions").select("*").eq("id",id).maybeSingle();const version=curriculumSchema.safeParse(v.data);
 if(v.error||!version.success||version.data.id!==id||version.data.status!=="draft")return null;
 const p=await client.from("programs").select("*").eq("id",version.data.program_id).maybeSingle();const program=programSchema.safeParse(p.data);
 if(p.error||!program.success||program.data.id!==version.data.program_id)return null;
 return {id,scope:{type:"organization",id:program.data.organization_id},access:"operational",resourcePolicyAllows:true};
});
export async function manageSession(versionId:unknown,sessionId:unknown,input:unknown){
 const gate=await requireAdminScope(policy,versionId);const fields=sessionInputSchema.safeParse(input);const id=z.uuid().nullable().safeParse(sessionId);
 if(!fields.success||!id.success)throw new AuthorizationError("VALIDATION_ERROR");
 const client=await createServerSupabaseClient();const {data,error}=await client.rpc("manage_session",{target_version:gate.resource.id,target_session:id.data,number:fields.data.session_number,session_title:fields.data.title,session_description:fields.data.description,goal:fields.data.learning_goal,session_position:fields.data.sequence,lifecycle:fields.data.status});
 if(error)throw new AuthorizationError(["23514","23505","22023"].includes(error.code)?"VALIDATION_ERROR":"FORBIDDEN");
 const result=sessionSchema.safeParse(data);if(!result.success||result.data.curriculum_version_id!==gate.resource.id||(id.data!==null&&result.data.id!==id.data))throw new AuthorizationError("FORBIDDEN");return result.data;
}

