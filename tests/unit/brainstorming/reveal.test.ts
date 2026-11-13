import {beforeEach,expect,it,vi} from "vitest";
vi.mock("server-only",()=>({}));
const mocks=vi.hoisted(()=>({auth:vi.fn(),rpc:vi.fn()}));
vi.mock("@/lib/auth/authorization",async original=>({...await original<typeof import("@/lib/auth/authorization")>(),getAuthorizationContext:mocks.auth}));
vi.mock("@/lib/db/server",()=>({createServerSupabaseClient:async()=>({rpc:mocks.rpc})}));
import {revealBrainstormEntries} from "@/features/brainstorming/reveal";
import {AuthorizationError} from "@/lib/auth/authorization";
const a="00000000-0000-4000-8000-000000006004",e1="aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",e2="bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb";
const input={activityInstanceId:a,entryIds:[e2,e1]};
const result={activityInstanceId:a,entries:[{entryId:e1,revealedAt:"2026-10-08T00:00:00Z"},{entryId:e2,revealedAt:"2026-10-08T01:00:00Z"}]};
beforeEach(()=>{vi.resetAllMocks();mocks.auth.mockResolvedValue({userId:a});mocks.rpc.mockResolvedValue({data:result,error:null});});
it("passes only approved arguments and returns canonical timestamps/order",async()=>{
 expect(await revealBrainstormEntries(input)).toEqual(result);
 expect(mocks.rpc).toHaveBeenCalledExactlyOnceWith("reveal_brainstorm_entries",{target_instance:a,target_entries:[e2,e1]});
});
it.each(["userId","revealedBy","revealedAt","workspaceId","projectId","teamId","role","creator","force","visibilityState"])("rejects spoofed field %s before RPC",async key=>{
 await expect(revealBrainstormEntries({...input,[key]:a})).rejects.toMatchObject({code:"VALIDATION_ERROR"});expect(mocks.rpc).not.toHaveBeenCalled();
});
it.each([{entryIds:[]},{entryIds:[e1,e1]},{entryIds:[e1,e1.toUpperCase()]},{entryIds:[null]},{entryIds:["bad"]},{activityInstanceId:"bad"},{entryIds:null}])("rejects invalid target set %j",async patch=>{
 await expect(revealBrainstormEntries({...input,...patch})).rejects.toMatchObject({code:"VALIDATION_ERROR"});expect(mocks.rpc).not.toHaveBeenCalled();
});
it("normalizes UUID casing",async()=>{expect(await revealBrainstormEntries({...input,entryIds:[e2.toUpperCase(),e1.toUpperCase()]})).toEqual(result);expect(mocks.rpc.mock.calls[0][1].target_entries).toEqual([e2,e1]);});
it("requires verified identity",async()=>{mocks.auth.mockRejectedValue(new AuthorizationError("AUTH_REQUIRED"));await expect(revealBrainstormEntries(input)).rejects.toMatchObject({code:"AUTH_REQUIRED"});expect(mocks.rpc).not.toHaveBeenCalled();});
it.each([false,true])("rejects identity change before/after RPC %s",async after=>{
 mocks.auth.mockResolvedValueOnce({userId:a}).mockResolvedValueOnce({userId:after?a:e1}).mockResolvedValueOnce({userId:e1});
 await expect(revealBrainstormEntries(input)).rejects.toMatchObject({code:"NOT_FOUND"});if(!after)expect(mocks.rpc).not.toHaveBeenCalled();
});
it.each([["28000","AUTH_REQUIRED"],["22023","VALIDATION_ERROR"],["0A000","DEPENDENCY_NOT_MET"],["55000","INVALID_STATE"],["42501","NOT_FOUND"],["XX000","NOT_FOUND"]])("maps %s safely",async(code,expected)=>{
 mocks.rpc.mockResolvedValue({error:{code,message:"Private content/owner"},data:null});await expect(revealBrainstormEntries(input)).rejects.toMatchObject({code:expected});
});
it.each([null,{...result,activityInstanceId:e1},{...result,entries:[]},{...result,entries:[result.entries[0]]},{...result,entries:[result.entries[1],result.entries[0]]},{...result,entries:[result.entries[0],result.entries[0]]},{...result,content:"hidden"},{...result,entries:[{...result.entries[0],revealedAt:null},result.entries[1]]}])("rejects noncanonical/leaking result %j",async data=>{
 mocks.rpc.mockResolvedValue({data,error:null});await expect(revealBrainstormEntries(input)).rejects.toMatchObject({code:"NOT_FOUND"});
});
