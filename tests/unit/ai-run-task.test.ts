import {beforeEach,expect,it,vi} from 'vitest';
vi.mock('server-only',()=>({}));
const m=vi.hoisted(()=>({auth:vi.fn(),scope:vi.fn(),workspace:vi.fn(),availability:vi.fn(),assembly:vi.fn(),store:vi.fn(),read:vi.fn(),provider:vi.fn()}));
vi.mock('@/lib/auth/authorization',()=>({getAuthorizationContext:m.auth}));
vi.mock('@/lib/db/server',()=>({createServerSupabaseClient:async()=>({rpc:m.scope,from:(table:string)=>table==='ai_context_references'?{select:()=>({eq:()=>({order:()=>({order:async()=>({data:[{id:'00000000-0000-4000-8000-000000000050',context_role:'COURSE_CONTEXT',entity_type:'ACTIVITY_INSTANCE'}],error:null})})})})}:{select:()=>({eq:()=>({maybeSingle:m.read})})}})}));
vi.mock('@/features/workspaces/access',()=>({getWorkspaceAccess:m.workspace}));
vi.mock('@/features/ai/activity-availability',()=>({getActivityAiAvailability:m.availability}));
vi.mock('@/features/ai/prompt-assembly',()=>({assembleAiPrompt:m.assembly}));
vi.mock('@/features/ai/task-persistence',()=>({createAiTaskPersistenceClient:()=>({rpc:m.store})}));
import {runAiTask} from '@/features/ai/run-task';
import {getAiTaskDefinition} from '@/features/ai/task-registry';
import {OpenAiResponsesProvider} from '@/features/ai/providers/openai-responses';
import {patentTestResponse} from '../support/ai-patent-output';
const id=(n:number)=>`00000000-0000-4000-8000-${String(n).padStart(12,'0')}`;
const input={projectId:id(1),workspaceId:id(2),activityInstanceId:id(3),taskType:'SCAMPER_ASSISTANCE',idempotencyKey:'request-one'};
const actor=id(4),runtime={provider:{generate:m.provider}};
const assembly={providerInput:{modelProfile:'AI_STANDARD',instructions:'FICI rules',input:'Authorized minimized data',outputSchema:{type:'object',properties:{technique:{type:'string'}},additionalProperties:false}},metadata:{aiRole:'STRUCTURED_CREATIVITY_ASSISTANT',modelProfile:'AI_STANDARD',promptTemplateId:id(5),promptTemplateVersion:2,contextReferences:[{entity_type:'ACTIVITY_INSTANCE',entity_id:id(3),context_role:'COURSE_CONTEXT',included_snapshot_hash:'a'.repeat(64),share_snapshot_id:null,permission_scope:{access:'SOURCE'}}]}};
const result={success:true,text:'Generated unverified suggestion',structured:{technique:'Suggestion',original_element:'Element',proposed_change:'Change',reasoning:'Reason',potential_benefit:'Benefit',risk_or_unknown:'Unknown'},usage:{inputUsage:12,outputUsage:6},latencyMs:20,reference:{provider:'openai',responseId:'resp_example'},error:null};
let op:{fingerprint:string;state:string;attemptId:string;outputId:string|null}|null,attempt:number,usage:unknown[],saved:Record<string,unknown>|null,saveFails:boolean,commitReplyFails:boolean;
beforeEach(()=>{vi.resetAllMocks();vi.unstubAllEnvs();op=null;attempt=100;usage=[];saved=null;saveFails=false;commitReplyFails=false;
 m.auth.mockResolvedValue({userId:actor});m.scope.mockResolvedValue({data:true,error:null});m.workspace.mockResolvedValue({canView:true});m.availability.mockResolvedValue({available:true,aiRole:'STRUCTURED_CREATIVITY_ASSISTANT',allowedTasks:['SCAMPER_ASSISTANCE']});m.assembly.mockResolvedValue(assembly);m.provider.mockResolvedValue(result);
 m.read.mockImplementation(async()=>({data:saved,error:null}));
 m.store.mockImplementation(async(name:string,args:{input:Record<string,unknown>})=>{const v=args.input;
  if(name==='begin_ai_task_operation'){
   if(op&&op.fingerprint!==v.fingerprint)return {data:null,error:{code:'23505'}};
   if(op?.state==='running')return {data:null,error:{code:'55P03'}};
   if(op?.state!=='completed')op={fingerprint:v.fingerprint as string,state:'running',attemptId:id(++attempt),outputId:null};
   return {data:{operationId:id(20),attemptId:op!.attemptId,outputId:op!.outputId,completed:op!.state==='completed'},error:null};
  }
  if(name==='record_ai_task_attempt'){if(!usage.some(x=>JSON.stringify(x)===JSON.stringify(v)))usage.push(v);return {data:null,error:null};}
  if(name==='release_ai_task_operation'){if(op?.state==='running')op.state='retryable';return {data:null,error:null};}
  if(name==='save_ai_task_result'){
   if(saveFails)return {data:null,error:{code:'42501'}};
   saved={id:id(30),project_id:input.projectId,workspace_id:input.workspaceId,activity_instance_id:input.activityInstanceId,requested_by:actor,ai_role:'STRUCTURED_CREATIVITY_ASSISTANT',task_type:input.taskType,prompt_text:v.promptText,response_text:v.responseText,output_type:v.outputType,verification_status:'UNVERIFIED',disposition:'KEEP_FOR_REVIEW',created_at:'2026-11-03T12:00:00Z',model_provider_reference:v.providerReference,metadata:v.metadata};
   op!.state='completed';op!.outputId=id(30);return {data:commitReplyFails?null:id(30),error:commitReplyFails?{code:'NETWORK'}:null};
  }
  throw Error('Unexpected persistence command');
 });
});
it('executes accepted assembly/provider once and returns saved safe UNVERIFIED output only',async()=>{const r=await runAiTask(input,runtime);expect(r).toMatchObject({id:id(30),verification_status:'UNVERIFIED',disposition:'KEEP_FOR_REVIEW',output_type:'SUGGESTION'});expect(r).not.toHaveProperty('prompt_text');expect(r).not.toHaveProperty('metadata');expect(m.provider).toHaveBeenCalledOnce();expect(m.provider).toHaveBeenCalledWith(assembly.providerInput);expect(usage).toHaveLength(1);expect(usage[0]).toMatchObject({actorId:actor,successFailure:'SUCCESS'});const call=m.store.mock.calls.find(([name])=>name==='save_ai_task_result');expect(call?.[1].input.references).toEqual(assembly.metadata.contextReferences);expect(saved?.prompt_text).toBe('SCAMPER_ASSISTANCE');expect(saved?.metadata).toMatchObject({prompt_template_id:id(5),prompt_template_version:2,model_profile:'AI_STANDARD'});});
it.each(['activityInstanceId','idempotencyKey'])('requires %s before provider/storage',async key=>{const v:Record<string,unknown>={...input};delete v[key];await expect(runAiTask(v,runtime)).rejects.toMatchObject({code:'VALIDATION_ERROR'});expect(m.provider).not.toHaveBeenCalled();expect(m.store).not.toHaveBeenCalled();});
it.each(['requested_by','actorId','aiRole','modelProfile','templateId','verification_status','outputType','provider','context','permission_scope'])('rejects client override %s',async key=>{await expect(runAiTask({...input,[key]:'spoof'},runtime)).rejects.toMatchObject({code:'VALIDATION_ERROR'});expect(m.provider).not.toHaveBeenCalled();});
it('same completed request reuses saved output without another attempt',async()=>{const a=await runAiTask(input,runtime),b=await runAiTask(input,runtime);expect(a).toEqual(b);expect(m.provider).toHaveBeenCalledOnce();expect(usage).toHaveLength(1);});
it('equivalent normalized user instruction preserves request fingerprint',async()=>{await runAiTask({...input,userInstruction:'  e\u0301  '},runtime);await runAiTask({...input,userInstruction:'é'},runtime);expect(m.provider).toHaveBeenCalledOnce();});
it.each([{userInstruction:'changed'},{projectId:id(40)},{workspaceId:id(41)},{activityInstanceId:id(42)},{selectedContextRefs:[{entityType:'PROJECT',entityId:id(1),contextRole:'CURRENT_PROJECT'}]}])('rejects changed request under same key %#',async change=>{await runAiTask(input,runtime);await expect(runAiTask({...input,...change},runtime)).rejects.toMatchObject({code:'IDEMPOTENCY_CONFLICT'});expect(m.provider).toHaveBeenCalledOnce();});
it('rejects changed allowed task under same key',async()=>{await runAiTask(input,runtime);m.availability.mockResolvedValue({available:true,aiRole:'COMPARATIVE_CRITICAL_ANALYST',allowedTasks:['COMPARATIVE_ANALYSIS']});await expect(runAiTask({...input,taskType:'COMPARATIVE_ANALYSIS'},runtime)).rejects.toMatchObject({code:'IDEMPOTENCY_CONFLICT'});});
it.each(['Team B','removed member','role-only','other Personal','known key'])('%s denial prevents provider and persistence',async()=>{m.scope.mockResolvedValue({data:false,error:null});await expect(runAiTask(input,runtime)).rejects.toMatchObject({code:'FORBIDDEN'});expect(m.provider).not.toHaveBeenCalled();expect(m.store).not.toHaveBeenCalled();});
it('authentication failure creates no records',async()=>{m.auth.mockRejectedValue(Error('private auth'));await expect(runAiTask(input,runtime)).rejects.toMatchObject({code:'FORBIDDEN'});expect(m.provider).not.toHaveBeenCalled();expect(m.store).not.toHaveBeenCalled();});
it('unavailable Activity prevents provider and usage',async()=>{m.availability.mockResolvedValue({available:false});await expect(runAiTask(input,runtime)).rejects.toMatchObject({code:'AI_UNAVAILABLE'});expect(m.provider).not.toHaveBeenCalled();expect(usage).toHaveLength(0);});
it.each(['revoked Share','hidden peer','exact-ID bypass'])('%s Context Builder/assembly denial prevents execution',async()=>{m.assembly.mockRejectedValue(Error('Denied'));await expect(runAiTask(input,runtime)).rejects.toMatchObject({code:'FORBIDDEN'});expect(m.provider).not.toHaveBeenCalled();expect(m.store).not.toHaveBeenCalled();});
it('provider failure logs failed attempt and same key may retry successfully',async()=>{m.provider.mockResolvedValueOnce({...result,success:false,text:null,structured:null,error:{code:'UNAVAILABLE',retryable:true}});await expect(runAiTask(input,runtime)).rejects.toMatchObject({code:'PROVIDER_FAILED'});expect(saved).toBeNull();expect(usage[0]).toMatchObject({successFailure:'FAILURE'});await runAiTask(input,runtime);expect(m.provider).toHaveBeenCalledTimes(2);expect(usage).toHaveLength(2);expect(usage[1]).toMatchObject({successFailure:'SUCCESS'});});
it('thrown or malformed provider response logs normalized failure only',async()=>{m.provider.mockRejectedValue(Error('raw provider secret body'));await expect(runAiTask(input,runtime)).rejects.toMatchObject({code:'PROVIDER_FAILED',message:'AI task unavailable.'});expect(saved).toBeNull();expect(JSON.stringify(usage)).not.toMatch(/raw provider|secret body/);});
it.each([null,{}, {...result,text:null,structured:null},{...result,structured:null},{...result,structured:[]},{...result,structured:'not an object'}])('malformed normalized transport fails rejected before persistence %#',async value=>{m.provider.mockResolvedValue(value);await expect(runAiTask(input,runtime)).rejects.toMatchObject({code:'PROVIDER_FAILED'});expect(saved).toBeNull();});
it('save failure leaves no usable result and preserves successful attempt observability; retry is safe',async()=>{saveFails=true;await expect(runAiTask(input,runtime)).rejects.toMatchObject({code:'SAVE_FAILED'});expect(saved).toBeNull();expect(usage[0]).toMatchObject({successFailure:'SUCCESS'});saveFails=false;await runAiTask(input,runtime);expect(usage).toHaveLength(2);expect(op?.state).toBe('completed');});
it('ambiguous save reply reconciles durable committed result without duplicate provider call',async()=>{commitReplyFails=true;await expect(runAiTask(input,runtime)).rejects.toMatchObject({code:'SAVE_FAILED'});commitReplyFails=false;const r=await runAiTask(input,runtime);expect(r.id).toBe(id(30));expect(m.provider).toHaveBeenCalledOnce();});
it('concurrent duplicate while provider is in flight returns IN_PROGRESS',async()=>{let done!:(v:typeof result)=>void;m.provider.mockImplementation(()=>new Promise(resolve=>{done=resolve;}));const a=runAiTask(input,runtime);await vi.waitFor(()=>expect(m.provider).toHaveBeenCalledOnce());await expect(runAiTask(input,runtime)).rejects.toMatchObject({code:'IN_PROGRESS'});done(result);await a;expect(m.provider).toHaveBeenCalledOnce();});
it('preflight authorization loss records no provider attempt and releases only its own operation',async()=>{m.assembly.mockResolvedValueOnce(assembly).mockRejectedValue(Error('revoked'));await expect(runAiTask(input,runtime)).rejects.toMatchObject({code:'FORBIDDEN'});expect(m.provider).not.toHaveBeenCalled();expect(usage).toHaveLength(0);expect(m.store).toHaveBeenCalledWith('release_ai_task_operation',{input:expect.objectContaining({beforeProvider:true})});});
it.each(['revoked VIEW Share','revoked COMMENT Share','removed destination member','expired MASTER assignment','inactive MASTER assignment'])('M14.18 pre-provider denial after %s',async()=>{
 const ref={entity_type:'ARTIFACT_VERSION',entity_id:id(70),context_role:'CURRENT_ARTIFACT',included_snapshot_hash:'c'.repeat(64),share_snapshot_id:id(71),permission_scope:{access:'SHARE_SNAPSHOT'}};
 const frozen={...assembly,providerInput:{...assembly.providerInput,input:'FROZEN_ONLY'},metadata:{...assembly.metadata,contextReferences:[...assembly.metadata.contextReferences,ref]}};
 m.assembly.mockResolvedValueOnce(frozen).mockRejectedValue(Error('Private destination detail'));
 await expect(runAiTask({...input,selectedContextRefs:[{entityType:'ARTIFACT_VERSION',entityId:id(70),contextRole:'CURRENT_ARTIFACT',shareId:id(72)}]},runtime)).rejects.toMatchObject({code:'FORBIDDEN',message:'AI task unavailable.'});
 expect(m.provider).not.toHaveBeenCalled();expect(saved).toBeNull();expect(usage).toHaveLength(0);
 expect(m.store).toHaveBeenCalledWith('release_ai_task_operation',{input:expect.objectContaining({beforeProvider:true})});
});
it('M14.18 active shared context sends only frozen provider data and persists exact Snapshot provenance',async()=>{
 const ref={entity_type:'ARTIFACT_VERSION',entity_id:id(70),context_role:'CURRENT_ARTIFACT',included_snapshot_hash:'c'.repeat(64),share_snapshot_id:id(71),permission_scope:{access:'SHARE_SNAPSHOT'}};
 const frozen={...assembly,providerInput:{...assembly.providerInput,input:'FROZEN_ONLY'},metadata:{...assembly.metadata,contextReferences:[...assembly.metadata.contextReferences,ref]}};m.assembly.mockResolvedValue(frozen);
 await runAiTask({...input,selectedContextRefs:[{entityType:'ARTIFACT_VERSION',entityId:id(70),contextRole:'CURRENT_ARTIFACT',shareId:id(72)}]},runtime);
 expect(m.provider).toHaveBeenCalledWith(frozen.providerInput);expect(JSON.stringify(m.provider.mock.calls)).not.toMatch(/NEWER_PRIVATE_STATE|sibling|storage_reference/);
 expect(m.store.mock.calls.find(([name])=>name==='save_ai_task_result')?.[1].input.references).toContainEqual(ref);
 expect(m.assembly.mock.calls.every(([request])=>request.selectedContextRefs[0].shareId===id(72))).toBe(true);
});
it('M14.18 changed Snapshot or excluded revoked optional source aborts stale preflight payload',async()=>{
 m.assembly.mockResolvedValueOnce(assembly).mockResolvedValue({...assembly,providerInput:{...assembly.providerInput,input:'Source excluded after revoke'}});
 await expect(runAiTask(input,runtime)).rejects.toMatchObject({code:'FORBIDDEN'});expect(m.provider).not.toHaveBeenCalled();
});
it('authorization loss after provider success records usage but never saves output',async()=>{m.assembly.mockResolvedValueOnce(assembly).mockResolvedValueOnce(assembly).mockRejectedValue(Error('removed'));await expect(runAiTask(input,runtime)).rejects.toMatchObject({code:'SAVE_FAILED'});expect(usage).toHaveLength(1);expect(saved).toBeNull();});
it('provider response containing configured credential is not persisted',async()=>{vi.stubEnv('M1411_TEST_SECRET','private-value-runtime');m.provider.mockResolvedValue({...result,text:'private-value-runtime'});await expect(runAiTask(input,runtime)).rejects.toMatchObject({code:'PROVIDER_FAILED'});expect(saved).toBeNull();});


