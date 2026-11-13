import "server-only";
import {z} from "zod";
import {AuthorizationError,getAuthorizationContext} from "@/lib/auth/authorization";
import {createServerSupabaseClient} from "@/lib/db/server";
import {baselineTypeSchema,projectBaselineItemSchema,setProjectBaselineInputSchema} from "./baseline-schema";

const safe=(error:unknown,code:"FORBIDDEN"|"NOT_FOUND")=>new AuthorizationError(error instanceof AuthorizationError&&["AUTH_REQUIRED","VALIDATION_ERROR"].includes(error.code)?error.code:code);
async function sameActor(id:string){if((await getAuthorizationContext()).userId!==id)throw new AuthorizationError("FORBIDDEN");}

/** Narrow command authority is verified by the RPC, never by client scope claims.
 * Intentionally does not require generic Personal/Team Project editing rights. */
export async function setProjectBaselineItem(input:unknown){try{
 const actor=await getAuthorizationContext();const parsed=setProjectBaselineInputSchema.safeParse(input);if(!parsed.success)throw new AuthorizationError("VALIDATION_ERROR");
 const db=await createServerSupabaseClient();await sameActor(actor.userId);const p=parsed.data;
 const result=await db.rpc("set_project_baseline_item",{target_project:p.projectId,baseline_type_input:p.baselineType,target_artifact:p.artifactId,target_version:p.artifactVersionId});await sameActor(actor.userId);
 if(result.error)throw new AuthorizationError(result.error.code==="28000"?"AUTH_REQUIRED":result.error.code==="22023"?"VALIDATION_ERROR":"FORBIDDEN");
 const row=projectBaselineItemSchema.safeParse(result.data);
 if(!row.success||row.data.project_id!==p.projectId||row.data.baseline_type!==p.baselineType||row.data.artifact_id!==p.artifactId||row.data.artifact_version_id!==p.artifactVersionId||row.data.effective_to!==null)throw new AuthorizationError("FORBIDDEN");
 // An authorized retry preserves the original setter, including after reassignment.
 return row.data;
}catch(error){throw safe(error,"FORBIDDEN");}}

async function readBaseline(projectId:unknown,history:boolean,baselineType?:unknown){try{
 const actor=await getAuthorizationContext();const id=z.uuid().safeParse(projectId);const type=baselineType===undefined?undefined:baselineTypeSchema.safeParse(baselineType);
 if(!id.success||(type&&!type.success))throw new AuthorizationError("VALIDATION_ERROR");
 const db=await createServerSupabaseClient();const project=await db.from("development_projects").select("id").eq("id",id.data).maybeSingle();
 if(project.error||project.data?.id!==id.data)throw new AuthorizationError("NOT_FOUND");
 let query=db.from("project_baseline_items").select("*").eq("project_id",id.data);
 if(!history)query=query.is("effective_to",null);
 if(type?.success)query=query.eq("baseline_type",type.data);
 const result=await query.order("baseline_type",{ascending:true}).order("effective_from",{ascending:true}).order("id",{ascending:true});await sameActor(actor.userId);
 const rows=z.array(projectBaselineItemSchema).safeParse(result.data);
 if(result.error||!rows.success||rows.data.some(row=>row.project_id!==id.data||(!history&&row.effective_to!==null)||(type?.success&&row.baseline_type!==type.data)))throw new AuthorizationError("NOT_FOUND");
 return rows.data;
}catch(error){throw safe(error,"NOT_FOUND");}}
export async function getProjectBaseline(projectId:unknown){return readBaseline(projectId,false);}
export async function listProjectBaselineHistory(projectId:unknown,baselineType?:unknown){return readBaseline(projectId,true,baselineType);}
