import "server-only";
import { z } from "zod";
import { requireActivePlatformUser } from "@/features/users/service";
import { getActiveRoleAssignments } from "@/features/auth/role-assignments";
import { roleAssignmentSchema, type RoleAssignment } from "@/features/auth/role-assignments-schema";
import { roleCodeSchema, SYSTEM_ROLE_CODES, SYSTEM_ROLE_IDS, type RoleCode } from "./role-codes";

export type AuthorizationErrorCode = "AUTH_REQUIRED" | "FORBIDDEN" | "NOT_FOUND" | "VALIDATION_ERROR";
const messages: Record<AuthorizationErrorCode, string> = {
  AUTH_REQUIRED: "Authentication required.", FORBIDDEN: "Access denied.",
  NOT_FOUND: "Resource unavailable.", VALIDATION_ERROR: "Invalid authorization request.",
};
export class AuthorizationError extends Error {
  constructor(readonly code: AuthorizationErrorCode) { super(messages[code]); this.name = "AuthorizationError"; }
}
export type ApiResult<T> = { ok: true; data: T } | { ok: false; error: { code: AuthorizationErrorCode; message: string } };

export type ScopeType = "organization" | "program" | "cohort" | "team" | "project";
export type AccessCategory = "operational" | "educational";
export type AuthorizationBinding = Readonly<RoleAssignment & { roleCode: RoleCode }>;
export type AuthorizationContext = Readonly<{ userId: string; assignments: readonly AuthorizationBinding[] }>;
export type AuthorizationResource = Readonly<{
  id: string;
  scope: Readonly<{ type: ScopeType; id: string }>;
  access: AccessCategory;
  /** Must come from the operation's approved resource rules, never client input. */
  resourcePolicyAllows: boolean;
}>;
export type AuthorizedResource = Readonly<{ context: AuthorizationContext; resource: AuthorizationResource }>;

const scopeTypeSchema = z.enum(["organization", "program", "cohort", "team", "project"]);
const accessSchema = z.enum(["operational", "educational"]);
const policySchema = z.strictObject({ role: roleCodeSchema, scopeType: scopeTypeSchema, access: accessSchema });
const resourceSchema = z.strictObject({
  id: z.uuid(), scope: z.strictObject({ type: scopeTypeSchema, id: z.uuid() }),
  access: accessSchema, resourcePolicyAllows: z.boolean(),
});
const scopeFields = {
  organization: "organization_id", program: "program_id", cohort: "cohort_id", team: "team_id", project: "project_id",
} as const;
type PolicyConfiguration = z.infer<typeof policySchema>;
type ResourceResolver = (id: string, context: AuthorizationContext) => Promise<AuthorizationResource | null>;
declare const policyBrand: unique symbol;
export type ScopedRolePolicy = Readonly<{ [policyBrand]: true }>;
const policies = new WeakMap<ScopedRolePolicy, { configuration: PolicyConfiguration; resolve: ResourceResolver }>();

/** Call only from trusted server code with a static operation policy and a
 * database/RLS-backed metadata resolver. Never define policies from request data.
 * The opaque registered handle cannot be reconstructed from browser JSON. */
export function defineScopedRolePolicy(configuration: PolicyConfiguration, resolve: ResourceResolver): ScopedRolePolicy {
  const parsed = policySchema.safeParse(configuration);
  if (!parsed.success || typeof resolve !== "function") throw new AuthorizationError("VALIDATION_ERROR");
  const policy = Object.freeze({}) as ScopedRolePolicy;
  policies.set(policy, { configuration: Object.freeze(parsed.data), resolve });
  return policy;
}

function currentBinding(row: RoleAssignment, now: number) {
  return row.status === "active" && Date.parse(row.starts_at) <= now &&
    (row.ends_at === null || Date.parse(row.ends_at) > now);
}
function singleScope(row: RoleAssignment) {
  return Object.values(scopeFields).filter((field) => row[field] !== null).length === 1;
}

/** Fresh verified session/profile and database-filtered bindings, no caller claims.
 * Contexts are immutable snapshots for inspection, not inputs to authorization.
 * Each authorization call below resolves a new context independently. */
