import {describe,expect,it,vi} from 'vitest';
vi.mock('server-only',()=>({}));
const m=vi.hoisted(()=>({auth:vi.fn(),db:vi.fn()}));
vi.mock('@/lib/auth/authorization',()=>({getAuthorizationContext:m.auth}));
vi.mock('@/lib/db/server',()=>({createServerSupabaseClient:m.db}));
import {copySharedSnapshotToWorkspace,SharedSnapshotCopyDeferredError} from '@/features/shares/copy';
import {createArtifactSchema} from '@/features/artifacts/create-schema';
import {createArtifactVersionSchema} from '@/features/artifacts/create-version-schema';
const id='00000000-0000-4000-8000-000000000001';
describe('M13.14 shared Snapshot copy remains deferred',()=>{
 it.each([null,undefined,{},[],{shareId:id},{snapshotId:id},{entityId:id,sourceVersionId:id},
  ...['VIEW','COMMENT','COLLABORATE'].map(permissionLevel=>({shareId:id,workspaceId:id,permissionLevel})),
  ...['TEAM','PERSONAL','MASTER'].map(destinationType=>({shareId:id,destinationType,workspaceId:id})),
  ...['clone','import','duplicate','copy'].map(operation=>({operation,shareId:id,force:true})),
 ])('denies without identity lookup, content access or database work %#',async input=>{
  await expect(copySharedSnapshotToWorkspace(input)).rejects.toBeInstanceOf(SharedSnapshotCopyDeferredError);
  await expect(copySharedSnapshotToWorkspace(input)).rejects.toMatchObject({code:'SHARED_SNAPSHOT_COPY_DEFERRED'});
  expect(m.auth).not.toHaveBeenCalled();expect(m.db).not.toHaveBeenCalled();
 });
 it('does not inspect caller-controlled properties',async()=>{
  const input=new Proxy({}, {get(){throw Error('Input must not be inspected');}});
  await expect(copySharedSnapshotToWorkspace(input)).rejects.toMatchObject({code:'SHARED_SNAPSHOT_COPY_DEFERRED'});
 });
 it.each(['shareId','snapshotId','sourceVersionId','sourceShareId','cloneFrom','importFrom'])('existing entity/version creation contracts reject %s adapters',field=>{
  expect(createArtifactSchema.safeParse({projectId:id,workspaceId:id,artifactType:'DEVELOPED_CONCEPT',title:'Copy',reviewRequired:false,approvalRequired:false,[field]:id}).success).toBe(false);
  expect(createArtifactVersionSchema.safeParse({artifactId:id,contentSnapshot:{},changeSummary:'Copy',[field]:id}).success).toBe(false);
 });
});
