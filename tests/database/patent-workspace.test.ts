import {spawnSync} from 'node:child_process';
import {join} from 'node:path';
import {expect,it,vi} from 'vitest';
vi.mock('server-only',()=>({}));
const state=vi.hoisted(()=>({userId:'00000000-0000-4000-8000-000000006004',tables:[] as string[]}));
vi.mock('@/lib/auth/authorization',async original=>({...await original<typeof import('@/lib/auth/authorization')>(),getAuthorizationContext:async()=>({userId:state.userId,assignments:[]})}));
vi.mock('@/lib/db/server',()=>({createServerSupabaseClient:async()=>({rpc:async(name:string,args:Record<string,string>)=>{
 if(!['can_read_development_project','get_team_workspace_access','team_workspace_has_chat_access'].includes(name))throw Error('Unexpected RPC');
 return authenticated('select to_jsonb(public.'+name+'('+Object.values(args).map(literal).join(',')+'))');
 },from:(table:string)=>builder(table)})}));
import {getPatentWorkspace} from '@/features/patents/workspace';
function literal(v:string){return "'"+v.replaceAll("'","''")+"'";}
function query(sql:string){const port=process.env.FICI_PATENT_TEST_PORT;if(!port||!/^\d+$/.test(port)||!process.env.POSTGRES_BIN)throw Error('Disposable DB required');const r=spawnSync(join(process.env.POSTGRES_BIN,process.platform==='win32'?'psql.exe':'psql'),['-X','-h','127.0.0.1','-p',port,'-U','postgres','-d','fici_patent_workspace','-v','ON_ERROR_STOP=1','-t','-A','-f','-'],{input:sql,encoding:'utf8',windowsHide:true,timeout:45000});if(r.error||r.status!==0)throw Error('SQL denied');return r.stdout.trim();}
function authenticated(sql:string){try{const out=query("begin;set local role authenticated;select set_config('request.jwt.claim.sub',"+literal(state.userId)+",true);select 'RESULT='||coalesce(("+sql+")::text,'null');commit;");return {data:JSON.parse(out.split(/\r?\n/).find(s=>s.startsWith('RESULT='))!.slice(7)),error:null};}catch{return {data:null,error:{code:'42501'}};}}
function builder(table:string){
 if(!['development_projects','workspaces','patent_records','patent_search_logs','evidence_links','evidence','development_objects','artifacts','artifact_versions','activity_instances'].includes(table))throw Error('Unexpected table');state.tables.push(table);
 let columns='*',single=false;const where:string[]=[];
 const column=(s:string)=>{if(!/^[a-z_,]+$/.test(s))throw Error('Unsafe test column');return s;};
 const b={select:(s:string)=>{columns=s==='*'?'*':column(s);return b;},eq:(k:string,v:string)=>{where.push(column(k)+'='+literal(v));return b;},in:(k:string,v:string[])=>{where.push(column(k)+' in ('+v.map(literal).join(',')+')');return b;},is:(k:string,v:null)=>{if(v!==null)throw Error('Unexpected filter');where.push(column(k)+' is null');return b;},order:()=>b,maybeSingle:()=>{single=true;return b;},then:(resolve:(v:unknown)=>unknown)=>{const q='select '+columns+' from public.'+table+(where.length?' where '+where.join(' and '):'');const r=authenticated("select coalesce(jsonb_agg(to_jsonb(r)),'[]'::jsonb) from ("+q+") r");return Promise.resolve(resolve({...r,data:single?(r.data?.[0]??null):r.data}));}};
 return b;
}
it('M12.15 actual loader uses canonical PostgreSQL data and denies scope attacks before research reads',async()=>{
 const contexts=JSON.parse(query('select jsonb_object_agg(label,payload)::text from public.patent_workspace_context'));
 const fetch=vi.spyOn(globalThis,'fetch').mockRejectedValue(Error('No external source queries'));
 for(const label of ['Team','Individual']){
  const loaded=await getPatentWorkspace(contexts[label].id);expect(loaded.project).toEqual(contexts[label]);expect(loaded.patents).toHaveLength(1);expect(loaded.patents[0]).toEqual(contexts['Patent'+label]);
  if(label==='Team'){expect(loaded.logs[0].query_text).toBe('Private search query');expect(loaded.evidence.map(e=>e.evidence_type).sort()).toEqual(['PATENT','PATENT_CLAIM']);expect(loaded.evidence.find(e=>e.evidence_type==='PATENT_CLAIM')?.claim_locator).toBe(' Claim 7, paragraph 2 ');}
 }
 for(const n of [6001,6002,6003,6006,6007,6008]){state.userId='00000000-0000-4000-8000-'+String(n).padStart(12,'0');state.tables=[];await expect(getPatentWorkspace(contexts.Team.id)).rejects.toMatchObject({code:'NOT_FOUND'});expect(state.tables).not.toContain('patent_records');expect(state.tables).not.toContain('patent_search_logs');}
 state.userId='00000000-0000-4000-8000-000000006005';state.tables=[];await expect(getPatentWorkspace(contexts.Individual.id)).rejects.toMatchObject({code:'NOT_FOUND'});expect(state.tables).not.toContain('patent_records');
 state.userId='00000000-0000-4000-8000-000000006004';
 for(const id of ['bad','00000000-0000-4000-8000-000000099999'])await expect(getPatentWorkspace(id)).rejects.toMatchObject({code:'NOT_FOUND'});
 query("begin;set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);select public.remove_team_member("+literal(contexts.TeamId.id)+","+literal(state.userId)+",null);commit;");
 state.tables=[];await expect(getPatentWorkspace(contexts.Team.id)).rejects.toMatchObject({code:'NOT_FOUND'});expect(state.tables).not.toContain('patent_records');expect((await getPatentWorkspace(contexts.Individual.id)).patents).toHaveLength(1);
 expect(fetch).not.toHaveBeenCalled();fetch.mockRestore();
},150000);
