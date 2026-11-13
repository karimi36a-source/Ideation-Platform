import {expect,test,type Page} from "@playwright/test";
import {execFileSync} from "node:child_process";
import {randomUUID} from "node:crypto";

test.use({trace:"off",screenshot:"off",video:"off"});
test.describe.configure({mode:"serial",retries:0});
test.skip(!process.env.FICI_MIND_MAP_BASE_URL,"Requires isolated real-auth fixture runner");
const password=process.env.FICI_MIND_MAP_USER_PASSWORD!;
const dbPassword=process.env.FICI_MIND_MAP_DB_PASSWORD!;
const psql="C:\\Program Files\\PostgreSQL\\17\\bin\\psql.exe";
const sql=(query:string)=>execFileSync(psql,["-w","-X","-h","127.0.0.1","-p","5432","-U","postgres","-d","fici_m1112_browser","-tA","-c",query],{encoding:"utf8",env:{...process.env,PGPASSWORD:dbPassword},windowsHide:true}).trim();
const fixture=(key:string)=>JSON.parse(sql(`select value::text from public.mind_map_browser_fixture where key='${key}'`));
const login=async(page:Page,user:number)=>{await page.goto("/login");await page.getByLabel("Email",{exact:true}).fill(`team-acceptance-${user}@example.test`);await page.getByLabel("Password",{exact:true}).fill(password);await page.getByRole("button",{name:"Sign in",exact:true}).click();await expect(page).toHaveURL(/\/account$/,{timeout:60_000});};
const actorSql=(actor:string,statement:string)=>sql(`begin;set local role authenticated;select set_config('request.jwt.claim.sub','${actor}',true);${statement};commit;`);
const settle=async(page:Page)=>{await expect(page.locator("section[aria-busy]")).toHaveAttribute("aria-busy","false",{timeout:60_000});};
const node=(page:Page,id:string)=>page.getByTestId(`rf__node-${id}`);
const dragWithMouseEvents=async(page:Page,selector:string,target:{x:number;y:number})=>{
 const source=page.locator(selector),box=await source.boundingBox();expect(box).not.toBeNull();
 const start={x:box!.x+box!.width/2,y:box!.y+box!.height/2};
 await page.evaluate(({selector,x,y})=>document.querySelector(selector)?.dispatchEvent(new MouseEvent("mousedown",{bubbles:true,cancelable:true,button:0,buttons:1,clientX:x,clientY:y,view:window})),{selector,...start});
 await page.evaluate(({x,y})=>window.dispatchEvent(new MouseEvent("mousemove",{bubbles:true,cancelable:true,buttons:1,clientX:x,clientY:y,view:window})),{x:start.x+(target.x-start.x)/2,y:start.y+(target.y-start.y)/2});
 await page.evaluate(({x,y})=>window.dispatchEvent(new MouseEvent("mousemove",{bubbles:true,cancelable:true,buttons:1,clientX:x,clientY:y,view:window})),target);
 await page.evaluate(({x,y})=>window.dispatchEvent(new MouseEvent("mouseup",{bubbles:true,cancelable:true,button:0,buttons:0,clientX:x,clientY:y,view:window})),target);
};
const connectWithMouseEvents=async(page:Page,sourceSelector:string,target:{x:number;y:number})=>{
 const source=page.locator(sourceSelector),box=await source.boundingBox();expect(box).not.toBeNull();
 const start={x:box!.x+box!.width/2,y:box!.y+box!.height/2};
 await page.evaluate(({selector,x,y})=>document.querySelector(selector)?.dispatchEvent(new MouseEvent("mousedown",{bubbles:true,cancelable:true,button:0,buttons:1,clientX:x,clientY:y,view:window})),{selector:sourceSelector,...start});
 await page.evaluate(({x,y})=>document.dispatchEvent(new MouseEvent("mousemove",{bubbles:true,cancelable:true,buttons:1,clientX:x,clientY:y,view:window})),{x:start.x+(target.x-start.x)/2,y:start.y+(target.y-start.y)/2});
 await page.evaluate(({x,y})=>document.dispatchEvent(new MouseEvent("mousemove",{bubbles:true,cancelable:true,buttons:1,clientX:x,clientY:y,view:window})),target);
 await page.evaluate(({x,y})=>document.dispatchEvent(new MouseEvent("mouseup",{bubbles:true,cancelable:true,button:0,buttons:0,clientX:x,clientY:y,view:window})),target);
};
const a1="00000000-0000-4000-8000-000000006004",master="00000000-0000-4000-8000-000000006002";

