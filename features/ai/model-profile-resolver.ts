import 'server-only';
import {z} from 'zod';
import {aiUsageModelProfileSchema} from './usage-schema';

export type AiModelProfile=z.infer<typeof aiUsageModelProfileSchema>;
export type AiTaskProfileContract={
 taskType:string;
 defaultModelProfile:AiModelProfile;
 allowedModelProfiles:readonly AiModelProfile[];
};
const contractSchema=z.strictObject({
 taskType:z.string().regex(/^[A-Z][A-Z0-9_]{0,63}$/),
 defaultModelProfile:aiUsageModelProfileSchema,
 allowedModelProfiles:z.array(aiUsageModelProfileSchema).min(1).max(4),
}).refine(v=>new Set(v.allowedModelProfiles).size===v.allowedModelProfiles.length&&v.allowedModelProfiles.includes(v.defaultModelProfile));
const requestSchema=z.strictObject({modelProfile:aiUsageModelProfileSchema.optional()});
export class AiModelProfileResolutionError extends Error {
 constructor(readonly code:'INVALID_TASK_CONTRACT'|'INVALID_PROFILE_REQUEST'|'PROFILE_NOT_ALLOWED'){
  super('AI model profile unavailable');this.name='AiModelProfileResolutionError';
 }
}

/** Bind only a trusted SERVER task contract, never request JSON. This is a
 * minimal contract boundary, not a task registry or an authorization decision.
 * The returned platform profile also selects the provider's private config map;
 * provider credentials/model names never enter this resolver or its result.
 */
export function createAiModelProfileResolver(contract:AiTaskProfileContract){
 const parsed=contractSchema.safeParse(contract);
 if(!parsed.success)throw new AiModelProfileResolutionError('INVALID_TASK_CONTRACT');
 // Zod copies input; later mutation of the caller's configuration cannot expand it.
 const trusted=parsed.data;
 return (request:unknown={}):Readonly<{taskType:string;modelProfile:AiModelProfile}>=>{
  const parsedRequest=requestSchema.safeParse(request);
  if(!parsedRequest.success)throw new AiModelProfileResolutionError('INVALID_PROFILE_REQUEST');
  const modelProfile=parsedRequest.data.modelProfile??trusted.defaultModelProfile;
  if(!trusted.allowedModelProfiles.includes(modelProfile))throw new AiModelProfileResolutionError('PROFILE_NOT_ALLOWED');
  return Object.freeze({taskType:trusted.taskType,modelProfile});
 };
}
