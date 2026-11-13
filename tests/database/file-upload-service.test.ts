import {spawn} from "node:child_process";
import {join} from "node:path";
import {existsSync} from "node:fs";
import {expect,it,vi} from "vitest";
import {createClient} from "@supabase/supabase-js";
vi.mock("server-only",()=>({}));
// These existing M12 tests isolate storage behavior; admission is exercised by
// file-upload-rate-limit.test.ts and the real DB rate-limit acceptance scenario.
vi.mock('@/features/files/upload-rate-limit',()=>({enforceFileUploadRateLimit:vi.fn().mockResolvedValue(undefined),FileUploadRateLimitError:class extends Error{}}));
const state=vi.hoisted(()=>({userId:"00000000-0000-4000-8000-000000006004",provider:false}));
vi.mock("@/lib/auth/authorization",async original=>({...await original<typeof import("@/lib/auth/authorization")>(),getAuthorizationContext:async()=>({userId:state.userId})}));
vi.mock("@/lib/validation/env-server",()=>({getServerEnv:()=>({NEXT_PUBLIC_SUPABASE_URL:process.env.FICI_STORAGE_TEST_URL,SUPABASE_SECRET_KEY:process.env.FICI_STORAGE_TEST_SERVICE_ROLE_KEY})}));
vi.mock("@/lib/db/server",()=>({createServerSupabaseClient:async()=>({from:(table:string)=>({select:()=>({eq:(_key:string,id:string)=>({maybeSingle:async()=>{
 if(table!=='files')throw Error('Unexpected table');
 try{const text=await query(`begin;set local role authenticated;select set_config('request.jwt.claim.sub',${literal(state.userId)},true);select 'RESULT='||to_jsonb(f)::text from public.files f where id=${literal(id)};commit;`);const row=text.split(/\r?\n/).find(x=>x.startsWith('RESULT='));return {data:row?JSON.parse(row.slice(7)):null,error:null};}catch{return {data:null,error:{code:'42501'}};}
 }})})}),rpc:async(name:string,args:Record<string,unknown>)=>{
 const signatures:Record<string,string[]>={request_file_upload:["target_workspace","target_project","upload_filename","upload_mime","upload_size"],get_file_upload_request:["target_request"],register_uploaded_file:["target_request"],link_file:['input'],archive_file:['target_file']};
 if(!signatures[name])throw Error("Unexpected test RPC");
 try{const text=await query(`begin;set local role authenticated;select set_config('request.jwt.claim.sub',${literal(state.userId)},true);select 'RESULT='||public.${name}(${signatures[name].map(k=>literal(k==='input'?JSON.stringify(args[k]):args[k])).join(',')})::text;commit;`);const row=text.split(/\r?\n/).find(x=>x.startsWith('RESULT='));return {data:row?JSON.parse(row.slice(7)):null,error:null};}
 catch{return {data:null,error:{code:"42501"}};}
 }})}));
