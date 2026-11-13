import {expect,it} from "vitest";
import {scamperEntrySchema,scamperEntryStatusSchema,scamperLensSchema} from "@/features/scamper/schema";
const id="00000000-0000-4000-8000-000000006004";
const row={id,activity_instance_id:id,project_id:id,workspace_id:id,created_by:id,scamper_type:"SUBSTITUTE",original_element:"Element",proposed_change:"Change",result_text:"Result",idea_object_id:null,status:"active",created_at:"2026-10-08T00:00:00Z",updated_at:"2026-10-08T00:00:00Z",updated_by:id,archived_at:null};
it.each(["SUBSTITUTE","COMBINE","ADAPT","MODIFY","PUT_TO_ANOTHER_USE","ELIMINATE","REVERSE_REARRANGE"])("accepts the approved lens %s",lens=>{
 expect(scamperEntrySchema.parse({...row,scamper_type:lens}).scamper_type).toBe(lens);
});
it("rejects unapproved lenses and statuses",()=>{
 expect(scamperLensSchema.safeParse("CUSTOM").success).toBe(false);
 expect(scamperEntryStatusSchema.options).toEqual(["active","archived"]);
 expect(scamperEntrySchema.safeParse({...row,status:"approved"}).success).toBe(false);
});
it("enforces paired archive metadata and structured fields",()=>{
 expect(scamperEntrySchema.parse(row)).toEqual(row);
 expect(scamperEntrySchema.safeParse({...row,archived_at:row.created_at}).success).toBe(false);
 expect(scamperEntrySchema.safeParse({...row,status:"archived"}).success).toBe(false);
 expect(scamperEntrySchema.parse({...row,status:"archived",archived_at:row.created_at})).toMatchObject({original_element:"Element",proposed_change:"Change",result_text:"Result"});
});
