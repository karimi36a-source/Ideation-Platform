import { expect, test } from "@playwright/test";
test.use({ trace: "off", screenshot: "off", video: "off" });

test("anonymous Workspace HTTP requests expose no metadata or existence details", async ({ request }) => {
  const bodies = [];
  for (const suffix of ["000000001901", "000000001999"]) {
    const response = await request.get(`/api/v1/workspaces/00000000-0000-4000-8000-${suffix}?role=ADMIN`, {
      headers: { "x-user-id": "00000000-0000-4000-8000-000000001701", "x-role": "ADMIN" },
    });
    expect(response.status()).toBe(401);
    expect(response.headers()["cache-control"]).toContain("no-store");
    bodies.push(await response.json());
  }
  expect(bodies).toEqual(Array(2).fill({ ok: false, error: { code: "AUTH_REQUIRED", message: "Authentication required." } }));
});

test("Workspace HTTP endpoint cannot be used for direct client mutation", async ({ request }) => {
  for (const method of ["POST", "PUT", "PATCH", "DELETE"]) {
    const response = await request.fetch("/api/v1/workspaces/00000000-0000-4000-8000-000000001901", {
      method, data: { owner_user_id: "00000000-0000-4000-8000-000000001702", status: "archived", role: "ADMIN" },
    });
    expect(response.status()).toBe(405);
    expect(await response.text()).toBe("");
  }
});
