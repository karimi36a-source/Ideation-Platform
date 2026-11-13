import {z} from "zod";
export const PRIVATE_FILE_BUCKET="fici-private-files";
export const fileStatusSchema=z.enum(["active","archived"]);
export const fileLinkEntityTypeSchema=z.enum(["EVIDENCE","ARTIFACT","ACTIVITY_INSTANCE","CHAT_MESSAGE","DEVELOPMENT_OBJECT"]);
export const fileRelationshipTypeSchema=z.enum(["ATTACHMENT","EVIDENCE_SOURCE","ARTIFACT_FILE","CHAT_ATTACHMENT","REFERENCE"]);
const timestamp=z.iso.datetime({offset:true});
// Persistence contract only. No upload, registration, linking or signed-access API.
export const fileSchema=z.strictObject({
 id:z.uuid(),uploaded_by:z.uuid(),workspace_id:z.uuid(),project_id:z.uuid().nullable(),
 storage_reference:z.string(),filename:z.string().refine(v=>v.trim().length>0&&!/[\\/\x00-\x1f\x7f]/.test(v)&&v!=="."&&v!==".."),
 mime_type:z.string().regex(/^[A-Za-z0-9][A-Za-z0-9!#$&^_.+-]*\/[A-Za-z0-9][A-Za-z0-9!#$&^_.+-]*$/).refine(v=>!/\s/.test(v)),
 size:z.number().int().min(0).max(Number.MAX_SAFE_INTEGER),status:fileStatusSchema,
 created_at:timestamp,updated_at:timestamp,updated_by:z.uuid(),archived_at:timestamp.nullable(),
}).refine(v=>v.storage_reference===`workspaces/${v.workspace_id}/files/${v.id}`,"Storage reference must match canonical identity")
 .refine(v=>v.status==="active"?v.archived_at===null:v.archived_at!==null,"Archive state mismatch")
 .refine(v=>Date.parse(v.updated_at)>=Date.parse(v.created_at),"Invalid update time")
 .refine(v=>v.archived_at===null||Date.parse(v.archived_at)>=Date.parse(v.created_at),"Invalid archive time");
export const fileLinkSchema=z.strictObject({id:z.uuid(),file_id:z.uuid(),entity_type:fileLinkEntityTypeSchema,entity_id:z.uuid(),relationship_type:fileRelationshipTypeSchema,created_by:z.uuid(),created_at:timestamp,archived_at:timestamp.nullable()})
 .refine(v=>v.archived_at===null||Date.parse(v.archived_at)>=Date.parse(v.created_at),"Invalid archive time");
export type FileRecord=z.infer<typeof fileSchema>;
export type FileLink=z.infer<typeof fileLinkSchema>;
