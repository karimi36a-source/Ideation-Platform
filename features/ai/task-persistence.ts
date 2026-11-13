import 'server-only';
import {createClient} from '@supabase/supabase-js';
import {getServerEnv} from '@/lib/validation/env-server';
import type {Database} from '@/lib/db/database.types';
/** This client calls only narrow runtime RPCs, never caller-context SELECTs. */
export function createAiTaskPersistenceClient(){
 const env=getServerEnv();if(!env.SUPABASE_SECRET_KEY)throw Error('Task storage unavailable');
 return createClient<Database>(env.NEXT_PUBLIC_SUPABASE_URL,env.SUPABASE_SECRET_KEY,{auth:{persistSession:false,autoRefreshToken:false},global:{fetch:(url,options)=>fetch(url,{...options,signal:AbortSignal.timeout(15000),redirect:'error',cache:'no-store'})}});
}
