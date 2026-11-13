import "server-only";

import { requireAuthenticatedUser } from "@/lib/auth/session";
import { createServerSupabaseClient } from "@/lib/db/server";
import { updateOwnProfileSchema, userProfileSchema, type UserProfile } from "@/features/users/schema";

export class ProfileError extends Error {
  constructor(readonly code: "NOT_FOUND" | "VALIDATION_ERROR" | "EXTERNAL_PROVIDER_ERROR") {
    super(code === "NOT_FOUND" ? "Profile unavailable." : code === "VALIDATION_ERROR" ? "Invalid profile update." : "Unable to access profile.");
    this.name = "ProfileError";
  }
}

export class AccountAccessError extends Error {
  readonly code = "FORBIDDEN";
  constructor(readonly reason: "missing_profile" | "invited" | "suspended" | "archived") {
    super("Platform account access is unavailable.");
    this.name = "AccountAccessError";
  }
}

function requireActiveProfile(profile: UserProfile): UserProfile {
  if (profile.account_status !== "active") throw new AccountAccessError(profile.account_status);
  return profile;
}

/** Fresh database state, not JWT metadata or client-submitted status. */
export async function requireActivePlatformUser(): Promise<UserProfile> {
  try { return requireActiveProfile(await getCurrentUser()); }
  catch (error) {
    if (error instanceof ProfileError && error.code === "NOT_FOUND") throw new AccountAccessError("missing_profile");
    throw error;
  }
}

/** Authenticated platform profile only; later membership/role scopes are not fabricated. */
export async function getCurrentUser(): Promise<UserProfile> {
  const user = await requireAuthenticatedUser();
  const client = await createServerSupabaseClient();
  const { data, error } = await client.from("users").select("*").eq("id", user.id).maybeSingle();
  if (error) throw new ProfileError("EXTERNAL_PROVIDER_ERROR");
  if (!data) throw new ProfileError("NOT_FOUND");
  const parsed = userProfileSchema.safeParse(data);
  if (!parsed.success || parsed.data.id !== user.id) throw new ProfileError("EXTERNAL_PROVIDER_ERROR");
  return parsed.data;
}

export async function updateOwnProfile(input: unknown): Promise<UserProfile> {
  const user = await requireAuthenticatedUser();
  const parsed = updateOwnProfileSchema.safeParse(input);
  if (!parsed.success) throw new ProfileError("VALIDATION_ERROR");
  const client = await createServerSupabaseClient();
  const current = await client.from("users").select("*").eq("id", user.id).maybeSingle();
  if (current.error) throw new ProfileError("EXTERNAL_PROVIDER_ERROR");
  if (!current.data) throw new AccountAccessError("missing_profile");
  const currentProfile = userProfileSchema.safeParse(current.data);
  if (!currentProfile.success || currentProfile.data.id !== user.id) throw new ProfileError("EXTERNAL_PROVIDER_ERROR");
  requireActiveProfile(currentProfile.data);
  const { data, error } = await client.from("users").update(parsed.data).eq("id", user.id).select("*").maybeSingle();
  if (error) throw new ProfileError("EXTERNAL_PROVIDER_ERROR");
  if (!data) throw new ProfileError("NOT_FOUND");
  const profile = userProfileSchema.safeParse(data);
  if (!profile.success || profile.data.id !== user.id) throw new ProfileError("EXTERNAL_PROVIDER_ERROR");
  return requireActiveProfile(profile.data);
}