test.beforeEach(async({page})=>{await page.route("**/api/v1/mind-map/collaboration-auth",route=>route.fulfill({status:503,body:"{}"}));});
test.beforeAll(()=>{if(!process.env.FICI_MIND_MAP_BASE_URL)return;const team=fixture("scope").teamId;if(sql(`select count(*) from public.team_memberships where team_id='${team}' and user_id='${a1}' and status='active'`)==="0")actorSql(master,`select public.add_team_member('${team}','${a1}','member')`);});
test("M11.12 real-auth Team scope and complete canonical Mind Map render",async({browser})=>{
 const activity=fixture("activity").activity.id as string;
 const a1=await browser.newPage();await login(a1,6004);await a1.goto(`/activities/${activity}/mind-map`);
 await expect(a1.getByRole("heading",{name:"Structure the whole invention"})).toBeVisible();
 await expect(a1.getByText("Editable draft",{exact:true})).toBeVisible();
 for(const label of ["system","subsystem","component","function","problem","solution","gap"].map(key=>sql(`select label from public.mind_map_nodes where id='${fixture("node_"+key).id}'`))){await expect(a1.locator('[data-testid^="rf__node-"]').filter({has:a1.getByText(label,{exact:true})})).toBeVisible();}
 await expect(a1.getByText("Linked · Canonical COMPONENT",{exact:true})).toBeVisible();
 await expect(a1.getByText("Visual node · unlinked",{exact:true}).first()).toBeVisible();

 const b1=await browser.newPage();await login(b1,6007);const response=await b1.goto(`/activities/${activity}/mind-map`);
 expect(response?.status()).toBe(404);const deniedPayload=await response!.text();for(const value of [fixture("map").mindMap.id,fixture("node_component").id,"System Alpha","Canonical COMPONENT"]){expect(deniedPayload).not.toContain(value);}await expect(b1.getByText("System Alpha",{exact:true})).toHaveCount(0);await expect(b1.getByText("Canonical COMPONENT",{exact:true})).toHaveCount(0);
 await a1.close();await b1.close();
});

