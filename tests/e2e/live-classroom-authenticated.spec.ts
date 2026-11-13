import {expect,test,type Page,type Request,type BrowserContext} from '@playwright/test';
import {execFileSync} from 'node:child_process';

test.use({trace:'off',screenshot:'off',video:'off'});
test.describe.configure({mode:'serial',retries:0});
const container=process.env.FICI_M1619_CONTAINER,docker=process.env.FICI_M1619_DOCKER,password=process.env.FICI_M1619_PASSWORD;
if(process.env.FICI_M1619_ISOLATED!=='1'||!/^fici-m1619-[a-f0-9-]+-db$/.test(container||'')||!docker||!password)throw Error('Use the isolated M16.19 runner; no hosted database accepted');
function sql(statement:string){return execFileSync(docker!,['exec','-i','--env','PGOPTIONS=-c statement_timeout=50000',container!,'psql','-X','-U','postgres','-d','postgres','-v','ON_ERROR_STOP=1','-qAt','-f','-'],{input:statement,encoding:'utf8',windowsHide:true}).trim();}
const fixture=(key:string)=>JSON.parse(sql(`select value::text from public.mind_map_browser_fixture where key='${key}'`));
const quote=(value:string)=>"'"+value.replaceAll("'","''")+"'";
/** SSR visibility does not imply hydration. Observe the installed React DOM
 * event binding, then click normally; never invoke the handler directly. */
async function clickClassroomControl(page:Page,name:string){
 const button=page.getByRole('button',{name,exact:true});
 await expect(button).toBeVisible({timeout:5000});
 await expect(button).toBeEnabled({timeout:5000});
 await expect.poll(()=>button.evaluate(element=>{
  const key=Object.keys(element).find(key=>key.startsWith('__reactProps$'));
  const props:unknown=key?Reflect.get(element,key):null;
  return !!props&&typeof props==='object'&&typeof Reflect.get(props,'onClick')==='function';
 }),{timeout:15000,message:'Live Classroom '+name+' must have a hydrated React onClick binding'}).toBe(true);
 await button.click({timeout:5000});
}
async function joinMasterBreakout(page:Page){
 const endpoint='/api/live-classroom/breakout-join';
 let started=false,status:number|null=null;
 const matches=(request:Request)=>new URL(request.url()).pathname===endpoint&&request.method()==='POST';
 const onRequest=(request:Request)=>{if(matches(request))started=true;};
 page.on('request',onRequest);
 try{
  const responseWait=page.waitForResponse(response=>matches(response.request()),{timeout:20000}).then(response=>response,()=>null);
  await clickClassroomControl(page,'Join classroom');
  const response=await responseWait;status=response?.status()??null;
  expect(started,'Master breakout POST must be emitted').toBe(true);
  expect(response,'Master breakout response must arrive within 20 seconds').not.toBeNull();
  expect(status).toBe(200);
 }finally{page.off('request',onRequest);}
}
async function login(page:Page,n:number){await page.goto('/login');await page.getByLabel('Email',{exact:true}).fill(`team-acceptance-${n}@example.test`);await page.getByLabel('Password',{exact:true}).fill(password!);await page.getByRole('button',{name:'Sign in',exact:true}).click();await expect(page).toHaveURL(/\/account$/);}
async function media(page:Page){
 await page.route('https://m1619.daily.co/**',route=>route.fulfill({contentType:'text/html',body:'<!doctype html><html><body><h1>Isolated Daily media</h1></body></html>'}));
 await page.route('**/api/v1/mind-map/collaboration-auth',route=>route.fulfill({status:503,body:'{}'}));
}
const snapshot=()=>sql(`select jsonb_build_object('activities',(select jsonb_agg(to_jsonb(x) order by id) from public.activity_instances x),'projects',(select jsonb_agg(to_jsonb(x) order by id) from public.development_projects x),'teams',(select jsonb_agg(to_jsonb(x) order by id) from public.teams x),'artifacts',(select jsonb_agg(to_jsonb(x) order by id) from public.artifacts x),'versions',(select jsonb_agg(to_jsonb(x) order by id) from public.artifact_versions x),'nodes',(select jsonb_agg(to_jsonb(x) order by id) from public.mind_map_nodes x),'edges',(select jsonb_agg(to_jsonb(x) order by id) from public.mind_map_edges x),'chat',(select jsonb_agg(to_jsonb(x) order by id) from public.chat_messages x),'channels',(select jsonb_agg(to_jsonb(x) order by id) from public.chat_channels x))::text;`);
async function closeBrowserContexts(contexts:BrowserContext[]){
 let timer:ReturnType<typeof setTimeout>|undefined;
 try{
  const results=await Promise.race([
   Promise.allSettled(contexts.map(async context=>{
    await Promise.allSettled(context.pages().map(page=>page.unrouteAll({behavior:'ignoreErrors'})));
    await context.unrouteAll({behavior:'ignoreErrors'});
    await context.close({reason:'M16.19 test teardown'});
   })),
   new Promise<null>(resolve=>{timer=setTimeout(()=>resolve(null),15000);}),
  ]);
  const ok=results!==null&&results.every(result=>result.status==='fulfilled');
  console.log('M16.19 browser-context cleanup '+(ok?'PASS':'WARN')+(results===null?' (15-second bound exceeded)':''));
  return ok;
 }finally{clearTimeout(timer);}
}

