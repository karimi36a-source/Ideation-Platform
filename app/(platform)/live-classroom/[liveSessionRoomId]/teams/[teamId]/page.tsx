import {notFound,redirect} from 'next/navigation';
import {createServerSupabaseClient} from '@/lib/db/server';
export const dynamic='force-dynamic';
export default async function TeamBreakoutEntry({params}:{params:Promise<{liveSessionRoomId:string;teamId:string}>}){const {liveSessionRoomId,teamId}=await params,db=await createServerSupabaseClient();const result=await db.rpc('find_team_live_breakout',{parent_room:liveSessionRoomId,target_team:teamId});if(result.error)notFound();if(result.data)redirect(`/breakouts/${result.data}`);return <main><h1>Team breakout</h1><p>The assigned Master has not opened this breakout yet.</p><a href={`/teams/${teamId}`}>Open My Team</a></main>;}
