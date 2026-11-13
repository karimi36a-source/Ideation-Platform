import {z} from "zod";
export const linkProjectToProgramSchema=z.strictObject({projectId:z.uuid(),programId:z.uuid(),cohortId:z.uuid(),entryArtifactVersionId:z.uuid().nullable().optional()});
export const projectProgramLinkSchema=z.object({id:z.uuid(),project_id:z.uuid(),program_id:z.uuid(),cohort_id:z.uuid(),entered_at:z.iso.datetime({offset:true}),completed_at:z.iso.datetime({offset:true}).nullable(),entry_artifact_version_id:z.uuid().nullable(),exit_artifact_version_id:z.uuid().nullable(),created_at:z.iso.datetime({offset:true}),updated_at:z.iso.datetime({offset:true})}).refine(v=>v.completed_at===null||Date.parse(v.completed_at)>=Date.parse(v.entered_at));
export type ProjectProgramLink=z.infer<typeof projectProgramLinkSchema>;
