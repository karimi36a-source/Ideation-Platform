import {z} from "zod";
export const enrollmentRoleSchema=z.enum(["participant","instructor"]);
export const enrollmentStatusSchema=z.enum(["invited","active","completed","withdrawn","removed"]);
export const enrollUserSchema=z.strictObject({cohortId:z.uuid(),userId:z.uuid(),enrollmentRole:enrollmentRoleSchema,status:z.enum(["invited","active"]).default("active")});
export const removeEnrollmentSchema=z.strictObject({enrollmentId:z.uuid()});
export const transitionEnrollmentSchema=z.strictObject({enrollmentId:z.uuid(),status:enrollmentStatusSchema});
export const enrollmentSchema=z.object({id:z.uuid(),cohort_id:z.uuid(),user_id:z.uuid(),enrollment_role:enrollmentRoleSchema,status:enrollmentStatusSchema,joined_at:z.iso.datetime({offset:true}).nullable(),completed_at:z.iso.datetime({offset:true}).nullable(),created_at:z.iso.datetime({offset:true}),updated_at:z.iso.datetime({offset:true})}).refine(e=>
 (e.status!=="invited"||e.joined_at===null)&&(!["active","completed"].includes(e.status)||e.joined_at!==null)&&(e.status!=="completed"||e.completed_at!==null)&&(!["invited","active"].includes(e.status)||e.completed_at===null)&&(e.completed_at===null||(e.joined_at!==null&&Date.parse(e.completed_at)>=Date.parse(e.joined_at))));
export type Enrollment=z.infer<typeof enrollmentSchema>;
