import { z } from "zod";

export const dependencyTypeSchema = z.enum(["completion", "approved_output", "artifact_available", "gate_passed"]);
export const dependencyInputSchema = z.strictObject({
  required_activity_definition_id: z.uuid(),
  dependency_type: dependencyTypeSchema,
  required_artifact_type: z.string().trim().min(1).nullable(),
  is_mandatory: z.boolean(),
});
export const dependencySchema = dependencyInputSchema.extend({
  id: z.uuid(), activity_definition_id: z.uuid(),
  created_at: z.iso.datetime({ offset: true }), updated_at: z.iso.datetime({ offset: true }),
}).refine(row => row.activity_definition_id !== row.required_activity_definition_id);
export type ActivityDependency = z.infer<typeof dependencySchema>;
