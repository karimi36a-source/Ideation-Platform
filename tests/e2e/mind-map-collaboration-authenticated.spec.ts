import {test,expect,type Page} from "@playwright/test";
import {execFileSync} from "node:child_process";
test.skip(!process.env.FICI_MIND_MAP_BASE_URL,"Requires isolated real-auth fixture runner");
test.use({trace:"off",screenshot:"off",video:"off"});test.describe.configure({mode:"serial",retries:0});
const sql=(query:string)=>execFileSync("C:\\Program Files\\PostgreSQL\\17\\bin\\psql.exe",["-w","-X","-h","127.0.0.1","-p","5432","-U","postgres","-d","fici_m1112_browser","-tA","-c",query],{encoding:"utf8",env:{...process.env,PGPASSWORD:process.env.FICI_MIND_MAP_DB_PASSWORD},windowsHide:true}).trim();
const fixture=(key:string)=>JSON.parse(sql(`select value::text from public.mind_map_browser_fixture where key='${key}'`));
const a1="00000000-0000-4000-8000-000000006004",master="00000000-0000-4000-8000-000000006002";
const actorSql=(statement:string)=>sql(`begin;set local role authenticated;select set_config('request.jwt.claim.sub','${master}',true);${statement};commit;`);
const node=(page:Page,id:string)=>page.getByTestId(`rf__node-${id}`);
async function login(page:Page,user:number){await page.goto("/login");await page.getByLabel("Email",{exact:true}).fill(`team-acceptance-${user}@example.test`);await page.getByLabel("Password",{exact:true}).fill(process.env.FICI_MIND_MAP_USER_PASSWORD!);await page.getByRole("button",{name:"Sign in",exact:true}).click();await expect(page).toHaveURL(/\/account$/,{timeout:60000});}
async function open(page:Page,user:number){await login(page,user);await page.goto(`/activities/${fixture("activity").activity.id}/mind-map`);await expect(page.getByTestId("mind-map-collaboration-status")).toHaveText("Collaboration connected",{timeout:90000});}
async function dragStart(page:Page,id:string,dx:number,dy:number){
 await node(page,id).evaluate((el,{dx,dy})=>{const b=el.getBoundingClientRect(),x=b.x+b.width/2,y=b.y+b.height/2;el.dispatchEvent(new MouseEvent("mousedown",{bubbles:true,button:0,buttons:1,clientX:x,clientY:y,view:window}));window.dispatchEvent(new MouseEvent("mousemove",{bubbles:true,buttons:1,clientX:x+dx/2,clientY:y+dy/2,view:window}));window.dispatchEvent(new MouseEvent("mousemove",{bubbles:true,buttons:1,clientX:x+dx,clientY:y+dy,view:window}));},{dx,dy});
}
async function dragEnd(page:Page){await page.evaluate(()=>window.dispatchEvent(new MouseEvent("mouseup",{bubbles:true,button:0,buttons:0,view:window})));}
test.beforeAll(()=>{const team=fixture("scope").teamId;if(sql(`select count(*) from public.team_memberships where team_id='${team}' and user_id='${a1}' and status='active'`)==="0")actorSql(`select public.add_team_member('${team}','${a1}','member')`);});

