import {expect,it} from "vitest";
import {brainstormEntrySchema,brainstormEntryStatusSchema} from "@/features/brainstorming/schema";
const id="00000000-0000-4000-8000-000000006004";
const row={id,activity_instance_id:id,project_id:id,workspace_id:id,created_by:id,content:"Private",status:"active",revealed_at:null,parent_entry_id:null,development_object_id:null,created_at:"2026-10-08T00:00:00Z",updated_at:"2026-10-08T00:00:00Z",updated_by:id,archived_at:null};
it("keeps lifecycle distinct from reveal",()=>{
 expect(brainstormEntryStatusSchema.options).toEqual(["active","archived"]);
 expect(brainstormEntrySchema.parse(row)).toEqual(row);
 expect(brainstormEntrySchema.parse({...row,revealed_at:row.created_at}).status).toBe("active");
});
it.each(["private","revealed","shared","promoted","CURRENT"])("rejects unapproved status %s",status=>expect(brainstormEntrySchema.safeParse({...row,status}).success).toBe(false));
it("enforces history metadata and rejects self parent/extra fields",()=>{
 expect(brainstormEntrySchema.safeParse({...row,status:"archived"}).success).toBe(false);
 expect(brainstormEntrySchema.safeParse({...row,archived_at:row.created_at}).success).toBe(false);
 expect(brainstormEntrySchema.parse({...row,status:"archived",archived_at:row.created_at}).id).toBe(id);
 expect(brainstormEntrySchema.safeParse({...row,parent_entry_id:id}).success).toBe(false);
 expect(brainstormEntrySchema.safeParse({...row,role:"ADMIN"}).success).toBe(false);
});
