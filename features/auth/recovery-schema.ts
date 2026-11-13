import { z } from "zod";

export const recoveryEmailSchema = z.object({ email: z.string().trim().pipe(z.email()) });
// Provider-issued token hashes only; token validity/expiry is checked by Supabase.
export const tokenHashSchema = z.string().min(1).max(2048).regex(/^[a-zA-Z0-9_-]+$/);
export const resetPasswordSchema = z.object({
  token_hash: tokenHashSchema,
  password: z.string().min(1).max(1024),
  confirmation: z.string(),
}).refine((input) => input.password === input.confirmation, { path: ["confirmation"] });

export type RecoveryState = { error: string | null; message: string | null; invalid?: boolean; completed?: boolean };
