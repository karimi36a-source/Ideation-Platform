import 'server-only';
import {createHash} from 'node:crypto';
import {z} from 'zod';
import {getAuthorizationContext} from '@/lib/auth/authorization';
import {createServerSupabaseClient} from '@/lib/db/server';
import {createDevelopmentObjectSchema} from '@/features/projects/object-operation-schema';
import {developmentObjectSchema,developmentObjectTypeSchema} from '@/features/projects/object-schema';
import {aiOutputSchema} from './schema';
import {getAiTaskDefinition} from './task-registry';
import {matchesAiOutputSchema} from './output-validation';
import {createAiTaskPersistenceClient} from './task-persistence';
// These are conversion permissions, not replacement Task output schemas.
export const aiConversionTargets:Readonly<Record<string,readonly string[]>>=Object.freeze({
 SCAMPER_ASSISTANCE:['IDEA'],BRAINSTORMING_ASSISTANCE:['IDEA'],
 SYSTEM_STRUCTURE_ANALYSIS:['SYSTEM','SUBSYSTEM','COMPONENT','FUNCTION'],
 GAP_ANALYSIS:['GAP','OPEN_QUESTION','REQUIREMENT','RISK'],
 PATENT_RESEARCH_ASSISTANCE:['GAP','OPEN_QUESTION','RISK'],
 COMPARATIVE_ANALYSIS:['GAP','REQUIREMENT','RISK','OPEN_QUESTION'],
 CRITICAL_REVIEW:['GAP','RISK','OPEN_QUESTION','REQUIREMENT'],
 SESSION10_GAP_REFINEMENT:['GAP','SOLUTION','REQUIREMENT','OPEN_QUESTION'],
});
const inputSchema=z.strictObject({aiOutputId:z.uuid(),targetObjectType:developmentObjectTypeSchema,candidateTitle:createDevelopmentObjectSchema.shape.title.max(1000000),candidateContent:createDevelopmentObjectSchema.shape.content.max(1000000).optional(),confirmed:z.literal(true)});
export class AiConversionError extends Error{
 constructor(readonly code:'VALIDATION_ERROR'|'HUMAN_CONFIRMATION_REQUIRED'|'TARGET_TYPE_NOT_ALLOWED'|'INVALID_AI_OUTPUT'|'NOT_ELIGIBLE'|'FORBIDDEN'|'CONFLICT'){super('AI conversion unavailable.');this.name='AiConversionError';}
}
/** Human-confirmed, same-source-scope conversion. No provider invocation or
 * context reopening. Source hashes/actor are trusted server claims only. */
export async function convertAiOutputToCandidate(input:unknown){
 try{
  const actor=await getAuthorizationContext();
  if(input&&typeof input==='object'&&!Array.isArray(input)&&(input as Record<string,unknown>).confirmed!==true)throw new AiConversionError('HUMAN_CONFIRMATION_REQUIRED');
  if(input&&typeof input==='object'&&typeof (input as Record<string,unknown>).targetObjectType==='string'&&!developmentObjectTypeSchema.safeParse((input as Record<string,unknown>).targetObjectType).success)throw new AiConversionError('TARGET_TYPE_NOT_ALLOWED');
  const parsed=inputSchema.safeParse(input);if(!parsed.success)throw new AiConversionError('VALIDATION_ERROR');const v=parsed.data;
  const db=await createServerSupabaseClient();
  const read=await db.from('ai_outputs').select('*').eq('id',v.aiOutputId).maybeSingle();const row=aiOutputSchema.safeParse(read.data);
  if(read.error||!row.success)throw new AiConversionError('FORBIDDEN');const source=row.data;
  let task:ReturnType<typeof getAiTaskDefinition>;
  try{task=getAiTaskDefinition(source.task_type);if(task.allowedRole!==source.ai_role||task.outputType!==source.output_type||!matchesAiOutputSchema((task as unknown as {outputSchema:unknown}).outputSchema,JSON.parse(source.response_text)))throw Error('Invalid');}
  catch{throw new AiConversionError('INVALID_AI_OUTPUT');}
  if(!aiConversionTargets[task.taskType]?.includes(v.targetObjectType))throw new AiConversionError(source.disposition==='CONVERTED_TO_PROJECT_OBJECT'?'CONFLICT':'TARGET_TYPE_NOT_ALLOWED');
  if(!['ACCEPT_AS_CANDIDATE','CONVERTED_TO_PROJECT_OBJECT'].includes(source.disposition))throw new AiConversionError('NOT_ELIGIBLE');
  if((await getAuthorizationContext()).userId!==actor.userId)throw new AiConversionError('FORBIDDEN');
  const storage=createAiTaskPersistenceClient();
  const r=await storage.rpc('convert_ai_output_to_candidate',{input:{actorId:actor.userId,aiOutputId:source.id,targetObjectType:v.targetObjectType,candidateTitle:v.candidateTitle,candidateContent:v.candidateContent??source.response_text,confirmed:true,sourceResponseHash:createHash('sha256').update(source.response_text).digest('hex')}});
  if(r.error)throw new AiConversionError(r.error.code==='23505'?'CONFLICT':r.error.code==='22000'?'INVALID_AI_OUTPUT':r.error.code==='55000'?'NOT_ELIGIBLE':r.error.code==='22023'?'TARGET_TYPE_NOT_ALLOWED':'FORBIDDEN');
  const result=developmentObjectSchema.safeParse(r.data);if(!result.success)throw new AiConversionError('FORBIDDEN');
  const current=await db.from('development_objects').select('*').eq('id',result.data.id).maybeSingle();const candidate=developmentObjectSchema.safeParse(current.data);
  if(current.error||!candidate.success||candidate.data.project_id!==source.project_id||candidate.data.workspace_id!==source.workspace_id||candidate.data.origin_type!=='AI'||candidate.data.origin_reference_id!==source.id||candidate.data.object_type!==v.targetObjectType||(await getAuthorizationContext()).userId!==actor.userId)throw new AiConversionError('FORBIDDEN');
  return candidate.data;
 }catch(error){throw error instanceof AiConversionError?error:new AiConversionError('FORBIDDEN');}
}


