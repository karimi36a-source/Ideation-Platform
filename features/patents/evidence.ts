import 'server-only';
import {AuthorizationError,getAuthorizationContext} from '@/lib/auth/authorization';
import {createServerSupabaseClient} from '@/lib/db/server';
import {evidenceSchema,type Evidence} from '@/features/evidence/schema';
import {linkPatentToEvidenceSchema} from './evidence-schema';
/** New UNVERIFIED Evidence + exact source link; canonical scope/source are RPC-derived. */
export async function linkPatentToEvidence(input:unknown):Promise<Evidence>{try{
 const actor=await getAuthorizationContext(),parsed=linkPatentToEvidenceSchema.safeParse(input);
 if(!parsed.success)throw new AuthorizationError('VALIDATION_ERROR');
 const v=parsed.data,db=await createServerSupabaseClient();
 if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError('NOT_FOUND');
 const result=await db.rpc('link_patent_to_evidence',{input:v});
 if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError('NOT_FOUND');
 if(result.error)throw new AuthorizationError(result.error.code==='28000'?'AUTH_REQUIRED':['22023','22P02','23514'].includes(result.error.code??'')?'VALIDATION_ERROR':'NOT_FOUND');
 const row=evidenceSchema.safeParse(result.data);
 if(!row.success||row.data.evidence_type!==v.evidenceType||row.data.title!==v.title||row.data.description!==v.description||row.data.claim_locator!==(v.claimLocator??null)
 ||row.data.created_by!==actor.userId||row.data.updated_by!==actor.userId||row.data.verification_status!=='UNVERIFIED'||row.data.verified_by!==null||row.data.verified_at!==null
 ||row.data.file_id!==null||row.data.archived_at!==null||Object.keys(row.data.metadata).length!==0||!/^https:\/\//i.test(row.data.source_url??''))throw new AuthorizationError('NOT_FOUND');
 return row.data;
 }catch(error){throw new AuthorizationError(error instanceof AuthorizationError&&['AUTH_REQUIRED','VALIDATION_ERROR'].includes(error.code)?error.code:'NOT_FOUND');}}
