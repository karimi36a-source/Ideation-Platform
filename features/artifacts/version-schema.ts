import {z} from "zod";
export const artifactVersionStatusSchema=z.enum(["DRAFT","SUBMITTED","UNDER_REVIEW","REVISION_REQUESTED","APPROVED","CURRENT","SUPERSEDED","ARCHIVED"]);
export const artifactVersionSchema=z.strictObject({
 id:z.uuid(),artifact_id:z.uuid(),version_number:z.number().int().positive().max(2147483647),version_label:z.string().nullable(),
 content_snapshot:z.json(),change_summary:z.string().nullable(),status:artifactVersionStatusSchema,draft_revision:z.number().int().min(0).max(2147483647),
 created_by:z.uuid(),created_at:z.iso.datetime({offset:true}),previous_version_id:z.uuid().nullable(),
 approved_by:z.uuid().nullable(),approved_at:z.iso.datetime({offset:true}).nullable(),approval_note:z.string().nullable(),
}).refine(v=>v.previous_version_id!==v.id,{message:"Version cannot reference itself"})
 .refine(v=>(v.approved_by===null)===(v.approved_at===null),{message:"Approval identity/time must be paired"})
 .refine(v=>!["APPROVED","CURRENT"].includes(v.status)||(v.approved_by!==null&&v.approved_at!==null),{message:"Approved/current Version requires approval identity/time"});
export type ArtifactVersion=z.infer<typeof artifactVersionSchema>;
