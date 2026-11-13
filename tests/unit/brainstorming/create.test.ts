import {beforeEach,expect,it,vi} from "vitest";
vi.mock("server-only",()=>({}));
const mocks=vi.hoisted(()=>({auth:vi.fn(),rpc:vi.fn()}));
vi.mock("@/lib/auth/authorization",async original=>({...await original<typeof import("@/lib/auth/authorization")>(),getAuthorizationContext:mocks.auth}));
vi.mock("@/lib/db/server",()=>({createServerSupabaseClient:async()=>({rpc:mocks.rpc})}));
import {createBrainstormEntry} from "@/features/brainstorming/service";
import {AuthorizationError} from "@/lib/auth/authorization";
const id="00000000-0000-4000-8000-000000006004",other="00000000-0000-4000-8000-000000006005";
const input={activityInstanceId:id,content:"  Exact content\n  ",visibilityState:"private"};
const row={id,activity_instance_id:id,project_id:other,workspace_id:other,created_by:id,content:input.content,status:"active",revealed_at:null,archived_at:null,development_object_id:null,parent_entry_id:null,created_at:"2026-10-08T00:00:00Z",updated_at:"2026-10-08T00:00:00Z",updated_by:id};
beforeEach(()=>{vi.resetAllMocks();mocks.auth.mockResolvedValue({userId:id});mocks.rpc.mockResolvedValue({data:row,error:null});});
it("passes only approved input and preserves content/defaults",async()=>{
 expect(await createBrainstormEntry(input)).toEqual(row);
 expect(mocks.rpc).toHaveBeenCalledExactlyOnceWith("create_brainstorm_entry",{target_instance:id,entry_content:input.content,visibility_state:"private",parent_entry:null});
});
it("passes an optional parent without client scope",async()=>{
 mocks.rpc.mockResolvedValue({data:{...row,parent_entry_id:other},error:null});
 expect((await createBrainstormEntry({...input,parentEntryId:other})).parent_entry_id).toBe(other);
 expect(mocks.rpc.mock.calls[0][1].parent_entry).toBe(other);
});
it.each(["revealed","shared","public","team","visible","hidden","draft",null,undefined])("rejects visibility %s before RPC",async visibilityState=>{
 await expect(createBrainstormEntry({...input,visibilityState})).rejects.toMatchObject({code:"VALIDATION_ERROR"});expect(mocks.rpc).not.toHaveBeenCalled();
});
it.each(["created_by","project_id","workspace_id","team_id","user_id","revealed_at","development_object_id","status","archivedAt","createdBy","projectId","workspaceId","role"])("rejects extra/provenance field %s",async key=>{
 await expect(createBrainstormEntry({...input,[key]:other})).rejects.toMatchObject({code:"VALIDATION_ERROR"});expect(mocks.rpc).not.toHaveBeenCalled();
});
it.each([{activityInstanceId:"invalid"},{content:null},{parentEntryId:null},{parentEntryId:"invalid"}])("rejects invalid required/optional input %j",async patch=>{
 await expect(createBrainstormEntry({...input,...patch})).rejects.toMatchObject({code:"VALIDATION_ERROR"});expect(mocks.rpc).not.toHaveBeenCalled();
});
it("requires authentication before database access",async()=>{mocks.auth.mockRejectedValue(new AuthorizationError("AUTH_REQUIRED"));await expect(createBrainstormEntry(input)).rejects.toMatchObject({code:"AUTH_REQUIRED"});expect(mocks.rpc).not.toHaveBeenCalled();});
it("identity changes before RPC fail closed",async()=>{mocks.auth.mockResolvedValueOnce({userId:id}).mockResolvedValueOnce({userId:other});await expect(createBrainstormEntry(input)).rejects.toMatchObject({code:"NOT_FOUND"});expect(mocks.rpc).not.toHaveBeenCalled();});
it("identity changes after RPC cannot disclose its result",async()=>{mocks.auth.mockResolvedValueOnce({userId:id}).mockResolvedValueOnce({userId:id}).mockResolvedValueOnce({userId:other});await expect(createBrainstormEntry(input)).rejects.toMatchObject({code:"NOT_FOUND"});});
it.each([["0A000","DEPENDENCY_NOT_MET"],["55000","INVALID_STATE"],["28000","AUTH_REQUIRED"],["22023","VALIDATION_ERROR"],["42501","NOT_FOUND"],["23503","NOT_FOUND"],["XX000","NOT_FOUND"]])("maps %s to stable %s",async(code,expected)=>{
 mocks.rpc.mockResolvedValue({data:null,error:{code,message:"Private resource owner/settings"}});await expect(createBrainstormEntry(input)).rejects.toMatchObject({code:expected});
});
it.each([{created_by:other},{updated_by:other},{activity_instance_id:other},{content:"Modified"},{revealed_at:row.created_at},{archived_at:row.created_at},{status:"archived"},{development_object_id:other},{parent_entry_id:other}])("rejects inconsistent returned row %j",async patch=>{
 mocks.rpc.mockResolvedValue({data:{...row,...patch},error:null});await expect(createBrainstormEntry(input)).rejects.toMatchObject({code:"NOT_FOUND"});
});

it("canonicalizes UUID spelling before RPC/result checks",async()=>{
 const activity="aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa";
 mocks.rpc.mockResolvedValue({data:{...row,activity_instance_id:activity,parent_entry_id:activity},error:null});
 expect((await createBrainstormEntry({...input,activityInstanceId:activity.toUpperCase(),parentEntryId:activity.toUpperCase()})).activity_instance_id).toBe(activity);
 expect(mocks.rpc.mock.calls[0][1]).toMatchObject({target_instance:activity,parent_entry:activity});
});
