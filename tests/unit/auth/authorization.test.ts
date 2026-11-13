import { beforeEach, afterEach, expect, it, vi } from "vitest";
vi.mock("server-only", () => ({}));
const { user, assignments } = vi.hoisted(() => ({ user: vi.fn(), assignments: vi.fn() }));
vi.mock("@/features/users/service", () => ({ requireActivePlatformUser: user }));
vi.mock("@/features/auth/role-assignments", () => ({ getActiveRoleAssignments: assignments }));
import { SYSTEM_ROLE_IDS, type RoleCode } from "@/lib/auth/role-codes";
import {
  getAuthorizationContext, defineScopedRolePolicy, hasScopedRole, requireScopedRole,
  requireAdminScope, asAuthorizationResult, AuthorizationError,
  type ScopeType, type AuthorizationResource, type ScopedRolePolicy,
} from "@/lib/auth/authorization";

const userId = "00000000-0000-4000-8000-000000000001";
const otherUser = "00000000-0000-4000-8000-000000000002";
const scopeA = "10000000-0000-4000-8000-000000000001";
const scopeB = "10000000-0000-4000-8000-000000000002";
const resourceId = "20000000-0000-4000-8000-000000000001";
const fields = { organization: "organization_id", program: "program_id", cohort: "cohort_id", team: "team_id", project: "project_id" } as const;
const binding = (role: RoleCode, type: ScopeType = "cohort", scopeId = scopeA) => ({
  id: "00000000-0000-4000-8000-000000000201", user_id: userId, role_id: SYSTEM_ROLE_IDS[role],
  organization_id: null, program_id: null, cohort_id: null, team_id: null, project_id: null,
  [fields[type]]: scopeId,
  starts_at: "2026-09-01T00:00:00Z", ends_at: null, status: "active",
  assigned_by: otherUser, created_at: "2026-09-01T00:00:00Z", updated_at: "2026-09-01T00:00:00Z",
});
const resource = (type: ScopeType = "cohort", scopeId = scopeA, access: "educational" | "operational" = "educational"): AuthorizationResource => ({
  id: resourceId, scope: { type, id: scopeId }, access, resourcePolicyAllows: true,
});
const policy = (role: RoleCode = "MASTER", type: ScopeType = "cohort", target = resource(type)) =>
  defineScopedRolePolicy({ role, scopeType: type, access: target.access }, async () => target);
beforeEach(() => {
  vi.useFakeTimers(); vi.setSystemTime(new Date("2026-09-30T12:00:00Z"));
  user.mockReset().mockResolvedValue({ id: userId, account_status: "active" });
  assignments.mockReset().mockResolvedValue([binding("MASTER")]);
});
afterEach(() => { vi.useRealTimers(); });

