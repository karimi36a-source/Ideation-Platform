import "server-only";
import { z } from "zod";
import { createServerSupabaseClient } from "@/lib/db/server";
import { AuthorizationError, defineScopedRolePolicy, requireAdminScope } from "@/lib/auth/authorization";
import { curriculumSchema, programSchema } from "@/features/programs/schema";
import { sessionSchema } from "@/features/sessions/schema";
import { activitySchema } from "@/features/activities/schema";
import { dependencyInputSchema, dependencySchema } from "./schema";

async function loadParent(id: string) {
  const client = await createServerSupabaseClient();
  const a = await client.from("activity_definitions").select("*").eq("id", id).maybeSingle();
  const activity = activitySchema.safeParse(a.data);
  if (a.error || !activity.success || activity.data.id !== id) return null;
  const s = await client.from("session_definitions").select("*").eq("id", activity.data.session_definition_id).maybeSingle();
  const session = sessionSchema.safeParse(s.data);
  if (s.error || !session.success || session.data.id !== activity.data.session_definition_id) return null;
  const v = await client.from("curriculum_versions").select("*").eq("id", session.data.curriculum_version_id).maybeSingle();
  const version = curriculumSchema.safeParse(v.data);
  if (v.error || !version.success || version.data.id !== session.data.curriculum_version_id || version.data.status !== "draft") return null;
  const p = await client.from("programs").select("*").eq("id", version.data.program_id).maybeSingle();
  const program = programSchema.safeParse(p.data);
  if (p.error || !program.success || program.data.id !== version.data.program_id) return null;
  return { versionId: version.data.id, organizationId: program.data.organization_id };
}
const policy = defineScopedRolePolicy({ role: "ADMIN", scopeType: "organization", access: "operational" }, async id => {
  const parent = await loadParent(id);
  return parent ? { id, scope: { type: "organization", id: parent.organizationId }, access: "operational", resourcePolicyAllows: true } : null;
});

/** Definition management only; this does not resolve artifacts or gate execution. */
export async function manageActivityDependency(activityId: unknown, dependencyId: unknown, input: unknown) {
  const gate = await requireAdminScope(policy, activityId);
  const fields = dependencyInputSchema.safeParse(input);
  const id = z.uuid().nullable().safeParse(dependencyId);
  if (!fields.success || !id.success || fields.data.required_activity_definition_id === gate.resource.id) throw new AuthorizationError("VALIDATION_ERROR");
  const parent = await loadParent(gate.resource.id);
  const required = await loadParent(fields.data.required_activity_definition_id);
  if (!parent || !required || parent.versionId !== required.versionId || parent.organizationId !== required.organizationId || parent.organizationId !== gate.resource.scope.id) throw new AuthorizationError("FORBIDDEN");
  const client = await createServerSupabaseClient();
  const { data, error } = await client.rpc("manage_activity_dependency", {
    target_activity: gate.resource.id, target_dependency: id.data,
    required_activity: fields.data.required_activity_definition_id, kind: fields.data.dependency_type,
    artifact_type: fields.data.required_artifact_type, mandatory: fields.data.is_mandatory,
  });
  if (error) throw new AuthorizationError(["23514", "23505", "22023", "22P02", "23502"].includes(error.code) ? "VALIDATION_ERROR" : "FORBIDDEN");
  const result = dependencySchema.safeParse(data);
  if (!result.success || result.data.activity_definition_id !== gate.resource.id || result.data.required_activity_definition_id !== fields.data.required_activity_definition_id || (id.data !== null && result.data.id !== id.data)) throw new AuthorizationError("FORBIDDEN");
  return result.data;
}
