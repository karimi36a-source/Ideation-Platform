import "server-only";
import {z} from "zod";
import {AuthorizationError,getAuthorizationContext} from "@/lib/auth/authorization";
import {createServerSupabaseClient} from "@/lib/db/server";
import {getWorkspaceAccess} from "@/features/workspaces/access";
import {developmentObjectSchema,type DevelopmentObject} from "./object-schema";
import {createDevelopmentObjectSchema,updateDevelopmentObjectSchema} from "./object-operation-schema";
const safe=(error:unknown)=>new AuthorizationError(error instanceof AuthorizationError&&["AUTH_REQUIRED","VALIDATION_ERROR"].includes(error.code)?error.code:"FORBIDDEN");
const rpcError=(code:string|undefined)=>new AuthorizationError(code==="28000"?"AUTH_REQUIRED":["22023","23514","23503","22P02"].includes(code??"")?"VALIDATION_ERROR":"FORBIDDEN");
async function authorize(projectId:string,workspaceId:string,capability:"canCreate"|"canEdit"){
 const db=await createServerSupabaseClient();const p=await db.from("development_projects").select("*").eq("id",projectId).maybeSingle();
 if(p.error||!p.data||p.data.id!==projectId||p.data.primary_workspace_id!==workspaceId)throw new AuthorizationError("FORBIDDEN");
 const access=await getWorkspaceAccess(workspaceId);if(!access[capability])throw new AuthorizationError("FORBIDDEN");return db;
}
async function existing(objectId:string){const db=await createServerSupabaseClient();const r=await db.from("development_objects").select("*").eq("id",objectId).maybeSingle();const o=developmentObjectSchema.safeParse(r.data);if(r.error||!o.success||o.data.id!==objectId)throw new AuthorizationError("FORBIDDEN");return o.data;}
function canonical(data:unknown){const o=developmentObjectSchema.safeParse(data);if(!o.success)throw new AuthorizationError("FORBIDDEN");return o.data;}
function sameIdentity(before:DevelopmentObject,after:DevelopmentObject){if(["id","project_id","workspace_id","object_type","created_by","created_at","current_version_number"].some(k=>before[k as keyof DevelopmentObject]!==after[k as keyof DevelopmentObject]))throw new AuthorizationError("FORBIDDEN");}
export async function createDevelopmentObject(input:unknown){try{
 const actor=await getAuthorizationContext();const parsed=createDevelopmentObjectSchema.safeParse(input);if(!parsed.success)throw new AuthorizationError("VALIDATION_ERROR");const v=parsed.data;
 const db=await authorize(v.projectId,v.workspaceId,"canCreate");
 if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError("FORBIDDEN");
 const r=await db.rpc("create_development_object",{target_project:v.projectId,target_workspace:v.workspaceId,kind:v.objectType,object_title:v.title,object_content:v.content,object_origin:v.originType,object_metadata:v.metadata??{}});if(r.error)throw rpcError(r.error.code);
 const o=canonical(r.data);if((await getAuthorizationContext()).userId!==actor.userId||o.created_by!==actor.userId||o.project_id!==v.projectId||o.workspace_id!==v.workspaceId||o.object_type!==v.objectType||o.archived_at!==null||o.current_version_number!==1)throw new AuthorizationError("FORBIDDEN");return o;
}catch(error){throw safe(error);}}
export async function updateDevelopmentObject(input:unknown){try{
 const actor=await getAuthorizationContext();const parsed=updateDevelopmentObjectSchema.safeParse(input);if(!parsed.success)throw new AuthorizationError("VALIDATION_ERROR");const {objectId,...changes}=parsed.data;
 const before=await existing(objectId);const db=await authorize(before.project_id,before.workspace_id,"canEdit");if(before.archived_at!==null)throw new AuthorizationError("VALIDATION_ERROR");
 if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError("FORBIDDEN");
 const r=await db.rpc("update_development_object",{target_object:objectId,changes});if(r.error)throw rpcError(r.error.code);const o=canonical(r.data);sameIdentity(before,o);
 if((await getAuthorizationContext()).userId!==actor.userId||o.archived_at!==null)throw new AuthorizationError("FORBIDDEN");return o;
}catch(error){throw safe(error);}}
export async function archiveDevelopmentObject(objectId:unknown){try{
 const actor=await getAuthorizationContext();const parsed=z.uuid().safeParse(objectId);if(!parsed.success)throw new AuthorizationError("VALIDATION_ERROR");
 const before=await existing(parsed.data);const db=await authorize(before.project_id,before.workspace_id,"canEdit");if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError("FORBIDDEN");
 const r=await db.rpc("archive_development_object",{target_object:before.id});if(r.error)throw rpcError(r.error.code);const o=canonical(r.data);sameIdentity(before,o);
 if((await getAuthorizationContext()).userId!==actor.userId||o.archived_at===null)throw new AuthorizationError("FORBIDDEN");return o;
}catch(error){throw safe(error);}}
