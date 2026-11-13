import { redirect } from "next/navigation";
import { getOptionalAuthenticatedUser } from "@/lib/auth/session";
import { LoginForm } from "@/features/auth/forms";
import Link from "next/link";

export const dynamic = "force-dynamic";

export default async function LoginPage() {
  if (await getOptionalAuthenticatedUser()) redirect("/account");
  return <main><h1>Sign in to FICI</h1><LoginForm /><p><Link href="/forgot-password">Forgot password?</Link></p><p><Link href="/verification">Email verification help</Link></p></main>;
}
