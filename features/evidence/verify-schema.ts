import {z} from "zod";
import {evidenceVerificationStatusSchema} from "./schema";
export const verifyEvidenceSchema=z.strictObject({evidenceId:z.uuid().transform(value=>value.toLowerCase()),verificationStatus:evidenceVerificationStatusSchema,note:z.string().trim().min(1).optional()});
export const evidenceVerificationHistorySchema=z.strictObject({id:z.uuid(),evidence_id:z.uuid(),previous_status:evidenceVerificationStatusSchema,new_status:evidenceVerificationStatusSchema,verified_by:z.uuid(),verified_at:z.iso.datetime({offset:true}),note:z.string().refine(value=>value.trim().length>0).nullable()}).refine(row=>row.previous_status!==row.new_status);
export type EvidenceVerificationHistory=z.infer<typeof evidenceVerificationHistorySchema>;
