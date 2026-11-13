import 'server-only';
import {z} from 'zod';
import {getAuthorizationContext,AuthorizationError} from '@/lib/auth/authorization';
import {createServerSupabaseClient} from '@/lib/db/server';
import {getMyCurrentWork} from '@/features/progress/current-work';
import {getActivityDefinitionMetadata} from '@/features/activities/definition-metadata';
import {getWorkspaceAccess} from '@/features/workspaces/access';
const teamSchema=z.object({id:z.uuid(),name:z.string(),workspace_id:z.uuid(),cohort_id:z.uuid(),status:z.enum(['created','active']),archived_at:z.null()});
async function memberTeam(teamId:string){
 const db=await createServerSupabaseClient();const row=await db.from('teams').select('id,name,workspace_id,cohort_id,status,archived_at').eq('id',teamId).maybeSingle();
 const team=teamSchema.safeParse(row.data);if(row.error||!team.success)throw new AuthorizationError('FORBIDDEN');
 const level=await db.rpc('get_team_workspace_access',{target_workspace:team.data.workspace_id});
 if(level.error||!['member','team_lead'].includes(String(level.data)))throw new AuthorizationError('FORBIDDEN');
 return team.data;
}
/** All current candidates, following M15's existing multi-context convention. */
export async function getMyCohortTeams(cohortId:unknown){
 const id=z.uuid().parse(cohortId),actor=await getAuthorizationContext(),db=await createServerSupabaseClient();
 const result=[];
 for(let offset=0;;offset+=200){const page=await db.from('teams').select('id').eq('cohort_id',id).in('status',['created','active']).is('archived_at',null).order('id').range(offset,offset+199);if(page.error)throw new AuthorizationError('FORBIDDEN');const rows=z.array(z.object({id:z.uuid()})).parse(page.data);
  for(const candidate of rows){try{const team=await memberTeam(candidate.id);if(team.cohort_id===id)result.push({id:team.id,name:team.name,href:`/teams/${team.id}`});}catch(error){if(!(error instanceof AuthorizationError))throw error;}}
  if(rows.length<200)break;
 }
 if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError('FORBIDDEN');
 // Recheck memberships after discovery; never return a stale selected Team.
 for(const team of result)await memberTeam(team.id);
 return result;
}
export async function getTeamPortal(teamId:unknown){
 const id=z.uuid().parse(teamId),actor=await getAuthorizationContext(),team=await memberTeam(id);
 const access=await getWorkspaceAccess(team.workspace_id);if(!access.canView)throw new AuthorizationError('FORBIDDEN');
 const work=await getMyCurrentWork();const contexts=work.contexts.filter(c=>c.team?.id===team.id&&c.workspace.id===team.workspace_id&&c.cohort.id===team.cohort_id);
 const activities=[];
 for(const context of contexts)for(const a of context.activities){if(!a.instanceId||a.status==='archived')continue;const definition=await getActivityDefinitionMetadata(a.instanceId);if(definition.id!==a.definition.id||definition.session_definition_id!==a.session.id)throw new AuthorizationError('FORBIDDEN');activities.push({id:a.instanceId,name:definition.name,status:a.status,href:definition.method_type==='mind_map'?`/activities/${a.instanceId}/mind-map`:'/current-work'});}
 await memberTeam(id);if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError('FORBIDDEN');
 return {team:{id:team.id,name:team.name,cohortId:team.cohort_id},workspaceId:team.workspace_id,projects:contexts.map(c=>c.project).filter((p,i,all)=>all.findIndex(x=>x.id===p.id)===i),activities:activities.filter((a,i,all)=>all.findIndex(x=>x.id===a.id)===i),canAccessChat:access.canAccessChat};
}
