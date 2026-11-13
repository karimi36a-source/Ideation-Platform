import { expect, it } from "vitest";
import {
  evidenceTypeSchema,
  evidenceVerificationStatusSchema,
  evidenceSchema,
} from "@/features/evidence/schema";

it.each([
  "PATENT", "PATENT_CLAIM", "STANDARD", "DATASHEET", "PAPER", "CALCULATION",
  "MEASUREMENT", "TEST_RESULT", "CUSTOMER_INTERVIEW", "MARKET_SOURCE",
  "SECONDARY_SOURCE", "OTHER",
])("accepts the approved Evidence type %s", (type) => {
  expect(evidenceTypeSchema.parse(type)).toBe(type);
});

const id = "00000000-0000-4000-8000-000000006004";
const time = "2026-10-21T00:00:00Z";
const row = { id, project_id: id, workspace_id: id, evidence_type: "CUSTOMER_INTERVIEW",
  title: "Recorded interview", description: "Interview notes captured by the Team",
  source_name: "Interview with participant P1, 2026-10-21", source_url: null, file_id: null, claim_locator: null,
  verification_status: "UNVERIFIED", verified_by: null, verified_at: null,
  created_by: id, captured_at: time, metadata: {}, created_at: time,
  updated_at: time, updated_by: id, archived_at: null };

it("accepts a named offline source without inventing a URL or file", () => {
  expect(evidenceSchema.parse(row)).toEqual(row);
});
it("requires explicit typed source identity", () => {
  expect(evidenceSchema.safeParse({ ...row, source_name: "  ", metadata: { source_name: "Hidden source" } }).success).toBe(false);
  expect(evidenceSchema.safeParse({ ...row, metadata: [] }).success).toBe(false);
});
it.each(["https://example.test/paper?id=1#section", "http://example.test/source"])("accepts external source reference %s", url => {
  expect(evidenceSchema.parse({ ...row, source_url: url }).source_url).toBe(url);
});
it.each(["", "javascript:alert(1)", "file:///private/file", "https://", "https://example.test/a b"])("rejects malformed/non-HTTP source URL %s", url => {
  expect(evidenceSchema.safeParse({ ...row, source_url: url }).success).toBe(false);
});
it("enforces only the approved UNVERIFIED implication", () => {
  expect(evidenceSchema.safeParse({ ...row, verified_by: id }).success).toBe(false);
  expect(evidenceSchema.safeParse({ ...row, verified_at: time }).success).toBe(false);
  for (const status of evidenceVerificationStatusSchema.options.filter(s => s !== "UNVERIFIED")) {
    expect(evidenceSchema.parse({ ...row, verification_status: status }).verification_status).toBe(status);
    expect(evidenceSchema.parse({ ...row, verification_status: status, verified_by: id }).verified_at).toBeNull();
  }
});
it("keeps capture, verification and archive timestamps separate", () => {
  expect(evidenceSchema.parse({ ...row, verification_status: "NEEDS_REVIEW", verified_at: "2026-10-22T00:00:00Z" }).captured_at).toBe(time);
  expect(evidenceSchema.safeParse({ ...row, archived_at: "2026-10-20T00:00:00Z" }).success).toBe(false);
  expect(evidenceSchema.parse({ ...row, archived_at: time }).created_by).toBe(id);
});

it("keeps Evidence types separate from analysis and conclusions", () => {
  for (const type of ["AI_ANALYSIS", "DECISION", "PATENTABILITY", "CUSTOM"])
    expect(evidenceTypeSchema.safeParse(type).success).toBe(false);
});

it("supports exactly the approved verification states", () => {
  expect(evidenceVerificationStatusSchema.options).toEqual([
    "UNVERIFIED", "PARTIALLY_VERIFIED", "VERIFIED", "CONTRADICTED", "NEEDS_REVIEW",
  ]);
  for (const status of ["APPROVED", "CURRENT", "active", "ARCHIVED"])
    expect(evidenceVerificationStatusSchema.safeParse(status).success).toBe(false);
});
