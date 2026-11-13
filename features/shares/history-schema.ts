import {z} from 'zod';
import {shareEntityTypes,sharePermissionLevels,shareModes} from './schema';
export const listEntitySharesInputSchema=z.strictObject({entityType:z.enum(shareEntityTypes),entityId:z.uuid().transform(s=>s.toLowerCase())});
const destination=z.discriminatedUnion('type',[
 z.strictObject({type:z.literal('TEAM'),teamId:z.uuid()}),
 z.strictObject({type:z.literal('MASTER'),userId:z.uuid().nullable()}),
 z.strictObject({type:z.literal('USER'),userId:z.uuid()}),
 z.strictObject({type:z.literal('COHORT'),cohortId:z.uuid()}),
 z.strictObject({type:z.literal('WORKSPACE'),workspaceId:z.uuid()}),
]);
export const shareHistoryRecordSchema=z.strictObject({shareId:z.uuid(),destination,permissionLevel:z.enum(sharePermissionLevels),shareMode:z.enum(shareModes),sourceVersionId:z.uuid().nullable(),createdAt:z.iso.datetime({offset:true}),sharedBy:z.uuid(),state:z.enum(['ACTIVE','REVOKED']),revokedAt:z.iso.datetime({offset:true}).nullable(),revokedBy:z.uuid().nullable()})
 .refine(r=>r.state==='ACTIVE'?r.revokedAt===null&&r.revokedBy===null:r.revokedAt!==null&&r.revokedBy!==null&&Date.parse(r.revokedAt)>=Date.parse(r.createdAt),'Invalid revocation history');
export const entityShareHistorySchema=z.strictObject({entityType:z.enum(shareEntityTypes),entityId:z.uuid(),shares:z.array(shareHistoryRecordSchema)})
 .refine(r=>new Set(r.shares.map(s=>s.shareId)).size===r.shares.length,'Duplicate Share history')
 .refine(r=>r.entityType==='ARTIFACT'||r.shares.every(s=>s.sourceVersionId===null),'Invalid non-versioned target');
export type ListEntitySharesInput=z.infer<typeof listEntitySharesInputSchema>;
export type ShareHistoryRecord=z.infer<typeof shareHistoryRecordSchema>;
export type EntityShareHistory=z.infer<typeof entityShareHistorySchema>;
