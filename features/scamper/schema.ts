import {z} from "zod";

export const scamperLensSchema=z.enum(["SUBSTITUTE","COMBINE","ADAPT","MODIFY","PUT_TO_ANOTHER_USE","ELIMINATE","REVERSE_REARRANGE"]);
export const scamperEntryStatusSchema=z.enum(["active","archived"]);
/** Canonical stored row only; no client write contract or promotion behavior. */
export const scamperEntrySchema=z.strictObject({
 id:z.uuid(),activity_instance_id:z.uuid(),project_id:z.uuid(),workspace_id:z.uuid(),created_by:z.uuid(),
 scamper_type:scamperLensSchema,original_element:z.string(),proposed_change:z.string(),result_text:z.string(),
 idea_object_id:z.uuid().nullable(),status:scamperEntryStatusSchema,
 created_at:z.iso.datetime({offset:true}),updated_at:z.iso.datetime({offset:true}),updated_by:z.uuid(),
 archived_at:z.iso.datetime({offset:true}).nullable(),
}).refine(row=>row.status==="active"?row.archived_at===null:row.archived_at!==null,{message:"Invalid SCAMPER archive state"});
export type ScamperEntry=z.infer<typeof scamperEntrySchema>;
