import {z} from "zod";

import {productClassificationSchema} from "./classification-schema";
// Storage contracts only; these schemas do not establish write authority.
const text=z.string().refine(v=>v.trim().length>=1&&v.trim().length<=200);
const object=z.record(z.string(),z.json());
export const mindMapSchema=z.strictObject({id:z.uuid(),artifact_id:z.uuid(),artifact_version_id:z.uuid(),root_node_id:z.uuid().nullable()});
export const mindMapNodeSchema=z.strictObject({id:z.uuid(),mind_map_id:z.uuid(),node_type:text,label:text,development_object_id:z.uuid().nullable(),parent_node_id:z.uuid().nullable(),position_data:object,metadata:object,created_by:z.uuid(),product_classification:productClassificationSchema.nullable().optional(),edit_revision:z.number().int().min(0).max(Number.MAX_SAFE_INTEGER)}).refine(v=>v.parent_node_id!==v.id);
export const mindMapEdgeSchema=z.strictObject({id:z.uuid(),mind_map_id:z.uuid(),source_node_id:z.uuid(),target_node_id:z.uuid(),edge_type:z.enum(["HIERARCHY","CROSS_CONNECTION"]),label:text.nullable(),metadata:object,edit_revision:z.number().int().min(0).max(Number.MAX_SAFE_INTEGER)});
export type MindMap=z.infer<typeof mindMapSchema>;
export type MindMapNode=z.infer<typeof mindMapNodeSchema>;
export type MindMapEdge=z.infer<typeof mindMapEdgeSchema>;
