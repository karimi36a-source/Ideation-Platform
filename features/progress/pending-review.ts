import 'server-only';
import {z} from 'zod';
import {getAuthorizationContext,AuthorizationError} from '@/lib/auth/authorization';
import {createServerSupabaseClient} from '@/lib/db/server';
import {pendingReviewQueueSchema} from './pending-review-schema';
/** Cohort is a requested filter, never authority. M8 authorizes every item in PostgreSQL. */
export async function getPendingReviewQueue(cohortId:unknown){
 const before=await getAuthorizationContext();
 const id=z.uuid().safeParse(cohortId);if(!id.success)throw new AuthorizationError('VALIDATION_ERROR');
 const db=await createServerSupabaseClient();
 const {data,error}=await db.rpc('get_pending_review_queue',{target_cohort:id.data});
 const result=pendingReviewQueueSchema.safeParse(data);
 if(error||!result.success||result.data.items.some(item=>item.cohortId!==id.data))throw new AuthorizationError('FORBIDDEN');
 if((await getAuthorizationContext()).userId!==before.userId)throw new AuthorizationError('FORBIDDEN');
 return result.data;
}
