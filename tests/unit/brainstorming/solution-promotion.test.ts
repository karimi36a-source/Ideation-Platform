import {beforeEach,expect,it,vi} from "vitest";
vi.mock("server-only",()=>({}));
const mocks=vi.hoisted(()=>({auth:vi.fn(),rpc:vi.fn()}));
vi.mock("@/lib/auth/authorization",async original=>({...await original<typeof import("@/lib/auth/authorization")>(),getAuthorizationContext:mocks.auth}));
vi.mock("@/lib/db/server",()=>({createServerSupabaseClient:async()=>({rpc:mocks.rpc})}));
import {AuthorizationError} from "@/lib/auth/authorization";
import {promoteBrainstormEntryToSolution} from "@/features/brainstorming/solution-promotion";
const id="00000000-0000-4000-8000-000000006004",author="00000000-0000-4000-8000-000000006005";
const row={id,project_id:id,workspace_id:id,object_type:"SOLUTION",title:"Source",content:"Source",status:null,verification_status:null,origin_type:"BRAINSTORM",origin_reference_id:id,created_by:author,current_version_number:1,archived_at:null,metadata:{},created_at:"2026-10-08T00:00:00Z",updated_at:"2026-10-08T00:00:00Z"};
beforeEach(()=>{vi.resetAllMocks();mocks.auth.mockResolvedValue({userId:id});mocks.rpc.mockResolvedValue({data:row,error:null});});
it("uses strict source-only RPC and retains source author separately from actor",async()=>{expect(await promoteBrainstormEntryToSolution({entryId:id,problemId:author})).toEqual(row);expect(mocks.rpc).toHaveBeenCalledExactlyOnceWith("promote_brainstorm_entry_to_solution",{target_entry:id,target_problem:author});});
it.each(["activityInstanceId","relationshipType","projectId","workspaceId","teamId","creatorId","promoterId","title","content","objectType","revealedAt","developmentObjectId","force","role","status"])("rejects spoofed %s",async key=>{await expect(promoteBrainstormEntryToSolution({entryId:id,problemId:author,[key]:author})).rejects.toMatchObject({code:"VALIDATION_ERROR"});expect(mocks.rpc).not.toHaveBeenCalled();});
it("rejects empty input and anonymous callers",async()=>{await expect(promoteBrainstormEntryToSolution({})).rejects.toMatchObject({code:"VALIDATION_ERROR"});mocks.auth.mockRejectedValue(new AuthorizationError("AUTH_REQUIRED"));await expect(promoteBrainstormEntryToSolution({entryId:id,problemId:author})).rejects.toMatchObject({code:"AUTH_REQUIRED"});expect(mocks.rpc).not.toHaveBeenCalled();});
it("fails closed when actor changes",async()=>{mocks.auth.mockResolvedValueOnce({userId:id}).mockResolvedValueOnce({userId:author});await expect(promoteBrainstormEntryToSolution({entryId:id,problemId:author})).rejects.toMatchObject({code:"NOT_FOUND"});expect(mocks.rpc).not.toHaveBeenCalled();});
it.each(["42501","XX000"])("sanitizes inaccessible/failed RPC %s",async code=>{mocks.rpc.mockResolvedValue({data:null,error:{code,message:"Private content"}});await expect(promoteBrainstormEntryToSolution({entryId:id,problemId:author})).rejects.toMatchObject({code:"NOT_FOUND",message:"Resource unavailable."});});
it.each([["23505","CONFLICT"],["55000","INVALID_STATE"]])("preserves stable %s failure",async(code,expected)=>{mocks.rpc.mockResolvedValue({data:null,error:{code}});await expect(promoteBrainstormEntryToSolution({entryId:id,problemId:author})).rejects.toMatchObject({code:expected});});
it.each([{...row,object_type:"IDEA"},{...row,object_type:"PROBLEM"},{...row,origin_type:"OTHER"},{...row,origin_reference_id:author},{}])("rejects noncanonical results",async data=>{mocks.rpc.mockResolvedValue({data,error:null});await expect(promoteBrainstormEntryToSolution({entryId:id,problemId:author})).rejects.toMatchObject({code:"NOT_FOUND"});});

it.each([{entryId:id},{problemId:author},{entryId:"bad",problemId:author},{entryId:id,problemId:"bad"}])("rejects missing/invalid source and Problem",async input=>{await expect(promoteBrainstormEntryToSolution(input)).rejects.toMatchObject({code:"VALIDATION_ERROR"});expect(mocks.rpc).not.toHaveBeenCalled();});

it("fails closed if identity changes after the RPC",async()=>{mocks.auth.mockResolvedValueOnce({userId:id}).mockResolvedValueOnce({userId:id}).mockResolvedValueOnce({userId:author});await expect(promoteBrainstormEntryToSolution({entryId:id,problemId:author})).rejects.toMatchObject({code:"NOT_FOUND"});expect(mocks.rpc).toHaveBeenCalledOnce();});
