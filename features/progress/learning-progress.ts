import 'server-only';
import {z} from 'zod';
import {getAuthorizationContext,AuthorizationError} from '@/lib/auth/authorization';
import {createServerSupabaseClient} from '@/lib/db/server';
import {getMyCurrentWork} from './current-work';
import {learningProgressCountsSchema,myLearningProgressSchema,type MyLearningProgress} from './learning-progress-schema';
/** Factual per-execution-context learning counts; no recommendation or state writes. */
export async function getMyLearningProgress(input:unknown={}):Promise<MyLearningProgress>{
 if(!z.strictObject({}).safeParse(input).success)throw new AuthorizationError('VALIDATION_ERROR');
 const actor=await getAuthorizationContext(),db=await createServerSupabaseClient();
 const work=await getMyCurrentWork();const contexts:MyLearningProgress['contexts']=[];
 for(const c of work.contexts){
  const result=await db.rpc('get_my_learning_progress',{target_project:c.project.id,target_workspace:c.workspace.id,target_cohort:c.cohort.id,target_team:c.team?.id??null});
  if(result.error)throw new AuthorizationError('FORBIDDEN');
  if(result.data===null)continue; // Canonical scope lost since initial discovery.
  const parsed=learningProgressCountsSchema.safeParse(result.data);
  if(!parsed.success)throw new AuthorizationError('FORBIDDEN');
  const currentSessions=[...new Map(c.activities.filter(a=>a.availability.available||a.status!==null&&['active','submitted','under_review','revision_requested'].includes(a.status)).map(a=>[a.session.id,a.session])).values()];
  contexts.push({id:c.id,enrollmentId:c.enrollmentId,course:c.course,cohort:c.cohort,project:c.project,workspace:c.workspace,team:c.team,currentSessions,progress:parsed.data});
 }
 // Reuse canonical scope discovery on return; IDs never establish authority.
 const visible=new Set((await getMyCurrentWork()).contexts.map(c=>c.id));
 if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError('FORBIDDEN');
 return myLearningProgressSchema.parse({contexts:contexts.filter(c=>visible.has(c.id))});
}
