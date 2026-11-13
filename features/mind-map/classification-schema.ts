import {z} from "zod";
export const productClassifications=["CORE","SUPPORTING","OPTIONAL_FUTURE"] as const;
export const productClassificationSchema=z.enum(productClassifications);
const revision=z.number().int().min(0).max(Number.MAX_SAFE_INTEGER);
export const classifyMindMapNodeSchema=z.strictObject({nodeId:z.uuid().transform(value=>value.toLowerCase()),expectedRevision:revision,expectedObjectRevision:revision.nullable(),classification:productClassificationSchema.nullable()});
export type ClassifyMindMapNodeInput=z.infer<typeof classifyMindMapNodeSchema>;
