import "server-only";
import {z} from "zod";
import {createServerSupabaseClient} from "@/lib/db/server";
import {AuthorizationError,defineScopedRolePolicy,requireAdminScope} from "@/lib/auth/authorization";
import {curriculumSchema,programSchema} from "@/features/programs/schema";
import {sessionSchema} from "@/features/sessions/schema";
import {activitySchema,activityInputSchema} from "./schema";
const policy=defineScopedRolePolicy({role:"ADMIN",scopeType:"organization",access:"operational"},async id=>{
 const client=await createServerSupabaseClient();const s=await client.from("session_definitions").select("*").eq("id",id).maybeSingle();const session=sessionSchema.safeParse(s.data);
 if(s.error||!session.success||session.data.id!==id)return null;
 const v=await client.from("curriculum_versions").select("*").eq("id",session.data.curriculum_version_id).maybeSingle();const version=curriculumSchema.safeParse(v.data);
 if(v.error||!version.success||version.data.id!==session.data.curriculum_version_id||version.data.status!=="draft")return null;
 const p=await client.from("programs").select("*").eq("id",version.data.program_id).maybeSingle();const program=programSchema.safeParse(p.data);
 if(p.error||!program.success||program.data.id!==version.data.program_id)return null;
 return {id,scope:{type:"organization",id:program.data.organization_id},access:"operational",resourcePolicyAllows:true};
});
export async function manageActivity(sessionId:unknown,activityId:unknown,input:unknown){
 const gate=await requireAdminScope(policy,sessionId);const fields=activityInputSchema.safeParse(input);const id=z.uuid().nullable().safeParse(activityId);
 if(!fields.success||!id.success)throw new AuthorizationError("VALIDATION_ERROR");
 const client=await createServerSupabaseClient();const {data,error}=await client.rpc("manage_activity",{target_session:gate.resource.id,target_activity:id.data,definition:fields.data});
 if(error)throw new AuthorizationError(["23514","23505","22023","22P02","23502"].includes(error.code)?"VALIDATION_ERROR":"FORBIDDEN");
 const result=activitySchema.safeParse(data);if(!result.success||result.data.session_definition_id!==gate.resource.id||(id.data!==null&&result.data.id!==id.data))throw new AuthorizationError("FORBIDDEN");return result.data;
}
