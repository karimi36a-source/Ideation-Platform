import {z} from "zod";
export const decisionStatusSchema=z.enum(["DRAFT","FINALIZED","SUPERSEDED","ARCHIVED"]);
export const decisionMethodSchema=z.enum(["DOT_VOTE","DISCUSSION","CONSENSUS","OTHER"]);
export const decisionLinkEntityTypeSchema=z.enum(["VOTING_SESSION","ARTIFACT","DEVELOPMENT_OBJECT","EVIDENCE","AI_OUTPUT","DECISION"]);
const nonblank=z.string().refine(value=>value.trim().length>0);
/** Stored structures only; contextual role and links never confer authority. */
export const decisionSchema=z.strictObject({id:z.uuid(),project_id:z.uuid(),workspace_id:z.uuid(),activity_instance_id:z.uuid().nullable(),title:nonblank,question:nonblank,method:decisionMethodSchema,outcome:z.string().nullable(),reasoning:z.string().nullable(),status:decisionStatusSchema,decision_owner_user_id:z.uuid(),decided_at:z.iso.datetime({offset:true}).nullable()});
export const decisionOptionSchema=z.strictObject({id:z.uuid(),decision_id:z.uuid(),label:nonblank,description:z.string().nullable(),selected:z.boolean(),development_object_id:z.uuid().nullable()});
export const decisionParticipantSchema=z.strictObject({id:z.uuid(),decision_id:z.uuid(),user_id:z.uuid(),role:nonblank,position:z.string().nullable(),comment:z.string().nullable()});
export const decisionLinkSchema=z.strictObject({id:z.uuid(),decision_id:z.uuid(),linked_entity_type:decisionLinkEntityTypeSchema,linked_entity_id:z.uuid(),relationship_type:nonblank});
export type Decision=z.infer<typeof decisionSchema>;
export type DecisionOption=z.infer<typeof decisionOptionSchema>;
export type DecisionParticipant=z.infer<typeof decisionParticipantSchema>;
export type DecisionLink=z.infer<typeof decisionLinkSchema>;
