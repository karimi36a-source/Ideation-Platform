import type { ReactNode } from "react";
import { requireProtectedAccount } from "@/lib/auth/protected-account";

export const dynamic = "force-dynamic";

export default async function PlatformLayout({ children }: { children: ReactNode }) {
  await requireProtectedAccount();
  return children;
}
