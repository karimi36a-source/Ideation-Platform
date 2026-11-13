import { beforeEach, describe, expect, it, vi } from "vitest";
import { AuthApiError, AuthSessionMissingError, type User } from "@supabase/supabase-js";

vi.mock("server-only", () => ({}));
const { getUser, createClient } = vi.hoisted(() => ({
  getUser: vi.fn(),
  createClient: vi.fn(),
}));
vi.mock("@/lib/db/server", () => ({ createServerSupabaseClient: createClient }));

import { getVerifiedSession, getOptionalAuthenticatedUser, requireAuthenticatedUser } from "@/lib/auth/session";
import { AuthenticationRequiredError, AuthenticationUnavailableError } from "@/lib/auth/errors";

const user: User = {
  id: "verified-user-a",
  app_metadata: {},
  user_metadata: {},
  aud: "authenticated",
  created_at: "2026-01-01T00:00:00Z",
};

beforeEach(() => {
  getUser.mockReset();
  createClient.mockReset().mockResolvedValue({ auth: { getUser } });
});

describe("verified server session", () => {
  it("derives identity only from the Auth server and returns no tokens", async () => {
    getUser.mockResolvedValue({ data: { user }, error: null });
    expect(await getVerifiedSession()).toEqual({ user });
    expect(getUser).toHaveBeenCalledWith();
    expect(createClient).toHaveBeenCalledWith();
  });

  it("retrieves an optional authenticated user", async () => {
    getUser.mockResolvedValue({ data: { user }, error: null });
    expect(await getOptionalAuthenticatedUser()).toEqual(user);
  });

  it("requires verified identity for protected operations", async () => {
    getUser.mockResolvedValue({ data: { user }, error: null });
    expect(await requireAuthenticatedUser()).toEqual(user);
  });

  it.each([
    null,
    new AuthSessionMissingError(),
    new AuthApiError("invalid", 401, "bad_jwt"),
    new AuthApiError("revoked", 400, "refresh_token_not_found"),
    new AuthApiError("expired", 400, "session_expired"),
  ])("denies missing or invalid identity (%s)", async (error) => {
    getUser.mockResolvedValue({ data: { user: null }, error });
    expect(await getOptionalAuthenticatedUser()).toBeNull();
    await expect(requireAuthenticatedUser()).rejects.toBeInstanceOf(AuthenticationRequiredError);
    await expect(requireAuthenticatedUser()).rejects.toMatchObject({ code: "AUTH_REQUIRED" });
  });

  it("does not accept a user alongside an authentication error", async () => {
    getUser.mockResolvedValue({ data: { user }, error: new AuthApiError("invalid", 401, "bad_jwt") });
    expect(await getVerifiedSession()).toBeNull();
  });

  it("fails closed and sanitizes provider errors", async () => {
    getUser.mockResolvedValue({ data: { user }, error: new AuthApiError("sensitive provider detail", 503, "unexpected_failure") });
    await expect(requireAuthenticatedUser()).rejects.toEqual(new AuthenticationUnavailableError());
  });

  it("sanitizes unexpected network failures", async () => {
    getUser.mockRejectedValue(new Error("sensitive network detail"));
    await expect(getVerifiedSession()).rejects.toEqual(new AuthenticationUnavailableError());
  });

  it("does not retain identity across requests", async () => {
    getUser.mockResolvedValueOnce({ data: { user }, error: null });
    getUser.mockResolvedValueOnce({ data: { user: { ...user, id: "verified-user-b" } }, error: null });
    expect((await requireAuthenticatedUser()).id).toBe(user.id);
    expect((await requireAuthenticatedUser()).id).toBe("verified-user-b");
    expect(createClient).toHaveBeenCalledTimes(2);
  });
});

