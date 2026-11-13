import "server-only";

import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";
import type { Database } from "@/lib/db/database.types";
import { getServerEnv } from "@/lib/validation/env-server";
import { getAuthCookieOptions } from '@/lib/auth/cookie-options';

/** Create a fresh, user-scoped client for each request. Never use an admin key. */
export async function createServerSupabaseClient() {
  const env = getServerEnv();
  const cookieStore = await cookies();

  return createServerClient<Database>(
    env.NEXT_PUBLIC_SUPABASE_URL,
    env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY,
    {
      cookieOptions: getAuthCookieOptions(),
      cookies: {
        getAll() {
          return cookieStore.getAll();
        },
        setAll(cookiesToSet) {
          try {
            for (const { name, value, options } of cookiesToSet) {
              cookieStore.set(name, value, options);
            }
          } catch (error) {
            // Server Components cannot write cookies. The Proxy persists
            // refresh cookies before rendering; actions/handlers write here.
            if (
              error instanceof Error &&
              error.message.includes(
                "Cookies can only be modified in a Server Action or Route Handler",
              )
            ) {
              return;
            }
            throw error;
          }
        },
      },
    },
  );
}