import {requestUpload,registerUploadedFile} from "@/features/files/upload";
import {getFileAccess} from "@/features/files/access";
import {linkFile} from "@/features/files/link";
import {archiveFile} from "@/features/files/archive";
function literal(v:unknown){return v==null?'null':`'${String(v).replaceAll("'","''")}'`;}
function query(sql:string):Promise<string>{return new Promise((resolve,reject)=>{
 const port=process.env.FICI_FILE_TEST_PORT;if(!port||!/^\d+$/.test(port)||!process.env.POSTGRES_BIN)return reject(Error("Disposable context missing"));
 const p=spawn(join(process.env.POSTGRES_BIN,process.platform==='win32'?'psql.exe':'psql'),['-X','-h','127.0.0.1','-p',port,'-U','postgres','-d','fici_file_upload_service','-v','ON_ERROR_STOP=1','-t','-A','-f','-'],{windowsHide:true});let out='';p.stdout.on('data',d=>out+=d);p.stderr.resume();p.on('error',reject);p.on('close',code=>code===0?resolve(out.trim()):reject(Error('Disposable SQL rejected')));p.stdin.end(sql);
});}
it("M12.7 public services: real signed upload + metadata bridge + registration/attacks/concurrency/rollback",async()=>{
 // No hosted migrations: the application RPC transport is the fresh local DB.
 // Only test setup mirrors provider-returned metadata into its provider fixture.
 if(!process.env.FICI_FILE_PROVIDER)throw Error("Explicit non-production provider verification required");
 if(existsSync('.env.test.local'))process.loadEnvFile('.env.test.local');
 if(new URL(process.env.FICI_STORAGE_TEST_URL!).origin!=='https://vbrnfkjzkqlidlsyuusy.supabase.co')throw Error("Unapproved provider");
 const admin=createClient(process.env.FICI_STORAGE_TEST_URL!,process.env.FICI_STORAGE_TEST_SERVICE_ROLE_KEY!,{auth:{persistSession:false,autoRefreshToken:false}});
 const client=createClient(process.env.FICI_STORAGE_TEST_URL!,process.env.FICI_STORAGE_TEST_ANON_KEY!,{auth:{persistSession:false,autoRefreshToken:false}});
 const bucket='fici-private-files';const paths:string[]=[];let teamFileId='';let issuedTeamUrl='';const initialTtl=process.env.FICI_FILE_ACCESS_TTL_SECONDS;delete process.env.FICI_FILE_ACCESS_TTL_SECONDS;
 const contexts=JSON.parse(await query("select jsonb_object_agg(label,payload)::text from public.file_service_context"));
 const create=async(label:string)=>{const p=contexts[label];const r=await requestUpload({workspaceId:p.primary_workspace_id,projectId:p.id,filename:'privacy.txt',mimeType:'text/plain',size:3});paths.push(r.path);return r;};
 const upload=async(r:Awaited<ReturnType<typeof requestUpload>>,size=3,mime='text/plain')=>{
 const sibling=r.path+'-foreign';paths.push(sibling);
 const wrongPath=await client.storage.from(bucket).uploadToSignedUrl(sibling,r.token,Buffer.from('BAD'),{contentType:mime});expect(!!wrongPath.error).toBe(true);
 const u=await client.storage.from(bucket).uploadToSignedUrl(r.path,r.token,Buffer.alloc(size,65),{contentType:mime,upsert:false});expect(!!u.error).toBe(false);
 const info=await admin.storage.from(bucket).info(r.path);expect(!!info.error).toBe(false);expect(info.data).toBeTruthy();
 // Metadata originates from real provider; bridge is trusted fixture setup only.
 const metadata={size:info.data!.size,mimetype:info.data!.contentType};
 await query(`insert into storage.objects(bucket_id,name,metadata) values('fici-private-files',${literal(r.path)},${literal(JSON.stringify(metadata))}::jsonb)`);
 };
 try{
 for(const label of ['Individual','Team']){const r=await create(label);expect(r.path).toMatch(/^workspaces\/[a-f0-9-]+\/files\/[a-f0-9-]+$/);expect(r.path).not.toContain('privacy.txt');await expect(registerUploadedFile({uploadRequestId:r.uploadRequestId})).rejects.toMatchObject({code:'NOT_FOUND'});await upload(r);
 const [a,b]=await Promise.all([registerUploadedFile({uploadRequestId:r.uploadRequestId}),registerUploadedFile({uploadRequestId:r.uploadRequestId})]);expect(a).toEqual(b);expect(a.uploaded_by).toBe(state.userId);expect(a.size).toBe(3);expect(Number(await query(`select count(*) from public.files where id=${literal(a.id)}`))).toBe(1);
 const before=await query(`select to_jsonb(f)::text from public.files f where id=${literal(a.id)}`);
 const access=await getFileAccess({fileId:a.id});expect(access.expiresIn).toBe(60);expect(Object.keys(access).sort()).toEqual(['expiresAt','expiresIn','signedUrl']);
 const response=await fetch(access.signedUrl,{signal:AbortSignal.timeout(15000),cache:'no-store'});expect(response.ok).toBe(true);expect((await response.arrayBuffer()).byteLength).toBe(3);
 for(const n of [6001,6002,6003,6006,6008]){state.userId=`00000000-0000-4000-8000-${String(n).padStart(12,'0')}`;await expect(getFileAccess({fileId:a.id})).rejects.toMatchObject({code:'NOT_FOUND'});await expect(archiveFile(a.id)).rejects.toMatchObject({code:'NOT_FOUND'});}state.userId='00000000-0000-4000-8000-000000006004';
 await expect(getFileAccess({fileId:'00000000-0000-4000-8000-999999999999'})).rejects.toMatchObject({code:'NOT_FOUND'});
 await expect(getFileAccess({fileId:a.id,expiry:300})).rejects.toMatchObject({code:'VALIDATION_ERROR'});
 if(label==='Team'){teamFileId=a.id;issuedTeamUrl=access.signedUrl;}
 if(label==='Individual'){
  state.userId='00000000-0000-4000-8000-000000006005';await expect(getFileAccess({fileId:a.id})).rejects.toMatchObject({code:'NOT_FOUND'});await expect(archiveFile(a.id)).rejects.toMatchObject({code:'NOT_FOUND'});state.userId='00000000-0000-4000-8000-000000006004';
  process.env.FICI_FILE_ACCESS_TTL_SECONDS='2';const short=await getFileAccess({fileId:a.id});expect(short.expiresIn).toBe(2);
  expect((await fetch(short.signedUrl,{cache:'no-store',signal:AbortSignal.timeout(15000)})).ok).toBe(true);
  await new Promise(resolve=>setTimeout(resolve,4000));
  expect((await fetch(short.signedUrl,{cache:'no-store',signal:AbortSignal.timeout(15000)})).ok).toBe(false);delete process.env.FICI_FILE_ACCESS_TTL_SECONDS;
  console.log('AT-FILE-003 actual provider URL works then expires; no URL persisted PASS');
 }
 expect(await query(`select to_jsonb(f)::text from public.files f where id=${literal(a.id)}`)).toBe(before);
 if(label==='Individual'){
  const [archived,retry]=await Promise.all([archiveFile(a.id),archiveFile(a.id)]);expect(retry).toEqual(archived);expect(archived.status).toBe('archived');expect(archived.storage_reference).toBe(a.storage_reference);
  expect((await fetch((await getFileAccess({fileId:a.id})).signedUrl,{cache:'no-store',signal:AbortSignal.timeout(15000)})).ok).toBe(true);expect(Number(await query(`select count(*) from public.files where id=${literal(a.id)}`))).toBe(1);
  expect(!!(await admin.storage.from(bucket).info(a.storage_reference)).error).toBe(false);
 }
 const raw=await fetch(`${process.env.FICI_STORAGE_TEST_URL}/storage/v1/object/public/${bucket}/${r.path}`,{signal:AbortSignal.timeout(15000)});expect(raw.ok).toBe(false);
 const replay=await client.storage.from(bucket).uploadToSignedUrl(r.path,r.token,Buffer.from('BAD'),{contentType:'text/plain',upsert:true});expect(!!replay.error).toBe(true);
 state.userId='00000000-0000-4000-8000-000000006006';await expect(registerUploadedFile({uploadRequestId:r.uploadRequestId})).rejects.toMatchObject({code:'NOT_FOUND'});state.userId='00000000-0000-4000-8000-000000006004';
 }
 for(const [size,mime] of [[2,'text/plain'],[3,'text/html']] as const){const r=await create('Team');await upload(r,size,mime);await expect(registerUploadedFile({uploadRequestId:r.uploadRequestId})).rejects.toMatchObject({code:'NOT_FOUND'});expect(Number(await query(`select count(*) from public.files where storage_reference=${literal(r.path)}`))).toBe(0);}
 for(const n of [6001,6002,6003,6006,6008]){state.userId=`00000000-0000-4000-8000-${String(n).padStart(12,'0')}`;await expect(create('Team')).rejects.toMatchObject({code:'NOT_FOUND'});}state.userId='00000000-0000-4000-8000-000000006004';
 // A canonical Chat attachment is not an ACL: retain Team/Chat access but close
 // A2's Project participation, independently removing access to its File.
 const message=JSON.parse((await query(`begin;set local role authenticated;select set_config('request.jwt.claim.sub',${literal(state.userId)},true);select 'RESULT='||public.send_team_chat_message(${literal(contexts.TeamId.id)},'Disposable attachment target',null)::text;commit;`)).split(/\r?\n/).find(v=>v.startsWith('RESULT='))!.slice(7));
 await linkFile({fileId:teamFileId,entityType:'CHAT_MESSAGE',entityId:message.id,relationshipType:'CHAT_ATTACHMENT'});
 const teamBefore=JSON.parse(await query(`select to_jsonb(f)::text from public.files f where id=${literal(teamFileId)}`));
 const linksBefore=await query(`select jsonb_agg(to_jsonb(l) order by id)::text from public.file_links l where file_id=${literal(teamFileId)}`);
 const archivedTeam=await archiveFile(teamFileId);expect(await archiveFile(teamFileId)).toEqual(archivedTeam);
 for(const key of ['id','storage_reference','uploaded_by','workspace_id','project_id','filename','mime_type','size','created_at'] as const)expect(archivedTeam[key]).toEqual(teamBefore[key]);
 expect(await query(`select jsonb_agg(to_jsonb(l) order by id)::text from public.file_links l where file_id=${literal(teamFileId)}`)).toBe(linksBefore);
 await expect(linkFile({fileId:teamFileId,entityType:'CHAT_MESSAGE',entityId:message.id,relationshipType:'CHAT_ATTACHMENT'})).rejects.toMatchObject({code:'NOT_FOUND'});
 expect((await fetch((await getFileAccess({fileId:teamFileId})).signedUrl,{cache:'no-store',signal:AbortSignal.timeout(15000)})).ok).toBe(true);
 expect(!!(await admin.storage.from(bucket).info(archivedTeam.storage_reference)).error).toBe(false);
 expect((await fetch(`${process.env.FICI_STORAGE_TEST_URL}/storage/v1/object/public/${bucket}/${archivedTeam.storage_reference}`,{signal:AbortSignal.timeout(15000)})).ok).toBe(false);
 await query(`begin;select set_config('request.jwt.claim.sub',${literal(state.userId)},true);update public.project_memberships set status='inactive',ends_at=statement_timestamp() where project_id=${literal(contexts.Team.id)} and user_id='00000000-0000-4000-8000-000000006005' and status='active';commit;`);
 state.userId='00000000-0000-4000-8000-000000006005';
 expect((await query(`begin;set local role authenticated;select set_config('request.jwt.claim.sub',${literal(state.userId)},true);select 'COUNT='||count(*) from public.chat_messages where id=${literal(message.id)};commit;`))).toContain('COUNT=1');
 await expect(getFileAccess({fileId:teamFileId})).rejects.toMatchObject({code:'NOT_FOUND'});state.userId='00000000-0000-4000-8000-000000006004';
 console.log('M12.9 readable linked Chat target does not grant File access PASS');
 const pending=await create('Team');await upload(pending);issuedTeamUrl=(await getFileAccess({fileId:teamFileId})).signedUrl;await query(`begin;set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);select public.remove_team_member(${literal(contexts.TeamId.id)},${literal(state.userId)},null);commit;`);
 await expect(getFileAccess({fileId:teamFileId})).rejects.toMatchObject({code:'NOT_FOUND'});expect((await fetch(issuedTeamUrl,{cache:'no-store',signal:AbortSignal.timeout(15000)})).ok).toBe(true);console.log('M12.9 removal denies new signing; issued URL remains usable until expiry PASS');
 await expect(archiveFile(teamFileId)).rejects.toMatchObject({code:'NOT_FOUND'});
 await expect(registerUploadedFile({uploadRequestId:pending.uploadRequestId})).rejects.toMatchObject({code:'NOT_FOUND'});await expect(create('Team')).rejects.toMatchObject({code:'NOT_FOUND'});expect(Number(await query(`select count(*) from public.files where storage_reference=${literal(pending.path)}`))).toBe(0);
 const personal=await create('Individual');expect(personal.uploadRequestId).toBeTruthy();
 console.log('AT-FILE-001/002 Personal/Team signed downloads, peer/TeamB/role-only/removal denials PASS');
 console.log('M12.7 real provider signed capability/upload/no-upsert + exact metadata + Personal/Team registration + concurrent idempotency + TeamB/role-only/removal + raw privacy PASS');
 }finally{if(initialTtl===undefined)delete process.env.FICI_FILE_ACCESS_TTL_SECONDS;else process.env.FICI_FILE_ACCESS_TTL_SECONDS=initialTtl;if(paths.length){const c=await admin.storage.from(bucket).remove(paths);if(c.error)throw Error('Provider cleanup failed');for(const p of paths){const d=await admin.storage.from(bucket).info(p);if(!d.error&&d.data)throw Error('Provider cleanup absence check failed');}}}
},150000);
