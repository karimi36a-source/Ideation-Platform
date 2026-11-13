import { z } from "zod";
export const organizationStatusSchema = z.enum(["active", "inactive", "archived"]);
export const organizationSchema = z.object({
 id:z.uuid(), name:z.string().trim().min(1).max(200), slug:z.string().regex(/^[a-z0-9]+(-[a-z0-9]+)*$/),
 status:organizationStatusSchema, settings:z.record(z.string(),z.unknown()),
 created_at:z.iso.datetime({offset:true}), updated_at:z.iso.datetime({offset:true}),
});
export const organizationUpdateSchema = z.strictObject({ name:z.string().trim().min(1).max(200),status:organizationStatusSchema });
export type Organization = z.infer<typeof organizationSchema>;
