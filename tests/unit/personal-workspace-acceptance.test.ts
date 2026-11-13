import { beforeEach, expect, it, vi } from "vitest";
vi.mock("server-only", () => ({}));
const { user, assignments, client } = vi.hoisted(() => ({ user: vi.fn(), assignments: vi.fn(), client: vi.fn() }));
vi.mock("@/features/users/service", () => ({ requireActivePlatformUser: user }));
vi.mock("@/features/auth/role-assignments", () => ({ getActiveRoleAssignments: assignments }));
vi.mock("@/lib/db/server", () => ({ createServerSupabaseClient: client }));
// Exercise the actual route, retrieval service, resolver and authorization layer.
// Only verified identity/provider I/O is replaced; PostgreSQL is tested separately.
import { GET } from "@/app/api/v1/workspaces/[workspaceId]/route";
import { getWorkspace, listMyWorkspaces } from "@/features/workspaces/service";
import { AuthorizationError } from "@/lib/auth/authorization";
import { SYSTEM_ROLE_IDS } from "@/lib/auth/role-codes";
import acceptance from "../fixtures/personal-workspace-acceptance.json";
const uuid = (n: number) => `00000000-0000-4000-8000-${String(n).padStart(12, "0")}`;
const studentA1 = uuid(1701), studentA2 = uuid(1702), master = uuid(1703), wid = uuid(1901);
const metadata = {
  id: wid, workspace_type: "PERSONAL", name: "Student A1 private workspace",
  owner_user_id: studentA1, cohort_id: uuid(1910), team_id: null, project_id: null,
  status: "active", visibility: "private", settings: { confidential: "owner only" },
  created_by: studentA1, updated_by: studentA1, archived_at: null,
  created_at: "2026-10-01T00:00:00Z", updated_at: "2026-10-01T00:00:00Z",
};
let actor: string;
it("AT-PW-004 records the exact deferred Artifact/Sharing dependency", () => {
  expect(acceptance["AT-PW-004"]).toBe("DEFERRED — requires Artifacts + Sharing");
});
const route = (id = wid, query = "") => GET(
  new Request(`http://localhost/api/v1/workspaces/${id}${query}`, { headers: { "x-user-id": studentA1, "x-role": "ADMIN" } }),
  { params: Promise.resolve({ workspaceId: id }) },
);
beforeEach(() => {
  actor = studentA1;
  user.mockReset().mockImplementation(async () => ({ id: actor }));
  assignments.mockReset().mockResolvedValue([]);
  // Deliberately return another owner's data from provider I/O: resolver must
  // independently deny it, rather than rely on a mock that filters for it.
  client.mockReset().mockResolvedValue({ from: () => ({ select: () => ({
    eq: (_field: string, id: string) => ({ maybeSingle: async () => ({ data: id === wid ? metadata : null, error: null }) }),
    order: () => ({ order: async () => ({ data: [{ id: wid }], error: null }) }),
  }) }) });
});
it("AT-PW-001: Student A1 retrieves their active Workspace through route and service", async () => {
  expect(await getWorkspace(wid)).toEqual(metadata);
  expect(await listMyWorkspaces()).toEqual([metadata]);
  const response = await route();
  expect(response.status).toBe(200);
  expect(await response.json()).toEqual({ ok: true, data: metadata });
  expect(response.headers.get("cache-control")).toBe("private, no-store");
});
it.each([studentA2, master])("AT-PW-002/003: non-owner %s cannot browse exact or guessed IDs", async id => {
  actor = id;
  if (id === master) assignments.mockResolvedValue([{
    id: uuid(1902), user_id: master, role_id: SYSTEM_ROLE_IDS.MASTER,
    organization_id: null, program_id: null, cohort_id: uuid(1910), team_id: null, project_id: null,
    status: "active", starts_at: "2020-01-01T00:00:00Z", ends_at: null, assigned_by: master,
    created_at: metadata.created_at, updated_at: metadata.updated_at,
  }]);
  await expect(getWorkspace(wid)).rejects.toMatchObject({ code: "FORBIDDEN", message: "Access denied." });
  expect(await listMyWorkspaces()).toEqual([]);
  const exact = await route(wid, `?owner_user_id=${studentA1}&role=ADMIN`);
  const guessed = await route(uuid(1999));
  expect(exact.status).toBe(403); expect(guessed.status).toBe(403);
  const denied = { ok: false, error: { code: "FORBIDDEN", message: "Access denied." } };
  expect(await exact.json()).toEqual(denied); expect(await guessed.json()).toEqual(denied);
  expect(exact.headers.get("cache-control")).toBe("private, no-store");
});
it("anonymous route/service access is denied before database lookup", async () => {
  user.mockRejectedValue(new AuthorizationError("AUTH_REQUIRED"));
  const response = await route(); expect(response.status).toBe(401);
  expect(await response.json()).toEqual({ ok: false, error: { code: "AUTH_REQUIRED", message: "Authentication required." } });
  expect(client).not.toHaveBeenCalled();
});
it("route never forwards provider exceptions or resource diagnostics", async () => {
  client.mockRejectedValue(new Error(JSON.stringify(metadata)));
  const response = await route(); expect(response.status).toBe(403);
  expect(await response.json()).toEqual({ ok: false, error: { code: "FORBIDDEN", message: "Access denied." } });
});

it.each([
  ["Student B", studentA2, "STUDENT"],
  ["Master", master, "MASTER"],
  ["Admin", uuid(1705), "ADMIN"],
] as const)("M4.9 %s cannot enumerate private metadata or distinguish real/missing IDs", async (_label, id, role) => {
  actor = id;
  assignments.mockResolvedValue([{
    id: uuid(1920), user_id: id, role_id: SYSTEM_ROLE_IDS[role],
    organization_id: role === "ADMIN" ? uuid(501) : null, program_id: null,
    cohort_id: role === "ADMIN" ? null : metadata.cohort_id, team_id: null, project_id: null,
    status: "active", starts_at: "2020-01-01T00:00:00Z", ends_at: null, assigned_by: id,
    created_at: metadata.created_at, updated_at: metadata.updated_at,
  }]);
  const expected = { ok: false, error: { code: "FORBIDDEN", message: "Access denied." } };
  for (const query of [
    `?owner_user_id=${studentA1}`,
    `?cohort_id=${metadata.cohort_id}&workspace_type=PERSONAL`,
    `?owner_user_id=${studentA1}&role=ADMIN&cohort_id=${metadata.cohort_id}`,
  ]) {
    const exact = await route(wid, query), missing = await route(uuid(1999), query);
    expect(exact.status).toBe(403); expect(missing.status).toBe(exact.status);
    expect(await exact.text()).toBe(JSON.stringify(expected));
    expect(await missing.text()).toBe(JSON.stringify(expected));
    expect(missing.headers.get("cache-control")).toBe(exact.headers.get("cache-control"));
  }
  for (const target of [wid, uuid(1999)]) {
    await expect(getWorkspace(target)).rejects.toMatchObject({ code: "FORBIDDEN", message: "Access denied." });
  }
  expect(await Reflect.apply(listMyWorkspaces, undefined, [{ owner_user_id: studentA1, cohort_id: metadata.cohort_id, role: "ADMIN" }])).toEqual([]);
});
