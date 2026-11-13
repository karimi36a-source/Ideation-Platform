import {z} from "zod";
import {mindMapSchema} from "./schema";
import {artifactVersionSchema} from "@/features/artifacts/version-schema";
export const createMindMapVersionSchema=z.strictObject({mindMapId:z.uuid(),expectedDraftRevision:z.number().int().min(0).max(2147483647),changeSummary:z.string().nullable()});
export const createdMindMapVersionSchema=z.strictObject({mindMap:mindMapSchema,version:artifactVersionSchema});
export type CreateMindMapVersionInput=z.infer<typeof createMindMapVersionSchema>;
export type CreatedMindMapVersion=z.infer<typeof createdMindMapVersionSchema>;
