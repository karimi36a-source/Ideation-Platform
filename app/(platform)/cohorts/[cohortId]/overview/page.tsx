import {notFound} from 'next/navigation';
import {requireProtectedAccount} from '@/lib/auth/protected-account';
import {AuthorizationError} from '@/lib/auth/authorization';
import {getMasterCohortOverview} from '@/features/progress/master-cohort-overview';
import {MasterCohortOverviewView} from '@/features/progress/master-cohort-overview-view';
export const dynamic='force-dynamic';
export default async function MasterCohortOverviewPage({params}:{params:Promise<{cohortId:string}>}){
 await requireProtectedAccount();
 const {cohortId}=await params;
 const state=await getMasterCohortOverview(cohortId).catch(error=>{
  if(error instanceof AuthorizationError&&['FORBIDDEN','VALIDATION_ERROR'].includes(error.code))notFound();
  throw error;
 });
 const sessions=new Map(state.teams.flatMap(team=>team.projects.flatMap(project=>project.activities.map(activity=>[activity.session.id,activity.session.title] as const))));
 return <><nav aria-label="Live classrooms">{[...sessions].map(([id,title])=><a key={id} href={`/cohorts/${cohortId}/live/${id}`}>Open live classroom — {title}</a>)}</nav><MasterCohortOverviewView state={state}/></>;
}
