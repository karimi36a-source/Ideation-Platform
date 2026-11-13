import {z} from 'zod';
import {aiUsageModelProfileSchema} from './usage-schema';
import {aiPromptOutputSchema} from './prompt-template-schema';

// Operational codes only: no caller identifiers, authorization, or arbitrary metadata.
export const aiGenerateInputSchema=z.strictObject({
 modelProfile:aiUsageModelProfileSchema,
 instructions:z.string().trim().min(1).max(128000),
 input:z.string().min(1).max(1000000),
 outputSchema:aiPromptOutputSchema.optional(),
 metadata:z.strictObject({operation:z.enum(['GENERATE','GENERATE_STRUCTURED']).optional()}).optional(),
});
export type AiGenerateInput=z.infer<typeof aiGenerateInputSchema>;
export type AiProviderErrorCode='INVALID_INPUT'|'CONFIGURATION'|'AUTHENTICATION'|'RATE_LIMIT'|'TIMEOUT'|'NETWORK'|'UNAVAILABLE'|'MALFORMED_RESPONSE'|'REFUSED'|'INCOMPLETE'|'UNKNOWN';
export type AiProviderResult={
 success:boolean; text:string|null; structured:unknown;
 usage:{inputUsage:number|null;outputUsage:number|null}; latencyMs:number;
 reference:{provider:string;responseId:string}|null;
 error:{code:AiProviderErrorCode;retryable:boolean}|null;
};
// No provider SDK types or model names cross this boundary.
export interface AiProvider {generate(input:AiGenerateInput):Promise<AiProviderResult>}
