import Link from "next/link";

export default async function VerificationPage({ searchParams }: { searchParams: Promise<{ status?: string }> }) {
  const { status } = await searchParams;
  const message = status === "verified" ? "Email verified. You can sign in." : status === "invalid" ?
    "This verification link is invalid or expired. Contact your account administrator for a new verification email." :
    "Email verification pending. Check your inbox for the verification email before signing in.";
  return <main><h1>Email verification</h1><p role="status">{message}</p><Link href="/login">Sign in</Link></main>;
}
