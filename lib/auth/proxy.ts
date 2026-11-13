import "server-only";

import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";
import { getPublicEnv } from "@/lib/validation/env-public";
import { getAuthCookieOptions } from './cookie-options';
import {
  AuthenticationUnavailableError,
  isMissingOrInvalidSession,
} from "@/lib/auth/errors";

/** Refresh cookies before Server Components render. Does not grant access. */
export async function updateSession(request: NextRequest): Promise<NextResponse> {
  const env = getPublicEnv();
  let response = NextResponse.next({ request });
  response.headers.set("Cache-Control", "private, no-store");

  const supabase = createServerClient(
    env.NEXT_PUBLIC_SUPABASE_URL,
    env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY,
    {
      cookieOptions: getAuthCookieOptions(),
      cookies: {
        getAll: () => request.cookies.getAll(),
        setAll(cookiesToSet, headers) {
          for (const { name, value } of cookiesToSet) {
            request.cookies.set(name, value);
          }
          // Rebuild request overrides with refreshed cookies, preserving every
          // earlier cookie/cache header if the SDK calls setAll more than once.
          const previous = response;
          response = NextResponse.next({ request });
          for (const cookie of previous.cookies.getAll()) {
            response.cookies.set(cookie);
          }
          for (const name of ["cache-control", "expires", "pragma"]) {
            const value = previous.headers.get(name);
            if (value !== null) response.headers.set(name, value);
          }
          for (const { name, value, options } of cookiesToSet) {
            response.cookies.set(name, value, options);
          }
          for (const [name, value] of Object.entries(headers)) {
            response.headers.set(name, value);
          }
        },
      },
    },
  );

  try {
    const { error } = await supabase.auth.getUser();
    if (error && !isMissingOrInvalidSession(error)) {
      throw new AuthenticationUnavailableError();
    }
  } catch (error) {
    if (!isMissingOrInvalidSession(error)) {
      throw new AuthenticationUnavailableError();
    }
  }
  return response;
}
