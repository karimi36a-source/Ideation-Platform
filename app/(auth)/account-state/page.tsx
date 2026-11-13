import { redirect } from "next/navigation";
import { AuthenticationRequiredError } from "@/lib/auth/errors";
import { getCurrentUser, ProfileError } from "@/features/users/service";
import { LogoutForm } from "@/features/auth/forms";

export const dynamic = "force-dynamic";

export default async function AccountStatePage() {
  let message: string;
  try {
    const profile = await getCurrentUser();
    if (profile.account_status === "active") redirect("/account");
    message = profile.account_status === "invited" ? "Your account is awaiting activation. Contact your account administrator." :
      profile.account_status === "suspended" ? "Your platform account is suspended. Contact your account administrator." :
      "Your platform account is archived. Contact your account administrator.";
  } catch (error) {
    if (error instanceof AuthenticationRequiredError) redirect("/login");
    if (!(error instanceof ProfileError && error.code === "NOT_FOUND")) throw error;
    message = "Your platform profile has not been provisioned. Contact your account administrator.";
  }
  return <main><h1>Account access unavailable</h1><p>{message}</p><LogoutForm /></main>;
}
