import {z} from "zod";
export const createArtifactVersionSchema=z.strictObject({artifactId:z.uuid(),contentSnapshot:z.json(),changeSummary:z.string().nullable(),sourceDecisionIds:z.array(z.uuid()).optional(),sourceEvidenceIds:z.array(z.uuid()).optional(),sourceAiOutputIds:z.array(z.uuid()).optional()});
