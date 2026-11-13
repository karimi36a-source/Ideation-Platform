import {spawn,spawnSync} from 'node:child_process';
import {join} from 'node:path';
import {expect,it,vi} from 'vitest';
vi.mock('server-only',()=>({}));
const state=vi.hoisted(()=>({userId:'00000000-0000-4000-8000-000000006004'}));
vi.mock('@/lib/auth/authorization',async original=>({...await original<typeof import('@/lib/auth/authorization')>(),getAuthorizationContext:async()=>({userId:state.userId,assignments:[]})}));
vi.mock('@/lib/db/server',()=>({createServerSupabaseClient:async()=>({rpc,from:table})}));
import {revokeShare} from '@/features/shares/revoke';
import {shareEntity} from '@/features/shares/create';
import {copySharedSnapshotToWorkspace} from '@/features/shares/copy';
import {resolveSharedEntityAccess} from '@/features/shares/access';
import {deniedSharedEntityAccess} from '@/features/shares/access-schema';
import {addSharedComment,listSharedComments} from '@/features/shares/comments';
import {getFileAccess} from '@/features/files/access';
import {GET} from '@/app/api/v1/workspaces/[workspaceId]/route';
const actor=(n:number)=>'00000000-0000-4000-8000-'+String(n).padStart(12,'0');
const literal=(s:string)=>"'"+s.replaceAll("'","''")+"'";
function connection(){
 const port=process.env.FICI_REVOKE_TEST_PORT,bin=process.env.POSTGRES_BIN;
 if(!port||!/^\d+$/.test(port)||!bin)throw Error('Disposable revoke context required');
 return {exe:join(bin,process.platform==='win32'?'psql.exe':'psql'),args:['-X','-h','127.0.0.1','-p',port,'-U','postgres','-d','fici_share_revoke','-v','ON_ERROR_STOP=1','-t','-A','-f','-']};
}
function query(sql:string){const c=connection();const r=spawnSync(c.exe,c.args,{input:'\\set VERBOSITY verbose\n'+sql,encoding:'utf8',windowsHide:true,timeout:45000});if(r.error||r.status!==0)throw Object.assign(Error('Disposable SQL denied'),{sqlstate:r.stderr.match(/ERROR:\s+([A-Z0-9]{5}):/)?.[1]??'UNKNOWN',diagnostic:r.stderr});return r.stdout.trim();}
const current=(sql:string)=>query('begin;set local role authenticated;select set_config(\'request.jwt.claim.sub\','+literal(state.userId)+',true);'+sql+';commit;');
function result(sql:string){const line=current("select 'RESULT='||("+sql+')::text').split(/\r?\n/).find(s=>s.startsWith('RESULT='));if(!line)throw Error('Missing result');return JSON.parse(line.slice(7));}
async function rpc(name:string,args:Record<string,unknown>){
 if(!['share_entity','revoke_share','resolve_shared_entity_access','add_share_comment','list_share_comments'].includes(name))throw Error('Unexpected RPC');
 try{return {data:result('public.'+name+'('+Object.entries(args).map(([k,v])=>k+'=>'+literal(JSON.stringify(v))+'::jsonb').join(',')+')'),error:null};}
 catch(e){return {data:null,error:{code:(e as {sqlstate?:string}).sqlstate??'UNKNOWN'}};}
}
function table(name:string){
 if(name!=='files')throw Error('Unexpected source traversal');
 return {select:()=>({eq:(key:string,id:string)=>{if(key!=='id')throw Error('Unexpected filter');return {maybeSingle:async()=>({data:result('(select to_jsonb(f) from public.files f where id='+literal(id)+')'),error:null})};}})};
}
function session(label:string,shareId:string,hold:boolean,mode:'revoke'|'comment'='revoke'){
 const c=connection();const child=spawn(c.exe,c.args,{windowsHide:true});
 let out='',err='',signalReady:()=>void=()=>{};const ready=new Promise<void>(resolve=>{signalReady=resolve;});
 const done=new Promise<string>((resolve,reject)=>{const timer=setTimeout(()=>{child.kill();reject(Error('Revoke concurrency timeout'));},45000);child.stdout.on('data',d=>{out+=d;if(out.includes('READY'))signalReady();});child.stderr.on('data',d=>{err+=d;});child.on('error',reject);child.on('exit',code=>{clearTimeout(timer);if(code===0)resolve(out);else reject(Object.assign(Error('Concurrent transaction failed'),{diagnostic:err}));});});done.catch(()=>{});
 const body=mode==='comment'?"do $$begin perform public.add_share_comment(jsonb_build_object('shareId',"+literal(shareId)+",'content','Concurrent future comment'));raise exception 'Comment bypass';exception when insufficient_privilege then null;end$$":"select 'REVOKED='||public.revoke_share(jsonb_build_object('shareId',"+literal(shareId)+'))::text';
 child.stdin.write("begin;set local application_name="+literal(label)+";set local role authenticated;select set_config('request.jwt.claim.sub',"+literal(mode==='comment'?actor(6006):actor(6004))+",true);"+body+";select 'READY';\n");
 if(!hold)child.stdin.end('commit;\n');
 return {ready,done,finish:(terminal:string)=>child.stdin.end(terminal+';\n'),stop:()=>{if(child.exitCode===null)child.kill();}};
}
async function waitBlocked(label:string){for(let n=0;n<100;n++){if(query('select count(*) from pg_stat_activity where application_name='+literal(label)+" and wait_event_type='Lock'")==='1')return;await new Promise(resolve=>setTimeout(resolve,20));}throw Error('Competing transaction did not serialize');}

