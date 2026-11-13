import {z} from "zod";
import {artifactTypeSchema,artifactStatusSchema} from "./schema";
export const submitArtifactSchema=z.strictObject({artifactId:z.uuid(),artifactVersionId:z.uuid(),activityInstanceId:z.uuid()});
export const submissionSchema=z.strictObject({id:z.uuid(),activity_instance_id:z.uuid(),artifact_id:z.uuid(),artifact_version_id:z.uuid(),submitted_by:z.uuid(),submitted_at:z.iso.datetime({offset:true}),status:z.enum(["SUBMITTED","UNDER_REVIEW","REVISION_REQUESTED","APPROVED","REJECTED"]),reviewer_user_id:z.uuid()}).refine(v=>v.submitted_by!==v.reviewer_user_id);
export const submittedArtifactMetadataSchema=z.strictObject({id:z.uuid(),artifactType:artifactTypeSchema,title:z.string().trim().min(1),status:artifactStatusSchema,projectId:z.uuid(),workspaceId:z.uuid(),activityInstanceId:z.uuid().nullable(),reviewRequired:z.boolean(),approvalRequired:z.boolean()});
export type Submission=z.infer<typeof submissionSchema>;
