import {z} from 'zod';
export const classroomInputSchema=z.strictObject({liveSessionRoomId:z.uuid(),activityInstanceId:z.uuid().optional()});
export const classroomContextSchema=z.strictObject({liveSessionRoomId:z.uuid(),cohortId:z.uuid(),cohortName:z.string(),sessionDefinitionId:z.uuid(),sessionTitle:z.string()});
export type ClassroomActivity={activityInstanceId:string;activityType:string;name:string;status:string;href:string;projectName:string|null;teamName:string|null};
export type ClassroomView={liveSessionRoomId:string;cohortName:string;sessionTitle:string;activity:ClassroomActivity|null;activityCandidates?:ClassroomActivity[];teams?:{id:string;name:string;href:string}[];masterBreakoutsHref?:string;breakoutRoomId?:string};
export function safeDailyRoomUrl(value:string,roomRef:string){
 const url=new URL(value);
 if(url.protocol!=='https:'||!url.hostname.endsWith('.daily.co')||url.username||url.password||url.port||url.search||url.hash||url.pathname!=='/'+roomRef)throw Error('Unavailable');
 return url.href;
}

