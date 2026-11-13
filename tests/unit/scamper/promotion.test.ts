import {beforeEach,expect,it,vi} from "vitest";
vi.mock("server-only",()=>({}));
const mocks=vi.hoisted(()=>({auth:vi.fn(),rpc:vi.fn()}));
vi.mock("@/lib/auth/authorization",async original=>({...await original<typeof import("@/lib/auth/authorization")>(),getAuthorizationContext:mocks.auth}));
vi.mock("@/lib/db/server",()=>({createServerSupabaseClient:async()=>({rpc:mocks.rpc})}));
import {AuthorizationError} from "@/lib/auth/authorization";
import {promoteScamperEntryToIdea} from "@/features/scamper/promotion";
const id="00000000-0000-4000-8000-000000006004",author="00000000-0000-4000-8000-000000006005";
const row={id,project_id:id,workspace_id:id,object_type:"IDEA",title:"Source",content:"Source",status:null,verification_status:null,origin_type:"SCAMPER",origin_reference_id:id,created_by:author,current_version_number:1,archived_at:null,metadata:{},created_at:"2026-10-08T00:00:00Z",updated_at:"2026-10-08T00:00:00Z"};
beforeEach(()=>{vi.resetAllMocks();mocks.auth.mockResolvedValue({userId:id});mocks.rpc.mockResolvedValue({data:row,error:null});});
it("uses strict source-only RPC and retains source author separately from actor",async()=>{expect(await promoteScamperEntryToIdea({entryId:id})).toEqual(row);expect(mocks.rpc).toHaveBeenCalledExactlyOnceWith("promote_scamper_entry_to_idea",{target_entry:id});});
it.each(["projectId","workspaceId","createdBy","role","ideaObjectId","status"])("rejects spoofed %s",async key=>{await expect(promoteScamperEntryToIdea({entryId:id,[key]:author})).rejects.toMatchObject({code:"VALIDATION_ERROR"});expect(mocks.rpc).not.toHaveBeenCalled();});
it("rejects empty input and anonymous callers",async()=>{await expect(promoteScamperEntryToIdea({})).rejects.toMatchObject({code:"VALIDATION_ERROR"});mocks.auth.mockRejectedValue(new AuthorizationError("AUTH_REQUIRED"));await expect(promoteScamperEntryToIdea({entryId:id})).rejects.toMatchObject({code:"AUTH_REQUIRED"});expect(mocks.rpc).not.toHaveBeenCalled();});
it("fails closed when actor changes",async()=>{mocks.auth.mockResolvedValueOnce({userId:id}).mockResolvedValueOnce({userId:author});await expect(promoteScamperEntryToIdea({entryId:id})).rejects.toMatchObject({code:"NOT_FOUND"});expect(mocks.rpc).not.toHaveBeenCalled();});
it.each(["42501","XX000"])("sanitizes inaccessible/failed RPC %s",async code=>{mocks.rpc.mockResolvedValue({data:null,error:{code,message:"Private content"}});await expect(promoteScamperEntryToIdea({entryId:id})).rejects.toMatchObject({code:"NOT_FOUND",message:"Resource unavailable."});});
it.each([["23505","CONFLICT"],["55000","INVALID_STATE"]])("preserves stable %s failure",async(code,expected)=>{mocks.rpc.mockResolvedValue({data:null,error:{code}});await expect(promoteScamperEntryToIdea({entryId:id})).rejects.toMatchObject({code:expected});});
it.each([{...row,object_type:"PROBLEM"},{...row,origin_type:"OTHER"},{...row,origin_reference_id:author},{}])("rejects noncanonical results",async data=>{mocks.rpc.mockResolvedValue({data,error:null});await expect(promoteScamperEntryToIdea({entryId:id})).rejects.toMatchObject({code:"NOT_FOUND"});});

it("normalizes source UUID casing and returns the canonical persisted IDEA on retry",async()=>{const canonical="aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa";const idea={...row,origin_reference_id:canonical};mocks.rpc.mockResolvedValue({data:idea,error:null});expect(await promoteScamperEntryToIdea({entryId:canonical.toUpperCase()})).toEqual(idea);expect(await promoteScamperEntryToIdea({entryId:canonical})).toEqual(idea);expect(mocks.rpc).toHaveBeenNthCalledWith(1,"promote_scamper_entry_to_idea",{target_entry:canonical});expect(mocks.rpc).toHaveBeenNthCalledWith(2,"promote_scamper_entry_to_idea",{target_entry:canonical});});
