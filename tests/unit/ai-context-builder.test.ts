import {beforeEach,expect,it,vi} from 'vitest';
vi.mock('server-only',()=>({}));
const m=vi.hoisted(()=>({auth:vi.fn(),rpc:vi.fn(),availability:vi.fn()}));
vi.mock('@/lib/auth/authorization',async original=>({...await original<typeof import('@/lib/auth/authorization')>(),getAuthorizationContext:m.auth}));
vi.mock('@/lib/db/server',()=>({createServerSupabaseClient:async()=>({rpc:m.rpc})}));
vi.mock('@/features/ai/activity-availability',()=>({getActivityAiAvailability:m.availability}));
import {buildAiContext} from '@/features/ai/context-builder';
import {aiContextCandidateSchema} from '@/features/ai/context-builder-schema';
import {aiContextReferenceSchema} from '@/features/ai/context-schema';
const id=(n:number)=>`00000000-0000-4000-8000-${String(n).padStart(12,'0')}`;
const actor=id(1),project=id(2),workspace=id(3),version=id(4),activity=id(5),share=id(7),snapshot=id(8),foreign=id(9),hash='a'.repeat(64);
const versionRef={entityType:'ARTIFACT_VERSION',entityId:version,contextRole:'CURRENT_ARTIFACT'};
const base={projectId:project,workspaceId:workspace,taskType:'CRITICAL_REVIEW',selectedContextRefs:[versionRef]};
function result(input:Record<string,string>,content:unknown={title:'Selected current content',content_snapshot:{notes:'Human authored notes'}}){return {entity_type:input.entityType,entity_id:input.entityId,context_role:input.contextRole,included_snapshot_hash:hash,share_snapshot_id:input.shareId?snapshot:null,permission_scope:{access:input.shareId?'SHARE_SNAPSHOT':'SOURCE'},content};}
beforeEach(()=>{
 vi.unstubAllEnvs();m.availability.mockReset();m.availability.mockResolvedValue({available:true});m.auth.mockReset();m.rpc.mockReset();m.auth.mockResolvedValue({userId:actor,assignments:[]});
 m.rpc.mockImplementation(async(_name,{input})=>({error:null,data:result(input,input.entityType==='PROJECT'?{name:'Current Project'}:input.entityType==='ACTIVITY_INSTANCE'?{instructions:'Immutable method instructions'}:undefined)}));
});
it.each(['Personal','Team'])('AT-AI-002/003: includes only authorized selected %s context and compatible provenance',async()=>{
 const output=await buildAiContext(base);expect(output.context).toEqual([{role:'CURRENT_ARTIFACT',content:{title:'Selected current content',content_snapshot:{notes:'Human authored notes'}}}]);
 expect(output.references).toEqual([{entity_type:'ARTIFACT_VERSION',entity_id:version,context_role:'CURRENT_ARTIFACT',included_snapshot_hash:hash,share_snapshot_id:null,permission_scope:{access:'SOURCE'}}]);
 const candidate=output.references[0];expect(aiContextCandidateSchema.safeParse(candidate).success).toBe(true);expect(aiContextReferenceSchema.safeParse({...candidate,id:id(50),ai_output_id:id(51)}).success).toBe(true);
 expect(m.rpc.mock.calls.every(([name])=>name==='resolve_ai_context_source')).toBe(true);
});
it.each(['Team B','other Personal','removed member','role-only Master','role-only Admin','role-only Mentor','wrong Workspace','wrong Activity'])('AT-AI-002/003/004 and LEAK-001/002/003: fails closed for %s scope',async()=>{
 m.rpc.mockResolvedValue({data:null,error:{message:'private SQL /server/path secret'}});await expect(buildAiContext(base)).rejects.toMatchObject({code:'FORBIDDEN',message:'Access denied.'});
});
it('uses only the exact active Share Snapshot and never queries private source scope',async()=>{
 const output=await buildAiContext({...base,selectedContextRefs:[{...versionRef,shareId:share}]});expect(output.references[0].share_snapshot_id).toBe(snapshot);expect(output.references[0].permission_scope).toEqual({access:'SHARE_SNAPSHOT'});
 expect(m.rpc.mock.calls.filter(([,v])=>v.input.entityType!=='PROJECT').every(([,v])=>v.input.shareId===share&&v.input.projectId===project&&v.input.workspaceId===workspace)).toBe(true);
});
it('M14.18 Share cannot override a forbidden Task context role',async()=>{
 const output=await buildAiContext({...base,taskType:'SCAMPER_ASSISTANCE',activityInstanceId:activity,selectedContextRefs:[versionRef,{entityType:'EVIDENCE',entityId:foreign,contextRole:'EVIDENCE',shareId:share}]});
 expect(output.references.every(r=>r.entity_id!==foreign)).toBe(true);expect(m.rpc.mock.calls.some(([,v])=>v.input.shareId===share)).toBe(false);
});
it('M14.18 minimizes an exact frozen Share without following embedded siblings or File references',async()=>{
 m.rpc.mockImplementation(async(_name,{input})=>({data:result(input,input.shareId?{title:'X',content_snapshot:{notes:'FROZEN_ONLY',relationships:[{notes:'SIBLING_SECRET'}],linked_file_id:foreign,metadata:{notes:'PRIVATE_METADATA'}}}:{name:'Recipient Project'}),error:null}));
 const output=await buildAiContext({...base,selectedContextRefs:[{...versionRef,shareId:share}]});
 expect(output.context[0].content).toEqual({title:'X',content_snapshot:{notes:'FROZEN_ONLY'}});
 expect(output.references[0]).toMatchObject({share_snapshot_id:snapshot,permission_scope:{access:'SHARE_SNAPSHOT'}});
 expect(m.rpc.mock.calls.every(([,v])=>v.input.entityId===project||v.input.entityId===version)).toBe(true);
});
it.each(['revoked Share','removed destination member','expired Master destination','known old Snapshot'])('denies required Share-derived context after %s',async()=>{
 m.rpc.mockImplementation(async(_name,{input})=>({data:input.shareId?null:result(input),error:null}));await expect(buildAiContext({...base,selectedContextRefs:[{...versionRef,shareId:share}]})).rejects.toMatchObject({code:'FORBIDDEN'});
});
it('rechecks after awaited identity refresh and rejects revoked required content',async()=>{
 let lost=false;m.auth.mockImplementation(async()=>{if(m.auth.mock.calls.length>1)lost=true;return {userId:actor};});
 m.rpc.mockImplementation(async(_name,{input})=>({data:lost&&input.shareId?null:result(input),error:null}));
 await expect(buildAiContext({...base,selectedContextRefs:[{...versionRef,shareId:share}]})).rejects.toMatchObject({code:'FORBIDDEN'});
});
it('does not substitute or search for missing required context',async()=>{
 await expect(buildAiContext({...base,selectedContextRefs:[]})).rejects.toMatchObject({code:'FORBIDDEN'});expect(m.rpc.mock.calls.every(([,v])=>v.input.entityType==='PROJECT')).toBe(true);
});
it('excludes inaccessible optional context without probing related endpoints',async()=>{
 m.rpc.mockImplementation(async(_name,{input})=>({data:input.entityId===foreign?null:result(input),error:null}));
 const output=await buildAiContext({...base,selectedContextRefs:[versionRef,{entityType:'EVIDENCE',entityId:foreign,contextRole:'EVIDENCE'}]});expect(output.references).toHaveLength(1);expect(JSON.stringify(output)).not.toContain(foreign);
});
it('excludes forbidden context even when independently accessible',async()=>{
 const output=await buildAiContext({...base,taskType:'SCAMPER_ASSISTANCE',activityInstanceId:activity,selectedContextRefs:[versionRef,{entityType:'EVIDENCE',entityId:foreign,contextRole:'EVIDENCE'}]});
 expect(output.references.map(r=>r.context_role)).toEqual(['COURSE_CONTEXT','CURRENT_ARTIFACT']);expect(m.rpc.mock.calls.some(([,v])=>v.input.entityId===foreign)).toBe(false);
});
it.each(['CHAT_MESSAGE','CHAT','FILE','SHARE_SNAPSHOT','AI_CONTEXT_REFERENCE','AI_OUTPUT','PATENT_SEARCH_LOG'])('excludes unsupported %s, including hidden peers and unselected Chat/Files',async entityType=>{
 await expect(buildAiContext({...base,selectedContextRefs:[{...versionRef,entityType}]})).rejects.toMatchObject({code:'VALIDATION_ERROR'});expect(m.rpc).not.toHaveBeenCalled();
});
it.each(['actor','userId','role','hash','snapshotId','context','taskContract','instructions','storageReference'])('rejects client authority/payload override %s',async key=>{
 await expect(buildAiContext({...base,[key]:'spoof'})).rejects.toMatchObject({code:'VALIDATION_ERROR'});expect(m.rpc).not.toHaveBeenCalled();
});
it.each(['shareSnapshotId','included_snapshot_hash','permission_scope','referenceId','storageReference','content'])('cannot replay supplied %s as a source capability',async key=>{
 await expect(buildAiContext({...base,selectedContextRefs:[{...versionRef,[key]:'spoof'}]})).rejects.toMatchObject({code:'VALIDATION_ERROR'});
});
it('minimizes nested content, ignores links/siblings/metadata and strips URLs without traversal',async()=>{
 m.rpc.mockImplementation(async(_name,{input})=>({error:null,data:result(input,{title:'Selected',storage_reference:'bucket/private',signed_url:'https://host/signed?token=private',created_by:foreign,metadata:{api_key:'secret'},content_snapshot:{notes:'Source https://host/private?token=example',nodes:[{label:'A',linked_object_id:foreign,metadata:{secret:'private'}}],relationships:[{content:'unrelated'}],siblings:[{notes:'hidden'}]}})}));
 const output=await buildAiContext(base);expect(output.context[0].content).toEqual({title:'Selected',content_snapshot:{notes:'Source [URL omitted]',nodes:[{label:'A'}]}});expect(JSON.stringify(output)).not.toMatch(/bucket\/private|token=|unrelated|hidden|api_key|linked_object_id/);
});
it('rejects configured secrets even when embedded in otherwise permitted narrative',async()=>{
 vi.stubEnv('TEST_AI_CONTEXT_SECRET','private-secret-value');m.rpc.mockImplementation(async(_name,{input})=>({error:null,data:result(input,{notes:'private-secret-value'})}));await expect(buildAiContext(base)).rejects.toMatchObject({code:'FORBIDDEN'});
});
it('rejects identity changes, malformed hashes and substituted source IDs',async()=>{
 m.auth.mockResolvedValueOnce({userId:actor}).mockResolvedValue({userId:foreign});await expect(buildAiContext(base)).rejects.toMatchObject({code:'FORBIDDEN'});
 m.auth.mockResolvedValue({userId:actor});m.rpc.mockImplementation(async(_name,{input})=>({error:null,data:{...result(input),included_snapshot_hash:'client hash'}}));await expect(buildAiContext(base)).rejects.toMatchObject({code:'FORBIDDEN'});
});
it('candidates are deduplicated, ordered, stable, and create no durable AI records',async()=>{
 const output=await buildAiContext({...base,selectedContextRefs:[versionRef,versionRef]});expect(output.references).toHaveLength(1);expect(await buildAiContext(base)).toEqual(output);expect(m.rpc.mock.calls.every(([name])=>name==='resolve_ai_context_source')).toBe(true);
});
it('unknown tasks and denied authentication fail without raw diagnostics',async()=>{
 await expect(buildAiContext({...base,taskType:'UNKNOWN'})).rejects.toMatchObject({code:'FORBIDDEN'});m.auth.mockRejectedValue({code:'AUTH_REQUIRED'});await expect(buildAiContext(base)).rejects.toMatchObject({code:'FORBIDDEN'});
});

