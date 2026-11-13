import { requireProtectedAccount } from "@/lib/auth/protected-account";
import { LogoutForm } from "@/features/auth/forms";

export const dynamic = "force-dynamic";

export default async function AccountPage() {
  const user = await requireProtectedAccount();
  return (
    <main>
      <h1>FICI Platform</h1>
      <p>Signed in{user.display_name || user.email ? ` as ${user.display_name || user.email}` : ""}.</p>
      <p><a href="/current-work">My current work</a></p>
      <LogoutForm />
    </main>
  );
}