it('structured provider content containing a credential cannot hide behind clean text',async()=>{vi.stubEnv('M1411_TEST_SECRET','private-value-runtime');m.provider.mockResolvedValue({...result,text:'Clean text',structured:{technique:'private-value-runtime'}});await expect(runAiTask(input,runtime)).rejects.toMatchObject({code:'PROVIDER_FAILED'});expect(saved).toBeNull();});

it.each([{}, {technique:'only'}, {...result.structured,extra:'private malformed body'}, {...result.structured,reasoning:null}, {...result.structured,reasoning:42}, {gap:'wrong task'}])('invalid task output logs failure, retains no body, then retries exactly once %#',async structured=>{
 m.provider.mockResolvedValueOnce({...result,structured});
 await expect(runAiTask(input,runtime)).rejects.toMatchObject({code:'PROVIDER_FAILED',message:'AI task unavailable.'});
 expect(saved).toBeNull();expect(m.store.mock.calls.some(([name])=>name==='save_ai_task_result')).toBe(false);
 expect(usage[0]).toMatchObject({successFailure:'FAILURE'});expect(JSON.stringify(usage)).not.toContain('private malformed body');
 const a=await runAiTask(input,runtime),b=await runAiTask(input,runtime);
 expect(a).toEqual(b);expect(m.provider).toHaveBeenCalledTimes(2);expect(usage).toHaveLength(2);expect(op?.state).toBe('completed');
});
it.each(['outputSchema','schema','validated','structured','output_type'])('rejects validation override %s',async key=>{
 await expect(runAiTask({...input,[key]:true},runtime)).rejects.toMatchObject({code:'VALIDATION_ERROR'});expect(m.provider).not.toHaveBeenCalled();
});

