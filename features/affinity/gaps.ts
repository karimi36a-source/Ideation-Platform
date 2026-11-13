import "server-only";
import { AuthorizationError, getAuthorizationContext } from "@/lib/auth/authorization";
import { createServerSupabaseClient } from "@/lib/db/server";
import { captureGapSchema, capturedGapSchema, type CapturedGap } from "./gap-schema";
import { AffinityActivityStateError } from "./service";
export class GapCaptureConflictError extends Error { readonly code = "CONFLICT"; constructor() { super("Gap capture conflict."); } }

export async function captureGap(input: unknown): Promise<CapturedGap> {
 try {
  const actor = await getAuthorizationContext();
  const parsed = captureGapSchema.safeParse(input);
  if (!parsed.success) throw new AuthorizationError("VALIDATION_ERROR");
  const db = await createServerSupabaseClient();
  if ((await getAuthorizationContext()).userId !== actor.userId) throw new AuthorizationError("NOT_FOUND");
  const { data, error } = await db.rpc("capture_gap", { input: parsed.data });
  if ((await getAuthorizationContext()).userId !== actor.userId) throw new AuthorizationError("NOT_FOUND");
  if (error) {
   if (["23505", "40001"].includes(error.code)) throw new GapCaptureConflictError();
   if (error.code === "55000") throw new AffinityActivityStateError();
   throw new AuthorizationError(error.code === "28000" ? "AUTH_REQUIRED" : error.code === "22023" ? "VALIDATION_ERROR" : "NOT_FOUND");
  }
  const result = capturedGapSchema.safeParse(data);
  if (!result.success) throw new AuthorizationError("NOT_FOUND");
  const { gap, artifact, version, membershipChanged, replayed } = result.data;
  if (gap.object_type !== "GAP" || gap.archived_at !== null || artifact.artifact_type !== "GAP_LIST"
   || artifact.activity_instance_id !== parsed.data.activityInstanceId || version.artifact_id !== artifact.id
   || gap.project_id !== artifact.project_id || gap.workspace_id !== artifact.workspace_id
   || (parsed.data.mode === "ADD_EXISTING" && gap.id !== parsed.data.gapObjectId)
   || (!replayed && membershipChanged && (version.status !== "DRAFT" || version.created_by !== actor.userId))
   || (parsed.data.mode === "CREATE_NEW" && gap.created_by !== actor.userId)) throw new AuthorizationError("NOT_FOUND");
  return result.data;
 } catch (error) {
  if (error instanceof GapCaptureConflictError || error instanceof AffinityActivityStateError) throw error;
  throw new AuthorizationError(error instanceof AuthorizationError && ["AUTH_REQUIRED", "VALIDATION_ERROR"].includes(error.code) ? error.code : "NOT_FOUND");
 }
}
