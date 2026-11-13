import 'server-only';
import {z} from 'zod';
import {activityMethodSchema} from '@/features/activities/schema';
import {aiContextRoleSchema} from './context-schema';
import {aiOutputTypeSchema,aiOutputVerificationStatusSchema} from './schema';
import {aiPromptRoleSchema,aiPromptOutputSchema,isAiPromptPairAllowed} from './prompt-template-schema';
import {aiUsageModelProfileSchema} from './usage-schema';
import {createAiModelProfileResolver} from './model-profile-resolver';
import {patentResearchOutputSchema} from './patent-traceability';

const taskTypeSchema=z.enum(['SCAMPER_ASSISTANCE','BRAINSTORMING_ASSISTANCE','SYSTEM_STRUCTURE_ANALYSIS','GAP_ANALYSIS','PATENT_RESEARCH_ASSISTANCE','COMPARATIVE_ANALYSIS','CRITICAL_REVIEW','SESSION10_GAP_REFINEMENT']);
// Safety exclusions, not new source kinds. All sources still use M14.2 roles.
const exclusions={unrelatedTeamOrWorkspace:true,revokedShare:true,formerTeam:true,unrevealedPeerBrainstorm:true,unrelatedChat:true,unrelatedFiles:true,siblingPrivateEntities:true,organizationWideData:true} as const;
const taskDefinitionSchema=z.strictObject({
 taskType:taskTypeSchema,
 allowedRole:aiPromptRoleSchema,
 templateActivityType:activityMethodSchema,
 context:z.strictObject({required:z.array(aiContextRoleSchema).min(1),optional:z.array(aiContextRoleSchema),forbidden:z.array(aiContextRoleSchema),exclusions:z.object(Object.fromEntries(Object.keys(exclusions).map(key=>[key,z.literal(true)])))}),
 outputType:aiOutputTypeSchema,
 outputSchema:aiPromptOutputSchema,
 verification:z.strictObject({initialStatus:z.literal(aiOutputVerificationStatusSchema.enum.UNVERIFIED),humanReviewRequired:z.literal(true),evidenceRequiredForFactualClaims:z.literal(true),automaticVerification:z.literal(false),automaticLegalConclusions:z.literal(false)}),
 // No automatic canonical writes, promotion, approval, votes, review or ACL changes.
 allowedProjectActions:z.array(z.never()).max(0),
 defaultModelProfile:aiUsageModelProfileSchema,
 allowedModelProfiles:z.array(aiUsageModelProfileSchema).length(1),
}).refine(v=>isAiPromptPairAllowed(v.allowedRole,v.templateActivityType))
 .refine(v=>v.allowedModelProfiles[0]===v.defaultModelProfile)
 .refine(v=>{const roles=[...v.context.required,...v.context.optional,...v.context.forbidden];return roles.length===aiContextRoleSchema.options.length&&new Set(roles).size===roles.length;});
