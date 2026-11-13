import {z} from "zod";
import {artifactSchema} from "@/features/artifacts/schema";
import {artifactVersionSchema} from "@/features/artifacts/version-schema";
export const composeSolutionBankSchema=z.strictObject({activityInstanceId:z.uuid().transform(v=>v.toLowerCase()),solutionIds:z.array(z.uuid().transform(v=>v.toLowerCase())).min(1).refine(v=>new Set(v).size===v.length,{message:"Duplicate Solutions"}),title:z.string().trim().min(1).optional()});
export const composedSolutionBankSchema=z.strictObject({artifact:artifactSchema,version:artifactVersionSchema});
export type ComposedSolutionBank=z.infer<typeof composedSolutionBankSchema>;
