import {afterEach,beforeEach,expect,it,vi} from 'vitest';
vi.mock('server-only',()=>({}));
const m=vi.hoisted(()=>({origin:'https://example.supabase.co',set:vi.fn(),jar:new Map<string,string>()}));
vi.mock('next/headers',()=>({cookies:async()=>({getAll:()=>[...m.jar].map(([name,value])=>({name,value})),set:m.set})}));
vi.mock('@/lib/validation/env-server',()=>({getServerEnv:()=>({NEXT_PUBLIC_SUPABASE_URL:m.origin,NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY:'sb_publishable_fixture_only'})}));
import {createServerSupabaseClient} from '@/lib/db/server';
const user={id:'00000000-0000-4000-8000-000000006004',aud:'authenticated',email:'pilot@example.test'};
const token=(generation:number)=>{
 const encode=(value:unknown)=>Buffer.from(JSON.stringify(value)).toString('base64url');
 return encode({alg:'HS256',typ:'JWT'})+'.'+encode({sub:user.id,exp:Math.floor(Date.now()/1000)+3600,aud:'authenticated',generation})+'.fixture_signature';
};
beforeEach(()=>{m.jar.clear();m.set.mockReset().mockImplementation((name:string,value:string)=>{if(value)m.jar.set(name,value);else m.jar.delete(name);});});
afterEach(()=>{vi.unstubAllEnvs();vi.unstubAllGlobals();});
function provider(){
 const transport=vi.fn().mockImplementation(async(input:RequestInfo|URL,options?:RequestInit)=>{
  const url=new URL(String(input));
  if(url.pathname.endsWith('/user'))return new Response(JSON.stringify(user),{status:200,headers:{'Content-Type':'application/json'}});
  const generation=url.searchParams.get('grant_type')==='refresh_token'?2:1;
  return new Response(JSON.stringify({access_token:token(generation),refresh_token:'fixture-refresh-'+generation,token_type:'bearer',expires_in:3600,user}),{status:200,headers:{'Content-Type':'application/json'}});
 });
 vi.stubGlobal('fetch',transport);return transport;
}
it('real SSR SDK emits Secure production cookies and preserves refresh rotation across fresh request clients',async()=>{
 vi.stubEnv('NODE_ENV','production');m.origin='https://example.supabase.co';const transport=provider();
 const first=await createServerSupabaseClient();
 expect((await first.auth.signInWithPassword({email:user.email,password:'fixture-password'})).error).toBeNull();
 const before=[...m.jar];expect(before).toHaveLength(1);
 const rotated=await first.auth.refreshSession({refresh_token:'fixture-refresh-1'});
 expect(rotated.error).toBeNull();expect(rotated.data.session?.refresh_token).toBe('fixture-refresh-2');expect([...m.jar]).not.toEqual(before);expect([...m.jar.keys()]).toEqual(before.map(([name])=>name));
 const fresh=await createServerSupabaseClient();expect((await fresh.auth.getUser()).data.user?.id).toBe(user.id);
 const userCall=transport.mock.calls.find(([url])=>String(url).endsWith('/user'));
 expect(new Headers(userCall?.[1]?.headers).get('Authorization')).toBe('Bearer '+rotated.data.session?.access_token);
 for(const [, ,options]of m.set.mock.calls){expect(options).toMatchObject({secure:true,sameSite:'lax',path:'/',httpOnly:false});expect(options.domain).toBeUndefined();}
});
it('real SSR SDK keeps localhost HTTP development cookies writable without Secure',async()=>{
 vi.stubEnv('NODE_ENV','development');m.origin='http://127.0.0.1:54321';provider();
 const client=await createServerSupabaseClient();expect((await client.auth.signInWithPassword({email:user.email,password:'fixture-password'})).error).toBeNull();
 expect(m.jar.size).toBe(1);expect(m.set).toHaveBeenCalled();
 for(const [, ,options]of m.set.mock.calls)expect(options).toMatchObject({secure:false,sameSite:'lax',path:'/',httpOnly:false});
});
