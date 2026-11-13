import {beforeEach,describe,expect,it,vi} from "vitest";
vi.mock("server-only",()=>({}));
const m=vi.hoisted(()=>({auth:vi.fn(),rpc:vi.fn()}));
vi.mock("@/lib/auth/authorization",async original=>({...await original<typeof import("@/lib/auth/authorization")>(),getAuthorizationContext:m.auth}));
vi.mock("@/lib/db/server",()=>({createServerSupabaseClient:async()=>({rpc:m.rpc})}));
import {resolveSharedEntityAccess} from "@/features/shares/access";
import {deniedSharedEntityAccess,sharedEntityAccessResultSchema} from "@/features/shares/access-schema";
const actor="00000000-0000-4000-8000-000000006007",source="00000000-0000-4000-8000-000000006004",version="00000000-0000-4000-8000-000000006005";
const input={shareId:actor};
const allowed={allowed:true,canView:true,canComment:false,canEdit:false,canReshare:false,isSnapshot:true,isLiveReference:false,shareId:actor,sharedEntityType:"ARTIFACT",sharedEntityId:source,sourceVersionId:version,
 snapshotContent:{artifact_type:"DEVELOPED_CONCEPT",title:"Shared only",version_number:2,version_label:"V2",content_snapshot:{notes:"Frozen V2"}}};
describe("M13.5 caller-bound frozen recipient capabilities",()=>{
 beforeEach(()=>{vi.resetAllMocks();m.auth.mockResolvedValue({userId:actor});m.rpc.mockResolvedValue({data:allowed,error:null});});
 it("uses the authoritative caller-scoped RPC and rechecks after identity I/O",async()=>{expect(await resolveSharedEntityAccess(input)).toEqual(allowed);expect(m.rpc).toHaveBeenCalledTimes(2);expect(m.rpc).toHaveBeenCalledWith("resolve_shared_entity_access",{input});});
 it("COMMENT permits commenting but never editing or re-sharing",async()=>{m.rpc.mockResolvedValue({data:{...allowed,canComment:true},error:null});expect(await resolveSharedEntityAccess(input)).toEqual({...allowed,canComment:true});});
 it("anonymous performs no RPC",async()=>{m.auth.mockRejectedValue(Error("Unauthenticated"));expect(await resolveSharedEntityAccess(input)).toEqual(deniedSharedEntityAccess);expect(m.rpc).not.toHaveBeenCalled();});
 it.each(["actorId","userId","entityId","snapshotId","sourceVersionId","sourceWorkspaceId","permissionLevel","force"])("rejects client %s",async key=>{expect(await resolveSharedEntityAccess({...input,[key]:source})).toEqual(deniedSharedEntityAccess);expect(m.rpc).not.toHaveBeenCalled();});
 it.each([null,[],{},"bad",{shareId:null},{shareId:"bad"}])("rejects malformed input %#",async v=>{expect(await resolveSharedEntityAccess(v)).toEqual(deniedSharedEntityAccess);expect(m.rpc).not.toHaveBeenCalled();});
 it("returns uniform denial without a second query",async()=>{m.rpc.mockResolvedValue({data:deniedSharedEntityAccess,error:null});expect(await resolveSharedEntityAccess(input)).toEqual(deniedSharedEntityAccess);expect(m.rpc).toHaveBeenCalledTimes(1);});
 it("observed destination removal/revocation denies the response",async()=>{m.rpc.mockResolvedValueOnce({data:allowed,error:null}).mockResolvedValueOnce({data:deniedSharedEntityAccess,error:null});expect(await resolveSharedEntityAccess(input)).toEqual(deniedSharedEntityAccess);});
 it("identity switch withholds the frozen content",async()=>{m.auth.mockResolvedValueOnce({userId:actor}).mockResolvedValue({userId:source});expect(await resolveSharedEntityAccess(input)).toEqual(deniedSharedEntityAccess);expect(m.rpc).toHaveBeenCalledTimes(1);});
 it.each([{...allowed,canEdit:true},{...allowed,canReshare:true},{...allowed,isLiveReference:true},{...allowed,sourceWorkspaceId:source},{...allowed,provenance:{source_workspace_id:source}},{...allowed,sourceVersionId:null},{...allowed,snapshotContent:{...allowed.snapshotContent,privateSibling:"leak"}},{...allowed,shareId:source}])("rejects excessive/noncanonical capabilities %#",async data=>{m.rpc.mockResolvedValue({data,error:null});expect(await resolveSharedEntityAccess(input)).toEqual(deniedSharedEntityAccess);});
 it("rejects changed binding on the fresh call",async()=>{m.rpc.mockResolvedValueOnce({data:allowed,error:null}).mockResolvedValueOnce({data:{...allowed,sourceVersionId:source},error:null});expect(await resolveSharedEntityAccess(input)).toEqual(deniedSharedEntityAccess);});
 it("does not cache access across requests",async()=>{await resolveSharedEntityAccess(input);m.rpc.mockResolvedValue({data:deniedSharedEntityAccess,error:null});expect(await resolveSharedEntityAccess(input)).toEqual(deniedSharedEntityAccess);expect(m.rpc).toHaveBeenCalledTimes(3);});
 it("sanitizes provider errors",async()=>{m.rpc.mockRejectedValue(Error("private credentials"));expect(await resolveSharedEntityAccess(input)).toEqual(deniedSharedEntityAccess);});
 it("File projection never permits storage capabilities",()=>{expect(sharedEntityAccessResultSchema.safeParse({...allowed,sharedEntityType:"FILE",sourceVersionId:null,snapshotContent:{filename:"test.txt",mime_type:"text/plain",size:3}}).success).toBe(true);expect(sharedEntityAccessResultSchema.safeParse({...allowed,sharedEntityType:"FILE",sourceVersionId:null,snapshotContent:{filename:"test.txt",mime_type:"text/plain",size:3,storage_reference:"private/path"}}).success).toBe(false);});
});
