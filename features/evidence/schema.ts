import { z } from "zod";

// Controlled storage vocabularies. Neither type nor verification state grants access.
export const evidenceTypeSchema = z.enum([
  "PATENT", "PATENT_CLAIM", "STANDARD", "DATASHEET", "PAPER", "CALCULATION",
  "MEASUREMENT", "TEST_RESULT", "CUSTOMER_INTERVIEW", "MARKET_SOURCE",
  "SECONDARY_SOURCE", "OTHER",
]);

export const evidenceVerificationStatusSchema = z.enum([
  "UNVERIFIED", "PARTIALLY_VERIFIED", "VERIFIED", "CONTRADICTED", "NEEDS_REVIEW",
]);

export type EvidenceType = z.infer<typeof evidenceTypeSchema>;
export type EvidenceVerificationStatus = z.infer<typeof evidenceVerificationStatusSchema>;

const text = z.string().refine(value => value.trim().length > 0);
const timestamp = z.iso.datetime({ offset: true });
const sourceUrl = z.string().refine(value => /^https?:\/\/[^/\s?#]+([/?#][^\s]*)?$/i.test(value));

// Storage shape only: parsing a row grants no creation or verification authority.
export const evidenceSchema = z.strictObject({
  id: z.uuid(), project_id: z.uuid(), workspace_id: z.uuid(),
  evidence_type: evidenceTypeSchema, title: text, description: text, source_name: text,
  claim_locator: text.nullable(),
  source_url: sourceUrl.nullable(), file_id: z.uuid().nullable(),
  verification_status: evidenceVerificationStatusSchema,
  verified_by: z.uuid().nullable(), verified_at: timestamp.nullable(),
  created_by: z.uuid(), captured_at: timestamp,
  metadata: z.record(z.string(), z.json()),
  created_at: timestamp, updated_at: timestamp, updated_by: z.uuid(),
  archived_at: timestamp.nullable(),
}).refine(row=>row.evidence_type==='PATENT_CLAIM'?row.claim_locator!==null:row.evidence_type!=='PATENT'||row.claim_locator===null,{message:'Invalid claim locator'})
 .refine(row => row.verification_status !== "UNVERIFIED" ||
  (row.verified_by === null && row.verified_at === null), { message: "UNVERIFIED has no verifier or verification time" })
  .refine(row => Date.parse(row.updated_at) >= Date.parse(row.created_at), { message: "Invalid update time" })
  .refine(row => row.archived_at === null || Date.parse(row.archived_at) >= Date.parse(row.captured_at), { message: "Invalid archive time" });

export type Evidence = z.infer<typeof evidenceSchema>;
