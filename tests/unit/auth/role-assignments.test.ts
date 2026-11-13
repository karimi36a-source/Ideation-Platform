import { beforeEach, expect, it, vi } from "vitest";
vi.mock("server-only", () => ({}));
const { requireUser, createClient, rpc } = vi.hoisted(() => ({ requireUser: vi.fn(), createClient: vi.fn(), rpc: vi.fn() }));
vi.mock("@/features/users/service", () => ({ requireActivePlatformUser: requireUser }));
vi.mock("@/lib/db/server", () => ({ createServerSupabaseClient: createClient }));
import { getActiveRoleAssignments, RoleAssignmentReadError } from "@/features/auth/role-assignments";

const userId = "00000000-0000-4000-8000-000000000001";
const otherId = "00000000-0000-4000-8000-000000000002";
const row = {
  id: "00000000-0000-4000-8000-000000000201", user_id: userId,
  role_id: "00000000-0000-4000-8000-000000000102",
  organization_id: "10000000-0000-4000-8000-000000000001",
  program_id: "10000000-0000-4000-8000-000000000002",
  cohort_id: "10000000-0000-4000-8000-000000000003",
  team_id: "10000000-0000-4000-8000-000000000004",
  project_id: "10000000-0000-4000-8000-000000000005",
  starts_at: "2026-01-01T00:00:00+00:00", ends_at: null,
  status: "active", assigned_by: otherId,
  created_at: "2026-01-01T00:00:00+00:00", updated_at: "2026-01-01T00:00:00+00:00",
};
beforeEach(() => {
  requireUser.mockReset().mockResolvedValue({ id: userId, account_status: "active" });
  createClient.mockReset().mockResolvedValue({ rpc });
  rpc.mockReset().mockResolvedValue({ data: [row], error: null });
});
it("resolves the active caller's bindings with all scope UUIDs and provenance intact", async () => {
  expect(await getActiveRoleAssignments()).toEqual([row]);
  expect(requireUser).toHaveBeenCalledWith();
  expect(rpc).toHaveBeenCalledWith("get_active_role_assignments");
});
it("accepts no caller identity, scope, role or as-of timestamp", async () => {
  expect(await Reflect.apply(getActiveRoleAssignments, null, [{ userId: otherId, role: "ADMIN", asOf: "2099-01-01" }])).toEqual([row]);
  expect(rpc).toHaveBeenCalledWith("get_active_role_assignments");
});
it("returns no bindings when the database filters out inactive/future/expired assignments", async () => {
  rpc.mockResolvedValue({ data: [], error: null });
  expect(await getActiveRoleAssignments()).toEqual([]);
});
it.each(["AUTH_REQUIRED", "FORBIDDEN"])("rejects %s before querying bindings", async (code) => {
  requireUser.mockRejectedValue(Object.assign(new Error("Access denied"), { code }));
  await expect(getActiveRoleAssignments()).rejects.toMatchObject({ code });
  expect(createClient).not.toHaveBeenCalled();
});
it("fails closed if returned bindings belong to another user", async () => {
  rpc.mockResolvedValue({ data: [{ ...row, user_id: otherId }], error: null });
  await expect(getActiveRoleAssignments()).rejects.toEqual(new RoleAssignmentReadError());
});
it.each([
  { ...row, status: "inactive" }, { ...row, role_id: "invalid" },
  { ...row, organization_id: null, program_id: null, cohort_id: null, team_id: null, project_id: null },
  { ...row, ends_at: row.starts_at }, { ...row, starts_at: "not-a-timestamp" },
])("rejects invalid/unscoped provider rows rather than constructing authorization", async (invalid) => {
  rpc.mockResolvedValue({ data: [invalid], error: null });
  await expect(getActiveRoleAssignments()).rejects.toEqual(new RoleAssignmentReadError());
});
it("sanitizes provider failures", async () => {
  rpc.mockResolvedValue({ data: null, error: { message: "private diagnostics" } });
  await expect(getActiveRoleAssignments()).rejects.toEqual(new RoleAssignmentReadError());
  rpc.mockRejectedValue(new Error("private diagnostics"));
  await expect(getActiveRoleAssignments()).rejects.toEqual(new RoleAssignmentReadError());
});
