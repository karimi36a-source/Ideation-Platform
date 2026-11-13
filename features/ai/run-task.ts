import 'server-only';
import {z} from 'zod';
import {createHash} from 'node:crypto';
import {isDeepStrictEqual} from 'node:util';
import {getAuthorizationContext} from '@/lib/auth/authorization';
import {createServerSupabaseClient} from '@/lib/db/server';
import {getWorkspaceAccess} from '@/features/workspaces/access';
import {getActivityAiAvailability} from './activity-availability';
import {getAiTaskDefinition} from './task-registry';
import {matchesAiOutputSchema} from './output-validation';
import {validatePatentAiResponse} from './patent-traceability';
import {assembleAiPrompt} from './prompt-assembly';
import {aiContextBuilderInputSchema} from './context-builder-schema';
import {aiOutputSchema} from './schema';
import {aiContextRoleSchema,aiContextEntityTypeSchema} from './context-schema';
import {createAiTaskPersistenceClient} from './task-persistence';
import type {AiProvider} from './provider';
const requestSchema=aiContextBuilderInputSchema.extend({activityInstanceId:z.uuid(),idempotencyKey:z.string().trim().min(1).max(200),userInstruction:z.string().max(12000).transform(v=>v.normalize('NFC').trim()).optional(),session10CheckpointId:z.uuid().optional(),reconstructionAiOutputId:z.uuid().optional()});
const count=z.number().int().min(0).max(Number.MAX_SAFE_INTEGER);
const normalizedResult=z.strictObject({success:z.boolean(),text:z.string().max(1000000).nullable(),structured:z.json(),usage:z.strictObject({inputUsage:count.nullable(),outputUsage:count.nullable()}),latencyMs:count,reference:z.strictObject({provider:z.string().regex(/^[a-z0-9_-]{1,32}$/),responseId:z.string().regex(/^[a-zA-Z0-9_-]{1,220}$/)}).nullable(),error:z.strictObject({code:z.enum(['INVALID_INPUT','CONFIGURATION','AUTHENTICATION','RATE_LIMIT','TIMEOUT','NETWORK','UNAVAILABLE','MALFORMED_RESPONSE','REFUSED','INCOMPLETE','UNKNOWN']),retryable:z.boolean()}).nullable()});
const operationSchema=z.strictObject({operationId:z.uuid(),attemptId:z.uuid(),outputId:z.uuid().nullable(),completed:z.boolean()}).refine(v=>v.completed===(v.outputId!==null));
export class AiTaskExecutionError extends Error{
 constructor(readonly code:'VALIDATION_ERROR'|'FORBIDDEN'|'AI_UNAVAILABLE'|'IDEMPOTENCY_CONFLICT'|'IN_PROGRESS'|'PROVIDER_FAILED'|'SAVE_FAILED'){super('AI task unavailable.');this.name='AiTaskExecutionError';}
}
function stable(value:unknown):unknown{if(Array.isArray(value))return value.map(stable);if(value&&typeof value==='object')return Object.fromEntries(Object.entries(value).sort(([a],[b])=>a<b?-1:a>b?1:0).map(([k,v])=>[k,stable(v)]));return value;}
function safeResponse(text:string){
 const secrets=Object.entries(process.env).filter(([k,v])=>!k.startsWith('NEXT_PUBLIC_')&&/(SECRET|SERVICE_ROLE|PASSWORD|TOKEN|API_KEY|DATABASE_URL)/i.test(k)&&v&&v.length>=8).map(([,v])=>v!);
 if(text.length>1000000||secrets.some(v=>text.includes(v))||/\bsk-[a-zA-Z0-9_-]{8,}|sb_secret_[a-zA-Z0-9_-]{12,}|eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+|-----BEGIN .*PRIVATE KEY-----/i.test(text))throw new AiTaskExecutionError('PROVIDER_FAILED');
 return text;
}
/** Canonical command; runtime is trusted server dependency injection, never a
 * client request field. No real credential/provider is required by tests. */
