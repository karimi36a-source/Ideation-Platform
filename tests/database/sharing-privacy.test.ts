import {spawnSync} from 'node:child_process';
import {join} from 'node:path';
import {expect,it,vi} from 'vitest';
vi.mock('server-only',()=>({}));
vi.mock('next/navigation',()=>({notFound:()=>{throw Error('NEXT_NOT_FOUND');},useRouter:()=>({refresh:vi.fn()})}));
const state=vi.hoisted(()=>({userId:'00000000-0000-4000-8000-000000006005',unexpected:[] as string[]}));
vi.mock('@/lib/auth/authorization',async original=>({...await original<typeof import('@/lib/auth/authorization')>(),getAuthorizationContext:async()=>({userId:state.userId,assignments:[]})}));
vi.mock('@/lib/db/server',()=>({createServerSupabaseClient:async()=>({rpc,from:table})}));
import {resolveSharedEntityAccess} from '@/features/shares/access';
import {revokeShare} from '@/features/shares/revoke';
import {getArtifact,getArtifactVersion,listArtifactVersions} from '@/features/artifacts/history';
import {getFileAccess} from '@/features/files/access';
import {getPatentWorkspace} from '@/features/patents/workspace';
import {getMindMapEditor} from '@/features/mind-map/editor-service';
import {createMindMapRoomAuthorizer} from '@/features/mind-map/collaboration';
import {getTeamChatChannel,listTeamChatMessages} from '@/features/chat/service';
import {getTeamChatAccess} from '@/features/chat/access';
import {getTeamChatSubscription} from '@/features/chat/realtime-service';
import {GET} from '@/app/api/v1/workspaces/[workspaceId]/route';
import MindMapPage from '@/app/(platform)/activities/[activityInstanceId]/mind-map/page';
import PatentPage from '@/app/(platform)/projects/[projectId]/patents/page';
const actor=(n:number)=>'00000000-0000-4000-8000-'+String(n).padStart(12,'0');
const literal=(v:unknown):string=>v===null?'null':typeof v==='object'?"'"+JSON.stringify(v).replaceAll("'","''")+"'::jsonb":"'"+String(v).replaceAll("'","''")+"'";
const ident=(v:string)=>{if(!/^[a-z_][a-z0-9_]*$/.test(v))throw Error('Invalid fixture identifier');return v;};
function query(sql:string){
 const port=process.env.FICI_SHARING_PRIVACY_TEST_PORT,bin=process.env.POSTGRES_BIN;
 if(!port||!/^\d+$/.test(port)||!bin)throw Error('Disposable sharing context required');
 const r=spawnSync(join(bin,process.platform==='win32'?'psql.exe':'psql'),['-X','-h','127.0.0.1','-p',port,'-U','postgres','-d','fici_sharing_privacy','-v','ON_ERROR_STOP=1','-t','-A','-f','-'],{input:'\\set VERBOSITY verbose\n'+sql,encoding:'utf8',windowsHide:true,timeout:45000});
 if(r.error||r.status!==0)throw Object.assign(Error('Disposable SQL denied'),{sqlstate:r.stderr.match(/ERROR:\s+([A-Z0-9]{5}):/)?.[1]??'UNKNOWN'});return r.stdout.trim();
}
function result(expression:string){const out=query(`begin;set local role authenticated;select set_config('request.jwt.claim.sub',${literal(state.userId)},true);select 'RESULT='||coalesce(to_jsonb((${expression})),'null'::jsonb)::text;commit;`);const line=out.split(/\r?\n/).find(s=>s.startsWith('RESULT='));if(!line)throw Error('Missing canonical result');return JSON.parse(line.slice(7));}
async function rpc(name:string,args:Record<string,unknown>){try{return {data:result('public.'+ident(name)+'('+Object.entries(args).map(([k,v])=>ident(k)+'=>'+literal(v)).join(',')+')'),error:null};}catch(e){const code=(e as {sqlstate?:string}).sqlstate??'UNKNOWN';if(!['42501','28000','22023'].includes(code))state.unexpected.push(name+':'+code);return {data:null,error:{code}};}}
function table(name:string){
 const allowed=['workspaces','development_projects','artifacts','artifact_versions','development_objects','files','file_links','evidence','evidence_links','patent_records','patent_search_logs','activity_instances','activity_research_links','chat_channels','chat_messages','development_object_relationships','shares','share_snapshots','mind_maps','mind_map_nodes','mind_map_edges'];
 if(!allowed.includes(name))throw Error('Unexpected source table');
 let columns='*';const filters:string[]=[],orders:string[]=[];
 const execute=async(single:boolean)=>{try{const rows=result(`(select coalesce(jsonb_agg(to_jsonb(x)),'[]') from (select ${columns} from public.${name}${filters.length?' where '+filters.join(' and '):''}${orders.length?' order by '+orders.join(','):''}) x)`);if(single&&rows.length>1)throw Error('Non-unique fixture query');return {data:single?(rows[0]??null):rows,error:null};}catch(e){const code=(e as {sqlstate?:string}).sqlstate??'UNKNOWN';if(code!=='42501')state.unexpected.push(name+':'+code);return {data:null,error:{code}};}};
 const builder={select:(v:string)=>{columns=v==='*'?'*':v.split(',').map(ident).join(',');return builder;},eq:(k:string,v:unknown)=>{filters.push(ident(k)+'='+literal(v));return builder;},in:(k:string,v:unknown[])=>{filters.push(ident(k)+' in ('+v.map(literal).join(',')+')');return builder;},is:(k:string,v:null)=>{expect(v).toBeNull();filters.push(ident(k)+' is null');return builder;},order:(k:string,options?:{ascending?:boolean})=>{orders.push(ident(k)+(options?.ascending===false?' desc':' asc'));return builder;},maybeSingle:()=>execute(true),then:(resolve:unknown,reject:unknown)=>execute(false).then(resolve as never,reject as never)};
 return builder;
}
it('M13.23 sharing-relevant AT-E2E-PRIV-001 never pivots from one frozen map into private source routes, services, graph or realtime',async()=>{
 const c=JSON.parse(query('select jsonb_object_agg(label,payload)::text from public.sharing_privacy_fixture'));
 const scope=c.scope,activity=c.activity.activity.id,artifact=c.selected.mindMap.artifact_id,version=c.selected.version.id;
 const provider=vi.fn().mockResolvedValue({status:200,body:'test-provider-authorized'}),room=createMindMapRoomAuthorizer(provider);
 // Genuine source-positive controls: the loaders/records must work for current source authority.
 expect((await getMindMapEditor(activity)).mindMap.id).toBe(c.successor.mindMap.id);
 expect((await getPatentWorkspace(scope.projectId)).patents.some(p=>p.id===c.patent.id)).toBe(true);
 expect((await listTeamChatMessages({teamId:scope.teamId})).items.some(m=>m.content==='PRIVATE M13.23 chat')).toBe(true);
 await room({activityInstanceId:activity});expect(provider).toHaveBeenCalledTimes(1);provider.mockClear();
 const before=query(`select md5(jsonb_build_array((select jsonb_agg(to_jsonb(o) order by id) from public.development_objects o),(select jsonb_agg(to_jsonb(v) order by id) from public.artifact_versions v),(select jsonb_agg(to_jsonb(m) order by id) from public.chat_messages m))::text)`);
 state.userId=actor(6007);
 const shared=await resolveSharedEntityAccess({shareId:c.share.id});
 expect(shared).toMatchObject({allowed:true,sharedEntityId:artifact,sourceVersionId:version,canView:true,canComment:false,canEdit:false,canReshare:false});
 for(const secret of ['PRIVATE M13.23',c.file.storage_reference,c.evidence.id,c.patent.id,c.object_component.id,scope.workspaceId,scope.projectId])expect(JSON.stringify(shared)).not.toContain(secret);
 const denied=async(p:Promise<unknown>)=>{await expect(p).rejects.toMatchObject({code:expect.stringMatching(/^(NOT_FOUND|FORBIDDEN)$/)});};
 async function sourceDenials(){
  const response=await GET(new Request('http://localhost/api/v1/workspaces/'+scope.workspaceId),{params:Promise.resolve({workspaceId:scope.workspaceId})});
  expect(response.status).toBe(403);expect(JSON.stringify(await response.json())).not.toContain('PRIVATE M13.23');
  await expect(MindMapPage({params:Promise.resolve({activityInstanceId:activity})})).rejects.toThrow('NEXT_NOT_FOUND');
  await expect(PatentPage({params:Promise.resolve({projectId:scope.projectId})})).rejects.toThrow('NEXT_NOT_FOUND');
  await denied(getPatentWorkspace(scope.projectId));await denied(getMindMapEditor(activity));
  await denied(getArtifact(artifact));await denied(getArtifact(c.readonlyMap.artifact.id));await denied(listArtifactVersions(artifact));
  for(const id of [c.map.version.id,version,c.successor.version.id])await denied(getArtifactVersion(id));
  await denied(getTeamChatChannel(scope.teamId));await denied(listTeamChatMessages({teamId:scope.teamId}));await denied(getTeamChatAccess(c.chat.chat_channel_id));await denied(getTeamChatSubscription(scope.teamId));
  await denied(room({activityInstanceId:activity}));expect(provider).not.toHaveBeenCalled();
 }
 await sourceDenials();
 const empty=(sql:string)=>{try{expect(result('(select count(*) from ('+sql+') hidden)')).toBe(0);}catch(e){if((e as {sqlstate?:string}).sqlstate!=='42501')throw e;}};
 if(!shared.allowed)throw Error('Missing positive frozen map');
 const nodeIds=(shared.snapshotContent.content_snapshot as {nodes:{id:string}[]}).nodes.map(n=>literal(n.id));
 expect(nodeIds.length).toBeGreaterThan(0);
 expect(query(`select count(*) from public.mind_map_nodes where id in(${nodeIds.join(',')})`)).toBe(String(nodeIds.length));
 empty(`select id from public.mind_map_nodes where id in(${nodeIds.join(',')})`);
 empty(`select id from public.development_objects where id=${literal(c.object_component.id)}`);
 for(const t of ['artifacts','development_objects','files','evidence','patent_records','patent_search_logs','activity_instances'])empty(`select id from public.${t} where workspace_id=${literal(scope.workspaceId)} and project_id=${literal(scope.projectId)} order by id limit 10`);
 for(const sql of [
  `select * from public.shares where id=${literal(c.share.id)}`,`select * from public.share_snapshots where share_id=${literal(c.share.id)}`,
  `select id from public.artifact_versions where artifact_id=${literal(artifact)}`,`select id from public.development_object_relationships where project_id=${literal(scope.projectId)}`,
  `select n.id from public.mind_map_nodes n join public.development_objects o on o.id=n.development_object_id where o.project_id=${literal(scope.projectId)}`,
  `select l.id from public.file_links l join public.files f on f.id=l.file_id where l.entity_id=${literal(artifact)}`,
  `select l.id from public.evidence_links l join public.evidence e on e.id=l.evidence_id where e.id=${literal(c.evidence.id)}`,
  `select id from public.chat_channels where id=${literal(c.chat.chat_channel_id)}`,`select id from public.chat_messages where chat_channel_id=${literal(c.chat.chat_channel_id)}`,
  `select id from storage.objects where name=${literal(c.file.storage_reference)}`,
 ])empty(sql);
 const fetchSpy=vi.spyOn(globalThis,'fetch').mockRejectedValue(Error('No provider access for non-FILE Share'));
 try{await denied(getFileAccess({fileId:c.file.id}));expect(fetchSpy).not.toHaveBeenCalled();await expect(getFileAccess({fileId:c.file.id,storageReference:c.file.storage_reference})).rejects.toMatchObject({code:'VALIDATION_ERROR'});}finally{fetchSpy.mockRestore();}
 expect((await rpc('authorize_shared_file_access',{target_file:c.file.id})).data).toBe(false);
 expect(query("select public from storage.buckets where id='fici-private-files'")).toBe('f');
 expect(query(`select md5(jsonb_build_array((select jsonb_agg(to_jsonb(o) order by id) from public.development_objects o),(select jsonb_agg(to_jsonb(v) order by id) from public.artifact_versions v),(select jsonb_agg(to_jsonb(m) order by id) from public.chat_messages m))::text)`)).toBe(before);
 for(const n of [6001,6002,6003,6008]){state.userId=actor(n);expect((await resolveSharedEntityAccess({shareId:c.share.id})).allowed).toBe(false);await denied(getPatentWorkspace(scope.projectId));await denied(getTeamChatSubscription(scope.teamId));await denied(room({activityInstanceId:activity}));}
 state.userId=actor(6005);await revokeShare(c.share.id);
 state.userId=actor(6007);expect((await resolveSharedEntityAccess({shareId:c.share.id})).allowed).toBe(false);await denied(getMindMapEditor(activity));await denied(getTeamChatSubscription(scope.teamId));
 // Re-share normally, then remove destination membership: no cached positive survives.
 state.userId=actor(6005);
 const again=JSON.parse(query(`begin;set local role authenticated;select set_config('request.jwt.claim.sub',${literal(state.userId)},true);select public.share_entity(${literal({entityType:'ARTIFACT',entityId:artifact,sourceVersionId:version,destinationType:'TEAM',destinationId:scope.teamBId,permissionLevel:'VIEW',shareMode:'SNAPSHOT'})})::text;commit;`).split(/\r?\n/).find(s=>s.startsWith('{'))!);
 state.userId=actor(6007);expect((await resolveSharedEntityAccess({shareId:again.id})).allowed).toBe(true);
 query(`begin;set local role authenticated;select set_config('request.jwt.claim.sub',${literal(actor(6002))},true);select public.remove_team_member(${literal(scope.teamBId)},${literal(actor(6007))},'M13.23 destination removal');commit;`);
 expect((await resolveSharedEntityAccess({shareId:again.id})).allowed).toBe(false);await denied(getPatentWorkspace(scope.projectId));await denied(getTeamChatSubscription(scope.teamId));
 const assignment=query(`select a.id from public.role_assignments a join public.roles r on r.id=a.role_id join public.teams t on t.cohort_id=a.cohort_id where t.id=${literal(scope.teamId)} and a.user_id=${literal(actor(6002))} and r.code='MASTER' and a.status='active'`);
 const masterShare=JSON.parse(query(`begin;set local role authenticated;select set_config('request.jwt.claim.sub',${literal(actor(6005))},true);select public.share_entity(${literal({entityType:'ARTIFACT',entityId:artifact,sourceVersionId:version,destinationType:'MASTER',destinationId:assignment,permissionLevel:'VIEW',shareMode:'SNAPSHOT'})})::text;commit;`).split(/\r?\n/).find(s=>s.startsWith('{'))!);
 state.userId=actor(6002);expect((await resolveSharedEntityAccess({shareId:masterShare.id})).allowed).toBe(true);
 query(`update public.role_assignments set ends_at=clock_timestamp()-interval '1 second' where id=${literal(assignment)}`);
 expect((await resolveSharedEntityAccess({shareId:masterShare.id})).allowed).toBe(false);
 query(`update public.role_assignments set ends_at=null,status='inactive' where id=${literal(assignment)}`);
 expect((await resolveSharedEntityAccess({shareId:masterShare.id})).allowed).toBe(false);
 expect(state.unexpected).toEqual([]);
},180000);
