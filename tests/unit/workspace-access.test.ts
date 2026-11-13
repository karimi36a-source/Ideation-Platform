import {beforeEach,expect,it,vi} from "vitest";
vi.mock("server-only",()=>({}));
const {user,bindings,client}=vi.hoisted(()=>({user:vi.fn(),bindings:vi.fn(),client:vi.fn()}));
vi.mock("@/features/users/service",()=>({requireActivePlatformUser:user}));
vi.mock("@/features/auth/role-assignments",()=>({getActiveRoleAssignments:bindings}));
vi.mock("@/lib/db/server",()=>({createServerSupabaseClient:client}));
import {getWorkspace,listMyWorkspaces,createMasterWorkspace} from "@/features/workspaces/service";
import {getWorkspaceAccess} from "@/features/workspaces/access";
import {SYSTEM_ROLE_IDS} from "@/lib/auth/role-codes";
const uuid=(n:number)=>`00000000-0000-4000-8000-${String(n).padStart(12,"0")}`;
const uid=uuid(1602),cid=uuid(1610),wid=uuid(1620);
const meta={created_at:"2026-10-01T00:00:00Z",updated_at:"2026-10-01T00:00:00Z"};
const w={id:wid,workspace_type:"PERSONAL",name:"Private secret name",owner_user_id:uid,team_id:null,cohort_id:null as string|null,project_id:null,status:"active",visibility:"private",settings:{sensitive:"private"},created_by:uid,updated_by:uid,archived_at:null,...meta};
let row:typeof w|null;let reads=0;const rpc=vi.fn();
function binding(role:"MASTER"|"ADMIN"|"STUDENT"|"MENTOR",scope=cid){return {id:uuid(1630),user_id:uid,role_id:SYSTEM_ROLE_IDS[role],organization_id:role==="ADMIN"?scope:null,program_id:null,cohort_id:role==="ADMIN"?null:scope,team_id:null,project_id:null,status:"active",starts_at:"2020-01-01T00:00:00Z",ends_at:null,assigned_by:uid,...meta};}
beforeEach(()=>{row={...w};reads=0;user.mockReset().mockResolvedValue({id:uid});bindings.mockReset().mockResolvedValue([]);rpc.mockReset().mockImplementation(async()=>({data:row,error:null}));client.mockReset().mockResolvedValue({rpc,from:(table:string)=>({select:()=>({eq:(_field:string,id:string)=>({maybeSingle:async()=>{reads++;return {data:table==="cohorts"?{id}:row,error:null};}}),order:()=>({order:async()=>({data:row?[{id:row.id}]:[],error:null})})})})});});
it("Personal owner gets only implemented capabilities and no metadata",async()=>{expect(await getWorkspaceAccess(wid)).toEqual({canView:true,canCreate:true,canEdit:true,canComment:false,canShare:false,canReview:false,canApprove:false,canManageMembers:false,canAccessChat:false});expect(reads).toBe(2);});
it.each(["MASTER","ADMIN","STUDENT","MENTOR"] as const)("%s cannot access another owner's Personal",async role=>{bindings.mockResolvedValue([binding(role)]);row={...w,owner_user_id:uuid(1699)};await expect(getWorkspaceAccess(wid)).rejects.toMatchObject({code:"FORBIDDEN",message:"Access denied."});});
it.each(["MASTER","CASE_STUDY"])("%s requires owner plus exact cohort MASTER",async workspace_type=>{row={...w,workspace_type,cohort_id:cid};bindings.mockResolvedValue([binding("MASTER")]);expect((await getWorkspaceAccess(wid)).canView).toBe(true);bindings.mockResolvedValue([binding("MASTER",uuid(1699))]);await expect(getWorkspaceAccess(wid)).rejects.toMatchObject({code:"FORBIDDEN"});});
it.each(["MASTER","CASE_STUDY"])("%s ownership alone/unscoped is denied",async workspace_type=>{row={...w,workspace_type};bindings.mockResolvedValue([binding("MASTER")]);await expect(getWorkspaceAccess(wid)).rejects.toMatchObject({code:"FORBIDDEN"});});
it.each(["TEAM","SHARED"])("%s defaults deny even for owner",async workspace_type=>{row={...w,workspace_type};bindings.mockResolvedValue([binding("MASTER")]);await expect(getWorkspaceAccess(wid)).rejects.toMatchObject({code:"FORBIDDEN"});});
it.each(["inactive","archived"])("%s denies normal capabilities",async status=>{row={...w,status};await expect(getWorkspaceAccess(wid)).rejects.toMatchObject({code:"FORBIDDEN"});});
it("client-supplied role/scope object cannot resolve access",async()=>{await expect(getWorkspaceAccess({id:wid,userId:uid,role:"MASTER",cohortId:cid})).rejects.toMatchObject({code:"VALIDATION_ERROR"});expect(client).not.toHaveBeenCalled();});
it("missing and inaccessible return same safe error without metadata",async()=>{row=null;await expect(getWorkspaceAccess(wid)).rejects.toMatchObject({code:"FORBIDDEN",message:"Access denied."});row={...w,owner_user_id:uuid(1699)};await expect(getWorkspaceAccess(wid)).rejects.toMatchObject({code:"FORBIDDEN",message:"Access denied."});});
it("scope revoked during resolution fails closed",async()=>{row={...w,workspace_type:"MASTER",cohort_id:cid};bindings.mockResolvedValueOnce([binding("MASTER")]).mockResolvedValue([]);await expect(getWorkspaceAccess(wid)).rejects.toMatchObject({code:"FORBIDDEN"});});

