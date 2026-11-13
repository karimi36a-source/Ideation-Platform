import {getMyRevisionStatus} from './revision-status';
import 'server-only';
import {z} from 'zod';
import {getAuthorizationContext,AuthorizationError} from '@/lib/auth/authorization';
import {createServerSupabaseClient} from '@/lib/db/server';
import {activityAvailabilitySchema} from '@/features/activities/availability-schema';
import {activityInstanceStatusSchema} from '@/features/activities/instance-schema';
import {artifactTypeSchema} from '@/features/artifacts/schema';
import {artifactVersionStatusSchema} from '@/features/artifacts/version-schema';
import {submissionSchema} from '@/features/artifacts/submission-schema';
import {myCurrentWorkSchema,type CurrentWorkContext,type CurrentWorkActivity,type CurrentWorkArtifact,type MyCurrentWork} from './current-work-schema';

type Db=Awaited<ReturnType<typeof createServerSupabaseClient>>;
type PageQuery={range:(start:number,end:number)=>PromiseLike<{data:unknown;error:unknown}>};
const uuid=z.uuid(),nullable=uuid.nullable();
const enrollment=z.object({id:uuid,user_id:uuid,cohort_id:uuid,status:z.string(),enrollment_role:z.string()});
const workspace=z.object({id:uuid,workspace_type:z.enum(['PERSONAL','TEAM']),owner_user_id:nullable,team_id:nullable,cohort_id:nullable,status:z.string(),visibility:z.string()});
const project=z.object({id:uuid,name:z.string(),project_type:z.string(),owner_user_id:nullable,owner_team_id:nullable,primary_workspace_id:uuid,status:z.string(),archived_at:z.string().nullable()});
const link=z.object({id:uuid,project_id:uuid,program_id:uuid,cohort_id:uuid,completed_at:z.string().nullable()});
const cohort=z.object({id:uuid,name:z.string(),program_id:uuid,curriculum_version_id:uuid,status:z.string()});
const course=z.object({id:uuid,name:z.string(),status:z.string()});
const curriculum=z.object({id:uuid,program_id:uuid,status:z.string()});
const team=z.object({id:uuid,name:z.string(),workspace_id:uuid,cohort_id:uuid,status:z.string(),archived_at:z.string().nullable()});
const session=z.object({id:uuid,curriculum_version_id:uuid,title:z.string(),session_number:z.number().int(),sequence:z.number().int(),status:z.string()});
const definition=z.object({id:uuid,session_definition_id:uuid,name:z.string(),workspace_mode:z.string().nullable(),sequence:z.number().int(),status:z.string()});
const catalog=z.object({course,cohort,curriculum,sessions:z.array(session),definitions:z.array(definition.extend({availability:activityAvailabilitySchema}))});
const instance=z.object({id:uuid,activity_definition_id:uuid,project_id:uuid,workspace_id:uuid,cohort_id:uuid,team_id:nullable,status:activityInstanceStatusSchema});
const output=z.object({activity_instance_id:uuid,artifact_id:uuid.nullable(),output_type:z.string()});
const artifact=z.object({id:uuid,project_id:uuid,workspace_id:uuid,activity_instance_id:nullable,title:z.string(),artifact_type:artifactTypeSchema,current_version_id:nullable,status:z.string(),archived_at:z.string().nullable()});
const version=z.object({id:uuid,artifact_id:uuid,version_number:z.number().int().positive(),status:artifactVersionStatusSchema,previous_version_id:nullable,approved_at:z.string().nullable()});
const submission=z.object({id:uuid,activity_instance_id:uuid,artifact_id:uuid,artifact_version_id:uuid,status:submissionSchema.shape.status});
const fields={enrollment:'id,user_id,cohort_id,status,enrollment_role',workspace:'id,workspace_type,owner_user_id,team_id,cohort_id,status,visibility',project:'id,name,project_type,owner_user_id,owner_team_id,primary_workspace_id,status,archived_at',link:'id,project_id,program_id,cohort_id,completed_at',cohort:'id,name,program_id,curriculum_version_id,status',course:'id,name,status',curriculum:'id,program_id,status',team:'id,name,workspace_id,cohort_id,status,archived_at',session:'id,curriculum_version_id,title,session_number,sequence,status',definition:'id,session_definition_id,name,workspace_mode,sequence,status',instance:'id,activity_definition_id,project_id,workspace_id,cohort_id,team_id,status',output:'activity_instance_id,artifact_id,output_type',artifact:'id,project_id,workspace_id,activity_instance_id,title,artifact_type,current_version_id,status,archived_at',version:'id,artifact_id,version_number,status,previous_version_id,approved_at',submission:'id,activity_instance_id,artifact_id,artifact_version_id,status'} as const;
async function rows<T>(schema:z.ZodType<T>,query:()=>PageQuery):Promise<T[]>{
 const result:T[]=[];
 for(let offset=0;;offset+=200){const page=await query().range(offset,offset+199);if(page.error)throw new Error('Unavailable');const values=z.array(schema).parse(page.data);result.push(...values);if(values.length<200)return result;}
}
async function rpc(db:Db,name:'can_read_development_project'|'get_team_workspace_access',id:string){
 const result=name==='can_read_development_project'?await db.rpc(name,{target_project:id}):await db.rpc(name,{target_workspace:id});if(result.error)throw new Error('Unavailable');return result.data;
}
type Scope={enrollment:z.infer<typeof enrollment>;workspace:z.infer<typeof workspace>;project:z.infer<typeof project>;link:z.infer<typeof link>;cohort:z.infer<typeof cohort>;course:z.infer<typeof course>;team:z.infer<typeof team>|null;catalog:z.infer<typeof catalog>};
/** Enumerate self-owned/participating scopes through ordinary caller RLS only.
 * Membership tables remain private: existing caller-bound capability helpers
 * validate Team and Project access. Role assignments are never a discovery key. */
