import 'server-only';
import {z} from 'zod';
import {getNotificationTypeDefinition} from './type-registry';
import type {EmailTemplateDefinition} from '@/features/email/templates';
/** Generic registry wording only; never interpolate stored notification text,
 * domain bodies, names, feedback or source metadata into email. */
export const notificationEmailTemplate:EmailTemplateDefinition=Object.freeze({
 id:'FICI_NOTIFICATION',
 variablesSchema:z.strictObject({notificationType:z.enum(['SUBMISSION_RECEIVED','REVISION_REQUESTED','ARTIFACT_APPROVED','MEMBER_ADDED','MEMBER_REMOVED','MEMBER_MOVED'])}),
 render:variables=>{const d=getNotificationTypeDefinition(variables.notificationType);return {subject:d.titleFormatter({}),text:d.bodyFormatter({})+' Sign in to FICI to view your notifications.',relativePath:'/account'};},
});
