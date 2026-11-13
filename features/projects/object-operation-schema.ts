import {z} from "zod";
import {developmentObjectTypeSchema} from "./object-schema";
const title=z.string().refine(v=>v.trim().length>0);
export const createDevelopmentObjectSchema=z.strictObject({projectId:z.uuid(),workspaceId:z.uuid(),objectType:developmentObjectTypeSchema,title,content:z.string(),originType:title.nullable(),metadata:z.record(z.string(),z.unknown()).optional()});
export const updateDevelopmentObjectSchema=z.strictObject({objectId:z.uuid(),title:title.optional(),content:z.string().optional(),metadata:z.record(z.string(),z.unknown()).optional()}).refine(v=>v.title!==undefined||v.content!==undefined||v.metadata!==undefined);
