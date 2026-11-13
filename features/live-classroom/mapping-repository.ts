import 'server-only';
import {z} from 'zod';
import {requireActivePlatformUser} from '@/features/users/service';
import {liveRoomMappingSchema} from './mapping-schema';
const context={cohortId:z.uuid(),sessionDefinitionId:z.uuid(),provider:z.literal('DAILY')};
const ref=z.string().regex(/^[A-Za-z0-9_-]{1,128}$/);
const commandSchema=z.discriminatedUnion('command',[
 z.strictObject({...context,command:z.literal('REUSE_OR_CREATE'),providerRoomRef:ref}),
 z.strictObject({...context,command:z.literal('REPLACE'),providerRoomRef:ref,expectedRoomId:z.uuid()}),
 z.strictObject({...context,command:z.literal('EXPIRE'),expectedRoomId:z.uuid()}),
]);
type MappingArgs={command:string;target_cohort:string;target_session:string;target_provider:string;room_reference:string|null;actor:string;expected_room:string|null};
type MappingPort={rpc:(name:'manage_live_room_mapping',args:MappingArgs)=>PromiseLike<{data:unknown;error:unknown}>};
/** Internal persistence seam, not a Server Action/API. Supply a privileged
 * server DB port only after domain authorization (M16.3+). This repository
 * neither grants source access nor creates provider rooms/tokens. */
export function createLiveRoomMappingRepository(db:MappingPort){
 return Object.freeze({async findActive(input:unknown){
  const parsed=z.strictObject(context).safeParse(input);if(!parsed.success)throw new Error('Invalid live room mapping input.');
  const user=await requireActivePlatformUser();const v=parsed.data;
  try{
   const {data,error}=await db.rpc('manage_live_room_mapping',{command:'FIND_ACTIVE',target_cohort:v.cohortId,target_session:v.sessionDefinitionId,target_provider:v.provider,room_reference:null,actor:user.id,expected_room:null});
   if(error)throw new Error();if(data===null)return null;
   const row=liveRoomMappingSchema.parse(data);
   if(row.cohort_id!==v.cohortId||row.session_definition_id!==v.sessionDefinitionId||row.provider!==v.provider||row.status!=='ACTIVE')throw new Error();
   return row;
  }catch{throw new Error('Live room mapping unavailable.');}
 },async write(input:unknown){
  const parsed=commandSchema.safeParse(input);if(!parsed.success)throw new Error('Invalid live room mapping input.');
  const user=await requireActivePlatformUser();const v=parsed.data;
  let response:Awaited<ReturnType<MappingPort['rpc']>>;
  try{response=await db.rpc('manage_live_room_mapping',{command:v.command,target_cohort:v.cohortId,target_session:v.sessionDefinitionId,target_provider:v.provider,room_reference:'providerRoomRef' in v?v.providerRoomRef:null,actor:user.id,expected_room:'expectedRoomId' in v?v.expectedRoomId:null});}
  catch{throw new Error('Live room mapping unavailable.');}
  const {data,error}=response;
  if(error)throw new Error('Live room mapping unavailable.');
  const result=liveRoomMappingSchema.safeParse(data);
  if(!result.success||result.data.cohort_id!==v.cohortId||result.data.session_definition_id!==v.sessionDefinitionId||result.data.provider!==v.provider||(v.command==='EXPIRE'?(result.data.id!==v.expectedRoomId||result.data.status!=='EXPIRED'):result.data.status!=='ACTIVE')||(v.command==='REPLACE'&&result.data.provider_room_ref!==v.providerRoomRef))throw new Error('Live room mapping unavailable.');
  return result.data;
 }});
}
