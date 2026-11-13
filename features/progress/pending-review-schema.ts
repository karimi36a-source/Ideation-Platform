import {z} from 'zod';
import {artifactTypeSchema} from '@/features/artifacts/schema';
// Preserve PostgreSQL microsecond ordering; Date.parse alone truncates to milliseconds.
const instant=(value:string)=>{const milliseconds=Date.parse(value);return Number.isFinite(milliseconds)?BigInt(milliseconds)*BigInt(1000)+BigInt((value.match(/\.(\d+)/)?.[1]??'').slice(3,6).padEnd(3,'0')):BigInt(0);};
const identity=z.strictObject({id:z.uuid(),name:z.string()});
export const pendingReviewQueueItemSchema=z.strictObject({
 submissionId:z.uuid(),cohortId:z.uuid(),submittedAt:z.iso.datetime({offset:true}),reviewState:z.enum(['SUBMITTED','UNDER_REVIEW']),
 teamOrStudent:identity.extend({type:z.enum(['TEAM','USER'])}),
 artifact:z.strictObject({id:z.uuid(),title:z.string(),artifactType:artifactTypeSchema}),
 version:z.strictObject({id:z.uuid(),versionNumber:z.number().int().positive()}),
 activity:identity.extend({definitionId:z.uuid()}),project:identity,
});
export const pendingReviewQueueSchema=z.strictObject({items:z.array(pendingReviewQueueItemSchema)}).refine(({items})=>{
 if(new Set(items.map(item=>item.submissionId.toLowerCase())).size!==items.length)return false;
 return items.every((item,index)=>index===0||instant(items[index-1].submittedAt)<instant(item.submittedAt)||instant(items[index-1].submittedAt)===instant(item.submittedAt)&&items[index-1].submissionId.toLowerCase()<item.submissionId.toLowerCase());
},{message:'Expected unique submissions in canonical oldest-first order'});
export type PendingReviewQueue=z.infer<typeof pendingReviewQueueSchema>;



