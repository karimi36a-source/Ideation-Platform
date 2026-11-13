import "server-only";
import {z} from "zod";
import {AuthorizationError,getAuthorizationContext} from "@/lib/auth/authorization";
import {createServerSupabaseClient} from "@/lib/db/server";
import {developmentProjectSchema} from "./schema";

/** Canonical RPC authorizes owners / exact Team management independently of content reads. */
export async function archiveProject(projectId:unknown){try{
 const actor=await getAuthorizationContext();const parsed=z.uuid().safeParse(projectId);
 if(!parsed.success)throw new AuthorizationError("VALIDATION_ERROR");
 const db=await createServerSupabaseClient();
 if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError("FORBIDDEN");
 const result=await db.rpc("archive_development_project",{target_project:parsed.data});
 if(result.error)throw new AuthorizationError(result.error.code==="28000"?"AUTH_REQUIRED":"FORBIDDEN");
 const canonical=developmentProjectSchema.safeParse(result.data);
 if(!canonical.success||canonical.data.id!==parsed.data||canonical.data.status!=="archived"||canonical.data.archived_at===null||(await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError("FORBIDDEN");
 return canonical.data;
}catch(error){throw new AuthorizationError(error instanceof AuthorizationError&&["AUTH_REQUIRED","VALIDATION_ERROR"].includes(error.code)?error.code:"FORBIDDEN");}}
