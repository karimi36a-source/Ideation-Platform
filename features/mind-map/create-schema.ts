import {z} from "zod";
import {artifactSchema} from "@/features/artifacts/schema";
import {artifactVersionSchema} from "@/features/artifacts/version-schema";
import {mindMapSchema,mindMapNodeSchema} from "./schema";
export const createMindMapSchema=z.strictObject({activityInstanceId:z.uuid().transform(v=>v.toLowerCase()),idempotencyKey:z.string().trim().min(1).max(200)});
export const createdMindMapSchema=z.strictObject({artifact:artifactSchema,version:artifactVersionSchema,mindMap:mindMapSchema,rootNode:mindMapNodeSchema,activityOutputId:z.uuid().nullable(),replayed:z.boolean()});
export type CreatedMindMap=z.infer<typeof createdMindMapSchema>;
