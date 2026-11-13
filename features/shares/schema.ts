import { z } from "zod";

export const shareEntityTypes = ["ARTIFACT", "DEVELOPMENT_OBJECT", "FILE", "EVIDENCE", "PATENT_RECORD", "SCAMPER_ENTRY"] as const;
export const shareDestinationTypes = ["USER", "TEAM", "MASTER", "COHORT", "WORKSPACE"] as const;
export const sharePermissionLevels = ["VIEW", "COMMENT", "COLLABORATE"] as const;
export const shareModes = ["LIVE_REFERENCE", "SNAPSHOT"] as const;

// Persisted row contract only; there is deliberately no public create contract.
export const shareSchema = z.object({
  id: z.uuid(), source_workspace_id: z.uuid(), shared_entity_type: z.enum(shareEntityTypes),
  shared_entity_id: z.uuid(), shared_by: z.uuid(), destination_type: z.enum(shareDestinationTypes),
  destination_id: z.uuid(), permission_level: z.enum(sharePermissionLevels), share_mode: z.enum(shareModes),
  created_at: z.iso.datetime({ offset: true }), revoked_at: z.iso.datetime({ offset: true }).nullable(), revoked_by: z.uuid().nullable(),
}).strict().refine(row => (row.revoked_at === null) === (row.revoked_by === null), "Revocation fields must be paired")
  .refine(row => row.revoked_at === null || Date.parse(row.revoked_at) >= Date.parse(row.created_at), "Revocation cannot precede creation");
export type Share = z.infer<typeof shareSchema>;
