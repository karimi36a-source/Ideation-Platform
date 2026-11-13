import {beforeEach,expect,it,vi} from "vitest";
vi.mock("server-only",()=>({}));
const {context,client,rpc,access,order}=vi.hoisted(()=>({context:vi.fn(),client:vi.fn(),rpc:vi.fn(),access:vi.fn(),order:vi.fn()}));
vi.mock("@/lib/auth/authorization",async original=>({...await original<typeof import("@/lib/auth/authorization")>(),getAuthorizationContext:context}));
vi.mock("@/lib/db/server",()=>({createServerSupabaseClient:client}));
vi.mock("@/features/workspaces/access",()=>({getWorkspaceAccess:access}));
import {getArtifact,getArtifactVersion,listArtifactVersions,archiveArtifact} from "@/features/artifacts/history";
const id=(n:number)=>`00000000-0000-4000-8000-${String(n).padStart(12,"0")}`;const stamp="2026-10-07T00:00:00Z";
let a:Record<string,unknown>|null;let versions:Record<string,unknown>[];
const v=(n:number,status="DRAFT")=>({id:id(10+n),artifact_id:id(1),version_number:n,version_label:null,draft_revision:0,content_snapshot:{version:n},change_summary:`Change ${n}`,status,created_by:id(5),created_at:stamp,previous_version_id:n===1?null:id(9+n),approved_by:status==="CURRENT"?id(6):null,approved_at:status==="CURRENT"?stamp:null,approval_note:null});
beforeEach(()=>{a={id:id(1),project_id:id(2),workspace_id:id(3),artifact_type:"PROBLEM_BANK",title:"Bank",status:"ACTIVE",current_version_id:id(11),created_by:id(5),activity_instance_id:null,review_required:true,approval_required:true,created_at:stamp,updated_at:stamp,archived_at:null};versions=[v(1,"CURRENT"),v(2),v(3)];context.mockReset().mockResolvedValue({userId:id(5)});access.mockReset().mockResolvedValue({canView:true,canEdit:true});order.mockReset().mockImplementation(async()=>({data:versions,error:null}));rpc.mockReset().mockImplementation(async()=>({data:{...a,status:"ARCHIVED",archived_at:a?.archived_at??stamp},error:null}));client.mockReset().mockResolvedValue({rpc,from:(table:string)=>({select:()=>({eq:(_key:string,wanted:string)=>({maybeSingle:async()=>({data:table==="artifacts"?a:versions.find(v=>v.id===wanted)??null,error:null}),order})})})});});
it("returns stored current pointer, not newest Draft, and only Artifact metadata",async()=>{const row=await getArtifact(id(1));expect(row).toMatchObject({id:id(1),currentVersionId:id(11),projectId:id(2),workspaceId:id(3)});expect(row).not.toHaveProperty("projectName");});
it("returns canonical Version metadata with parent authorization",async()=>{expect(await getArtifactVersion(id(11))).toMatchObject({versionNumber:1,artifactId:id(1),status:"CURRENT",createdBy:id(5),createdAt:stamp,changeSummary:"Change 1",approvedBy:id(6)});});
it("AT-VER-003 foundation returns full ordered history without mutation",async()=>{const before=JSON.stringify(versions);expect((await listArtifactVersions(id(1))).map(v=>v.versionNumber)).toEqual([1,2,3]);expect(order).toHaveBeenCalledWith("version_number",{ascending:true});expect(JSON.stringify(versions)).toBe(before);});
it("AT-VER-003 exposes exact persisted history fields and keeps latest Draft separate from current",async()=>{
 versions=[{...v(1,"SUPERSEDED"),approved_by:id(6),approved_at:stamp,approval_note:"First approval"},{...v(2,"CURRENT"),change_summary:null,approval_note:"Second approval"},v(3)];
 a!.current_version_id=id(12);
 const before=structuredClone(versions);
 const history=await listArtifactVersions(id(1));
 for(let n=0;n<versions.length;n++){
  const stored=versions[n];
  expect(history[n]).toEqual({id:stored.id,artifactId:stored.artifact_id,versionNumber:stored.version_number,draftRevision:stored.draft_revision,versionLabel:stored.version_label,contentSnapshot:stored.content_snapshot,changeSummary:stored.change_summary,status:stored.status,createdBy:stored.created_by,createdAt:stored.created_at,previousVersionId:stored.previous_version_id,approvedBy:stored.approved_by,approvedAt:stored.approved_at,approvalNote:stored.approval_note});
  expect(await getArtifactVersion(stored.id)).toEqual(history[n]);
 }
 expect(await getArtifact(id(1))).toMatchObject({currentVersionId:id(12)});
 expect(history.at(-1)).toMatchObject({id:id(13),status:"DRAFT"});
 expect(history[1].changeSummary).toBeNull();
 expect(order).toHaveBeenCalledWith("version_number",{ascending:true});
 expect(versions).toEqual(before);
});
it("does not hide superseded/archived Versions",async()=>{versions=[v(1,"SUPERSEDED"),v(2,"ARCHIVED")];expect((await listArtifactVersions(id(1))).map(v=>v.status)).toEqual(["SUPERSEDED","ARCHIVED"]);});
it("allows authorized archived history and idempotent archive retry",async()=>{a!.status="ARCHIVED";a!.archived_at=stamp;expect((await getArtifact(id(1))).status).toBe("ARCHIVED");expect((await getArtifactVersion(id(11))).id).toBe(id(11));expect(await listArtifactVersions(id(1))).toHaveLength(3);expect((await archiveArtifact(id(1))).archivedAt).toBe(stamp);});
it("archives only through caller-bound RPC",async()=>{expect((await archiveArtifact(id(1))).status).toBe("ARCHIVED");expect(rpc).toHaveBeenCalledWith("archive_artifact",{target_artifact:id(1)});});
it.each([getArtifact,getArtifactVersion,listArtifactVersions,archiveArtifact])("anonymous operation denied",async operation=>{const {AuthorizationError}=await import("@/lib/auth/authorization");context.mockRejectedValue(new AuthorizationError("AUTH_REQUIRED"));await expect(operation(id(1))).rejects.toMatchObject({code:"AUTH_REQUIRED"});expect(client).not.toHaveBeenCalled();});
it.each([getArtifact,getArtifactVersion,listArtifactVersions,archiveArtifact])("inaccessible/nonexistent IDs share opaque denial",async operation=>{a=null;versions=[];for(const key of [id(1),id(999)])await expect(operation(key)).rejects.toMatchObject({code:"NOT_FOUND",message:"Resource unavailable."});expect(rpc.mock.calls.every(([name])=>name!=="archive_artifact")).toBe(true);});
it("visible Version cannot bypass inaccessible parent",async()=>{a=null;await expect(getArtifactVersion(id(11))).rejects.toMatchObject({code:"NOT_FOUND"});});
it("requires canonical Workspace view despite row visibility",async()=>{access.mockResolvedValue({canView:false});await expect(getArtifact(id(1))).rejects.toMatchObject({code:"NOT_FOUND"});});
it("archive requires edit, not merely view",async()=>{access.mockResolvedValue({canView:true,canEdit:false});await expect(archiveArtifact(id(1))).rejects.toMatchObject({code:"NOT_FOUND"});expect(rpc).not.toHaveBeenCalled();});
it.each([getArtifact,getArtifactVersion,listArtifactVersions,archiveArtifact])("rejects caller identity/scope objects",async operation=>{await expect(operation({id:id(1),role:"ADMIN",ownerUserId:id(5)})).rejects.toMatchObject({code:"VALIDATION_ERROR"});expect(rpc).not.toHaveBeenCalled();});
it("stale actor fails closed",async()=>{context.mockResolvedValueOnce({userId:id(5)}).mockResolvedValue({userId:id(9)});await expect(getArtifact(id(1))).rejects.toMatchObject({code:"NOT_FOUND"});});
it("hides RPC diagnostics",async()=>{rpc.mockResolvedValue({error:{code:"42501",message:"Private archive details"},data:null});await expect(archiveArtifact(id(1))).rejects.toMatchObject({code:"NOT_FOUND",message:"Resource unavailable."});});
it("rejects current pointer mutation in archive response",async()=>{rpc.mockResolvedValue({data:{...a,status:"ARCHIVED",archived_at:stamp,current_version_id:id(13)},error:null});await expect(archiveArtifact(id(1))).rejects.toMatchObject({code:"NOT_FOUND"});});
it("retry must preserve original archive timestamp",async()=>{a!.status="ARCHIVED";a!.archived_at=stamp;rpc.mockResolvedValue({data:{...a,archived_at:"2026-10-08T00:00:00Z"},error:null});await expect(archiveArtifact(id(1))).rejects.toMatchObject({code:"NOT_FOUND"});});
it("reviewer metadata is minimal and grants no Workspace/edit access",async()=>{
 const target={id:id(1),artifactType:"PROBLEM_BANK",title:"Submitted",status:"ACTIVE",projectId:id(2),workspaceId:id(3),activityInstanceId:id(7),reviewRequired:true,approvalRequired:false};
 a=null;context.mockResolvedValue({userId:id(6)});access.mockResolvedValue({canView:false,canEdit:false});rpc.mockResolvedValue({data:target,error:null});
 expect(await getArtifact(id(1))).toEqual(target);expect(await getArtifact(id(1))).not.toHaveProperty("currentVersionId");
 await expect(archiveArtifact(id(1))).rejects.toMatchObject({code:"NOT_FOUND"});expect(rpc.mock.calls.every(([name])=>name==="get_submitted_artifact_metadata")).toBe(true);
});
it("reviewer Version/history retrieval uses only exact rows admitted by RLS",async()=>{
 a=null;versions=[v(2,"SUBMITTED")];context.mockResolvedValue({userId:id(6)});rpc.mockResolvedValue({data:{id:id(1),artifactType:"PROBLEM_BANK",title:"Submitted",status:"ACTIVE",projectId:id(2),workspaceId:id(3),activityInstanceId:id(7),reviewRequired:true,approvalRequired:true},error:null});
 expect((await getArtifactVersion(id(12))).id).toBe(id(12));expect((await listArtifactVersions(id(1))).map(v=>v.id)).toEqual([id(12)]);
 await expect(getArtifactVersion(id(13))).rejects.toMatchObject({code:"NOT_FOUND"});
});
it("revoked review entitlement yields the same opaque denial as unknown ID",async()=>{a=null;rpc.mockResolvedValue({data:null,error:null});for(const key of [id(1),id(999)])await expect(getArtifact(key)).rejects.toMatchObject({code:"NOT_FOUND",message:"Resource unavailable."});});
