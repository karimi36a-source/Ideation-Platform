import "server-only";
import {z} from "zod";
import {AuthorizationError,getAuthorizationContext} from "@/lib/auth/authorization";
import {createServerSupabaseClient} from "@/lib/db/server";
import {getWorkspaceAccess} from "@/features/workspaces/access";
import {developmentObjectSchema} from "./object-schema";
import {developmentRelationshipSchema,relateDevelopmentObjectsSchema} from "./relationship-schema";
const safe=(error:unknown)=>new AuthorizationError(error instanceof AuthorizationError&&["AUTH_REQUIRED","VALIDATION_ERROR"].includes(error.code)?error.code:"FORBIDDEN");
const rpcError=(code:string|undefined)=>new AuthorizationError(code==="28000"?"AUTH_REQUIRED":["22023","23505","23514","23503","22P02"].includes(code??"")?"VALIDATION_ERROR":"FORBIDDEN");
async function endpoints(sourceId:string,targetId:string,allowArchived:boolean){
 const db=await createServerSupabaseClient();const load=async(id:string)=>{const r=await db.from("development_objects").select("*").eq("id",id).maybeSingle();const o=developmentObjectSchema.safeParse(r.data);if(r.error||!o.success||o.data.id!==id)throw new AuthorizationError("FORBIDDEN");return o.data;};
 const source=await load(sourceId);const target=await load(targetId);
 for(const o of [source,target]){const access=await getWorkspaceAccess(o.workspace_id);if(!access.canEdit)throw new AuthorizationError("FORBIDDEN");}
 if(source.project_id!==target.project_id||(!allowArchived&&(source.archived_at!==null||target.archived_at!==null)))throw new AuthorizationError("VALIDATION_ERROR");
 return {db,source,target};
}
export async function relateDevelopmentObjects(input:unknown){try{
 const actor=await getAuthorizationContext();const parsed=relateDevelopmentObjectsSchema.safeParse(input);if(!parsed.success)throw new AuthorizationError("VALIDATION_ERROR");const v=parsed.data;
 const {db,source,target}=await endpoints(v.sourceObjectId,v.targetObjectId,false);
 if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError("FORBIDDEN");
 const r=await db.rpc("relate_development_objects",{source_object:source.id,target_object:target.id,kind:v.relationshipType,relationship_description:v.description??null});if(r.error)throw rpcError(r.error.code);
 const edge=developmentRelationshipSchema.safeParse(r.data);if(!edge.success||edge.data.source_object_id!==source.id||edge.data.target_object_id!==target.id||edge.data.project_id!==source.project_id||edge.data.relationship_type!==v.relationshipType||edge.data.created_by!==actor.userId||edge.data.status!=="active"||(await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError("FORBIDDEN");return edge.data;
}catch(error){throw safe(error);}}
export async function unlinkDevelopmentObjects(relationshipId:unknown){try{
 const actor=await getAuthorizationContext();const id=z.uuid().safeParse(relationshipId);if(!id.success)throw new AuthorizationError("VALIDATION_ERROR");
 const client=await createServerSupabaseClient();const loaded=await client.from("development_object_relationships").select("*").eq("id",id.data).maybeSingle();const before=developmentRelationshipSchema.safeParse(loaded.data);
 if(loaded.error||!before.success||before.data.id!==id.data)throw new AuthorizationError("FORBIDDEN");const edge=before.data;
 const {db}=await endpoints(edge.source_object_id,edge.target_object_id,true);
 if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError("FORBIDDEN");
 const r=await db.rpc("unlink_development_objects",{target_relationship:edge.id});if(r.error)throw rpcError(r.error.code);const after=developmentRelationshipSchema.safeParse(r.data);
 if(!after.success||after.data.status!=="inactive"||["id","project_id","source_object_id","target_object_id","relationship_type","description","created_by","created_at"].some(key=>after.data[key as keyof typeof after.data]!==edge[key as keyof typeof edge])||(await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError("FORBIDDEN");return after.data;
}catch(error){throw safe(error);}}
