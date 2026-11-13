import 'server-only';
import {z} from 'zod';
import {getAuthorizationContext} from '@/lib/auth/authorization';
import {createServerSupabaseClient} from '@/lib/db/server';
import {aiOutputSchema,aiOutputDispositionSchema} from './schema';
export const aiDispositionInputSchema=z.strictObject({aiOutputId:z.uuid(),disposition:aiOutputDispositionSchema.exclude(['CONVERTED_TO_PROJECT_OBJECT'])});
export class AiDispositionError extends Error {
 constructor(readonly code:'VALIDATION_ERROR'|'FORBIDDEN'|'CONFLICT'){super('AI output unavailable.');this.name='AiDispositionError';}
}
/** Human command only. Revision is read under the caller's RLS, never supplied
 * as an authority claim. The RPC rechecks current access and performs CAS. */
export async function setAiOutputDisposition(input:unknown){
 try{
  const actor=await getAuthorizationContext();
  const v=aiDispositionInputSchema.safeParse(input);if(!v.success)throw new AiDispositionError('VALIDATION_ERROR');
  const db=await createServerSupabaseClient();
  const before=await db.from('ai_outputs').select('*').eq('id',v.data.aiOutputId).maybeSingle();
  const row=aiOutputSchema.safeParse(before.data);
  if(before.error||!row.success)throw new AiDispositionError('FORBIDDEN');
  const r=await db.rpc('set_ai_output_disposition',{target_output:v.data.aiOutputId,target_disposition:v.data.disposition,expected_revision:row.data.disposition_revision});
  if(r.error)throw new AiDispositionError(r.error.code==='40001'?'CONFLICT':'FORBIDDEN');
  const out=aiOutputSchema.safeParse(r.data);
  if(!out.success||out.data.id!==row.data.id||(await getAuthorizationContext()).userId!==actor.userId)throw new AiDispositionError('FORBIDDEN');
  const o=out.data;
  return {id:o.id,ai_generated:true as const,output_type:o.output_type,verification_status:o.verification_status,ai_role:o.ai_role,task_type:o.task_type,requested_by:o.requested_by,disposition:o.disposition,disposition_revision:o.disposition_revision};
 }catch(error){throw error instanceof AiDispositionError?error:new AiDispositionError('FORBIDDEN');}
}
