import {z} from "zod";
import {artifactSchema} from "@/features/artifacts/schema";
import {artifactVersionSchema} from "@/features/artifacts/version-schema";
const uuid=z.uuid().transform(v=>v.toLowerCase());
export const finalizeSession7OutputsSchema=z.strictObject({
 activityInstanceId:uuid,mindMapId:uuid,expectedDraftRevision:z.number().int().min(0).max(2147483647),
 changeSummary:z.string().nullable().optional(),idempotencyKey:z.string().trim().min(1).max(200),
});
const output=z.strictObject({artifact:artifactSchema,version:artifactVersionSchema,activityOutputId:z.uuid()})
 .refine(x=>x.version.artifact_id===x.artifact.id,{message:"Invalid output binding"});
export const finalizedSession7OutputsSchema=z.strictObject({
 mindMapId:z.uuid(),successorMindMapId:z.uuid(),sourceDraftRevision:z.number().int().min(0).max(2147483647),
 mindMap:output,essentialStructure:output,inventionConcept:output,replayed:z.boolean(),
}).refine(x=>x.mindMapId!==x.successorMindMapId
 &&x.mindMap.artifact.artifact_type==="MIND_MAP"
 &&x.essentialStructure.artifact.artifact_type==="MINIMUM_ESSENTIAL_STRUCTURE"
 &&x.inventionConcept.artifact.artifact_type==="INVENTION_CONCEPT"
 &&new Set([x.mindMap,x.essentialStructure,x.inventionConcept].map(o=>o.artifact.id)).size===3
 &&new Set([x.mindMap,x.essentialStructure,x.inventionConcept].map(o=>o.activityOutputId)).size===3
 &&[x.essentialStructure,x.inventionConcept].every(o=>o.artifact.project_id===x.mindMap.artifact.project_id
 &&o.artifact.workspace_id===x.mindMap.artifact.workspace_id&&o.artifact.activity_instance_id===x.mindMap.artifact.activity_instance_id),{message:"Inconsistent composition"});
export type FinalizeSession7OutputsInput=z.infer<typeof finalizeSession7OutputsSchema>;
export type FinalizedSession7Outputs=z.infer<typeof finalizedSession7OutputsSchema>;
