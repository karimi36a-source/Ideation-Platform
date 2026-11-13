import {pilotEmailDefaults} from './email-policy-config';
import membershipText from './membership-registry.json';
import 'server-only';
import {z} from 'zod';

// Reuse M5 persisted codes; do not introduce a second membership vocabulary.
export const notificationTypeSchema=z.enum([
 'MEMBER_ADDED','MEMBER_REMOVED','MEMBER_MOVED','ARTIFACT_SHARED',
 'SUBMISSION_RECEIVED','REVISION_REQUESTED','ARTIFACT_APPROVED','COMMENT_RECEIVED',
]);
export type NotificationType=z.infer<typeof notificationTypeSchema>;
// Generic summaries need no source body, display name, ID or client recipient.
// Reject unexpected fields at runtime as well as in TypeScript.
const safeInputSchema=z.strictObject({});
export type NotificationTextInput=Readonly<Record<string,never>>;
type RecipientStrategy='CURRENT_AUTHORIZED_TARGET_OWNERS_EXCLUDING_AUTHOR'|'AFFECTED_MEMBERSHIP_USER'|'CURRENT_SHARE_DESTINATION'|'CURRENT_ASSIGNED_SUBMISSION_REVIEWER'|'CURRENT_AUTHORIZED_SUBMITTER_OR_OWNING_TEAM';
export type NotificationTypeDefinition=Readonly<{
 code:NotificationType;
 titleFormatter:(input:NotificationTextInput)=>string;
 bodyFormatter:(input:NotificationTextInput)=>string;
 // Canonical existing audit/navigation entity names, not a new entity catalog.
 targetEntityType:'team'|'share'|'submission';
 targetEntityTypes?:readonly ('share'|'submission')[];
 emailPolicy:'PILOT_ELIGIBLE'|'DISABLED';
 realtimeEligible:boolean;
 recipientResolution:Readonly<{strategy:RecipientStrategy;authority:'SERVER_CANONICAL_CURRENT_AUTHORIZATION'}>;
}>;
function definition(code:NotificationType,title:string,body:string,targetEntityType:NotificationTypeDefinition['targetEntityType'],strategy:RecipientStrategy):NotificationTypeDefinition{
 return Object.freeze({code,
  titleFormatter:Object.freeze((input:NotificationTextInput)=>{safeInputSchema.parse(input);return title;}),
  bodyFormatter:Object.freeze((input:NotificationTextInput)=>{safeInputSchema.parse(input);return body;}),
  targetEntityType,emailPolicy:pilotEmailDefaults[code]?'PILOT_ELIGIBLE':'DISABLED',realtimeEligible:true,
  recipientResolution:Object.freeze({strategy,authority:'SERVER_CANONICAL_CURRENT_AUTHORIZATION'}),
 });
}
/** Metadata only. Never creates rows, resolves recipients, authorizes targets or
 * delivers messages. Later services must recheck current canonical access.
 * Realtime eligibility is no subscription/access grant. Email policy metadata
 * reflects pilot defaults only; it does not dispatch email or select recipients.
 */
const registry:Readonly<Record<NotificationType,NotificationTypeDefinition>>=Object.freeze({
 MEMBER_ADDED:definition('MEMBER_ADDED',membershipText.MEMBER_ADDED.title,membershipText.MEMBER_ADDED.body,'team','AFFECTED_MEMBERSHIP_USER'),
 MEMBER_REMOVED:definition('MEMBER_REMOVED',membershipText.MEMBER_REMOVED.title,membershipText.MEMBER_REMOVED.body,'team','AFFECTED_MEMBERSHIP_USER'),
 MEMBER_MOVED:definition('MEMBER_MOVED',membershipText.MEMBER_MOVED.title,membershipText.MEMBER_MOVED.body,'team','AFFECTED_MEMBERSHIP_USER'),
 ARTIFACT_SHARED:definition('ARTIFACT_SHARED','Artifact shared','An Artifact Snapshot has been shared with you.','share','CURRENT_SHARE_DESTINATION'),
 SUBMISSION_RECEIVED:definition('SUBMISSION_RECEIVED','Submission received','A submission is available for your assigned review.','submission','CURRENT_ASSIGNED_SUBMISSION_REVIEWER'),
 REVISION_REQUESTED:definition('REVISION_REQUESTED','Revision requested','A revision has been requested for a submission.','submission','CURRENT_AUTHORIZED_SUBMITTER_OR_OWNING_TEAM'),
 ARTIFACT_APPROVED:definition('ARTIFACT_APPROVED','Artifact approved','An Artifact submission has been approved.','submission','CURRENT_AUTHORIZED_SUBMITTER_OR_OWNING_TEAM'),
 COMMENT_RECEIVED:Object.freeze({...definition('COMMENT_RECEIVED','New comment received','New feedback was added.','submission','CURRENT_AUTHORIZED_TARGET_OWNERS_EXCLUDING_AUTHOR'),targetEntityTypes:Object.freeze(['submission','share'] as const)}),
});
const definitions=Object.freeze(Object.values(registry));
export class NotificationTypeError extends Error{
 readonly code='UNKNOWN_NOTIFICATION_TYPE';
 constructor(){super('Notification type unavailable');this.name='NotificationTypeError';}
}
export function getNotificationTypeDefinition(code:unknown):NotificationTypeDefinition{
 const parsed=notificationTypeSchema.safeParse(code);
 if(!parsed.success)throw new NotificationTypeError();
 return registry[parsed.data];
}
export function listNotificationTypeDefinitions():readonly NotificationTypeDefinition[]{return definitions;}
