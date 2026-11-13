import {beforeEach,expect,it,vi} from 'vitest';
vi.mock('server-only',()=>({}));
const m=vi.hoisted(()=>({rpc:vi.fn(),open:vi.fn()}));
vi.mock('@/lib/db/server',()=>({createServerSupabaseClient:async()=>({rpc:m.rpc})}));
vi.mock('@/features/live-classroom/room',()=>({getOrCreateLiveSessionRoom:m.open}));
vi.mock('next/navigation',()=>({notFound:()=>{throw Error('NOT_FOUND');},redirect:(url:string)=>{throw Error('REDIRECT '+url);}}));
import Page from '@/app/(platform)/cohorts/[cohortId]/live/[sessionDefinitionId]/page';
const input={params:Promise.resolve({cohortId:'cohort',sessionDefinitionId:'session'}),searchParams:Promise.resolve({})};
beforeEach(()=>{vi.clearAllMocks();m.rpc.mockResolvedValue({data:{actorId:'current'},error:null});m.open.mockResolvedValue({id:'room'});});
it('renders a read-only authorized form and opens only through the existing reauthorizing operation',async()=>{
 const page=await Page(input);expect(m.open).not.toHaveBeenCalled();expect(m.rpc).toHaveBeenCalledWith('authorize_master_live_room',{target_cohort:'cohort',target_session:'session',target_activity:null});
 const form=page.props.children.find((child:unknown)=>typeof child==='object'&&child!==null&&'type'in child&&child.type==='form');
 await expect(form.props.action()).rejects.toThrow('REDIRECT /live-classroom/room');expect(m.open).toHaveBeenCalledExactlyOnceWith({cohortId:'cohort',sessionDefinitionId:'session'});
});
it('Student/unrelated Master denial renders no open operation',async()=>{m.rpc.mockResolvedValue({data:null,error:{code:'42501'}});await expect(Page(input)).rejects.toThrow('NOT_FOUND');expect(m.open).not.toHaveBeenCalled();});
it('authority loss/provider failure on form replay exposes only a safe retry destination',async()=>{m.open.mockRejectedValue(Error('private provider diagnostic'));const page=await Page(input);const form=page.props.children.find((child:unknown)=>typeof child==='object'&&child!==null&&'type'in child&&child.type==='form');await expect(form.props.action()).rejects.toThrow('REDIRECT /cohorts/cohort/live/session?unavailable=1');});
