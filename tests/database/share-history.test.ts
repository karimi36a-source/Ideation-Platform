import {spawnSync} from 'node:child_process';
import {join} from 'node:path';
import {expect,it,vi} from 'vitest';
vi.mock('server-only',()=>({}));
const state=vi.hoisted(()=>({userId:'00000000-0000-4000-8000-000000006004'}));
vi.mock('@/lib/auth/authorization',async original=>({...await original<typeof import('@/lib/auth/authorization')>(),getAuthorizationContext:async()=>({userId:state.userId,assignments:[]})}));
vi.mock('@/lib/db/server',()=>({createServerSupabaseClient:async()=>({rpc})}));
import {copySharedSnapshotToWorkspace} from '@/features/shares/copy';
import {listEntityShares} from '@/features/shares/history';
import {shareEntity} from '@/features/shares/create';
import {revokeShare} from '@/features/shares/revoke';
import {resolveSharedEntityAccess} from '@/features/shares/access';
import {shareHistoryRecordSchema} from '@/features/shares/history-schema';
const actor=(n:number)=>'00000000-0000-4000-8000-'+String(n).padStart(12,'0');
const literal=(s:string)=>"'"+s.replaceAll("'","''")+"'";
function query(sql:string){const port=process.env.FICI_HISTORY_TEST_PORT,bin=process.env.POSTGRES_BIN;if(!port||!/^\d+$/.test(port)||!bin)throw Error('Disposable history context required');
 const r=spawnSync(join(bin,process.platform==='win32'?'psql.exe':'psql'),['-X','-h','127.0.0.1','-p',port,'-U','postgres','-d','fici_share_history','-v','ON_ERROR_STOP=1','-t','-A','-f','-'],{input:'\\set VERBOSITY verbose\n'+sql,encoding:'utf8',windowsHide:true,timeout:45000});
 if(r.error||r.status!==0)throw Object.assign(Error('Disposable history SQL denied'),{sqlstate:r.stderr.match(/ERROR:\s+([A-Z0-9]{5}):/)?.[1]??'UNKNOWN',diagnostic:r.stderr});return r.stdout.trim();}
function current(sql:string){return query("begin;set local role authenticated;select set_config('request.jwt.claim.sub',"+literal(state.userId)+',true);'+sql+';commit;');}
async function rpc(name:string,args:Record<string,unknown>){if(!['list_entity_shares','share_entity','revoke_share','resolve_shared_entity_access'].includes(name))throw Error('Unexpected RPC');
 try{const sql='public.'+name+'('+Object.entries(args).map(([k,v])=>k+'=>'+literal(JSON.stringify(v))+'::jsonb').join(',')+')';const line=current("select 'RESULT='||("+sql+')::text').split(/\r?\n/).find(s=>s.startsWith('RESULT='));if(!line)throw Error('Missing result');return {data:JSON.parse(line.slice(7)),error:null};}
 catch(e){return {data:null,error:{code:(e as {sqlstate?:string}).sqlstate??'UNKNOWN'}};}}
