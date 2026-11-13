import "server-only";
import { AuthorizationError, getAuthorizationContext } from "@/lib/auth/authorization";
import { createServerSupabaseClient } from "@/lib/db/server";
import { confirmAffinityStructureSchema, affinityStructureResultSchema, type AffinityStructureResult } from "./structure-schema";
import { AffinityActivityStateError } from "./service";
export class AffinityStructureConflictError extends Error { readonly code = "CONFLICT"; constructor() { super("Affinity confirmation conflict."); } }

export async function confirmAffinityStructure(input: unknown): Promise<AffinityStructureResult> {
 try {
 const actor = await getAuthorizationContext();
 const parsed = confirmAffinityStructureSchema.safeParse(input);
 if (!parsed.success) throw new AuthorizationError("VALIDATION_ERROR");
 const db = await createServerSupabaseClient();
 if ((await getAuthorizationContext()).userId !== actor.userId) throw new AuthorizationError("NOT_FOUND");
 const { data, error } = await db.rpc("confirm_affinity_structure", { input: parsed.data });
 if ((await getAuthorizationContext()).userId !== actor.userId) throw new AuthorizationError("NOT_FOUND");
 if (error) {
  if (["23505", "40001"].includes(error.code)) throw new AffinityStructureConflictError();
  if (error.code === "55000") throw new AffinityActivityStateError();
  throw new AuthorizationError(error.code === "28000" ? "AUTH_REQUIRED" : error.code === "22023" ? "VALIDATION_ERROR" : "NOT_FOUND");
 }
 const result = affinityStructureResultSchema.safeParse(data);
 if (!result.success || result.data.artifact.artifact_type !== "INVENTION_STRUCTURE"
  || result.data.artifact.activity_instance_id !== parsed.data.activityInstanceId
  || result.data.version.artifact_id !== result.data.artifact.id) throw new AuthorizationError("NOT_FOUND");
 return result.data;
 } catch (error) {
  if (error instanceof AffinityStructureConflictError || error instanceof AffinityActivityStateError) throw error;
  throw new AuthorizationError(error instanceof AuthorizationError && ["AUTH_REQUIRED", "VALIDATION_ERROR"].includes(error.code) ? error.code : "NOT_FOUND");
 }
}
