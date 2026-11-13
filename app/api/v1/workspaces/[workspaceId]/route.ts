import { NextResponse } from "next/server";
import { getWorkspace } from "@/features/workspaces/service";
import { AuthorizationError, type ApiResult } from "@/lib/auth/authorization";
import type { Workspace } from "@/features/workspaces/schema";

export const dynamic = "force-dynamic";
const headers = { "Cache-Control": "private, no-store" };

/** Metadata only; the existing service owns identity, access checks and RLS. */
export async function GET(
  _request: Request,
  context: { params: Promise<{ workspaceId: string }> },
) {
  try {
    const { workspaceId } = await context.params;
    const data = await getWorkspace(workspaceId);
    return NextResponse.json<ApiResult<Workspace>>({ ok: true, data }, { headers });
  } catch (error) {
    const code = error instanceof AuthorizationError &&
      (error.code === "AUTH_REQUIRED" || error.code === "VALIDATION_ERROR")
      ? error.code : "FORBIDDEN";
    const safe = new AuthorizationError(code);
    return NextResponse.json<ApiResult<Workspace>>(
      { ok: false, error: { code: safe.code, message: safe.message } },
      { status: code === "AUTH_REQUIRED" ? 401 : code === "VALIDATION_ERROR" ? 400 : 403, headers },
    );
  }
}