it('M13.13 exact-source current authority, immutable active/revoked/re-share history, safe destinations and no recipient enumeration',async()=>{
 const c=JSON.parse(query('select jsonb_object_agg(label,payload)::text from public.revoke_test_context'));
 const id=(label:string)=>c[label].id;
 const input={entityType:'ARTIFACT',entityId:id('MainArtifact')};
 const personal={entityType:'PATENT_RECORD',entityId:c.PersonalShare.shared_entity_id};
 const tables=['shares','share_snapshots','share_comments','audit_events','notifications','artifacts','artifact_versions','development_objects','files','evidence','patent_records','scamper_entries','workspaces','teams','team_memberships','role_assignments','artifact_object_links','file_links','evidence_links','development_object_relationships'];
 const checksum=()=>query('select md5(jsonb_build_array('+tables.map(t=>"(select coalesce(jsonb_agg(to_jsonb(x) order by id),'[]'::jsonb) from public."+t+' x)').join(',')+')::text)');
 async function inspect(value:unknown){const before=checksum();const rows=await listEntityShares(value);expect(checksum()).toBe(before);return rows;}
 // M13.14: unsupported copy never materializes content or grants destination rights.
 async function deniedCopy(shareId:string){
  const before=checksum();
  for(const workspaceId of [c.TeamB.workspaceId,c.MainShare.source_workspace_id,actor(9999)]){
   await expect(copySharedSnapshotToWorkspace({shareId,workspaceId,sourceVersionId:id('MainVersion')})).rejects.toMatchObject({code:'SHARED_SNAPSHOT_COPY_DEFERRED'});
  }
  expect(checksum()).toBe(before);
 }
 const copyBefore=checksum();
 for(const n of [6006,6007,6002,6004]){
  state.userId=actor(n);
  for(const label of ['ViewShare','MainShare','MasterShare','PersonalShare'])await deniedCopy(id(label));
  await deniedCopy(actor(9999));
  const snapshotId=query('select id from public.share_snapshots where share_id='+literal(id('ViewShare')));
  for(const candidate of [snapshotId,id('MainArtifact'),id('MainVersion')])await deniedCopy(candidate);
  for(const name of ['copy_shared_snapshot_to_workspace','clone_shared_snapshot','import_shared_snapshot','duplicate_shared_snapshot']){
   try{current('select public.'+name+'('+literal(JSON.stringify({shareId:id('MainShare'),workspaceId:c.TeamB.workspaceId}))+'::jsonb)');throw Error('Unexpected copy RPC');}
   catch(e){expect((e as {sqlstate?:string}).sqlstate).toBe('42883');}
  }
 }
 state.userId=actor(6006);
 for(const table of ['artifacts','artifact_versions','development_objects','artifact_object_links','files','file_links','evidence_links','share_snapshots','shares','team_memberships']){
  try{current('insert into public.'+table+' default values');throw Error('Direct materialization succeeded');}
  catch(e){expect((e as {sqlstate?:string}).sqlstate).toBe('42501');}
 }
 try{current('select public.create_artifact_version('+literal(id('MainArtifact'))+"::uuid,'{}'::jsonb,'Copy bypass')");throw Error('Source Version mutation succeeded');}
 catch(e){expect((e as {sqlstate?:string}).sqlstate).toBe('42501');}
 expect(checksum()).toBe(copyBefore);
 expect((await resolveSharedEntityAccess({shareId:id('ViewShare')})).allowed).toBe(true);
 expect((await resolveSharedEntityAccess({shareId:id('MainShare')})).allowed).toBe(true);
 state.userId=actor(6004);
 const initial=await inspect(input);expect(initial).toHaveLength(3);expect(initial.every(s=>s.state==='ACTIVE')).toBe(true);
 expect(initial.find(s=>s.shareId===id('MasterShare'))?.destination).toEqual({type:'MASTER',userId:actor(6002)});
 expect(await inspect({entityType:'ARTIFACT',entityId:id('SiblingArtifact')})).toEqual([]);
 expect(await inspect(personal)).toHaveLength(1);
 for(const value of [{entityType:'FILE',entityId:id('File')},{entityType:'EVIDENCE',entityId:id('EvidenceSource')},{entityType:'DEVELOPMENT_OBJECT',entityId:id('ObjectSource')},{entityType:'SCAMPER_ENTRY',entityId:id('ScamperSource')}]){
  const rows=await inspect(value);expect(rows.every(s=>s.sourceVersionId===null)).toBe(true);rows.forEach(s=>expect(shareHistoryRecordSchema.safeParse(s).success).toBe(true));
 }
 const beforeDenial=checksum();
 state.userId='';await expect(listEntityShares(input)).rejects.toMatchObject({code:'AUTH_REQUIRED'});
 for(const n of [6001,6002,6003,6005,6006,6007,6008]){
  state.userId=actor(n);
  await expect(listEntityShares(input)).rejects.toMatchObject({code:'NOT_FOUND'});
  await expect(listEntityShares(personal)).rejects.toMatchObject({code:'NOT_FOUND'});
  await expect(listEntityShares({entityType:'ARTIFACT',entityId:id('SiblingArtifact')})).rejects.toMatchObject({code:'NOT_FOUND'});
  expect((await rpc('list_entity_shares',{input})).error?.code).toBe('42501');
 }
 state.userId=actor(6006);expect((await resolveSharedEntityAccess({shareId:id('MainShare')})).allowed).toBe(true);
 await expect(listEntityShares({entityType:'ARTIFACT',entityId:id('MainShare')})).rejects.toMatchObject({code:'NOT_FOUND'});
 for(const value of [{...input,workspaceId:c.MainShare.source_workspace_id},{...input,shareId:id('MainShare')},{...input,actorId:actor(6004)},{entityType:'WORKSPACE',entityId:c.MainShare.source_workspace_id},null,[],{}])expect((await rpc('list_entity_shares',{input:value})).error?.code).toBe('22023');
 state.userId=actor(6004);
 await expect(listEntityShares({entityType:'ARTIFACT',entityId:'ffffffff-ffff-4fff-8fff-ffffffffffff'})).rejects.toMatchObject({code:'NOT_FOUND'});
 expect(checksum()).toBe(beforeDenial);
 // Revocation and re-sharing remain distinct, with V2 and V1 exact bindings.
 await revokeShare(id('ViewShare'));
 state.userId=actor(6006);await deniedCopy(id('ViewShare'));state.userId=actor(6004);
 const v1=query('select previous_version_id from public.artifact_versions where id='+literal(id('MainVersion')));
 const reshared=await shareEntity({...input,sourceVersionId:v1,destinationType:'TEAM',destinationId:c.TeamB.teamId,permissionLevel:'VIEW',shareMode:'SNAPSHOT'});
 expect(reshared.id).not.toBe(id('ViewShare'));
 const rows=await inspect(input);expect(rows).toHaveLength(4);
 expect(rows.find(s=>s.shareId===id('ViewShare'))).toMatchObject({state:'REVOKED',sourceVersionId:id('MainVersion'),revokedBy:actor(6004)});
 expect(rows.find(s=>s.shareId===reshared.id)).toMatchObject({state:'ACTIVE',sourceVersionId:v1});
 const order=JSON.parse(query('select json_agg(id order by created_at,id)::text from public.shares where shared_entity_type=\'ARTIFACT\' and shared_entity_id='+literal(id('MainArtifact'))));
 expect(rows.map(s=>s.shareId)).toEqual(order);
 expect(await inspect(input)).toEqual(rows);
 const encoded=JSON.stringify(rows);
 for(const secret of [id('UnsharedV3'),id('SiblingArtifact'),c.File.storage_reference,c.MainShare.source_workspace_id,id('MasterAssignment'),'Exact selected V2','Private unshared V3','storage_reference','snapshot_data','members','role_id','ends_at','account_status'])expect(encoded).not.toContain(secret);
 await revokeShare(id('PersonalShare'));
 const personalReshare=await shareEntity({...personal,destinationType:'TEAM',destinationId:c.TeamA.teamId,permissionLevel:'VIEW',shareMode:'SNAPSHOT'});
 const personalRows=await inspect(personal);expect(personalRows).toHaveLength(2);expect(personalRows.map(s=>s.shareId)).toEqual([id('PersonalShare'),personalReshare.id]);expect(personalRows.map(s=>s.state)).toEqual(['REVOKED','ACTIVE']);
 // History is independent of current recipient eligibility, including MASTER expiry.
 query("begin;select set_config('request.jwt.claim.sub',"+literal(actor(6002))+",true);select public.remove_team_member("+literal(c.TeamB.teamId)+','+literal(actor(6006))+",'M13.13 former recipient');commit;");
 expect(await inspect(input)).toEqual(rows);
 state.userId=actor(6006);await deniedCopy(id('MainShare'));await expect(listEntityShares(input)).rejects.toMatchObject({code:'NOT_FOUND'});expect((await resolveSharedEntityAccess({shareId:id('MainShare')})).allowed).toBe(false);
 state.userId=actor(6004);
 const previousEnd=query("select coalesce(ends_at::text,'NULL') from public.role_assignments where id="+literal(id('MasterAssignment')));
 query("update public.role_assignments set ends_at=clock_timestamp()-interval '1 second' where id="+literal(id('MasterAssignment')));
 expect(await inspect(input)).toEqual(rows);
 state.userId=actor(6002);expect((await resolveSharedEntityAccess({shareId:id('MasterShare')})).allowed).toBe(false);await expect(listEntityShares(input)).rejects.toMatchObject({code:'NOT_FOUND'});
 query('update public.role_assignments set ends_at='+(previousEnd==='NULL'?'null':literal(previousEnd)+'::timestamptz')+' where id='+literal(id('MasterAssignment')));
 // Source creator and historical sharer lose inspection when Lead authority ends.
 query("begin;select set_config('request.jwt.claim.sub',"+literal(actor(6002))+",true);select public.remove_team_member("+literal(c.TeamA.teamId)+','+literal(actor(6004))+",'M13.13 former Lead');select public.assign_team_lead("+literal(c.TeamA.teamId)+','+literal(actor(6005))+');commit;');
 state.userId=actor(6004);await expect(listEntityShares(input)).rejects.toMatchObject({code:'NOT_FOUND'});expect(await inspect(personal)).toEqual(personalRows);
 state.userId=actor(6005);expect(await inspect(input)).toEqual(rows);
 // No source-table SELECT grant was introduced for enumeration.
 try{current('select * from public.shares');throw Error('Direct Share enumeration succeeded');}catch(e){expect((e as {sqlstate?:string}).sqlstate).toBe('42501');}
 for(const role of ['anon','service_role'])expect(query('select has_function_privilege('+literal(role)+",'public.list_entity_shares(jsonb)','EXECUTE')")).toBe('f');
 expect(query("select prosecdef and provolatile='s' and proconfig=array['search_path=\"\"'] from pg_proc where oid='public.list_entity_shares(jsonb)'::regprocedure")).toBe('t');
},180000);
