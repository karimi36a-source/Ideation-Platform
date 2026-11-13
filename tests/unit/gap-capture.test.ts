import { beforeEach, describe, expect, it, vi } from "vitest";
import { captureGapSchema } from "@/features/affinity/gap-schema";
const id = "00000000-0000-4000-8000-000000000001";
const input = { activityInstanceId: id, mode: "CREATE_NEW", newGap: { title: "Missing function" }, idempotencyKey: "capture-1" };
const auth = vi.hoisted(() => vi.fn());
const rpc = vi.hoisted(() => vi.fn());
vi.mock("server-only", () => ({}));
vi.mock("@/lib/auth/authorization", async original => ({ ...await original<object>(), getAuthorizationContext: auth }));
vi.mock("@/lib/db/server", () => ({ createServerSupabaseClient: async () => ({ rpc }) }));
import { captureGap, GapCaptureConflictError } from "@/features/affinity/gaps";

describe("human-driven canonical Gap capture", () => {
 beforeEach(() => { vi.resetAllMocks(); auth.mockResolvedValue({ userId: id, assignments: [] }); });
 it("requires an explicit mode and bounded nonblank key", () => {
  expect(captureGapSchema.safeParse(input).success).toBe(true);
  for (const change of [{ mode: undefined }, { mode: "AUTOMATIC" }, { idempotencyKey: " " }, { idempotencyKey: "x".repeat(201) }]) expect(captureGapSchema.safeParse({ ...input, ...change }).success).toBe(false);
 });
 it("keeps new and existing Gap contracts exclusive", () => {
  expect(captureGapSchema.safeParse({ ...input, gapObjectId: id }).success).toBe(false);
  expect(captureGapSchema.safeParse({ ...input, mode: "ADD_EXISTING", gapObjectId: id }).success).toBe(false);
  expect(captureGapSchema.safeParse({ activityInstanceId: id, mode: "ADD_EXISTING", gapObjectId: id, idempotencyKey: "reuse" }).success).toBe(true);
 });
 it("normalizes titles and rejects unsupported Object/lifecycle metadata", () => {
  const parsed = captureGapSchema.parse({ ...input, newGap: { title: "  Human Gap  " } });
  expect(parsed.mode === "CREATE_NEW" && parsed.newGap.title).toBe("Human Gap");
  for (const newGap of [{ title: " " }, { title: "x".repeat(201) }, { title: "G", content: "x".repeat(100001) }, { title: "G", objectType: "IDEA" }, { title: "G", createdBy: id }, { title: "G", origin_type: "USER" }]) expect(captureGapSchema.safeParse({ ...input, newGap }).success).toBe(false);
 });
 it.each(["actor", "createdBy", "creator", "projectId", "workspaceId", "teamId", "artifactId", "artifactVersionId", "status", "baselineId", "approvalState"])("rejects %s before database execution", async key => {
  await expect(captureGap({ ...input, [key]: id })).rejects.toMatchObject({ code: "VALIDATION_ERROR" }); expect(rpc).not.toHaveBeenCalled();
 });
 it("uses only explicit approved relationship requests", () => {
  expect(captureGapSchema.safeParse({ ...input, relationships: [{ sourceObjectId: "CONFIRMED_OBJECT", targetObjectId: id, relationshipType: "IDENTIFIED_IN" }] }).success).toBe(true);
  for (const edge of [{ sourceObjectId: "GROUP", targetObjectId: id, relationshipType: "BELONGS_TO" }, { sourceObjectId: id, targetObjectId: id, relationshipType: "INFERRED" }, { sourceObjectId: id, targetObjectId: id, relationshipType: "DEPENDS_ON", createdBy: id }]) expect(captureGapSchema.safeParse({ ...input, relationships: [edge] }).success).toBe(false);
 });
 it("maps duplicate/conflicting intent without disclosing payload", async () => {
  rpc.mockResolvedValue({ error: { code: "23505", message: "Private payload" } });
  await expect(captureGap(input)).rejects.toBeInstanceOf(GapCaptureConflictError);
 });
 it("does not disclose inaccessible IDs or unexpected transport details", async () => {
  rpc.mockResolvedValueOnce({ error: { code: "42501", message: "Private Gap name" } }).mockRejectedValueOnce(new Error("Private backend"));
  for (let i = 0; i < 2; i++) await expect(captureGap(input)).rejects.toMatchObject({ code: "NOT_FOUND", message: "Resource unavailable." });
 });
 it("requires a verified session before parsing or executing", async () => {
  const { AuthorizationError } = await import("@/lib/auth/authorization");
  auth.mockRejectedValue(new AuthorizationError("AUTH_REQUIRED"));
  await expect(captureGap(input)).rejects.toMatchObject({ code: "AUTH_REQUIRED" }); expect(rpc).not.toHaveBeenCalled();
 });
 it("rechecks identity before and after the transaction", async () => {
  auth.mockResolvedValueOnce({ userId: id }).mockResolvedValueOnce({ userId: "00000000-0000-4000-8000-000000000002" });
  await expect(captureGap(input)).rejects.toMatchObject({ code: "NOT_FOUND" }); expect(rpc).not.toHaveBeenCalled();
  auth.mockResolvedValueOnce({ userId: id }).mockResolvedValueOnce({ userId: id }).mockResolvedValueOnce({ userId: "00000000-0000-4000-8000-000000000002" });
  rpc.mockResolvedValue({ data: {}, error: null });
  await expect(captureGap(input)).rejects.toMatchObject({ code: "NOT_FOUND" }); expect(rpc).toHaveBeenCalledTimes(1);
 });
});
