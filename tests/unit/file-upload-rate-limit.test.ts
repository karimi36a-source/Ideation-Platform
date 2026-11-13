import {afterEach,beforeEach,expect,it,vi} from 'vitest';
vi.mock('server-only',()=>({}));
const m=vi.hoisted(()=>({actor:'',source:'203.0.113.7',auth:vi.fn(),rate:vi.fn(),rpc:vi.fn(),sign:vi.fn(),serial:1000,rows:new Map<string,unknown>()}));
vi.mock('next/headers',()=>({headers:async()=>new Headers(m.source?{'x-real-ip':m.source}:{})}));
vi.mock('@/lib/auth/authorization',async original=>({...await original<typeof import('@/lib/auth/authorization')>(),getAuthorizationContext:m.auth}));
vi.mock('@/lib/db/server',()=>({createServerSupabaseClient:async()=>({rpc:m.rpc})}));
vi.mock('@/lib/validation/env-server',()=>({getServerEnv:()=>({NEXT_PUBLIC_SUPABASE_URL:'https://example.test',SUPABASE_SECRET_KEY:'server-only-test-key'})}));
vi.mock('@supabase/supabase-js',()=>({createClient:()=>({rpc:m.rate,storage:{getBucket:async()=>({data:{public:false,file_size_limit:null},error:null}),from:()=>({createSignedUploadUrl:m.sign})}})}));
import {AuthorizationError} from '@/lib/auth/authorization';
import {requestUpload} from '@/features/files/upload';
import {FileUploadRateLimitError} from '@/features/files/upload-rate-limit';
const id=(n:number)=>`00000000-0000-4000-8000-${String(n).padStart(12,'0')}`;
const input={workspaceId:id(99),filename:'pilot.txt',mimeType:'text/plain',size:1};
const allow={data:{allowed:true,retryAfterSeconds:0},error:null};
const deny={data:{allowed:false,retryAfterSeconds:17},error:null};
beforeEach(()=>{
 vi.resetAllMocks();m.actor=id(6004);m.source='203.0.113.7';m.rows.clear();
 vi.stubEnv('FICI_UPLOAD_RATE_USER_LIMIT','60');vi.stubEnv('FICI_UPLOAD_RATE_SOURCE_LIMIT','300');vi.stubEnv('FICI_UPLOAD_RATE_WINDOW_SECONDS','60');vi.stubEnv('FICI_UPLOAD_RATE_IP_HEADER','x-real-ip');
 m.auth.mockImplementation(async()=>({userId:m.actor}));m.rate.mockResolvedValue(allow);
 m.rpc.mockImplementation(async(name:string,args:Record<string,unknown>)=>{
  if(name==='get_file_upload_request')return {data:m.rows.get(args.target_request as string),error:null};
  expect(name).toBe('request_file_upload');const key=id(++m.serial);
  const row={id:key,file_id:key,requested_by:m.actor,workspace_id:args.target_workspace,project_id:null,storage_reference:`workspaces/${args.target_workspace}/files/${key}`,filename:args.upload_filename,mime_type:args.upload_mime,expected_size:args.upload_size,created_at:new Date().toISOString(),expires_at:new Date(Date.now()+7200000).toISOString(),registered_at:null};
  m.rows.set(key,row);return {data:row,error:null};
 });
 m.sign.mockImplementation(async(path:string)=>({data:{path,token:'fixture-only',signedUrl:`https://example.test/${path}?token=fixture-only`},error:null}));
});
afterEach(()=>{vi.unstubAllEnvs();vi.useRealTimers();});
it('limits an authenticated concurrent burst before intent creation and signing',async()=>{
 m.rate.mockResolvedValue(deny);for(let n=0;n<4;n++)m.rate.mockResolvedValueOnce(allow);
 const outcomes=await Promise.allSettled(Array.from({length:64},()=>requestUpload(input)));
 expect(outcomes.filter(v=>v.status==='fulfilled')).toHaveLength(4);
 const rejected=outcomes.filter(v=>v.status==='rejected');expect(rejected).toHaveLength(60);
 for(const v of rejected)if(v.status==='rejected'){expect(v.reason).toBeInstanceOf(FileUploadRateLimitError);expect(v.reason).toMatchObject({code:'RATE_LIMIT',status:429,retryAfterSeconds:17,headers:{'Retry-After':'17'}});}
 expect(m.rpc.mock.calls.filter(([name])=>name==='request_file_upload')).toHaveLength(4);expect(m.sign).toHaveBeenCalledTimes(4);
 expect(m.rate.mock.invocationCallOrder[0]).toBeLessThan(m.rpc.mock.invocationCallOrder[0]);
});
it('shares the trusted source key across accounts without trusting caller identity/path overrides',async()=>{
 await requestUpload(input);m.actor=id(6005);m.rate.mockResolvedValueOnce(deny);
 await expect(requestUpload(input)).rejects.toMatchObject({code:'RATE_LIMIT'});
 const first=m.rate.mock.calls[0][1],second=m.rate.mock.calls[1][1];
 expect(first.target_actor).toBe(id(6004));expect(second.target_actor).toBe(id(6005));
 expect(second.target_source_hash).toBe(first.target_source_hash);expect(first.target_source_hash).toMatch(/^[a-f0-9]{64}$/);
 expect(JSON.stringify(m.rate.mock.calls)).not.toContain(m.source);expect(m.sign).toHaveBeenCalledTimes(1);
 m.source='203.0.113.8';await requestUpload(input);expect(m.rate.mock.calls[2][1].target_source_hash).not.toBe(first.target_source_hash);
});
it('honors canonical retry timing and admits a request after the DB window resets',async()=>{
 vi.useFakeTimers();m.rate.mockResolvedValueOnce(deny).mockResolvedValueOnce(allow);
 await expect(requestUpload(input)).rejects.toMatchObject({retryAfterSeconds:17,headers:{'Retry-After':'17'}});
 expect(m.rpc).not.toHaveBeenCalled();expect(m.sign).not.toHaveBeenCalled();
 vi.advanceTimersByTime(17000);await requestUpload(input);expect(m.sign).toHaveBeenCalledOnce();
});
it('allows ordinary pilot bursts under defaults and sends server configuration only',async()=>{
 await Promise.all(Array.from({length:24},()=>requestUpload(input)));expect(m.sign).toHaveBeenCalledTimes(24);
 expect(m.rate).toHaveBeenCalledWith('consume_file_upload_rate_limit',expect.objectContaining({user_limit:60,source_limit:300,window_seconds:60}));
 vi.stubEnv('FICI_UPLOAD_RATE_USER_LIMIT','12');vi.stubEnv('FICI_UPLOAD_RATE_SOURCE_LIMIT','80');vi.stubEnv('FICI_UPLOAD_RATE_WINDOW_SECONDS','120');
 await requestUpload(input);expect(m.rate).toHaveBeenLastCalledWith('consume_file_upload_rate_limit',expect.objectContaining({user_limit:12,source_limit:80,window_seconds:120}));
});
it('anonymous/invalid requests never reach admission, intent creation, or signing',async()=>{
 m.auth.mockRejectedValueOnce(new AuthorizationError('AUTH_REQUIRED'));await expect(requestUpload(input)).rejects.toMatchObject({code:'AUTH_REQUIRED'});
 await expect(requestUpload({...input,size:26_214_401})).rejects.toMatchObject({code:'VALIDATION_ERROR'});
 await expect(requestUpload({...input,sourceIp:'203.0.113.8'})).rejects.toMatchObject({code:'VALIDATION_ERROR'});
 expect(m.rate).not.toHaveBeenCalled();expect(m.rpc).not.toHaveBeenCalled();expect(m.sign).not.toHaveBeenCalled();
});
it.each(['', '0', '-1', 'not-a-number'])('invalid configuration %j fails closed',async value=>{
 vi.stubEnv('FICI_UPLOAD_RATE_USER_LIMIT',value);await expect(requestUpload(input)).rejects.toMatchObject({code:'NOT_FOUND'});expect(m.rate).not.toHaveBeenCalled();expect(m.rpc).not.toHaveBeenCalled();expect(m.sign).not.toHaveBeenCalled();
});
it.each(['','untrusted, 203.0.113.7'])('missing/invalid required trusted IP %j cannot bypass source protection',async source=>{
 m.source=source;await expect(requestUpload(input)).rejects.toMatchObject({code:'NOT_FOUND'});expect(m.rate).not.toHaveBeenCalled();expect(m.rpc).not.toHaveBeenCalled();expect(m.sign).not.toHaveBeenCalled();
});
it('retains user protection when no trustworthy source is configured',async()=>{
 vi.stubEnv('FICI_UPLOAD_RATE_IP_HEADER',undefined);await requestUpload(input);expect(m.rate.mock.calls[0][1].target_source_hash).toBeNull();
});
it('counter failure or malformed response fails closed without exposing diagnostics',async()=>{
 m.rate.mockResolvedValueOnce({data:null,error:{message:'private counter failure'}}).mockResolvedValueOnce({data:{allowed:true,retryAfterSeconds:2},error:null});
 for(let n=0;n<2;n++)await expect(requestUpload(input)).rejects.toMatchObject({code:'NOT_FOUND',message:'Resource unavailable.'});
 expect(m.rpc).not.toHaveBeenCalled();expect(m.sign).not.toHaveBeenCalled();
});
it('reauthorizes identity after admission and preserves scope denial before signing',async()=>{
 m.auth.mockResolvedValueOnce({userId:id(6004)}).mockResolvedValueOnce({userId:id(6005)});
 await expect(requestUpload(input)).rejects.toMatchObject({code:'NOT_FOUND'});expect(m.rpc).not.toHaveBeenCalled();
 m.rpc.mockResolvedValueOnce({data:null,error:{code:'42501'}});await expect(requestUpload(input)).rejects.toMatchObject({code:'NOT_FOUND'});expect(m.sign).not.toHaveBeenCalled();
});
