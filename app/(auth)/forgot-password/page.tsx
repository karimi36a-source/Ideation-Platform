import Link from "next/link";
import { ForgotPasswordForm } from "@/features/auth/recovery-forms";

export default function ForgotPasswordPage() {
  return <main><h1>Forgot password</h1><ForgotPasswordForm /><p><Link href="/login">Back to sign in</Link></p></main>;
}
