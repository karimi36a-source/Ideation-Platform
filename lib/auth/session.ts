import "server-only";

import type { User } from "@supabase/supabase-js";
import { createServerSupabaseClient } from "@/lib/db/server";
import {
  AuthenticationRequiredError,
  AuthenticationUnavailableError,
  isMissingOrInvalidSession,
} from "@/lib/auth/errors";

/** Verified request identity only; deliberately excludes access/refresh tokens. */
export type VerifiedSession = { user: User };

export async function getVerifiedSession(): Promise<VerifiedSession | null> {
  const supabase = await createServerSupabaseClient();
  try {
    // getSession() alone trusts cookie storage. getUser() checks with Auth.
    const { data, error } = await supabase.auth.getUser();
    if (error) {
      if (isMissingOrInvalidSession(error)) return null;
      throw new AuthenticationUnavailableError();
    }
    return data.user ? { user: data.user } : null;
  } catch (error) {
    if (isMissingOrInvalidSession(error)) return null;
    // Do not propagate provider diagnostics or token-bearing error details.
    throw new AuthenticationUnavailableError();
  }
}

export async function getOptionalAuthenticatedUser(): Promise<User | null> {
  return (await getVerifiedSession())?.user ?? null;
}

/** Call inside every protected server operation; Proxy is not authorization. */
export async function requireAuthenticatedUser(): Promise<User> {
  const user = await getOptionalAuthenticatedUser();
  if (!user) throw new AuthenticationRequiredError();
  return user;
}
