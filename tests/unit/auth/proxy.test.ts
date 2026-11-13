import { beforeEach, expect, it, vi } from "vitest";
import type { CookieMethodsServer } from "@supabase/ssr";
import { AuthApiError, AuthSessionMissingError } from "@supabase/supabase-js";
import { NextRequest } from "next/server";

vi.mock("server-only", () => ({}));
const { createClient, getUser, getEnv } = vi.hoisted(() => ({
  createClient: vi.fn(), getUser: vi.fn(), getEnv: vi.fn(),
}));
vi.mock("@supabase/ssr", () => ({ createServerClient: createClient }));
vi.mock("@/lib/validation/env-public", () => ({ getPublicEnv: getEnv }));

import { updateSession } from "@/lib/auth/proxy";
import { proxy } from "@/proxy";
import { AuthenticationUnavailableError } from "@/lib/auth/errors";


let cookies: CookieMethodsServer;
beforeEach(() => {
  getEnv.mockReset().mockReturnValue({
    NEXT_PUBLIC_SUPABASE_URL: "http://127.0.0.1:54321",
    NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY: "sb_publishable_test_placeholder",
  });
  getUser.mockReset().mockResolvedValue({ data: { user: null }, error: null });
  createClient.mockReset().mockImplementation((_url: string, _key: string, options: { cookies: CookieMethodsServer }) => {
    cookies = options.cookies;
    return { auth: { getUser } };
  });
});

it("forwards refreshed cookie chunks to server rendering and the browser, with cache headers", async () => {
  const request = new NextRequest("http://localhost/auth/example", {
    headers: { cookie: "session.0=old; session.1=stale" },
  });
  getUser.mockImplementation(async () => {
    expect(await cookies.getAll()).toContainEqual({ name: "session.0", value: "old" });
    await cookies.setAll?.([
      { name: "session.0", value: "fresh", options: { path: "/", sameSite: "lax", secure: true } },
      { name: "session.1", value: "", options: { path: "/", maxAge: 0 } },
    ], { "Cache-Control": "private, no-cache, no-store, must-revalidate, max-age=0", Expires: "0", Pragma: "no-cache" });
    // The SDK sends cache headers only on the first cookie write.
    await cookies.setAll?.([{ name: "extra", value: "second", options: { path: "/" } }], {});
    return { data: { user: null }, error: null };
  });
  const response = await updateSession(request);
  expect(request.cookies.get("session.0")?.value).toBe("fresh");
  expect(response.headers.get("x-middleware-request-cookie")).toContain("session.0=fresh");
  expect(response.cookies.get("session.0")).toMatchObject({ value: "fresh", path: "/", sameSite: "lax", secure: true });
  expect(response.cookies.get("session.1")?.maxAge).toBe(0);
  expect(response.cookies.get("extra")?.value).toBe("second");
  expect(response.headers.get("cache-control")).toContain("no-store");
  expect(response.headers.get("expires")).toBe("0");
  expect(response.headers.get("pragma")).toBe("no-cache");
  expect(createClient.mock.calls[0]?.slice(0, 2)).toEqual(["http://127.0.0.1:54321", "sb_publishable_test_placeholder"]);
});

it("allows an absent session without granting protected access", async () => {
  getUser.mockResolvedValue({ data: { user: null }, error: new AuthSessionMissingError() });
  const response = await updateSession(new NextRequest("http://localhost/auth/example"));
  expect(response.status).toBe(200);
  expect(response.headers.get("cache-control")).toBe("private, no-store");
});

it("fails closed on provider outages", async () => {
  getUser.mockResolvedValue({ data: { user: null }, error: new AuthApiError("private detail", 503, "unexpected_failure") });
  await expect(updateSession(new NextRequest("http://localhost/auth/example"))).rejects.toEqual(new AuthenticationUnavailableError());
});

it("preserves the credential-free static foundation page", async () => {
  expect((await proxy(new NextRequest("http://localhost/"))).status).toBe(200);
  expect(createClient).not.toHaveBeenCalled();
  expect(getEnv).not.toHaveBeenCalled();
});

it("runs refresh for other routes and fails closed on invalid configuration", async () => {
  getEnv.mockImplementation(() => { throw new Error("Invalid configuration"); });
  await expect(proxy(new NextRequest("http://localhost/auth/example"))).rejects.toThrow("Invalid configuration");
});

it("refreshes each application request with its own client and cookies", async () => {
  const first = new NextRequest("http://localhost/auth/example", { headers: { cookie: "session=user-a" } });
  const second = new NextRequest("http://localhost/auth/example", { headers: { cookie: "session=user-b" } });
  const observed: string[] = [];
  getUser.mockImplementation(async () => {
    observed.push((await cookies.getAll())?.find((cookie) => cookie.name === "session")?.value ?? "");
    return { data: { user: null }, error: null };
  });
  await proxy(first);
  await proxy(second);
  expect(observed).toEqual(["user-a", "user-b"]);
  expect(createClient).toHaveBeenCalledTimes(2);
});