test("M11.12 editor mutations persist, reconcile conflicts, and preserve canonical objects",async({page})=>{
 const activity=fixture("activity").activity.id as string,readonlyActivity=fixture("readonlyActivity").activity.id as string;
 const component=fixture("node_component"),problem=fixture("node_problem"),system=fixture("node_system"),root=fixture("map").rootNode;
 const canonicalBefore=sql("select jsonb_build_object('project',to_jsonb(p),'object',to_jsonb(o),'relationships',(select coalesce(jsonb_agg(to_jsonb(r) order by r.id),'[]') from public.development_object_relationships r where r.source_object_id=o.id or r.target_object_id=o.id))::text from public.development_projects p join public.development_objects o on o.project_id=p.id where o.id='"+component.development_object_id+"'");
 await login(page,6005);await page.goto(`/activities/${activity}/mind-map`);await expect(page.getByText("Editable draft",{exact:true})).toBeVisible({timeout:15_000});

 const oldPosition=sql(`select position_data::text from public.mind_map_nodes where id='${component.id}'`),box=await node(page,component.id).boundingBox();expect(box).not.toBeNull();
 await dragWithMouseEvents(page,`[data-testid="rf__node-${component.id}"]`,{x:box!.x+125,y:box!.y+90});
 await expect(page.getByRole("status")).toContainText("Saved",{timeout:60_000});await settle(page);const movedPosition=sql(`select position_data::text from public.mind_map_nodes where id='${component.id}'`);expect(movedPosition).not.toBe(oldPosition);
 await page.reload();await expect(node(page,component.id)).toBeVisible();expect(sql(`select position_data::text from public.mind_map_nodes where id='${component.id}'`)).toBe(movedPosition);

 await node(page,component.id).dispatchEvent("click");await page.getByLabel("Canonical Project object").selectOption("");await page.getByRole("button",{name:"Remove visual reference"}).click();
 await expect(node(page,component.id)).toContainText("Visual node · unlinked",{timeout:60000});await settle(page);expect(sql(`select development_object_id is null from public.mind_map_nodes where id='${component.id}'`)).toBe("t");
 await page.getByLabel("Canonical Project object").selectOption(component.development_object_id);await page.getByRole("button",{name:"Link object",exact:true}).click();
 await expect(node(page,component.id)).toContainText("Linked · Canonical COMPONENT",{timeout:60000});await settle(page);expect(sql(`select development_object_id from public.mind_map_nodes where id='${component.id}'`)).toBe(component.development_object_id);

 const editedLabel=`Browser component ${randomUUID().slice(0,8)}`;await node(page,component.id).dispatchEvent("click");await page.getByLabel("Visual label").fill(editedLabel);await page.getByRole("button",{name:"Save label"}).click();await expect(node(page,component.id)).toContainText(editedLabel);await page.reload();await expect(node(page,component.id)).toContainText(editedLabel);
 await node(page,root.id).dispatchEvent("click");await page.getByLabel("Visual label").fill(`Browser central ${randomUUID().slice(0,8)}`);await page.getByRole("button",{name:"Save label"}).click();await settle(page);
 const conflictLabel=`Concurrent ${randomUUID().slice(0,8)}`;await node(page,problem.id).dispatchEvent("click");await page.getByLabel("Visual label").fill("Stale browser label");
 const revision=Number(sql(`select edit_revision from public.mind_map_nodes where id='${problem.id}'`));actorSql(a1,`select public.update_mind_map_node('{"nodeId":"${problem.id}","expectedRevision":${revision},"label":"${conflictLabel}"}'::jsonb)`);
 await page.getByRole("button",{name:"Save label"}).click();await expect(page.getByRole("status")).toContainText("changed elsewhere",{timeout:60_000});await expect(node(page,problem.id)).toContainText(conflictLabel);expect(sql(`select label from public.mind_map_nodes where id='${problem.id}'`)).toBe(conflictLabel);

 const addedLabel=`Browser leaf ${randomUUID().slice(0,8)}`;await page.getByLabel("Node type").selectOption("GAP");await page.getByLabel("Label",{exact:true}).fill(addedLabel);await page.locator("form").getByLabel("Parent").selectOption(root.id);await page.getByRole("button",{name:"Add node"}).click();await expect(page.getByRole("status")).toContainText("Saved",{timeout:60_000});await settle(page);
 const addedId=sql(`select id from public.mind_map_nodes where label='${addedLabel}'`);await page.reload();await expect(node(page,addedId)).toContainText(addedLabel);

 const sourceHandle=node(page,addedId).locator('.react-flow__handle.source'),targetHandle=node(page,component.id).locator('.react-flow__handle.target');const sourceBox=await sourceHandle.boundingBox(),targetBox=await targetHandle.boundingBox();expect(sourceBox&&targetBox).toBeTruthy();
 await connectWithMouseEvents(page,`[data-testid="rf__node-${addedId}"] .react-flow__handle.source`,{x:targetBox!.x+targetBox!.width/2,y:targetBox!.y+targetBox!.height/2});await expect(page.getByRole("status")).toContainText("Saved",{timeout:60_000});await settle(page);
 const edgeId=sql(`select id from public.mind_map_edges where source_node_id='${addedId}' and target_node_id='${component.id}'`);expect(edgeId).not.toBe("");await page.reload();await expect(page.getByTestId(`rf__edge-${edgeId}`)).toBeAttached();await page.getByTestId(`rf__edge-${edgeId}`).locator(".react-flow__edge-interaction").dispatchEvent("click");await expect(page.getByRole("button",{name:"Remove visual connection"})).toBeVisible({timeout:15000});await page.getByRole("button",{name:"Remove visual connection"}).click({timeout:15000});await expect(page.getByRole("status")).toContainText("Saved",{timeout:60_000});await settle(page);expect(sql(`select count(*) from public.mind_map_edges where id='${edgeId}'`)).toBe("0");

 await node(page,system.id).dispatchEvent("click");await expect(page.getByRole("button",{name:"Remove visual node"})).toBeDisabled();await expect(page.getByText("Move or remove child nodes before removing this node.")).toBeVisible();
 await node(page,root.id).dispatchEvent("click");await expect(page.getByRole("button",{name:"Remove visual node"})).toHaveCount(0);
 await node(page,addedId).dispatchEvent("click");await page.getByRole("button",{name:"Remove visual node"}).click();await expect(page.getByRole("status")).toContainText("Saved",{timeout:60_000});await settle(page);await expect.poll(()=>sql(`select count(*) from public.mind_map_nodes where id='${addedId}'`)).toBe("0");
 expect(sql("select jsonb_build_object('project',to_jsonb(p),'object',to_jsonb(o),'relationships',(select coalesce(jsonb_agg(to_jsonb(r) order by r.id),'[]') from public.development_object_relationships r where r.source_object_id=o.id or r.target_object_id=o.id))::text from public.development_projects p join public.development_objects o on o.project_id=p.id where o.id='"+component.development_object_id+"'")).toBe(canonicalBefore);

 await page.goto(`/activities/${readonlyActivity}/mind-map`);await expect(page.getByText("Read only",{exact:true})).toBeVisible({timeout:15_000});await expect(page.getByRole("button",{name:"Add node"})).toHaveCount(0);await expect(page.getByLabel("Visual label")).toHaveCount(0);
});

