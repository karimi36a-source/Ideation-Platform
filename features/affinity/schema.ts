import {z} from "zod";
const order=z.number().int().positive().max(2147483647);
const timestamp=z.iso.datetime({offset:true});
/** Stored linkage contracts only; provenance never establishes authorization. */
export const affinityGroupSchema=z.strictObject({id:z.uuid(),activity_instance_id:z.uuid(),name:z.string().refine(v=>v.trim().length>0),description:z.string().nullable(),sequence:order,created_by:z.uuid(),created_at:timestamp});
export const affinityGroupItemSchema=z.strictObject({id:z.uuid(),affinity_group_id:z.uuid(),development_object_id:z.uuid().nullable(),brainstorm_entry_id:z.uuid().nullable(),position:order,move_revision:z.number().int().min(0).max(2147483647),added_by:z.uuid(),created_at:timestamp}).refine(v=>(v.development_object_id===null)!==(v.brainstorm_entry_id===null));
export type AffinityGroup=z.infer<typeof affinityGroupSchema>;
export type AffinityGroupItem=z.infer<typeof affinityGroupItemSchema>;
