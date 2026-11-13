import {notFound} from 'next/navigation';
import {getBreakoutContext} from '@/features/live-classroom/breakout';
import {getTeamPortal} from '@/features/teams/portal';
import {LiveClassroom} from '@/features/live-classroom/classroom-view';
export const dynamic='force-dynamic';
export default async function BreakoutPage({params}:{params:Promise<{breakoutRoomId:string}>}){
 const {breakoutRoomId}=await params,c=await getBreakoutContext(breakoutRoomId).catch(()=>notFound());
 const portal=c.participantRole==='STUDENT'?await getTeamPortal(c.teamId).catch(()=>notFound()):null;
 return <><nav><a href={`/teams/${c.teamId}`}>Open Team Portal</a><a href="/current-work">Open Current Activity</a>{portal?.projects.map(project=><a key={project.id} href={`/projects/${project.id}/patents`}>Open Project patent research: {project.name}</a>)}</nav><LiveClassroom state={{liveSessionRoomId:c.liveSessionRoomId,cohortName:'Authorized Cohort',sessionTitle:portal?`${portal.team.name} breakout`:'Team breakout',activity:null,breakoutRoomId:c.breakoutRoomId,...(portal?{teams:[{id:portal.team.id,name:portal.team.name,href:`/teams/${portal.team.id}`}]}:{})}}/></>;
}
