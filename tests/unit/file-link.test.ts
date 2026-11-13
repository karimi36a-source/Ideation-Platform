import {it,expect,vi,beforeEach} from "vitest";
import {linkFileSchema,FILE_LINK_RELATIONSHIPS} from "@/features/files/link-schema";
import {fileLinkEntityTypeSchema,fileRelationshipTypeSchema} from "@/features/files/schema";
const id="00000000-0000-4000-8000-000000006004";
for(const entityType of fileLinkEntityTypeSchema.options)for(const relationshipType of fileRelationshipTypeSchema.options){
 it(`${entityType} / ${relationshipType} exact approved matrix`,()=>expect(linkFileSchema.safeParse({fileId:id,entityId:id,entityType,relationshipType}).success).toBe((FILE_LINK_RELATIONSHIPS[entityType] as readonly string[]).includes(relationshipType)));
}
it.each(["workspaceId","projectId","uploadedBy","storage_reference","storagePath","ownerId","teamId","visibility","grants","notes"])("rejects extra %s",key=>expect(linkFileSchema.safeParse({fileId:id,entityId:id,entityType:"EVIDENCE",relationshipType:"REFERENCE",[key]:id}).success).toBe(false));
it.each(["evidence","CHAT","ACTIVITY","PROJECT_OBJECT","custom"])("rejects noncanonical target %s",entityType=>expect(linkFileSchema.safeParse({fileId:id,entityId:id,entityType,relationshipType:"REFERENCE"}).success).toBe(false));
it("rejects malformed identities and relationship case variants",()=>{expect(linkFileSchema.safeParse({fileId:"bad",entityId:id,entityType:"EVIDENCE",relationshipType:"REFERENCE"}).success).toBe(false);expect(linkFileSchema.safeParse({fileId:id,entityId:id,entityType:"EVIDENCE",relationshipType:"reference"}).success).toBe(false);});
vi.mock("server-only",()=>({}));
const mocks=vi.hoisted(()=>({auth:vi.fn(),rpc:vi.fn()}));
vi.mock("@/lib/auth/authorization",async original=>({...await original<typeof import("@/lib/auth/authorization")>(),getAuthorizationContext:mocks.auth}));
vi.mock("@/lib/db/server",()=>({createServerSupabaseClient:async()=>({rpc:mocks.rpc})}));
import {linkFile} from "@/features/files/link";
import {AuthorizationError} from "@/lib/auth/authorization";
beforeEach(()=>{vi.resetAllMocks();mocks.auth.mockResolvedValue({userId:id});});
const input={fileId:id,entityId:id,entityType:"EVIDENCE",relationshipType:"REFERENCE"};
it("anonymous cannot link",async()=>{mocks.auth.mockRejectedValue(new AuthorizationError("AUTH_REQUIRED"));await expect(linkFile(input)).rejects.toMatchObject({code:"AUTH_REQUIRED"});expect(mocks.rpc).not.toHaveBeenCalled();});
it("spoof rejected before mutation",async()=>{await expect(linkFile({...input,uploadedBy:id})).rejects.toMatchObject({code:"VALIDATION_ERROR"});expect(mocks.rpc).not.toHaveBeenCalled();});
it("safe identical denial for missing/inaccessible IDs",async()=>{mocks.rpc.mockResolvedValue({error:{code:"42501",message:"private detail"}});await expect(linkFile(input)).rejects.toMatchObject({code:"NOT_FOUND"});});
it("does not expose File metadata or storage values from a malformed transport",async()=>{mocks.rpc.mockResolvedValue({data:{filename:"private",storage_reference:"private"},error:null});await expect(linkFile(input)).rejects.toMatchObject({code:"NOT_FOUND"});});
it("canonical retry preserves original creator; no File row/body returned",async()=>{const row={id,file_id:id,entity_id:id,entity_type:"EVIDENCE",relationship_type:"REFERENCE",created_by:"00000000-0000-4000-8000-000000006005",created_at:"2026-10-26T00:00:00Z",archived_at:null};mocks.rpc.mockResolvedValue({data:row,error:null});expect(await linkFile(input)).toEqual(row);expect(mocks.rpc).toHaveBeenCalledWith("link_file",{input});});