test('M16.19 real-auth Cohort UI → room → Student media → canonical work → refresh/rejoin',async({browser})=>{
 const scope=fixture('scope'),activity=fixture('activity').activity.id as string,component=fixture('node_component');
 const masterContext=await browser.newContext(),studentContext=await browser.newContext(),otherContext=await browser.newContext(),a2Context=await browser.newContext(),b1Context=await browser.newContext();
 try{
  const master=await masterContext.newPage(),student=await studentContext.newPage(),other=await otherContext.newPage();
  await media(master);await media(student);await login(master,6002);
  const beforeOpen=snapshot();await master.goto(`/cohorts/${scope.cohortId}/overview`);
  await master.getByRole('link',{name:'Open live classroom — Test only',exact:true}).click();
  await master.getByRole('button',{name:'Open live classroom',exact:true}).click();await expect(master).toHaveURL(/\/live-classroom\/[a-f0-9-]+$/);
  const roomId=new URL(master.url()).pathname.split('/').pop()!;
  expect(sql(`select count(*) from public.live_session_rooms where cohort_id=${quote(scope.cohortId)} and session_definition_id=${quote(scope.sessionId)} and status='ACTIVE'`)).toBe('1');
  expect(snapshot()).toBe(beforeOpen);
  const masterJoin=master.waitForResponse(r=>r.url().endsWith('/api/live-classroom/join')&&r.request().method()==='POST');await clickClassroomControl(master,'Join classroom');
  const masterCapability=await (await masterJoin).json();expect(Object.keys(masterCapability).sort()).toEqual(['expiresAt','token','url']);expect(masterCapability.token).toMatch(/^m1619\./);expect(JSON.stringify(masterCapability)).not.toContain('m1619-test-management-canary');
  await expect(master.frameLocator('iframe').getByRole('heading',{name:'Isolated Daily media'})).toBeVisible();
  await master.getByRole('link',{name:'Team breakouts',exact:true}).click();await master.getByRole('button',{name:'Open breakout: Team A',exact:true}).click();await expect(master).toHaveURL(/\/breakouts\/[a-f0-9-]+$/);const breakoutId=new URL(master.url()).pathname.split('/').pop()!;
  await joinMasterBreakout(master);
  await expect(master.frameLocator('iframe').getByRole('heading',{name:'Isolated Daily media'})).toBeVisible();
  await login(student,6004);const classroom=`/live-classroom/${roomId}?activityInstanceId=${activity}`;await student.goto(classroom);
  await expect(student.getByRole('heading',{name:'Browser Team Mind Map',exact:true})).toBeVisible();
  const join=student.waitForResponse(r=>r.url().endsWith('/api/live-classroom/join')&&r.request().method()==='POST');await clickClassroomControl(student,'Join classroom');const first=await (await join).json();
  expect(first.expiresAt).toBeGreaterThan(Date.now()/1000);expect(first.expiresAt).toBeLessThanOrEqual(Date.now()/1000+61);
  await expect(student.frameLocator('iframe').getByRole('heading',{name:'Isolated Daily media'})).toBeVisible();expect(snapshot()).toBe(beforeOpen);
  await student.getByRole('link',{name:'Open My Team',exact:true}).click();await expect(student).toHaveURL(new RegExp(`/teams/${scope.teamId}$`));await expect(student.getByRole('heading',{name:'Team A — Team Portal',exact:true})).toBeVisible();await expect(student.getByRole('heading',{name:'Team Project',exact:true})).toBeVisible();
  await student.getByRole('link',{name:'Open Activity: Browser Team Mind Map',exact:true}).click();await expect(student).toHaveURL(new RegExp(`/activities/${activity}/mind-map$`));
  await expect(student.getByText('Editable draft',{exact:true})).toBeVisible();
  const componentNode=student.getByTestId(`rf__node-${component.id}`);
  await expect(componentNode).toBeVisible();
  await expect.poll(()=>componentNode.evaluate(element=>{
   const key=Object.keys(element).find(key=>key.startsWith('__reactProps$'));
   const props:unknown=key?Reflect.get(element,key):null;
   return !!props&&typeof props==='object'&&typeof Reflect.get(props,'onClick')==='function';
  }),{timeout:15000,message:'Mind Map node must have a hydrated React click binding'}).toBe(true);
  await componentNode.click();
  const inspector=student.locator('aside').filter({has:student.getByRole('heading',{name:component.label,exact:true})});
  await expect(inspector).toBeVisible();
  await expect(inspector.getByRole('heading',{name:component.label,exact:true})).toBeVisible();
  await expect(inspector.getByLabel('Visual label',{exact:true})).toBeEditable();
  const label='M16.19 explicit persisted learner edit';await inspector.getByLabel('Visual label',{exact:true}).fill(label);await inspector.getByRole('button',{name:'Save label',exact:true}).click();
  await expect.poll(()=>sql(`select label from public.mind_map_nodes where id=${quote(component.id)}`)).toBe(label);
  const afterEdit=snapshot();expect(afterEdit).not.toBe(beforeOpen);
  // Distinct real sessions: A2 and Team B B1 are enrolled in the same Cohort.
  // A Cohort media token must not grant B1 access to Team A's work.
  for(const [context,n] of [[a2Context,6005],[b1Context,6006]] as const){const page=await context.newPage();await media(page);await login(page,n);await page.goto(`/live-classroom/${roomId}`);const response=page.waitForResponse(r=>r.url().endsWith('/api/live-classroom/join'));await clickClassroomControl(page,'Join classroom');expect((await response).status()).toBe(200);await expect(page.frameLocator('iframe').getByRole('heading',{name:'Isolated Daily media'})).toBeVisible();if(n===6006){expect((await page.goto(`/activities/${activity}/mind-map`))?.status()).toBe(404);expect((await page.goto(`/teams/${scope.teamId}`))?.status()).toBe(404);expect((await page.goto(`/breakouts/${breakoutId}`))?.status()).toBe(404);const attack=await page.evaluate(async id=>{const r=await fetch('/api/live-classroom/breakout-join',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({breakoutRoomId:id})});return r.status;},breakoutId);expect(attack).toBe(403);}}
  await login(other,6009);await other.goto(`/live-classroom/${roomId}`);await expect(other.getByRole('button',{name:'Join classroom'})).toHaveCount(0);
  const denied=await other.evaluate(async id=>{const r=await fetch('/api/live-classroom/join',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({liveSessionRoomId:id})});return {status:r.status,body:await r.json()};},roomId);expect(denied.status).toBe(403);expect(denied.body).not.toHaveProperty('token');
  await student.goto(classroom);await clickClassroomControl(student,'Join classroom');await expect(student.frameLocator('iframe').getByRole('heading',{name:'Isolated Daily media'})).toBeVisible();await clickClassroomControl(student,'Leave classroom');await expect(student.locator('iframe')).toHaveCount(0);
  await student.reload();await expect(student.getByRole('link',{name:'Open Current Activity'})).toHaveAttribute('href',`/activities/${activity}/mind-map`);await expect(student.locator('iframe')).toHaveCount(0);
  const rejoin=student.waitForResponse(r=>r.url().endsWith('/api/live-classroom/join'));await clickClassroomControl(student,'Join classroom');const fresh=await (await rejoin).json();expect(fresh.token).not.toBe(first.token);await expect(student.frameLocator('iframe').getByRole('heading',{name:'Isolated Daily media'})).toBeVisible();
  expect(snapshot()).toBe(afterEdit);expect(sql(`select count(*) from public.live_session_rooms where cohort_id=${quote(scope.cohortId)} and session_definition_id=${quote(scope.sessionId)} and status='ACTIVE'`)).toBe('1');
  await student.goto(`/live-classroom/${roomId}/teams/${scope.teamId}`);await expect(student).toHaveURL(new RegExp(`/breakouts/${breakoutId}$`));const teamJoin=student.waitForResponse(r=>r.url().endsWith('/api/live-classroom/breakout-join'));await clickClassroomControl(student,'Join classroom');expect((await teamJoin).status()).toBe(200);await expect(student.frameLocator('iframe').getByRole('heading',{name:'Isolated Daily media'})).toBeVisible();await student.getByRole('link',{name:'Open Team Portal',exact:true}).click();
await expect(student.getByRole('heading',{name:'Team A — Team Portal',exact:true})).toBeVisible();
expect(snapshot()).toBe(afterEdit);
  // Provider outage leaves direct authorized work available; no domain writes.
  await student.goto(classroom);await student.route('**/api/live-classroom/join',route=>route.fulfill({status:503,json:{error:'Live classroom unavailable.'}}));await clickClassroomControl(student,'Join classroom');await expect(student.getByRole('button',{name:'Try joining again'})).toBeVisible();await student.getByRole('link',{name:'Open Current Activity'}).click();await expect(
  student.getByTestId(`rf__node-${component.id}`)
).toContainText(label);expect(snapshot()).toBe(afterEdit);
  console.log('M16.19 substantive browser/security/persistence assertions PASS');
 }finally{
  // Cleanup is bounded and cannot replace the substantive test result.
  // Playwright owns final browser teardown if a context does not close in time.
  await closeBrowserContexts([masterContext,studentContext,otherContext,a2Context,b1Context]);
 }
});
