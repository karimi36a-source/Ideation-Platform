import {beforeEach,expect,it,vi} from 'vitest';
vi.mock('server-only',()=>({}));
const {identity}=vi.hoisted(()=>({identity:vi.fn()}));
vi.mock('@/features/users/service',()=>({requireActivePlatformUser:identity}));
import {createLiveRoomMappingRepository} from '@/features/live-classroom/mapping-repository';
const id=(n:number)=>`00000000-0000-4000-8000-${String(n).padStart(12,'0')}`;
const base={cohortId:id(1),sessionDefinitionId:id(2),provider:'DAILY' as const};
const row={id:id(3),cohort_id:id(1),session_definition_id:id(2),provider:'DAILY',provider_room_ref:'existing-room',status:'ACTIVE',created_by:id(4),created_at:'2026-11-11T10:00:00Z',updated_at:'2026-11-11T10:00:00Z',ended_at:null};
const rpc=vi.fn(),repo=createLiveRoomMappingRepository({rpc});
beforeEach(()=>{identity.mockReset().mockResolvedValue({id:id(4)});rpc.mockReset().mockResolvedValue({data:row,error:null});});
it('looks up an active mapping before any provider creation',async()=>{expect(await repo.findActive(base)).toEqual(row);expect(rpc.mock.calls[0][1]).toMatchObject({command:'FIND_ACTIVE',room_reference:null,actor:id(4)});rpc.mockResolvedValue({data:null,error:null});expect(await repo.findActive(base)).toBeNull();});
it('derives creator and returns canonical active reuse without overwriting reference',async()=>{
 expect(await repo.write({...base,command:'REUSE_OR_CREATE',providerRoomRef:'candidate-room'})).toEqual(row);
 expect(rpc).toHaveBeenCalledWith('manage_live_room_mapping',{command:'REUSE_OR_CREATE',target_cohort:id(1),target_session:id(2),target_provider:'DAILY',room_reference:'candidate-room',actor:id(4),expected_room:null});
});
it.each(['created_by','actor','status','token','apiKey','workspaceId','ended_at'])('rejects client-controlled %s',async field=>{
 await expect(repo.write({...base,command:'REUSE_OR_CREATE',providerRoomRef:'room',[field]:'spoof'})).rejects.toThrow('Invalid live room mapping input.');expect(rpc).not.toHaveBeenCalled();
});
it('requires a verified active identity before persistence',async()=>{identity.mockRejectedValue(Error('Access denied'));await expect(repo.write({...base,command:'REUSE_OR_CREATE',providerRoomRef:'room'})).rejects.toThrow();expect(rpc).not.toHaveBeenCalled();});
it('expires only the exact expected mapping',async()=>{
 rpc.mockResolvedValue({data:{...row,status:'EXPIRED',ended_at:'2026-11-11T11:00:00Z'},error:null});
 expect((await repo.write({...base,command:'EXPIRE',expectedRoomId:id(3)})).status).toBe('EXPIRED');expect(rpc.mock.calls[0][1]).toMatchObject({room_reference:null,expected_room:id(3)});
});
it('replaces using an explicit predecessor without modifying it',async()=>{
 rpc.mockResolvedValue({data:{...row,id:id(5),provider_room_ref:'replacement'},error:null});
 expect((await repo.write({...base,command:'REPLACE',expectedRoomId:id(3),providerRoomRef:'replacement'})).id).toBe(id(5));
});
it.each([{...row,cohort_id:id(9)},{...row,session_definition_id:id(9)},{...row,token:'secret'},{...row,status:'EXPIRED'},null])('rejects mismatched or unsafe database projections',async data=>{
 rpc.mockResolvedValue({data,error:null});await expect(repo.write({...base,command:'REUSE_OR_CREATE',providerRoomRef:'room'})).rejects.toThrow('Live room mapping unavailable.');
});
it('sanitizes persistence diagnostics',async()=>{rpc.mockResolvedValue({data:null,error:{message:'private database credential'}});await expect(repo.write({...base,command:'REUSE_OR_CREATE',providerRoomRef:'room'})).rejects.toThrow('Live room mapping unavailable.');});
it('sanitizes thrown transport diagnostics',async()=>{rpc.mockRejectedValue(Error('private database credential'));await expect(repo.write({...base,command:'REUSE_OR_CREATE',providerRoomRef:'room'})).rejects.toThrow('Live room mapping unavailable.');});
