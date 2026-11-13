import { beforeEach, afterEach, expect, it, vi } from "vitest";
vi.mock("server-only", () => ({}));
const { user, assignments } = vi.hoisted(() => ({ user: vi.fn(), assignments: vi.fn() }));
vi.mock("@/features/users/service", () => ({ requireActivePlatformUser: user }));
vi.mock("@/features/auth/role-assignments", () => ({ getActiveRoleAssignments: assignments }));
import fixture from "../../fixtures/m2-authorization.json";
import { SYSTEM_ROLE_IDS, type RoleCode } from "@/lib/auth/role-codes";
import { asAuthorizationResult, defineScopedRolePolicy, getAuthorizationContext, requireAdminScope, requireScopedRole, type ScopeType } from "@/lib/auth/authorization";
const fields = { organization: "organization_id", program: "program_id", cohort: "cohort_id", team: "team_id", project: "project_id" } as const;
const denied = { ok: false, error: { code: "FORBIDDEN", message: "Access denied." } };
function actAs(id: string, role: RoleCode, type: ScopeType, scope: string, change = {}) {
 user.mockResolvedValue({ id, account_status: "active" });
 assignments.mockResolvedValue([{
  id: "20000000-0000-4000-8000-000000000301", user_id: id, role_id: SYSTEM_ROLE_IDS[role],
  organization_id: null, program_id: null, cohort_id: null, team_id: null, project_id: null,
  [fields[type]]: scope, starts_at: "2026-09-01T00:00:00Z", ends_at: null,
  status: "active", assigned_by: fixture.users.admin,
  created_at: "2026-09-01T00:00:00Z", updated_at: "2026-09-01T00:00:00Z", ...change,
 }]);
}
function gate(role: RoleCode, type: ScopeType, scope: string, allows = true) {
 return defineScopedRolePolicy({ role, scopeType: type, access: role === "ADMIN" ? "operational" : "educational" }, async () => ({
  id: scope, scope: { type, id: scope }, access: role === "ADMIN" ? "operational" : "educational", resourcePolicyAllows: allows,
 }));
}
beforeEach(() => { vi.useFakeTimers(); vi.setSystemTime(new Date("2026-09-30T12:00:00Z")); user.mockReset(); assignments.mockReset(); });
afterEach(() => vi.useRealTimers());
it("AT-RBAC-001: Student A cannot execute an Admin operation; scoped Admin control passes", async () => {
 const policy = gate("ADMIN", "cohort", fixture.scopes.cohortA);
 actAs(fixture.users.studentA, "STUDENT", "cohort", fixture.scopes.cohortA);
 expect(await asAuthorizationResult(() => requireAdminScope(policy, fixture.scopes.cohortA))).toEqual(denied);
 actAs(fixture.users.admin, "ADMIN", "cohort", fixture.scopes.cohortA);
 expect((await requireAdminScope(policy, fixture.scopes.cohortA)).context.userId).toBe(fixture.users.admin);
});
it("AT-RBAC-002: Master has Cohort A authority and cannot access Cohort B", async () => {
 actAs(fixture.users.master, "MASTER", "cohort", fixture.scopes.cohortA);
 expect((await requireScopedRole(gate("MASTER", "cohort", fixture.scopes.cohortA), fixture.scopes.cohortA)).context.userId).toBe(fixture.users.master);
 expect(await asAuthorizationResult(() => requireScopedRole(gate("MASTER", "cohort", fixture.scopes.cohortB), fixture.scopes.cohortB))).toEqual(denied);
});
it("AT-RBAC-003: Team A Mentor denied Team B and both unrelated project scopes", async () => {
 actAs(fixture.users.mentor, "MENTOR", "team", fixture.scopes.teamA);
 expect((await requireScopedRole(gate("MENTOR", "team", fixture.scopes.teamA), fixture.scopes.teamA)).context.userId).toBe(fixture.users.mentor);
 for (const [type, scope] of [["team",fixture.scopes.teamB],["project",fixture.scopes.projectA],["project",fixture.scopes.projectB]] as const) {
  expect(await asAuthorizationResult(() => requireScopedRole(gate("MENTOR", type, scope), scope))).toEqual(denied);
 }
});
it.each([{status:"inactive"},{ends_at:"2026-09-29T00:00:00Z"},{starts_at:"2026-10-01T00:00:00Z"}])("assignment validity denial: %j", async change => {
 actAs(fixture.users.master,"MASTER","cohort",fixture.scopes.cohortA,change);
 expect(await asAuthorizationResult(() => requireScopedRole(gate("MASTER","cohort",fixture.scopes.cohortA),fixture.scopes.cohortA))).toEqual(denied);
});
it("client Admin role and Student B ID cannot change Student A verified identity", async () => {
 actAs(fixture.users.studentA,"STUDENT","cohort",fixture.scopes.cohortA);
 const context = await Reflect.apply(getAuthorizationContext,null,[{userId:fixture.users.studentB,role:"ADMIN"}]);
 expect(context.userId).toBe(fixture.users.studentA); expect(context.assignments[0].roleCode).toBe("STUDENT");
 expect(await asAuthorizationResult(() => requireAdminScope(gate("ADMIN","cohort",fixture.scopes.cohortA),fixture.scopes.cohortA))).toEqual(denied);
 expect(user).toHaveBeenCalledWith(); expect(assignments).toHaveBeenCalledWith();
});
it("restricted metadata, unrelated scope, and missing resource have indistinguishable safe denials", async () => {
 actAs(fixture.users.master,"MASTER","cohort",fixture.scopes.cohortA);
 const missing = defineScopedRolePolicy({role:"MASTER",scopeType:"cohort",access:"educational"},async()=>null);
 for (const [policy,id] of [[missing,fixture.scopes.cohortA],[gate("MASTER","cohort",fixture.scopes.cohortA,false),fixture.scopes.cohortA],[gate("MASTER","cohort",fixture.scopes.cohortB),fixture.scopes.cohortB]] as const) {

  expect(await asAuthorizationResult(() => requireScopedRole(policy,id))).toEqual(denied);
 }
});

