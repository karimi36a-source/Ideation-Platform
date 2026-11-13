"use client";

import { useActionState } from "react";
import { login, logout } from "@/features/auth/actions";
import type { AuthFormState } from "@/features/auth/schema";

const initialState: AuthFormState = { error: null };

export function LoginForm() {
  const [state, action, pending] = useActionState(login, initialState);
  return (
    <form action={action} aria-busy={pending}>
      <p>
        <label htmlFor="email">Email</label><br />
        <input id="email" name="email" type="email" autoComplete="username" required
          aria-describedby={state.error ? "login-error" : undefined} />
      </p>
      <p>
        <label htmlFor="password">Password</label><br />
        <input id="password" name="password" type="password" autoComplete="current-password" required
          aria-describedby={state.error ? "login-error" : undefined} />
      </p>
      {state.error && <p id="login-error" role="alert">{state.error}</p>}
      <button type="submit" disabled={pending}>{pending ? "Signing in…" : "Sign in"}</button>
    </form>
  );
}

export function LogoutForm() {
  const [state, action, pending] = useActionState(logout, initialState);
  return (
    <form action={action} aria-busy={pending}>
      {state.error && <p role="alert">{state.error}</p>}
      <button type="submit" disabled={pending}>{pending ? "Signing out…" : "Sign out"}</button>
    </form>
  );
}
