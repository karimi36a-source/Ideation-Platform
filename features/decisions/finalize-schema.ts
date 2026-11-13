import {z} from "zod";
const uuid=z.uuid().transform(v=>v.toLowerCase());
const ids=z.array(uuid).refine(v=>new Set(v).size===v.length);
export const finalizeDecisionSchema=z.strictObject({decisionId:uuid,selectedOptionId:uuid.optional(),outcome:z.string().trim().min(1),reasoning:z.string().trim().min(1),linkedEvidenceIds:z.array(uuid).optional(),linkedArtifactIds:ids.optional(),linkedObjectIds:ids.optional()});
export type FinalizeDecisionInput=z.infer<typeof finalizeDecisionSchema>;
