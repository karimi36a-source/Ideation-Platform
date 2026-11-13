import {afterEach,beforeEach,expect,it,vi} from 'vitest';
import {NextRequest,NextResponse} from 'next/server';
vi.mock('server-only',()=>({}));
const m=vi.hoisted(()=>({requestId:'',headers:vi.fn(),create:vi.fn(),updateSession:vi.fn()}));
vi.mock('next/headers',()=>({headers:m.headers}));
vi.mock('@/features/notifications/service',()=>({createNotification:m.create}));
vi.mock('@/lib/auth/proxy',()=>({updateSession:m.updateSession}));
import {observeDatabase,recordStructuredFailure,setLogContext,withOperationLog} from '@/lib/observability/structured-log';
import {recordLiveClassroomFailure} from '@/features/live-classroom/diagnostics';
import {DailyLiveClassroomProvider} from '@/features/live-classroom/providers/daily';
import {notifySubmissionReceived} from '@/features/notifications/submission';
import {proxy} from '@/proxy';
const id=(n:number)=>`00000000-0000-4000-8000-${String(n).padStart(12,'0')}`;
const secret='PRIVATE_API_KEY_PASSWORD_TOKEN';
const entries=()=>vi.mocked(console.warn).mock.calls.map(([line])=>JSON.parse(String(line)));
beforeEach(()=>{
 vi.resetAllMocks();vi.spyOn(console,'warn').mockImplementation(()=>{});m.requestId=id(1);
 m.headers.mockImplementation(async()=>new Headers({'x-fici-correlation-id':m.requestId}));
 m.create.mockRejectedValue(Error(secret+' private Evidence prompt https://private.test/?token=signed'));
});
afterEach(()=>vi.restoreAllMocks());
it('shares request ID across application, surfaced database, provider, and notification fallback events',async()=>{
 const provider=new DailyLiveClassroomProvider({apiKey:'daily-server-test-secret',timeoutMs:100},vi.fn().mockResolvedValue(new Response(secret,{status:503})));
 await withOperationLog('LIVE_ROOM',async()=>{
  setLogContext({actorId:id(2),cohortId:id(3),teamId:id(4),workspaceId:id(5),projectId:id(6)});
  await provider.getRoomStatus('fici-room');
  await observeDatabase('master_live_room_mapping',async()=>({data:null,error:{code:'XX000',message:secret}}));
  recordLiveClassroomFailure('MAPPING_SAVE','UNAVAILABLE');
  await notifySubmissionReceived(id(7));
 });
 const logs=entries();expect(logs.length).toBeGreaterThanOrEqual(5);
 for(const event of logs){
  expect(event).toMatchObject({correlationId:id(1),actorId:id(2),cohortId:id(3),teamId:id(4),workspaceId:id(5),projectId:id(6),level:'warn'});
  expect(event.timestamp).toMatch(/^\d{4}-\d\d-\d\dT/);expect(Number.isFinite(event.durationMs)).toBe(true);expect(event.durationMs).toBeGreaterThanOrEqual(0);
 }
 expect(logs).toContainEqual(expect.objectContaining({event:'LIVE_FAILURE',operation:'LIVE_PROVIDER',provider:'DAILY',task:'ROOM_LOOKUP',code:'UNAVAILABLE'}));
 expect(logs).toContainEqual(expect.objectContaining({event:'DATABASE_FAILURE',task:'master_live_room_mapping',provider:'SUPABASE',code:'DATABASE_UNAVAILABLE'}));
 expect(logs).toContainEqual(expect.objectContaining({event:'NOTIFICATION_FALLBACK',operation:'NOTIFICATION_SUBMISSION',entityId:id(7),code:'UNAVAILABLE'}));
 expect(JSON.stringify(logs)).not.toMatch(/PRIVATE_API|PASSWORD|signed|Evidence|prompt|https:|XX000/);
});
it('isolates simultaneous requests and preserves one ID through nested asynchronous work',async()=>{
 m.headers.mockResolvedValueOnce(new Headers({'x-fici-correlation-id':id(10)})).mockResolvedValueOnce(new Headers({'x-fici-correlation-id':id(20)}));
 await Promise.all([10,20].map(n=>withOperationLog('LIVE_ROOM',async()=>{
  setLogContext({actorId:id(n+1),projectId:id(n+2)});await Promise.resolve();
  await withOperationLog('LIVE_PROVIDER',async()=>{await Promise.resolve();recordLiveClassroomFailure('PROVIDER','TIMEOUT');});
 })));
 expect(entries()).toEqual(expect.arrayContaining([expect.objectContaining({correlationId:id(10),actorId:id(11),projectId:id(12)}),expect.objectContaining({correlationId:id(20),actorId:id(21),projectId:id(22)})]));
 expect(m.headers).toHaveBeenCalledTimes(2);
});
it('proxy overwrites forged correlation headers and forwards the generated request ID',async()=>{
 m.updateSession.mockImplementation(async(request:NextRequest)=>NextResponse.next({request}));
 const request=new NextRequest('https://fici.test/live-classroom/test',{headers:{'x-fici-correlation-id':id(999)}});
 const response=await proxy(request);const generated=request.headers.get('x-fici-correlation-id');
 expect(generated).toMatch(/^[a-f0-9-]{36}$/);expect(generated).not.toBe(id(999));
 expect(response.headers.get('x-middleware-request-x-fici-correlation-id')).toBe(generated);
});
it('drops hostile fields, raw errors, credentials, signed URLs and invalid identity fields',async()=>{
 await withOperationLog(secret,async()=>{
  setLogContext({actorId:secret,cohortId:'https://private.test',password:secret,apiKey:secret,token:secret,provider:secret,task:secret,prompt:secret});
  recordStructuredFailure('LIVE_FAILURE',{phase:secret,code:secret,actorId:secret,requestId:secret,authorization:secret,signedUrl:'https://private.test/?token='+secret,file:secret,evidence:secret,teamContent:secret,error:new Error(secret),durationMs:Infinity});
 });
 expect(entries()[0]).toMatchObject({operation:'UNKNOWN',code:'UNKNOWN',phase:'APPLICATION'});
 expect(Object.keys(entries()[0]).sort()).toEqual(['code','correlationId','durationMs','event','level','operation','phase','timestamp']);
 expect(JSON.stringify(entries())).not.toMatch(/PRIVATE|password|signedUrl|https:|stack|apiKey|prompt|evidence/);
});
it('background/no-request contexts get distinct generated IDs with no stale actor',async()=>{
 m.headers.mockRejectedValue(Error('No HTTP request'));
 for(let n=0;n<2;n++)await withOperationLog('NOTIFICATION_SUBMISSION',async()=>recordStructuredFailure('NOTIFICATION_FALLBACK',{code:'UNAVAILABLE'}));
 const [a,b]=entries();expect(a.correlationId).not.toBe(b.correlationId);expect(a.actorId).toBeUndefined();expect(b.actorId).toBeUndefined();
});
it('provider exception and fallback sink failures remain nonfatal and never change canonical state',async()=>{
 const domain={status:'APPROVED',version:id(50)},before=JSON.stringify(domain);
 const provider=new DailyLiveClassroomProvider({apiKey:'daily-server-test-secret',timeoutMs:100},vi.fn().mockRejectedValue(Error(secret)));
 await withOperationLog('LIVE_ROOM',async()=>{
  const outcome=await provider.getRoomStatus('fici-room');expect(outcome.success).toBe(false);
  expect(JSON.stringify(entries())).not.toContain(secret);
  vi.mocked(console.warn).mockImplementation(()=>{throw Error(secret);});
  await expect(notifySubmissionReceived(id(7))).resolves.toBeUndefined();
 });
 expect(JSON.stringify(domain)).toBe(before);
});
