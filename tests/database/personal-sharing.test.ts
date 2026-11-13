import {spawnSync} from 'node:child_process';
import {join} from 'node:path';
import {expect,it,vi} from 'vitest';
vi.mock('server-only',()=>({}));
const state=vi.hoisted(()=>({userId:'00000000-0000-4000-8000-000000006004'}));
vi.mock('@/lib/auth/authorization',async original=>({...await original<typeof import('@/lib/auth/authorization')>(),getAuthorizationContext:async()=>({userId:state.userId,assignments:[]})}));
vi.mock('@/lib/db/server',()=>({createServerSupabaseClient:async()=>({rpc:rpcTransport,from:tableTransport})}));
import {shareEntity} from '@/features/shares/create';
import type {Share} from '@/features/shares/schema';
import {resolveSharedEntityAccess} from '@/features/shares/access';
import {addSharedComment,listSharedComments} from '@/features/shares/comments';
import {revokeShare} from '@/features/shares/revoke';
import {listEntityShares} from '@/features/shares/history';
import {updateScamperEntry} from '@/features/scamper/service';
import {getScamperEntry,listScamperEntries,shareScamperEntryToTeam} from '@/features/scamper/privacy';
import {getFileAccess} from '@/features/files/access';
import {listMyWorkspaces} from '@/features/workspaces/service';
import {GET} from '@/app/api/v1/workspaces/[workspaceId]/route';
const owner='00000000-0000-4000-8000-000000006004',recipient='00000000-0000-4000-8000-000000006005',master='00000000-0000-4000-8000-000000006002';
function literal(v:string){return `'${v.replaceAll("'","''")}'`;}
function query(sql:string){
 const port=process.env.FICI_PERSONAL_SHARE_TEST_PORT;if(!port||!/^\d+$/.test(port)||!process.env.POSTGRES_BIN)throw Error('Disposable context required');
 const r=spawnSync(join(process.env.POSTGRES_BIN,process.platform==='win32'?'psql.exe':'psql'),['-X','-h','127.0.0.1','-p',port,'-U','postgres','-d','fici_personal_sharing','-v','ON_ERROR_STOP=1','-t','-A','-f','-'],{input:sql,encoding:'utf8',windowsHide:true,timeout:45000});
 if(r.error||r.status!==0)throw Error('Disposable SQL denied');return r.stdout.trim();
}
function current(sql:string){return query(`begin;set local role authenticated;select set_config('request.jwt.claim.sub',${literal(state.userId)},true);${sql};commit;`);}
function result(sql:string){const line=current(`select 'RESULT='||(${sql})::text`).split(/\r?\n/).find(s=>s.startsWith('RESULT='));if(!line)throw Error('Missing canonical result');return JSON.parse(line.slice(7));}
async function rpcTransport(name:string,args:Record<string,unknown>){
 const jsonCalls=['share_entity','resolve_shared_entity_access','add_share_comment','list_share_comments','revoke_share','list_entity_shares'];const idCalls:Record<string,string>={get_scamper_entry:'target_entry',list_scamper_entries:'target_instance',get_team_workspace_access:'target_workspace',team_workspace_has_chat_access:'target_workspace'};
 try{
  if(name==='authorize_shared_file_access')return {data:result(`to_jsonb(public.authorize_shared_file_access(${literal(String(args.target_file))}::uuid))`),error:null};
  if(name==='update_scamper_entry')return {data:result(`public.update_scamper_entry(${literal(String(args.target_entry))}::uuid,${literal(JSON.stringify(args.changes))}::jsonb)`),error:null};
  if(jsonCalls.includes(name))return {data:result(`public.${name}(${literal(JSON.stringify(args.input))}::jsonb)`),error:null};
  if(idCalls[name])return {data:result(`to_jsonb(public.${name}(${literal(String(args[idCalls[name]]))}::uuid))`),error:null};
  throw Error('Unexpected RPC');
 }catch{return {data:null,error:{code:'42501'}};}
}
function tableTransport(table:string){
 if(!['workspaces','files'].includes(table))throw Error('Unexpected table');
 let columns='*',id:string|undefined;
 const execute=async(single:boolean)=>{
  try{const rows=result(`(select coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb) from (select ${columns} from public.${table}${id?` where id=${literal(id)}::uuid`:''} order by created_at,id) x)`);return {data:single?(rows[0]??null):rows,error:null};}catch{return {data:null,error:{code:'42501'}};}
 };
 const builder={select:(v:string)=>{if(!['*','id'].includes(v))throw Error('Unexpected projection');columns=v;return builder;},eq:(k:string,v:string)=>{if(k!=='id')throw Error('Unexpected filter');id=v;return builder;},order:()=>builder,maybeSingle:()=>execute(true),then:(resolve:unknown,reject:unknown)=>execute(false).then(resolve as never,reject as never)};
 return builder;
}
it('AT-PW-004 and AT-SCAMPER-003 preserve selected-only Personal ownership through actual M13 services and database RLS',async()=>{
 const fetchSpy=vi.spyOn(globalThis,'fetch').mockRejectedValue(Error('Provider access forbidden for unshared File'));
 const c=JSON.parse(query('select jsonb_object_agg(label,payload)::text from public.personal_share_context'));
 const sourceBefore=query(`select jsonb_build_object('objects',(select jsonb_agg(to_jsonb(x) order by id) from public.development_objects x where workspace_id=${literal(c.Workspace.id)}),'scamper',(select jsonb_agg(to_jsonb(x) order by id) from public.scamper_entries x where workspace_id=${literal(c.Workspace.id)}),'workspace',(select to_jsonb(x) from public.workspaces x where id=${literal(c.Workspace.id)}),'file',(select to_jsonb(x) from public.files x where id=${literal(c.File.id)}))::text`);
 const make=(type:string,id:string,permission='VIEW')=>({entityType:type,entityId:id,destinationType:'TEAM',destinationId:c.TeamA.teamId,permissionLevel:permission,shareMode:'SNAPSHOT'});
 const shares=[];
 for(let n=1;n<=3;n++)shares.push(await shareEntity(make('DEVELOPMENT_OBJECT',c[`Idea${n}`].id,n===2?'COMMENT':'VIEW')));
 const artifactShare=await shareEntity({...make('ARTIFACT',c.Artifact.artifactId),sourceVersionId:c.Version.id});
 const scamperShare=await shareScamperEntryToTeam(make('SCAMPER_ENTRY',c.Scamper1.id));
 expect(await shareScamperEntryToTeam(make('SCAMPER_ENTRY',c.Scamper1.id))).toEqual(scamperShare);
 expect(Number(query(`select count(*) from public.shares where source_workspace_id=${literal(c.Workspace.id)}`))).toBe(5);
 state.userId=recipient;
 for(const [n,s] of shares.entries()){
  const access=await resolveSharedEntityAccess({shareId:s.id});expect(access).toMatchObject({allowed:true,sharedEntityId:c[`Idea${n+1}`].id,canEdit:false,canReshare:false,canComment:n===1});
 }
 expect(await resolveSharedEntityAccess({shareId:artifactShare.id})).toMatchObject({allowed:true,sourceVersionId:c.Version.id,snapshotContent:{content_snapshot:{notes:'Explicit Personal V2'}}});
 expect(await resolveSharedEntityAccess({shareId:scamperShare.id})).toMatchObject({allowed:true,sharedEntityId:c.Scamper1.id,snapshotContent:{result_text:c.Scamper1.result_text}});
 for(let n=1;n<=10;n++){
  expect(result(`(select count(*) from public.development_objects where id=${literal(c[`Idea${n}`].id)})`)).toBe(0);
  expect((await resolveSharedEntityAccess({shareId:c[`Idea${n}`].id})).allowed).toBe(false);
 }
 expect(Number(query(`select count(*) from public.shares where shared_entity_id in (${Array.from({length:7},(_,i)=>literal(c[`Idea${i+4}`].id)).join(',')})`))).toBe(0);
 for(let n=1;n<=3;n++)await expect(getScamperEntry(c[`Scamper${n}`].id)).rejects.toMatchObject({code:'NOT_FOUND'});
 await expect(listScamperEntries(c.Activity.id)).rejects.toMatchObject({code:'NOT_FOUND'});
 expect(()=>current(`select * from public.scamper_entries where workspace_id=${literal(c.Workspace.id)}`)).toThrow();
 const route=await GET(new Request(`http://localhost/api/v1/workspaces/${c.Workspace.id}`),{params:Promise.resolve({workspaceId:c.Workspace.id})});
 expect(route.status).toBe(403);expect(await route.json()).toMatchObject({ok:false,error:{code:'FORBIDDEN'}});expect(route.headers.get('cache-control')).toBe('private, no-store');
 expect((await listMyWorkspaces()).some(w=>w.id===c.Workspace.id)).toBe(false);
 await expect(getFileAccess({fileId:c.File.id})).rejects.toMatchObject({code:'NOT_FOUND'});expect(fetchSpy).not.toHaveBeenCalled();
 expect(result(`(select count(*) from public.file_links where file_id=${literal(c.File.id)})`)).toBe(0);
 expect(()=>current(`update public.development_objects set title='Stolen' where id=${literal(c.Idea1.id)}`)).toThrow();
 for(const user of [recipient,master,'00000000-0000-4000-8000-000000006001','00000000-0000-4000-8000-000000006003','00000000-0000-4000-8000-000000006006','00000000-0000-4000-8000-000000006008']){
  state.userId=user;
  await expect(shareEntity(make('DEVELOPMENT_OBJECT',c.Idea1.id))).rejects.toMatchObject({code:'NOT_FOUND'});
  await expect(shareScamperEntryToTeam(make('SCAMPER_ENTRY',c.Scamper1.id))).rejects.toMatchObject({code:'NOT_FOUND'});
 }
 state.userId='00000000-0000-4000-8000-000000006006';
 expect((await resolveSharedEntityAccess({shareId:shares[0].id})).allowed).toBe(false);
 const snapshot=JSON.parse(query(`select to_jsonb(ss)::text from public.share_snapshots ss where share_id=${literal(scamperShare.id)}`));
 expect((await resolveSharedEntityAccess({shareId:snapshot.id})).allowed).toBe(false);
 state.userId=owner;
 await expect(shareEntity({...make('DEVELOPMENT_OBJECT',c.Idea4.id),destinationId:c.TeamB.teamId})).rejects.toMatchObject({code:'NOT_FOUND'});
 await expect(shareScamperEntryToTeam(make('SCAMPER_ENTRY','ffffffff-ffff-4fff-8fff-ffffffffffff'))).rejects.toMatchObject({code:'NOT_FOUND'});
 expect(snapshot.snapshot_data.provenance).toMatchObject({source_entity_id:c.Scamper1.id,source_workspace_id:c.Workspace.id,source_created_by:owner,source_owner_user_id:owner,share_id:scamperShare.id});
 expect(query(`select jsonb_build_object('objects',(select jsonb_agg(to_jsonb(x) order by id) from public.development_objects x where workspace_id=${literal(c.Workspace.id)}),'scamper',(select jsonb_agg(to_jsonb(x) order by id) from public.scamper_entries x where workspace_id=${literal(c.Workspace.id)}),'workspace',(select to_jsonb(x) from public.workspaces x where id=${literal(c.Workspace.id)}),'file',(select to_jsonb(x) from public.files x where id=${literal(c.File.id)}))::text`)).toBe(sourceBefore);
 expect(Number(query(`select count(*) from public.share_snapshots where share_id in(select id from public.shares where source_workspace_id=${literal(c.Workspace.id)})`))).toBe(5);
 expect(Number(query(`select count(*) from public.audit_events where event_type='SHARE_CREATED' and actor_user_id=${literal(owner)} and entity_id in(select id from public.shares where source_workspace_id=${literal(c.Workspace.id)})`))).toBe(5);
 // Trusted history setup only; there is deliberately no new revoke service.
 query(`begin;select set_config('request.jwt.claim.sub',${literal(owner)},true);update public.shares set revoked_at=clock_timestamp(),revoked_by=${literal(owner)} where id=${literal(scamperShare.id)};commit;`);
 state.userId=recipient;expect((await resolveSharedEntityAccess({shareId:scamperShare.id})).allowed).toBe(false);
 state.userId=owner;expect(await getScamperEntry(c.Scamper1.id)).toEqual(c.Scamper1);
 state.userId=master;current(`select public.remove_team_member(${literal(c.TeamA.teamId)},${literal(owner)},'M13.6 source destination-membership removal')`);
 state.userId=owner;
 await expect(shareEntity(make('DEVELOPMENT_OBJECT',c.Idea4.id))).rejects.toMatchObject({code:'NOT_FOUND'});
 await expect(shareScamperEntryToTeam(make('SCAMPER_ENTRY',c.Scamper2.id))).rejects.toMatchObject({code:'NOT_FOUND'});
 expect((await listScamperEntries(c.Activity.id)).map(e=>e.id)).toEqual(expect.arrayContaining([c.Scamper1.id,c.Scamper2.id,c.Scamper3.id]));
 expect((await GET(new Request(`http://localhost/api/v1/workspaces/${c.Workspace.id}`),{params:Promise.resolve({workspaceId:c.Workspace.id})})).status).toBe(200);
 state.userId=master;current(`select public.remove_team_member(${literal(c.TeamA.teamId)},${literal(recipient)},'M13.6 recipient membership removal')`);
 state.userId=recipient;for(const share of [...shares,artifactShare])expect((await resolveSharedEntityAccess({shareId:share.id})).allowed).toBe(false);
 expect(JSON.parse(query(`select to_jsonb(ss)::text from public.share_snapshots ss where share_id=${literal(scamperShare.id)}`))).toEqual(snapshot);
 expect(query(`select revoked_at is null from public.shares where id=${literal(shares[0].id)}`)).toBe('t');
 expect(Number(query(`select count(*) from public.shares where source_workspace_id=${literal(c.Workspace.id)}`))).toBe(5);
 expect(Number(query(`select count(*) from public.audit_events where event_type='SHARE_CREATED' and entity_id=${literal(scamperShare.id)}`))).toBe(1);
 fetchSpy.mockRestore();
},120000);

