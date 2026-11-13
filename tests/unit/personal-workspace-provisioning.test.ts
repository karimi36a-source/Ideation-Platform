import {beforeEach,expect,it,vi} from "vitest";
vi.mock("server-only",()=>({}));
const {user,client,rpc}=vi.hoisted(()=>({user:vi.fn(),client:vi.fn(),rpc:vi.fn()}));
vi.mock("@/features/users/service",()=>({requireActivePlatformUser:user}));
vi.mock("@/lib/db/server",()=>({createServerSupabaseClient:client}));
import {createPersonalWorkspace} from "@/features/workspaces/service";
import {AuthenticationRequiredError} from "@/lib/auth/errors";
const uid="00000000-0000-4000-8000-000000001501";
const w={id:uid,workspace_type:"PERSONAL",name:"My Workspace",owner_user_id:uid,team_id:null,cohort_id:null,project_id:null,status:"active",visibility:"private",settings:{},created_at:"2026-10-01T00:00:00Z",updated_at:"2026-10-01T00:00:00Z",created_by:uid,updated_by:uid,archived_at:null};
beforeEach(()=>{user.mockReset().mockResolvedValue({id:uid});rpc.mockReset().mockResolvedValue({data:w,error:null});client.mockReset().mockResolvedValue({rpc});});
it("uses no owner argument and returns same workspace on retries",async()=>{expect(await createPersonalWorkspace()).toEqual(w);expect(await createPersonalWorkspace()).toEqual(w);expect(rpc).toHaveBeenCalledWith("create_personal_workspace");});
it("anonymous identity is denied before database call",async()=>{user.mockRejectedValue(new Error("Authentication required"));await expect(createPersonalWorkspace()).rejects.toThrow();expect(rpc).not.toHaveBeenCalled();});
it("another owner in provider response fails closed",async()=>{rpc.mockResolvedValue({data:{...w,owner_user_id:"00000000-0000-4000-8000-000000001502"},error:null});await expect(createPersonalWorkspace()).rejects.toMatchObject({code:"FORBIDDEN"});});
it("identity change during provisioning fails closed",async()=>{user.mockResolvedValueOnce({id:uid}).mockResolvedValue({id:"00000000-0000-4000-8000-000000001502"});await expect(createPersonalWorkspace()).rejects.toMatchObject({code:"FORBIDDEN"});});
it("provider details are not exposed",async()=>{rpc.mockResolvedValue({data:null,error:{code:"42501",message:"Private provider details"}});await expect(createPersonalWorkspace()).rejects.toMatchObject({code:"FORBIDDEN",message:"Access denied."});});
it.each(["connection","rpc"])("thrown %s diagnostics are sanitized",async phase=>{
 const error=new Error("Private SQL, owner email, provider diagnostics");
 if(phase==="connection")client.mockRejectedValue(error);else rpc.mockRejectedValue(error);
 await expect(createPersonalWorkspace()).rejects.toMatchObject({code:"FORBIDDEN",message:"Access denied."});
});
it("typed anonymous failure preserves the stable authentication-required response",async()=>{
 user.mockRejectedValue(new AuthenticationRequiredError());
 await expect(createPersonalWorkspace()).rejects.toMatchObject({code:"AUTH_REQUIRED",message:"Authentication required."});
 expect(rpc).not.toHaveBeenCalled();
});

it.each(["MASTER","TEAM","SHARED","CASE_STUDY"])("client arguments cannot turn Personal provisioning into %s",async workspace_type=>{
 const result=await Reflect.apply(createPersonalWorkspace,undefined,[{workspace_type,owner_user_id:"00000000-0000-4000-8000-000000009999",team_id:"00000000-0000-4000-8000-000000009998"}]);
 expect(result).toEqual(w);expect(rpc).toHaveBeenCalledWith("create_personal_workspace");expect(rpc.mock.calls[0]).toHaveLength(1);
});
