import {beforeEach,describe,expect,it,vi} from 'vitest';
vi.mock('server-only',()=>({}));
const commentNotify=vi.hoisted(()=>vi.fn());
vi.mock('@/features/notifications/comment',()=>({notifyCommentReceived:commentNotify}));
const m=vi.hoisted(()=>({auth:vi.fn(),rpc:vi.fn(),access:vi.fn()}));
vi.mock('@/lib/auth/authorization',async original=>({...await original<typeof import('@/lib/auth/authorization')>(),getAuthorizationContext:m.auth}));
vi.mock('@/lib/db/server',()=>({createServerSupabaseClient:async()=>({rpc:m.rpc})}));
vi.mock('@/features/shares/access',()=>({resolveSharedEntityAccess:m.access}));
import {addSharedComment,listSharedComments} from '@/features/shares/comments';
const actor='00000000-0000-4000-8000-000000006006',share='00000000-0000-4000-8000-000000000001',target='00000000-0000-4000-8000-000000000002',version='00000000-0000-4000-8000-000000000003';
const row={id:version,share_id:share,target_entity_type:'ARTIFACT',target_entity_id:target,target_version_id:version,author_user_id:actor,content:'Comment',created_at:'2026-11-01T00:00:00Z'};
const access={allowed:true,canComment:true,sharedEntityType:'ARTIFACT',sharedEntityId:target,sourceVersionId:version};
describe('M13.10 exact-Share comment wrapper',()=>{
 beforeEach(()=>{vi.resetAllMocks();m.auth.mockResolvedValue({userId:actor});m.access.mockResolvedValue(access);m.rpc.mockResolvedValue({data:row,error:null});});
 it('uses resolver and one authenticated write with server-derived target/identity',async()=>{expect(await addSharedComment({shareId:share,content:' Comment '})).toEqual(row);expect(m.access).toHaveBeenCalledWith({shareId:share});expect(m.rpc).toHaveBeenCalledExactlyOnceWith('add_share_comment',{input:{shareId:share,content:'Comment'}});});
 it.each(['authorUserId','targetEntityId','targetVersionId','createdAt','submissionId','permissionLevel','force'])('rejects writable %s',async field=>{await expect(addSharedComment({shareId:share,content:'Comment',[field]:actor})).rejects.toMatchObject({code:'VALIDATION_ERROR'});expect(m.rpc).not.toHaveBeenCalled();});
 it.each([{},[],null,{shareId:'bad',content:'Comment'},{shareId:share,content:'  '}])('rejects malformed input %#',async input=>{await expect(addSharedComment(input)).rejects.toMatchObject({code:'VALIDATION_ERROR'});});
 it.each([{allowed:false},{...access,canComment:false}])('denies VIEW/revoked/removed capability %#',async a=>{m.access.mockResolvedValue(a);await expect(addSharedComment({shareId:share,content:'Comment'})).rejects.toMatchObject({code:'FORBIDDEN'});expect(m.rpc).not.toHaveBeenCalled();});
 it('denies a changed identity before write',async()=>{m.auth.mockResolvedValueOnce({userId:actor}).mockResolvedValue({userId:share});await expect(addSharedComment({shareId:share,content:'Comment'})).rejects.toMatchObject({code:'FORBIDDEN'});expect(m.rpc).not.toHaveBeenCalled();});
 it('honors database revocation after preflight',async()=>{m.rpc.mockResolvedValue({data:null,error:{code:'42501'}});await expect(addSharedComment({shareId:share,content:'Comment'})).rejects.toMatchObject({code:'FORBIDDEN'});});
 it.each([{...row,author_user_id:share},{...row,share_id:target},{...row,target_entity_id:share},{...row,target_version_id:share},{...row,content:'Other'},{...row,privateMetadata:'Hidden'}])('rejects wrong persisted context %#',async data=>{m.rpc.mockResolvedValue({data,error:null});await expect(addSharedComment({shareId:share,content:'Comment'})).rejects.toMatchObject({code:'FORBIDDEN'});});
 it('reads only an exact thread with a fresh second database authorization',async()=>{m.rpc.mockResolvedValue({data:[row],error:null});expect(await listSharedComments({shareId:share})).toEqual([row]);expect(m.rpc).toHaveBeenCalledTimes(2);expect(m.access).not.toHaveBeenCalled();});
 it('withholds a thread after access loss during identity refresh',async()=>{m.rpc.mockResolvedValueOnce({data:[row],error:null}).mockResolvedValue({data:null,error:{code:'42501'}});await expect(listSharedComments({shareId:share})).rejects.toMatchObject({code:'FORBIDDEN'});});
 it('does not accept another Share thread',async()=>{m.rpc.mockResolvedValue({data:[{...row,share_id:target}],error:null});await expect(listSharedComments({shareId:share})).rejects.toMatchObject({code:'FORBIDDEN'});});
 it('rejects thread enumeration parameters',async()=>{await expect(listSharedComments({shareId:share,workspaceId:actor})).rejects.toMatchObject({code:'VALIDATION_ERROR'});});
 it('supports non-versioned exact targets without a version',async()=>{m.access.mockResolvedValue({...access,sharedEntityType:'FILE',sourceVersionId:null});m.rpc.mockResolvedValue({data:{...row,target_entity_type:'FILE',target_version_id:null},error:null});expect((await addSharedComment({shareId:share,content:'Comment'})).target_version_id).toBeNull();});
});

it('committed exact Share comment dispatches its canonical identity',async()=>{vi.resetAllMocks();m.auth.mockResolvedValue({userId:actor});m.access.mockResolvedValue(access);m.rpc.mockResolvedValue({data:row,error:null});await addSharedComment({shareId:share,content:'Comment'});expect(commentNotify).toHaveBeenCalledExactlyOnceWith(row.id);});
