import { NextResponse, type NextRequest } from "next/server";
import { updateSession } from "@/lib/auth/proxy";

export async function proxy(request: NextRequest) {
  // M0's static landing page has no auth/data usage and needs no credentials.
  // Remove this exemption if the root page ever starts reading auth state.
  if (request.nextUrl.pathname === "/") return NextResponse.next();
  if (["/forgot-password", "/reset-password", "/verification", "/auth/confirm"].includes(request.nextUrl.pathname)) {
    // These public provider-token flows validate identity inside their handler.
    // Avoid refreshing an unrelated session before processing a recovery link.
    const response = NextResponse.next();
    response.headers.set("Cache-Control", "private, no-store");
    response.headers.set("Referrer-Policy", "no-referrer");
    return response;
  }
  // Overwrite caller input; this ID joins only safe application diagnostics.
  request.headers.set('x-fici-correlation-id',crypto.randomUUID());
  return updateSession(request);
}

export const config = {
  matcher: ["/((?!_next/static|_next/image|favicon.ico).*)"],
};
