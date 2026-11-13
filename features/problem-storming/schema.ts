import {z} from "zod";
import {developmentObjectSchema} from "@/features/projects/object-schema";
import {problemDetailsSchema} from "@/features/projects/typed-detail-schema";
export const problemStormingCategorySchema=z.enum(["user","functional","technical","cost","safety","environmental","accessibility","maintenance"]);
export const createProblemStormingProblemSchema=z.strictObject({activityInstanceId:z.uuid().transform(v=>v.toLowerCase()),content:z.string(),problemCategory:problemStormingCategorySchema,perspective:z.string().refine(v=>v.trim().length>0).optional()});
export const problemStormingProblemSchema=developmentObjectSchema.extend({problem_details:problemDetailsSchema});
export type ProblemStormingProblem=z.infer<typeof problemStormingProblemSchema>;
