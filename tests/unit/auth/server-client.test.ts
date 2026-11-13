import { beforeEach, expect, it, vi } from "vitest";
import type { CookieMethodsServer } from "@supabase/ssr";

vi.mock("server-only", () => ({}));
const { createClient, cookieStore, readCookies } = vi.hoisted(() => ({
  createClient: vi.fn(),
  cookieStore: { getAll: vi.fn(), set: vi.fn() },
  readCookies: vi.fn(),
}));
vi.mock("@supabase/ssr", () => ({ createServerClient: createClient }));
vi.mock("next/headers", () => ({ cookies: readCookies }));
vi.mock("@/lib/validation/env-server", () => ({
  getServerEnv: () => ({
    NEXT_PUBLIC_SUPABASE_URL: "http://127.0.0.1:54321",
    NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY: "sb_publishable_test_placeholder",
    SUPABASE_SECRET_KEY: "server-only-test-sentinel",
  }),
}));

import { createServerSupabaseClient } from "@/lib/db/server";

let cookieMethods: CookieMethodsServer;
beforeEach(() => {
  cookieStore.set.mockReset();
  cookieStore.getAll.mockReset().mockReturnValue([{ name: "session", value: "request-cookie" }]);
  readCookies.mockReset().mockResolvedValue(cookieStore);
  createClient.mockReset().mockImplementation((_url: string, _key: string, options: { cookies: CookieMethodsServer }) => {
    cookieMethods = options.cookies;
    return { requestScoped: true };
  });
});

it("creates fresh clients with request cookies and only the publishable key", async () => {
  await createServerSupabaseClient();
  expect(await cookieMethods.getAll()).toEqual([{ name: "session", value: "request-cookie" }]);
  await createServerSupabaseClient();
  expect(createClient).toHaveBeenCalledTimes(2);
  expect(readCookies).toHaveBeenCalledTimes(2);
  for (const call of createClient.mock.calls) {
    expect(call.slice(0, 2)).toEqual(["http://127.0.0.1:54321", "sb_publishable_test_placeholder"]);
    expect(JSON.stringify(call)).not.toContain("server-only-test-sentinel");
  }
});

it("persists refreshed cookies where Next.js permits writes", async () => {
  await createServerSupabaseClient();
  await cookieMethods.setAll?.([{ name: "session", value: "fresh", options: { path: "/", sameSite: "lax" } }], {});
  expect(cookieStore.set).toHaveBeenCalledWith("session", "fresh", { path: "/", sameSite: "lax" });
});

it("allows read-only Server Components because Proxy owns refresh persistence", async () => {
  cookieStore.set.mockImplementation(() => { throw new Error("Cookies can only be modified in a Server Action or Route Handler."); });
  await createServerSupabaseClient();
  expect(() => cookieMethods.setAll?.([{ name: "session", value: "fresh", options: {} }], {})).not.toThrow();
});

it("does not swallow unexpected cookie persistence failures", async () => {
  cookieStore.set.mockImplementation(() => { throw new Error("Unexpected cookie failure"); });
  await createServerSupabaseClient();
  expect(() => cookieMethods.setAll?.([{ name: "session", value: "fresh", options: {} }], {})).toThrow("Unexpected cookie failure");
});
