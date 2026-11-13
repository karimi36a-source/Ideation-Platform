import {notFound,redirect} from 'next/navigation';
import {createServerSupabaseClient} from '@/lib/db/server';
import {getOrCreateLiveSessionRoom} from '@/features/live-classroom/room';

export const dynamic='force-dynamic';
export default async function OpenLiveClassroom({params,searchParams}:{params:Promise<{cohortId:string;sessionDefinitionId:string}>;searchParams:Promise<{unavailable?:string}>}){
 const {cohortId,sessionDefinitionId}=await params;
 const db=await createServerSupabaseClient();
 const authorization=await db.rpc('authorize_master_live_room',{target_cohort:cohortId,target_session:sessionDefinitionId,target_activity:null});
 if(authorization.error||!authorization.data)notFound();
 async function open(){
  'use server';
  let roomId:string|null=null;
  try{roomId=(await getOrCreateLiveSessionRoom({cohortId,sessionDefinitionId})).id;}catch{}
  // The existing operation reauthorizes every invocation, including form replay.
  redirect(roomId?`/live-classroom/${roomId}`:`/cohorts/${cohortId}/live/${sessionDefinitionId}?unavailable=1`);
 }
 return <main><h1>Open live classroom</h1><p>Media participation does not change Activity or Project state.</p>{(await searchParams).unavailable&&<p role="alert">Live classroom unavailable. Check your access or try again.</p>}<form action={open}><button type="submit">Open live classroom</button></form><a href={`/cohorts/${cohortId}/overview`}>Return to Cohort</a></main>;
}
