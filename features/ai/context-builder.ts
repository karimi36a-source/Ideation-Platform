import 'server-only';
import {z} from 'zod';
import {isDeepStrictEqual} from 'node:util';
import {getAuthorizationContext,AuthorizationError} from '@/lib/auth/authorization';
import {createServerSupabaseClient} from '@/lib/db/server';
import {getAiTaskDefinition} from './task-registry';
import {aiContextBuilderInputSchema,aiContextCandidateSchema,type AiContextCandidate} from './context-builder-schema';
import {getActivityAiAvailability} from './activity-availability';

const record=z.record(z.string(),z.json());
// Narrative/structure allowlist only. Never hydrate IDs, links, File references,
// relationship graphs, contributors, rosters, audit or arbitrary JSON metadata.
const contentKeys=new Set(['name','title','description','content','text','notes','summary','label','labels','sections','title_notes','abstract','abstract_notes','description_notes','claims','claims_notes','drawings','drawings_notes','bibliographic_information','bibliographic_notes','structure','systems','subsystems','components','functions','nodes','children','problem','solution','gap','gaps','reasoning','question','outcome','instructions','method_type','artifact_type','object_type','content_snapshot','feedback_type','evidence_type','source_name','verification_status','claim_locator','publication_number','source_database','abstract_text','ipc_cpc','uncertainties','verification_needed']);
function minimize(value:unknown,secrets:readonly string[],depth=0):unknown{
 if(depth>8)return undefined;
 if(typeof value==='string'){
  if(value.length>12000||secrets.some(secret=>value.includes(secret))||/\bsk-[a-zA-Z0-9_-]{8,}|eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+|postgres(?:ql)?:\/\/|(?:storage_reference|service_role|api_key|access_token)\s*[=:]/i.test(value))throw Error('Unsafe context');
  return value.replace(/https?:\/\/[^\s<>"']+/gi,'[URL omitted]');
 }
 if(value===null||typeof value==='number'||typeof value==='boolean')return value;
 if(Array.isArray(value))return value.slice(0,64).map(v=>minimize(v,secrets,depth+1)).filter(v=>v!==undefined);
 if(value&&typeof value==='object')return Object.fromEntries(Object.entries(value).filter(([key])=>contentKeys.has(key)).map(([key,v])=>[key,minimize(v,secrets,depth+1)]).filter(([,v])=>v!==undefined));
 return undefined;
}
/** Current, caller-bound context only. References are provenance candidates,
 * not reusable authority. No provider, final prompt or durable output is made.
 */
export async function buildAiContext(input:unknown){
 const parsed=aiContextBuilderInputSchema.safeParse(input);
 if(!parsed.success)throw new AuthorizationError('VALIDATION_ERROR');
 try{
  const request=parsed.data,task=getAiTaskDefinition(request.taskType),actor=await getAuthorizationContext(),db=await createServerSupabaseClient();
  if(task.taskType==='SESSION10_GAP_REFINEMENT'&&request.selectedContextRefs.filter(ref=>ref.contextRole==='GAP').length!==1)throw new AuthorizationError('FORBIDDEN');
  const secrets=Object.entries(process.env).filter(([key,v])=>!key.startsWith('NEXT_PUBLIC_')&&/(SECRET|SERVICE_ROLE|PASSWORD|TOKEN|API_KEY|DATABASE_URL)/i.test(key)&&v&&v.length>=8).map(([,v])=>v!);
  const scope={projectId:request.projectId,workspaceId:request.workspaceId,...(request.activityInstanceId?{activityInstanceId:request.activityInstanceId}:{})};
  const brainstormSelected=request.selectedContextRefs.some(ref=>ref.entityType==='BRAINSTORM_ENTRY'&&!task.context.forbidden.includes(ref.contextRole));
  const checkBrainstormAvailability=async()=>{
   if(!brainstormSelected)return;
   if(!request.activityInstanceId)throw new AuthorizationError('FORBIDDEN');
   const availability=await getActivityAiAvailability({...scope,activityInstanceId:request.activityInstanceId,requestedTaskType:task.taskType});
   if(!availability.available)throw new AuthorizationError('FORBIDDEN');
  };
  await checkBrainstormAvailability();
  const query=async(ref:{entityType:string;entityId:string;contextRole:string;shareId?:string})=>{
   const result=await db.rpc('resolve_ai_context_source',{input:{...scope,...ref}});
   if(result.error)throw new AuthorizationError('FORBIDDEN');
   if(result.data===null)return null;
   const value=record.parse(result.data),{content,...candidate}=value,reference=aiContextCandidateSchema.parse(candidate);
   if(reference.entity_type!==ref.entityType||reference.entity_id!==ref.entityId||reference.context_role!==ref.contextRole||(reference.share_snapshot_id!==null)!==(ref.shareId!==undefined))throw Error('Invalid context');
   const minimized=minimize(content,secrets);
   if(!minimized||typeof minimized!=='object'||Object.keys(minimized).length===0)return null;
   return {reference,content:minimized};
  };
  const envelope={entityType:'PROJECT',entityId:request.projectId,contextRole:'CURRENT_PROJECT'};
  if(!await query(envelope))throw new AuthorizationError('FORBIDDEN');
  const selected=[...request.selectedContextRefs];
  if(task.context.required.includes('CURRENT_PROJECT')&&!selected.some(r=>r.contextRole==='CURRENT_PROJECT'))selected.push(envelope as typeof selected[number]);
  if(task.context.required.includes('COURSE_CONTEXT')&&!selected.some(r=>r.contextRole==='COURSE_CONTEXT')&&request.activityInstanceId)selected.push({entityType:'ACTIVITY_INSTANCE',entityId:request.activityInstanceId,contextRole:'COURSE_CONTEXT'});
  const refs=[...new Map(selected.map(ref=>[JSON.stringify(ref),ref])).values()].sort((a,b)=>`${a.contextRole}:${a.entityId}:${a.shareId??''}`.localeCompare(`${b.contextRole}:${b.entityId}:${b.shareId??''}`));
  const entries:{reference:AiContextCandidate;content:unknown}[]=[],admitted:typeof refs=[];
  for(const ref of refs){
   if(task.context.forbidden.includes(ref.contextRole))continue;
   const required=task.context.required.includes(ref.contextRole);
   try{
    const before=await query(ref);
    if(!before){if(required)throw Error('Required context unavailable');continue;}
    const current=await query(ref);
    if(!current||!isDeepStrictEqual(current,before)){if(required)throw Error('Required context changed');continue;}
    entries.push(current);admitted.push(ref);
   }catch{if(required)throw new AuthorizationError('FORBIDDEN');}
  }
  if(task.context.required.some(role=>!entries.some(entry=>entry.reference.context_role===role)))throw new AuthorizationError('FORBIDDEN');
  if((await getAuthorizationContext()).userId!==actor.userId||!await query(envelope))throw new AuthorizationError('FORBIDDEN');
  // Re-check selected sources after all awaited work and the refreshed session.
  // A provenance candidate or an earlier successful read is never authority.
  for(let i=entries.length-1;i>=0;i--){
   const entry=entries[i],ref=admitted[i];
   let current:null|typeof entry=null;
   try{if(ref)current=await query(ref);}catch{/* Fail closed without raw diagnostics. */}
   if(!current||!isDeepStrictEqual(current,entry)){
    if(task.context.required.includes(entry.reference.context_role))throw new AuthorizationError('FORBIDDEN');
    entries.splice(i,1);
   }
  }
  await checkBrainstormAvailability();
  return {taskType:task.taskType,context:entries.map(entry=>({role:entry.reference.context_role,content:entry.content})),references:entries.map(entry=>entry.reference)};
 }catch(error){throw new AuthorizationError(error instanceof AuthorizationError&&error.code==='AUTH_REQUIRED'?'AUTH_REQUIRED':'FORBIDDEN');}
}


