import 'server-only';
import {z} from 'zod';
import {getAuthorizationContext,AuthorizationError} from '@/lib/auth/authorization';
import {createServerSupabaseClient} from '@/lib/db/server';
import {masterCohortOverviewSchema} from './master-cohort-overview-schema';
/** No caller identity/scope override. The DB rechecks the canonical assignment. */
export async function getMasterCohortOverview(cohortId:unknown){
 const before=await getAuthorizationContext();
 const input=z.uuid().safeParse(cohortId);if(!input.success)throw new AuthorizationError('VALIDATION_ERROR');
 const db=await createServerSupabaseClient();
 const {data,error}=await db.rpc('get_master_cohort_overview',{target_cohort:input.data});
 const result=masterCohortOverviewSchema.safeParse(data);
 if(error||!result.success||result.data.cohort.id!==input.data)throw new AuthorizationError('FORBIDDEN');
 const after=await getAuthorizationContext();
 if(after.userId!==before.userId)throw new AuthorizationError('FORBIDDEN');
 return result.data;
}

