import {getLiveClassroomView} from '@/features/live-classroom/classroom';
import {LiveClassroom} from '@/features/live-classroom/classroom-view';
export const dynamic='force-dynamic';
async function load(input:unknown){try{return await getLiveClassroomView(input);}catch{return null;}}
export default async function LiveClassroomPage({params,searchParams}:{params:Promise<{liveSessionRoomId:string}>;searchParams:Promise<{activityInstanceId?:string}>}){
 const {liveSessionRoomId}=await params,query=await searchParams;
 const state=await load({liveSessionRoomId,...(query.activityInstanceId?{activityInstanceId:query.activityInstanceId}:{})});
 if(!state)return <main><h1>Live classroom</h1><p role="alert">Live classroom unavailable. Check your access or try again.</p><a href="/current-work">Return to current work</a></main>;
 return <LiveClassroom key={state.liveSessionRoomId} state={state}/>;
}

