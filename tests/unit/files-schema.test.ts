import {expect,it} from "vitest";
import {fileSchema,fileLinkSchema,fileStatusSchema,fileLinkEntityTypeSchema,fileRelationshipTypeSchema,PRIVATE_FILE_BUCKET} from "@/features/files/schema";
const id=(n:number)=>`00000000-0000-4000-8000-${String(n).padStart(12,"0")}`;
const time="2026-10-26T12:00:00Z";
const row={id:id(1),uploaded_by:id(2),workspace_id:id(3),project_id:null,storage_reference:`workspaces/${id(3)}/files/${id(1)}`,filename:"Team drawing.svg",mime_type:"image/svg+xml",size:4096,status:"active",created_at:time,updated_at:time,updated_by:id(2),archived_at:null};
it("has exactly the approved lifecycle and link vocabularies",()=>{
 expect(fileStatusSchema.options).toEqual(["active","archived"]);
 expect(fileLinkEntityTypeSchema.options).toEqual(["EVIDENCE","ARTIFACT","ACTIVITY_INSTANCE","CHAT_MESSAGE","DEVELOPMENT_OBJECT"]);
 expect(fileRelationshipTypeSchema.options).toEqual(["ATTACHMENT","EVIDENCE_SOURCE","ARTIFACT_FILE","CHAT_ATTACHMENT","REFERENCE"]);
 expect(PRIVATE_FILE_BUCKET).toBe("fici-private-files");
});
it.each([null,id(4)])("accepts nullable or Project-bound metadata %s",project_id=>expect(fileSchema.parse({...row,project_id})).toEqual({...row,project_id}));
it("accepts archived metadata without deleting historical identity",()=>expect(fileSchema.parse({...row,status:"archived",archived_at:time}).id).toBe(row.id));
it.each(["pending","deleted","public","ACTIVE"])("rejects unapproved status %s",status=>expect(fileSchema.safeParse({...row,status}).success).toBe(false));
it.each(["https://example.test/public/file","/absolute/file","C:\\private\\file","../other","workspaces/other/files/other"])("rejects noncanonical reference %s",storage_reference=>expect(fileSchema.safeParse({...row,storage_reference}).success).toBe(false));
it.each(["../file","..\\file","/file","C:\\file",".","..",""," \t ","bad\nname","bad\0name"])("rejects path/control filename %j",filename=>expect(fileSchema.safeParse({...row,filename}).success).toBe(false));
it.each([-1,1.5,Number.MAX_SAFE_INTEGER+1])("rejects unsafe size %s",size=>expect(fileSchema.safeParse({...row,size}).success).toBe(false));
it.each([0,Number.MAX_SAFE_INTEGER])("accepts exact nonnegative byte count %s",size=>expect(fileSchema.safeParse({...row,size}).success).toBe(true));
it.each(["text","text/plain; charset=utf-8","text/plain\n","../image"])("rejects malformed MIME metadata %j",mime_type=>expect(fileSchema.safeParse({...row,mime_type}).success).toBe(false));
it.each([{status:"active",archived_at:time},{status:"archived",archived_at:null},{updated_at:"2000-01-01T00:00:00Z"},{status:"archived",archived_at:"2000-01-01T00:00:00Z"},{public_url:"https://example.test/file"}])("rejects inconsistent or additional fields %j",patch=>expect(fileSchema.safeParse({...row,...patch}).success).toBe(false));
it("keeps File Links as canonical typed identities without an access grant",()=>{
 const link={id:id(5),file_id:row.id,entity_type:"ARTIFACT",entity_id:id(6),relationship_type:"REFERENCE",created_by:row.uploaded_by,created_at:time,archived_at:null};
 expect(fileLinkSchema.parse(link)).toEqual(link);
 expect(fileLinkSchema.safeParse({...link,entity_type:"CUSTOM"}).success).toBe(false);
 expect(fileLinkSchema.safeParse({...link,permission:"view"}).success).toBe(false);
});
