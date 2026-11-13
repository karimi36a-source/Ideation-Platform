import "server-only";

import { z } from "zod";
import { getPublicEnv } from "./env-public";

const optionalSecret = z.preprocess(
  (value) => (typeof value === "string" && value.trim() === "" ? undefined : value),
  z.string().trim().min(1).optional(),
);

const serverEnvSchema = z.object({
  SUPABASE_SECRET_KEY: optionalSecret,
  OPENAI_API_KEY: optionalSecret,
  LIVEBLOCKS_SECRET_KEY: optionalSecret,
  DAILY_API_KEY: optionalSecret,
  RESEND_API_KEY: optionalSecret,
  RESEND_FROM_EMAIL: optionalSecret,
});

/** Server-only, lazy validation. Blank optional keys are treated as absent. */
export function getServerEnv() {
  const result = serverEnvSchema.safeParse({
    SUPABASE_SECRET_KEY: process.env.SUPABASE_SECRET_KEY,
    OPENAI_API_KEY: process.env.OPENAI_API_KEY,
    LIVEBLOCKS_SECRET_KEY: process.env.LIVEBLOCKS_SECRET_KEY,
    DAILY_API_KEY: process.env.DAILY_API_KEY,
    RESEND_API_KEY: process.env.RESEND_API_KEY,
    RESEND_FROM_EMAIL: process.env.RESEND_FROM_EMAIL,
  });

  if (!result.success) {
    const names = [...new Set(result.error.issues.map((issue) => issue.path[0]))];
    throw new Error(`Invalid server environment variables: ${names.join(", ")}`);
  }

  return { ...getPublicEnv(), ...result.data };
}