export async function runAiTask(input:unknown,runtime:Readonly<{provider:AiProvider}>){
 let actorId:string;
 try{actorId=(await getAuthorizationContext()).userId;}catch{throw new AiTaskExecutionError('FORBIDDEN');}
 const parsed=requestSchema.safeParse(input);if(!parsed.success)throw new AiTaskExecutionError('VALIDATION_ERROR');
 const raw=parsed.data;
 if(raw.taskType==='SESSION10_GAP_REFINEMENT'){
  if(!raw.session10CheckpointId||!raw.reconstructionAiOutputId||raw.selectedContextRefs.filter(ref=>ref.contextRole==='GAP').length!==1)throw new AiTaskExecutionError('FORBIDDEN');
 }else if(raw.session10CheckpointId||raw.reconstructionAiOutputId)throw new AiTaskExecutionError('VALIDATION_ERROR');
 const selectedContextRefs=[...new Map(raw.selectedContextRefs.map(r=>{const v={...r,entityId:r.entityId.toLowerCase(),...(r.shareId?{shareId:r.shareId.toLowerCase()}:{})};return [JSON.stringify(stable(v)),v] as const;})).values()].sort((a,b)=>{const x=JSON.stringify(stable(a)),y=JSON.stringify(stable(b));return x<y?-1:x>y?1:0;});
 const v={...raw,projectId:raw.projectId.toLowerCase(),workspaceId:raw.workspaceId.toLowerCase(),activityInstanceId:raw.activityInstanceId.toLowerCase(),selectedContextRefs,userInstruction:raw.userInstruction??''};
 const {idempotencyKey,session10CheckpointId,reconstructionAiOutputId,...assemblyRequest}=v;
 const scope={projectId:v.projectId,workspaceId:v.workspaceId,activityInstanceId:v.activityInstanceId,requestedTaskType:v.taskType};
 const fingerprint=createHash('sha256').update(JSON.stringify(stable({actorId,...assemblyRequest,...(session10CheckpointId?{session10CheckpointId,reconstructionAiOutputId}:{})}))).digest('hex');
 try{
  const db=await createServerSupabaseClient();
  const checkpoint=async()=>{
   if(v.taskType!=='SESSION10_GAP_REFINEMENT')return;
   const r=await db.rpc('resolve_session10_checkpoint',{input:{checkpointId:session10CheckpointId!,reconstructionAiOutputId:reconstructionAiOutputId!,activityInstanceId:v.activityInstanceId,projectId:v.projectId,workspaceId:v.workspaceId}});
   if(r.error||r.data?.id!==session10CheckpointId||r.data?.reconstruction_ai_output_id!==reconstructionAiOutputId)throw new AiTaskExecutionError('FORBIDDEN');
   const baselineRefs=selectedContextRefs.filter(ref=>ref.contextRole==='CURRENT_ARTIFACT');
   const baselineVersion=r.data?.baseline_version_id;
   if(!baselineVersion||!baselineRefs.some(ref=>ref.entityId===baselineVersion&&!ref.shareId))throw new AiTaskExecutionError('FORBIDDEN');
  };
  await checkpoint();
  const project=await db.rpc('can_read_development_project',{target_project:v.projectId});
  if(project.error||project.data!==true)throw new AiTaskExecutionError('FORBIDDEN');
  if(!(await getWorkspaceAccess(v.workspaceId)).canView)throw new AiTaskExecutionError('FORBIDDEN');
  const available=await getActivityAiAvailability(scope);if(!available.available)throw new AiTaskExecutionError('AI_UNAVAILABLE');
  const task=getAiTaskDefinition(v.taskType);
  if(available.aiRole!==task.allowedRole||!available.allowedTasks.includes(task.taskType))throw new AiTaskExecutionError('AI_UNAVAILABLE');
  const assembly=await assembleAiPrompt(assemblyRequest);
  if((await getAuthorizationContext()).userId!==actorId)throw new AiTaskExecutionError('FORBIDDEN');
  const storage=createAiTaskPersistenceClient();
  const begin=await storage.rpc('begin_ai_task_operation',{input:{actorId,idempotencyKey,fingerprint,projectId:v.projectId,workspaceId:v.workspaceId,activityInstanceId:v.activityInstanceId,taskType:task.taskType,aiRole:assembly.metadata.aiRole,modelProfile:assembly.metadata.modelProfile,...(session10CheckpointId?{session10CheckpointId,reconstructionAiOutputId,session10GapId:selectedContextRefs.find(ref=>ref.contextRole==='GAP')!.entityId,session10GapShareId:selectedContextRefs.find(ref=>ref.contextRole==='GAP')!.shareId??null}:{})}});
  if(begin.error)throw new AiTaskExecutionError(begin.error.code==='23505'?'IDEMPOTENCY_CONFLICT':begin.error.code==='55P03'?'IN_PROGRESS':'FORBIDDEN');
  const operation=operationSchema.parse(begin.data);
  const readOutput=async(outputId:string)=>{
   await checkpoint();
   if((await getAuthorizationContext()).userId!==actorId)throw new AiTaskExecutionError('FORBIDDEN');
   const r=await db.from('ai_outputs').select('*').eq('id',outputId).maybeSingle();
   const output=aiOutputSchema.safeParse(r.data);
   if(r.error||!output.success||output.data.requested_by!==actorId||output.data.project_id!==v.projectId||output.data.workspace_id!==v.workspaceId||output.data.activity_instance_id!==v.activityInstanceId||output.data.task_type!==task.taskType)throw new AiTaskExecutionError('FORBIDDEN');
   const refs=await db.from('ai_context_references').select('id,context_role,entity_type').eq('ai_output_id',outputId).order('context_role').order('id');
   const summary=z.array(z.strictObject({id:z.uuid(),context_role:aiContextRoleSchema,entity_type:aiContextEntityTypeSchema})).min(1).safeParse(refs.data);
   if(refs.error||!summary.success)throw new AiTaskExecutionError('FORBIDDEN');
   const o=output.data;
   return {id:o.id,ai_generated:true as const,ai_role:o.ai_role,task_type:o.task_type,requested_by:o.requested_by,output_type:o.output_type,verification_status:o.verification_status,disposition:o.disposition,response_text:o.response_text,context_reference_summary:summary.data};
  };
  if(operation.completed&&operation.outputId)return await readOutput(operation.outputId);
  const attempt={actorId,operationId:operation.operationId,attemptId:operation.attemptId};
  // Fresh assembly performed immediately before the one provider invocation.
  // Recheck by original selectors, never by historical provenance as authority.
  let fresh:Awaited<ReturnType<typeof assembleAiPrompt>>;
  try{await checkpoint();fresh=await assembleAiPrompt(assemblyRequest);if(!isDeepStrictEqual(fresh,assembly)||(await getAuthorizationContext()).userId!==actorId)throw Error('Changed');}
  catch{try{await storage.rpc('release_ai_task_operation',{input:{...attempt,beforeProvider:true}});}catch{/* No provider attempt occurred. */}throw new AiTaskExecutionError('FORBIDDEN');}
  const started=performance.now();let result:ReturnType<typeof normalizedResult.safeParse>;
  try{result=normalizedResult.safeParse(await runtime.provider.generate(fresh.providerInput));}catch{result=normalizedResult.safeParse(null);}
  let success=false,responseText:string|null=null;
  if(result.success&&result.data.success&&result.data.error===null){
   try{
    const d=result.data;
    const outputSchema=(task as unknown as {outputSchema:unknown}).outputSchema;
    if(outputSchema&&!matchesAiOutputSchema(outputSchema,d.structured))throw Error('Invalid task output');
    if(!validatePatentAiResponse(task.taskType,d.structured,d.text,fresh.providerInput.input))throw Error('Invalid patent analysis');
    if(d.reference)safeResponse(`${d.reference.provider}:${d.reference.responseId}`);
    if(fresh.providerInput.outputSchema&&(d.structured===null||typeof d.structured!=='object'||Array.isArray(d.structured)))throw Error('Malformed structured transport');
    if(d.structured!==null&&(typeof d.structured!=='object'||Array.isArray(d.structured)))throw Error('Malformed structured transport');
    if(d.text!==null)safeResponse(d.text);
    responseText=safeResponse(d.structured!==null?JSON.stringify(d.structured):d.text??'');
    if(!responseText.trim())throw Error('Absent response');
    success=true;
   }catch{success=false;}
  }
  const metrics={...attempt,inputUsage:result.success?result.data.usage.inputUsage:null,outputUsage:result.success?result.data.usage.outputUsage:null,latencyMs:result.success?result.data.latencyMs:Math.min(Number.MAX_SAFE_INTEGER,Math.max(0,Math.round(performance.now()-started))),successFailure:success?'SUCCESS':'FAILURE'};
  let logged=false;
  for(let i=0;i<2&&!logged;i++){
   try{const r=await storage.rpc('record_ai_task_attempt',{input:metrics});logged=!r.error;}catch{/* Same attempt, same metrics: exact logging retry only. */}
  }
  if(!logged)throw new AiTaskExecutionError('SAVE_FAILED');
  const release=async()=>{try{await storage.rpc('release_ai_task_operation',{input:attempt});}catch{/* Running remains fail-closed if storage is unavailable. */}};
  if(!success||!result.success||responseText===null){await release();throw new AiTaskExecutionError('PROVIDER_FAILED');}
  try{
   await checkpoint();
   const current=await assembleAiPrompt(assemblyRequest);
   if(!isDeepStrictEqual(current,assembly)||(await getAuthorizationContext()).userId!==actorId)throw Error('Authorization/context changed');
   const sourceReferences=(assembly.metadata.sourceReferences??[]).filter(({candidate})=>candidate.context_role==='PATENT'||candidate.context_role==='EVIDENCE').map(({reference,candidate})=>({reference,entity_type:candidate.entity_type,entity_id:candidate.entity_id,context_role:candidate.context_role,included_snapshot_hash:candidate.included_snapshot_hash,share_snapshot_id:candidate.share_snapshot_id}));
   const saveBody:Record<string,z.infer<ReturnType<typeof z.json>>>=JSON.parse(JSON.stringify({...attempt,promptText:v.userInstruction||task.taskType,responseText,outputType:task.outputType,providerReference:result.data.reference?`${result.data.reference.provider}:${result.data.reference.responseId}`:null,references:assembly.metadata.contextReferences,metadata:{prompt_template_id:assembly.metadata.promptTemplateId,prompt_template_version:assembly.metadata.promptTemplateVersion,model_profile:assembly.metadata.modelProfile,output_schema:task.outputSchema,...(sourceReferences.length?{source_references:sourceReferences}:{})}}));
   const r=await storage.rpc('save_ai_task_result',{input:saveBody});
   if(r.error||!z.uuid().safeParse(r.data).success)throw Error('Save unavailable');
   return await readOutput(r.data as string);
  }catch{await release();throw new AiTaskExecutionError('SAVE_FAILED');}
 }catch(error){throw error instanceof AiTaskExecutionError?error:new AiTaskExecutionError('FORBIDDEN');}
}







