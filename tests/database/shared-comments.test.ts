import {spawnSync} from 'node:child_process';
import {join} from 'node:path';
import {expect,it,vi} from 'vitest';
vi.mock('server-only',()=>({}));
const state=vi.hoisted(()=>({userId:'00000000-0000-4000-8000-000000006006'}));
vi.mock('@/lib/auth/authorization',async original=>({...await original<typeof import('@/lib/auth/authorization')>(),getAuthorizationContext:async()=>({userId:state.userId,assignments:[]})}));
vi.mock('@/lib/db/server',()=>({createServerSupabaseClient:async()=>({rpc:rpcTransport,from:tableTransport})}));
import {createArtifactVersion} from '@/features/artifacts/create-version';
import {updateScamperEntry} from '@/features/scamper/service';
import {addSharedComment,listSharedComments} from '@/features/shares/comments';
import {shareEntity} from '@/features/shares/create';
import {resolveSharedEntityAccess} from '@/features/shares/access';
import {resolveShareability} from '@/features/shares/shareability';
import {deniedSharedEntityAccess} from '@/features/shares/access-schema';
import {archiveFile} from '@/features/files/archive';
import {updateDevelopmentObject} from '@/features/projects/object-service';
import {createMindMap} from '@/features/mind-map/create';
import {saveMindMapDraft} from '@/features/mind-map/draft';
import {getFileAccess} from '@/features/files/access';
import {listMyWorkspaces} from '@/features/workspaces/service';
import {GET} from '@/app/api/v1/workspaces/[workspaceId]/route';
function literal(v:string){return `'${v.replaceAll("'","''")}'`;}
function query(sql:string){
 const port=process.env.FICI_COMMENT_TEST_PORT;if(!port||!/^\d+$/.test(port)||!process.env.POSTGRES_BIN)throw Error('Disposable context required');
 const r=spawnSync(join(process.env.POSTGRES_BIN,process.platform==='win32'?'psql.exe':'psql'),['-X','-h','127.0.0.1','-p',port,'-U','postgres','-d','fici_share_comments','-v','ON_ERROR_STOP=1','-t','-A','-f','-'],{input:'\\set VERBOSITY verbose\n'+sql,encoding:'utf8',windowsHide:true,timeout:45000});
 if(r.error||r.status!==0)throw Object.assign(Error('Disposable SQL denied'),{sqlstate:r.stderr.match(/ERROR:\s+([A-Z0-9]{5}):/)?.[1]??'UNKNOWN'});return r.stdout.trim();
}
function current(sql:string){return query(`begin;set local role authenticated;select set_config('request.jwt.claim.sub',${literal(state.userId)},true);${sql};commit;`);}
function result(sql:string){const line=current(`select 'RESULT='||(${sql})::text`).split(/\r?\n/).find(s=>s.startsWith('RESULT='));if(!line)throw Error('Missing canonical result');return JSON.parse(line.slice(7));}
async function rpcTransport(name:string,args:Record<string,unknown>){
 const allowed=['create_artifact_version','save_mind_map_draft','resolve_shareability','archive_file','create_mind_map','update_scamper_entry','add_share_comment','list_share_comments','share_entity','resolve_shared_entity_access','get_team_workspace_access','team_workspace_has_chat_access','get_submitted_artifact_metadata','update_artifact_draft','archive_artifact','submit_artifact','approve_artifact','start_review','request_revision','add_feedback','link_file','link_evidence','request_file_upload'];
 if(!allowed.includes(name))throw Error('Unexpected RPC '+name);
 const value=(v:unknown):string=>v===null?'null':typeof v==='object'?literal(JSON.stringify(v))+'::jsonb':typeof v==='number'||typeof v==='boolean'?String(v):literal(String(v));
 try{return {data:result('public.'+name+'('+Object.entries(args).map(([k,v])=>k+'=>'+value(v)).join(',')+')'),error:null};}
 catch(e){return {data:null,error:{code:(e as {sqlstate?:string}).sqlstate??'UNKNOWN'}};}
}
function tableTransport(table:string){
 if(!['workspaces','files','artifacts','artifact_versions','development_objects'].includes(table))throw Error('Unexpected table');
 let columns='*',id:string|undefined;
 const execute=async(single:boolean)=>{
  try{const rows=result(`(select coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb) from (select ${columns} from public.${table}${id?` where id=${literal(id)}::uuid`:''} order by created_at,id) x)`);return {data:single?(rows[0]??null):rows,error:null};}catch{return {data:null,error:{code:'42501'}};}
 };
 const builder={select:(v:string)=>{if(!['*','id'].includes(v))throw Error('Unexpected projection');columns=v;return builder;},eq:(k:string,v:string)=>{if(k!=='id')throw Error('Unexpected filter');id=v;return builder;},order:()=>builder,maybeSingle:()=>execute(true),then:(resolve:unknown,reject:unknown)=>execute(false).then(resolve as never,reject as never)};
 return builder;
}

