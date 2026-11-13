import "server-only";
import { redirect } from "next/navigation";
import { AuthenticationRequiredError } from "@/lib/auth/errors";
import { AccountAccessError, requireActivePlatformUser } from "@/features/users/service";

/** Route guard. Server mutations use requireActivePlatformUser independently. */
export async function requireProtectedAccount() {
  try { return await requireActivePlatformUser(); }
  catch (error) {
    if (error instanceof AuthenticationRequiredError) redirect("/login");
    if (error instanceof AccountAccessError) redirect("/account-state");
    // Provider/database failures deny access; never turn failure into approval.
    throw error;
  }
}
