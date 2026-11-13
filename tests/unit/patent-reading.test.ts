import {beforeEach,expect,it,vi} from 'vitest';
vi.mock('server-only',()=>({}));
const m=vi.hoisted(()=>({auth:vi.fn(),rpc:vi.fn()}));
vi.mock('@/lib/auth/authorization',async original=>({...await original<typeof import('@/lib/auth/authorization')>(),getAuthorizationContext:m.auth}));
vi.mock('@/lib/db/server',()=>({createServerSupabaseClient:async()=>({rpc:m.rpc})}));
import {savePatentReadingFramework} from '@/features/patents/reading';
const id=(n:number)=>'00000000-0000-4000-8000-'+String(n).padStart(12,'0');
const stamp='2026-10-29T00:00:00Z';
const notes={title:'My reading',abstract:'Purpose',description:'Structure',claims:'Claim 1',drawings:'Figure 2',bibliographic_information:'Dates'};
const input={activityInstanceId:id(1),patentRecordId:id(2),notes};
const artifact={id:id(3),project_id:id(4),workspace_id:id(5),artifact_type:'PATENT_READING_FRAMEWORK',title:'Patent Reading Framework',status:'ACTIVE',current_version_id:null,created_by:id(6),activity_instance_id:id(1),review_required:false,approval_required:false,created_at:stamp,updated_at:stamp,archived_at:null};
const version={id:id(7),artifact_id:id(3),version_number:1,version_label:null,content_snapshot:{learner_notes:notes,source_patent_record_ids:[id(2)]},change_summary:null,status:'DRAFT',draft_revision:1,created_by:id(6),created_at:stamp,previous_version_id:null,approved_by:null,approved_at:null,approval_note:null};
beforeEach(()=>{vi.resetAllMocks();m.auth.mockResolvedValue({userId:id(6)});m.rpc.mockResolvedValue({data:{artifact,version},error:null});});
it('returns canonical persisted state without identity/scope overrides',async()=>{
 expect(await savePatentReadingFramework(input)).toEqual({artifact,version});
 expect(m.rpc).toHaveBeenCalledExactlyOnceWith('save_patent_reading_framework',{target_instance:id(1),target_patent:id(2),notes,expected_revision:null,target_version:null});
});
it('binds edits to Version identity and CAS revision',async()=>{
 await savePatentReadingFramework({...input,artifactVersionId:id(7),expectedDraftRevision:1});
 expect(m.rpc).toHaveBeenCalledWith('save_patent_reading_framework',expect.objectContaining({target_version:id(7),expected_revision:1}));
});
it.each([{...input,createdBy:id(6)},{...input,workspaceId:id(5)},{...input,expectedDraftRevision:1},{...input,artifactVersionId:id(7)},{...input,notes:{title:'incomplete'}}])('rejects spoofed/incomplete input',async value=>{
 await expect(savePatentReadingFramework(value)).rejects.toMatchObject({code:'VALIDATION_ERROR'});expect(m.rpc).not.toHaveBeenCalled();
});
it.each(['42501','28000','55000','23505'])('hides database details for %s',async code=>{
 m.rpc.mockResolvedValue({data:null,error:{code,message:'Private source'}});await expect(savePatentReadingFramework(input)).rejects.toMatchObject({code:'NOT_FOUND'});
});
it.each([{artifact:{...artifact,artifact_type:'PATENT_LANDSCAPE'}},{artifact:{...artifact,activity_instance_id:id(8)}},{version:{...version,artifact_id:id(8)}},{version:{...version,content_snapshot:{learner_notes:notes,source_patent_record_ids:[id(8)]}}}])('rejects noncanonical result',async patch=>{
 m.rpc.mockResolvedValue({data:{artifact,version,...patch},error:null});await expect(savePatentReadingFramework(input)).rejects.toMatchObject({code:'NOT_FOUND'});
});
it('rechecks server identity',async()=>{m.auth.mockResolvedValueOnce({userId:id(6)}).mockResolvedValueOnce({userId:id(8)});await expect(savePatentReadingFramework(input)).rejects.toMatchObject({code:'NOT_FOUND'});});
