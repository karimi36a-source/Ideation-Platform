import 'server-only';
import {z} from 'zod';
import {getAuthorizationContext} from '@/lib/auth/authorization';
import {createServerSupabaseClient} from '@/lib/db/server';
import {getProjectBaseline} from '@/features/projects/baseline';
import {aiContextBuilderInputSchema} from './context-builder-schema';
import {runAiTask} from './run-task';
import type {AiProvider} from './provider';
const checkpointInput=z.strictObject({activityInstanceId:z.uuid(),reconstructionAiOutputId:z.uuid(),confirmed:z.literal(true)});
export const session10CheckpointSchema=z.strictObject({id:z.uuid(),activity_instance_id:z.uuid(),project_id:z.uuid(),workspace_id:z.uuid(),reconstruction_ai_output_id:z.uuid(),baseline_item_id:z.uuid(),confirmed_by:z.uuid(),confirmed_at:z.iso.datetime({offset:true})});
export type Session10Checkpoint=z.infer<typeof session10CheckpointSchema>;
export class Session10Error extends Error{constructor(readonly code:'VALIDATION_ERROR'|'FORBIDDEN'|'CURRENT_BASELINE_REQUIRED'){super('Session 10 unavailable.');this.name='Session10Error';}}
export async function confirmSession10Reconstruction(input:unknown){try{
 const v=checkpointInput.safeParse(input);if(!v.success)throw new Session10Error('VALIDATION_ERROR');
 const actor=await getAuthorizationContext(),db=await createServerSupabaseClient();
 const r=await db.rpc('confirm_session10_reconstruction',{input:v.data});const row=session10CheckpointSchema.safeParse(r.data);
 if(r.error||!row.success||row.data.activity_instance_id!==v.data.activityInstanceId||row.data.reconstruction_ai_output_id!==v.data.reconstructionAiOutputId||row.data.confirmed_by!==actor.userId||(await getAuthorizationContext()).userId!==actor.userId)throw new Session10Error('FORBIDDEN');
 return row.data;
}catch(e){throw e instanceof Session10Error?e:new Session10Error('FORBIDDEN');}}
const reconstructionInput=aiContextBuilderInputSchema.omit({taskType:true}).extend({activityInstanceId:z.uuid(),baselineItemId:z.uuid(),idempotencyKey:z.string().trim().min(1).max(200)});
/** Reuse the exact effective M8 baseline and ordinary comparative AI Output.
 * No Gap is required, no missing source is invented, no Project state is written. */
export async function runSession10Reconstruction(input:unknown,runtime:Readonly<{provider:AiProvider}>){try{
 const v=reconstructionInput.safeParse(input);if(!v.success)throw new Session10Error('VALIDATION_ERROR');
 const actor=await getAuthorizationContext(),p=v.data;
 const db=await createServerSupabaseClient();
 const scope=await db.rpc('validate_session10_reconstruction_scope',{target_activity:p.activityInstanceId,target_project:p.projectId,target_workspace:p.workspaceId});
 if(scope.error||scope.data!==true)throw new Session10Error('FORBIDDEN');
 const baseline=(await getProjectBaseline(p.projectId)).find(row=>row.id===p.baselineItemId);
 if(!baseline||baseline.baseline_type!=='CURRENT_INVENTION_CONCEPT')throw new Session10Error('CURRENT_BASELINE_REQUIRED');
 if(p.selectedContextRefs.some(ref=>ref.contextRole==='GAP'))throw new Session10Error('VALIDATION_ERROR');
 const a=await db.from('artifacts').select('id,project_id,workspace_id,current_version_id,artifact_type').eq('id',baseline.artifact_id).maybeSingle();
 if(a.error||a.data?.artifact_type!=='INVENTION_CONCEPT'||a.data?.project_id!==p.projectId||a.data?.workspace_id!==p.workspaceId||a.data?.current_version_id!==baseline.artifact_version_id||(await getAuthorizationContext()).userId!==actor.userId)throw new Session10Error('FORBIDDEN');
 return runAiTask({projectId:p.projectId,workspaceId:p.workspaceId,activityInstanceId:p.activityInstanceId,taskType:'COMPARATIVE_ANALYSIS',idempotencyKey:p.idempotencyKey,selectedContextRefs:[{entityType:'ARTIFACT_VERSION',entityId:baseline.artifact_version_id,contextRole:'CURRENT_ARTIFACT'},...p.selectedContextRefs],userInstruction:'Reconstruct the current invention from the selected current baseline and authorized Project memory: main problem, current solution, components, functions, relationships, architecture, technical results, constraints and open questions. Distinguish source facts, source-backed Evidence/Patent research and AI interpretation. State missing information and uncertainty; do not invent facts or legal conclusions. Human review is required before resolving one Gap.'},runtime);
}catch(e){throw e instanceof Session10Error?e:new Session10Error('FORBIDDEN');}}
