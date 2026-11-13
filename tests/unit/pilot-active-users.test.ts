import {beforeEach,expect,it,vi} from 'vitest';
vi.mock('server-only',()=>({}));
const m=vi.hoisted(()=>({user:vi.fn(),bindings:vi.fn(),client:vi.fn(),rpc:vi.fn(),organization:vi.fn()}));
vi.mock('@/features/users/service',()=>({requireActivePlatformUser:m.user}));
vi.mock('@/features/auth/role-assignments',()=>({getActiveRoleAssignments:m.bindings}));
vi.mock('@/lib/db/server',()=>({createServerSupabaseClient:m.client}));
import {listPilotActiveUsers} from '@/features/users/pilot-active-users';
import {SYSTEM_ROLE_IDS} from '@/lib/auth/role-codes';
const org='00000000-0000-4000-8000-000000000501',actor='00000000-0000-4000-8000-000000000502';
const row={id:actor,display_name:'Admin',email:'admin@example.test',account_status:'active'};
const binding={id:'00000000-0000-4000-8000-000000000503',user_id:actor,role_id:SYSTEM_ROLE_IDS.ADMIN,organization_id:org,program_id:null,cohort_id:null,team_id:null,project_id:null,starts_at:'2020-01-01T00:00:00Z',ends_at:null,status:'active',assigned_by:actor,created_at:'2020-01-01T00:00:00Z',updated_at:'2020-01-01T00:00:00Z'};
beforeEach(()=>{
 vi.resetAllMocks();m.user.mockResolvedValue({id:actor,account_status:'active'});m.bindings.mockResolvedValue([binding]);
 m.organization.mockResolvedValue({data:{id:org,status:'active'},error:null});m.rpc.mockResolvedValue({data:[row],error:null});
 m.client.mockResolvedValue({from:()=>({select:()=>({eq:()=>({maybeSingle:m.organization})})}),rpc:m.rpc});
});
it('exact active organization Admin uses caller-bound narrow RPC and four-field result',async()=>{
 expect(await listPilotActiveUsers({organizationId:org})).toEqual([row]);
 expect(m.rpc).toHaveBeenCalledExactlyOnceWith('list_pilot_active_users',{target_organization:org});
});
it.each(['STUDENT','MASTER','MENTOR'] as const)('%s alone cannot enumerate',async role=>{
 m.bindings.mockResolvedValue([{...binding,role_id:SYSTEM_ROLE_IDS[role]}]);
 await expect(listPilotActiveUsers({organizationId:org})).rejects.toMatchObject({code:'FORBIDDEN'});expect(m.rpc).not.toHaveBeenCalled();
});
it.each([{organization_id:'00000000-0000-4000-8000-000000000599'},{status:'inactive'},{ends_at:'2021-01-01T00:00:00Z'},{starts_at:'2099-01-01T00:00:00Z'}])('foreign/expired/revoked/future assignment fails %#',async change=>{
 m.bindings.mockResolvedValue([{...binding,...change}]);await expect(listPilotActiveUsers({organizationId:org})).rejects.toMatchObject({code:'FORBIDDEN'});expect(m.rpc).not.toHaveBeenCalled();
});
it('inactive account and inactive organization fail closed',async()=>{
 m.user.mockRejectedValue(new Error('Account inactive'));await expect(listPilotActiveUsers({organizationId:org})).rejects.toMatchObject({code:'FORBIDDEN'});
 m.user.mockResolvedValue({id:actor});m.organization.mockResolvedValue({data:{id:org,status:'inactive'},error:null});await expect(listPilotActiveUsers({organizationId:org})).rejects.toMatchObject({code:'FORBIDDEN'});expect(m.rpc).not.toHaveBeenCalled();
});
it.each(['userId','actorId','role','fields','teamId','email'])('rejects client %s overrides',async field=>{
 await expect(listPilotActiveUsers({organizationId:org,[field]:actor})).rejects.toMatchObject({code:'VALIDATION_ERROR'});expect(m.rpc).not.toHaveBeenCalled();
});
it.each([[{...row,first_name:'PRIVATE'}],[{...row,account_status:'suspended'}],[row,row],null])('rejects excessive/malformed response %#',async data=>{
 m.rpc.mockResolvedValue({data,error:null});await expect(listPilotActiveUsers({organizationId:org})).rejects.toMatchObject({code:'FORBIDDEN'});
});
it('rechecks Admin authority after RPC and sanitizes errors',async()=>{
 m.rpc.mockImplementation(async()=>{m.bindings.mockResolvedValue([]);return {data:[row],error:null};});
 await expect(listPilotActiveUsers({organizationId:org})).rejects.toMatchObject({code:'FORBIDDEN'});
 m.bindings.mockResolvedValue([binding]);m.rpc.mockResolvedValue({data:null,error:{message:'PRIVATE_SQL'}});
 await expect(listPilotActiveUsers({organizationId:org})).rejects.toMatchObject({message:'Access denied.'});
});
it('identity switch during lookup cannot expose previous response',async()=>{
 m.rpc.mockImplementation(async()=>{const id='00000000-0000-4000-8000-000000000504';m.user.mockResolvedValue({id});m.bindings.mockResolvedValue([{...binding,user_id:id}]);return {data:[row],error:null};});
 await expect(listPilotActiveUsers({organizationId:org})).rejects.toMatchObject({code:'FORBIDDEN'});
});
