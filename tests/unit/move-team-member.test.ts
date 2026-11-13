vi.mock('@/features/notifications/email-delivery',()=>({scheduleCommittedNotificationEmails:vi.fn(async()=>{})}));
import {beforeEach,expect,it,vi} from "vitest";
vi.mock("server-only",()=>({}));
const {user,bindings,client,rpc}=vi.hoisted(()=>({user:vi.fn(),bindings:vi.fn(),client:vi.fn(),rpc:vi.fn()}));
vi.mock("@/features/users/service",()=>({requireActivePlatformUser:user}));
vi.mock("@/features/auth/role-assignments",()=>({getActiveRoleAssignments:bindings}));
vi.mock("@/lib/db/server",()=>({createServerSupabaseClient:client}));
import {moveTeamMember} from "@/features/teams/member-service";



import {AuthorizationError} from "@/lib/auth/authorization";
import {SYSTEM_ROLE_IDS} from "@/lib/auth/role-codes";
const uuid=(n:number)=>`00000000-0000-4000-8000-${String(n).padStart(12,"0")}`;
const uid=uuid(4101),cid=uuid(4102),tid=uuid(4103),wid=uuid(4104),org=uuid(501),pid=uuid(601),target=uuid(4110);
const to=uuid(4108);
const result={fromTeamId:tid,toTeamId:to,sourceMembershipId:uuid(4105),targetMembershipId:uuid(4106),chatMembershipId:uuid(4109)};
const meta={created_at:"2026-10-01T00:00:00Z",updated_at:"2026-10-01T00:00:00Z"};
function assignment(role:"ADMIN"|"MASTER"|"STUDENT"|"MENTOR",scope=role==="ADMIN"?org:cid,team=false){return {
 id:uuid(4111),user_id:uid,role_id:SYSTEM_ROLE_IDS[role],organization_id:role==="ADMIN"?scope:null,
 program_id:null,cohort_id:role==="ADMIN"||team?null:scope,team_id:team?scope:null,project_id:null,
 status:"active",starts_at:"2020-01-01T00:00:00Z",ends_at:null,assigned_by:uid,...meta,
};}
const workspace={id:wid,workspace_type:"TEAM",name:"Private Team",owner_user_id:null,team_id:tid,cohort_id:cid,project_id:null,status:"active",visibility:"private",settings:{private:true},created_by:uid,updated_by:uid,archived_at:null,...meta};
let membership:string|null;let chatLevel:string|null;
beforeEach(()=>{
 membership="member";chatLevel="read_write";
 user.mockReset().mockResolvedValue({id:uid});bindings.mockReset().mockResolvedValue([assignment("MASTER")]);
 rpc.mockReset().mockImplementation(async(name:string)=>({data:name==="move_team_member"?result:name==="get_team_workspace_access"?membership:name==="get_team_chat_access"?chatLevel:name==="team_workspace_has_chat_access"?chatLevel!==null:null,error:null}));
 client.mockReset().mockResolvedValue({rpc,from:(table:string)=>({select:()=>({eq:(_key:string,id:string)=>({maybeSingle:async()=>({data:table==="teams"?{id,cohort_id:cid}:table==="cohorts"?{id,program_id:pid}:table==="programs"?{id,organization_id:org}:workspace,error:null})}),order:()=>({order:async()=>({data:[{id:wid}],error:null})})})})});
});
it.each(["MASTER","ADMIN"] as const)("%s authorizes both Teams before one atomic move RPC",async role=>{
 bindings.mockResolvedValue([assignment(role)]);
 expect(await moveTeamMember({userId:target,fromTeamId:tid,toTeamId:to,reason:"Move request"})).toEqual(result);
 expect(rpc).toHaveBeenCalledExactlyOnceWith("move_team_member",{target_user:target,source_team:tid,destination_team:to,move_reason:"Move request"});
});
it("exact Team Master bindings must cover BOTH resources",async()=>{
 bindings.mockResolvedValue([{...assignment("MASTER",tid,true),id:uuid(4112)},{...assignment("MASTER",to,true),id:uuid(4113)}]);
 await expect(moveTeamMember({userId:target,fromTeamId:tid,toTeamId:to})).resolves.toEqual(result);
});
it.each([tid,to])("Master authorized for only %s denied",async scope=>{
 bindings.mockResolvedValue([assignment("MASTER",scope,true)]);await expect(moveTeamMember({userId:target,fromTeamId:tid,toTeamId:to})).rejects.toMatchObject({code:"FORBIDDEN"});expect(rpc).not.toHaveBeenCalled();
});
it.each(["STUDENT","MENTOR"] as const)("%s and contextual Lead cannot move or spoof actor",async role=>{
 bindings.mockResolvedValue([assignment(role)]);await expect(moveTeamMember({userId:target,fromTeamId:tid,toTeamId:to,actorUserId:uid,role:"ADMIN"})).rejects.toMatchObject({code:"FORBIDDEN"});expect(rpc).not.toHaveBeenCalled();
});
it("unrelated Master cannot move by known IDs",async()=>{
 bindings.mockResolvedValue([assignment("MASTER",uuid(4199))]);await expect(moveTeamMember({userId:target,fromTeamId:tid,toTeamId:to})).rejects.toMatchObject({code:"FORBIDDEN"});expect(rpc).not.toHaveBeenCalled();
});
it.each(["inactive","expired","future"])("%s assignment cannot move",async kind=>{
 const row=assignment("MASTER");bindings.mockResolvedValue([{...row,status:kind==="inactive"?"inactive":"active",starts_at:kind==="future"?"2999-01-01T00:00:00Z":row.starts_at,ends_at:kind==="expired"?"2020-02-01T00:00:00Z":null}]);
 await expect(moveTeamMember({userId:target,fromTeamId:tid,toTeamId:to})).rejects.toMatchObject({code:"FORBIDDEN"});expect(rpc).not.toHaveBeenCalled();
});
it("same Team and client scope/role transfer claims rejected",async()=>{
 for(const input of [{userId:target,fromTeamId:tid,toTeamId:tid},{userId:target,fromTeamId:tid,toTeamId:to,membershipRole:"team_lead"},{userId:target,fromTeamId:tid,toTeamId:to,reason:12}])await expect(moveTeamMember(input)).rejects.toMatchObject({code:"VALIDATION_ERROR"});expect(rpc).not.toHaveBeenCalled();
});
it("anonymous caller denied",async()=>{
 user.mockRejectedValue(new AuthorizationError("AUTH_REQUIRED"));await expect(moveTeamMember({userId:target,fromTeamId:tid,toTeamId:to})).rejects.toMatchObject({code:"AUTH_REQUIRED"});expect(rpc).not.toHaveBeenCalled();
});
it.each(["22023","23505"])("cross-Cohort/eligibility/duplicate rejection %s is safe",async code=>{
 rpc.mockResolvedValue({data:null,error:{code,message:"private target enrollment"}});await expect(moveTeamMember({userId:target,fromTeamId:tid,toTeamId:to})).rejects.toMatchObject({code:"VALIDATION_ERROR"});
});
it("provider diagnostics and reused historical row never leak",async()=>{
 rpc.mockRejectedValue(new Error("private source Chat SQL"));await expect(moveTeamMember({userId:target,fromTeamId:tid,toTeamId:to})).rejects.toMatchObject({code:"FORBIDDEN",message:"Access denied."});
 rpc.mockResolvedValue({data:{...result,targetMembershipId:result.sourceMembershipId},error:null});await expect(moveTeamMember({userId:target,fromTeamId:tid,toTeamId:to})).rejects.toMatchObject({code:"FORBIDDEN"});
});

import {scheduleCommittedNotificationEmails} from '@/features/notifications/email-delivery';
it('M15.16 schedules only after successful canonical membership commit',async()=>{
 const schedule=vi.mocked(scheduleCommittedNotificationEmails);schedule.mockClear();
 await moveTeamMember({userId:target,fromTeamId:tid,toTeamId:to});expect(schedule).toHaveBeenCalledExactlyOnceWith({membershipId:result.targetMembershipId,membershipType:'MEMBER_MOVED'});expect(rpc.mock.invocationCallOrder[0]).toBeLessThan(schedule.mock.invocationCallOrder[0]);
 schedule.mockClear();rpc.mockResolvedValue({data:null,error:{code:'42501'}});await expect(moveTeamMember({userId:target,fromTeamId:tid,toTeamId:to})).rejects.toMatchObject({code:'FORBIDDEN'});expect(schedule).not.toHaveBeenCalled();
});
