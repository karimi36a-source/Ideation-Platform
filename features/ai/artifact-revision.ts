import 'server-only';
import {createHash} from 'node:crypto';
import {z} from 'zod';
import {getAuthorizationContext} from '@/lib/auth/authorization';
import {createServerSupabaseClient} from '@/lib/db/server';
import {artifactVersionSchema} from '@/features/artifacts/version-schema';
import {aiOutputSchema} from './schema';
import {getAiTaskDefinition} from './task-registry';
import {matchesAiOutputSchema} from './output-validation';
import {createAiTaskPersistenceClient} from './task-persistence';
const inputSchema=z.strictObject({aiOutputId:z.uuid(),artifactId:z.uuid(),expectedVersionId:z.uuid(),expectedDraftRevision:z.number().int().min(0).max(2147483647).nullable(),contentSnapshot:z.json(),changeSummary:z.string().max(1000000).nullable().optional(),confirmed:z.literal(true),idempotencyKey:z.uuid()});
export class AiArtifactRevisionError extends Error{
 constructor(readonly code:'VALIDATION_ERROR'|'HUMAN_CONFIRMATION_REQUIRED'|'INVALID_AI_OUTPUT'|'FORBIDDEN'|'CONFLICT'|'INVALID_STATE'|'SPECIALIZED_ARTIFACT_REVISION_REQUIRED'){super('AI-assisted revision unavailable.');this.name='AiArtifactRevisionError';}
}
/** Explicit human content only. M8 owns Version creation/editing; no provider calls. */
export async function applyAiArtifactRevision(input:unknown){try{
 const actor=await getAuthorizationContext();
 if(input&&typeof input==='object'&&!Array.isArray(input)&&(input as Record<string,unknown>).confirmed!==true)throw new AiArtifactRevisionError('HUMAN_CONFIRMATION_REQUIRED');
 const parsed=inputSchema.safeParse(input);if(!parsed.success||JSON.stringify(parsed.data).length>1000000)throw new AiArtifactRevisionError('VALIDATION_ERROR');const v=parsed.data;
 const db=await createServerSupabaseClient();const read=await db.from('ai_outputs').select('*').eq('id',v.aiOutputId).maybeSingle();const row=aiOutputSchema.safeParse(read.data);
 if(read.error||!row.success)throw new AiArtifactRevisionError('FORBIDDEN');const source=row.data;
 try{const task=getAiTaskDefinition(source.task_type);if(task.allowedRole!==source.ai_role||task.outputType!==source.output_type||!matchesAiOutputSchema((task as unknown as {outputSchema:unknown}).outputSchema,JSON.parse(source.response_text)))throw Error('Invalid');}catch{throw new AiArtifactRevisionError('INVALID_AI_OUTPUT');}
 if((await getAuthorizationContext()).userId!==actor.userId)throw new AiArtifactRevisionError('FORBIDDEN');
 const result=await createAiTaskPersistenceClient().rpc('apply_ai_artifact_revision',{input:{...v,changeSummary:v.changeSummary??null,actorId:actor.userId,sourceResponseHash:createHash('sha256').update(source.response_text).digest('hex')}});
 if(result.error)throw new AiArtifactRevisionError(result.error.code==='23505'?'CONFLICT':result.error.code==='0A000'?'SPECIALIZED_ARTIFACT_REVISION_REQUIRED':result.error.code==='55000'?'INVALID_STATE':result.error.code==='22000'?'INVALID_AI_OUTPUT':result.error.code==='22023'?'VALIDATION_ERROR':'FORBIDDEN');
 const made=artifactVersionSchema.safeParse(result.data);if(!made.success||made.data.artifact_id!==v.artifactId)throw new AiArtifactRevisionError('FORBIDDEN');
 const current=await db.from('artifact_versions').select('*').eq('id',made.data.id).maybeSingle();const draft=artifactVersionSchema.safeParse(current.data);
 if(current.error||!draft.success||draft.data.artifact_id!==v.artifactId||(await getAuthorizationContext()).userId!==actor.userId)throw new AiArtifactRevisionError('FORBIDDEN');
 return draft.data;
}catch(error){throw error instanceof AiArtifactRevisionError?error:new AiArtifactRevisionError('FORBIDDEN');}}
