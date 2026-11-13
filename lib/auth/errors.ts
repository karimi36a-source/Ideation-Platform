import "server-only";

import { isAuthApiError, isAuthSessionMissingError } from "@supabase/supabase-js";

export class AuthenticationRequiredError extends Error {
  readonly code = "AUTH_REQUIRED";

  constructor() {
    super("Authentication required.");
    this.name = "AuthenticationRequiredError";
  }
}

export class AuthenticationUnavailableError extends Error {
  readonly code = "EXTERNAL_PROVIDER_ERROR";

  constructor() {
    super("Unable to verify authentication.");
    this.name = "AuthenticationUnavailableError";
  }
}

/** Only known credential/session failures are treated as signed out. */
export function isMissingOrInvalidSession(error: unknown): boolean {
  return (
    isAuthSessionMissingError(error) ||
    (isAuthApiError(error) &&
      (error.status === 401 ||
        [
          "bad_jwt",
          "session_not_found",
          "session_expired",
          "refresh_token_not_found",
          "refresh_token_already_used",
          "user_not_found",
        ].includes(error.code ?? "")))
  );
}
