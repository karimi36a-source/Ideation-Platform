import {spawnSync} from 'node:child_process';
import {join} from 'node:path';
import {expect,it,vi} from 'vitest';
vi.mock('server-only',()=>({}));
const state=vi.hoisted(()=>({userId:'00000000-0000-4000-8000-000000006004',signs:0,beforeSign:null as null|(()=>void)}));
vi.mock('@/lib/auth/authorization',async original=>({...await original<typeof import('@/lib/auth/authorization')>(),getAuthorizationContext:async()=>({userId:state.userId,assignments:[]})}));
vi.mock('@/lib/db/server',()=>({createServerSupabaseClient:async()=>({rpc,from:()=>fileQuery(false)})}));
vi.mock('@/lib/validation/env-server',()=>({getServerEnv:()=>({NEXT_PUBLIC_SUPABASE_URL:'https://storage.test',SUPABASE_SECRET_KEY:'server-test-only'})}));
// Provider signing is simulated; all authorization and File reads use real PostgreSQL.
vi.mock('@supabase/supabase-js',()=>({createClient:()=>({rpc:async(name:string,args:{target_file:string})=>{
 expect(name).toBe('get_file_signing_record');
 const text=query('begin;set local role service_role;select public.get_file_signing_record('+literal(args.target_file)+'::uuid)::text;commit;');
 return {data:JSON.parse(text.split(/\r?\n/).find(s=>s.startsWith('{'))!),error:null};
},storage:{getBucket:async()=>({data:{public:false},error:null}),from:()=>({createSignedUrl:async(path:string,ttl:number)=>{
 state.signs++;expect(ttl).toBe(60);state.beforeSign?.();return {data:{signedUrl:'https://storage.test/storage/v1/object/sign/fici-private-files/'+path+'?token=temporary-test-token'},error:null};
}})}})}));
import {getFileAccess} from '@/features/files/access';
import {resolveSharedEntityAccess} from '@/features/shares/access';
const actor=(n:number)=>'00000000-0000-4000-8000-'+String(n).padStart(12,'0');
const literal=(s:string)=>"'"+s.replaceAll("'","''")+"'";
function query(sql:string){
 const port=process.env.FICI_SHARED_FILES_TEST_PORT,bin=process.env.POSTGRES_BIN;if(!port||!/^\d+$/.test(port)||!bin)throw Error('Disposable shared File context required');
 const r=spawnSync(join(bin,process.platform==='win32'?'psql.exe':'psql'),['-X','-h','127.0.0.1','-p',port,'-U','postgres','-d','fici_shared_files','-v','ON_ERROR_STOP=1','-t','-A','-f','-'],{input:'\\set VERBOSITY verbose\n'+sql,encoding:'utf8',windowsHide:true,timeout:45000});
 if(r.error||r.status!==0)throw Object.assign(Error('Shared File SQL denied'),{sqlstate:r.stderr.match(/ERROR:\s+([A-Z0-9]{5}):/)?.[1]??'UNKNOWN',diagnostic:r.stderr});return r.stdout.trim();
}
function current(sql:string){return query("begin;set local role authenticated;select set_config('request.jwt.claim.sub',"+literal(state.userId)+',true);'+sql+';commit;');}
function result(sql:string,privileged=false){const text=(privileged?query:current)("select 'RESULT='||("+sql+')::text');const line=text.split(/\r?\n/).find(s=>s.startsWith('RESULT='));if(!line)throw Error('Missing result');return JSON.parse(line.slice(7));}
async function rpc(name:string,args:Record<string,unknown>){
 try{let expression:string;
  if(name==='authorize_shared_file_access')expression='to_jsonb(public.authorize_shared_file_access('+literal(String(args.target_file))+'::uuid))';
  else if(['resolve_shared_entity_access','add_share_comment'].includes(name))expression='public.'+name+'('+literal(JSON.stringify(args.input))+'::jsonb)';
  else throw Error('Unexpected RPC');
  return {data:result(expression),error:null};
 }catch(e){return {data:null,error:{code:(e as {sqlstate?:string}).sqlstate??'UNKNOWN'}};}
}
function fileQuery(privileged:boolean){let id='';const builder={select:()=>builder,eq:(key:string,value:string)=>{expect(key).toBe('id');id=value;return builder;},maybeSingle:async()=>{
 try{return {data:result('(select to_jsonb(f) from public.files f where id='+literal(id)+'::uuid)',privileged),error:null};}catch{return {data:null,error:{code:'42501'}};}
}};return builder;}
it('M13.15 canonical signing requires exact independent FILE authority and preserves storage/source privacy',async()=>{
 vi.unstubAllEnvs();
 const c=JSON.parse(query('select jsonb_object_agg(label,payload)::text from public.revoke_test_context'));
 const id=(label:string)=>c[label].id,fileId=id('File'),shareId=id('FileShare');
 const request=(entityType:string,entityId:string,permissionLevel='VIEW',destinationType='TEAM',destinationId=c.TeamB.teamId)=>literal(JSON.stringify({entityType,entityId,permissionLevel,destinationType,destinationId,shareMode:'SNAPSHOT'}))+'::jsonb';
 const ownerSQL=(sql:string)=>query("begin;select set_config('request.jwt.claim.sub',"+literal(actor(6004))+",true);"+sql+';commit;');
 const tables=['shares','share_snapshots','share_comments','audit_events','notifications','files','file_links','artifacts','artifact_versions','workspaces','teams','team_memberships','role_assignments'];
 const checksum=()=>query('select md5(jsonb_build_array('+tables.map(t=>"(select coalesce(jsonb_agg(to_jsonb(x) order by id),'[]'::jsonb) from public."+t+' x)').join(',')+')::text)');
 async function denied(value:unknown){const signs=state.signs;await expect(getFileAccess(value)).rejects.toMatchObject({code:expect.stringMatching(/NOT_FOUND|VALIDATION_ERROR/)});expect(state.signs).toBe(signs);}
 async function signed(){const before=checksum();const response=await getFileAccess({fileId});expect(response.expiresIn).toBe(60);expect(Date.parse(response.expiresAt)-Date.now()).toBeLessThanOrEqual(60000);expect(Object.keys(response).sort()).toEqual(['expiresAt','expiresIn','signedUrl']);expect(checksum()).toBe(before);return response;}
 // Existing direct M12 authority does not need any Share.
 await signed();
 ownerSQL('select public.link_file(jsonb_build_object(\'fileId\','+literal(fileId)+',\'entityType\',\'ARTIFACT\',\'entityId\','+literal(id('MainArtifact'))+',\'relationshipType\',\'ARTIFACT_FILE\'))');
 // Retain history but remove the explicit File grant. Non-FILE representations stay valid.
 ownerSQL('select public.revoke_share('+literal(JSON.stringify({shareId}))+'::jsonb)');
 state.userId=actor(6006);
 expect((await resolveSharedEntityAccess({shareId:id('MainShare')})).allowed).toBe(true);
 expect((await rpc('authorize_shared_file_access',{target_file:fileId})).data).toBe(false);
 await denied({fileId});
 // Other independently shared entity kinds confer no File capability either.
 state.userId=actor(6004);
 for(const [kind,source] of [['EVIDENCE',id('EvidenceSource')],['DEVELOPMENT_OBJECT',id('ObjectSource')],['SCAMPER_ENTRY',id('TeamScamper')],['PATENT_RECORD',id('TeamPatent')]]){
  const row=JSON.parse(ownerSQL('select public.share_entity('+request(kind,source)+')').split(/\r?\n/).find(s=>s.startsWith('{'))!);
  state.userId=actor(6006);expect((await resolveSharedEntityAccess({shareId:row.id})).allowed).toBe(true);await denied({fileId});state.userId=actor(6004);
 }
 const shares=JSON.parse(ownerSQL("select jsonb_build_object('view',public.share_entity("+request('FILE',fileId)+"),'comment',public.share_entity("+request('FILE',fileId,'COMMENT')+"),'master',public.share_entity("+request('FILE',fileId,'VIEW','MASTER',id('MasterAssignment'))+"))").split(/\r?\n/).find(s=>s.startsWith('{'))!);
 state.userId=actor(6006);await signed();
 const discussion=await rpc('add_share_comment',{input:{shareId:shares.comment.id,content:'File discussion only'}});
 expect(discussion.error).toBeNull();expect(discussion.data).toMatchObject({target_entity_type:'FILE',target_entity_id:fileId,target_version_id:null,author_user_id:actor(6006)});
 expect((await rpc('add_share_comment',{input:{shareId:shares.view.id,content:'VIEW forbidden'}})).error?.code).toBe('42501');
 const snapshot=await resolveSharedEntityAccess({shareId:shares.view.id});expect(JSON.stringify(snapshot)).not.toMatch(/storage_reference|workspaces\/|temporary-test-token/);
 // Neither raw tables nor Storage traversal become readable under recipient JWT.
 expect(result("(select count(*) from public.files where workspace_id="+literal(c.File.workspace_id)+"::uuid)")).toBe(0);
 expect(result("(select count(*) from storage.objects where name="+literal(c.File.storage_reference)+")")).toBe(0);
 for(const key of ['storageReference','storagePath','shareId','expiresIn','expiry','workspaceId'])await denied({fileId,[key]:c.File.storage_reference});
 for(const guessed of [id('SiblingFile'),actor(9999),id('MainArtifact'),id('MainVersion'),shares.view.id])await denied({fileId:guessed});
 for(const table of ['files','file_links','share_snapshots']){
  try{current('insert into public.'+table+' default values');throw Error('Mutation succeeded');}catch(e){expect((e as {sqlstate?:string}).sqlstate).toBe('42501');}
 }
 const mutationBefore=checksum();
 for(const sql of ['update public.files set filename=\'overwrite.txt\' where id='+literal(fileId),'delete from storage.objects where name='+literal(c.File.storage_reference),'select public.archive_file('+literal(fileId)+'::uuid)']){
  if(sql.startsWith('select')){
   try{current(sql);throw Error('Mutation succeeded');}catch(e){expect((e as {sqlstate?:string}).sqlstate).toBe('42501');}
  }else{
   try{current('do $$declare n bigint;begin execute '+literal(sql)+';get diagnostics n=row_count;assert n=0;end$$');}catch(e){expect((e as {sqlstate?:string}).sqlstate).toBe('42501');}
  }
 }
 expect(checksum()).toBe(mutationBefore);
 ownerSQL('select public.revoke_share('+literal(JSON.stringify({shareId:shares.view.id}))+'::jsonb)');
 await signed(); // Independent COMMENT FILE Share still authorizes read only.

 query("begin;select set_config('request.jwt.claim.sub',"+literal(actor(6002))+",true);select public.remove_team_member("+literal(c.TeamB.teamId)+','+literal(actor(6006))+",'M13.15 removed recipient');commit;");
 await denied({fileId});expect((await resolveSharedEntityAccess({shareId:shares.comment.id})).allowed).toBe(false);
 query("begin;select set_config('request.jwt.claim.sub',"+literal(actor(6002))+",true);select public.add_team_member("+literal(c.TeamB.teamId)+','+literal(actor(6006))+",'member');commit;");
 await signed();
 ownerSQL('select public.archive_file('+literal(fileId)+'::uuid)');await signed();
 try{current('select public.link_file('+literal(JSON.stringify({fileId,entityType:'ARTIFACT',entityId:id('MainArtifact'),relationshipType:'ARTIFACT_FILE'}))+'::jsonb)');throw Error('Archived link succeeded');}catch(e){expect((e as {sqlstate?:string}).sqlstate).toBe('42501');}
 // Mid-sign revocation is observed by the canonical service recheck.
 state.beforeSign=()=>{state.beforeSign=null;ownerSQL('select public.revoke_share('+literal(JSON.stringify({shareId:shares.comment.id}))+'::jsonb)');};
 await expect(getFileAccess({fileId})).rejects.toMatchObject({code:'NOT_FOUND'});
 await denied({fileId});expect((await resolveSharedEntityAccess({shareId:shares.comment.id})).allowed).toBe(false);
 expect(query('select count(*) from public.files where id='+literal(fileId))).toBe('1');
 state.userId=actor(6002);await signed();
 query('update public.role_assignments set ends_at=clock_timestamp()-interval \'1 second\' where id='+literal(id('MasterAssignment')));await denied({fileId});
 query("update public.role_assignments set ends_at=null,status='inactive' where id="+literal(id('MasterAssignment')));await denied({fileId});
 query("update public.role_assignments set status='active' where id="+literal(id('MasterAssignment')));
 for(const n of [6001,6003,6008]){state.userId=actor(n);await denied({fileId});}
 expect(query("select has_table_privilege('service_role','public.files','SELECT')")).toBe('f');
 for(const role of ['anon','authenticated'])expect(query('select has_function_privilege('+literal(role)+",'public.get_file_signing_record(uuid)','EXECUTE')")).toBe('f');
 try{current('select public.get_file_signing_record('+literal(fileId)+'::uuid)');throw Error('Private signing record exposed');}catch(e){expect((e as {sqlstate?:string}).sqlstate).toBe('42501');}
 for(const role of ['anon','service_role'])expect(query('select has_function_privilege('+literal(role)+",'public.authorize_shared_file_access(uuid)','EXECUTE')")).toBe('f');
 // Permanent URL/token never appears in persisted sharing or File records.
 const persisted=query("select jsonb_build_array((select jsonb_agg(to_jsonb(s)) from public.shares s),(select jsonb_agg(to_jsonb(s)) from public.share_snapshots s),(select jsonb_agg(to_jsonb(s)) from public.share_comments s),(select jsonb_agg(to_jsonb(s)) from public.audit_events s))::text");
 expect(persisted).not.toMatch(/storage\.test|temporary-test-token|signedUrl/);
},180000);
