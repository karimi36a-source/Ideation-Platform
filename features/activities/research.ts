import 'server-only';
import {z} from 'zod';
import {AuthorizationError,getAuthorizationContext} from '@/lib/auth/authorization';
import {createServerSupabaseClient} from '@/lib/db/server';
import {ActivityOutputStateError} from './outputs';
import {addActivityResearchReferenceSchema,activityResearchLinkSchema} from './research-schema';
/** Only canonical IDs. The database resolves scope, actor and source authorization. */
export async function addActivityResearchReference(input:unknown){
 try{
 const before=await getAuthorizationContext();
 const parsed=addActivityResearchReferenceSchema.safeParse(input);
 if(!parsed.success)throw new AuthorizationError('VALIDATION_ERROR');
 const v=parsed.data,db=await createServerSupabaseClient();
 if((await getAuthorizationContext()).userId!==before.userId)throw new AuthorizationError('NOT_FOUND');
 const {data,error}=await db.rpc('add_activity_research_reference',{target_instance:v.activityInstanceId,target_type:v.entityType,target_entity:v.entityId});
 const after=await getAuthorizationContext();
 if(after.userId!==before.userId)throw new AuthorizationError('NOT_FOUND');
 if(error){if(error.code==='55000')throw new ActivityOutputStateError();throw new AuthorizationError(error.code==='28000'?'AUTH_REQUIRED':'NOT_FOUND');}
 const row=activityResearchLinkSchema.safeParse(data);
 if(!row.success||row.data.activity_instance_id!==v.activityInstanceId||row.data.entity_id!==v.entityId||row.data.entity_type!==v.entityType)throw new AuthorizationError('NOT_FOUND');
 return row.data;
 }catch(error){if(error instanceof ActivityOutputStateError)throw new ActivityOutputStateError();throw new AuthorizationError(error instanceof AuthorizationError&&(error.code==='AUTH_REQUIRED'||error.code==='VALIDATION_ERROR')?error.code:'NOT_FOUND');}
}
/** Authorized prior outputs for later Activity contexts; no copied input/source rows. */
export async function listActivityResearchReferences(activityInstanceId:unknown){
 try{
 const before=await getAuthorizationContext();
 const parsed=z.uuid().safeParse(activityInstanceId);
 if(!parsed.success)throw new AuthorizationError('VALIDATION_ERROR');
 const db=await createServerSupabaseClient();
 const {data:allowed,error:authError}=await db.rpc('can_read_activity_instance',{target_instance:parsed.data});
 if(authError||!allowed)throw new AuthorizationError('NOT_FOUND');
 const {data,error}=await db.from('activity_research_links').select('*').eq('activity_instance_id',parsed.data).order('created_at').order('id');
 const rows=z.array(activityResearchLinkSchema).safeParse(data);
 const after=await getAuthorizationContext();
 const {data:stillAllowed,error:lastError}=await db.rpc('can_read_activity_instance',{target_instance:parsed.data});
 if(error||!rows.success||rows.data.some(r=>r.activity_instance_id!==parsed.data)||after.userId!==before.userId||lastError||!stillAllowed)throw new AuthorizationError('NOT_FOUND');
 return rows.data;
 }catch(error){throw new AuthorizationError(error instanceof AuthorizationError&&(error.code==='AUTH_REQUIRED'||error.code==='VALIDATION_ERROR')?error.code:'NOT_FOUND');}
}
