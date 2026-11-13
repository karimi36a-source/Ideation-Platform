import "server-only";
import {z} from "zod";
import {AuthorizationError,getAuthorizationContext} from "@/lib/auth/authorization";
import {createServerSupabaseClient} from "@/lib/db/server";
import {scamperEntrySchema} from "./schema";
import {shareEntityInputSchema} from "@/features/shares/create-schema";
import {shareEntity} from "@/features/shares/create";
import type {Share} from "@/features/shares/schema";
import {workspaceSchema} from "@/features/workspaces/schema";
const canonicalUuid=z.uuid().transform(value=>value.toLowerCase());
export const SCAMPER_SHARE_ACCEPTANCE_STATUS="AT-SCAMPER-003 = standard M13 SNAPSHOT sharing";
/** Source identity only; all scope checks run against canonical database state. */
export async function getScamperEntry(entryId:unknown){
 try{
  const actor=await getAuthorizationContext();const id=canonicalUuid.safeParse(entryId);
  if(!id.success)throw new AuthorizationError("VALIDATION_ERROR");
  const db=await createServerSupabaseClient();
  const {data,error}=await db.rpc("get_scamper_entry",{target_entry:id.data});
  if(error)throw new AuthorizationError(error.code==="28000"?"AUTH_REQUIRED":"NOT_FOUND");
  const parsed=scamperEntrySchema.safeParse(data);
  if(!parsed.success||parsed.data.id!==id.data||(await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError("NOT_FOUND");
  return parsed.data;
 }catch(error){throw new AuthorizationError(error instanceof AuthorizationError&&["AUTH_REQUIRED","VALIDATION_ERROR"].includes(error.code)?error.code:"NOT_FOUND");}
}
/** Standard M13 Share contract, narrowed to selected Personal SCAMPER -> TEAM.
 * No separate permission, payload, copy or recipient-access model. */
export async function shareScamperEntryToTeam(input:unknown):Promise<Share>{
 try{
  const actor=await getAuthorizationContext(),parsed=shareEntityInputSchema.safeParse(input);
  if(!parsed.success||parsed.data.entityType!=="SCAMPER_ENTRY"||parsed.data.destinationType!=="TEAM")throw new AuthorizationError("VALIDATION_ERROR");
  const entry=await getScamperEntry(parsed.data.entityId),db=await createServerSupabaseClient();
  const loaded=await db.from("workspaces").select("*").eq("id",entry.workspace_id).maybeSingle();
  const workspace=workspaceSchema.safeParse(loaded.data);
  if(loaded.error||!workspace.success||workspace.data.id!==entry.workspace_id||workspace.data.workspace_type!=="PERSONAL"||workspace.data.owner_user_id!==actor.userId
   ||(await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError("NOT_FOUND");
  // Canonical source scope/ownership is immutable. The existing transaction
  // rechecks current source and destination authority and writes all history.
  return await shareEntity(parsed.data);
 }catch(error){throw new AuthorizationError(error instanceof AuthorizationError&&["AUTH_REQUIRED","VALIDATION_ERROR"].includes(error.code)?error.code:"NOT_FOUND");}
}

/** Reload persisted feature state after generic Activity resume; no lifecycle writes. */
export async function listScamperEntries(activityInstanceId:unknown){
 try{
  const actor=await getAuthorizationContext();const id=canonicalUuid.safeParse(activityInstanceId);
  if(!id.success)throw new AuthorizationError("VALIDATION_ERROR");
  const db=await createServerSupabaseClient();
  const {data,error}=await db.rpc("list_scamper_entries",{target_instance:id.data});
  if(error)throw new AuthorizationError(error.code==="28000"?"AUTH_REQUIRED":"NOT_FOUND");
  const parsed=z.array(scamperEntrySchema).safeParse(data);
  if(!parsed.success||parsed.data.some(row=>row.activity_instance_id!==id.data)||new Set(parsed.data.map(row=>row.id)).size!==parsed.data.length||(await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError("NOT_FOUND");
  return parsed.data;
 }catch(error){throw new AuthorizationError(error instanceof AuthorizationError&&["AUTH_REQUIRED","VALIDATION_ERROR"].includes(error.code)?error.code:"NOT_FOUND");}
}