test("M11.12 removed member stale UI and exact IDs cannot bypass authorization",async({browser})=>{
 const activity=fixture("activity").activity.id as string,scope=fixture("scope"),component=fixture("node_component"),crossEdge=fixture("crossEdge"),leaf=fixture("node_function");
 const snapshot=()=>sql(`select jsonb_build_object('nodes',(select jsonb_agg(to_jsonb(n) order by n.id) from public.mind_map_nodes n where n.mind_map_id='${fixture("map").mindMap.id}'),'edges',(select jsonb_agg(to_jsonb(e) order by e.id) from public.mind_map_edges e where e.mind_map_id='${fixture("map").mindMap.id}'))::text`);
 const before=snapshot(),pages:Page[]=[];
 try{
  for(let i=0;i<6;i++){const page=await browser.newPage();pages.push(page);await page.route("**/api/v1/mind-map/collaboration-auth",route=>route.fulfill({status:503,body:"{}"}));await login(page,6004);await page.goto(`/activities/${activity}/mind-map`);await expect(page.getByText("Editable draft",{exact:true})).toBeVisible({timeout:60000});}
  actorSql(master,`select public.remove_team_member('${scope.teamId}','${a1}')`);
  // Every page is stale before removal. Execute independently so six Auth/
  // PostgREST requests do not compete with each other for the same UI timeout.
  const attacks=[
   async(page:Page)=>{await node(page,component.id).dispatchEvent("click");await page.getByLabel("Visual label").fill("Forbidden stale edit");await page.getByRole("button",{name:"Save label"}).click();},
   async(page:Page)=>{await page.getByLabel("Label",{exact:true}).fill("Forbidden stale add");await page.getByRole("button",{name:"Add node"}).click();},
   async(page:Page)=>{await page.getByTestId(`rf__edge-${crossEdge.id}`).dispatchEvent("click");await page.getByRole("button",{name:"Remove visual connection"}).click();},
   async(page:Page)=>{const box=await node(page,component.id).boundingBox();await dragWithMouseEvents(page,`[data-testid="rf__node-${component.id}"]`,{x:box!.x+160,y:box!.y+90});},
   async(page:Page)=>{await node(page,leaf.id).dispatchEvent("click");await page.getByRole("button",{name:"Remove visual node"}).click();},
   async(page:Page)=>{const target=await node(page,component.id).locator('.react-flow__handle.target').boundingBox();await connectWithMouseEvents(page,`[data-testid="rf__node-${leaf.id}"] .react-flow__handle.source`,{x:target!.x+target!.width/2,y:target!.y+target!.height/2});},
  ];
  for(const [i,page] of pages.entries()){
   await attacks[i](page);await expect(page.getByRole("status")).toContainText("unavailable",{timeout:90000});await settle(page);
   expect(snapshot()).toBe(before);const response=await page.reload();expect(response?.status()).toBe(404);const payload=await response!.text();
   for(const value of [fixture("map").mindMap.id,component.id,"System Alpha","Canonical COMPONENT"])expect(payload).not.toContain(value);
   await page.close();
  }
  expect(snapshot()).toBe(before);expect(sql(`select count(*) from public.team_memberships where team_id='${scope.teamId}' and user_id='${a1}' and status='active'`)).toBe("0");
  const remaining=await browser.newPage();pages.push(remaining);await login(remaining,6005);await remaining.goto(`/activities/${activity}/mind-map`);await expect(remaining.getByRole("heading",{name:"Structure the whole invention"})).toBeVisible({timeout:60000});
 }finally{await Promise.all(pages.map(page=>page.close()));}
});