async function scopes(db:Db,userId:string):Promise<Scope[]>{
 const enrollments=(await rows(enrollment,()=>db.from('enrollments').select(fields.enrollment).eq('user_id',userId).eq('enrollment_role','participant').eq('status','active').order('created_at').order('id'))).filter(e=>e.user_id===userId&&e.status==='active'&&e.enrollment_role==='participant');
 if(!enrollments.length)return [];
 const cohortIds=[...new Set(enrollments.map(e=>e.cohort_id))];
 const personal=await rows(workspace,()=>db.from('workspaces').select(fields.workspace).eq('workspace_type','PERSONAL').eq('owner_user_id',userId).eq('status','active').order('id'));
 const teams=await rows(workspace,()=>db.from('workspaces').select(fields.workspace).eq('workspace_type','TEAM').in('cohort_id',cohortIds).eq('status','active').order('id'));
 const result:Scope[]=[];
 for(const w of [...personal,...teams]){
  if(w.status!=='active'||w.visibility!=='private')continue;
  let t:z.infer<typeof team>|null=null;
  if(w.workspace_type==='PERSONAL'){if(w.owner_user_id!==userId||w.team_id!==null)continue;}
  else{
   if(w.team_id===null||w.cohort_id===null||!cohortIds.includes(w.cohort_id))continue;
   const access=await rpc(db,'get_team_workspace_access',w.id);if(access!=='member'&&access!=='team_lead')continue;
   t=(await rows(team,()=>db.from('teams').select(fields.team).eq('id',w.team_id!).eq('cohort_id',w.cohort_id!).eq('status','active').is('archived_at',null).order('id'))).find(t=>t.id===w.team_id&&t.workspace_id===w.id&&t.cohort_id===w.cohort_id&&t.status==='active'&&t.archived_at===null)??null;
   if(!t)continue;
  }
  const projects=await rows(project,()=>{let q=db.from('development_projects').select(fields.project).eq('primary_workspace_id',w.id).eq('project_type',t?'team':'individual').eq('status','active').is('archived_at',null);q=t?q.eq('owner_team_id',t.id):q.eq('owner_user_id',userId);return q.order('id');});
  for(const p of projects){
   if(p.primary_workspace_id!==w.id||p.status!=='active'||p.archived_at!==null||(t?p.project_type!=='team'||p.owner_team_id!==t.id||p.owner_user_id!==null:p.project_type!=='individual'||p.owner_user_id!==userId||p.owner_team_id!==null))continue;
   if(await rpc(db,'can_read_development_project',p.id)!==true)continue;
   for(const l of await rows(link,()=>db.from('project_program_links').select(fields.link).eq('project_id',p.id).in('cohort_id',cohortIds).is('completed_at',null).order('id'))){
    if(l.project_id!==p.id||l.completed_at!==null||(t&&l.cohort_id!==t.cohort_id))continue;
    const e=enrollments.find(e=>e.cohort_id===l.cohort_id);if(!e)continue;
    const c=(await rows(cohort,()=>db.from('cohorts').select(fields.cohort).eq('id',l.cohort_id).in('status',['planned','active']).order('id'))).find(c=>c.id===l.cohort_id&&c.program_id===l.program_id&&['planned','active'].includes(c.status));if(!c)continue;
    const answer=await db.rpc('get_my_current_work_catalog',{target_project:p.id,target_workspace:w.id,target_cohort:c.id,target_team:t?.id??null});
    if(answer.error)throw new Error('Unavailable');if(answer.data===null)continue;
    const cat=catalog.parse(answer.data);
    if(cat.course.id!==l.program_id||cat.course.status!=='active'||cat.cohort.id!==c.id||cat.cohort.program_id!==cat.course.id||cat.cohort.curriculum_version_id!==cat.curriculum.id||cat.curriculum.program_id!==cat.course.id||cat.curriculum.status!=='approved')throw new Error('Unavailable');
    result.push({enrollment:e,workspace:w,project:p,link:l,cohort:c,course:cat.course,team:t,catalog:cat});
   }
  }
 }
 return result;
}
function versionRef(v:z.infer<typeof version>){return {id:v.id,versionNumber:v.version_number,status:v.status};}
async function activityWork(db:Db,s:Scope,instances:z.infer<typeof instance>[]){
 const result=new Map<string,CurrentWorkArtifact[]>();if(!instances.length)return result;
 const ids=instances.map(i=>i.id);
 const outputs=(await rows(output,()=>db.from('activity_outputs').select(fields.output).in('activity_instance_id',ids).eq('output_type','artifact').order('id'))).filter(o=>ids.includes(o.activity_instance_id)&&o.output_type==='artifact'&&o.artifact_id!==null);
 const submissions=(await rows(submission,()=>db.from('submissions').select(fields.submission).in('activity_instance_id',ids).order('id'))).filter(v=>ids.includes(v.activity_instance_id));
 const linkedIds=[...new Set([...outputs.map(o=>o.artifact_id!),...submissions.map(v=>v.artifact_id)])];
 const bound=await rows(artifact,()=>db.from('artifacts').select(fields.artifact).eq('project_id',s.project.id).eq('workspace_id',s.workspace.id).in('activity_instance_id',ids).eq('status','ACTIVE').is('archived_at',null).order('id'));
 const linked=linkedIds.length?await rows(artifact,()=>db.from('artifacts').select(fields.artifact).eq('project_id',s.project.id).eq('workspace_id',s.workspace.id).in('id',linkedIds).eq('status','ACTIVE').is('archived_at',null).order('id')):[];
 const artifacts=[...new Map([...bound,...linked].filter(a=>a.project_id===s.project.id&&a.workspace_id===s.workspace.id&&a.status==='ACTIVE'&&a.archived_at===null&&(a.activity_instance_id!==null&&ids.includes(a.activity_instance_id)||linkedIds.includes(a.id))).map(a=>[a.id,a])).values()];
 if(!artifacts.length)return result;
 const versions=await rows(version,()=>db.from('artifact_versions').select(fields.version).in('artifact_id',artifacts.map(a=>a.id)).order('version_number').order('id'));
 for(const i of instances){
  const items:CurrentWorkArtifact[]=[];
  for(const a of artifacts){
   if(a.activity_instance_id!==i.id&&!outputs.some(o=>o.activity_instance_id===i.id&&o.artifact_id===a.id)&&!submissions.some(v=>v.activity_instance_id===i.id&&v.artifact_id===a.id))continue;
   const all=versions.filter(v=>v.artifact_id===a.id).sort((a,b)=>a.version_number-b.version_number),current=all.find(v=>v.id===a.current_version_id&&['CURRENT','APPROVED'].includes(v.status)&&v.approved_at!==null);
   const drafts=all.filter(v=>v.status==='DRAFT'&&(a.artifact_type!=='MIND_MAP'||v.id===all.at(-1)?.id));
   items.push({id:a.id,title:a.title,artifactType:a.artifact_type,drafts:drafts.map(versionRef),approvedOutput:current?versionRef(current):null,
    submissions:submissions.filter(v=>v.activity_instance_id===i.id&&v.artifact_id===a.id).flatMap(v=>{const ver=all.find(x=>x.id===v.artifact_version_id);return ver?[{id:v.id,artifactVersionId:ver.id,versionNumber:ver.version_number,previousVersionId:ver.previous_version_id,status:v.status,revisionRequested:false}]:[];}),
   });
  }
  result.set(i.id,items);
 }
 return result;
}
async function candidates(db:Db,s:Scope):Promise<CurrentWorkActivity[]>{
 const sessions=s.catalog.sessions.filter(v=>v.curriculum_version_id===s.cohort.curriculum_version_id&&v.status==='active');
 const definitions=s.catalog.definitions.filter(d=>d.status==='active'&&sessions.some(v=>v.id===d.session_definition_id)&&d.workspace_mode===(s.team?'Team Workspace':'Personal Workspace'));
 const instances=(await rows(instance,()=>{let q=db.from('activity_instances').select(fields.instance).eq('project_id',s.project.id).eq('workspace_id',s.workspace.id).eq('cohort_id',s.cohort.id).neq('status','archived');q=s.team?q.eq('team_id',s.team.id):q.is('team_id',null);return q.order('id');})).filter(i=>i.project_id===s.project.id&&i.workspace_id===s.workspace.id&&i.cohort_id===s.cohort.id&&i.team_id===(s.team?.id??null)&&i.status!=='archived'&&definitions.some(d=>d.id===i.activity_definition_id));
 const work=await activityWork(db,s,instances),result:CurrentWorkActivity[]=[];
 // Curriculum sequence orders facts only, never chooses or recommends a winner.
 definitions.sort((a,b)=>sessions.find(s=>s.id===a.session_definition_id)!.sequence-sessions.find(s=>s.id===b.session_definition_id)!.sequence||a.sequence-b.sequence);
 for(const d of definitions){
  const availability=d.availability;
  const sess=sessions.find(v=>v.id===d.session_definition_id)!;
  const common={session:{id:sess.id,title:sess.title,sessionNumber:sess.session_number,sequence:sess.sequence},definition:{id:d.id,name:d.name,sequence:d.sequence},availability};
  for(const i of instances.filter(i=>i.activity_definition_id===d.id)){
   const items=work.get(i.id)??[];
   // Completed execution is retained only to expose canonical approved output;
   // it is explicitly marked completed, never an active recommendation.
   if(i.status==='completed'&&!items.some(a=>a.approvedOutput!==null))continue;
   result.push({...common,instanceId:i.id,status:i.status,work:items});
  }
  if(availability.available)result.push({...common,instanceId:null,status:null,work:[]});
 }
 return result;
}
/** Self-service metadata aggregation only. No arbitrary identity/scope inputs,
 * privileged client, writes, cached permissions, priority, selected context or
 * implicit Share traversal. ID ordering is pagination stability, not ranking. */
