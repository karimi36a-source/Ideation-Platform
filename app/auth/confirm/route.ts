import { NextResponse, type NextRequest } from "next/server";
import { createServerSupabaseClient } from "@/lib/db/server";
import { tokenHashSchema } from "@/features/auth/recovery-schema";

export async function GET(request: NextRequest) {
  const token = tokenHashSchema.safeParse(request.nextUrl.searchParams.get("token_hash"));
  const type = request.nextUrl.searchParams.get("type");
  let verified = false;
  if (token.success && (type === "signup" || type === "email_change")) {
    try {
      const client = await createServerSupabaseClient();
      const result = await client.auth.verifyOtp({ token_hash: token.data, type });
      verified = !result.error && Boolean(result.data.user);
      // Verification does not establish a persistent product session here.
      if (verified) {
        const ended = await client.auth.signOut({ scope: "local" });
        verified = !ended.error;
      }
    } catch { verified = false; }
  }
  const response = NextResponse.redirect(new URL(`/verification?status=${verified ? "verified" : "invalid"}`, request.url));
  response.headers.set("Cache-Control", "private, no-store");
  response.headers.set("Referrer-Policy", "no-referrer");
  return response;
}
