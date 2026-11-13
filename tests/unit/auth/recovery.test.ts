import { beforeEach, expect, it, vi } from "vitest";
vi.mock("server-only", () => ({}));
const mocks = vi.hoisted(() => ({ create: vi.fn(), request: vi.fn(), verify: vi.fn(), getUser: vi.fn(), update: vi.fn(), signOut: vi.fn(), revalidate: vi.fn() }));
vi.mock("@/lib/db/server", () => ({ createServerSupabaseClient: mocks.create }));
vi.mock("next/cache", () => ({ revalidatePath: mocks.revalidate }));
import { requestPasswordReset, resetPassword } from "@/features/auth/recovery-actions";
import { getAuthSiteUrl } from "@/lib/auth/site-url";
import { GET } from "@/app/auth/confirm/route";
import { NextRequest } from "next/server";

const initial = { error: null, message: null };
const form = () => {
  const value = new FormData(); value.set("email", "person@example.test");
  value.set("token_hash", "provider-token-fixture"); value.set("password", "new-provider-password");
  value.set("confirmation", "new-provider-password"); return value;
};
beforeEach(() => {
  vi.stubEnv("AUTH_SITE_URL", "https://fici.example.test");
  mocks.create.mockReset().mockResolvedValue({ auth: { resetPasswordForEmail: mocks.request, verifyOtp: mocks.verify, getUser: mocks.getUser, updateUser: mocks.update, signOut: mocks.signOut } });
  mocks.request.mockReset().mockResolvedValue({ error: null });
  mocks.verify.mockReset().mockResolvedValue({ data: { user: { id: "provider-user" }, session: {} }, error: null });
  mocks.getUser.mockReset().mockResolvedValue({ data: { user: { id: "provider-user" } }, error: null });
  mocks.update.mockReset().mockResolvedValue({ data: { user: { id: "provider-user" } }, error: null });
  mocks.signOut.mockReset().mockResolvedValue({ error: null });
});
it("uses a configured origin rather than submitted redirect values", async () => {
  const input = form(); input.set("redirectTo", "https://evil.test");
  expect((await requestPasswordReset(initial, input)).message).toContain("If an eligible account exists");
  expect(mocks.request).toHaveBeenCalledWith("person@example.test", { redirectTo: "https://fici.example.test/reset-password" });
});
it("gives identical request states for absent accounts, rate limits and exceptions", async () => {
  const success = await requestPasswordReset(initial, form());
  mocks.request.mockResolvedValue({ error: { message: "account missing" } });
  expect(await requestPasswordReset(initial, form())).toEqual(success);
  mocks.request.mockRejectedValue(new Error("private provider data"));
  expect(await requestPasswordReset(initial, form())).toEqual(success);
});
it("rejects invalid email without contacting Supabase", async () => {
  const input = form(); input.set("email", "invalid");
  expect((await requestPasswordReset(initial, input)).error).toBe("Enter a valid email address.");
  expect(mocks.create).not.toHaveBeenCalled();
});
it.each(["https://evil.test/path", "http://public.test", "https://user:password@fici.test", "https://fici.test/?next=evil"])("rejects unsafe configured origin %s", (origin) => {
  vi.stubEnv("AUTH_SITE_URL", origin); expect(getAuthSiteUrl).toThrow();
});
it("requires a provider recovery token even when a normal session exists", async () => {
  const input = form(); input.delete("token_hash");
  expect((await resetPassword(initial, input)).error).not.toBeNull();
  expect(mocks.verify).not.toHaveBeenCalled(); expect(mocks.update).not.toHaveBeenCalled();
});
it("checks matching passwords before consuming the token", async () => {
  const input = form(); input.set("confirmation", "different");
  expect((await resetPassword(initial, input)).error).not.toBeNull(); expect(mocks.verify).not.toHaveBeenCalled();
});
it.each(["expired", "replayed", "invalid"])("denies %s provider token without updating a password", async (reason) => {
  mocks.verify.mockResolvedValue({ data: { user: null, session: null }, error: { message: reason } });
  expect((await resetPassword(initial, form())).invalid).toBe(true); expect(mocks.update).not.toHaveBeenCalled();
});
it("requires remote verified identity matching the provider recovery user", async () => {
  mocks.getUser.mockResolvedValue({ data: { user: { id: "another-user" } }, error: null });
  expect((await resetPassword(initial, form())).invalid).toBe(true); expect(mocks.update).not.toHaveBeenCalled();
  expect(mocks.signOut).toHaveBeenCalledWith({ scope: "local" });
});
it("updates through Supabase only, ends the session, and returns no password/token", async () => {
  const result = await resetPassword(initial, form());
  expect(mocks.verify).toHaveBeenCalledWith({ token_hash: "provider-token-fixture", type: "recovery" });
  expect(mocks.update).toHaveBeenCalledWith({ password: "new-provider-password" });
  expect(mocks.signOut).toHaveBeenCalledWith({ scope: "local" });
  expect(result).toEqual({ error: null, message: "Password updated. Sign in with your new password.", completed: true });
});
it("handles provider password policy failures without exposing provider data", async () => {
  mocks.update.mockResolvedValue({ data: { user: null }, error: { message: "secret provider detail" } });
  const result = await resetPassword(initial, form()); expect(result.invalid).toBe(true);
  expect(result.error).not.toContain("secret"); expect(mocks.signOut).toHaveBeenCalled();
});
it("does not falsely report session termination", async () => {
  mocks.signOut.mockResolvedValue({ error: { message: "failure" } });
  expect((await resetPassword(initial, form())).error).toContain("sign-out could not be confirmed");
});
it("verification uses a fixed clean destination and provider token validation", async () => {
  const response = await GET(new NextRequest("https://fici.test/auth/confirm?token_hash=fixture&type=signup&next=https://evil.test"));
  expect(mocks.verify).toHaveBeenCalledWith({ token_hash: "fixture", type: "signup" });
  expect(response.headers.get("location")).toBe("https://fici.test/verification?status=verified");
  expect(response.headers.get("cache-control")).toContain("no-store");
  expect(response.headers.get("referrer-policy")).toBe("no-referrer");
});
it.each(["recovery", "magiclink", "unknown"])("verification callback rejects unsupported type %s", async (type) => {
  const response = await GET(new NextRequest(`https://fici.test/auth/confirm?token_hash=fixture&type=${type}`));
  expect(response.headers.get("location")).toContain("status=invalid"); expect(mocks.verify).not.toHaveBeenCalled();
});
it("verification rejects expired tokens without reflecting them", async () => {
  mocks.verify.mockResolvedValue({ data: { user: null }, error: { message: "private token" } });
  const response = await GET(new NextRequest("https://fici.test/auth/confirm?token_hash=fixture&type=signup"));
  expect(response.headers.get("location")).toBe("https://fici.test/verification?status=invalid");
});
