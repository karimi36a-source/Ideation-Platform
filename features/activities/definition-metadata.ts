import 'server-only';
import {z} from 'zod';
import {AuthorizationError,getAuthorizationContext} from '@/lib/auth/authorization';
import {createServerSupabaseClient} from '@/lib/db/server';
const metadata=z.strictObject({id:z.uuid(),name:z.string(),session_definition_id:z.uuid(),method_type:z.string().min(1)});
/** Minimal display identity through M7's instance gate, never definition-table access. */
export async function getActivityDefinitionMetadata(activityInstanceId:unknown){
 const id=z.uuid().parse(activityInstanceId),actor=await getAuthorizationContext(),db=await createServerSupabaseClient();
 const result=await db.rpc('activity_resume_definition_metadata',{target_instance:id});
 const parsed=metadata.safeParse(result.data);
 if(result.error||!parsed.success)throw new AuthorizationError('FORBIDDEN');
 const latest=await db.rpc('can_read_activity_instance',{target_instance:id});
 if(latest.error||latest.data!==true||(await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError('FORBIDDEN');
 return parsed.data;
}
