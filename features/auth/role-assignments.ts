import "server-only";
import { z } from "zod";
import { createServerSupabaseClient } from "@/lib/db/server";
import { requireActivePlatformUser } from "@/features/users/service";
import { roleAssignmentSchema, type RoleAssignment } from "./role-assignments-schema";

export class RoleAssignmentReadError extends Error {
  readonly code = "EXTERNAL_PROVIDER_ERROR";
  constructor() { super("Unable to resolve role assignments."); this.name = "RoleAssignmentReadError"; }
}

/** Reads the caller's current bindings with every scope intact. This does not
 * decide permissions, scope inheritance, or the meaning of multiple scope IDs.
 * No client identity, role, scope or as-of timestamp is accepted. */
export async function getActiveRoleAssignments(): Promise<RoleAssignment[]> {
  const user = await requireActivePlatformUser();
  try {
    const client = await createServerSupabaseClient();
    const { data, error } = await client.rpc("get_active_role_assignments");
    if (error) throw new RoleAssignmentReadError();
    const parsed = z.array(roleAssignmentSchema).safeParse(data);
    if (!parsed.success || parsed.data.some((row) => row.user_id !== user.id || row.status !== "active")) {
      throw new RoleAssignmentReadError();
    }
    // The invoker RPC/RLS checks starts_at and ends_at against database time.
    return parsed.data;
  } catch { throw new RoleAssignmentReadError(); }
}