it("AT-RBAC-001: STUDENT cannot perform a scoped operational Admin action", async () => {
  assignments.mockResolvedValue([binding("STUDENT", "organization")]);
  const admin = policy("ADMIN", "organization", resource("organization", scopeA, "operational"));
  await expect(requireAdminScope(admin, resourceId)).rejects.toMatchObject({ code: "FORBIDDEN", message: "Access denied." });
});
it("AT-RBAC-002: MASTER is allowed only for an exact assigned cohort", async () => {
  expect(await hasScopedRole(policy(), resourceId)).toBe(true);
  expect(await hasScopedRole(policy("MASTER", "cohort", resource("cohort", scopeB)), resourceId)).toBe(false);
});
it("AT-RBAC-003: MENTOR is limited to its exact assigned team", async () => {
  assignments.mockResolvedValue([binding("MENTOR", "team")]);
  expect(await hasScopedRole(policy("MENTOR", "team"), resourceId)).toBe(true);
  expect(await hasScopedRole(policy("MENTOR", "team", resource("team", scopeB)), resourceId)).toBe(false);
});
it("permits operational Admin scope without granting educational content access", async () => {
  assignments.mockResolvedValue([binding("ADMIN", "organization")]);
  const admin = policy("ADMIN", "organization", resource("organization", scopeA, "operational"));
  expect((await requireAdminScope(admin, resourceId)).context.userId).toBe(userId);
  expect(await hasScopedRole(policy("ADMIN", "organization"), resourceId)).toBe(false);
});
it("does not let an operational policy authorize an educational resource", async () => {
  assignments.mockResolvedValue([binding("ADMIN", "organization")]);
  const admin = defineScopedRolePolicy({ role: "ADMIN", scopeType: "organization", access: "operational" }, async () => resource("organization"));
  expect(await hasScopedRole(admin, resourceId)).toBe(false);
});
it("keeps separately assigned instructional authority distinct from Admin authority", async () => {
  assignments.mockResolvedValue([binding("ADMIN", "organization"), binding("MASTER")]);
  expect(await hasScopedRole(policy(), resourceId)).toBe(true);
});
it.each([
  { status: "inactive" }, { starts_at: "2026-10-01T00:00:00Z" },
  { ends_at: "2026-09-30T12:00:00Z" }, { ends_at: "2026-09-29T00:00:00Z" },
])("denies inactive, future, boundary-expired or expired assignment (%j)", async (change) => {
  assignments.mockResolvedValue([{ ...binding("MASTER"), ...change }]);
  expect(await hasScopedRole(policy(), resourceId)).toBe(false);
});
it("accepts the inclusive start boundary", async () => {
  assignments.mockResolvedValue([{ ...binding("MASTER"), starts_at: "2026-09-30T12:00:00Z" }]);
  expect(await hasScopedRole(policy(), resourceId)).toBe(true);
});
it("denies multi-scope assignments pending an approved interpretation policy", async () => {
  assignments.mockResolvedValue([{ ...binding("MASTER"), organization_id: scopeB }]);
  expect(await hasScopedRole(policy(), resourceId)).toBe(false);
  expect((await getAuthorizationContext()).assignments).toEqual([]);
});
it("does not infer cohort authority from an organization assignment", async () => {
  assignments.mockResolvedValue([binding("MASTER", "organization")]);
  expect(await hasScopedRole(policy(), resourceId)).toBe(false);
});
it("ignores client-supplied role and user ID when resolving context", async () => {
  assignments.mockResolvedValue([binding("STUDENT")]);
  const context = await Reflect.apply(getAuthorizationContext, null, [{ userId: otherUser, role: "ADMIN" }]);
  expect(context.userId).toBe(userId); expect(context.assignments[0].roleCode).toBe("STUDENT");
  expect(user).toHaveBeenCalledWith(); expect(assignments).toHaveBeenCalledWith();
});
it("rejects forged policy/context JSON instead of trusting caller role claims", async () => {
  const forged = { role: "MASTER", userId, scopeType: "cohort", access: "educational" } as unknown as ScopedRolePolicy;
  await expect(requireScopedRole(forged, resourceId)).rejects.toMatchObject({ code: "VALIDATION_ERROR" });
});
it("fails closed for assignment rows belonging to another identity", async () => {
  assignments.mockResolvedValue([{ ...binding("MASTER"), user_id: otherUser }]);
  expect(await hasScopedRole(policy(), resourceId)).toBe(false);
});
it("requires an explicit trusted resource-policy approval", async () => {
  expect(await hasScopedRole(policy("MASTER", "cohort", { ...resource(), resourcePolicyAllows: false }), resourceId)).toBe(false);
});
it("does not accept resource metadata for a different requested ID", async () => {
  expect(await hasScopedRole(policy("MASTER", "cohort", { ...resource(), id: scopeB }), resourceId)).toBe(false);
});
it("missing, inaccessible and mismatched resources return indistinguishable errors", async () => {
  const missing = defineScopedRolePolicy({ role: "MASTER", scopeType: "cohort", access: "educational" }, async () => null);
  const mismatch = policy("MASTER", "cohort", resource("cohort", scopeB));
  const denied = policy("MASTER", "cohort", { ...resource(), resourcePolicyAllows: false });
  const expected = { ok: false, error: { code: "FORBIDDEN", message: "Access denied." } };
  for (const gate of [missing, mismatch, denied]) expect(await asAuthorizationResult(() => requireScopedRole(gate, resourceId))).toEqual(expected);
});
it("normalizes anonymous authentication and provider failures without diagnostics", async () => {
  user.mockRejectedValue(Object.assign(new Error("private account detail"), { code: "AUTH_REQUIRED" }));
  expect(await asAuthorizationResult(() => requireScopedRole(policy(), resourceId))).toEqual({ ok: false, error: { code: "AUTH_REQUIRED", message: "Authentication required." } });
  user.mockRejectedValue(new Error("private provider details"));
  expect(await asAuthorizationResult(() => requireScopedRole(policy(), resourceId))).toEqual({ ok: false, error: { code: "FORBIDDEN", message: "Access denied." } });
});
it("returns stable validation and authorized not-found errors", async () => {
  expect(await asAuthorizationResult(() => requireScopedRole(policy(), "not-a-uuid"))).toEqual({ ok: false, error: { code: "VALIDATION_ERROR", message: "Invalid authorization request." } });
  expect(await asAuthorizationResult(async () => { throw new AuthorizationError("NOT_FOUND"); })).toEqual({ ok: false, error: { code: "NOT_FOUND", message: "Resource unavailable." } });
});
it("rechecks revocation after asynchronous metadata resolution", async () => {
  const gate = defineScopedRolePolicy({ role: "MASTER", scopeType: "cohort", access: "educational" }, async () => {
    assignments.mockResolvedValue([]); return resource();
  });
  expect(await hasScopedRole(gate, resourceId)).toBe(false);
});
it("denies a session identity change during metadata resolution", async () => {
  const gate = defineScopedRolePolicy({ role: "MASTER", scopeType: "cohort", access: "educational" }, async () => {
    user.mockResolvedValue({ id: otherUser }); assignments.mockResolvedValue([{ ...binding("MASTER"), user_id: otherUser }]);
    return resource();
  });
  expect(await hasScopedRole(gate, resourceId)).toBe(false);
});
it("does not authorize from an old exported context snapshot", async () => {
  const context = await getAuthorizationContext();
  expect(Object.isFrozen(context)).toBe(true); expect(Object.isFrozen(context.assignments)).toBe(true);
  assignments.mockResolvedValue([]);
  expect(await hasScopedRole(policy(), resourceId)).toBe(false);
});

it("reconstructs canonical errors instead of exposing a mutated diagnostic message", async () => {
  const error = new AuthorizationError("FORBIDDEN");
  error.message = "restricted resource title and private provider details";
  expect(await asAuthorizationResult(async () => { throw error; })).toEqual({
    ok: false, error: { code: "FORBIDDEN", message: "Access denied." },
  });
});
it("normalizes an unknown code on a mutated AuthorizationError", async () => {
  const error = new AuthorizationError("FORBIDDEN");
  Reflect.set(error, "code", "PRIVATE_RESOURCE_DIAGNOSTIC");
  expect(await asAuthorizationResult(async () => { throw error; })).toEqual({
    ok: false, error: { code: "FORBIDDEN", message: "Access denied." },
  });
});