it('M13.21 AT-PW-004 exposes exactly three of ten canonical Personal entities without source collection authority',async()=>{
 const c=JSON.parse(query('select jsonb_object_agg(label,payload)::text from public.personal_share_context'));
 // A2's otherwise empty canonical Personal Workspace is separate from the mixed M13.6/M13.18 fixtures.
 const a1=recipient,a2=owner;
 state.userId=master;
 for(const user of [a1,a2])current(`select public.add_team_member(${literal(c.TeamA.teamId)},${literal(user)},'member')`);
 state.userId=a1;
 const w=result('public.create_personal_workspace()');
 expect(w).toMatchObject({owner_user_id:a1,workspace_type:'PERSONAL'});
 expect(query(`select count(*) from public.development_objects where workspace_id=${literal(w.id)}`)).toBe('0');
 const p=result(`public.create_development_project('AT-PW-004 exactly ten','individual',${literal(w.id)})`);
 const entities=Array.from({length:10},(_,i)=>result(`public.create_development_object(${literal(p.id)},${literal(w.id)},'IDEA','Selected acceptance ${i+1}','Private idea ${i+1}','User')`));
 expect(p).toMatchObject({owner_user_id:a1,primary_workspace_id:w.id});
 for(const entity of entities)expect(entity).toMatchObject({created_by:a1,workspace_id:w.id,project_id:p.id});
 const edge=result(`public.relate_development_objects(${literal(entities[0].id)},${literal(entities[3].id)},'CONNECTED_TO','Private selected-to-unselected reference')`);
 const otherCount=query(`select (select count(*) from public.artifacts where workspace_id=${literal(w.id)})+(select count(*) from public.scamper_entries where workspace_id=${literal(w.id)})+(select count(*) from public.files where workspace_id=${literal(w.id)})+(select count(*) from public.evidence where workspace_id=${literal(w.id)})+(select count(*) from public.patent_records where workspace_id=${literal(w.id)})`);
 expect(otherCount).toBe('0');
 expect(query(`select count(*) from public.development_objects where workspace_id=${literal(w.id)}`)).toBe('10');
 const sourceState=()=>query(`select jsonb_build_object('workspace',(select to_jsonb(w) from public.workspaces w where id=${literal(w.id)}),'project',(select to_jsonb(p) from public.development_projects p where id=${literal(p.id)}),'objects',(select jsonb_agg(to_jsonb(o) order by id) from public.development_objects o where workspace_id=${literal(w.id)}),'relationships',(select jsonb_agg(to_jsonb(r) order by id) from public.development_object_relationships r where project_id=${literal(p.id)}))::text`);
 const before=sourceState();
 const totalObjects=query('select count(*) from public.development_objects');
 const selected:Share[]=[];
 for(const [i,e] of entities.slice(0,3).entries())selected.push(await shareEntity({entityType:'DEVELOPMENT_OBJECT',entityId:e.id,destinationType:'TEAM',destinationId:c.TeamA.teamId,permissionLevel:i===1?'COMMENT':'VIEW',shareMode:'SNAPSHOT'}));
 expect(query(`select count(*) from public.shares where source_workspace_id=${literal(w.id)}`)).toBe('3');
 for(const [i,s] of selected.entries()){
  expect(s).toMatchObject({shared_by:a1,source_workspace_id:w.id,shared_entity_id:entities[i].id,destination_id:c.TeamA.teamId,share_mode:'SNAPSHOT'});
  const snap=JSON.parse(query(`select to_jsonb(s)::text from public.share_snapshots s where share_id=${literal(s.id)}`));
  expect(snap.source_version_id).toBeNull();
  expect(snap.snapshot_data.provenance).toMatchObject({share_id:s.id,source_entity_id:entities[i].id,source_workspace_id:w.id,source_created_by:a1,source_owner_user_id:a1});
  expect(query(`select count(*) from public.audit_events where event_type='SHARE_CREATED' and entity_id=${literal(s.id)} and actor_user_id=${literal(a1)} and metadata='{}'::jsonb`)).toBe('1');
 }
 const history=()=>query(`select jsonb_agg(to_jsonb(s) order by id)::text from public.share_snapshots s where share_id in(${selected.map(s=>literal(s.id)).join(',')})`);
 const snapshots=history();
 state.userId=a2;
 let accessible=0,denied=0;
 for(let i=0;i<10;i++){
  expect(result(`(select count(*) from public.development_objects where id=${literal(entities[i].id)})`)).toBe(0);
  const access=await resolveSharedEntityAccess({shareId:i<3?selected[i].id:entities[i].id});
  if(i<3){expect(access).toMatchObject({allowed:true,sharedEntityId:entities[i].id,canView:true,canComment:i===1,canEdit:false,canReshare:false});accessible++;}
  else{expect(access.allowed).toBe(false);denied++;}
 }
 expect({accessible,denied}).toEqual({accessible:3,denied:7});
 expect(query(`select count(*) from public.shares where shared_entity_id in(${entities.slice(3).map(e=>literal(e.id)).join(',')})`)).toBe('0');
 for(const sql of [
  `select id from public.development_objects where workspace_id=${literal(w.id)} order by id limit 10 offset 0`,
  `select id from public.development_objects where project_id=${literal(p.id)} and title ilike '%acceptance%' order by id limit 2 offset 1`,
  `select id from public.development_object_relationships where id=${literal(edge.id)}`,
  `select o.id from public.development_objects o join public.development_object_relationships r on r.target_object_id=o.id where r.source_object_id=${literal(entities[0].id)}`,
  ...['artifacts','files','evidence','scamper_entries','activity_instances'].map(t=>`select id from public.${t} where workspace_id=${literal(w.id)}`),
 ]){
  try{expect(result(`(select count(*) from (${sql}) denied_collection)`)).toBe(0);}catch(error){if(!(error instanceof Error)||error.message!=='Disposable SQL denied')throw error;}
 }
 expect((await GET(new Request(`http://localhost/api/v1/workspaces/${w.id}`),{params:Promise.resolve({workspaceId:w.id})})).status).toBe(403);
 expect((await listMyWorkspaces()).some(x=>x.id===w.id)).toBe(false);
 for(const sql of [
  `update public.development_objects set title='Stolen' where id=${literal(entities[0].id)}`,
  `update public.shares set destination_id=${literal(c.TeamB.teamId)} where id=${literal(selected[0].id)}`,
  `update public.shares set permission_level='COLLABORATE' where id=${literal(selected[1].id)}`,
  `update public.workspaces set owner_user_id=${literal(a2)} where id=${literal(w.id)}`,
 ])expect(()=>current(sql)).toThrow();
 expect(sourceState()).toBe(before);
 state.userId='00000000-0000-4000-8000-000000006006';
 for(const s of selected)expect((await resolveSharedEntityAccess({shareId:s.id})).allowed).toBe(false);
 state.userId=a1;await revokeShare(selected[0].id);
 state.userId=a2;expect((await resolveSharedEntityAccess({shareId:selected[0].id})).allowed).toBe(false);
 expect(()=>current(`update public.shares set revoked_at=null,revoked_by=null where id=${literal(selected[0].id)}`)).toThrow();
 state.userId=master;current(`select public.remove_team_member(${literal(c.TeamA.teamId)},${literal(a2)},'M13.21 recipient removal')`);
 state.userId=a2;for(const s of selected)expect((await resolveSharedEntityAccess({shareId:s.id})).allowed).toBe(false);
 expect(history()).toBe(snapshots);expect(sourceState()).toBe(before);
 expect(query('select count(*) from public.development_objects')).toBe(totalObjects);
 expect(query(`select count(*) from public.shares where source_workspace_id=${literal(w.id)}`)).toBe('3');
 // Restore the two removed memberships expected by the following M13.18 fixture.
 state.userId=master;current(`select public.remove_team_member(${literal(c.TeamA.teamId)},${literal(a1)},'M13.21 restore fixture membership boundary')`);
 state.userId=a1;expect(result(`(select count(*) from public.development_objects where workspace_id=${literal(w.id)})`)).toBe(10);
},120000);

