import {beforeEach,it,expect,vi} from "vitest";
vi.mock("server-only",()=>({}));
const {context,rpc,client}=vi.hoisted(()=>({context:vi.fn(),rpc:vi.fn(),client:vi.fn()}));
vi.mock("@/lib/auth/authorization",async importOriginal=>({...await importOriginal<object>(),getAuthorizationContext:context}));
vi.mock("@/lib/db/server",()=>({createServerSupabaseClient:client}));
import {archiveProject} from "@/features/projects/archive-service";
const id="00000000-0000-4000-8000-000000007201",actor="00000000-0000-4000-8000-000000006004",stamp="2026-10-04T00:00:00Z";
const row={id,name:"Project",description:null,project_type:"individual",owner_user_id:actor,owner_team_id:null,primary_workspace_id:id,status:"archived",current_stage:null,confidentiality_level:null,created_at:stamp,updated_at:stamp,archived_at:stamp,required_workspace_type:"PERSONAL"};
beforeEach(()=>{context.mockReset().mockResolvedValue({userId:actor});rpc.mockReset().mockResolvedValue({data:row,error:null});client.mockReset().mockResolvedValue({rpc});});
it("returns canonical archive without client ownership arguments",async()=>{expect(await archiveProject(id)).toEqual(row);expect(rpc).toHaveBeenCalledWith("archive_development_project",{target_project:id});});
it("authorized retry retains timestamp",async()=>expect((await archiveProject(id)).archived_at).toBe(stamp));
it.each([null,"bad",{projectId:id,role:"ADMIN"}])("rejects invalid/spoofed input %j",async input=>{await expect(archiveProject(input)).rejects.toMatchObject({code:"VALIDATION_ERROR"});expect(rpc).not.toHaveBeenCalled();});
it("masks provider details",async()=>{rpc.mockResolvedValue({data:null,error:{code:"42501",message:"Private owner"}});await expect(archiveProject(id)).rejects.toMatchObject({code:"FORBIDDEN",message:"Access denied."});});
it.each([{...row,status:"active"},{...row,archived_at:null},{...row,id:actor}])("rejects invalid canonical result",async data=>{rpc.mockResolvedValue({data,error:null});await expect(archiveProject(id)).rejects.toMatchObject({code:"FORBIDDEN"});});
it("identity change before mutation denied",async()=>{context.mockResolvedValueOnce({userId:actor}).mockResolvedValue({userId:id});await expect(archiveProject(id)).rejects.toMatchObject({code:"FORBIDDEN"});expect(rpc).not.toHaveBeenCalled();});

it("anonymous is denied before database work",async()=>{const {AuthorizationError}=await import("@/lib/auth/authorization");context.mockRejectedValue(new AuthorizationError("AUTH_REQUIRED"));await expect(archiveProject(id)).rejects.toMatchObject({code:"AUTH_REQUIRED"});expect(client).not.toHaveBeenCalled();});
it("identity change after RPC cannot expose canonical result",async()=>{context.mockResolvedValueOnce({userId:actor}).mockResolvedValueOnce({userId:actor}).mockResolvedValue({userId:id});await expect(archiveProject(id)).rejects.toMatchObject({code:"FORBIDDEN"});});
