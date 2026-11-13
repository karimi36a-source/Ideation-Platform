import {beforeEach,expect,it,vi} from 'vitest';
vi.mock('server-only',()=>({}));
const m=vi.hoisted(()=>({auth:vi.fn(),rpc:vi.fn(),from:vi.fn(),work:vi.fn(),access:vi.fn(),metadata:vi.fn()}));
vi.mock('@/lib/auth/authorization',async original=>({...await original<typeof import('@/lib/auth/authorization')>(),getAuthorizationContext:m.auth}));
vi.mock('@/lib/db/server',()=>({createServerSupabaseClient:async()=>({rpc:m.rpc,from:m.from})}));
vi.mock('@/features/progress/current-work',()=>({getMyCurrentWork:m.work}));
vi.mock('@/features/workspaces/access',()=>({getWorkspaceAccess:m.access}));
vi.mock('@/features/activities/definition-metadata',()=>({getActivityDefinitionMetadata:m.metadata}));
import {getMyCohortTeams,getTeamPortal} from '@/features/teams/portal';
const id=(n:number)=>`00000000-0000-4000-8000-${String(n).padStart(12,'0')}`;
let teams:{id:string;name:string;workspace_id:string;cohort_id:string;status:string;archived_at:null}[];
beforeEach(()=>{vi.clearAllMocks();m.auth.mockResolvedValue({userId:id(1),assignments:[]});teams=[{id:id(2),name:'Team A',workspace_id:id(3),cohort_id:id(4),status:'active',archived_at:null}];m.rpc.mockResolvedValue({data:'member',error:null});m.work.mockResolvedValue({contexts:[]});m.access.mockResolvedValue({canView:true,canAccessChat:true});m.from.mockImplementation(()=>{let selected:string|null=null;const q={select:()=>q,eq:(field:string,value:string)=>{if(field==='id')selected=value;return q;},in:()=>q,is:()=>q,order:()=>q,range:async()=>({data:teams.map(t=>({id:t.id})),error:null}),maybeSingle:async()=>({data:teams.find(t=>t.id===selected)??null,error:null})};return q;});});
it('resolves one current Team without trusting a client actor',async()=>{expect(await getMyCohortTeams(id(4))).toEqual([{id:id(2),name:'Team A',href:`/teams/${id(2)}`}]);expect(m.rpc).toHaveBeenCalledWith('get_team_workspace_access',{target_workspace:id(3)});});
it('individual participant has no Team requirement',async()=>{teams=[];expect(await getMyCohortTeams(id(4))).toEqual([]);});
it('all multiple authorized Team candidates remain explicit',async()=>{teams.push({...teams[0],id:id(5),name:'Team B',workspace_id:id(6)});expect((await getMyCohortTeams(id(4))).map(t=>t.id)).toEqual([id(2),id(5)]);});
it.each([null,'mentor','admin','true'])('cross-Team/removed/role-only result %s grants no portal',async data=>{m.rpc.mockResolvedValue({data,error:null});expect(await getMyCohortTeams(id(4))).toEqual([]);await expect(getTeamPortal(id(2))).rejects.toMatchObject({code:'FORBIDDEN'});});
it('membership loss during discovery withholds stale navigation',async()=>{m.rpc.mockResolvedValueOnce({data:'member',error:null}).mockResolvedValue({data:null,error:null});await expect(getMyCohortTeams(id(4))).rejects.toMatchObject({code:'FORBIDDEN'});});
it('portal retains canonical Team and Workspace, without sibling contexts',async()=>{m.work.mockResolvedValue({contexts:[{team:{id:id(9)},workspace:{id:id(8)},cohort:{id:id(4)},project:{id:id(7),name:'Private sibling'},activities:[]}]});const result=await getTeamPortal(id(2));expect(result.team.id).toBe(id(2));expect(result.workspaceId).toBe(id(3));expect(result.projects).toEqual([]);expect(result.activities).toEqual([]);});
it('identity changes fail closed',async()=>{m.auth.mockResolvedValueOnce({userId:id(1)}).mockResolvedValue({userId:id(99)});await expect(getTeamPortal(id(2))).rejects.toMatchObject({code:'FORBIDDEN'});});

it('portal tool route uses M7 metadata with no direct definition SELECT',async()=>{
 m.work.mockResolvedValue({contexts:[{team:{id:id(2)},workspace:{id:id(3)},cohort:{id:id(4)},project:{id:id(7),name:'Team project'},activities:[{instanceId:id(8),definition:{id:id(9),name:'Activity'},session:{id:id(10)},status:'active'}]}]});
 m.metadata.mockResolvedValue({id:id(9),name:'Canonical Mind Map',session_definition_id:id(10),method_type:'mind_map'});
 expect((await getTeamPortal(id(2))).activities).toEqual([{id:id(8),name:'Canonical Mind Map',status:'active',href:'/activities/'+id(8)+'/mind-map'}]);
 expect(m.from.mock.calls.some(c=>c[0]==='activity_definitions')).toBe(false);
 m.metadata.mockResolvedValue({id:id(999),name:'Wrong definition',session_definition_id:id(10),method_type:'mind_map'});await expect(getTeamPortal(id(2))).rejects.toMatchObject({code:'FORBIDDEN'});
});