export async function getAuthorizationContext(): Promise<AuthorizationContext> {
  try {
    const user = await requireActivePlatformUser();
    const parsed = z.array(roleAssignmentSchema).safeParse(await getActiveRoleAssignments());
    if (!parsed.success || parsed.data.some((row) => row.user_id !== user.id)) throw new AuthorizationError("FORBIDDEN");
    const now = Date.now();
    const assignments: AuthorizationBinding[] = [];
    for (const row of parsed.data) {
      if (!currentBinding(row, now) || !singleScope(row)) continue;
      const roleCode = SYSTEM_ROLE_CODES.find((code) => SYSTEM_ROLE_IDS[code] === row.role_id);
      if (!roleCode) throw new AuthorizationError("FORBIDDEN");
      assignments.push(Object.freeze({ ...row, roleCode }));
    }
    return Object.freeze({ userId: user.id, assignments: Object.freeze(assignments) });
  } catch (error) { throw normalizeError(error); }
}

function normalizeError(error: unknown): AuthorizationError {
  if (error instanceof AuthorizationError) {
    // Error instances are mutable at runtime; never forward their message/code blindly.
    const code = error.code;
    return new AuthorizationError(Object.hasOwn(messages, code) ? code : "FORBIDDEN");
  }
  if (error && typeof error === "object" && "code" in error && error.code === "AUTH_REQUIRED") {
    return new AuthorizationError("AUTH_REQUIRED");
  }
  // Includes account/provider failures: fail closed without provider diagnostics.
  return new AuthorizationError("FORBIDDEN");
}

/** Checks one registered server operation against a trusted resource descriptor. */
export async function requireScopedRole(policy: ScopedRolePolicy, resourceId: unknown): Promise<AuthorizedResource> {
  const registered = policies.get(policy);
  const id = z.uuid().safeParse(resourceId);
  if (!registered || !id.success) throw new AuthorizationError("VALIDATION_ERROR");
  const context = await getAuthorizationContext();
  const { configuration } = registered;
  // ADMIN is operational authority, never an implicit educational-content grant.
  if (configuration.role === "ADMIN" && configuration.access === "educational") throw new AuthorizationError("FORBIDDEN");
  if (!context.assignments.some((row) => row.roleCode === configuration.role && row[scopeFields[configuration.scopeType]] !== null)) {
    throw new AuthorizationError("FORBIDDEN");
  }
  let raw: AuthorizationResource | null;
  try { raw = await registered.resolve(id.data, context); }
  catch { throw new AuthorizationError("FORBIDDEN"); }
  const parsed = resourceSchema.safeParse(raw);
  if (!parsed.success || parsed.data.id !== id.data || !parsed.data.resourcePolicyAllows ||
      parsed.data.access !== configuration.access || parsed.data.scope.type !== configuration.scopeType) {
    // Missing, inaccessible, malformed and scope-mismatched resources look alike.
    throw new AuthorizationError("FORBIDDEN");
  }
  // Metadata resolution may await I/O. Re-read identity/profile/bindings before
  // granting access so a deactivation during that await cannot reuse a snapshot.
  const latest = await getAuthorizationContext();
  if (latest.userId !== context.userId) throw new AuthorizationError("FORBIDDEN");
  const now = Date.now();
  const allowed = latest.assignments.some((row) => row.roleCode === configuration.role &&
    currentBinding(row, now) && singleScope(row) && row[scopeFields[configuration.scopeType]] === parsed.data.scope.id);
  if (!allowed) throw new AuthorizationError("FORBIDDEN");
  const resource = Object.freeze({ ...parsed.data, scope: Object.freeze(parsed.data.scope) });
  return Object.freeze({ context: latest, resource });
}

export async function hasScopedRole(policy: ScopedRolePolicy, resourceId: unknown): Promise<boolean> {
  try { await requireScopedRole(policy, resourceId); return true; }
  catch (error) {
    const normalized = normalizeError(error);
    if (normalized.code === "FORBIDDEN" || normalized.code === "NOT_FOUND") return false;
    throw normalized;
  }
}

export async function requireAdminScope(policy: ScopedRolePolicy, resourceId: unknown): Promise<AuthorizedResource> {
  const registered = policies.get(policy);
  if (!registered || registered.configuration.role !== "ADMIN" || registered.configuration.access !== "operational") {
    throw new AuthorizationError("VALIDATION_ERROR");
  }
  return requireScopedRole(policy, resourceId);
}

/** Safe API error envelope; never serializes thrown diagnostics or resource details.
 * NOT_FOUND may be used by an operation only after access has been established. */
export async function asAuthorizationResult<T>(operation: () => Promise<T>): Promise<ApiResult<T>> {
  try { return { ok: true, data: await operation() }; }
  catch (error) {
    const normalized = normalizeError(error);
    return { ok: false, error: { code: normalized.code, message: normalized.message } };
  }
}

