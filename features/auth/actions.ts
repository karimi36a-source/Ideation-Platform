"use server";

import { redirect } from "next/navigation";
import { revalidatePath } from "next/cache";
import { createServerSupabaseClient } from "@/lib/db/server";
import { loginSchema, type AuthFormState } from "@/features/auth/schema";

export async function login(_previous: AuthFormState, form: FormData): Promise<AuthFormState> {
  const parsed = loginSchema.safeParse({ email: form.get("email"), password: form.get("password") });
  if (!parsed.success) return { error: "Enter a valid email address and password." };
  try {
    const client = await createServerSupabaseClient();
    const { data, error } = await client.auth.signInWithPassword(parsed.data);
    if (error || !data.user || !data.session) {
      return { error: "Unable to sign in. Check your email and password and try again." };
    }
  } catch {
    return { error: "Unable to sign in. Check your email and password and try again." };
  }
  revalidatePath("/", "layout");
  // Fixed internal destination; client-supplied return URLs are never consumed.
  redirect("/account");
}

export async function logout(): Promise<AuthFormState> {
  try {
    const client = await createServerSupabaseClient();
    const { error } = await client.auth.signOut({ scope: "local" });
    if (error) return { error: "Unable to sign out. Please try again." };
  } catch {
    return { error: "Unable to sign out. Please try again." };
  }
  revalidatePath("/", "layout");
  redirect("/login");
}

