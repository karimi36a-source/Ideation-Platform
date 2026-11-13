"use server";

import { revalidatePath } from "next/cache";
import { createServerSupabaseClient } from "@/lib/db/server";
import { getAuthSiteUrl } from "@/lib/auth/site-url";
import { recoveryEmailSchema, resetPasswordSchema, type RecoveryState } from "./recovery-schema";

export async function requestPasswordReset(_previous: RecoveryState, form: FormData): Promise<RecoveryState> {
  const parsed = recoveryEmailSchema.safeParse({ email: form.get("email") });
  if (!parsed.success) return { error: "Enter a valid email address.", message: null };
  let origin: string;
  try { origin = getAuthSiteUrl(); }
  catch { return { error: "Password recovery is temporarily unavailable. Please try again later.", message: null }; }
  try {
    const client = await createServerSupabaseClient();
    await client.auth.resetPasswordForEmail(parsed.data.email, { redirectTo: `${origin}/reset-password` });
  } catch {
    // Identical response for absent accounts, rate limits and provider failures.
    // Never return provider messages or log email/token/password values.
  }
  return { error: null, message: "If an eligible account exists, a password reset email has been requested. Check your inbox." };
}

export async function resetPassword(_previous: RecoveryState, form: FormData): Promise<RecoveryState> {
  const parsed = resetPasswordSchema.safeParse({
    token_hash: form.get("token_hash"), password: form.get("password"), confirmation: form.get("confirmation"),
  });
  if (!parsed.success) return { error: "Enter a new password and matching confirmation using a valid reset link.", message: null };
  let client: Awaited<ReturnType<typeof createServerSupabaseClient>> | undefined;
  let recoveryEstablished = false;
  try {
    client = await createServerSupabaseClient();
    // Consume the provider's one-time recovery token only on submission, so email
    // previews/GET requests cannot consume it. An ordinary login is insufficient.
    const verified = await client.auth.verifyOtp({ token_hash: parsed.data.token_hash, type: "recovery" });
    if (verified.error || !verified.data.user || !verified.data.session) {
      return { error: "This reset link is invalid or expired. Request a new reset email.", message: null, invalid: true };
    }
    recoveryEstablished = true;
    const user = await client.auth.getUser();
    if (user.error || user.data.user?.id !== verified.data.user.id) {
      await client.auth.signOut({ scope: "local" });
      return { error: "This reset link is invalid or expired. Request a new reset email.", message: null, invalid: true };
    }
    const updated = await client.auth.updateUser({ password: parsed.data.password });
    const ended = await client.auth.signOut({ scope: "local" });
    revalidatePath("/", "layout");
    if (updated.error || !updated.data.user) {
      return { error: "The password could not be updated. Check the password requirements and request a new reset email.", message: null, invalid: true };
    }
    if (ended.error) return { error: "Password updated, but sign-out could not be confirmed. Sign out before leaving this device.", message: null, completed: true };
    return { error: null, message: "Password updated. Sign in with your new password.", completed: true };
  } catch {
    if (client && recoveryEstablished) {
      try { await client.auth.signOut({ scope: "local" }); } catch { /* No provider/token details are logged. */ }
    }
    return { error: "Recovery could not be completed. Request a new reset email and try again.", message: null, invalid: true };
  }
}