test("M11.13 actual provider two-user movement/CAS/reconnect and private-room denial",async({browser})=>{
 const first=await browser.newPage(),second=await browser.newPage(),foreign=await browser.newPage();
 try{
  await open(first,6004);await open(second,6005);
  const n1=fixture("node_component"),n2=fixture("node_solution"),activity=fixture("activity").activity.id;
  const old=sql(`select jsonb_agg(jsonb_build_object('id',id,'position',position_data,'revision',edit_revision) order by id)::text from public.mind_map_nodes where id in ('${n1.id}','${n2.id}')`);
  const originalSecond=await node(second,n1.id).getAttribute("style");
  await dragStart(first,n1.id,75,45);
  await expect.poll(()=>node(second,n1.id).getAttribute("style"),{timeout:15000}).not.toBe(originalSecond);
  expect(sql(`select jsonb_agg(jsonb_build_object('id',id,'position',position_data,'revision',edit_revision) order by id)::text from public.mind_map_nodes where id in ('${n1.id}','${n2.id}')`)).toBe(old);
  const originalFirst=await node(first,n2.id).getAttribute("style");await dragStart(second,n2.id,70,-45);
  await expect.poll(()=>node(first,n2.id).getAttribute("style"),{timeout:15000}).not.toBe(originalFirst);
  await Promise.all([dragEnd(first),dragEnd(second)]);
  await expect(first.getByRole("status")).toContainText("Saved",{timeout:90000});await expect(second.getByRole("status")).toContainText("Saved",{timeout:90000});
  const persisted=sql(`select jsonb_agg(jsonb_build_object('id',id,'position',position_data,'revision',edit_revision) order by id)::text from public.mind_map_nodes where id in ('${n1.id}','${n2.id}')`);expect(persisted).not.toBe(old);
  expect(JSON.parse(persisted).map((n:{revision:number})=>n.revision)).toEqual(JSON.parse(old).map((n:{revision:number})=>n.revision+1));
  await first.reload();await second.reload();await expect(first.getByTestId("mind-map-collaboration-status")).toHaveText("Collaboration connected",{timeout:90000});await expect(second.getByTestId("mind-map-collaboration-status")).toHaveText("Collaboration connected",{timeout:90000});
  // Both drag starts capture the same canonical revision, before either commit.
  const revision=Number(sql(`select edit_revision from public.mind_map_nodes where id='${n1.id}'`));
  await dragStart(first,n1.id,65,25);await dragStart(second,n1.id,-60,-25);await dragEnd(first);
  await expect(first.getByRole("status")).toContainText("Saved",{timeout:90000});
  await dragEnd(second);await expect(second.getByRole("status")).toContainText("changed elsewhere",{timeout:90000});
  await expect.poll(()=>node(second,n1.id).evaluate(el=>el.style.transform),{timeout:60000}).toBe(await node(first,n1.id).evaluate(el=>el.style.transform));
  expect(Number(sql(`select edit_revision from public.mind_map_nodes where id='${n1.id}'`))).toBe(revision+1);
  const winner=sql(`select position_data::text from public.mind_map_nodes where id='${n1.id}'`);
  await second.reload();await expect(second.getByTestId("mind-map-collaboration-status")).toHaveText("Collaboration connected",{timeout:90000});expect(sql(`select position_data::text from public.mind_map_nodes where id='${n1.id}'`)).toBe(winner);
  await login(foreign,6007);
  const denied=await foreign.request.post("/api/v1/mind-map/collaboration-auth",{data:{activityInstanceId:activity}});expect(denied.status()).toBe(404);expect(await denied.text()).not.toContain(fixture("map").mindMap.id);
  const exact=await foreign.request.post("/api/v1/mind-map/collaboration-auth",{data:{activityInstanceId:activity,roomId:`mind-map:${fixture("map").mindMap.id}`}});expect(exact.ok()).toBe(false);
  actorSql(`select public.remove_team_member('${fixture("scope").teamId}','${a1}')`);
  const removed=await first.request.post("/api/v1/mind-map/collaboration-auth",{data:{activityInstanceId:activity}});expect(removed.status()).toBe(404);
  const response=await first.reload();expect(response?.status()).toBe(404);expect(await response!.text()).not.toContain(n1.id);
  await second.reload();await expect(second.getByTestId("mind-map-collaboration-status")).toHaveText("Collaboration connected",{timeout:90000});
 }finally{await first.close();await second.close();await foreign.close();}
});

test("M11.13 provider auth failure leaves canonical editor usable without fake saves",async({page})=>{
 await page.route("**/api/v1/mind-map/collaboration-auth",route=>route.fulfill({status:503,contentType:"application/json",body:JSON.stringify({ok:false,error:{code:"DEPENDENCY_NOT_READY",message:"Collaboration provider unavailable."}})}));
 const activity=fixture("activity").activity.id,n=fixture("node_component"),before=sql(`select to_jsonb(n)::text from public.mind_map_nodes n where id='${n.id}'`);
 await login(page,6005);await page.goto(`/activities/${activity}/mind-map`);await expect(page.getByTestId("mind-map-collaboration-status")).toContainText("unavailable",{timeout:90000});
 expect(sql(`select to_jsonb(n)::text from public.mind_map_nodes n where id='${n.id}'`)).toBe(before);await expect(page.getByRole("status")).toHaveCount(0);await expect(page.getByText("Editable draft",{exact:true})).toBeVisible();
});
