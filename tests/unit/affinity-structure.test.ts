import { describe, it, expect, vi, beforeEach } from "vitest";
import { confirmAffinityStructureSchema } from "@/features/affinity/structure-schema";
const id = "00000000-0000-4000-8000-000000000001";
const input = { activityInstanceId: id, affinityGroupId: id, mode: "LINK_EXISTING", targetObjectId: id, idempotencyKey: "confirmation-1" };
const auth = vi.hoisted(() => vi.fn());
const rpc = vi.hoisted(() => vi.fn());
vi.mock("server-only", () => ({}));
vi.mock("@/lib/auth/authorization", async original => ({ ...await original<object>(), getAuthorizationContext: auth }));
vi.mock("@/lib/db/server", () => ({ createServerSupabaseClient: async () => ({ rpc }) }));
import { confirmAffinityStructure, AffinityStructureConflictError } from "@/features/affinity/structure";

describe("explicit Affinity structural confirmation", () => {
 beforeEach(() => { vi.clearAllMocks(); auth.mockResolvedValue({ userId: id, assignments: [] }); });
 it("requires explicit mode and bounded idempotency key", () => {
  expect(confirmAffinityStructureSchema.safeParse(input).success).toBe(true);
  for (const change of [{ mode: undefined }, { idempotencyKey: " " }, { idempotencyKey: "x".repeat(201) }]) expect(confirmAffinityStructureSchema.safeParse({ ...input, ...change }).success).toBe(false);
 });
 it("keeps link/create contracts mutually exclusive", () => {
  expect(confirmAffinityStructureSchema.safeParse({ ...input, newObject: { objectType: "SYSTEM", title: "System" } }).success).toBe(false);
  const { targetObjectId: _, ...rest } = input; void _;
  for (const objectType of ["SYSTEM", "SUBSYSTEM", "COMPONENT", "FUNCTION", "GAP"]) expect(confirmAffinityStructureSchema.safeParse({ ...rest, mode: "CREATE_NEW", newObject: { objectType, title: " Structure " } }).success).toBe(true);
  for (const objectType of ["IDEA", "PROBLEM", "CUSTOM"]) expect(confirmAffinityStructureSchema.safeParse({ ...rest, mode: "CREATE_NEW", newObject: { objectType, title: "Structure" } }).success).toBe(false);
 });
 it.each(["actor", "createdBy", "projectId", "workspaceId", "teamId", "status", "baselineId", "approvalStatus"])("rejects %s claims before database execution", async key => {
  await expect(confirmAffinityStructure({ ...input, [key]: id })).rejects.toMatchObject({ code: "VALIDATION_ERROR" }); expect(rpc).not.toHaveBeenCalled();
 });
 it("accepts explicit local relationship reference only", () => {
  expect(confirmAffinityStructureSchema.safeParse({ ...input, relationships: [{ sourceObjectId: "CONFIRMED_OBJECT", targetObjectId: id, relationshipType: "BELONGS_TO" }] }).success).toBe(true);
  expect(confirmAffinityStructureSchema.safeParse({ ...input, relationships: [{ sourceObjectId: "GROUP", targetObjectId: id, relationshipType: "CUSTOM" }] }).success).toBe(false);
 });
 it("maps conflicts without source details", async () => {
  rpc.mockResolvedValue({ error: { code: "23505", message: "private payload" } });
  await expect(confirmAffinityStructure(input)).rejects.toBeInstanceOf(AffinityStructureConflictError);
 });
 it("maps inaccessible resources to safe denial", async () => {
  rpc.mockResolvedValue({ error: { code: "42501", message: "secret group name" } });
  await expect(confirmAffinityStructure(input)).rejects.toMatchObject({ code: "NOT_FOUND", message: "Resource unavailable." });
 });
 it("sanitizes unexpected transport failures", async () => {
  rpc.mockRejectedValue(new Error("private backend payload"));
  await expect(confirmAffinityStructure(input)).rejects.toMatchObject({ code: "NOT_FOUND", message: "Resource unavailable." });
 });
 it("rechecks verified actor before invoking transaction", async () => {
  auth.mockResolvedValueOnce({ userId: id }).mockResolvedValueOnce({ userId: "00000000-0000-4000-8000-000000000002" });
  await expect(confirmAffinityStructure(input)).rejects.toMatchObject({ code: "NOT_FOUND" }); expect(rpc).not.toHaveBeenCalled();
 });
});