it('valid Gap Analysis reaches canonical persistence using its own Task Contract',async()=>{
 m.availability.mockResolvedValue({available:true,aiRole:'COMPARATIVE_CRITICAL_ANALYST',allowedTasks:['GAP_ANALYSIS']});
 const gapAssembly={...assembly,metadata:{...assembly.metadata,aiRole:'COMPARATIVE_CRITICAL_ANALYST'}};
 m.assembly.mockResolvedValue(gapAssembly);
 const structured={gap:'Missing function',evidence:'Source-backed observation',why_it_matters:'Impact',candidate_direction:'Investigate',verification_needed:'Human review'};
 m.provider.mockResolvedValue({...result,structured});
 // Read projection models the exact canonical task row returned after persistence.
 m.read.mockImplementation(async()=>({data:saved?{...saved,task_type:'GAP_ANALYSIS',ai_role:'COMPARATIVE_CRITICAL_ANALYST'}:null,error:null}));
 const r=await runAiTask({...input,taskType:'GAP_ANALYSIS'},runtime);
 expect(r.output_type).toBe('ANALYSIS');expect(JSON.parse(r.response_text)).toEqual(structured);
 expect(usage[0]).toMatchObject({successFailure:'SUCCESS'});
});


it.each(['SCAMPER_ASSISTANCE','BRAINSTORMING_ASSISTANCE','SYSTEM_STRUCTURE_ANALYSIS','GAP_ANALYSIS','PATENT_RESEARCH_ASSISTANCE','COMPARATIVE_ANALYSIS','CRITICAL_REVIEW','SESSION10_GAP_REFINEMENT'])('AT-AI-006: %s retains server classification and explicit AI origin on retry',async taskType=>{
 const task=getAiTaskDefinition(taskType);
 const schema=(task as unknown as {outputSchema:{required:string[]}}).outputSchema;
 const structured=taskType==='PATENT_RESEARCH_ASSISTANCE'?patentTestResponse('[]'):Object.fromEntries(schema.required.map(k=>[k,'Cited source; confidence 100%; candidate accepted; still requires human verification']));
 m.availability.mockResolvedValue({available:true,aiRole:task.allowedRole,allowedTasks:[taskType]});
 m.assembly.mockResolvedValue({...assembly,providerInput:{...assembly.providerInput,input:'[]'},metadata:{...assembly.metadata,aiRole:task.allowedRole,modelProfile:task.defaultModelProfile}});
 m.provider.mockResolvedValue({...result,structured});
 m.read.mockImplementation(async()=>({data:saved?{...saved,task_type:taskType,ai_role:task.allowedRole}:null,error:null}));
 const session10=taskType==='SESSION10_GAP_REFINEMENT'?{session10CheckpointId:id(72),reconstructionAiOutputId:id(73),selectedContextRefs:[{entityType:'ARTIFACT_VERSION',entityId:id(70),contextRole:'CURRENT_ARTIFACT'},{entityType:'DEVELOPMENT_OBJECT',entityId:id(71),contextRole:'GAP'}]}:{};
 if(taskType==='SESSION10_GAP_REFINEMENT')m.scope.mockImplementation(async(name:string)=>({data:name==='resolve_session10_checkpoint'?{id:id(72),reconstruction_ai_output_id:id(73),confirmed_by:actor,baseline_version_id:id(70)}:true,error:null}));
 const a=await runAiTask({...input,taskType,...session10},runtime),b=await runAiTask({...input,taskType,...session10},runtime);
 expect(a).toEqual(b);expect(m.provider).toHaveBeenCalledOnce();
 expect(a).toMatchObject({ai_generated:true,requested_by:actor,ai_role:task.allowedRole,task_type:taskType,output_type:task.outputType,verification_status:'UNVERIFIED',disposition:'KEEP_FOR_REVIEW'});
 expect(['EVIDENCE','DECISION','APPROVED_CONTENT','VERIFIED_FACT']).not.toContain(a.output_type);
 expect(a).not.toHaveProperty('metadata');expect(a).not.toHaveProperty('model_provider_reference');
 const write=m.store.mock.calls.find(([name])=>name==='save_ai_task_result')?.[1].input;
 expect(write?.outputType).toBe(task.outputType);expect(write).not.toHaveProperty('verification_status');
 expect(m.store.mock.calls.every(([name])=>['begin_ai_task_operation','record_ai_task_attempt','save_ai_task_result'].includes(name))).toBe(true);
});
it.each(['output_type','ai_role','task_type','verificationStatus','requestedBy','ai_generated','createVerifiedEvidence','verifiedBy','verifiedAt','promoteToEvidence','sourceBypass'])('AT-AI-006: client classification override %s rejected',async key=>{
 await expect(runAiTask({...input,[key]:'VERIFIED'},runtime)).rejects.toMatchObject({code:'VALIDATION_ERROR'});expect(m.provider).not.toHaveBeenCalled();expect(m.store).not.toHaveBeenCalled();
});
it.each(['GAP_ANALYSIS','COMPARATIVE_ANALYSIS','PATENT_RESEARCH_ASSISTANCE'])('M14.17: %s over verified Evidence stays unverified and never invokes Evidence operations',async taskType=>{
 const task=getAiTaskDefinition(taskType),fields=(task as unknown as {outputSchema:{required:string[]}}).outputSchema.required;
 const sourceInput=JSON.stringify([{layer:'AUTHORIZED EVIDENCE',content:{sources:[{reference:'source-001',role:'EVIDENCE',content:{title:'Source',verification_status:'VERIFIED'}}]}}]);
 const structured=taskType==='PATENT_RESEARCH_ASSISTANCE'?patentTestResponse(sourceInput):Object.fromEntries(fields.map(k=>[k,'AI interpretation of VERIFIED Evidence; confidence 100%; suggested https://example.test/unreviewed; human review required']));
 const reference={entity_type:'EVIDENCE',entity_id:id(90),context_role:'EVIDENCE',included_snapshot_hash:'b'.repeat(64),share_snapshot_id:null,permission_scope:{access:'SOURCE'}};
 m.availability.mockResolvedValue({available:true,aiRole:task.allowedRole,allowedTasks:[taskType]});
 m.assembly.mockResolvedValue({...assembly,providerInput:{...assembly.providerInput,input:sourceInput},metadata:{...assembly.metadata,aiRole:task.allowedRole,contextReferences:[...assembly.metadata.contextReferences,reference]}});
 m.provider.mockResolvedValue({...result,structured});
 m.read.mockImplementation(async()=>({data:saved?{...saved,task_type:taskType,ai_role:task.allowedRole}:null,error:null}));
 const output=await runAiTask({...input,taskType},runtime);
 expect(output).toMatchObject({ai_generated:true,output_type:task.outputType,verification_status:'UNVERIFIED'});
 expect(JSON.parse(output.response_text)).toEqual(structured);
 expect(m.store.mock.calls.map(([name])=>name)).toEqual(['begin_ai_task_operation','record_ai_task_attempt','save_ai_task_result']);
 expect(m.scope.mock.calls.every(([name])=>name==='can_read_development_project')).toBe(true);
 expect(m.store.mock.calls.at(-1)?.[1].input.references).toContainEqual(reference);
 expect(saved).not.toHaveProperty('verified_by');expect(saved).not.toHaveProperty('verified_at');
});
it.each([['EVIDENCE','EVIDENCE'],['PATENT','PATENT_RECORD']])('AT-AI-006: authorized %s context does not verify generated output',async(context_role,entity_type)=>{
 m.assembly.mockResolvedValue({...assembly,metadata:{...assembly.metadata,contextReferences:[...assembly.metadata.contextReferences,{entity_type,entity_id:id(90),context_role,included_snapshot_hash:'b'.repeat(64),share_snapshot_id:null,permission_scope:{access:'SOURCE'}}]}});
 await expect(runAiTask(input,runtime)).resolves.toMatchObject({ai_generated:true,verification_status:'UNVERIFIED'});
 expect(saved?.verification_status).toBe('UNVERIFIED');
 const write=m.store.mock.calls.find(([name])=>name==='save_ai_task_result')?.[1].input;
 expect(write?.references).toEqual(expect.arrayContaining([expect.objectContaining({context_role,entity_type})]));
});
it.each(['hidden peer selected','pool still private','membership removed','entry changed before dispatch'])('M14.19 fresh pre-provider assembly denies %s without provider usage or provenance',async()=>{
 m.availability.mockResolvedValue({available:true,aiRole:'BRAINSTORMING_FACILITATOR',allowedTasks:['BRAINSTORMING_ASSISTANCE']});
 const brain={...assembly,metadata:{...assembly.metadata,aiRole:'BRAINSTORMING_FACILITATOR'}};
 m.assembly.mockResolvedValueOnce(brain).mockRejectedValue(Error('Inaccessible Brainstorm content'));
 await expect(runAiTask({...input,taskType:'BRAINSTORMING_ASSISTANCE',selectedContextRefs:[{entityType:'BRAINSTORM_ENTRY',entityId:id(75),contextRole:'BRAINSTORM'}]},runtime)).rejects.toMatchObject({code:'FORBIDDEN'});
 expect(m.provider).not.toHaveBeenCalled();expect(usage).toHaveLength(0);expect(saved).toBeNull();expect(m.store.mock.calls.some(([name])=>name==='save_ai_task_result')).toBe(false);
});