import {updateArtifactDraft} from '@/features/artifacts/update-draft';
import {archiveArtifact,getArtifactVersion} from '@/features/artifacts/history';
import {submitArtifact} from '@/features/artifacts/submit';
import {approveArtifact} from '@/features/artifacts/approve';
import {startReview,requestRevision,addFeedback} from '@/features/artifacts/review';
import {reopenApprovedArtifact} from '@/features/artifacts/reopen';
import {linkFile} from '@/features/files/link';
import {linkEvidence} from '@/features/evidence/link';
import {requestUpload} from '@/features/files/upload';
it('M13.11 COLLABORATE is inert across server/RPC/legacy rows/direct DML/feature boundaries',async()=>{
 const c=JSON.parse(query('select jsonb_object_agg(label,payload)::text from public.comment_test_context'));
 const id=(label:string)=>c[label].id;
 const tables=['shares','share_snapshots','audit_events','artifacts','artifact_versions','artifact_object_links','development_objects','scamper_entries','files','file_links','evidence_links','mind_maps','mind_map_nodes','mind_map_edges','workspaces','team_memberships','share_comments','submissions','review_actions','feedback_items'];
 const history=()=>query('select jsonb_build_array('+tables.map(t=>"(select coalesce(jsonb_agg(to_jsonb(x) order by id),'[]'::jsonb) from public."+t+" x)").join(',')+')::text');
 const before=history();
 const request={entityType:'ARTIFACT',entityId:id('Artifact'),sourceVersionId:id('V2'),destinationType:'TEAM',destinationId:c.TeamB.teamId,permissionLevel:'COLLABORATE',shareMode:'SNAPSHOT'};
 for(const user of ['00000000-0000-4000-8000-000000006004','00000000-0000-4000-8000-000000006001','00000000-0000-4000-8000-000000006002','00000000-0000-4000-8000-000000006003','00000000-0000-4000-8000-000000006008']){
  state.userId=user;
  for(const input of [request,{...request,entityType:'PATENT_RECORD',entityId:c.TeamA.shared_entity_id,sourceVersionId:null,destinationId:c.TeamA.destination_id},{...request,destinationType:'MASTER',destinationId:c.Master.destination_id}]){
   const {sourceVersionId,...eligibility}=input;expect(sourceVersionId===null||typeof sourceVersionId==='string').toBe(true);
   expect(await resolveShareability(eligibility)).toEqual({allowed:false,deniedReason:'PERMISSION_NOT_ALLOWED'});
   await expect(shareEntity(input)).rejects.toMatchObject({code:'NOT_FOUND'});
   expect((await rpcTransport('resolve_shareability',{input:eligibility})).data).toEqual({allowed:false,deniedReason:'PERMISSION_NOT_ALLOWED'});
   expect((await rpcTransport('share_entity',{input})).error?.code).toBe('42501');
  }
  for(const statement of [
   'insert into public.shares(shared_entity_type,shared_entity_id,destination_type,destination_id,permission_level,share_mode) values('+['ARTIFACT',id('Artifact'),'TEAM',c.TeamB.teamId,'COLLABORATE','SNAPSHOT'].map(literal).join(',')+')',
   "update public.shares set permission_level='COLLABORATE' where id="+literal(id('View')),
  ]){try{current(statement);throw Error('Direct Share forgery succeeded');}catch(e){expect((e as {sqlstate?:string}).sqlstate).toBe('42501');}}
 }
 expect(history()).toBe(before); // Includes the existing durable audit/notification hook.
 // Defense beyond missing grants: authenticated RLS must reject forged writes
 // even if a future migration accidentally grants table DML. Roll grants back.
 const grantProbe="begin;grant select,insert,update on public.shares to authenticated;set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);do $$declare n bigint;begin begin insert into public.shares(shared_entity_type,shared_entity_id,destination_type,destination_id,permission_level,share_mode) values('ARTIFACT',"+literal(id('Artifact'))+",'TEAM',"+literal(c.TeamB.teamId)+",'COLLABORATE','SNAPSHOT');raise exception 'RLS insert bypass';exception when insufficient_privilege then null;end;update public.shares set permission_level='COLLABORATE' where id="+literal(id('View'))+";get diagnostics n=row_count;assert n=0;end$$;rollback;";
 query(grantProbe);
 expect(history()).toBe(before);
 // Trusted legacy fixtures retain vocabulary, but confer no runtime authority.
 const legacy=JSON.parse(query("begin;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);with s as (insert into public.shares(shared_entity_type,shared_entity_id,destination_type,destination_id,permission_level,share_mode) values('ARTIFACT',"+literal(id('Artifact'))+",'TEAM',"+literal(c.TeamB.teamId)+",'COLLABORATE','SNAPSHOT') returning id),ss as (insert into public.share_snapshots(share_id,source_version_id) select id,"+literal(id('V2'))+"::uuid from s) select json_build_object('id',id) from s;commit;").split(/\r?\n/).find(s=>s.startsWith('{'))!);
 const legacyOnly=JSON.parse(query("begin;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);with s as (insert into public.shares(shared_entity_type,shared_entity_id,destination_type,destination_id,permission_level,share_mode) values('ARTIFACT',"+literal(id('Sibling'))+",'TEAM',"+literal(c.TeamB.teamId)+",'COLLABORATE','SNAPSHOT') returning id),ss as (insert into public.share_snapshots(share_id,source_version_id) select s.id,v.id from s cross join public.artifact_versions v where v.artifact_id="+literal(id('Sibling'))+") select json_build_object('id',id) from s;commit;").split(/\r?\n/).find(s=>s.startsWith('{'))!);
 state.userId='00000000-0000-4000-8000-000000006006';
 expect(await resolveSharedEntityAccess({shareId:legacy.id})).toEqual(deniedSharedEntityAccess);
 expect(await resolveSharedEntityAccess({shareId:legacyOnly.id})).toEqual(deniedSharedEntityAccess);
 expect(await resolveSharedEntityAccess({shareId:id('Collaborate')})).toEqual(deniedSharedEntityAccess);
 expect(await resolveSharedEntityAccess({shareId:id('View')})).toMatchObject({canView:true,canComment:false,canEdit:false,canReshare:false});
 expect(await resolveSharedEntityAccess({shareId:id('Comment')})).toMatchObject({canView:true,canComment:true,canEdit:false,canReshare:false});
 await expect(addSharedComment({shareId:legacy.id,content:'No implicit COMMENT'})).rejects.toMatchObject({code:'FORBIDDEN'});
 // A real source Mind Map with a deferred Share, not a nonexistent guessed map.
 const mapContext=JSON.parse(query("begin;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);do $$declare a uuid;v uuid;m uuid;s uuid;begin insert into public.artifacts(project_id,workspace_id,artifact_type,title,created_by) select project_id,workspace_id,'MIND_MAP','Deferred boundary map',created_by from public.artifacts where id="+literal(id('Artifact'))+" returning id into a;insert into public.artifact_versions(artifact_id,version_number,content_snapshot,status,created_by) values(a,1,'{}','DRAFT','00000000-0000-4000-8000-000000006004') returning id into v;insert into public.mind_maps(artifact_id,artifact_version_id) values(a,v) returning id into m;insert into public.shares(shared_entity_type,shared_entity_id,destination_type,destination_id,permission_level,share_mode) values('ARTIFACT',a,'TEAM',"+literal(c.TeamB.teamId)+",'COLLABORATE','SNAPSHOT') returning id into s;insert into public.share_snapshots(share_id,source_version_id) values(s,v);perform set_config('m13.map_fixture',json_build_object('mapId',m,'shareId',s)::text,true);end$$;select current_setting('m13.map_fixture');commit;").split(/\r?\n/).find(s=>s.startsWith('{'))!);
 expect(await resolveSharedEntityAccess({shareId:mapContext.shareId})).toEqual(deniedSharedEntityAccess);
 const afterFixture=history();
 const denied=async(p:Promise<unknown>)=>{await expect(p).rejects.toMatchObject({code:expect.stringMatching(/^(NOT_FOUND|FORBIDDEN)$/)});};
 await denied(updateArtifactDraft({artifactVersionId:id('V2'),expectedDraftRevision:0,contentSnapshot:{notes:'COLLABORATE attack'}}));
 await denied(createArtifactVersion({artifactId:id('Artifact'),contentSnapshot:{notes:'Unauthorized successor'},changeSummary:null}));
 await denied(archiveArtifact(id('Artifact')));
 await denied(archiveFile(id('FileRow')));
 await denied(updateDevelopmentObject({objectId:id('ObjectSource'),title:'COLLABORATE attack'}));
 await denied(updateScamperEntry({entryId:c.Scamper.shared_entity_id,resultText:'COLLABORATE attack'}));
 await denied(createMindMap({activityInstanceId:id('Activity'),idempotencyKey:'collaborate-denied'}));
 await denied(saveMindMapDraft({mindMapId:mapContext.mapId,expectedDraftRevision:0}));
 await denied(linkFile({fileId:id('FileRow'),entityType:'ARTIFACT',entityId:id('Artifact'),relationshipType:'ARTIFACT_FILE'}));
 for(const [table,assignment,where] of [
  ['artifacts',"created_by="+literal(state.userId)+",workspace_id="+literal(c.View.source_workspace_id)+",status='ARCHIVED',archived_at=clock_timestamp()",'id='+literal(id('Artifact'))],
  ['artifact_versions','id=id','id='+literal(id('V2'))],
  ['artifact_object_links','id=id','artifact_id='+literal(id('Artifact'))],
  ['development_objects','id=id','id='+literal(id('ObjectSource'))],
  ['files','id=id','id='+literal(id('FileRow'))],
  ['scamper_entries','id=id','id='+literal(c.Scamper.shared_entity_id)],
  ['mind_maps','id=id','true'],['mind_map_nodes','id=id','true'],['mind_map_edges','id=id','true'],
 ]){try{current('do $$declare n bigint;begin update public.'+table+' set '+assignment+' where '+where+';get diagnostics n=row_count;assert n=0;end$$');}catch(e){expect((e as {sqlstate?:string}).sqlstate).toBe('42501');}}
 expect((await GET(new Request('http://localhost/api/v1/workspaces/'+c.View.source_workspace_id),{params:Promise.resolve({workspaceId:c.View.source_workspace_id})})).status).toBe(403);
 expect((await listMyWorkspaces()).some(w=>w.id===c.View.source_workspace_id)).toBe(false);
 expect(history()).toBe(afterFixture);
 console.log('M13.11 COLLABORATE policy/server/RPC/legacy/direct-DML/feature-mutations/privacy PASS');
},180000);
it('AT-SHARE-004 exact-Share comments never grant source mutation or formal review',async()=>{
 const c=JSON.parse(query('select jsonb_object_agg(label,payload)::text from public.comment_test_context'));
 const id=(label:string)=>c[label].id;
 const frozen=await resolveSharedEntityAccess({shareId:id('Comment')});
 const canonical=()=>query('select jsonb_build_array('+['files','evidence','patent_records','scamper_entries','artifacts','artifact_versions','submissions','feedback_items','review_actions','development_objects','workspaces','team_memberships','file_links','evidence_links'].map(t=>"(select coalesce(jsonb_agg(to_jsonb(x) order by id),'[]'::jsonb) from public."+t+" x)").join(',')+')::text');
 const canonicalBefore=canonical();
 const comment=await addSharedComment({shareId:id('Comment'),content:'Team B feedback on frozen V2'});
 expect(comment).toMatchObject({share_id:id('Comment'),author_user_id:state.userId,target_entity_type:'ARTIFACT',target_entity_id:id('Artifact'),target_version_id:id('V2'),content:'Team B feedback on frozen V2'});
 expect(await listSharedComments({shareId:id('Comment')})).toEqual([comment]);
 await expect(addSharedComment({shareId:id('View'),content:'Denied VIEW comment'})).rejects.toMatchObject({code:'FORBIDDEN'});
 await expect(listSharedComments({shareId:id('View')})).rejects.toMatchObject({code:'FORBIDDEN'});
 await expect(listSharedComments({shareId:id('MasterComment')})).rejects.toMatchObject({code:'FORBIDDEN'});
 for(const field of ['authorUserId','targetVersionId','targetEntityId','createdAt','submissionId'])await expect(addSharedComment({shareId:id('Comment'),content:'Spoof', [field]:id('V3')})).rejects.toMatchObject({code:'VALIDATION_ERROR'});

 expect(frozen).toMatchObject({allowed:true,canView:true,canComment:true,canEdit:false,canReshare:false,sourceVersionId:id('V2'),snapshotContent:{content_snapshot:{notes:'Frozen V2'}}});
 const draftComment=await addSharedComment({shareId:id('DraftShare'),content:'Discussion on a Draft without formal review'});
 expect(draftComment).toMatchObject({target_entity_id:c.DraftArtifact.artifactId,target_version_id:c.DraftArtifact.initialVersionId});
 expect(query('select count(*) from public.submissions where artifact_id='+literal(c.DraftArtifact.artifactId))).toBe('0');
 expect(query('select status from public.artifact_versions where id='+literal(c.DraftArtifact.initialVersionId))).toBe('DRAFT');
 // All six supported entity types use this one Share context, not M8 review.
 const nonVersionedComments=[];
 for(const [kind,target,team,recipient] of [
  ['DEVELOPMENT_OBJECT',id('ObjectSource'),c.TeamB.teamId,'00000000-0000-4000-8000-000000006006'],
  ['FILE',id('FileRow'),c.TeamB.teamId,'00000000-0000-4000-8000-000000006006'],
  ['EVIDENCE',id('EvidenceSource'),c.TeamB.teamId,'00000000-0000-4000-8000-000000006006'],
  ['PATENT_RECORD',c.Patent.shared_entity_id,c.TeamB.teamId,'00000000-0000-4000-8000-000000006006'],
  ['SCAMPER_ENTRY',c.Scamper.shared_entity_id,c.TeamA.destination_id,'00000000-0000-4000-8000-000000006005'],
 ]){
  state.userId='00000000-0000-4000-8000-000000006004';
  const shared=await shareEntity({entityType:kind,entityId:target,destinationType:'TEAM',destinationId:team,permissionLevel:'COMMENT',shareMode:'SNAPSHOT'});
  state.userId=recipient;const item=await addSharedComment({shareId:shared.id,content:'Exact '+kind+' discussion'});
  expect(item).toMatchObject({share_id:shared.id,target_entity_type:kind,target_entity_id:target,target_version_id:null,author_user_id:recipient});
  expect(await listSharedComments({shareId:shared.id})).toEqual([item]);nonVersionedComments.push(item);
  if(kind==='SCAMPER_ENTRY')await expect(updateScamperEntry({entryId:target,resultText:'COMMENT is not edit permission'})).rejects.toMatchObject({code:'NOT_FOUND'});
 }
 state.userId='00000000-0000-4000-8000-000000006006';
 expect(await listSharedComments({shareId:id('Comment')})).toEqual([comment]);
 // Bypass the TypeScript preflight: RPC itself must reject VIEW and spoofing.
 expect((await rpcTransport('add_share_comment',{input:{shareId:id('View'),content:'Raw VIEW attack'}})).error?.code).toBe('42501');
 for(const field of ['authorUserId','targetEntityId','targetVersionId','createdAt'])expect((await rpcTransport('add_share_comment',{input:{shareId:id('Comment'),content:'Raw spoof',[field]:id('V3')}})).error?.code).toBe('22023');
 expect(result('(select count(*) from public.share_comments where share_id='+literal(id('MasterComment'))+')')).toBe(0);
 for(const fn of ['add_share_comment','list_share_comments']){
  expect(query("select has_function_privilege('anon','public."+fn+"(jsonb)','EXECUTE')")).toBe('f');
  expect(query("select has_function_privilege('service_role','public."+fn+"(jsonb)','EXECUTE')")).toBe('f');
  expect(query("select has_function_privilege('authenticated','public."+fn+"(jsonb)','EXECUTE')")).toBe('t');
  expect(query("select prosecdef and proconfig=array['search_path=\"\"'] from pg_proc where oid='public."+fn+"(jsonb)'::regprocedure")).toBe('t');
 }
 expect(canonical()).toBe(canonicalBefore);
 const tables=['share_comments','artifacts','artifact_versions','artifact_object_links','share_snapshots','shares','submissions','feedback_items','review_actions','development_objects','files','file_links','evidence','evidence_links','workspaces','team_memberships'];
 const history=()=>query('select jsonb_build_array('+tables.map(t=>"(select coalesce(jsonb_agg(to_jsonb(x) order by id),'[]'::jsonb) from public."+t+" x)").join(',')+')::text');
 const before=history();
 const denied=async(p:Promise<unknown>)=>{try{await p;throw Error('VIEW write succeeded');}catch(e){expect(['NOT_FOUND','FORBIDDEN']).toContain((e as {code?:string}).code);}};
 await denied(updateArtifactDraft({artifactVersionId:id('V2'),expectedDraftRevision:0,contentSnapshot:{notes:'Stolen'}}));
 await denied(updateArtifactDraft({artifactVersionId:id('V3'),expectedDraftRevision:0,contentSnapshot:{notes:'Stolen sibling Draft'}}));
 await denied(createArtifactVersion({artifactId:id('Artifact'),contentSnapshot:{notes:'Unauthorized successor'},changeSummary:null}));
 await denied(archiveArtifact(id('Artifact')));
 await denied(reopenApprovedArtifact({artifactId:id('Artifact')}));
 await denied(getArtifactVersion(id('V2')));
 await denied(submitArtifact({artifactId:id('Artifact'),artifactVersionId:id('V2'),activityInstanceId:id('Activity')}));
 await denied(addFeedback({targetEntityType:'ARTIFACT',targetEntityId:id('Artifact'),targetVersionId:id('V2'),feedbackType:'COMMENT',content:'VIEW must not comment'}));
 await denied(approveArtifact({submissionId:id('Submission')}));
 await denied(startReview(id('Submission')));
 await denied(requestRevision({submissionId:id('Submission'),note:'Unauthorized'}));
 await denied(linkFile({fileId:id('FileRow'),entityType:'ARTIFACT',entityId:id('Artifact'),relationshipType:'ARTIFACT_FILE'}));
 await denied(linkEvidence({evidenceId:id('EvidenceSource'),entityType:'ARTIFACT',entityId:id('Artifact'),relationshipType:'RELATED_TO'}));
 await denied(shareEntity({entityType:'ARTIFACT',entityId:id('Artifact'),sourceVersionId:id('V2'),destinationType:'TEAM',destinationId:c.TeamB.teamId,permissionLevel:'VIEW',shareMode:'SNAPSHOT'}));
 await denied(requestUpload({workspaceId:c.View.source_workspace_id,projectId:id('Project'),filename:'attack.txt',mimeType:'text/plain',size:1}));
 await denied(getFileAccess({fileId:id('FileRow')}));
 expect((await GET(new Request('http://localhost/api/v1/workspaces/'+c.View.source_workspace_id),{params:Promise.resolve({workspaceId:c.View.source_workspace_id})})).status).toBe(403);
 expect((await listMyWorkspaces()).some(w=>w.id===c.View.source_workspace_id)).toBe(false);
 for(const [table,target] of [['artifacts',id('Artifact')],['artifact_versions',id('V2')],['share_snapshots',id('Snapshot')],['shares',id('View')],['share_comments',comment.id],['development_objects',id('ObjectSource')]]){
  for(const sql of ['update public.'+table+" set id=id where id="+literal(target)+' returning id','delete from public.'+table+' where id='+literal(target)+' returning id']){
   try{current('do $$declare n bigint;begin execute '+literal(sql)+';get diagnostics n=row_count;assert n=0;end$$');}catch(e){expect((e as {sqlstate?:string}).sqlstate).toBe('42501');}
  }
 }
 // No insert permission exists for source relationships, feedback or Snapshots.
 for(const table of ['share_comments','artifacts','artifact_versions','artifact_object_links','feedback_items','share_snapshots','file_links','evidence_links']){
  try{current('insert into public.'+table+' default values');throw Error('Direct insert succeeded');}catch(e){expect((e as {sqlstate?:string}).sqlstate).toBe('42501');}
 }
 expect(history()).toBe(before);
 expect(await resolveSharedEntityAccess({shareId:id('Comment')})).toEqual(frozen);
 // Previously removed recipient, unrelated role-only actors and source IDs grant nothing.
 for(const user of ['00000000-0000-4000-8000-000000006007','00000000-0000-4000-8000-000000006001','00000000-0000-4000-8000-000000006003','00000000-0000-4000-8000-000000006008']){
  state.userId=user;expect((await resolveSharedEntityAccess({shareId:id('View')})).allowed).toBe(false);
  await expect(addSharedComment({shareId:id('Comment'),content:'Unrelated or removed caller'})).rejects.toMatchObject({code:'FORBIDDEN'});
 }
 state.userId='00000000-0000-4000-8000-000000006006';
 for(const guessed of [id('Snapshot'),id('Artifact'),id('V2')]){
  expect((await resolveSharedEntityAccess({shareId:guessed})).allowed).toBe(false);
  await expect(addSharedComment({shareId:guessed,content:'Guessed target'})).rejects.toMatchObject({code:'FORBIDDEN'});
  await expect(listSharedComments({shareId:guessed})).rejects.toMatchObject({code:'FORBIDDEN'});
 }

 // Exact MASTER recipient expiry removes new comment rights, not history.
 state.userId='00000000-0000-4000-8000-000000006002';
 expect(await listSharedComments({shareId:id('Comment')})).toEqual([comment]);
 await expect(listSharedComments({shareId:id('DraftShare')})).rejects.toMatchObject({code:'FORBIDDEN'});
 const masterComment=await addSharedComment({shareId:id('MasterComment'),content:'Master discussion, not formal review'});
 expect(canonical()).toBe(canonicalBefore);
 const masterAssignment=c.MasterComment.destination_id;
 const priorEnd=query("select coalesce(ends_at::text,'NULL') from public.role_assignments where id="+literal(masterAssignment));
 query("update public.role_assignments set ends_at=clock_timestamp()-interval '1 second' where id="+literal(masterAssignment));
 await expect(addSharedComment({shareId:id('MasterComment'),content:'Expired'})).rejects.toMatchObject({code:'FORBIDDEN'});
 await expect(listSharedComments({shareId:id('MasterComment')})).rejects.toMatchObject({code:'FORBIDDEN'});
 query('update public.role_assignments set ends_at='+(priorEnd==='NULL'?'null':literal(priorEnd)+'::timestamptz')+' where id='+literal(masterAssignment));
 query("update public.role_assignments set status='inactive' where id="+literal(masterAssignment));
 await expect(addSharedComment({shareId:id('MasterComment'),content:'Inactive assignment'})).rejects.toMatchObject({code:'FORBIDDEN'});
 await expect(listSharedComments({shareId:id('MasterComment')})).rejects.toMatchObject({code:'FORBIDDEN'});
 query("update public.role_assignments set status='active' where id="+literal(masterAssignment));
 // Revocation denies an otherwise active MASTER recipient independently of membership loss.
 query("begin;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);update public.shares set revoked_at=clock_timestamp(),revoked_by='00000000-0000-4000-8000-000000006004' where id="+literal(id('MasterComment'))+';commit;');
 await expect(addSharedComment({shareId:id('MasterComment'),content:'Revoked active destination'})).rejects.toMatchObject({code:'FORBIDDEN'});
 // Independent formal source-review authority still permits historical reads.
 expect(await listSharedComments({shareId:id('MasterComment')})).toEqual([masterComment]);
 // Current destination membership is authoritative even though Share stays active.
 current('select public.remove_team_member('+literal(c.TeamB.teamId)+",'00000000-0000-4000-8000-000000006006','M13.10 recipient removal')");
 state.userId='00000000-0000-4000-8000-000000006006';
 await expect(addSharedComment({shareId:id('Comment'),content:'Removed'})).rejects.toMatchObject({code:'FORBIDDEN'});
 await expect(listSharedComments({shareId:id('Comment')})).rejects.toMatchObject({code:'FORBIDDEN'});
 expect(result('(select count(*) from public.share_comments where share_id='+literal(id('Comment'))+')')).toBe(0);
 state.userId='00000000-0000-4000-8000-000000006004';
 expect(await listSharedComments({shareId:id('Comment')})).toEqual([comment]);
 query("begin;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);update public.shares set revoked_at=clock_timestamp(),revoked_by='00000000-0000-4000-8000-000000006004' where id="+literal(id('Comment'))+';commit;');
 expect(await listSharedComments({shareId:id('Comment')})).toEqual([comment]);
 expect(await listSharedComments({shareId:id('MasterComment')})).toEqual([masterComment]);
 await expect(addSharedComment({shareId:id('Comment'),content:'Revoked'})).rejects.toMatchObject({code:'FORBIDDEN'});
 state.userId='00000000-0000-4000-8000-000000006006';
 await expect(listSharedComments({shareId:id('Comment')})).rejects.toMatchObject({code:'FORBIDDEN'});
 expect(Number(query('select count(*) from public.share_comments'))).toBe(nonVersionedComments.length+3);
},180000);
