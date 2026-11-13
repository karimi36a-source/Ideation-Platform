import { NextResponse } from "next/server";
import { AuthorizationError } from "@/lib/auth/authorization";
import { authorizeAffinityCollaboration, AffinityProviderUnavailableError } from "@/features/affinity/collaboration";
export const dynamic = "force-dynamic";
export async function POST(request: Request) {
 const headers = { "Cache-Control": "private, no-store" };
 try {
  const input: unknown = await request.json();
  const data = await authorizeAffinityCollaboration(input);
  return NextResponse.json({ ok: true, data }, { headers });
 } catch (error) {
  const code = error instanceof AffinityProviderUnavailableError ? error.code : error instanceof SyntaxError ? "VALIDATION_ERROR" : error instanceof AuthorizationError && ["AUTH_REQUIRED", "VALIDATION_ERROR"].includes(error.code) ? error.code : "NOT_FOUND";
  return NextResponse.json({ ok: false, error: { code, message: code === "DEPENDENCY_NOT_READY" ? "Collaboration provider unavailable." : new AuthorizationError(code === "AUTH_REQUIRED" ? "AUTH_REQUIRED" : code === "VALIDATION_ERROR" ? "VALIDATION_ERROR" : "NOT_FOUND").message } }, { status: code === "DEPENDENCY_NOT_READY" ? 503 : code === "AUTH_REQUIRED" ? 401 : code === "VALIDATION_ERROR" ? 400 : 404, headers });
 }
}