// AT-AI-004 retains successful history while revoking current authority.
it.each(['same key','new key','known context'])('M14.20 removed requester %s cannot reuse Team authority',async attack=>{
 await runAiTask(input,runtime);const history=JSON.stringify({saved,op,usage});
 m.provider.mockClear();m.store.mockClear();m.assembly.mockClear();m.read.mockClear();
 m.scope.mockResolvedValue({data:false,error:null});
 const request=attack==='new key'?{...input,idempotencyKey:'after-removal'}:attack==='known context'?{...input,selectedContextRefs:[{entityType:'ARTIFACT_VERSION',entityId:id(90),contextRole:'CURRENT_ARTIFACT'}]}:input;
 await expect(runAiTask(request,runtime)).rejects.toMatchObject({code:'FORBIDDEN',message:'AI task unavailable.'});
 expect(m.assembly).not.toHaveBeenCalled();expect(m.provider).not.toHaveBeenCalled();expect(m.store).not.toHaveBeenCalled();expect(m.read).not.toHaveBeenCalled();
 expect(JSON.stringify({saved,op,usage})).toBe(history);
});
it('M14.20 completed replay rechecks database visibility after preflight',async()=>{
 await runAiTask(input,runtime);const history=JSON.stringify({saved,op,usage});
 m.provider.mockClear();m.read.mockResolvedValue({data:null,error:null});
 await expect(runAiTask(input,runtime)).rejects.toMatchObject({code:'FORBIDDEN'});
 expect(m.provider).not.toHaveBeenCalled();expect(JSON.stringify({saved,op,usage})).toBe(history);
});

