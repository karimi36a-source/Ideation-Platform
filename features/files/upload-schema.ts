import {z} from "zod";
export const MAX_UPLOAD_BYTES=26_214_400;
export const UPLOAD_MIME_TYPES=["application/pdf","image/jpeg","image/png","image/webp","text/plain","text/csv","application/vnd.openxmlformats-officedocument.wordprocessingml.document","application/vnd.openxmlformats-officedocument.spreadsheetml.sheet","application/vnd.openxmlformats-officedocument.presentationml.presentation"] as const;
export const uploadFilenameSchema=z.string().min(1).refine(v=>v===v.trim()&&v===v.normalize("NFKC")&&!/[\\/\x00-\x1f\x7f-\x9f\u202a-\u202e\u2066-\u2069]/.test(v)&&v!=="."&&v!==".."&&!/[. ]$/.test(v),"Unsafe filename");
export const requestUploadSchema=z.strictObject({workspaceId:z.uuid(),projectId:z.uuid().optional(),filename:uploadFilenameSchema,mimeType:z.enum(UPLOAD_MIME_TYPES),size:z.number().int().min(1).max(MAX_UPLOAD_BYTES)});
export const registerUploadedFileSchema=z.strictObject({uploadRequestId:z.uuid()});
export const uploadRequestSchema=z.strictObject({id:z.uuid(),file_id:z.uuid(),requested_by:z.uuid(),workspace_id:z.uuid(),project_id:z.uuid().nullable(),storage_reference:z.string(),filename:uploadFilenameSchema,mime_type:z.enum(UPLOAD_MIME_TYPES),expected_size:z.number().int().min(1).max(MAX_UPLOAD_BYTES),created_at:z.iso.datetime({offset:true}),expires_at:z.iso.datetime({offset:true}),registered_at:z.iso.datetime({offset:true}).nullable()}).refine(v=>v.storage_reference===`workspaces/${v.workspace_id}/files/${v.file_id}`);
export type UploadRequest=z.infer<typeof uploadRequestSchema>;