it('AT-AUD-003 / AT-SHARE-005 lifecycle audit hooks, current authority, history, retries, rollback and concurrency',async()=>{
 const c=JSON.parse(query('select jsonb_object_agg(label,payload)::text from public.revoke_test_context'));
 const id=(label:string)=>c[label].id;
 const sourceTables=['artifacts','artifact_versions','artifact_object_links','development_objects','files','file_links','evidence_links','workspaces','team_memberships','share_snapshots','share_comments'];
 const history=()=>query('select jsonb_build_array('+sourceTables.map(t=>"(select coalesce(jsonb_agg(to_jsonb(x) order by id),'[]'::jsonb) from public."+t+' x)').join(',')+')::text');
 const all=()=>query("select jsonb_build_array((select jsonb_agg(to_jsonb(s) order by id) from public.shares s),(select jsonb_agg(to_jsonb(a) order by id) from public.audit_events a),(select coalesce(jsonb_agg(to_jsonb(n) order by id),'[]') from public.notifications n))::text");
 const original=history(),beforeDenial=all();
 // AT-AUD-003: the durable audit/M15 signal references retained, exact provenance.
 const created=JSON.parse(query("select to_jsonb(a)::text from public.audit_events a where event_type='SHARE_CREATED' and entity_id="+literal(id('MainShare'))));
 expect(created).toMatchObject({actor_user_id:actor(6004),entity_type:'share',entity_id:id('MainShare'),scope_type:'share',scope_id:id('MainShare'),share_target_id:id('MainShare'),metadata:{}});
 expect(query("select count(*) from public.audit_events where event_type='SHARE_CREATED' and entity_id="+literal(id('MainShare')))).toBe('1');
 expect(query("select a.actor_user_id=s.shared_by and a.created_at>=s.created_at and a.created_at<=clock_timestamp() and s.source_workspace_id="+literal(c.Project.primary_workspace_id)+"::uuid and s.destination_type='TEAM' and s.destination_id="+literal(c.TeamB.teamId)+"::uuid and s.permission_level='COMMENT' and s.share_mode='SNAPSHOT' and ss.source_version_id="+literal(id('MainVersion'))+"::uuid from public.audit_events a join public.shares s on s.id=a.entity_id join public.share_snapshots ss on ss.share_id=s.id where a.event_type='SHARE_CREATED' and s.id="+literal(id('MainShare')))).toBe('t');
 for(const n of [6004,6006,6001]){
  state.userId=actor(n);
  await expect(copySharedSnapshotToWorkspace({shareId:id('MainShare')})).rejects.toMatchObject({code:'SHARED_SNAPSHOT_COPY_DEFERRED'});
 }
 expect(all()).toBe(beforeDenial);expect(history()).toBe(original);
 // Neither lifecycle signals nor the existing notification foundation are writable.
 state.userId=actor(6006);
 for(const sql of [
  'select * from public.audit_events where entity_id='+literal(id('MainShare')),
  'insert into public.notifications default values',
  "update public.audit_events set created_at=clock_timestamp() where entity_id="+literal(id('MainShare')),
 ]){try{current(sql);throw Error('Audit/notification boundary bypass');}catch(e){expect((e as {sqlstate?:string}).sqlstate).toBe('42501');}}
 expect(all()).toBe(beforeDenial);
 state.userId='';
 await expect(revokeShare(id('MainShare'))).rejects.toMatchObject({code:'AUTH_REQUIRED'});
 for(const n of [6001,6002,6003,6005,6006,6007,6008]){
  state.userId=actor(n);
  await expect(revokeShare(id('MainShare'))).rejects.toMatchObject({code:'NOT_FOUND'});
  expect((await rpc('revoke_share',{input:{shareId:id('MainShare')}})).error?.code).toBe('42501');
  await expect(revokeShare(id('PersonalShare'))).rejects.toMatchObject({code:'NOT_FOUND'});
 }
 state.userId=actor(6004);
 for(const guessed of [id('MainArtifact'),id('MainVersion'),'ffffffff-ffff-4fff-8fff-ffffffffffff'])await expect(revokeShare(guessed)).rejects.toMatchObject({code:'NOT_FOUND'});
 for(const field of ['actorId','revokedBy','revokedAt','force','sourceWorkspaceId'])expect((await rpc('revoke_share',{input:{shareId:id('MainShare'),[field]:actor(6004)}})).error?.code).toBe('22023');
 for(const input of [null,[],{},'invalid',{shareId:'bad'}])expect((await rpc('revoke_share',{input})).error?.code).toBe('22023');
 expect(all()).toBe(beforeDenial);expect(history()).toBe(original);
 // A failure of the required durable audit/M15 hook rolls the transition back.
 query("create function public.revoke_test_fail() returns trigger language plpgsql as $$begin if new.event_type='SHARE_REVOKED' then raise exception 'Injected durable hook failure' using errcode='23514';end if;return new;end$$;create trigger revoke_test_fail before insert on public.audit_events for each row execute function public.revoke_test_fail();");
 try{await expect(revokeShare(id('RollbackShare'))).rejects.toMatchObject({code:'NOT_FOUND'});expect(all()).toBe(beforeDenial);expect(history()).toBe(original);}
 finally{query('drop trigger revoke_test_fail on public.audit_events;drop function public.revoke_test_fail();');}
 // Two real transactions hold/compete on the same Share. Retry sees the first
 // committed result; rolling it back lets the second make the sole transition.
 for(const [label,terminal] of [['RaceShare','commit'],['RollbackShare','rollback']]){
  const first=session('revoke_first',id(label),true);let second:ReturnType<typeof session>|undefined;
  try{
   await Promise.race([first.ready,first.done.then(()=>{throw Error('Missing readiness');})]);
   second=session('revoke_second',id(label),false);await waitBlocked('revoke_second');
   first.finish(terminal);const [a,b]=await Promise.all([first.done,second.done]);
   const row=(s:string)=>JSON.parse(s.split(/\r?\n/).find(line=>line.startsWith('REVOKED='))!.slice(8));
   if(terminal==='commit')expect(row(b)).toEqual(row(a));
   expect(query("select count(*) from public.audit_events where event_type='SHARE_REVOKED' and entity_id="+literal(id(label)))).toBe('1');
  }finally{first.stop();second?.stop();}
 }
 // A comment already in flight must recheck after waiting for revocation.
 const revoking=session('revoke_comment_first',id('CommentRaceShare'),true);let commenting:ReturnType<typeof session>|undefined;
 try{await Promise.race([revoking.ready,revoking.done.then(()=>{throw Error('Missing readiness');})]);commenting=session('comment_after_revoke',id('CommentRaceShare'),false,'comment');await waitBlocked('comment_after_revoke');revoking.finish('commit');await Promise.all([revoking.done,commenting.done]);}
 finally{revoking.stop();commenting?.stop();}
 expect(query('select count(*) from public.share_comments where share_id='+literal(id('CommentRaceShare')))).toBe('0');
 // Main acceptance: exact Snapshot is visible before revoke, then denied.
 state.userId=actor(6006);
 expect(await resolveSharedEntityAccess({shareId:id('MainShare')})).toMatchObject({allowed:true,canView:true,canComment:true,canEdit:false,sourceVersionId:id('MainVersion')});
 expect(await listSharedComments({shareId:id('MainShare')})).toEqual([c.Comment]);
 state.userId=actor(6004);
 const revoked=await revokeShare(id('MainShare'));expect(revoked.revoked_by).toBe(actor(6004));expect(revoked.revoked_at).not.toBeNull();
 expect(await revokeShare(id('MainShare'))).toEqual(revoked);
 const revokedView=await revokeShare(id('ViewShare'));
 await revokeShare(id('FileShare'));await revokeShare(id('PersonalShare'));
 expect(history()).toBe(original);
 const audit=JSON.parse(query("select to_jsonb(a)::text from public.audit_events a where event_type='SHARE_REVOKED' and entity_id="+literal(id('MainShare'))));
 expect(audit).toMatchObject({actor_user_id:actor(6004),entity_type:'share',entity_id:revoked.id,scope_type:'share',scope_id:revoked.id,share_target_id:revoked.id,metadata:{}});
 expect(Date.parse(audit.created_at)).toBe(Date.parse(revoked.revoked_at!));
 expect(query("select a.created_at=s.revoked_at and a.actor_user_id=s.revoked_by from public.audit_events a join public.shares s on s.id=a.entity_id where a.event_type='SHARE_REVOKED' and s.id="+literal(revoked.id))).toBe('t');
 expect(query("select count(*) from public.audit_events where entity_id="+literal(revoked.id)+" and event_type in ('SHARE_CREATED','SHARE_REVOKED')")).toBe('2');
 for(const code of ['SHARE_CREATED','SHARE_REVOKED']){
  try{query("update public.audit_events set metadata='{}' where entity_id="+literal(revoked.id)+' and event_type='+literal(code));throw Error('Audit was mutable');}catch(e){expect((e as {sqlstate?:string}).sqlstate).toBe('23514');}
 }
 state.userId=actor(6006);
 for(const label of ['MainShare','ViewShare','FileShare']){
  expect(await resolveSharedEntityAccess({shareId:id(label)})).toEqual(deniedSharedEntityAccess);
  await expect(addSharedComment({shareId:id(label),content:'Denied after revoke'})).rejects.toMatchObject({code:'FORBIDDEN'});
 }
 await expect(listSharedComments({shareId:id('MainShare')})).rejects.toMatchObject({code:'FORBIDDEN'});
 await expect(revokeShare(id('MainShare'))).rejects.toMatchObject({code:'NOT_FOUND'});
 await expect(getFileAccess({fileId:id('File')})).rejects.toMatchObject({code:'NOT_FOUND'});
 const reshare={entityType:'ARTIFACT',entityId:id('MainArtifact'),sourceVersionId:id('MainVersion'),destinationType:'TEAM',destinationId:c.TeamB.teamId,permissionLevel:'VIEW',shareMode:'SNAPSHOT'};
 await expect(shareEntity(reshare)).rejects.toMatchObject({code:'NOT_FOUND'});
 expect((await rpc('share_entity',{input:reshare})).error?.code).toBe('42501');
 expect((await GET(new Request('http://localhost/api/v1/workspaces/'+revoked.source_workspace_id),{params:Promise.resolve({workspaceId:revoked.source_workspace_id})})).status).toBe(403);
 expect(result('(select count(*) from public.artifacts where id in('+literal(id('MainArtifact'))+','+literal(id('SiblingArtifact'))+'))')).toBe(0);
 expect(result('(select count(*) from public.artifact_versions where id='+literal(id('MainVersion'))+')')).toBe(0);
 for(const statement of [
  'update public.shares set revoked_at=null,revoked_by=null where id='+literal(revoked.id),
  'delete from public.share_snapshots where share_id='+literal(revoked.id),
  'update public.artifacts set created_by='+literal(actor(6006))+' where id='+literal(id('MainArtifact')),
 ]){try{current(statement);throw Error('Authenticated history/source mutation succeeded');}catch(e){expect((e as {sqlstate?:string}).sqlstate).toBe('42501');}}
 // Defense in depth: RLS still denies reactivation after an accidental grant.
 query("begin;grant select,update on public.shares to authenticated;set local role authenticated;select set_config('request.jwt.claim.sub',"+literal(actor(6006))+",true);do $$declare n bigint;begin update public.shares set revoked_at=null,revoked_by=null where id="+literal(revoked.id)+";get diagnostics n=row_count;assert n=0;end$$;rollback;");
 state.userId=actor(6004);expect(await listSharedComments({shareId:id('MainShare')})).toEqual([c.Comment]);
 // M13.24: membership changes affect the individual, never revoke a Team Share.
 const transitionBefore=query('select to_jsonb(s)::text from public.shares s where id='+literal(id('TransitionShare')));
 const transitionSnapshot=query('select to_jsonb(s)::text from public.share_snapshots s where share_id='+literal(id('TransitionShare')));
 query("begin;select set_config('request.jwt.claim.sub',"+literal(actor(6002))+",true);select public.add_team_member("+literal(c.TeamB.teamId)+','+literal(actor(6005))+",'member');commit;");
 state.userId=actor(6006);
 expect((await resolveSharedEntityAccess({shareId:id('TransitionShare')})).allowed).toBe(true);
 const memberComment=await addSharedComment({shareId:id('TransitionShare'),content:'M13.24 history before removal'});
 query("begin;select set_config('request.jwt.claim.sub',"+literal(actor(6002))+",true);select public.remove_team_member("+literal(c.TeamB.teamId)+','+literal(actor(6006))+",'M13.24 destination removal');commit;");
 expect(await resolveSharedEntityAccess({shareId:id('TransitionShare')})).toEqual(deniedSharedEntityAccess);
 await expect(addSharedComment({shareId:id('TransitionShare'),content:'Removed recipient'})).rejects.toMatchObject({code:'FORBIDDEN'});
 state.userId=actor(6005);
 expect(await resolveSharedEntityAccess({shareId:id('TransitionShare')})).toMatchObject({allowed:true,canComment:true});
 expect(await listSharedComments({shareId:id('TransitionShare')})).toEqual([memberComment]);
 expect(query('select to_jsonb(s)::text from public.shares s where id='+literal(id('TransitionShare')))).toBe(transitionBefore);
 query("begin;select set_config('request.jwt.claim.sub',"+literal(actor(6002))+",true);select public.add_team_member("+literal(c.TeamB.teamId)+','+literal(actor(6006))+",'member');commit;");
 state.userId=actor(6004);
 // Authority comes from the current Lead, never original creator/sharer.
 query("begin;select set_config('request.jwt.claim.sub',"+literal(actor(6002))+",true);select public.remove_team_member("+literal(c.TeamA.teamId)+','+literal(actor(6004))+",'M13.12 old Lead removal');select public.assign_team_lead("+literal(c.TeamA.teamId)+','+literal(actor(6005))+');commit;');
 await expect(revokeShare(id('TransitionShare'))).rejects.toMatchObject({code:'NOT_FOUND'});
 await expect(revokeShare(id('ViewShare'))).rejects.toMatchObject({code:'NOT_FOUND'});
 state.userId=actor(6006);
 expect((await resolveSharedEntityAccess({shareId:id('TransitionShare')})).allowed).toBe(true);
 expect(query('select to_jsonb(s)::text from public.shares s where id='+literal(id('TransitionShare')))).toBe(transitionBefore);
 expect(query('select to_jsonb(s)::text from public.share_snapshots s where share_id='+literal(id('TransitionShare')))).toBe(transitionSnapshot);
 expect(await listSharedComments({shareId:id('TransitionShare')})).toEqual([memberComment]);
 expect(query("select count(*) from public.audit_events where event_type='SHARE_REVOKED' and entity_id="+literal(id('TransitionShare')))).toBe('0');
 state.userId=actor(6005);expect(await revokeShare(id('ViewShare'))).toEqual(revokedView);
 const transition=await revokeShare(id('TransitionShare'));expect(transition.revoked_by).toBe(actor(6005));expect(transition.shared_by).toBe(actor(6004));
 state.userId=actor(6004);await expect(revokeShare(id('TransitionShare'))).rejects.toMatchObject({code:'NOT_FOUND'});
 // Removing Team authority does not remove independent Personal ownership.
 expect((await revokeShare(id('PersonalShare'))).revoked_by).toBe(actor(6004));
 for(const role of ['anon','service_role'])expect(query("select has_function_privilege("+literal(role)+",'public.revoke_share(jsonb)','EXECUTE')")).toBe('f');
 expect(query("select prosecdef and proconfig=array['search_path=\"\"'] from pg_proc where oid='public.revoke_share(jsonb)'::regprocedure")).toBe('t');
 expect(query("select count(*) from public.audit_events where event_type='SHARE_REVOKED'")).toBe('8');
 // M13.16: move to a newer Version only through real revoke + new Share operations.
 state.userId=actor(6005); // Current source Lead; historical creator remains unchanged.
 const selected={...reshare,permissionLevel:'COMMENT'};
 const oldShare=await shareEntity(selected);
 expect(await shareEntity(selected)).toEqual(oldShare);
 const oldSnapshot=query('select to_jsonb(s)::text from public.share_snapshots s where share_id='+literal(oldShare.id));
 const newer=JSON.parse(current('select public.create_artifact_version('+literal(id('MainArtifact'))+"::uuid,'{\"notes\":\"Explicit next checkpoint\"}'::jsonb,'M13.16 next Version')").split(/\r?\n/).find(s=>s.startsWith('{'))!);
 await expect(shareEntity({...selected,sourceVersionId:newer.id})).rejects.toMatchObject({code:'ACTIVE_SHARE_DIFFERENT_VERSION'});
 expect(query('select to_jsonb(s)::text from public.share_snapshots s where share_id='+literal(oldShare.id))).toBe(oldSnapshot);
 await revokeShare(oldShare.id);
 const nextShare=await shareEntity({...selected,sourceVersionId:newer.id});
 expect(nextShare.id).not.toBe(oldShare.id);
 expect(query('select source_version_id::text from public.share_snapshots where share_id='+literal(nextShare.id))).toBe(newer.id);
 expect(query('select to_jsonb(s)::text from public.share_snapshots s where share_id='+literal(oldShare.id))).toBe(oldSnapshot);
 expect(query('select revoked_at is not null from public.shares where id='+literal(oldShare.id))).toBe('t');
 state.userId=actor(6006);
 expect((await resolveSharedEntityAccess({shareId:oldShare.id})).allowed).toBe(false);
 expect(await resolveSharedEntityAccess({shareId:nextShare.id})).toMatchObject({allowed:true,sourceVersionId:newer.id,canEdit:false});
},180000);