it("M4.4 owner retrieves authorized metadata and list",async()=>{expect(await getWorkspace(wid)).toEqual(w);expect(await listMyWorkspaces()).toEqual([w]);});
it.each(["MASTER","ADMIN","MENTOR","STUDENT"] as const)("M4.4 %s cannot retrieve another Personal by guessed ID",async role=>{bindings.mockResolvedValue([binding(role)]);row={...w,owner_user_id:uuid(1699)};await expect(getWorkspace(wid)).rejects.toMatchObject({code:"FORBIDDEN",message:"Access denied."});expect(await listMyWorkspaces()).toEqual([]);});
it("M4.4 missing and private UUID return identical error",async()=>{row=null;await expect(getWorkspace(wid)).rejects.toMatchObject({code:"FORBIDDEN",message:"Access denied."});});
it.each(["MASTER","CASE_STUDY"])("M4.4 scoped owner retrieves %s; unrelated denied",async workspace_type=>{row={...w,workspace_type,cohort_id:cid};bindings.mockResolvedValue([binding("MASTER")]);expect(await getWorkspace(wid)).toEqual(row);bindings.mockResolvedValue([binding("MASTER",uuid(1699))]);await expect(getWorkspace(wid)).rejects.toMatchObject({code:"FORBIDDEN"});expect(await listMyWorkspaces()).toEqual([]);});
it.each(["TEAM","SHARED"])("M4.4 %s absent from lists and denied directly",async workspace_type=>{row={...w,workspace_type};expect(await listMyWorkspaces()).toEqual([]);await expect(getWorkspace(wid)).rejects.toMatchObject({code:"FORBIDDEN"});});
it.each(["inactive","archived"])("M4.4 %s absent from lists",async status=>{row={...w,status};expect(await listMyWorkspaces()).toEqual([]);});
it("M4.4 spoofed role/scope cannot retrieve metadata",async()=>{await expect(getWorkspace({id:wid,role:"ADMIN",owner_user_id:uid})).rejects.toMatchObject({code:"VALIDATION_ERROR"});});

it("M4.4 provider exceptions never expose sensitive diagnostics",async()=>{client.mockRejectedValue(new Error("Private owner email and SQL details"));await expect(getWorkspace(wid)).rejects.toMatchObject({code:"FORBIDDEN",message:"Access denied."});await expect(listMyWorkspaces()).rejects.toMatchObject({code:"FORBIDDEN",message:"Access denied."});});

it("M4.6 scoped Master provisions through owner-free RPC and resolver",async()=>{row={...w,workspace_type:"MASTER",cohort_id:cid};bindings.mockResolvedValue([binding("MASTER")]);expect(await createMasterWorkspace(cid)).toEqual(row);expect(rpc).toHaveBeenCalledWith("create_master_workspace",{target_cohort:cid});});
it.each(["ADMIN","STUDENT","MENTOR"] as const)("M4.6 %s cannot provision Master",async role=>{bindings.mockResolvedValue([binding(role)]);await expect(createMasterWorkspace(cid)).rejects.toMatchObject({code:"FORBIDDEN"});expect(rpc).not.toHaveBeenCalled();});
it("M4.6 unrelated cohort and spoofed owner/scope denied",async()=>{bindings.mockResolvedValue([binding("MASTER",uuid(1699))]);await expect(createMasterWorkspace(cid)).rejects.toMatchObject({code:"FORBIDDEN"});await expect(createMasterWorkspace({cohortId:cid,ownerUserId:uid,role:"MASTER"})).rejects.toMatchObject({code:"VALIDATION_ERROR"});expect(rpc).not.toHaveBeenCalled();});
it("M4.6 provisioning response cannot hijack ownership",async()=>{row={...w,workspace_type:"MASTER",cohort_id:cid};bindings.mockResolvedValue([binding("MASTER")]);rpc.mockResolvedValue({data:{...row,owner_user_id:uuid(1699)},error:null});await expect(createMasterWorkspace(cid)).rejects.toMatchObject({code:"FORBIDDEN"});});
