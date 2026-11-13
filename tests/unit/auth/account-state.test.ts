import { beforeEach, expect, it, vi } from "vitest";
vi.mock("server-only", () => ({}));
const { profile, redirect } = vi.hoisted(() => ({ profile: vi.fn(), redirect: vi.fn() }));
vi.mock("@/features/users/service", async (importOriginal) => {
  const actual = await importOriginal<typeof import("@/features/users/service")>();
  return { ...actual, getCurrentUser: profile };
});
vi.mock("next/navigation", () => ({ redirect }));
vi.mock("@/features/auth/forms", () => ({ LogoutForm: () => null }));
import AccountStatePage from "@/app/(auth)/account-state/page";
import { ProfileError } from "@/features/users/service";
import { AuthenticationRequiredError } from "@/lib/auth/errors";
beforeEach(() => {
  profile.mockReset();
  redirect.mockReset().mockImplementation((path: string) => { throw new Error(`redirect:${path}`); });
});
it("requires verified authentication for account-state details", async () => {
  profile.mockRejectedValue(new AuthenticationRequiredError());
  await expect(AccountStatePage()).rejects.toThrow("redirect:/login");
});
it("returns activated accounts to the protected area", async () => {
  profile.mockResolvedValue({ account_status: "active" });
  await expect(AccountStatePage()).rejects.toThrow("redirect:/account");
});
it.each(["invited", "suspended", "archived"])("renders a logout-capable blocked state for %s", async (status) => {
  profile.mockResolvedValue({ account_status: status });
  const page = await AccountStatePage();
  expect(JSON.stringify(page)).toContain(status === "invited" ? "awaiting activation" : status);
  expect(redirect).not.toHaveBeenCalled();
});
it("reports missing trusted provisioning without creating a profile", async () => {
  profile.mockRejectedValue(new ProfileError("NOT_FOUND"));
  expect(JSON.stringify(await AccountStatePage())).toContain("has not been provisioned");
});
it("does not treat a provider outage as a missing profile", async () => {
  profile.mockRejectedValue(new ProfileError("EXTERNAL_PROVIDER_ERROR"));
  await expect(AccountStatePage()).rejects.toMatchObject({ code: "EXTERNAL_PROVIDER_ERROR" });
});
