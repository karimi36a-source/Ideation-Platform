"use client";

import { createBrowserClient } from "@supabase/ssr";
import type { Database } from "@/lib/db/database.types";
import { getPublicEnv } from "@/lib/validation/env-public";
import { getAuthCookieOptions } from '@/lib/auth/cookie-options';

export function createBrowserSupabaseClient() {
  const env = getPublicEnv();
  return createBrowserClient<Database>(
    env.NEXT_PUBLIC_SUPABASE_URL,
    env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY,
    {cookieOptions:getAuthCookieOptions()},
  );
}

