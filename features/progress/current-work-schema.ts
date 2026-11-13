import {z} from 'zod';
import {activityInstanceStatusSchema} from '@/features/activities/instance-schema';
import {activityAvailabilitySchema} from '@/features/activities/availability-schema';
import {artifactTypeSchema} from '@/features/artifacts/schema';
import {artifactVersionStatusSchema} from '@/features/artifacts/version-schema';
import {submissionSchema} from '@/features/artifacts/submission-schema';
const label=z.strictObject({id:z.uuid(),name:z.string()});
export const currentWorkVersionSchema=z.strictObject({id:z.uuid(),versionNumber:z.number().int().positive(),status:artifactVersionStatusSchema});
export const currentWorkArtifactSchema=z.strictObject({
 id:z.uuid(),title:z.string(),artifactType:artifactTypeSchema,
 drafts:z.array(currentWorkVersionSchema),
 // Each cycle retains its exact canonical target/status. No latest-Submission
 // heuristic or independent aggregate review state is introduced.
 submissions:z.array(z.strictObject({id:z.uuid(),artifactVersionId:z.uuid(),versionNumber:z.number().int().positive(),status:submissionSchema.shape.status,revisionRequested:z.boolean(),previousVersionId:z.uuid().nullable()})),
 approvedOutput:currentWorkVersionSchema.nullable(),
});
export const currentWorkActivitySchema=z.strictObject({
 session:z.strictObject({id:z.uuid(),title:z.string(),sessionNumber:z.number().int(),sequence:z.number().int()}),
 definition:z.strictObject({id:z.uuid(),name:z.string(),sequence:z.number().int()}),
 instanceId:z.uuid().nullable(),status:activityInstanceStatusSchema.nullable(),
 availability:activityAvailabilitySchema,work:z.array(currentWorkArtifactSchema),
});
export const currentWorkContextSchema=z.strictObject({
 id:z.uuid(),enrollmentId:z.uuid(),course:label,cohort:label,team:label.nullable(),
 workspace:z.strictObject({id:z.uuid(),type:z.enum(['PERSONAL','TEAM'])}),project:label,
 activities:z.array(currentWorkActivitySchema),
});
export const myCurrentWorkSchema=z.strictObject({contexts:z.array(currentWorkContextSchema),unreadNotificationCount:z.number().int().nonnegative()});
export type CurrentWorkArtifact=z.infer<typeof currentWorkArtifactSchema>;
export type CurrentWorkActivity=z.infer<typeof currentWorkActivitySchema>;
export type CurrentWorkContext=z.infer<typeof currentWorkContextSchema>;
export type MyCurrentWork=z.infer<typeof myCurrentWorkSchema>;
