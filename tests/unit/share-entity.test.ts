import {beforeEach,describe,expect,it,vi} from "vitest";
vi.mock("server-only",()=>({}));
const m=vi.hoisted(()=>({auth:vi.fn(),rpc:vi.fn(),notify:vi.fn()}));
vi.mock("@/lib/auth/authorization",async original=>({...await original<typeof import("@/lib/auth/authorization")>(),getAuthorizationContext:m.auth}));
vi.mock("@/lib/db/server",()=>({createServerSupabaseClient:async()=>({rpc:m.rpc})}));
vi.mock('@/features/notifications/share',()=>({notifyArtifactShareCreated:m.notify}));
import {shareEntity,ActiveShareDifferentVersionError} from "@/features/shares/create";
import {shareEntityInputSchema} from "@/features/shares/create-schema";
import {AuthorizationError} from "@/lib/auth/authorization";
const actor="00000000-0000-4000-8000-000000006004",other="00000000-0000-4000-8000-000000006007";
const input={entityType:"ARTIFACT",entityId:actor,sourceVersionId:other,destinationType:"TEAM",destinationId:other,permissionLevel:"VIEW",shareMode:"SNAPSHOT"};
const row={id:other,source_workspace_id:actor,shared_entity_type:"ARTIFACT",shared_entity_id:actor,shared_by:actor,destination_type:"TEAM",destination_id:other,permission_level:"VIEW",share_mode:"SNAPSHOT",created_at:"2026-10-01T00:00:00Z",revoked_at:null,revoked_by:null};
describe("M13.4 caller-bound transaction wrapper",()=>{
 beforeEach(()=>{vi.resetAllMocks();m.auth.mockResolvedValue({userId:actor});m.rpc.mockResolvedValue({data:row,error:null});});
 it("uses one atomic user-scoped RPC with exact selected Version",async()=>{expect(await shareEntity(input)).toEqual(row);expect(m.rpc).toHaveBeenCalledExactlyOnceWith("share_entity",{input});expect(m.notify).toHaveBeenCalledExactlyOnceWith(row.id);expect(m.rpc.mock.invocationCallOrder[0]).toBeLessThan(m.notify.mock.invocationCallOrder[0]);});
 it("accepts canonical retry created by a previous authorized Lead",async()=>{m.rpc.mockResolvedValue({data:{...row,shared_by:other},error:null});expect((await shareEntity(input)).shared_by).toBe(other);});
 it.each(["SNAPSHOT","LIVE_REFERENCE"])("COLLABORATE/%s is policy-denied before any write RPC",async shareMode=>{await expect(shareEntity({...input,permissionLevel:"COLLABORATE",shareMode})).rejects.toMatchObject({code:"NOT_FOUND"});expect(m.rpc).not.toHaveBeenCalled();});
 it.each(['FILE','EVIDENCE','PATENT_RECORD','DEVELOPMENT_OBJECT','SCAMPER_ENTRY'])('non-Artifact %s stays supported and silent',async entityType=>{
  m.rpc.mockResolvedValue({data:{...row,shared_entity_type:entityType},error:null});
  expect((await shareEntity({...input,entityType,sourceVersionId:null})).shared_entity_type).toBe(entityType);expect(m.notify).not.toHaveBeenCalled();
 });
 it('failed canonical Share creates no notification',async()=>{m.rpc.mockResolvedValue({data:null,error:{code:'42501'}});await expect(shareEntity(input)).rejects.toThrow();expect(m.notify).not.toHaveBeenCalled();});
 it("requires explicit Artifact Version",async()=>{const {sourceVersionId,...v}=input;expect(sourceVersionId).toBe(other);await expect(shareEntity(v)).rejects.toMatchObject({code:"VALIDATION_ERROR"});expect(m.rpc).not.toHaveBeenCalled();});
 it.each([undefined,null])("non-versioned source supports omitted/null Version %#",version=>{expect(shareEntityInputSchema.safeParse({...input,entityType:"FILE",sourceVersionId:version}).success).toBe(true);});
 it.each(["FILE","EVIDENCE","PATENT_RECORD","DEVELOPMENT_OBJECT","SCAMPER_ENTRY"])("rejects Version for %s",async entityType=>{await expect(shareEntity({...input,entityType})).rejects.toMatchObject({code:"VALIDATION_ERROR"});expect(m.rpc).not.toHaveBeenCalled();});
 it.each(["shared_by","source_workspace_id","created_at","revoked_at","revoked_by","snapshot_data","actorId"])("rejects spoofed %s",async key=>{await expect(shareEntity({...input,[key]:actor})).rejects.toMatchObject({code:"VALIDATION_ERROR"});expect(m.rpc).not.toHaveBeenCalled();});
 it("denies unauthenticated without RPC",async()=>{m.auth.mockRejectedValue(new AuthorizationError("AUTH_REQUIRED"));await expect(shareEntity(input)).rejects.toMatchObject({code:"AUTH_REQUIRED"});expect(m.rpc).not.toHaveBeenCalled();});
 it("sanitizes provider/private diagnostics",async()=>{m.rpc.mockResolvedValue({data:null,error:{code:"42501",message:"private source path"}});await expect(shareEntity(input)).rejects.toMatchObject({code:"NOT_FOUND",message:"Resource unavailable."});});
 it("returns stable different-Version conflict without private metadata",async()=>{m.rpc.mockResolvedValue({data:null,error:{code:"P1304",message:"private version metadata"}});await expect(shareEntity(input)).rejects.toEqual(new ActiveShareDifferentVersionError());});
 it.each([{...row,revoked_at:"2026-10-02T00:00:00Z",revoked_by:actor},{...row,shared_entity_id:other},{...row,destination_id:actor},{...row,permission_level:"COMMENT"},{...row,privateNotes:"leak"}])("rejects noncanonical/leaking output %#",async data=>{m.rpc.mockResolvedValue({data,error:null});await expect(shareEntity(input)).rejects.toMatchObject({code:"NOT_FOUND"});});
 it("rechecks identity before transaction",async()=>{m.auth.mockResolvedValueOnce({userId:actor}).mockResolvedValue({userId:other});await expect(shareEntity(input)).rejects.toMatchObject({code:"NOT_FOUND"});expect(m.rpc).not.toHaveBeenCalled();});
 it("withholds result after identity switch",async()=>{m.auth.mockResolvedValueOnce({userId:actor}).mockResolvedValueOnce({userId:actor}).mockResolvedValue({userId:other});await expect(shareEntity(input)).rejects.toMatchObject({code:"NOT_FOUND"});expect(m.rpc).toHaveBeenCalledTimes(1);});
});

