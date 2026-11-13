import {notFound} from 'next/navigation';
import {getTeamPortal} from '@/features/teams/portal';
export const dynamic='force-dynamic';
export default async function TeamPortalPage({params}:{params:Promise<{teamId:string}>}){
 const {teamId}=await params;const state=await getTeamPortal(teamId).catch(()=>notFound());
 return <main><h1>{state.team.name} — Team Portal</h1><p>Private Team Workspace</p><a href="/current-work">Open Current Activity</a>
 <section><h2>Team Project</h2>{state.projects.length?state.projects.map(project=><article key={project.id}><h3>{project.name}</h3><a href={`/projects/${project.id}/patents`}>Open Project patent research</a></article>):<p>No current authorized Project.</p>}</section>
 <section><h2>Team Activities and tools</h2>{state.activities.map(activity=><article key={activity.id}><h3>{activity.name}</h3><p>Status: {activity.status}</p><a href={activity.href}>Open Activity: {activity.name}</a></article>)}</section>
 <section><h2>Additional tools</h2><p>Brainstorming, SCAMPER, Voting/Affinity, Team Chat and Files: DEFERRED UI. Their existing canonical authorization/services remain in place; no browser tool route is available here.</p></section>
 </main>;
}
