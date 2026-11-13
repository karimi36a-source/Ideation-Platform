import { z } from "zod";

const publicEnvSchema = z.object({
  NEXT_PUBLIC_SUPABASE_URL: z.url({ protocol: /^https?$/ }),
  NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY: z
    .string()
    .trim()
    .startsWith("sb_publishable_")
    .min("sb_publishable_".length + 1),
});

/** Validate only when a Supabase client is needed, not when the module loads. */
export function getPublicEnv() {
  // Next.js requires static property access to inline public browser variables.
  const result = publicEnvSchema.safeParse({
    NEXT_PUBLIC_SUPABASE_URL: process.env.NEXT_PUBLIC_SUPABASE_URL,
    NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY:
      process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY,
  });

  if (!result.success) {
    const names = [...new Set(result.error.issues.map((issue) => issue.path[0]))];
    // Report variable names only; never include supplied values.
    throw new Error(`Invalid or missing environment variables: ${names.join(", ")}`);
  }

  return result.data;
}
