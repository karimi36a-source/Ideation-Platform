import "server-only";
import {AuthorizationError,getAuthorizationContext} from "@/lib/auth/authorization";
import {createServerSupabaseClient} from "@/lib/db/server";
import {evidenceSchema,type Evidence} from "./schema";
import {verifyEvidenceSchema} from "./verify-schema";
export class EvidenceVerificationError extends Error {constructor(readonly code:"CONFLICT"){super("Verification conflicts with current state.");}}
/** Canonical Evidence result; an authorized same-status retry preserves its verifier/time. */
export async function verifyEvidence(input:unknown):Promise<Evidence>{try{
 const actor=await getAuthorizationContext();const parsed=verifyEvidenceSchema.safeParse(input);if(!parsed.success)throw new AuthorizationError("VALIDATION_ERROR");
 const db=await createServerSupabaseClient();if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError("NOT_FOUND");
 const r=await db.rpc("verify_evidence",{target_evidence:parsed.data.evidenceId,target_status:parsed.data.verificationStatus,verification_note:parsed.data.note??null});
 if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError("NOT_FOUND");
 if(r.error){if(r.error.code==="40001")throw new EvidenceVerificationError("CONFLICT");throw new AuthorizationError(r.error.code==="28000"?"AUTH_REQUIRED":["22023","22P02"].includes(r.error.code??"")?"VALIDATION_ERROR":"NOT_FOUND");}
 const row=evidenceSchema.safeParse(r.data);if(!row.success||row.data.id!==parsed.data.evidenceId||row.data.verification_status!==parsed.data.verificationStatus||row.data.archived_at!==null)throw new AuthorizationError("NOT_FOUND");
 return row.data;
}catch(error){if(error instanceof EvidenceVerificationError)throw new EvidenceVerificationError(error.code);throw new AuthorizationError(error instanceof AuthorizationError&&["AUTH_REQUIRED","VALIDATION_ERROR"].includes(error.code)?error.code:"NOT_FOUND");}}
