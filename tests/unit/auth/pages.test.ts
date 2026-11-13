import { beforeEach, expect, it, vi } from "vitest";
vi.mock("server-only", () => ({}));
const { getUser, redirect, getProfile } = vi.hoisted(() => ({ getUser: vi.fn(), redirect: vi.fn(), getProfile: vi.fn() }));
vi.mock("@/lib/auth/session", () => ({ getOptionalAuthenticatedUser: getUser }));
vi.mock("next/navigation", () => ({ redirect }));
vi.mock("@/features/users/service", async (importOriginal) => {
  const actual = await importOriginal<typeof import("@/features/users/service")>();
  return { ...actual, requireActivePlatformUser: getProfile };
});
vi.mock("@/features/auth/forms", () => ({ LoginForm: () => null, LogoutForm: () => null }));
import LoginPage from "@/app/(auth)/login/page";
import AccountPage from "@/app/(platform)/account/page";
import PlatformLayout from "@/app/(platform)/layout";
import { AccountAccessError } from "@/features/users/service";
import { AuthenticationRequiredError } from "@/lib/auth/errors";
beforeEach(() => {
  getUser.mockReset();
  getProfile.mockReset();
  redirect.mockReset().mockImplementation((path: string) => { throw new Error(`redirect:${path}`); });
});
it("redirects an already verified user away from login", async () => {
  getUser.mockResolvedValue({ id: "verified" });
  await expect(LoginPage()).rejects.toThrow("redirect:/account");
});
it("denies anonymous landing-page access", async () => {
  getProfile.mockRejectedValue(new AuthenticationRequiredError());
  await expect(AccountPage()).rejects.toThrow("redirect:/login");
});
it("does not render protected content when verification fails", async () => {
  getProfile.mockRejectedValue(new Error("Unable to verify authentication"));
  await expect(AccountPage()).rejects.toThrow("Unable to verify authentication");
});
it.each(["missing_profile", "invited", "suspended", "archived"] as const)("blocks %s accounts in both the protected layout and page", async (reason) => {
  getProfile.mockRejectedValue(new AccountAccessError(reason));
  await expect(AccountPage()).rejects.toThrow("redirect:/account-state");
  await expect(PlatformLayout({ children: "protected content" })).rejects.toThrow("redirect:/account-state");
});
it("allows active account content through the protected layout", async () => {
  getProfile.mockResolvedValue({ account_status: "active" });
  expect(await PlatformLayout({ children: "protected content" })).toBe("protected content");
});