it('M14.19 own hidden context survives while exact hidden-peer ID is excluded from content and provenance',async()=>{
 m.rpc.mockImplementation(async(_name,{input})=>({data:input.entityId===foreign?null:result(input,input.entityType==='BRAINSTORM_ENTRY'?{content:'OWN_HIDDEN_ONLY',parent_entry_id:foreign}:{instructions:'Method',title:'Source'}),error:null}));
 const output=await buildAiContext({...base,taskType:'BRAINSTORMING_ASSISTANCE',activityInstanceId:activity,selectedContextRefs:[versionRef,{entityType:'BRAINSTORM_ENTRY',entityId:id(60),contextRole:'BRAINSTORM'},{entityType:'BRAINSTORM_ENTRY',entityId:foreign,contextRole:'BRAINSTORM'}]});
 expect(output.context.find(e=>e.role==='BRAINSTORM')?.content).toEqual({content:'OWN_HIDDEN_ONLY'});
 expect(output.references.filter(e=>e.context_role==='BRAINSTORM').map(e=>e.entity_id)).toEqual([id(60)]);
 expect(JSON.stringify(output)).not.toContain(foreign);expect(m.availability).toHaveBeenCalledTimes(2);
});
it('M14.19 pool-dependent unavailability stops before context reads',async()=>{
 m.availability.mockResolvedValue({available:false,reason:'PRIVATE_BEFORE_REVEAL'});
 await expect(buildAiContext({...base,taskType:'BRAINSTORMING_ASSISTANCE',activityInstanceId:activity,selectedContextRefs:[versionRef,{entityType:'BRAINSTORM_ENTRY',entityId:foreign,contextRole:'BRAINSTORM'}]})).rejects.toMatchObject({code:'FORBIDDEN'});
 expect(m.rpc).not.toHaveBeenCalled();
});
it('M14.19 rechecks canonical availability after context work',async()=>{
 m.availability.mockResolvedValueOnce({available:true}).mockResolvedValue({available:false,reason:'PRIVATE_BEFORE_REVEAL'});
 await expect(buildAiContext({...base,taskType:'BRAINSTORMING_ASSISTANCE',activityInstanceId:activity,selectedContextRefs:[versionRef,{entityType:'BRAINSTORM_ENTRY',entityId:foreign,contextRole:'BRAINSTORM'}]})).rejects.toMatchObject({code:'FORBIDDEN'});
});
it.each(['ownerUserId','authorId','revealed','teamPool','peerVisibility'])('M14.19 rejects client Brainstorm authority flag %s',async key=>{
 await expect(buildAiContext({...base,selectedContextRefs:[{entityType:'BRAINSTORM_ENTRY',entityId:foreign,contextRole:'BRAINSTORM',[key]:true}]})).rejects.toMatchObject({code:'VALIDATION_ERROR'});expect(m.rpc).not.toHaveBeenCalled();
});
it('M14.19 other Tasks cannot query Brainstorm even with exact IDs',async()=>{
 const r=await buildAiContext({...base,selectedContextRefs:[versionRef,{entityType:'BRAINSTORM_ENTRY',entityId:foreign,contextRole:'BRAINSTORM'}]});
 expect(r.references.some(e=>e.entity_id===foreign)).toBe(false);expect(m.rpc.mock.calls.some(([,v])=>v.input.entityId===foreign)).toBe(false);
});
