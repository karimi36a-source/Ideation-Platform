import { z } from "zod";

export const roleAssignmentStatusSchema = z.enum(["active", "inactive"]);
export const roleAssignmentSchema = z.object({
  id: z.uuid(), user_id: z.uuid(), role_id: z.uuid(),
  organization_id: z.uuid().nullable(), program_id: z.uuid().nullable(),
  cohort_id: z.uuid().nullable(), team_id: z.uuid().nullable(), project_id: z.uuid().nullable(),
  starts_at: z.iso.datetime({ offset: true }), ends_at: z.iso.datetime({ offset: true }).nullable(),
  status: roleAssignmentStatusSchema, assigned_by: z.uuid(),
  created_at: z.iso.datetime({ offset: true }), updated_at: z.iso.datetime({ offset: true }),
}).refine((row) => [row.organization_id, row.program_id, row.cohort_id, row.team_id, row.project_id].some((scope) => scope !== null), {
  message: "A scoped assignment requires at least one scope.",
}).refine((row) => row.ends_at === null || Date.parse(row.ends_at) > Date.parse(row.starts_at), {
  message: "Invalid assignment validity window.",
});

export type RoleAssignment = z.infer<typeof roleAssignmentSchema>;
