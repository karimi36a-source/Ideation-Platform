import {beforeEach,describe,expect,it,vi} from 'vitest';
vi.mock('server-only',()=>({}));
const m=vi.hoisted(()=>({auth:vi.fn(),rpc:vi.fn()}));
vi.mock('@/lib/auth/authorization',async original=>({...await original<typeof import('@/lib/auth/authorization')>(),getAuthorizationContext:m.auth}));
vi.mock('@/lib/db/server',()=>({createServerSupabaseClient:async()=>({rpc:m.rpc})}));
import {AuthorizationError} from '@/lib/auth/authorization';
import {listEntityShares} from '@/features/shares/history';
const id='00000000-0000-4000-8000-000000000001',other='00000000-0000-4000-8000-000000000002';
const input={entityType:'ARTIFACT',entityId:id};
const row={shareId:other,destination:{type:'TEAM',teamId:other},permissionLevel:'VIEW',shareMode:'SNAPSHOT',sourceVersionId:id,createdAt:'2026-11-01T00:00:00Z',sharedBy:id,state:'ACTIVE',revokedAt:null,revokedBy:null};
const envelope={...input,shares:[row]};
describe('M13.13 exact-source read-only history wrapper',()=>{
 beforeEach(()=>{vi.resetAllMocks();m.auth.mockResolvedValue({userId:id});m.rpc.mockResolvedValue({data:envelope,error:null});});
 it('returns safe records after a fresh authority recheck',async()=>{expect(await listEntityShares(input)).toEqual([row]);expect(m.rpc).toHaveBeenCalledTimes(2);expect(m.rpc).toHaveBeenCalledWith('list_entity_shares',{input});});
 it('supports a valid entity with no history',async()=>{m.rpc.mockResolvedValue({data:{...input,shares:[]},error:null});expect(await listEntityShares(input)).toEqual([]);});
 it.each(['workspaceId','shareId','actorId','destinationId','includeContent','permissionLevel','force'])('rejects enumeration/spoof input %s',async field=>{await expect(listEntityShares({...input,[field]:other})).rejects.toMatchObject({code:'VALIDATION_ERROR'});expect(m.rpc).not.toHaveBeenCalled();});
 it.each([null,[],{},'bad',{entityType:'WORKSPACE',entityId:id},{...input,entityId:'bad'}])('rejects malformed input %#',async value=>{await expect(listEntityShares(value)).rejects.toMatchObject({code:'VALIDATION_ERROR'});expect(m.rpc).not.toHaveBeenCalled();});
 it('requires authentication',async()=>{m.auth.mockRejectedValue(new AuthorizationError('AUTH_REQUIRED'));await expect(listEntityShares(input)).rejects.toMatchObject({code:'AUTH_REQUIRED'});expect(m.rpc).not.toHaveBeenCalled();});
 it('withholds stale history when current Lead authority is lost',async()=>{m.rpc.mockResolvedValueOnce({data:envelope,error:null}).mockResolvedValue({data:null,error:{code:'42501'}});await expect(listEntityShares(input)).rejects.toMatchObject({code:'NOT_FOUND'});});
 it('withholds history across an identity switch',async()=>{m.auth.mockResolvedValueOnce({userId:id}).mockResolvedValue({userId:other});await expect(listEntityShares(input)).rejects.toMatchObject({code:'NOT_FOUND'});expect(m.rpc).toHaveBeenCalledTimes(1);});
 it.each([{...envelope,entityId:other},{...envelope,entityType:'FILE'},{...envelope,sourceWorkspaceId:other},{...envelope,shares:[row,row]},
  {...envelope,shares:[{...row,snapshotContent:{private:'body'}}]},
  {...envelope,shares:[{...row,destination:{...row.destination,members:[id]}}]},
  {...envelope,shares:[{...row,destination:{type:'MASTER',userId:id,assignmentId:other}}]},
  {...envelope,shares:[{...row,state:'REVOKED'}]},
 ])('rejects wrong-source/leaking/noncanonical responses %#',async data=>{m.rpc.mockResolvedValue({data,error:null});await expect(listEntityShares(input)).rejects.toMatchObject({code:'NOT_FOUND'});});
 it('retains distinct revoked and re-shared records without changing Version IDs',async()=>{const rows=[{...row,shareId:id,state:'REVOKED',revokedAt:'2026-11-01T01:00:00Z',revokedBy:id},{...row,createdAt:'2026-11-01T02:00:00Z',sourceVersionId:other}];m.rpc.mockResolvedValue({data:{...input,shares:rows},error:null});expect(await listEntityShares(input)).toEqual(rows);});
 it('sanitizes provider/private errors',async()=>{m.rpc.mockRejectedValue(Error('private credentials'));await expect(listEntityShares(input)).rejects.toMatchObject({code:'NOT_FOUND',message:'Resource unavailable.'});});
});
