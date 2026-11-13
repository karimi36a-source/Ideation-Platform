"use client";

import { useActionState } from "react";
import Link from "next/link";
import { requestPasswordReset, resetPassword } from "./recovery-actions";
import type { RecoveryState } from "./recovery-schema";

const initial: RecoveryState = { error: null, message: null };

export function ForgotPasswordForm() {
  const [state, action, pending] = useActionState(requestPasswordReset, initial);
  return <form action={action} aria-busy={pending}>
    <p><label htmlFor="recovery-email">Email</label><br />
      <input id="recovery-email" name="email" type="email" autoComplete="email" required /></p>
    {state.error && <p id="recovery-error" role="alert">{state.error}</p>}
    {state.message && <p role="status">{state.message}</p>}
    <button disabled={pending}>{pending ? "Requesting…" : "Request reset email"}</button>
  </form>;
}

export function ResetPasswordForm({ tokenHash }: { tokenHash: string }) {
  const [state, action, pending] = useActionState(resetPassword, initial);
  return <>
    {!state.invalid && !state.completed && <form action={action} aria-busy={pending}>
      <input type="hidden" name="token_hash" value={tokenHash} />
      <p><label htmlFor="new-password">New password</label><br />
        <input id="new-password" name="password" type="password" autoComplete="new-password" required maxLength={1024} /></p>
      <p><label htmlFor="confirm-password">Confirm new password</label><br />
        <input id="confirm-password" name="confirmation" type="password" autoComplete="new-password" required maxLength={1024} /></p>
      <button disabled={pending}>{pending ? "Updating…" : "Update password"}</button>
    </form>}
    {state.error && <p id="reset-error" role="alert">{state.error}</p>}
    {state.message && <p role="status">{state.message}</p>}
    {state.invalid && <Link href="/forgot-password">Request a new reset email</Link>}
    {state.completed && <Link href="/login">Sign in</Link>}
  </>;
}
