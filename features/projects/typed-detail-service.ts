import "server-only";
import {AuthorizationError,getAuthorizationContext} from "@/lib/auth/authorization";
import {createServerSupabaseClient} from "@/lib/db/server";
import {getWorkspaceAccess} from "@/features/workspaces/access";
import {developmentObjectSchema} from "./object-schema";
import {createProblemDetailsSchema,updateProblemDetailsSchema,createIdeaDetailsSchema,updateIdeaDetailsSchema,problemDetailsSchema,ideaDetailsSchema} from "./typed-detail-schema";
async function write(input:unknown,kind:"PROBLEM"|"IDEA",createNew:boolean){try{
 const actor=await getAuthorizationContext();const schema=kind==="PROBLEM"?(createNew?createProblemDetailsSchema:updateProblemDetailsSchema):(createNew?createIdeaDetailsSchema:updateIdeaDetailsSchema);
 const parsed=schema.safeParse(input);if(!parsed.success)throw new AuthorizationError("VALIDATION_ERROR");const v=parsed.data;
 const db=await createServerSupabaseClient();const result=await db.from("development_objects").select("*").eq("id",v.objectId).maybeSingle();const object=developmentObjectSchema.safeParse(result.data);
 if(result.error||!object.success||object.data.id!==v.objectId)throw new AuthorizationError("FORBIDDEN");
 const o=object.data;const access=await getWorkspaceAccess(o.workspace_id);if(!access.canEdit)throw new AuthorizationError("FORBIDDEN");
 if(o.object_type!==kind||o.archived_at!==null)throw new AuthorizationError("VALIDATION_ERROR");
 const details:Record<string,unknown>={};const keys={problemCategory:"problem_category",priority:"priority",perspective:"perspective",technique:"technique",acceptanceState:"acceptance_state",originalPrivateWorkspaceId:"original_private_workspace_id"} as const;
 for(const [key,value] of Object.entries(v)){if(key!=="objectId")details[keys[key as keyof typeof keys]]=value;}
 if("originalPrivateWorkspaceId" in v&&v.originalPrivateWorkspaceId!=null){
 if(o.created_by!==actor.userId)throw new AuthorizationError("FORBIDDEN");
 const source=await db.from("workspaces").select("*").eq("id",v.originalPrivateWorkspaceId).maybeSingle();
 if(source.error||!source.data||source.data.id!==v.originalPrivateWorkspaceId||source.data.workspace_type!=="PERSONAL"||source.data.owner_user_id!==actor.userId||source.data.status!=="active"||source.data.visibility!=="private")throw new AuthorizationError("FORBIDDEN");
 }
 if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError("FORBIDDEN");
 const r=await db.rpc(kind==="PROBLEM"?"write_problem_details":"write_idea_details",{target_object:v.objectId,details,create_new:createNew});
 if(r.error)throw new AuthorizationError(r.error.code==="28000"?"AUTH_REQUIRED":["22023","23505","23514","23503","22P02"].includes(r.error.code??"")?"VALIDATION_ERROR":"FORBIDDEN");
 const d=(kind==="PROBLEM"?problemDetailsSchema:ideaDetailsSchema).safeParse(r.data);
 if(!d.success||d.data.development_object_id!==o.id||(await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError("FORBIDDEN");return d.data;
}catch(error){throw new AuthorizationError(error instanceof AuthorizationError&&["AUTH_REQUIRED","VALIDATION_ERROR"].includes(error.code)?error.code:"FORBIDDEN");}}
export const createProblemDetails=(input:unknown)=>write(input,"PROBLEM",true);
export const updateProblemDetails=(input:unknown)=>write(input,"PROBLEM",false);
export const createIdeaDetails=(input:unknown)=>write(input,"IDEA",true);
export const updateIdeaDetails=(input:unknown)=>write(input,"IDEA",false);