export async function getMyCurrentWork(input:unknown={}):Promise<MyCurrentWork>{
 if(!z.strictObject({}).safeParse(input).success)throw new AuthorizationError('VALIDATION_ERROR');
 try{
  const actor=await getAuthorizationContext(),db=await createServerSupabaseClient();
  const allowed=await scopes(db,actor.userId),contexts:CurrentWorkContext[]=[];
  for(const s of allowed)contexts.push({id:s.link.id,enrollmentId:s.enrollment.id,course:{id:s.course.id,name:s.course.name},cohort:{id:s.cohort.id,name:s.cohort.name},team:s.team?{id:s.team.id,name:s.team.name}:null,workspace:{id:s.workspace.id,type:s.workspace.workspace_type},project:{id:s.project.id,name:s.project.name},activities:await candidates(db,s)});
  // Revalidate scope after aggregation so membership/enrollment revocation does
  // not survive through previously fetched metadata or a privileged role.
  if((await getAuthorizationContext()).userId!==actor.userId)throw new Error('Unavailable');
  const current=new Set((await scopes(db,actor.userId)).map(s=>s.link.id));
  const unread=await db.from('notifications').select('id',{count:'exact',head:true}).eq('recipient_user_id',actor.userId).is('read_at',null);
  if(unread.error||!z.number().int().nonnegative().safeParse(unread.count).success||(await getAuthorizationContext()).userId!==actor.userId)throw new Error('Unavailable');
  const revisions=new Set((await getMyRevisionStatus()).outstanding.map(i=>i.submissionId));
  if((await getAuthorizationContext()).userId!==actor.userId)throw new Error('Unavailable');
  const visible=contexts.filter(c=>current.has(c.id)).map(c=>({...c,activities:c.activities.map(a=>({...a,work:a.work.map(w=>({...w,submissions:w.submissions.map(s=>({...s,revisionRequested:revisions.has(s.id)}))}))}))}));
  return myCurrentWorkSchema.parse({contexts:visible,unreadNotificationCount:unread.count});
 }catch(error){throw new AuthorizationError(error instanceof AuthorizationError&&error.code==='AUTH_REQUIRED'?'AUTH_REQUIRED':'NOT_FOUND');}
}

