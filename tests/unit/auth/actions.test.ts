import { beforeEach, expect, it, vi } from "vitest";
vi.mock("server-only", () => ({}));
const { createClient, signIn, signOut, redirect, revalidate } = vi.hoisted(() => ({
  createClient: vi.fn(), signIn: vi.fn(), signOut: vi.fn(), redirect: vi.fn(), revalidate: vi.fn(),
}));
vi.mock("@/lib/db/server", () => ({ createServerSupabaseClient: createClient }));
vi.mock("next/navigation", () => ({ redirect }));
vi.mock("next/cache", () => ({ revalidatePath: revalidate }));
import { login, logout } from "@/features/auth/actions";
const state = { error: null };
const form = (email = "person@example.test", password = " test-password ") => {
  const value = new FormData(); value.set("email", email); value.set("password", password); return value;
};
beforeEach(() => {
  createClient.mockReset().mockResolvedValue({ auth: { signInWithPassword: signIn, signOut } });
  signIn.mockReset().mockResolvedValue({ data: { user: { id: "verified" }, session: {} }, error: null });
  signOut.mockReset().mockResolvedValue({ error: null });
  redirect.mockReset().mockImplementation((path: string) => { throw new Error(`redirect:${path}`); });
  revalidate.mockReset();
});
it("AT-AUTH-001: uses Supabase password authentication, persists via the SSR client, and redirects", async () => {
  await expect(login(state, form(" person@example.test "))).rejects.toThrow("redirect:/account");
  expect(signIn).toHaveBeenCalledWith({ email: "person@example.test", password: " test-password " });
  expect(revalidate).toHaveBeenCalledWith("/", "layout");
});
it.each(["https://evil.example", "//evil.example", "/\\evil.example", "/admin"])("ignores untrusted return target %s", async (target) => {
  const input = form(); input.set("next", target); input.set("redirectTo", target);
  await expect(login(state, input)).rejects.toThrow("redirect:/account");
});
it.each([["invalid", "password"], ["a@example.test", ""], ["", "password"]])("validates credentials before provider access", async (email, password) => {
  expect((await login(state, form(email, password))).error).toBe("Enter a valid email address and password.");
  expect(createClient).not.toHaveBeenCalled();
});
it.each(["Invalid credentials", "User not found", "Email not confirmed", "Provider outage"])("AT-AUTH-002: hides provider/account details (%s)", async (message) => {
  signIn.mockResolvedValue({ data: { user: null, session: null }, error: { message } });
  expect((await login(state, form())).error).toBe("Unable to sign in. Check your email and password and try again.");
  expect(redirect).not.toHaveBeenCalled();
});
it("does not treat a missing session as a successful login", async () => {
  signIn.mockResolvedValue({ data: { user: null, session: null }, error: null });
  expect((await login(state, form())).error).not.toBeNull();
  expect(redirect).not.toHaveBeenCalled();
});
it("sanitizes thrown provider failures", async () => {
  signIn.mockRejectedValue(new Error("private detail"));
  expect((await login(state, form())).error).toBe("Unable to sign in. Check your email and password and try again.");
});
it("ends only the current Supabase session and clears cached route state", async () => {
  await expect(logout()).rejects.toThrow("redirect:/login");
  expect(signOut).toHaveBeenCalledWith({ scope: "local" });
  expect(revalidate).toHaveBeenCalledWith("/", "layout");
});
it("does not report successful logout on provider failure", async () => {
  signOut.mockResolvedValue({ error: { message: "private detail" } });
  expect(await logout()).toEqual({ error: "Unable to sign out. Please try again." });
  expect(redirect).not.toHaveBeenCalled();
});
