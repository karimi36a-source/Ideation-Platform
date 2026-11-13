import {beforeEach,expect,it,vi} from 'vitest';
vi.mock('server-only',()=>({}));
const m=vi.hoisted(()=>({rpc:vi.fn(),client:vi.fn(),env:vi.fn()}));
vi.mock('@supabase/supabase-js',()=>({createClient:m.client}));
vi.mock('@/lib/validation/env-server',()=>({getServerEnv:m.env}));
import {resolveActiveAiPromptTemplate} from '@/features/ai/active-template';
import {getAiTaskDefinition} from '@/features/ai/task-registry';
const row:Record<string,unknown>={id:'00000000-0000-4000-8000-000000000007',role_code:'STRUCTURED_CREATIVITY_ASSISTANT',activity_type:'scamper',version:2,status:'active',system_instruction:'FICI rules',task_template:'SCAMPER task',output_schema:getAiTaskDefinition('SCAMPER_ASSISTANCE').outputSchema,created_by:'00000000-0000-4000-8000-000000000001',created_at:'2026-11-03T12:00:00Z'};
const load=():Promise<unknown>=>resolveActiveAiPromptTemplate(row.role_code,row.activity_type);
beforeEach(()=>{vi.resetAllMocks();m.client.mockReturnValue({rpc:m.rpc});m.env.mockReturnValue({NEXT_PUBLIC_SUPABASE_URL:'https://example.test',SUPABASE_SECRET_KEY:'mock-private-credential'});m.rpc.mockResolvedValue({data:row,error:null});});
it('reads exact active canonical row through server-only narrow RPC, without session persistence',async()=>{expect(await load()).toEqual(row as unknown);expect(m.rpc).toHaveBeenCalledWith('read_active_ai_prompt_template',{role0:row.role_code,activity0:row.activity_type});expect(m.client.mock.calls[0][2].auth).toEqual({persistSession:false,autoRefreshToken:false});});
it.each([{status:'inactive'},{role_code:'CRITICAL_REVIEWER',activity_type:'review'},{activity_type:'brainstorming'},{version:0},{output_schema:{type:'string'}}])('rejects invalid active row %#',async change=>{m.rpc.mockResolvedValue({data:{...row,...change},error:null});await expect(load()).rejects.toThrow();});
it('missing server credential fails before DB access',async()=>{m.env.mockReturnValue({NEXT_PUBLIC_SUPABASE_URL:'https://example.test'});await expect(load()).rejects.toThrow('Active template unavailable');expect(m.client).not.toHaveBeenCalled();});
it('database errors never become returned template data',async()=>{m.rpc.mockResolvedValue({data:null,error:{message:'private details'}});await expect(load()).rejects.toThrow('Active template unavailable');});



