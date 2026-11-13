import { z } from "zod";

export const accountStatusSchema = z.enum(["invited", "active", "suspended", "archived"]);
export const userProfileSchema = z.object({
  id: z.uuid(),
  email: z.string().nullable(),
  display_name: z.string().nullable(),
  first_name: z.string().nullable(),
  last_name: z.string().nullable(),
  profile_image: z.string().nullable(),
  account_status: accountStatusSchema,
  timezone: z.string().nullable(),
  locale: z.string().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
});

// These are the only self-edit fields approved by docs/11_API_CONTRACTS.md.
// profile_image is an opaque reference; this task neither fetches nor renders it.
export const updateOwnProfileSchema = z.strictObject({
  display_name: z.string().trim().min(1).nullable().optional(),
  profile_image: z.string().trim().min(1).nullable().optional(),
  timezone: z.string().trim().min(1).nullable().optional(),
  locale: z.string().trim().min(1).nullable().optional(),
}).refine((value) => Object.values(value).some((field) => field !== undefined), {
  message: "Provide at least one editable profile field.",
});

export type UserProfile = z.infer<typeof userProfileSchema>;
export type UpdateOwnProfileInput = z.infer<typeof updateOwnProfileSchema>;
