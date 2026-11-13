import 'server-only';
import {z} from 'zod';
import {getAuthorizationContext,AuthorizationError} from '@/lib/auth/authorization';
import {createServerSupabaseClient} from '@/lib/db/server';
import {revisionStatusSchema} from './revision-status-schema';
async function load(cohortId:string|null){
 const actor=await getAuthorizationContext(),db=await createServerSupabaseClient();
 const {data,error}=await db.rpc('get_revision_status',{target_cohort:cohortId});const result=revisionStatusSchema.safeParse(data);
 if(error||!result.success||(cohortId!==null&&[...result.data.outstanding,...result.data.history].some(i=>i.cohortId!==cohortId||i.drafts.length>0))||(await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError('FORBIDDEN');
 return result.data;
}
export async function getMyRevisionStatus(input:unknown={}){
 if(!z.strictObject({}).safeParse(input).success)throw new AuthorizationError('VALIDATION_ERROR');return load(null);
}
export async function getMasterRevisionStatus(cohortId:unknown){
 const id=z.uuid().safeParse(cohortId);if(!id.success)throw new AuthorizationError('VALIDATION_ERROR');return load(id.data);
}
