import {z} from "zod";
export const brainstormEntryStatusSchema=z.enum(["active","archived"]);
/** Stored row only; no client mutation contract. Status is independent of reveal. */
export const brainstormEntrySchema=z.strictObject({
 id:z.uuid(),activity_instance_id:z.uuid(),project_id:z.uuid(),workspace_id:z.uuid(),created_by:z.uuid(),
 content:z.string(),status:brainstormEntryStatusSchema,revealed_at:z.iso.datetime({offset:true}).nullable(),
 development_object_id:z.uuid().nullable(),parent_entry_id:z.uuid().nullable(),
 created_at:z.iso.datetime({offset:true}),updated_at:z.iso.datetime({offset:true}),updated_by:z.uuid(),
 archived_at:z.iso.datetime({offset:true}).nullable(),
}).refine(row=>row.status==="active"?row.archived_at===null:row.archived_at!==null,{message:"Invalid Brainstorm archive state"})
.refine(row=>row.parent_entry_id!==row.id,{message:"Invalid self parent"});
export type BrainstormEntry=z.infer<typeof brainstormEntrySchema>;
