import {beforeEach,expect,it,vi} from 'vitest';
vi.mock('server-only',()=>({}));
vi.mock('@/features/teams/portal',()=>({getMyCohortTeams:vi.fn().mockResolvedValue([])}));
const m=vi.hoisted(()=>({auth:vi.fn(),rpc:vi.fn(),from:vi.fn(),token:vi.fn(),status:vi.fn(),metadata:vi.fn()}));
vi.mock('@/lib/auth/authorization',async()=>{const actual=await vi.importActual<typeof import('@/lib/auth/authorization')>('@/lib/auth/authorization');return {...actual,getAuthorizationContext:m.auth};});
vi.mock('@/lib/db/server',()=>({createServerSupabaseClient:async()=>({rpc:m.rpc,from:m.from})}));
vi.mock('@/features/live-classroom/current-activity',()=>({listLiveCurrentActivityIds:vi.fn().mockResolvedValue([])}));
vi.mock('@/features/live-classroom/join-token',()=>({getLiveSessionJoinToken:m.token}));
vi.mock('@/features/live-classroom/factory',()=>({createLiveClassroomProvider:()=>({getRoomStatus:m.status})}));
vi.mock('@/features/activities/definition-metadata',()=>({getActivityDefinitionMetadata:m.metadata}));
import {getLiveClassroomView,getLiveClassroomJoin} from '@/features/live-classroom/classroom';
import {POST} from '@/app/api/live-classroom/join/route';
const id=(n:number)=>`00000000-0000-4000-8000-${String(n).padStart(12,'0')}`;
const context={liveSessionRoomId:id(1),cohortId:id(2),cohortName:'Cohort',sessionDefinitionId:id(3),sessionTitle:'Session'};
beforeEach(()=>{vi.clearAllMocks();m.metadata.mockResolvedValue({id:id(10),name:'Mind Map',session_definition_id:id(3),method_type:'mind_map'});m.auth.mockResolvedValue({userId:id(4)});m.rpc.mockImplementation(async name=>({data:name==='get_live_classroom_context'?context:{liveSessionRoomId:id(1),providerRoomRef:'canonical-room',userId:id(4)},error:null}));m.token.mockResolvedValue({token:'ephemeral.token',expiresAt:Math.floor(Date.now()/1000)+60});m.status.mockResolvedValue({success:true,data:{status:'available',url:'https://pilot.daily.co/canonical-room'}});});
it('page projection contains no token or room reference and makes no provider call',async()=>{expect(await getLiveClassroomView({liveSessionRoomId:id(1)})).toEqual({liveSessionRoomId:id(1),cohortName:'Cohort',sessionTitle:'Session',activity:null});expect(m.token).not.toHaveBeenCalled();expect(m.status).not.toHaveBeenCalled();expect(m.from).not.toHaveBeenCalled();});
it('uses M16.5 alone to issue capability and canonical provider lookup for URL',async()=>{expect(await getLiveClassroomJoin({liveSessionRoomId:id(1)})).toMatchObject({url:'https://pilot.daily.co/canonical-room',token:'ephemeral.token'});expect(m.token).toHaveBeenCalledWith({liveSessionRoomId:id(1)});expect(m.status).toHaveBeenCalledWith('canonical-room');});
it('unauthorized context never calls provider or token issuer',async()=>{m.rpc.mockResolvedValue({data:null,error:{code:'42501'}});await expect(getLiveClassroomJoin({liveSessionRoomId:id(1)})).rejects.toThrow();await expect(getLiveClassroomView({liveSessionRoomId:id(1)})).rejects.toThrow();expect(m.token).not.toHaveBeenCalled();expect(m.status).not.toHaveBeenCalled();});
it.each(['role','cohortId','providerRoomRef','userId','token'])('spoofed %s is rejected before provider',async field=>{await expect(getLiveClassroomJoin({liveSessionRoomId:id(1),[field]:'spoof'})).rejects.toThrow();expect(m.token).not.toHaveBeenCalled();});
it.each(['missing','expired'])('provider %s status issues no token',async status=>{m.status.mockResolvedValue({success:true,data:{status}});await expect(getLiveClassroomJoin({liveSessionRoomId:id(1)})).rejects.toThrow();expect(m.token).not.toHaveBeenCalled();});
it('Activity visibility checked independently before any Activity metadata query',async()=>{m.rpc.mockImplementation(async name=>({data:name==='can_read_activity_instance'?false:context,error:null}));await expect(getLiveClassroomView({liveSessionRoomId:id(1),activityInstanceId:id(9)})).rejects.toThrow();expect(m.from).not.toHaveBeenCalled();});
it('POST rejects foreign/missing origin and never invokes auth/provider',async()=>{for(const origin of [null,'https://evil.example']){const response=await POST(new Request('https://fici.test/api/live-classroom/join',{method:'POST',headers:origin?{origin}:{},body:'{}'}));expect(response.status).toBe(403);expect(response.headers.get('Cache-Control')).toContain('no-store');}expect(m.rpc).not.toHaveBeenCalled();});
it('POST safe denial masks provider/token diagnostics and never caches capability',async()=>{m.token.mockRejectedValue(Error('DAILY_API_KEY server-secret'));const response=await POST(new Request('https://fici.test/api/live-classroom/join',{method:'POST',headers:{origin:'https://fici.test'},body:JSON.stringify({liveSessionRoomId:id(1)})}));expect(response.status).toBe(403);expect(await response.text()).not.toMatch(/server-secret|DAILY_API_KEY/);expect(response.headers.get('Cache-Control')).toContain('no-store');});
it('POST successful token transport is private and not in redirects or GET',async()=>{const response=await POST(new Request('https://fici.test/api/live-classroom/join',{method:'POST',headers:{origin:'https://fici.test'},body:JSON.stringify({liveSessionRoomId:id(1)})}));expect(response.status).toBe(200);expect(response.headers.get('Cache-Control')).toContain('no-store');expect(response.headers.get('Location')).toBeNull();expect(await response.json()).toMatchObject({token:'ephemeral.token'});});
it('authorized Activity summary uses caller RLS, exact room Session and existing Mind Map route',async()=>{
 m.rpc.mockImplementation(async name=>({data:name==='can_read_activity_instance'?true:context,error:null}));
 m.from.mockImplementation(table=>{const data=table==='activity_instances'?{id:id(9),cohort_id:id(2),activity_definition_id:id(10),project_id:id(11),team_id:id(12),status:'active'}:table==='activity_definitions'?{name:'Mind Map',session_definition_id:id(3),method_type:'mind_map'}:table==='development_projects'?{name:'Authorized project'}:{name:'Authorized Team'};const q={select:vi.fn(),eq:vi.fn(),maybeSingle:async()=>({data,error:null})};q.select.mockReturnValue(q);q.eq.mockReturnValue(q);return q;});
 const view=await getLiveClassroomView({liveSessionRoomId:id(1),activityInstanceId:id(9)});
 expect(view.activity).toEqual({activityInstanceId:id(9),activityType:'mind_map',name:'Mind Map',status:'active',href:`/activities/${id(9)}/mind-map`,projectName:'Authorized project',teamName:'Authorized Team'});
 expect(m.token).not.toHaveBeenCalled();expect(m.from.mock.calls.some(c=>c[0]==='activity_definitions')).toBe(false);expect(m.metadata).toHaveBeenCalledWith(id(9));
});
it('Activity from another room Cohort cannot be rendered even if independently readable',async()=>{
 m.rpc.mockImplementation(async name=>({data:name==='can_read_activity_instance'?true:context,error:null}));
 const q={select:vi.fn(),eq:vi.fn(),maybeSingle:async()=>({data:{id:id(9),cohort_id:id(999),activity_definition_id:id(10),project_id:id(11),team_id:null,status:'active'},error:null})};q.select.mockReturnValue(q);q.eq.mockReturnValue(q);m.from.mockReturnValue(q);
 await expect(getLiveClassroomView({liveSessionRoomId:id(1),activityInstanceId:id(9)})).rejects.toThrow();
 expect(m.from).toHaveBeenCalledTimes(1);
});


it('wrong Session or definition from gated metadata fails closed',async()=>{
 m.rpc.mockImplementation(async name=>({data:name==='can_read_activity_instance'?true:context,error:null}));
 const q={select:()=>q,eq:()=>q,maybeSingle:async()=>({data:{id:id(9),cohort_id:id(2),activity_definition_id:id(10),project_id:id(11),team_id:null,status:'active'},error:null})};m.from.mockReturnValue(q);
 for(const metadata of [{id:id(999),session_definition_id:id(3)},{id:id(10),session_definition_id:id(999)}]){m.metadata.mockResolvedValue({...metadata,name:'Mind Map',method_type:'mind_map'});await expect(getLiveClassroomView({liveSessionRoomId:id(1),activityInstanceId:id(9)})).rejects.toThrow();}
});
