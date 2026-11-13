import 'server-only';
import {createClient} from '@supabase/supabase-js';
import {getServerEnv} from '@/lib/validation/env-server';
import type {Database} from '@/lib/db/database.types';
import {aiPromptTemplateSchema,aiPromptRoleSchema} from './prompt-template-schema';
import {activityMethodSchema} from '@/features/activities/schema';
/** Narrow privileged read only. Never use this client to load caller context. */
export async function resolveActiveAiPromptTemplate(role:unknown,activity:unknown){
 const role0=aiPromptRoleSchema.parse(role),activity0=activityMethodSchema.parse(activity),env=getServerEnv();
 if(!env.SUPABASE_SECRET_KEY)throw Error('Active template unavailable');
 const db=createClient<Database>(env.NEXT_PUBLIC_SUPABASE_URL,env.SUPABASE_SECRET_KEY,{auth:{persistSession:false,autoRefreshToken:false},global:{fetch:(url,options)=>fetch(url,{...options,signal:AbortSignal.timeout(15000),redirect:'error',cache:'no-store'})}});
 const r=await db.rpc('read_active_ai_prompt_template',{role0,activity0});
 if(r.error)throw Error('Active template unavailable');
 const t=aiPromptTemplateSchema.parse(r.data);
 if(t.status!=='active'||t.role_code!==role0||t.activity_type!==activity0)throw Error('Active template unavailable');
 return t;
}
