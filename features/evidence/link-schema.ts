import {z} from "zod";
export const evidenceLinkEntityTypeSchema=z.enum(["DECISION","REQUIREMENT","GAP","ARTIFACT","PATENT_RECORD"]);
export const evidenceRelationshipTypeSchema=z.enum(["SUPPORTS","CONTRADICTS","VALIDATES","SOURCE_FOR","RELATED_TO"]);
export const linkEvidenceSchema=z.strictObject({evidenceId:z.uuid(),entityType:evidenceLinkEntityTypeSchema,entityId:z.uuid(),relationshipType:evidenceRelationshipTypeSchema,notes:z.string().optional()});
export const evidenceLinkSchema=z.strictObject({id:z.uuid(),evidence_id:z.uuid(),linked_entity_type:evidenceLinkEntityTypeSchema,linked_entity_id:z.uuid(),relationship_type:evidenceRelationshipTypeSchema,notes:z.string().nullable(),created_by:z.uuid(),created_at:z.iso.datetime({offset:true}),archived_at:z.iso.datetime({offset:true}).nullable()});
export type LinkEvidenceInput=z.infer<typeof linkEvidenceSchema>;
export type EvidenceLink=z.infer<typeof evidenceLinkSchema>;
