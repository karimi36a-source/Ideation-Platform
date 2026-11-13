import { describe, expect, it } from "vitest";
import { shareSchema, shareEntityTypes } from "@/features/shares/schema";

const id = "00000000-0000-4000-8000-000000000001";
const row = { id, source_workspace_id: id, shared_entity_type: "ARTIFACT", shared_entity_id: id, shared_by: id,
  destination_type: "TEAM", destination_id: id, permission_level: "VIEW", share_mode: "SNAPSHOT",
  created_at: "2026-10-29T00:00:00Z", revoked_at: null, revoked_by: null };
describe("M13.1 persisted Share contract", () => {
  it.each(shareEntityTypes)("accepts canonical entity %s", shared_entity_type => {
    expect(shareSchema.safeParse({ ...row, shared_entity_type }).success).toBe(true);
  });
  it("rejects unsupported entities, payloads and partial revocation", () => {
    for (const change of [{ shared_entity_type: "MIND_MAP" }, { shared_entity_type: "SEARCH_LOG" },
      { payload: {} }, { revoked_by: id }, { revoked_at: "2026-10-28T00:00:00Z", revoked_by: id }]) {
      expect(shareSchema.safeParse({ ...row, ...change }).success).toBe(false);
    }
  });
});
