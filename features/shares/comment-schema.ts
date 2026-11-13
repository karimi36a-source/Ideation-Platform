import {z} from 'zod';
import {shareEntityTypes} from './schema';
export const addSharedCommentSchema=z.strictObject({shareId:z.uuid().transform(id=>id.toLowerCase()),content:z.string().trim().min(1)});
export const sharedCommentThreadSchema=z.strictObject({shareId:z.uuid().transform(id=>id.toLowerCase())});
export const sharedCommentSchema=z.strictObject({id:z.uuid(),share_id:z.uuid(),target_entity_type:z.enum(shareEntityTypes),target_entity_id:z.uuid(),target_version_id:z.uuid().nullable(),author_user_id:z.uuid(),content:z.string().min(1).refine(s=>s===s.trim()),created_at:z.iso.datetime({offset:true})}).refine(r=>(r.target_entity_type==='ARTIFACT')===(r.target_version_id!==null));
export type SharedComment=z.infer<typeof sharedCommentSchema>;
