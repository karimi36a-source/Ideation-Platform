import {spawnSync} from 'node:child_process';
import {join} from 'node:path';
import {expect,it,vi} from 'vitest';
vi.mock('server-only',()=>({}));
const state=vi.hoisted(()=>({userId:'00000000-0000-4000-8000-000000006006'}));
vi.mock('@/lib/auth/authorization',async original=>({...await original<typeof import('@/lib/auth/authorization')>(),getAuthorizationContext:async()=>({userId:state.userId,assignments:[]})}));
vi.mock('@/lib/db/server',()=>({createServerSupabaseClient:async()=>({rpc:rpcTransport,from:tableTransport})}));
import {shareEntity} from '@/features/shares/create';
import {addSharedComment} from '@/features/shares/comments';
import {copySharedSnapshotToWorkspace} from '@/features/shares/copy';
import {createArtifactVersion} from '@/features/artifacts/create-version';
import {resolveSharedEntityAccess} from '@/features/shares/access';
import {getFileAccess} from '@/features/files/access';
import {listMyWorkspaces} from '@/features/workspaces/service';
import {GET} from '@/app/api/v1/workspaces/[workspaceId]/route';
function literal(v:string){return `'${v.replaceAll("'","''")}'`;}
function query(sql:string){
 const port=process.env.FICI_VIEW_TEST_PORT;if(!port||!/^\d+$/.test(port)||!process.env.POSTGRES_BIN)throw Error('Disposable context required');
 const r=spawnSync(join(process.env.POSTGRES_BIN,process.platform==='win32'?'psql.exe':'psql'),['-X','-h','127.0.0.1','-p',port,'-U','postgres','-d','fici_share_view','-v','ON_ERROR_STOP=1','-t','-A','-f','-'],{input:'\\set VERBOSITY verbose\n'+sql,encoding:'utf8',windowsHide:true,timeout:45000});
 if(r.error||r.status!==0)throw Object.assign(Error('Disposable SQL denied'),{sqlstate:r.stderr.match(/ERROR:\s+([A-Z0-9]{5}):/)?.[1]??'UNKNOWN'});return r.stdout.trim();
}
function current(sql:string){return query(`begin;set local role authenticated;select set_config('request.jwt.claim.sub',${literal(state.userId)},true);${sql};commit;`);}
function result(sql:string){const line=current(`select 'RESULT='||(${sql})::text`).split(/\r?\n/).find(s=>s.startsWith('RESULT='));if(!line)throw Error('Missing canonical result');return JSON.parse(line.slice(7));}
async function rpcTransport(name:string,args:Record<string,unknown>){
 const allowed=['share_entity','resolve_shared_entity_access','add_share_comment','create_artifact_version','get_team_workspace_access','team_workspace_has_chat_access','get_submitted_artifact_metadata','update_artifact_draft','archive_artifact','submit_artifact','approve_artifact','start_review','request_revision','add_feedback','link_file','link_evidence','request_file_upload'];
 if(!allowed.includes(name))throw Error('Unexpected RPC '+name);
 const value=(v:unknown):string=>v===null?'null':typeof v==='object'?literal(JSON.stringify(v))+'::jsonb':typeof v==='number'||typeof v==='boolean'?String(v):literal(String(v));
 try{return {data:result('public.'+name+'('+Object.entries(args).map(([k,v])=>k+'=>'+value(v)).join(',')+')'),error:null};}
 catch(e){return {data:null,error:{code:(e as {sqlstate?:string}).sqlstate??'UNKNOWN'}};}
}
function tableTransport(table:string){
 if(!['workspaces','files','artifacts','artifact_versions'].includes(table))throw Error('Unexpected table');
 let columns='*',id:string|undefined;
 const execute=async(single:boolean)=>{
  try{const rows=result(`(select coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb) from (select ${columns} from public.${table}${id?` where id=${literal(id)}::uuid`:''} order by created_at,id) x)`);return {data:single?(rows[0]??null):rows,error:null};}catch{return {data:null,error:{code:'42501'}};}
 };
 const builder={select:(v:string)=>{if(!['*','id'].includes(v))throw Error('Unexpected projection');columns=v;return builder;},eq:(k:string,v:string)=>{if(k!=='id')throw Error('Unexpected filter');id=v;return builder;},order:()=>builder,maybeSingle:()=>execute(true),then:(resolve:unknown,reject:unknown)=>execute(false).then(resolve as never,reject as never)};
 return builder;
}

