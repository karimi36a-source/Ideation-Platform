import {z} from "zod";
import {productClassificationSchema} from "@/features/mind-map/classification-schema";
export const developmentObjectTypeSchema=z.enum(["PROBLEM", "IDEA", "SOLUTION", "FEATURE", "FUNCTION", "COMPONENT", "SYSTEM", "SUBSYSTEM", "GAP", "OPEN_QUESTION", "REQUIREMENT", "RISK"]);
const descriptive=z.string().refine(v=>v.trim().length>0).nullable();
export const developmentObjectSchema=z.object({
 id:z.uuid(),project_id:z.uuid(),workspace_id:z.uuid(),object_type:developmentObjectTypeSchema,
 title:z.string().refine(v=>v.trim().length>0),content:z.string(),status:descriptive,verification_status:descriptive,origin_type:descriptive,
 origin_reference_id:z.uuid().nullable(),created_by:z.uuid(),current_version_number:z.number().int().min(1),archived_at:z.iso.datetime({offset:true}).nullable(),
 product_classification:productClassificationSchema.nullable().optional(),classification_revision:z.number().int().min(0).max(Number.MAX_SAFE_INTEGER).optional(),
 metadata:z.record(z.string(),z.unknown()),created_at:z.iso.datetime({offset:true}),updated_at:z.iso.datetime({offset:true}),
});
export type DevelopmentObject=z.infer<typeof developmentObjectSchema>;
