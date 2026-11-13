import 'server-only';
import {observeDatabase,setLogContext,withOperationLog} from '@/lib/observability/structured-log';
import {z} from 'zod';
import {getAuthorizationContext,AuthorizationError} from '@/lib/auth/authorization';
import {createServerSupabaseClient} from '@/lib/db/server';
import {getActivityDefinitionMetadata} from '@/features/activities/definition-metadata';
import {listLiveCurrentActivityIds} from './current-activity';
import {getMyCohortTeams} from '@/features/teams/portal';
import {getLiveSessionJoinToken} from './join-token';
import {createLiveClassroomProvider} from './factory';
import {classroomInputSchema,classroomContextSchema,safeDailyRoomUrl,type ClassroomView} from './classroom-schema';
const joinContext=z.object({liveSessionRoomId:z.uuid(),providerRoomRef:z.string(),userId:z.uuid()});
/** Read-only page data. Activity/Project/Team use their ordinary caller RLS and
 * authorization independently; media membership never grants content access. */
export async function getLiveClassroomView(input:unknown):Promise<ClassroomView>{
 const v=classroomInputSchema.parse(input),actor=await getAuthorizationContext(),db=await createServerSupabaseClient();
 const resolve=async()=>{const r=await db.rpc('get_live_classroom_context',{target_room:v.liveSessionRoomId});if(r.error)throw new AuthorizationError('FORBIDDEN');const c=classroomContextSchema.parse(r.data);if(c.liveSessionRoomId!==v.liveSessionRoomId)throw new AuthorizationError('FORBIDDEN');return c;};
 const context=await resolve();
 const candidateIds=v.activityInstanceId?[v.activityInstanceId]:await listLiveCurrentActivityIds({cohortId:context.cohortId,sessionDefinitionId:context.sessionDefinitionId});
 async function loadActivity(activityInstanceId:string){
  const allowed=await db.rpc('can_read_activity_instance',{target_instance:activityInstanceId});
  if(allowed.error||allowed.data!==true)throw new AuthorizationError('FORBIDDEN');
  const r=await db.from('activity_instances').select('id,cohort_id,activity_definition_id,project_id,team_id,status').eq('id',activityInstanceId).maybeSingle();
  const a=z.object({id:z.uuid(),cohort_id:z.uuid(),activity_definition_id:z.uuid(),project_id:z.uuid(),team_id:z.uuid().nullable(),status:z.string()}).parse(r.data);
  if(r.error||a.id!==activityInstanceId||a.cohort_id!==context.cohortId||a.status==='archived')throw new AuthorizationError('FORBIDDEN');
  const definition=await getActivityDefinitionMetadata(a.id);
  if(definition.id!==a.activity_definition_id||definition.session_definition_id!==context.sessionDefinitionId)throw new AuthorizationError('FORBIDDEN');
  const p=await db.from('development_projects').select('name').eq('id',a.project_id).maybeSingle();
  const t=a.team_id?await db.from('teams').select('name').eq('id',a.team_id).maybeSingle():null;
  const activity={activityInstanceId:a.id,activityType:definition.method_type,name:definition.name,status:a.status,href:definition.method_type==='mind_map'?`/activities/${a.id}/mind-map`:'/current-work',projectName:!p.error&&typeof p.data?.name==='string'?p.data.name:null,teamName:t&&!t.error&&typeof t.data?.name==='string'?t.data.name:null};
  const latest=await db.rpc('can_read_activity_instance',{target_instance:a.id});if(latest.error||latest.data!==true)throw new AuthorizationError('FORBIDDEN');
  return activity;
 }
 const activities=[];for(const id of candidateIds)activities.push(await loadActivity(id));
 const activity=activities.length===1?activities[0]:null;
 if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError('FORBIDDEN');
 const teams=await getMyCohortTeams(context.cohortId);
 const master=actor.assignments?.some(a=>a.roleCode==='MASTER'&&a.cohort_id===context.cohortId);
 await resolve();return {liveSessionRoomId:context.liveSessionRoomId,cohortName:context.cohortName,sessionTitle:context.sessionTitle,activity,...(activities.length>1?{activityCandidates:activities}:{}),...(teams.length?{teams}:{}),...(master?{masterBreakoutsHref:`/live-classroom/${context.liveSessionRoomId}/breakouts`}:{})};
}
/** POST-only transport, never a canonical token store. Only M16.5 issues tokens. */
export async function getLiveClassroomJoin(input:unknown){
 return withOperationLog('LIVE_JOIN',async()=>{
 const v=z.strictObject({liveSessionRoomId:z.uuid()}).parse(input),actor=await getAuthorizationContext(),db=await createServerSupabaseClient();
 setLogContext({actorId:actor.userId});
 const authorize=async()=>{const r=await observeDatabase('authorize_live_session_join',()=>db.rpc('authorize_live_session_join',{target_room:v.liveSessionRoomId}));if(r.error)throw new AuthorizationError('FORBIDDEN');const c=joinContext.parse(r.data);if(c.userId!==actor.userId||c.liveSessionRoomId!==v.liveSessionRoomId)throw new AuthorizationError('FORBIDDEN');return c;};
 const ctx=await authorize();setLogContext({liveSessionRoomId:ctx.liveSessionRoomId,provider:'DAILY'});const status=await createLiveClassroomProvider().getRoomStatus(ctx.providerRoomRef);
 if(!status.success||status.data.status!=='available'||!status.data.url)throw Error('Unavailable');
 const url=safeDailyRoomUrl(status.data.url,ctx.providerRoomRef);
 const capability=await getLiveSessionJoinToken(v);
 const latest=await authorize();if(latest.providerRoomRef!==ctx.providerRoomRef||(await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError('FORBIDDEN');
 return {url,token:capability.token,expiresAt:capability.expiresAt};
 });
}


