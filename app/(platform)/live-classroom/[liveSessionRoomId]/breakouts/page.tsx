import {notFound,redirect} from 'next/navigation';
import {getMasterBreakoutTeams,getOrCreateTeamBreakout} from '@/features/live-classroom/breakout';
export const dynamic='force-dynamic';
export default async function MasterBreakouts({params}:{params:Promise<{liveSessionRoomId:string}>}){
 const {liveSessionRoomId}=await params;const teams=await getMasterBreakoutTeams(liveSessionRoomId).catch(()=>notFound());
 return <main><h1>Team breakouts</h1><a href={`/live-classroom/${liveSessionRoomId}`}>Return to Cohort classroom</a>{teams.map(team=>{
  async function open(){'use server';const room=await getOrCreateTeamBreakout({liveSessionRoomId,teamId:team.id});redirect(`/breakouts/${room.id}`);}
  return <section key={team.id}><h2>{team.name}</h2><form action={open}><button type="submit">Open breakout: {team.name}</button></form><a href={`/teams/${team.id}`}>Open Team Portal: {team.name}</a></section>;
 })}</main>;
}
