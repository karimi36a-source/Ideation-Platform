import {beforeEach,expect,it,vi} from "vitest";
import {finalizeSession7OutputsSchema} from "@/features/mind-map/session7-schema";
const auth=vi.hoisted(()=>vi.fn());
const rpc=vi.hoisted(()=>vi.fn());
vi.mock("server-only",()=>({}));
vi.mock("@/lib/auth/authorization",async original=>({...await original<object>(),getAuthorizationContext:auth}));
vi.mock("@/lib/db/server",()=>({createServerSupabaseClient:async()=>({rpc})}));
import {finalizeSession7Outputs} from "@/features/mind-map/session7";
const id=(n:number)=>`00000000-0000-4000-8000-${String(n).padStart(12,"0")}`;
const input={activityInstanceId:id(1),mindMapId:id(2),expectedDraftRevision:3,idempotencyKey:"human-confirmed"};
beforeEach(()=>{vi.resetAllMocks();auth.mockResolvedValue({userId:id(4)});});
it("accepts only the approved saved-state contract and normalizes UUIDs",()=>{
 expect(finalizeSession7OutputsSchema.parse({...input,mindMapId:input.mindMapId.toUpperCase()})).toEqual(input);
});
it.each(["actor","projectId","workspaceId","teamId","status","nodes","edges","contentSnapshot","essentialObjectIds","classification","force","approvedBy"])("denies client composition/authority field %s",async key=>{
 await expect(finalizeSession7Outputs({...input,[key]:id(4)})).rejects.toMatchObject({code:"VALIDATION_ERROR"});expect(rpc).not.toHaveBeenCalled();
});
it.each([-1,0.5,2147483648,"3",null,undefined])("rejects invalid Draft token %s",value=>expect(finalizeSession7OutputsSchema.safeParse({...input,expectedDraftRevision:value}).success).toBe(false));
it.each([["23505","CONFLICT"],["40001","CONFLICT"],["55000","INVALID_STATE"],["22023","VALIDATION_ERROR"],["42501","NOT_FOUND"],["28000","AUTH_REQUIRED"]])("normalizes SQLSTATE %s",async(code,expected)=>{
 rpc.mockResolvedValue({error:{code,message:"Private invention title"}});await expect(finalizeSession7Outputs(input)).rejects.toMatchObject({code:expected});
});
it("denies identity drift before database access",async()=>{auth.mockResolvedValueOnce({userId:id(4)}).mockResolvedValueOnce({userId:id(5)});await expect(finalizeSession7Outputs(input)).rejects.toMatchObject({code:"NOT_FOUND"});expect(rpc).not.toHaveBeenCalled();});
const output=(offset:number,type:string)=>({artifact:{id:id(offset),project_id:id(40),workspace_id:id(41),artifact_type:type,title:type,status:"ACTIVE",current_version_id:null,created_by:id(4),activity_instance_id:id(1),review_required:true,approval_required:true,created_at:"2026-10-18T12:00:00Z",updated_at:"2026-10-18T12:00:00Z",archived_at:null},
 version:{id:id(offset+1),artifact_id:id(offset),version_number:1,version_label:null,content_snapshot:{},change_summary:null,status:"DRAFT",draft_revision:0,created_by:id(4),created_at:"2026-10-18T12:00:00Z",previous_version_id:null,approved_by:null,approved_at:null,approval_note:null},activityOutputId:id(offset+2)});
const result={mindMapId:id(2),successorMindMapId:id(3),sourceDraftRevision:3,mindMap:output(10,"MIND_MAP"),essentialStructure:output(20,"MINIMUM_ESSENTIAL_STRUCTURE"),inventionConcept:output(30,"INVENTION_CONCEPT"),replayed:false};
it("returns canonical typed outputs",async()=>{rpc.mockResolvedValue({data:result,error:null});await expect(finalizeSession7Outputs(input)).resolves.toEqual(result);expect(rpc).toHaveBeenCalledWith("finalize_session7_outputs",{input});});
it("does not trust a valid-looking foreign scope response",async()=>{rpc.mockResolvedValue({data:{...result,inventionConcept:{...result.inventionConcept,artifact:{...result.inventionConcept.artifact,workspace_id:id(42)}}},error:null});await expect(finalizeSession7Outputs(input)).rejects.toMatchObject({code:"NOT_FOUND"});});
it("denies identity drift after successful RPC",async()=>{auth.mockResolvedValueOnce({userId:id(4)}).mockResolvedValueOnce({userId:id(4)}).mockResolvedValueOnce({userId:id(5)});rpc.mockResolvedValue({data:result,error:null});await expect(finalizeSession7Outputs(input)).rejects.toMatchObject({code:"NOT_FOUND"});});
it("rejects malformed results without exposing metadata",async()=>{rpc.mockResolvedValue({data:{name:"Private invention"},error:null});await expect(finalizeSession7Outputs(input)).rejects.toMatchObject({code:"NOT_FOUND"});});
it("returns canonical review state on an authorized retry",async()=>{
 const approved={...result,replayed:true,inventionConcept:{...result.inventionConcept,version:{...result.inventionConcept.version,status:"CURRENT",approved_by:id(5),approved_at:"2026-10-18T13:00:00Z"}}};
 rpc.mockResolvedValue({data:approved,error:null});await expect(finalizeSession7Outputs(input)).resolves.toEqual(approved);
});
