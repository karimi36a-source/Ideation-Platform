import {readFileSync} from "node:fs";
import {spawn} from "node:child_process";
import {it,vi} from "vitest";
import {createClient} from "@liveblocks/client";
import {Liveblocks} from "@liveblocks/node";
const state=vi.hoisted(()=>({actor:"",args:[] as string[],binary:""}));
vi.mock("server-only",()=>({}));
function query(expression:string,actor=state.actor):Promise<{data:unknown;error:{code:string}|null}>{
 return new Promise((resolve,reject)=>{
  const child=spawn(state.binary,[...state.args,"--set=VERBOSITY=verbose","-tA","-f","-"],{windowsHide:true});let out="",err="";
  child.stdout.on("data",x=>out+=x);child.stderr.on("data",x=>err+=x);child.on("error",()=>reject(Error("Test database transport unavailable")));
  child.on("close",code=>{const line=out.split(/\r?\n/).find(x=>x.startsWith("RESULT="));resolve(code?{data:null,error:{code:err.match(/ERROR:\s+([0-9A-Z]{5}):/)?.[1]??"UNKNOWN"}}:{data:line?JSON.parse(line.slice(7)):null,error:null});});
  child.stdin.end(`begin;set local role authenticated;select set_config('request.jwt.claim.sub','${actor}',true);select 'RESULT='||(${expression})::text;commit;`);
 });
}
vi.mock("@/lib/auth/authorization",async original=>({...await original<typeof import("@/lib/auth/authorization")>(),getAuthorizationContext:async()=>{
 const result=await query("to_jsonb(public.current_platform_user_id())");if(result.error||!result.data)throw Error("Authentication unavailable");return {userId:result.data,assignments:[]};
}}));
vi.mock("@/lib/db/server",()=>({createServerSupabaseClient:async()=>({rpc:async(name:string,args:{target_activity:string})=>query(`public.${name}('${args.target_activity}')`)})}));
import {POST} from "@/app/api/v1/mind-map/collaboration-auth/route";
import {createMindMapRoomAuthorizer} from "@/features/mind-map/collaboration";
import {getMindMapEditor} from "@/features/mind-map/editor-service";
import {mindMapRoomId} from "@/features/mind-map/collaboration-schema";
const check=(value:unknown,message:string)=>{if(!value)throw Error(message);};
const delay=(ms:number)=>new Promise(resolve=>setTimeout(resolve,ms));
async function until(predicate:()=>boolean,message:string){const end=Date.now()+30000;while(!predicate()&&Date.now()<end)await delay(100);check(predicate(),message);}
it.skipIf(!process.env.FICI_MIND_MAP_LIVEBLOCKS_FIXTURE)("M11.13 actual private provider events retain canonical scope/CAS/revocation",async()=>{
 process.loadEnvFile(".env.local");const secret=process.env.LIVEBLOCKS_SECRET_KEY;check(secret,"Liveblocks secret MISSING");
 const fixture=JSON.parse(readFileSync(process.env.FICI_MIND_MAP_LIVEBLOCKS_FIXTURE!,"utf8"));state.args=fixture.args;state.binary=fixture.binary;
 const values=fixture.values,activity=values.activity.activity.id,map=values.map.mindMap.id,roomId=mindMapRoomId(map),scope=values.scope;
 const a1="00000000-0000-4000-8000-000000006004",a2="00000000-0000-4000-8000-000000006005",master="00000000-0000-4000-8000-000000006002",b1="00000000-0000-4000-8000-000000006007";
 const provider=new Liveblocks({secret:secret!}),connections:{leave:()=>void}[]=[];let created=false;
 const authorize=async(actor:string,input:unknown={activityInstanceId:activity})=>{state.actor=actor;return POST(new Request("http://localhost/api/v1/mind-map/collaboration-auth",{method:"POST",body:JSON.stringify(input)}));};
 const token=async(actor:string)=>{const response=await authorize(actor);check(response.status===200,"Provider authorization failed");const body=await response.json();check(typeof body.data?.token==="string","Provider grant missing");check(!JSON.stringify(body).includes(secret!),"Secret exposure");const claims=JSON.parse(Buffer.from(body.data.token.split('.')[1],"base64url").toString());check(Object.keys(claims.perms).length===1&&Object.keys(claims.perms)[0]===roomId,"Room token scope mismatch");return body.data;};
 try{
  const t1=await token(a1);created=true;const t2=await token(a2);
  const acl=await provider.getRoom(roomId);check(!acl.defaultAccesses.length&&!Object.keys(acl.usersAccesses).length&&!Object.keys(acl.groupsAccesses).length,"Public/broad provider room");
  for(const actor of [b1,master,"00000000-0000-4000-8000-000000006001","00000000-0000-4000-8000-000000006003",""]){const response=await authorize(actor);check(response.status!==200&&!JSON.stringify(await response.json()).includes(map),"Foreign role/scope grant or metadata");}
  for(const key of ["roomId","role","userId","teamId","permission"]){const response=await authorize(b1,{activityInstanceId:activity,[key]:roomId});check(response.status!==200,"Spoofed room grant");}
  const first=createClient({authEndpoint:async()=>t1}).enterRoom(roomId),second=createClient({authEndpoint:async()=>t2}).enterRoom(roomId);connections.push(first,second);
  const received1:unknown[]=[],received2:unknown[]=[],foreign:unknown[]=[];
  first.room.subscribe("event",({event})=>received1.push(event));second.room.subscribe("event",({event})=>received2.push(event));
  await until(()=>first.room.getStatus()==="connected"&&second.room.getStatus()==="connected","Authorized real connections unavailable");
  const wrong=provider.prepareSession(b1);wrong.allow(mindMapRoomId(crypto.randomUUID()),["*:write"]);const wrongGrant=await wrong.authorize();check(wrongGrant.status===200,"Negative token fixture failed");
  const outsider=createClient({authEndpoint:async()=>JSON.parse(wrongGrant.body)}).enterRoom(roomId);connections.push(outsider);outsider.room.subscribe("event",({event})=>foreign.push(event));
  const n1=values.node_component,n2=values.node_solution;
  const before=JSON.stringify((await query(`public.get_mind_map_editor('${activity}')`,a2)).data);
  first.room.broadcastEvent({type:"mind-map-move",nodeId:n1.id,revision:n1.edit_revision,x:411,y:312});
  second.room.broadcastEvent({type:"mind-map-move",nodeId:n2.id,revision:n2.edit_revision,x:522,y:423});
  await until(()=>received1.length>0&&received2.length>0,"Bidirectional movement unavailable");
  check(before===JSON.stringify((await query(`public.get_mind_map_editor('${activity}')`,a2)).data),"Provider event mutated PostgreSQL");
  const update=(actor:string,id:string,revision:number,x:number)=>query(`public.update_mind_map_node('${JSON.stringify({nodeId:id,expectedRevision:revision,positionData:{x,y:123}})}'::jsonb)`,actor);
  const independent=await Promise.all([update(a1,n1.id,n1.edit_revision,411),update(a2,n2.id,n2.edit_revision,522)]);check(independent.every(x=>!x.error),"Independent canonical moves failed");
  const rivals=await Promise.all([update(a1,n1.id,n1.edit_revision+1,601),update(a2,n1.id,n1.edit_revision+1,602)]);
  check(rivals.filter(x=>!x.error).length===1&&rivals.filter(x=>x.error?.code==="40001").length===1,"Same-node CAS did not select one winner");
  // M11.14 checkpoints the canonical CAS winner, never the earlier provider coordinates.
  const checkpoint=await query(`public.save_mind_map_draft('${JSON.stringify({mindMapId:map,expectedDraftRevision:0})}'::jsonb)`,a2);
  check(!checkpoint.error,"Canonical collaborative Draft checkpoint failed");
  const savedVersion=await query(`(select to_jsonb(v) from public.artifact_versions v where id='${values.map.version.id}')`,a2);
  const saved=savedVersion.data as {draft_revision:number;content_snapshot:{nodes:{id:string;positionData:{x:number}}[]}};
  check(saved.draft_revision===1&&[601,602].includes(saved.content_snapshot.nodes.find(n=>n.id===n1.id)?.positionData.x??0),"Checkpoint promoted stale provider coordinates");
  first.room.broadcastEvent({type:"mind-map-reload"});await delay(1000);
  check(outsider.room.getStatus()!=="connected"&&!foreign.length,"Team B received Team A provider events");
  state.actor=a2;const canonical=await getMindMapEditor(activity);check(canonical.nodes.find(n=>n.id===n1.id)?.edit_revision===n1.edit_revision+2,"Canonical winner lost");
  second.leave();const reconnect=createClient({authEndpoint:async()=>await token(a2)}).enterRoom(roomId);connections.push(reconnect);
  await until(()=>reconnect.room.getStatus()==="connected","Authorized reconnect failed");state.actor=a2;check(JSON.stringify(await getMindMapEditor(activity))===JSON.stringify(canonical),"Reconnect changed canonical data");
  await createMindMapRoomAuthorizer(async()=>{throw Error("private provider failure");})({activityInstanceId:activity}).then(()=>{throw Error("Provider failure granted access");},error=>check(error.message==="Collaboration provider unavailable.","Unsafe provider error"));
  state.actor=a2;check(JSON.stringify(await getMindMapEditor(activity))===JSON.stringify(canonical),"Provider failure mutated state");
  check(!(await query(`public.remove_team_member('${scope.teamId}','${a1}')`,master)).error,"Removal failed");
  check((await authorize(a1)).status!==200,"Removed member got new grant");
  let newAuthDenied=false;const fresh=createClient({authEndpoint:async()=>{newAuthDenied=(await authorize(a1)).status!==200;return {error:"forbidden",reason:"Resource unavailable."};}}).enterRoom(roomId);connections.push(fresh);
  await until(()=>newAuthDenied&&fresh.room.getStatus()!=="connecting","Removed fresh reconnect not denied");
  check((await update(a1,n1.id,n1.edit_revision+2,999)).error!==null,"Removed member persisted mutation");
  check((await query(`public.save_mind_map_draft('${JSON.stringify({mindMapId:map,expectedDraftRevision:1})}'::jsonb)`,a1)).error!==null,"Open provider session bypassed checkpoint authorization");
  check(first.room.getStatus()==="connected","Open provider session behavior changed; inspect revocation");
  // M11.26: removal commits while the real grant is awaiting server delivery.
  state.actor=a2;
  let raced=false;
  await createMindMapRoomAuthorizer(async()=>{
   check(!(await query(`public.remove_team_member('${scope.teamId}','${a2}')`,master)).error,'Race removal failed');
   raced=true;return t2;
  })({activityInstanceId:activity}).then(()=>{throw Error('Post-removal grant escaped');},error=>check(error.code==='NOT_FOUND','Unsafe race denial'));
  check(raced&&(await authorize(a2)).status!==200,'Removal race did not revoke fresh authorization');
  check((await update(a2,n1.id,n1.edit_revision+2,999)).error?.code==='42501','Post-removal stale-revision mutation committed');
  console.log('M11.26 Mind Map committed-removal/provider-delivery race and stale-revision canonical write denial PASS');
  console.log("M11.13 real connection/two-user movement/no provider persistence/one CAS winner/TeamB no events/reconnect/failure/removal PASS");
 }finally{for(const connection of connections)connection.leave();if(created)await provider.deleteRoom(roomId);}
} ,300000);
