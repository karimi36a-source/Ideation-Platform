import "server-only";
import {AuthorizationError,getAuthorizationContext} from "@/lib/auth/authorization";
import {createServerSupabaseClient} from "@/lib/db/server";
import {evidenceLinkSchema,linkEvidenceSchema,type EvidenceLink} from "./link-schema";
export class EvidenceLinkError extends Error {
 constructor(readonly code:"DEPENDENCY_REQUIRED"|"INVALID_STATE"|"CONFLICT"){super(code==="DEPENDENCY_REQUIRED"?"Target dependency is unavailable.":code==="CONFLICT"?"Link conflicts with persisted state.":"Resource is not writable.");}
}
/** The caller-bound RPC owns authorization, scope validation and atomic retry. */
export async function linkEvidence(input:unknown):Promise<EvidenceLink>{try{
 const actor=await getAuthorizationContext();
 const parsed=linkEvidenceSchema.safeParse(input);if(!parsed.success)throw new AuthorizationError("VALIDATION_ERROR");
 const db=await createServerSupabaseClient();
 if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError("NOT_FOUND");
 const r=await db.rpc("link_evidence",{input:parsed.data});
 if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError("NOT_FOUND");
 if(r.error){
  if(r.error.code==="0A000")throw new EvidenceLinkError("DEPENDENCY_REQUIRED");
  if(r.error.code==="55000")throw new EvidenceLinkError("INVALID_STATE");
  if(r.error.code==="40001")throw new EvidenceLinkError("CONFLICT");
  throw new AuthorizationError(r.error.code==="28000"?"AUTH_REQUIRED":["22023","22P02"].includes(r.error.code??"")?"VALIDATION_ERROR":"NOT_FOUND");
 }
 const row=evidenceLinkSchema.safeParse(r.data);const v=parsed.data;
 if(!row.success||row.data.archived_at!==null||row.data.evidence_id.toLowerCase()!==v.evidenceId.toLowerCase()||row.data.linked_entity_id.toLowerCase()!==v.entityId.toLowerCase()||row.data.linked_entity_type!==v.entityType||row.data.relationship_type!==v.relationshipType)throw new AuthorizationError("NOT_FOUND");
 return row.data;
}catch(error){if(error instanceof EvidenceLinkError)throw new EvidenceLinkError(error.code);throw new AuthorizationError(error instanceof AuthorizationError&&["AUTH_REQUIRED","VALIDATION_ERROR"].includes(error.code)?error.code:"NOT_FOUND");}}
