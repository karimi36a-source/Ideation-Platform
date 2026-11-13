import {z} from "zod";
export const linkDecisionEntitySchema=z.strictObject({decisionId:z.uuid(),linkedEntityType:z.enum(["VOTING_SESSION","ARTIFACT","DEVELOPMENT_OBJECT","EVIDENCE","AI_OUTPUT"]),linkedEntityId:z.uuid(),relationshipType:z.enum(["INFORMED_BY","CONSIDERED_IN_DECISION"])}).refine(v=>v.linkedEntityType==="VOTING_SESSION"?v.relationshipType==="INFORMED_BY":v.relationshipType==="CONSIDERED_IN_DECISION");
export type LinkDecisionEntityInput=z.infer<typeof linkDecisionEntitySchema>;