it('M13.18 selected SCAMPER snapshots preserve Personal ownership through comments, edits, revocation and membership loss',async()=>{
 const c=JSON.parse(query('select jsonb_object_agg(label,payload)::text from public.personal_share_context'));
 // Restore canonical memberships removed by the preceding acceptance scenario.
 state.userId=master;
 for(const user of [owner,recipient])current(`select public.add_team_member(${literal(c.TeamA.teamId)},${literal(user)},'member')`);
 // The canonical base fixture includes an explicit Team Mentor membership.
 // Remove that independent grant before testing role-only Mentor denial.
 current(`select public.remove_team_member(${literal(c.TeamA.teamId)},'00000000-0000-4000-8000-000000006008','M13.18 role-only Mentor fixture')`);
 state.userId=owner;
 const entries=await listScamperEntries(c.Activity.id);expect(entries).toHaveLength(10);
 const entryCount=query('select count(*) from public.scamper_entries');
 const request=(entryId:string,permissionLevel='VIEW')=>({entityType:'SCAMPER_ENTRY',entityId:entryId,destinationType:'TEAM',destinationId:c.TeamA.teamId,permissionLevel,shareMode:'SNAPSHOT'});
 const selected:Share[]=[];
 for(let n=1;n<=3;n++)selected.push(await shareScamperEntryToTeam(request(c[`Scamper${n}`].id,n===2?'COMMENT':'VIEW')));
 expect(Number(query(`select count(*) from public.shares where shared_entity_type='SCAMPER_ENTRY' and source_workspace_id=${literal(c.Workspace.id)} and revoked_at is null`))).toBe(3);
 expect(Number(query(`select count(*) from public.shares where shared_entity_id in(${Array.from({length:7},(_,i)=>literal(c[`Scamper${i+4}`].id)).join(',')})`))).toBe(0);
 for(const share of selected){
  const snap=JSON.parse(query(`select to_jsonb(s)::text from public.share_snapshots s where share_id=${literal(share.id)}`));
  expect(snap.source_version_id).toBeNull();
  expect(snap.snapshot_data.provenance).toMatchObject({source_entity_id:share.shared_entity_id,source_workspace_id:c.Workspace.id,source_owner_user_id:owner,source_created_by:owner,share_id:share.id});
  expect(query(`select count(*) from public.audit_events where event_type='SHARE_CREATED' and entity_id=${literal(share.id)} and actor_user_id=${literal(owner)} and metadata='{}'::jsonb`)).toBe('1');
 }
 state.userId=recipient;
 for(const share of selected)expect(await resolveSharedEntityAccess({shareId:share.id})).toMatchObject({allowed:true,sharedEntityId:share.shared_entity_id,canEdit:false,canReshare:false});
 const frozen=await resolveSharedEntityAccess({shareId:selected[0].id});
 expect(frozen).toMatchObject({allowed:true,canView:true,canComment:false,canEdit:false,canReshare:false,sharedEntityId:c.Scamper1.id,snapshotContent:{result_text:c.Scamper1.result_text}});
 expect(await resolveSharedEntityAccess({shareId:selected[1].id})).toMatchObject({allowed:true,canComment:true,canEdit:false,canReshare:false});
 const comment=await addSharedComment({shareId:selected[1].id,content:'Selected frozen SCAMPER discussion'});
 expect(comment).toMatchObject({target_entity_type:'SCAMPER_ENTRY',target_entity_id:c.Scamper2.id,target_version_id:null,author_user_id:recipient});
 await expect(addSharedComment({shareId:selected[0].id,content:'VIEW forbidden'})).rejects.toMatchObject({code:'FORBIDDEN'});
 for(let n=1;n<=10;n++)await expect(getScamperEntry(c[`Scamper${n}`].id)).rejects.toMatchObject({code:'NOT_FOUND'});
 await expect(listScamperEntries(c.Activity.id)).rejects.toMatchObject({code:'NOT_FOUND'});
 for(const guessed of [c.Scamper1.id,c.Scamper10.id,'ffffffff-ffff-4fff-8fff-ffffffffffff'])expect((await resolveSharedEntityAccess({shareId:guessed})).allowed).toBe(false);
 for(const user of ['00000000-0000-4000-8000-000000006006',master,'00000000-0000-4000-8000-000000006001','00000000-0000-4000-8000-000000006003','00000000-0000-4000-8000-000000006008']){
  expect(query(`select count(*) from public.team_memberships where team_id=${literal(c.TeamA.teamId)} and user_id=${literal(user)} and status='active'`)).toBe('0');
  state.userId=user;expect((await resolveSharedEntityAccess({shareId:selected[0].id})).allowed,`No destination membership for ${user}`).toBe(false);
  await expect(shareScamperEntryToTeam(request(c.Scamper1.id))).rejects.toMatchObject({code:'NOT_FOUND'});
 }
 state.userId=owner;
 const changed=await updateScamperEntry({entryId:c.Scamper1.id,resultText:'Later Personal-only source edit'});
 expect(changed.result_text).toBe('Later Personal-only source edit');
 const sourceState=()=>query(`select jsonb_build_object('entries',(select jsonb_agg(to_jsonb(e) order by id) from public.scamper_entries e where workspace_id=${literal(c.Workspace.id)}),'workspace',(select to_jsonb(w) from public.workspaces w where id=${literal(c.Workspace.id)}))::text`);
 const before=sourceState();
 state.userId=recipient;
 expect(await resolveSharedEntityAccess({shareId:selected[0].id})).toEqual(frozen);
 await expect(updateScamperEntry({entryId:c.Scamper1.id,resultText:'Recipient overwrite'})).rejects.toMatchObject({code:'NOT_FOUND'});
 await expect(shareScamperEntryToTeam(request(c.Scamper1.id))).rejects.toMatchObject({code:'NOT_FOUND'});
 await expect(revokeShare(selected[0].id)).rejects.toMatchObject({code:'NOT_FOUND'});
 await expect(listEntityShares({entityType:'SCAMPER_ENTRY',entityId:c.Scamper1.id})).rejects.toMatchObject({code:'NOT_FOUND'});
 expect((await GET(new Request(`http://localhost/api/v1/workspaces/${c.Workspace.id}`),{params:Promise.resolve({workspaceId:c.Workspace.id})})).status).toBe(403);
 for(const table of ['artifacts','evidence','files'])expect(result(`(select count(*) from public.${table} where workspace_id=${literal(c.Workspace.id)})`)).toBe(0);
 expect((await rpcTransport('authorize_shared_file_access',{target_file:c.File.id})).data).toBe(false);
 await expect(getFileAccess({fileId:c.File.id})).rejects.toMatchObject({code:'NOT_FOUND'});
 const statements=[`select * from public.scamper_entries where workspace_id=${literal(c.Workspace.id)}`,
  `update public.scamper_entries set result_text='Stolen' where id=${literal(c.Scamper2.id)}`,
  `update public.shares set permission_level='COMMENT' where id=${literal(selected[0].id)}`,
  `update public.shares set permission_level='COLLABORATE' where id=${literal(selected[1].id)}`,
  `update public.workspaces set owner_user_id=${literal(recipient)} where id=${literal(c.Workspace.id)}`];
 for(const sql of statements)expect(()=>current(sql)).toThrow();
 expect(sourceState()).toBe(before);
 state.userId=owner;
 const snapshots=query(`select jsonb_agg(to_jsonb(s) order by id)::text from public.share_snapshots s where share_id in(${selected.map(s=>literal(s.id)).join(',')})`);
 for(const share of selected)await revokeShare(share.id);
 expect(query(`select jsonb_agg(to_jsonb(s) order by id)::text from public.share_snapshots s where share_id in(${selected.map(s=>literal(s.id)).join(',')})`)).toBe(snapshots);
 expect(await listSharedComments({shareId:selected[1].id})).toEqual([comment]);
 expect(await listEntityShares({entityType:'SCAMPER_ENTRY',entityId:c.Scamper1.id})).toEqual(expect.arrayContaining([expect.objectContaining({shareId:selected[0].id,state:'REVOKED'})]));
 state.userId=recipient;
 for(const share of selected){expect((await resolveSharedEntityAccess({shareId:share.id})).allowed).toBe(false);await expect(addSharedComment({shareId:share.id,content:'Revoked'})).rejects.toMatchObject({code:'FORBIDDEN'});}
 expect(()=>current(`update public.shares set revoked_at=null,revoked_by=null where id=${literal(selected[0].id)}`)).toThrow();
 state.userId=owner;const currentShare=await shareScamperEntryToTeam(request(c.Scamper3.id));
 state.userId=master;current(`select public.remove_team_member(${literal(c.TeamA.teamId)},${literal(recipient)},'M13.18 recipient removal')`);
 state.userId=recipient;expect((await resolveSharedEntityAccess({shareId:currentShare.id})).allowed).toBe(false);
 expect(sourceState()).toBe(before);
 expect(query(`select revoked_at is null from public.shares where id=${literal(currentShare.id)}`)).toBe('t');
 expect(query(`select count(*) from public.scamper_entries where workspace_id=${literal(c.Workspace.id)}`)).toBe('10');
 expect(query('select count(*) from public.scamper_entries')).toBe(entryCount);
},120000);
