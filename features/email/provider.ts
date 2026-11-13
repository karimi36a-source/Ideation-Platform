import 'server-only';
import {z} from 'zod';

const scalar=z.union([z.string().max(8192),z.number(),z.boolean(),z.null()]);
export const emailSendSchema=z.strictObject({
 to:z.email().max(254),
 template:z.string().regex(/^[A-Z][A-Z0-9_]{0,63}$/),
 variables:z.record(z.string().regex(/^[A-Za-z][A-Za-z0-9_]{0,63}$/),scalar).refine(v=>Object.keys(v).length<=32),
 idempotencyKey:z.string().regex(/^[A-Za-z0-9:/.\-_]{1,256}$/).optional(),
});
export type EmailSendInput=z.infer<typeof emailSendSchema>;
export type EmailErrorCode='INVALID_INPUT'|'CONFIGURATION'|'AUTHENTICATION'|'RATE_LIMIT'|'TIMEOUT'|'NETWORK'|'UNAVAILABLE'|'REJECTED'|'CONFLICT'|'MALFORMED_RESPONSE'|'UNKNOWN';
export type EmailResult={success:true;messageId:string}|{success:false;error:{code:EmailErrorCode;message:string;retryable:boolean}};
/** Server-to-server contract only. No provider types, authorization, persistence,
 * eligibility rules, retries or domain callbacks cross this boundary. */
export interface EmailProvider {send(input:EmailSendInput):Promise<EmailResult>}
