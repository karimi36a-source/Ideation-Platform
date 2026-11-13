import {z} from 'zod';
import {activityInstanceStatusSchema} from '@/features/activities/instance-schema';
import {artifactTypeSchema} from '@/features/artifacts/schema';
const identity=z.strictObject({id:z.uuid(),name:z.string()});
const target=z.strictObject({submissionId:z.uuid(),artifactId:z.uuid(),versionId:z.uuid(),versionNumber:z.number().int().positive(),status:z.enum(['SUBMITTED','UNDER_REVIEW','REVISION_REQUESTED'])});
export const masterCohortOverviewSchema=z.strictObject({
 cohort:identity.extend({status:z.enum(['planned','active','completed','archived'])}),
 teams:z.array(z.strictObject({
  team:identity.extend({status:z.enum(['created','active','completed'])}),activeMemberCount:z.number().int().nonnegative(),
  projects:z.array(z.strictObject({
   project:identity.extend({status:z.enum(['active','completed'])}),
   activities:z.array(z.strictObject({definition:identity.extend({sequence:z.number().int()}),session:z.strictObject({id:z.uuid(),title:z.string(),sessionNumber:z.number().int(),sequence:z.number().int()}),instances:z.array(z.strictObject({id:z.uuid(),status:activityInstanceStatusSchema})),availableToStart:z.boolean()})),
   pendingReview:z.strictObject({count:z.number().int().nonnegative(),targets:z.array(target)}).refine(v=>v.count===v.targets.length&&v.targets.every(t=>t.status!=='REVISION_REQUESTED')),
   revisionRequested:z.strictObject({pending:z.boolean(),targets:z.array(target)}).refine(v=>v.pending===(v.targets.length>0)&&v.targets.every(t=>t.status==='REVISION_REQUESTED')),
   approvedOutputs:z.array(z.strictObject({artifactId:z.uuid(),artifactType:artifactTypeSchema,versionId:z.uuid(),versionNumber:z.number().int().positive(),status:z.enum(['APPROVED','CURRENT'])})),
   lastMeaningfulWorkflowUpdateAt:z.iso.datetime({offset:true}).nullable(),
  })),
 })),
});
export type MasterCohortOverview=z.infer<typeof masterCohortOverviewSchema>;
