import Link from "next/link";
import { ResetPasswordForm } from "@/features/auth/recovery-forms";
import { tokenHashSchema } from "@/features/auth/recovery-schema";

export const dynamic = "force-dynamic";

export default async function ResetPasswordPage({ searchParams }: {
  searchParams: Promise<{ token_hash?: string | string[]; type?: string | string[] }>;
}) {
  const query = await searchParams;
  const token = tokenHashSchema.safeParse(query.token_hash);
  return <main><h1>Reset password</h1>
    {token.success && query.type === "recovery" ? <ResetPasswordForm tokenHash={token.data} /> :
      <><p>This reset link is invalid or expired. Request a new reset email.</p><Link href="/forgot-password">Request a new reset email</Link></>}
  </main>;
}
