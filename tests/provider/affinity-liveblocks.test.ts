import { readFileSync } from "node:fs";
import { spawn, spawnSync } from "node:child_process";
import { it, vi } from "vitest";
import { createClient } from "@liveblocks/client";
import { Liveblocks } from "@liveblocks/node";
const state = vi.hoisted(() => ({ actor: "", args: [] as string[], binary: "" }));
vi.mock("server-only", () => ({}));
function queryAsync(expression: string, actor: string): Promise<{ data: unknown; error: {code:string} | null }> {
 return new Promise((resolve,reject) => {
  const child=spawn(state.binary,[...state.args,"--set=VERBOSITY=verbose","-t","-A","-f","-"],{windowsHide:true});let out="",err="";
  child.stdout.on('data',x=>out+=x);child.stderr.on('data',x=>err+=x);child.on('error',()=>reject(new Error('Database transport unavailable.')));
  child.on('close',code=>{if(code!==0)return resolve({data:null,error:{code:err.match(/ERROR:\s+([0-9A-Z]{5}):/)?.[1]??'UNKNOWN'}});const line=out.split(/\r?\n/).find(x=>x.startsWith('RESULT='));resolve({data:line?JSON.parse(line.slice(7)):null,error:null});});
  child.stdin.end(`begin;set local statement_timeout='30s';set local role authenticated;select set_config('request.jwt.claim.sub','${actor}',true);select 'RESULT='||(${expression})::text;select pg_sleep(0.2);commit;`);
 });
}
function query(expression: string, actor = state.actor) {
 const result = spawnSync(state.binary, [...state.args, "--set=VERBOSITY=verbose", "-t", "-A", "-f", "-"], { encoding: "utf8", windowsHide: true, input: `begin;set local role authenticated;select set_config('request.jwt.claim.sub','${actor}',true);select 'RESULT='||(${expression})::text;commit;`, timeout: 15000 });
 if (result.status !== 0) return { data: null, error: { code: result.stderr.match(/ERROR:\s+([0-9A-Z]{5}):/)?.[1] ?? "UNKNOWN" } };
 const line = result.stdout.split(/\r?\n/).find(x => x.startsWith("RESULT="));
 return { data: line ? JSON.parse(line.slice(7)) : null, error: null };
}
vi.mock("@/lib/auth/authorization", async original => ({ ...await original<typeof import("@/lib/auth/authorization")>(), getAuthorizationContext: async () => {
 const identity = query("to_jsonb(public.current_platform_user_id())");
 if (identity.error || !identity.data) throw new Error("Authentication unavailable.");
 return { userId: identity.data, assignments: [] };
} }));
vi.mock("@/lib/db/server", () => ({ createServerSupabaseClient: async () => ({ rpc: async (name: string, args: { target_activity?: string; input?: unknown }) => name === "get_affinity_collaboration_board" ? query(`public.get_affinity_collaboration_board('${args.target_activity}')`) : query(`public.${name}('${JSON.stringify(args.input)}'::jsonb)`) }) }));
import { createAffinityRoomAuthorizer } from "@/features/affinity/collaboration";
import { moveItemToAffinityGroup } from "@/features/affinity/items";
import { persistCollaborativeAffinityMove } from "@/features/affinity/collaboration-movement";
import { POST } from "@/app/api/v1/affinity/collaboration-auth/route";
const check = (value: boolean, message: string) => { if (!value) throw new Error(message); };
const delay = (ms: number) => new Promise(resolve => setTimeout(resolve, ms));
async function until(test: () => boolean, message: string) { const end = Date.now()+20000; while (!test() && Date.now()<end) await delay(100); check(test(), message); }
it("real provider authorization/events retain PostgreSQL scope/CAS/removal", async () => {
 process.loadEnvFile(".env.local");
 const secret = process.env.LIVEBLOCKS_SECRET_KEY;
 check(Boolean(secret), "Liveblocks configuration missing.");
 const fixture = JSON.parse(readFileSync(process.env.FICI_LIVEBLOCKS_FIXTURE!, "utf8")) as { args: string[]; binary: string; a: string; team: string; g1: string; g2: string; g3: string; o1: string };
 state.args = fixture.args; state.binary = fixture.binary;
 const a1 = "00000000-0000-4000-8000-000000006004", a2 = "00000000-0000-4000-8000-000000006005", b1 = "00000000-0000-4000-8000-000000006007", master = "00000000-0000-4000-8000-000000006002";
 const roomId = `affinity:${fixture.a}`;
 const provider = new Liveblocks({ secret: secret! });
 const connections: { leave: () => void }[] = [];
 const received: unknown[] = [], foreign: unknown[] = [];
 let roomCreated = false;
 try {
  const tokenFor = async (actor: string) => {
   state.actor = actor;
   const response = await POST(new Request("http://localhost/api/v1/affinity/collaboration-auth", { method: "POST", body: JSON.stringify({ activityInstanceId: fixture.a }) }));
   check(response.status === 200, "Real provider authorization failed.");
   const body = await response.json() as { data: { token: string } };
   check(typeof body.data?.token === "string", "Provider token missing.");
   check(!JSON.stringify(body).includes(secret!), "Secret exposure detected.");
   const claims = JSON.parse(Buffer.from(body.data.token.split('.')[1], 'base64url').toString()) as { perms?: Record<string,unknown>; uid?: string };
   check(Boolean(claims.perms && Object.keys(claims.perms).length === 1 && Object.keys(claims.perms)[0] === roomId), "Token room scope mismatch.");
   return body.data;
  };
  const token1 = await tokenFor(a1); roomCreated = true;
  const token2 = await tokenFor(a2);
  const room = await provider.getRoom(roomId);
  check(room.defaultAccesses.length === 0 && Object.keys(room.usersAccesses).length === 0 && Object.keys(room.groupsAccesses).length === 0, "Provider room is not private.");
  state.actor = b1;
  for (const body of [{ activityInstanceId: fixture.a }, { activityInstanceId: fixture.a, roomId }, { activityInstanceId: fixture.a, teamId: fixture.team, role: 'MASTER' }]) {
   const response = await POST(new Request("http://localhost/api/v1/affinity/collaboration-auth", { method: "POST", body: JSON.stringify(body) }));
   check(response.status !== 200, "Foreign authorization issued.");
   const json = await response.json() as { data?: unknown };
   check(json.data === undefined, "Foreign response exposed provider data.");
  }
  const client1 = createClient({ authEndpoint: async requested => requested === roomId ? token1 : { error: "forbidden", reason: "Resource unavailable." } });
  const client2 = createClient({ authEndpoint: async requested => requested === roomId ? token2 : { error: "forbidden", reason: "Resource unavailable." } });
  const first = client1.enterRoom(roomId), second = client2.enterRoom(roomId); connections.push(first, second);
  second.room.subscribe("event", ({ event }) => received.push(event));
  await until(() => first.room.getStatus() === 'connected' && second.room.getStatus() === 'connected', "Authorized provider connections unavailable.");
  // Use another real access token scoped exclusively to an isolated fixture room;
  // room knowledge cannot turn it into a grant for Team A.
  const wrongRoom = `affinity:${crypto.randomUUID()}`;
  const wrong = provider.prepareSession(b1); wrong.allow(wrongRoom, ["*:write"]);
  const denialToken = await wrong.authorize();
  check(denialToken.status === 200, "Scoped negative-test token unavailable.");
  const outsider = createClient({ authEndpoint: async () => JSON.parse(denialToken.body) as { token: string } });
  const outsiderConnection = outsider.enterRoom(roomId); connections.push(outsiderConnection);
  outsiderConnection.room.subscribe("event", ({event}) => foreign.push(event));
  first.room.broadcastEvent({ type: 'affinity-test-move', position: 1 });
  await until(() => received.length > 0, "Permitted provider event not delivered.");
  await delay(1200);
  check(outsiderConnection.room.getStatus() !== 'connected' && foreign.length === 0, "Foreign provider event access.");
  state.actor = a1;
  const added = query(`public.add_affinity_item('${JSON.stringify({ affinityGroupId: fixture.g1, developmentObjectId: fixture.o1 })}'::jsonb)`).data as { id: string; move_revision: number };
  check(Boolean(added?.id), "Canonical item creation failed.");
  first.room.broadcastEvent({ type: 'affinity-optimistic', itemId: added.id, position: 1 });
  const phases: string[] = [];
  const moved = await persistCollaborativeAffinityMove({ itemId: added.id, targetGroupId: fixture.g2, position: 1, expectedRevision: added.move_revision }, moveItemToAffinityGroup, phase => phases.push(phase.phase));
  check(phases.join(',') === 'optimistic,persisted', "Persistence acknowledgement mismatch.");
  const reload = query(`public.get_affinity_collaboration_board('${fixture.a}')`).data as { items: { id:string;affinity_group_id:string;move_revision:number }[] };
  check(reload.items.some(i => i.id === moved.id && i.affinity_group_id === fixture.g2 && i.move_revision === moved.move_revision), "Canonical reload mismatch.");
  // Both real provider contexts are connected. Durable contenders use independent
  // database sessions and the same CAS token; exactly one may commit.
  const contend = async (actor: string, group: string) => {
   await delay(0);
   return queryAsync(`public.move_affinity_item('${JSON.stringify({ itemId:moved.id,targetGroupId:group,position:1,expectedRevision:moved.move_revision })}'::jsonb)`,actor);
  };
  const rivals = await Promise.all([contend(a1,fixture.g1),contend(a2,fixture.g3)]);
  check(rivals.filter(v => !v.error).length === 1 && rivals.filter(v => v.error?.code === '40001').length === 1, "Provider-context CAS failed.");
  const winner = rivals.find(v => !v.error)!.data as { id:string;affinity_group_id:string;position:number;move_revision:number };
  first.room.broadcastEvent({ type:'affinity-canonical',itemId:winner.id,position:winner.position,revision:winner.move_revision });
  await until(()=>received.some(event=>typeof event==='object' && event!==null && 'type' in event && event.type==='affinity-canonical' && 'itemId' in event && event.itemId===winner.id && 'revision' in event && event.revision===winner.move_revision),'Canonical provider reconciliation hint not delivered.');
  const canonicalWinner=query(`public.get_affinity_collaboration_board('${fixture.a}')`,a2).data as {items:{id:string;affinity_group_id:string;move_revision:number}[]};
  check(canonicalWinner.items.some(item=>item.id===winner.id && item.affinity_group_id===winner.affinity_group_id && item.move_revision===winner.move_revision),'Fresh PostgreSQL winner/reconciliation mismatch.');

  const beforeFailure = JSON.stringify(query(`public.get_affinity_collaboration_board('${fixture.a}')`,a1).data);
  state.actor = a1;
  try { await createAffinityRoomAuthorizer({ authorize: async () => { throw new Error('private provider internals'); } })({activityInstanceId:fixture.a}); throw new Error('Expected provider failure'); }
  catch(error) { check(error instanceof Error && error.message === 'Collaboration provider unavailable.', "Unsafe provider failure."); }
  check(beforeFailure === JSON.stringify(query(`public.get_affinity_collaboration_board('${fixture.a}')`,a1).data), "Provider failure mutated database.");
  check(!query(`public.remove_team_member('${fixture.team}','${a1}',null)`,master).error, "Canonical removal failed.");
  state.actor = a1;
  for(let attempt=0;attempt<2;attempt++) {
   const response = await POST(new Request("http://localhost/api/v1/affinity/collaboration-auth",{method:'POST',body:JSON.stringify({activityInstanceId:fixture.a})}));
   check(response.status !== 200, "Removed member authorization issued.");
  }
  check(query(`public.move_affinity_item('${JSON.stringify({itemId:winner.id,targetGroupId:fixture.g2,position:1,expectedRevision:winner.move_revision})}'::jsonb)`,a1).error?.code === '42501', "Removed member durable write allowed.");
  let freshDenied = false;
  const freshEvents: unknown[] = [];
  const freshClient = createClient({ authEndpoint: async () => {
   state.actor=a1;
   const response=await POST(new Request("http://localhost/api/v1/affinity/collaboration-auth",{method:'POST',body:JSON.stringify({activityInstanceId:fixture.a})}));
   freshDenied=response.status!==200;
   return {error:"forbidden",reason:"Resource unavailable."};
  }});
  const freshConnection=freshClient.enterRoom(roomId);connections.push(freshConnection);
  freshConnection.room.subscribe('event',({event})=>freshEvents.push(event));
  await until(()=>freshDenied && freshConnection.room.getStatus()!=='connecting', 'Fresh removed-member reconnect not denied.');
  second.room.broadcastEvent({type:'affinity-post-removal',position:1});
  await delay(600);
  check(freshConnection.room.getStatus()!=='connected' && freshEvents.length===0,'Removed fresh session received provider state.');
  // Existing token/socket is not forcibly revoked by this access-token integration.
  // Do not confuse a denied NEW auth with revocation of an unexpired old token.
  check(first.room.getStatus() === 'connected', "Open-session observation changed; inspect provider behavior.");
  state.actor=a2;let raced=false;
  await createAffinityRoomAuthorizer({authorize:async()=>{
   check(!query(`public.remove_team_member('${fixture.team}','${a2}',null)`,master).error,'Race removal failed');
   raced=true;return token2;
  }})({activityInstanceId:fixture.a}).then(()=>{throw Error('Post-removal Affinity grant escaped');},error=>check(error.code==='NOT_FOUND','Unsafe race denial'));
  check(raced&&query(`public.move_affinity_item('${JSON.stringify({itemId:winner.id,targetGroupId:fixture.g2,position:1,expectedRevision:winner.move_revision})}'::jsonb)`,a2).error?.code==='42501','Post-removal Affinity write committed');
  console.log('M11.26 Affinity committed-removal/provider-delivery race and stale-revision canonical write denial PASS');
  console.log('M11.4 real Liveblocks private-room auth/Team B token+event denial/removal new-auth denial/event transport/PostgreSQL CAS/provider failure PASS');
  console.log('M11.4 existing open access-token session remains connected; no immediate socket/token revocation claimed');
 } finally {
  for(const connection of connections) connection.leave();
  if(roomCreated) await provider.deleteRoom(roomId);
 }
});