import {updateArtifactDraft} from '@/features/artifacts/update-draft';
import {archiveArtifact,getArtifact,getArtifactVersion,listArtifactVersions} from '@/features/artifacts/history';
import {submitArtifact} from '@/features/artifacts/submit';
import {approveArtifact} from '@/features/artifacts/approve';
import {startReview,requestRevision,addFeedback} from '@/features/artifacts/review';
import {reopenApprovedArtifact} from '@/features/artifacts/reopen';
import {linkFile} from '@/features/files/link';
import {linkEvidence} from '@/features/evidence/link';
import {requestUpload} from '@/features/files/upload';
it('AT-SHARE-003 VIEW is frozen-only across real server services and direct authenticated SQL',async()=>{
 const c=JSON.parse(query('select jsonb_object_agg(label,payload)::text from public.view_test_context'));
 const id=(label:string)=>c[label].id;
 const frozen=await resolveSharedEntityAccess({shareId:id('View')});
 expect(frozen).toMatchObject({allowed:true,canView:true,canComment:false,canEdit:false,canReshare:false,sourceVersionId:id('V2'),snapshotContent:{content_snapshot:{notes:'Frozen V2'}}});
 const tables=['artifacts','artifact_versions','artifact_object_links','share_snapshots','shares','share_comments','submissions','feedback_items','review_actions','development_objects','files','file_links','evidence','evidence_links','workspaces','team_memberships'];
 const history=()=>query('select jsonb_build_array('+tables.map(t=>"(select coalesce(jsonb_agg(to_jsonb(x) order by id),'[]'::jsonb) from public."+t+" x)").join(',')+')::text');
 const before=history();
 const denied=async(p:Promise<unknown>)=>{try{await p;throw Error('VIEW write succeeded');}catch(e){expect(['NOT_FOUND','FORBIDDEN']).toContain((e as {code?:string}).code);}};
 await denied(updateArtifactDraft({artifactVersionId:id('V2'),expectedDraftRevision:0,contentSnapshot:{notes:'Stolen'}}));
 await denied(updateArtifactDraft({artifactVersionId:id('V3'),expectedDraftRevision:0,contentSnapshot:{notes:'Stolen sibling Draft'}}));
 await denied(createArtifactVersion({artifactId:id('Artifact'),contentSnapshot:{notes:'Unauthorized successor'},changeSummary:null}));
 await denied(addSharedComment({shareId:id('View'),content:'VIEW must not create Share comments'}));
 await expect(copySharedSnapshotToWorkspace({shareId:id('View'),destinationWorkspaceId:c.TeamB.workspaceId})).rejects.toMatchObject({code:'SHARED_SNAPSHOT_COPY_DEFERRED'});
 await denied(archiveArtifact(id('Artifact')));
 await denied(reopenApprovedArtifact({artifactId:id('Artifact')}));
 await denied(getArtifactVersion(id('V2')));
 // M13.16: a frozen V2 capability grants neither sibling reads nor history browsing.
 for(const label of ['V1','V3'])await denied(getArtifactVersion(id(label)));
 await denied(getArtifact(id('Artifact')));
 await denied(listArtifactVersions(id('Artifact')));
 expect(result('(select count(*) from public.artifact_versions where artifact_id='+literal(id('Artifact'))+'::uuid)')).toBe(0);
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
 for(const [table,target] of [['artifacts',id('Artifact')],['artifact_versions',id('V2')],['share_snapshots',id('Snapshot')],['shares',id('View')],['development_objects',id('ObjectSource')]]){
  for(const sql of ['update public.'+table+" set id=id where id="+literal(target)+' returning id','delete from public.'+table+' where id='+literal(target)+' returning id']){
   try{current('do $$declare n bigint;begin execute '+literal(sql)+';get diagnostics n=row_count;assert n=0;end$$');}catch(e){expect((e as {sqlstate?:string}).sqlstate).toBe('42501');}
  }
 }
 // No insert permission exists for source relationships, feedback or Snapshots.
 try{current("update public.shares set permission_level='COMMENT' where id="+literal(id('View')));throw Error('VIEW elevated permission');}catch(e){expect((e as {sqlstate?:string}).sqlstate).toBe('42501');}
 for(const table of ['artifact_object_links','feedback_items','share_snapshots','file_links','evidence_links']){
  try{current('insert into public.'+table+' default values');throw Error('Direct insert succeeded');}catch(e){expect((e as {sqlstate?:string}).sqlstate).toBe('42501');}
 }
 expect(history()).toBe(before);
 expect(await resolveSharedEntityAccess({shareId:id('View')})).toEqual(frozen);
 // Previously removed recipient, unrelated role-only actors and source IDs grant nothing.
 for(const user of ['00000000-0000-4000-8000-000000006007','00000000-0000-4000-8000-000000006001','00000000-0000-4000-8000-000000006003','00000000-0000-4000-8000-000000006008']){
  state.userId=user;expect((await resolveSharedEntityAccess({shareId:id('View')})).allowed).toBe(false);
 }
 state.userId='00000000-0000-4000-8000-000000006006';
 for(const guessed of [id('Snapshot'),id('Artifact'),id('V2')])expect((await resolveSharedEntityAccess({shareId:guessed})).allowed).toBe(false);
 query("begin;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);update public.shares set revoked_at=clock_timestamp(),revoked_by='00000000-0000-4000-8000-000000006004' where id="+literal(id('View'))+';commit;');
 expect((await resolveSharedEntityAccess({shareId:id('View')})).allowed).toBe(false);
},180000);
