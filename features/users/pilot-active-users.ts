import 'server-only';
import {z} from 'zod';
import {createServerSupabaseClient} from '@/lib/db/server';
import {AuthorizationError,defineScopedRolePolicy,requireAdminScope} from '@/lib/auth/authorization';

const inputSchema=z.strictObject({organizationId:z.uuid()});
export const pilotActiveUserSchema=z.strictObject({id:z.uuid(),display_name:z.string().nullable(),email:z.string().nullable(),account_status:z.literal('active')});
export type PilotActiveUser=z.infer<typeof pilotActiveUserSchema>;
const rosterSchema=z.array(pilotActiveUserSchema).refine(rows=>new Set(rows.map(r=>r.id)).size===rows.length);
const adminPolicy=defineScopedRolePolicy({role:'ADMIN',scopeType:'organization',access:'operational'},async id=>{
 const db=await createServerSupabaseClient();
 const result=await db.from('organizations').select('id,status').eq('id',id).maybeSingle();
 const row=z.object({id:z.uuid(),status:z.literal('active')}).safeParse(result.data);
 return result.error||!row.success||row.data.id!==id?null:{id,scope:{type:'organization',id},access:'operational',resourcePolicyAllows:true};
});
/** Pilot roster only. Caller-bound RPC, no profile enumeration or service key. */
export async function listPilotActiveUsers(input:unknown):Promise<PilotActiveUser[]>{
 const parsed=inputSchema.safeParse(input);if(!parsed.success)throw new AuthorizationError('VALIDATION_ERROR');
 const before=await requireAdminScope(adminPolicy,parsed.data.organizationId);
 const db=await createServerSupabaseClient();
 const result=await db.rpc('list_pilot_active_users',{target_organization:before.resource.id});
 const rows=rosterSchema.safeParse(result.data);
 if(result.error||!rows.success)throw new AuthorizationError('FORBIDDEN');
 const after=await requireAdminScope(adminPolicy,parsed.data.organizationId);
 if(after.context.userId!==before.context.userId)throw new AuthorizationError('FORBIDDEN');
 return rows.data;
}