type DeepReadonly<T>=T extends object?{readonly [K in keyof T]:DeepReadonly<T[K]>}:T;
export type AiTaskDefinition=DeepReadonly<z.infer<typeof taskDefinitionSchema>>;
export type AiTaskType=z.infer<typeof taskTypeSchema>;
function freeze<T>(value:T):DeepReadonly<T>{if(value!==null&&typeof value==='object'){Object.values(value).forEach(freeze);Object.freeze(value);}return value as DeepReadonly<T>;}
// Closed structured JSON schemas reuse the accepted M14.3 subset. These define
// output intent only; provider-output validation policy belongs to M14.12.
const string={type:'string'};
function output(fields:readonly string[]){return {type:'object',properties:Object.fromEntries(fields.map(field=>[field,string])),required:[...fields],additionalProperties:false};}
function context(required:z.infer<typeof aiContextRoleSchema>[],optional:z.infer<typeof aiContextRoleSchema>[]){return {required,optional,forbidden:aiContextRoleSchema.options.filter(role=>![...required,...optional].includes(role)),exclusions};}
const verification={initialStatus:'UNVERIFIED',humanReviewRequired:true,evidenceRequiredForFactualClaims:true,automaticVerification:false,automaticLegalConclusions:false} as const;
function define(taskType:AiTaskType,allowedRole:z.infer<typeof aiPromptRoleSchema>,templateActivityType:z.infer<typeof activityMethodSchema>,scope:ReturnType<typeof context>,outputType:z.infer<typeof aiOutputTypeSchema>,fields:readonly string[]|Record<string,unknown>,profile:z.infer<typeof aiUsageModelProfileSchema>):AiTaskDefinition{
 return freeze<unknown>(taskDefinitionSchema.parse({taskType,allowedRole,templateActivityType,context:scope,outputType,outputSchema:Array.isArray(fields)?output(fields):fields,verification,allowedProjectActions:[],defaultModelProfile:profile,allowedModelProfiles:[profile]})) as AiTaskDefinition;
}
// Contracts hold no prompt bodies, credentials, provider models, source IDs or
// data access. Template methodology resolves by this role/activity pair later.
const tasks=freeze({
 SCAMPER_ASSISTANCE:define('SCAMPER_ASSISTANCE','STRUCTURED_CREATIVITY_ASSISTANT','scamper',context(['CURRENT_ARTIFACT','COURSE_CONTEXT'],['CURRENT_PROJECT','GAP']),'SUGGESTION',['technique','original_element','proposed_change','reasoning','potential_benefit','risk_or_unknown'],'AI_STANDARD'),
 BRAINSTORMING_ASSISTANCE:define('BRAINSTORMING_ASSISTANCE','BRAINSTORMING_FACILITATOR','brainstorming',context(['CURRENT_ARTIFACT','COURSE_CONTEXT'],['CURRENT_PROJECT','GAP','BRAINSTORM']),'SUGGESTION',['candidate_options','different_perspectives','assumptions','verification_needed'],'AI_STANDARD'),
 SYSTEM_STRUCTURE_ANALYSIS:define('SYSTEM_STRUCTURE_ANALYSIS','SYSTEM_STRUCTURE_ANALYST','mind_map',context(['CURRENT_ARTIFACT','COURSE_CONTEXT'],['CURRENT_PROJECT','GAP','EVIDENCE','TEAM_DECISION']),'ANALYSIS',['structure_observations','missing_relationships','proposed_directions','verification_needed'],'AI_DEEP'),
 GAP_ANALYSIS:define('GAP_ANALYSIS','COMPARATIVE_CRITICAL_ANALYST','comparison',context(['GAP','CURRENT_ARTIFACT'],['EVIDENCE','PATENT','INSTRUCTOR_FEEDBACK','COURSE_CONTEXT','CURRENT_PROJECT']),'ANALYSIS',['gap','evidence','why_it_matters','candidate_direction','verification_needed'],'AI_DEEP'),
 PATENT_RESEARCH_ASSISTANCE:define('PATENT_RESEARCH_ASSISTANCE','PATENT_RESEARCH_ASSISTANT','patent_research',context(['CURRENT_ARTIFACT','COURSE_CONTEXT'],['PATENT','EVIDENCE','GAP','CURRENT_PROJECT']),'ANALYSIS',patentResearchOutputSchema,'AI_DEEP'),
 COMPARATIVE_ANALYSIS:define('COMPARATIVE_ANALYSIS','COMPARATIVE_CRITICAL_ANALYST','comparison',context(['CURRENT_ARTIFACT'],['PRIOR_APPROVED_OUTPUT','PATENT','EVIDENCE','GAP','TEAM_DECISION','INSTRUCTOR_FEEDBACK','COURSE_CONTEXT']),'COMPARISON',['similarities','differences','assumptions','source_references','verification_needed'],'AI_DEEP'),
 CRITICAL_REVIEW:define('CRITICAL_REVIEW','CRITICAL_REVIEWER','review',context(['CURRENT_ARTIFACT'],['PRIOR_APPROVED_OUTPUT','EVIDENCE','GAP','TEAM_DECISION','INSTRUCTOR_FEEDBACK','COURSE_CONTEXT']),'ANALYSIS',['observations','weak_assumptions','open_questions','verification_needed'],'AI_DEEP'),
 SESSION10_GAP_REFINEMENT:define('SESSION10_GAP_REFINEMENT','COMPARATIVE_CRITICAL_ANALYST','comparison',context(['CURRENT_ARTIFACT','GAP','COURSE_CONTEXT'],['CURRENT_PROJECT','PRIOR_APPROVED_OUTPUT','PATENT','EVIDENCE','TEAM_DECISION','INSTRUCTOR_FEEDBACK']),'ANALYSIS',['current_state','gap','candidate_directions','impact_analysis','uncertainties','verification_needed'],'AI_DEEP'),
});
export class AiTaskRegistryError extends Error{
 constructor(readonly code:'UNKNOWN_TASK'|'INVALID_TASK_REQUEST'){super('AI task unavailable');this.name='AiTaskRegistryError';}
}
export function getAiTaskDefinition(taskType:unknown):AiTaskDefinition{
 const parsed=taskTypeSchema.safeParse(taskType);
 if(!parsed.success)throw new AiTaskRegistryError('UNKNOWN_TASK');
 return tasks[parsed.data];
}
const requestSchema=z.strictObject({taskType:taskTypeSchema});
/** Identifier-only request boundary. No retrieval, authorization, provider call,
 * output persistence or autonomous action is performed by registry resolution.
 */
export function resolveAiTaskRequest(request:unknown){
 const parsed=requestSchema.safeParse(request);
 if(!parsed.success)throw new AiTaskRegistryError('INVALID_TASK_REQUEST');
 const definition=getAiTaskDefinition(parsed.data.taskType);
 const resolved=createAiModelProfileResolver({taskType:definition.taskType,defaultModelProfile:definition.defaultModelProfile,allowedModelProfiles:definition.allowedModelProfiles})();
 return Object.freeze({definition,modelProfile:resolved.modelProfile});
}


/** Server-only catalog; definitions contain no source data or authority. */
export function listAiTaskDefinitions():readonly AiTaskDefinition[]{return Object.freeze(Object.values(tasks));}

