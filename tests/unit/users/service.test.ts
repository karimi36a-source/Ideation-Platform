import { beforeEach, expect, it, vi } from "vitest";
vi.mock("server-only", () => ({}));
const { requireUser, createClient, query } = vi.hoisted(() => ({
  requireUser: vi.fn(), createClient: vi.fn(),
  query: { from: vi.fn(), select: vi.fn(), eq: vi.fn(), update: vi.fn(), maybeSingle: vi.fn() },
}));
vi.mock("@/lib/auth/session", () => ({ requireAuthenticatedUser: requireUser }));
vi.mock("@/lib/db/server", () => ({ createServerSupabaseClient: createClient }));
import { getCurrentUser, updateOwnProfile, ProfileError, requireActivePlatformUser, AccountAccessError } from "@/features/users/service";
const profile = {
  id: "00000000-0000-4000-8000-000000000001", email: "a@example.test", display_name: "Alice",
  first_name: null, last_name: null, profile_image: null, account_status: "active",
  timezone: null, locale: null, created_at: "2026-01-01T00:00:00Z", updated_at: "2026-01-01T00:00:00Z",
};
beforeEach(() => {
  requireUser.mockReset().mockResolvedValue({ id: profile.id });
  createClient.mockReset().mockResolvedValue(query);
  for (const method of [query.from, query.select, query.eq, query.update]) method.mockReset().mockReturnValue(query);
  query.maybeSingle.mockReset().mockResolvedValue({ data: profile, error: null });
});
it("reads the profile only for the verified identity", async () => {
  expect(await getCurrentUser()).toEqual(profile);
  expect(query.eq).toHaveBeenCalledWith("id", profile.id);
});
it("updates only allowlisted fields on the verified user's row", async () => {
  await updateOwnProfile({ display_name: " Alice ", profile_image: null, timezone: "UTC", locale: "en" });
  expect(query.update).toHaveBeenCalledWith({ display_name: "Alice", profile_image: null, timezone: "UTC", locale: "en" });
  expect(query.eq).toHaveBeenCalledWith("id", profile.id);
});
it.each(["id", "userId", "email", "account_status", "first_name", "last_name", "created_at", "updated_at"])("AT-AUTH-004: rejects unapproved field %s rather than trusting or ignoring it", async (field) => {
  await expect(updateOwnProfile({ display_name: "Alice", [field]: "spoofed" })).rejects.toMatchObject({ code: "VALIDATION_ERROR" });
  expect(createClient).not.toHaveBeenCalled();
});
it.each([{}, null, { display_name: " " }, { locale: 42 }])("rejects invalid or empty input", async (input) => {
  await expect(updateOwnProfile(input)).rejects.toMatchObject({ code: "VALIDATION_ERROR" });
});
it("rejects anonymous reads and writes before database access", async () => {
  requireUser.mockRejectedValue(new Error("Authentication required"));
  await expect(getCurrentUser()).rejects.toThrow("Authentication required");
  await expect(updateOwnProfile({ locale: "en" })).rejects.toThrow("Authentication required");
  expect(createClient).not.toHaveBeenCalled();
});
it("reports a missing profile without provisioning or granting a status", async () => {
  query.maybeSingle.mockResolvedValue({ data: null, error: null });
  await expect(getCurrentUser()).rejects.toEqual(new ProfileError("NOT_FOUND"));
  await expect(updateOwnProfile({ locale: "en" })).rejects.toEqual(new AccountAccessError("missing_profile"));
  await expect(requireActivePlatformUser()).rejects.toEqual(new AccountAccessError("missing_profile"));
  expect(query.update).not.toHaveBeenCalled();
});

it("allows only a validated active platform identity", async () => {
  expect(await requireActivePlatformUser()).toEqual(profile);
});
it.each(["invited", "suspended", "archived"] as const)("blocks %s protected access and profile mutation without altering status", async (status) => {
  query.maybeSingle.mockResolvedValue({ data: { ...profile, account_status: status }, error: null });
  await expect(requireActivePlatformUser()).rejects.toEqual(new AccountAccessError(status));
  await expect(updateOwnProfile({ locale: "en" })).rejects.toEqual(new AccountAccessError(status));
  expect(query.update).not.toHaveBeenCalled();
  expect((await getCurrentUser()).account_status).toBe(status);
});
it("rechecks status after an earlier active read rather than caching authorization", async () => {
  await requireActivePlatformUser();
  query.maybeSingle.mockResolvedValue({ data: { ...profile, account_status: "suspended" }, error: null });
  await expect(requireActivePlatformUser()).rejects.toMatchObject({ reason: "suspended" });
});
it("fails closed on malformed or mismatched profile identity", async () => {
  query.maybeSingle.mockResolvedValue({ data: { ...profile, id: "00000000-0000-4000-8000-000000000002" }, error: null });
  await expect(requireActivePlatformUser()).rejects.toEqual(new ProfileError("EXTERNAL_PROVIDER_ERROR"));
  await expect(updateOwnProfile({ locale: "en" })).rejects.toEqual(new ProfileError("EXTERNAL_PROVIDER_ERROR"));
  expect(query.update).not.toHaveBeenCalled();
});
it("does not expose database diagnostics", async () => {
  query.maybeSingle.mockResolvedValue({ data: null, error: { message: "private details" } });
  await expect(getCurrentUser()).rejects.toEqual(new ProfileError("EXTERNAL_PROVIDER_ERROR"));
  await expect(updateOwnProfile({ locale: "en" })).rejects.toEqual(new ProfileError("EXTERNAL_PROVIDER_ERROR"));
});
