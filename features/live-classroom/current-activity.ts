import 'server-only';
import {z} from 'zod';
import {getAuthorizationContext,AuthorizationError} from '@/lib/auth/authorization';
import {createServerSupabaseClient} from '@/lib/db/server';
import {getMyCurrentWork} from '@/features/progress/current-work';
import {getActivityDefinitionMetadata} from '@/features/activities/definition-metadata';
import {resumeActivity} from '@/features/activities/resume';
import type {ActivityInstance} from '@/features/activities/instance-schema';
const inputSchema=z.strictObject({cohortId:z.uuid(),sessionDefinitionId:z.uuid()});
// M15's in-progress execution states; no new state or priority is persisted.
const current=new Set<ActivityInstance['status']>(['active','submitted','under_review','revision_requested']);
/** Discover candidates, never start or choose between concurrent executions.
 * Student candidates come from M15. Master discovery uses ordinary caller RLS;
 * an assignment is a discovery filter, never a grant to private Team work. */
export async function listLiveCurrentActivityIds(input:unknown):Promise<string[]>{
 const scope=inputSchema.parse(input),actor=await getAuthorizationContext();
 const own=await getMyCurrentWork();
 const ids=own.contexts.filter(c=>c.cohort.id===scope.cohortId).flatMap(c=>c.activities.filter(a=>a.session.id===scope.sessionDefinitionId&&a.instanceId!==null&&a.status!==null&&current.has(a.status)).map(a=>a.instanceId!));
 const db=await createServerSupabaseClient();
 if(actor.assignments.some(a=>a.roleCode==='MASTER'&&a.cohort_id===scope.cohortId)){
  const definitions=[];
  for(let offset=0;;offset+=200){const page=await db.from('activity_definitions').select('id,sequence').eq('session_definition_id',scope.sessionDefinitionId).eq('status','active').order('sequence').order('id').range(offset,offset+199);if(page.error)throw new AuthorizationError('FORBIDDEN');const rows=z.array(z.object({id:z.uuid(),sequence:z.number()})).parse(page.data);definitions.push(...rows);if(rows.length<200)break;}
  for(const d of definitions){
   for(let offset=0;;offset+=200){const page=await db.from('activity_instances').select('id').eq('cohort_id',scope.cohortId).eq('activity_definition_id',d.id).in('status',[...current]).order('id').range(offset,offset+199);if(page.error)throw new AuthorizationError('FORBIDDEN');const rows=z.array(z.object({id:z.uuid()})).parse(page.data);ids.push(...rows.map(r=>r.id));if(rows.length<200)break;}
  }
 }
 const result:string[]=[];
 for(const id of new Set(ids)){
  // Canonical M7 read-only resume is independently authoritative at resolution.
  try{const state=await resumeActivity(id);if(state.activity.cohort_id!==scope.cohortId||!current.has(state.activity.status))continue;
   const d=await getActivityDefinitionMetadata(id);
   if(d.id===state.activity.activity_definition_id&&d.session_definition_id===scope.sessionDefinitionId)result.push(id);
  }catch{/* A candidate that lost access must not appear. */}
 }
 if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError('FORBIDDEN');
 return result;
}