const failureCases=['timeout','5xx','429','network','invalid structured','normalization'] as const;
it.each(failureCases)('M14.21 AT-AI-009 %s fails safely then retries exactly once',async kind=>{
 const transport=vi.fn<typeof fetch>();
 if(kind==='timeout')transport.mockImplementationOnce(()=>new Promise(()=>{}));
 else if(kind==='network')transport.mockRejectedValueOnce(new TypeError('PRIVATE_HEADER api-key /server/path SQL private prompt'));
 else if(kind==='5xx'||kind==='429')transport.mockResolvedValueOnce(new Response('PRIVATE_HEADER private prompt',{status:kind==='5xx'?503:429}));
 else transport.mockResolvedValueOnce(new Response(JSON.stringify(kind==='normalization'?{private:'PRIVATE_HEADER'}:{id:'resp_invalid',status:'completed',output:[{type:'message',role:'assistant',content:[{type:'output_text',text:JSON.stringify({technique:42})}]}],usage:{input_tokens:9,output_tokens:3}})));
 transport.mockResolvedValue(new Response(JSON.stringify({id:'resp_retry',status:'completed',output:[{type:'message',role:'assistant',content:[{type:'output_text',text:JSON.stringify(result.structured)}]}],usage:{input_tokens:12,output_tokens:6}})));
 const provider=new OpenAiResponsesProvider({apiKey:'mock-private-credential',models:{AI_STANDARD:'test-model'},timeoutMs:100},transport);
 await expect(runAiTask(input,{provider})).rejects.toMatchObject({code:'PROVIDER_FAILED',message:'AI task unavailable.'});
 expect(saved).toBeNull();expect(usage).toHaveLength(1);expect(usage[0]).toMatchObject({actorId:actor,successFailure:'FAILURE',inputUsage:kind==='invalid structured'?9:null,outputUsage:kind==='invalid structured'?3:null});
 expect(m.store.mock.calls.map(([name])=>name)).toEqual(['begin_ai_task_operation','record_ai_task_attempt','release_ai_task_operation']);
 expect(JSON.stringify(usage)).not.toMatch(/PRIVATE_HEADER|private prompt|mock-private|server.path|SQL/);
 const a=await runAiTask(input,{provider}),b=await runAiTask(input,{provider});
 expect(a).toEqual(b);expect(a.verification_status).toBe('UNVERIFIED');expect(transport).toHaveBeenCalledTimes(2);expect(usage).toHaveLength(2);
 expect(usage[1]).toMatchObject({successFailure:'SUCCESS'});
 expect(m.store.mock.calls.filter(([name])=>name==='save_ai_task_result')).toHaveLength(1);
 expect(m.store.mock.calls.find(([name])=>name==='save_ai_task_result')?.[1].input.references).toEqual(assembly.metadata.contextReferences);
});
it('M14.21 repeated failures retain distinct attempts and reject changed fingerprint',async()=>{
 m.provider.mockResolvedValue({...result,success:false,text:null,structured:null,error:{code:'RATE_LIMIT',retryable:true}});
 for(let i=0;i<2;i++)await expect(runAiTask(input,runtime)).rejects.toMatchObject({code:'PROVIDER_FAILED'});
 expect(usage).toHaveLength(2);expect(new Set(usage.map(v=>(v as {attemptId:string}).attemptId)).size).toBe(2);expect(saved).toBeNull();
 await expect(runAiTask({...input,userInstruction:'changed'},runtime)).rejects.toMatchObject({code:'IDEMPOTENCY_CONFLICT'});expect(m.provider).toHaveBeenCalledTimes(2);
 m.provider.mockResolvedValue(result);await runAiTask(input,runtime);expect(usage).toHaveLength(3);expect(m.store.mock.calls.filter(([name])=>name==='save_ai_task_result')).toHaveLength(1);
});
it('M14.21 concurrent retries after failure permit one provider attempt and one result',async()=>{
 m.provider.mockResolvedValueOnce({...result,success:false,text:null,structured:null,error:{code:'UNAVAILABLE',retryable:true}});
 await expect(runAiTask(input,runtime)).rejects.toMatchObject({code:'PROVIDER_FAILED'});
 let finish!:(v:typeof result)=>void;m.provider.mockImplementation(()=>new Promise(resolve=>{finish=resolve;}));
 const retry=runAiTask(input,runtime);await vi.waitFor(()=>expect(m.provider).toHaveBeenCalledTimes(2));
 await expect(runAiTask(input,runtime)).rejects.toMatchObject({code:'IN_PROGRESS'});finish(result);const output=await retry;
 expect(await runAiTask(input,runtime)).toEqual(output);expect(m.provider).toHaveBeenCalledTimes(2);expect(usage).toHaveLength(2);
 expect(m.store.mock.calls.filter(([name])=>name==='save_ai_task_result')).toHaveLength(1);
});
it('M14.21 failed attempt never caches authorization for a removed requester retry',async()=>{
 m.provider.mockResolvedValueOnce({...result,success:false,text:null,structured:null,error:{code:'TIMEOUT',retryable:true}});
 await expect(runAiTask(input,runtime)).rejects.toMatchObject({code:'PROVIDER_FAILED'});const history=JSON.stringify({saved,op,usage});
 m.provider.mockClear();m.assembly.mockClear();m.store.mockClear();m.scope.mockResolvedValue({data:false,error:null});
 await expect(runAiTask(input,runtime)).rejects.toMatchObject({code:'FORBIDDEN'});
 expect(m.provider).not.toHaveBeenCalled();expect(m.assembly).not.toHaveBeenCalled();expect(m.store).not.toHaveBeenCalled();expect(JSON.stringify({saved,op,usage})).toBe(history);
});
it('M14.30 lost browser delivery reuses committed result without another attempt or reference save',async()=>{
 let committedId:string|undefined;
 const deliver=async()=>{const output=await runAiTask(input,runtime);committedId=output.id;throw Error('Simulated browser disconnect after commit');};
 await expect(deliver()).rejects.toThrow('Simulated browser disconnect');
 const durable=JSON.stringify({saved,usage});
 const replay=await runAiTask(input,runtime);
 expect(replay.id).toBe(committedId);expect(op?.state).toBe('completed');
 expect(m.provider).toHaveBeenCalledOnce();expect(usage).toHaveLength(1);
 expect(m.store.mock.calls.filter(([name])=>name==='save_ai_task_result')).toHaveLength(1);
 expect(JSON.stringify({saved,usage})).toBe(durable);
});
it('M14.30 provider response metadata cannot select identity or alter completed replay',async()=>{
 const first=await runAiTask(input,runtime);const durable=JSON.stringify({saved,usage,op});
 expect(first.id).not.toBe(result.reference.responseId);
 expect(saved?.model_provider_reference).toBe('openai:resp_example');
 m.provider.mockResolvedValue({...result,reference:{provider:'openai',responseId:'resp_guessed'}});
 expect(await runAiTask(input,runtime)).toEqual(first);
 expect(m.provider).toHaveBeenCalledOnce();expect(JSON.stringify({saved,usage,op})).toBe(durable);
});
it.each(['providerRequestId','providerReference','responseId','model_provider_reference','attemptId','operationId'])('M14.30 client %s is not retry authority',async field=>{
 await runAiTask(input,runtime);const durable=JSON.stringify({saved,usage,op});
 await expect(runAiTask({...input,[field]:'resp_example'},runtime)).rejects.toMatchObject({code:'VALIDATION_ERROR',message:'AI task unavailable.'});
 expect(m.provider).toHaveBeenCalledOnce();expect(JSON.stringify({saved,usage,op})).toBe(durable);
});
it('M14.30 lost response followed by authority loss cannot reopen the committed result',async()=>{
 await runAiTask(input,runtime);const durable=JSON.stringify({saved,usage,op});
 m.store.mockClear();m.read.mockClear();m.scope.mockResolvedValue({data:false,error:null});
 await expect(runAiTask(input,runtime)).rejects.toMatchObject({code:'FORBIDDEN',message:'AI task unavailable.'});
 expect(m.provider).toHaveBeenCalledOnce();expect(m.store).not.toHaveBeenCalled();expect(m.read).not.toHaveBeenCalled();
 expect(JSON.stringify({saved,usage,op})).toBe(durable);
});
