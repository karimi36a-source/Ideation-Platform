import 'server-only';
import {z} from 'zod';
import type {NotificationType} from './type-registry';

/** Approved M15.15 pilot defaults. Eligibility is not dispatch or recipient
 * authority. Future types must be explicitly approved; never inherit a default. */
export const pilotEmailDefaults=Object.freeze({
 MEMBER_ADDED:true,MEMBER_REMOVED:true,MEMBER_MOVED:true,
 SUBMISSION_RECEIVED:true,REVISION_REQUESTED:true,ARTIFACT_APPROVED:true,
 ARTIFACT_SHARED:false,COMMENT_RECEIVED:false,
} satisfies Readonly<Record<NotificationType,boolean>>);
export type EmailPolicyOverrides=Partial<Record<Exclude<NotificationType,'COMMENT_RECEIVED'>,boolean>>&{COMMENT_RECEIVED?:false};
const overridesSchema=z.strictObject(Object.fromEntries(Object.keys(pilotEmailDefaults).map(code=>[code,z.boolean().optional()])))
 .refine(value=>value.COMMENT_RECEIVED!==true);
/** Trusted server composition only. Never construct configuration from a client
 * request. No environment secrets, provider types, templates or recipient lists. */
export function createEmailEligibilityPolicy(overrides:EmailPolicyOverrides={}){
 const parsed=overridesSchema.safeParse(overrides);
 if(!parsed.success)throw new Error('Invalid notification email policy configuration');
 const settings=Object.freeze({...pilotEmailDefaults,...Object.fromEntries(Object.entries(parsed.data).filter(([,value])=>value!==undefined))});
 return Object.freeze({isEligible:(type:unknown):boolean=>typeof type==='string'&&Object.hasOwn(settings,type)&&settings[type as NotificationType]===true});
}
