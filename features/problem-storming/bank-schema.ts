import {z} from "zod";
import {artifactSchema} from "@/features/artifacts/schema";
import {artifactVersionSchema} from "@/features/artifacts/version-schema";
export const composeProblemBankSchema=z.strictObject({activityInstanceId:z.uuid().transform(v=>v.toLowerCase()),problemIds:z.array(z.uuid().transform(v=>v.toLowerCase())).min(1).refine(v=>new Set(v).size===v.length,{message:"Duplicate Problems"}),title:z.string().trim().min(1).optional()});
export const composedProblemBankSchema=z.strictObject({artifact:artifactSchema,version:artifactVersionSchema});
export type ComposedProblemBank=z.infer<typeof composedProblemBankSchema>;
