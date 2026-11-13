import {z} from 'zod';
import {artifactTypeSchema} from '@/features/artifacts/schema';
import {submissionSchema} from '@/features/artifacts/submission-schema';
const identity=z.strictObject({id:z.uuid(),name:z.string()});
const ref=z.strictObject({id:z.uuid(),versionNumber:z.number().int().positive()});
export const revisionStatusItemSchema=z.strictObject({submissionId:z.uuid(),cohortId:z.uuid(),artifact:z.strictObject({id:z.uuid(),title:z.string(),artifactType:artifactTypeSchema}),version:ref,
 status:z.literal('REVISION_REQUESTED'),requestedAt:z.iso.datetime({offset:true}),feedbackTarget:z.strictObject({feedbackId:z.uuid(),reviewActionId:z.uuid()}),activity:identity,project:identity,
 teamOrStudent:identity.extend({type:z.enum(['TEAM','USER'])}),hasSuccessor:z.boolean(),drafts:z.array(ref),successors:z.array(z.strictObject({submissionId:z.uuid(),versionId:z.uuid(),versionNumber:z.number().int().positive(),status:submissionSchema.shape.status}))});
export const revisionStatusSchema=z.strictObject({outstanding:z.array(revisionStatusItemSchema),history:z.array(revisionStatusItemSchema)}).refine(v=>v.outstanding.every(i=>!i.hasSuccessor)&&v.history.every(i=>i.hasSuccessor)&&new Set([...v.outstanding,...v.history].map(i=>i.submissionId)).size===v.outstanding.length+v.history.length);
export type RevisionStatus=z.infer<typeof revisionStatusSchema>;
