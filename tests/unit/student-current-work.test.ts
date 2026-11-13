vi.mock('@/features/progress/revision-status',()=>({getMyRevisionStatus:async()=>({outstanding:[{submissionId:'00000000-0000-4000-8000-000000000702'}],history:[]})}));
import {beforeEach,expect,it,vi} from 'vitest';
import {readFileSync} from 'node:fs';
vi.mock('server-only',()=>({}));
const m=vi.hoisted(()=>({actor:vi.fn(),rpc:vi.fn()}));
vi.mock('@/lib/auth/authorization',async original=>({...await original<typeof import('@/lib/auth/authorization')>(),getAuthorizationContext:m.actor}));
vi.mock('@/lib/db/server',()=>({createServerSupabaseClient:async()=>({from:builder,rpc:m.rpc})}));
import {getMyCurrentWork} from '@/features/progress/current-work';
const id=(n:number)=>'00000000-0000-4000-8000-'+String(n).padStart(12,'0');
type Row=Record<string,unknown>;
let tables:Record<string,Row[]>,queries:{table:string;columns:string;head:boolean}[],roles:Map<string,string>,denied:Set<string>;
function builder(table:string){
 const filters:((r:Row)=>boolean)[]=[],ordering:{key:string;asc:boolean}[]=[];let columns='',head=false;
 const execute=(start=0,end=Infinity)=>{queries.push({table,columns,head});const data=[...(tables[table]??[])].filter(r=>filters.every(f=>f(r)));for(const {key,asc} of [...ordering].reverse())data.sort((a,b)=>a[key]===b[key]?0:(a[key]!<b[key]!?-1:1)*(asc?1:-1));return {data:head?null:data.slice(start,end+1),count:head?data.length:null,error:null};};
 const q={select:(v:string,options?:{head?:boolean})=>{columns=v;head=options?.head??false;return q;},eq:(k:string,v:unknown)=>{filters.push(r=>r[k]===v);return q;},neq:(k:string,v:unknown)=>{filters.push(r=>r[k]!==v);return q;},is:(k:string,v:unknown)=>{filters.push(r=>r[k]===v);return q;},in:(k:string,v:unknown[])=>{filters.push(r=>v.includes(r[k]));return q;},order:(key:string,options?:{ascending?:boolean})=>{ordering.push({key,asc:options?.ascending!==false});return q;},range:async(start:number,end:number)=>execute(start,end),then:(resolve:unknown,reject:unknown)=>Promise.resolve(execute()).then(resolve as never,reject as never)};return q;
}
beforeEach(()=>{
 vi.resetAllMocks();queries=[];roles=new Map([[id(11),'member']]);denied=new Set();m.actor.mockResolvedValue({userId:id(1),assignments:[{roleCode:'ADMIN'}]});
 tables={
  enrollments:[{id:id(101),user_id:id(1),cohort_id:id(51),status:'active',enrollment_role:'participant'},{id:id(102),user_id:id(2),cohort_id:id(51),status:'active',enrollment_role:'participant'}],
  workspaces:[{id:id(10),workspace_type:'PERSONAL',owner_user_id:id(1),team_id:null,cohort_id:null,status:'active',visibility:'private'},{id:id(11),workspace_type:'TEAM',owner_user_id:null,team_id:id(31),cohort_id:id(51),status:'active',visibility:'private'},{id:id(12),workspace_type:'PERSONAL',owner_user_id:id(2),team_id:null,cohort_id:null,status:'active',visibility:'private'},{id:id(13),workspace_type:'TEAM',owner_user_id:null,team_id:id(32),cohort_id:id(51),status:'active',visibility:'private'}],
  teams:[{id:id(31),workspace_id:id(11),cohort_id:id(51),name:'Team A',status:'active',archived_at:null},{id:id(32),workspace_id:id(13),cohort_id:id(51),name:'Team B SECRET',status:'active',archived_at:null}],
  development_projects:[{id:id(201),name:'Personal project',project_type:'individual',owner_user_id:id(1),owner_team_id:null,primary_workspace_id:id(10),status:'active',archived_at:null},{id:id(202),name:'Team project',project_type:'team',owner_user_id:null,owner_team_id:id(31),primary_workspace_id:id(11),status:'active',archived_at:null},{id:id(203),name:'A2 SECRET',project_type:'individual',owner_user_id:id(2),owner_team_id:null,primary_workspace_id:id(12),status:'active',archived_at:null},{id:id(204),name:'Team B SECRET',project_type:'team',owner_user_id:null,owner_team_id:id(32),primary_workspace_id:id(13),status:'active',archived_at:null}],
  project_program_links:[201,202,203,204].map((n,i)=>({id:id(301+i),project_id:id(n),program_id:id(61),cohort_id:id(51),completed_at:null})),
  cohorts:[{id:id(51),name:'Course cohort',program_id:id(61),curriculum_version_id:id(71),status:'active'}],programs:[{id:id(61),name:'Professional Course',status:'active'}],curriculum_versions:[{id:id(71),program_id:id(61),status:'approved'}],
  session_definitions:[{id:id(81),curriculum_version_id:id(71),title:'Session 2',session_number:2,sequence:2,status:'active'},{id:id(82),curriculum_version_id:id(71),title:'Session 1',session_number:1,sequence:1,status:'active'}],
  activity_definitions:[{id:id(91),session_definition_id:id(81),name:'Team Activity',workspace_mode:'Team Workspace',sequence:1,status:'active'},{id:id(92),session_definition_id:id(82),name:'Personal Activity',workspace_mode:'Personal Workspace',sequence:1,status:'active'},{id:id(93),session_definition_id:id(82),name:'Earlier configured Activity',workspace_mode:'Team Workspace',sequence:2,status:'active'}],
  activity_instances:[{id:id(401),activity_definition_id:id(91),project_id:id(202),workspace_id:id(11),cohort_id:id(51),team_id:id(31),status:'active'},{id:id(402),activity_definition_id:id(92),project_id:id(201),workspace_id:id(10),cohort_id:id(51),team_id:null,status:'active'},{id:id(403),activity_definition_id:id(93),project_id:id(202),workspace_id:id(11),cohort_id:id(51),team_id:id(31),status:'revision_requested'}],
  activity_outputs:[],
  artifacts:[{id:id(501),project_id:id(202),workspace_id:id(11),activity_instance_id:id(401),title:'Team work',artifact_type:'PROBLEM_BANK',current_version_id:id(601),status:'ACTIVE',archived_at:null},{id:id(502),project_id:id(201),workspace_id:id(10),activity_instance_id:id(402),title:'My work',artifact_type:'PROBLEM_BANK',current_version_id:null,status:'ACTIVE',archived_at:null},{id:id(503),project_id:id(202),workspace_id:id(11),activity_instance_id:null,title:'Unrelated SECRET',artifact_type:'PROBLEM_BANK',current_version_id:null,status:'ACTIVE',archived_at:null}],
  artifact_versions:[{id:id(601),artifact_id:id(501),version_number:1,status:'CURRENT',previous_version_id:null,approved_at:'2026-11-06T00:00:00Z',content_snapshot:{private:'SECRET'}},{id:id(602),artifact_id:id(501),version_number:2,status:'REVISION_REQUESTED',previous_version_id:id(601),approved_at:null},{id:id(603),artifact_id:id(501),version_number:3,status:'DRAFT',previous_version_id:id(602),approved_at:null},{id:id(604),artifact_id:id(502),version_number:1,status:'DRAFT',previous_version_id:null,approved_at:null}],
  submissions:[{id:id(701),activity_instance_id:id(401),artifact_id:id(501),artifact_version_id:id(601),status:'APPROVED'},{id:id(702),activity_instance_id:id(401),artifact_id:id(501),artifact_version_id:id(602),status:'REVISION_REQUESTED',feedback:'SECRET'}],
  notifications:[{id:id(801),recipient_user_id:id(1),read_at:null,body:'SECRET'},{id:id(802),recipient_user_id:id(2),read_at:null,body:'OTHER SECRET'},{id:id(803),recipient_user_id:id(1),read_at:'2026-11-06'},{id:id(804),recipient_user_id:id(1),read_at:null,entity_id:id(32)}],
 };
 m.rpc.mockImplementation(async(name:string,args:Record<string,string>)=>{
  if(name==='get_team_workspace_access')return {data:roles.get(args.target_workspace)??null,error:null};
  if(name==='can_read_development_project')return {data:!denied.has(args.target_project),error:null};
  if(name==='get_my_current_work_catalog'){
   const c=tables.cohorts.find(c=>c.id===args.target_cohort)!,p=tables.programs.find(p=>p.id===c.program_id)!,cv=tables.curriculum_versions.find(v=>v.id===c.curriculum_version_id)!;
   if(!p||p.status!=='active'||!cv||cv.status!=='approved')return {data:null,error:null};
   const sessions=tables.session_definitions.filter(v=>v.curriculum_version_id===cv.id&&v.status==='active');
   const definitions=tables.activity_definitions.filter(d=>d.status==='active'&&sessions.some(v=>v.id===d.session_definition_id)).map(d=>{const i=tables.activity_instances.find(i=>i.activity_definition_id===d.id&&i.project_id===args.target_project&&i.status!=='completed'&&i.status!=='archived');return {...d,availability:i?{available:false,reasonCode:'ACTIVE_INSTANCE_EXISTS',existingActiveInstanceId:i.id}:{available:true}};});
   return {data:{course:p,cohort:c,curriculum:cv,sessions,definitions},error:null};
  }
  if(name==='resolve_activity_availability'){const instance=tables.activity_instances.find(i=>i.activity_definition_id===args.target_definition&&i.project_id===args.target_project&&i.status!=='archived'&&i.status!=='completed');return {data:instance?{available:false,reasonCode:'ACTIVE_INSTANCE_EXISTS',existingActiveInstanceId:instance.id}:{available:true},error:null};}
  throw Error('Unexpected RPC');
 });
});
const teamContext=(result:Awaited<ReturnType<typeof getMyCurrentWork>>)=>result.contexts.find(c=>c.team!==null)!;
it('returns every simultaneous own Personal/Team context and one user-global unread count',async()=>{const result=await getMyCurrentWork();expect(result.contexts).toHaveLength(2);expect(result.contexts.map(c=>c.project.id).sort()).toEqual([id(201),id(202)]);expect(result.unreadNotificationCount).toBe(2);expect(queries.filter(q=>q.table==='notifications')).toEqual([{table:'notifications',columns:'id',head:true}]);expect(JSON.stringify(result)).not.toContain('SECRET');});
it('one legitimate context remains when Personal Project is archived',async()=>{tables.development_projects[0].status='archived';tables.development_projects[0].archived_at='2026-11-06';expect((await getMyCurrentWork()).contexts).toHaveLength(1);});
it('all legitimate Activities remain candidates ordered only by configured Session/Activity sequence',async()=>{const context=teamContext(await getMyCurrentWork());expect(context.activities.map(a=>a.instanceId)).toEqual([id(403),id(401)]);expect(context).not.toHaveProperty('currentActivity');expect(context).not.toHaveProperty('selectedActivity');});
it('available unstarted Activity is a candidate without creating an instance or recommendation',async()=>{tables.activity_definitions.push({id:id(94),session_definition_id:id(82),name:'Available',workspace_mode:'Team Workspace',sequence:3,status:'active'});expect(teamContext(await getMyCurrentWork()).activities.find(a=>a.definition.id===id(94))).toMatchObject({instanceId:null,status:null,availability:{available:true},work:[]});expect(tables.activity_instances).toHaveLength(3);});
it('removed Team member loses context despite known IDs, Admin role, and historical notification',async()=>{roles.clear();const result=await getMyCurrentWork();expect(result.contexts.map(c=>c.project.id)).toEqual([id(201)]);expect(result.unreadNotificationCount).toBe(2);});
it('membership removal during aggregation is rechecked before returning fetched metadata',async()=>{const original=m.rpc.getMockImplementation()!;m.rpc.mockImplementation(async(name,args)=>{const result=await original(name,args);if(name==='get_my_current_work_catalog'&&args.target_project===id(202))roles.clear();return result;});expect((await getMyCurrentWork()).contexts.map(c=>c.project.id)).toEqual([id(201)]);});
it('A2 Personal and Team B content never enters results even with privileged role on same account',async()=>{const result=await getMyCurrentWork();expect(result.contexts.some(c=>c.workspace.id===id(12)||c.workspace.id===id(13))).toBe(false);expect(JSON.stringify(result)).not.toMatch(/A2|Team B|Unrelated|SECRET/);});
it('canonical revision target/status remains per exact Submission and Version, with no feedback body',async()=>{const work=teamContext(await getMyCurrentWork()).activities.find(a=>a.instanceId===id(401))!.work[0];expect(work.submissions.find(s=>s.id===id(702))).toEqual({id:id(702),artifactVersionId:id(602),versionNumber:2,previousVersionId:id(601),status:'REVISION_REQUESTED',revisionRequested:true});expect(work.drafts.map(v=>v.id)).toEqual([id(603)]);});
it('approved output follows exact current pointer, never newer Draft or revision-requested Version',async()=>{const work=teamContext(await getMyCurrentWork()).activities.find(a=>a.instanceId===id(401))!.work[0];expect(work.approvedOutput).toEqual({id:id(601),versionNumber:1,status:'CURRENT'});});
it('invalid non-approved current pointer never fabricates approved output',async()=>{tables.artifacts[0].current_version_id=id(603);expect(teamContext(await getMyCurrentWork()).activities.find(a=>a.instanceId===id(401))!.work[0].approvedOutput).toBeNull();});
it.each(['DRAFT','SUBMITTED','UNDER_REVIEW','REVISION_REQUESTED'])('M15.23 newer %s never replaces current approved Version',async status=>{
 tables.artifact_versions[2].status=status;
 expect(teamContext(await getMyCurrentWork()).activities.find(a=>a.instanceId===id(401))!.work[0].approvedOutput).toEqual({id:id(601),versionNumber:1,status:'CURRENT'});
});
it.each(['DRAFT','SUBMITTED','UNDER_REVIEW','REVISION_REQUESTED','SUPERSEDED'])('M15.23 pointer to %s is not approval, even with an approval timestamp',async status=>{
 tables.artifact_versions[0].status=status;
 expect(teamContext(await getMyCurrentWork()).activities.find(a=>a.instanceId===id(401))!.work[0].approvedOutput).toBeNull();
});
it('M15.23 missing timestamp, foreign Version, and missing pointer all fail closed',async()=>{
 for(const mutate of [()=>{tables.artifact_versions[0].approved_at=null;},()=>{tables.artifact_versions[0].artifact_id=id(502);},()=>{tables.artifacts[0].current_version_id=null;}]){
  mutate();expect(teamContext(await getMyCurrentWork()).activities.find(a=>a.instanceId===id(401))!.work[0].approvedOutput).toBeNull();
 }
});
it('M15.23 AI Candidate, Team decision, completed state, and approval notification cannot imply approved output',async()=>{
 tables.artifacts[0].current_version_id=null;
 tables.ai_outputs=[{id:id(900),status:'APPROVED',ai_generated:true}];
 tables.development_objects=[{id:id(901),object_type:'IDEA',status:'CANDIDATE'}];
 tables.decisions=[{id:id(902),status:'APPROVED'}];
 tables.notifications.push({id:id(903),recipient_user_id:id(1),read_at:null,type:'ARTIFACT_APPROVED',entity_id:id(501)});
 const work=teamContext(await getMyCurrentWork()).activities.find(a=>a.instanceId===id(401))!.work[0];expect(work.approvedOutput).toBeNull();
 tables.activity_instances[0].status='completed';
 expect(teamContext(await getMyCurrentWork()).activities.some(a=>a.instanceId===id(401))).toBe(false);
 expect(queries.some(q=>['ai_outputs','development_objects','decisions'].includes(q.table))).toBe(false);
});
it('current Mind Map Draft excludes frozen earlier DRAFT checkpoints according to lineage',async()=>{tables.artifacts[0].artifact_type='MIND_MAP';tables.artifact_versions[0].status='DRAFT';tables.artifact_versions[1].status='DRAFT';expect(teamContext(await getMyCurrentWork()).activities.find(a=>a.instanceId===id(401))!.work[0].drafts.map(v=>v.id)).toEqual([id(603)]);});
it('unrelated artifact/Share/input alone is never own Activity work',async()=>{tables.shares=[{id:id(999),shared_entity_id:id(503)}];const result=await getMyCurrentWork();expect(JSON.stringify(result)).not.toContain(id(503));expect(queries.some(q=>['shares','share_snapshots','activity_inputs','evidence','ai_outputs','chat_messages'].includes(q.table))).toBe(false);});
it('registered canonical Artifact output is included without cloning it',async()=>{tables.activity_outputs.push({activity_instance_id:id(401),artifact_id:id(503),output_type:'artifact'});tables.artifacts[2].title='Registered output';expect(teamContext(await getMyCurrentWork()).activities.find(a=>a.instanceId===id(401))!.work.map(a=>a.id)).toContain(id(503));});
it('cross-scope output link cannot broaden artifact authorization',async()=>{tables.activity_outputs.push({activity_instance_id:id(401),artifact_id:id(900),output_type:'artifact'});tables.artifacts.push({...tables.artifacts[2],id:id(900),project_id:id(204),workspace_id:id(13),title:'FOREIGN'});expect(JSON.stringify(await getMyCurrentWork())).not.toContain('FOREIGN');});
it.each(['paused','completed','archived'])('non-active Project %s does not appear as active work',async status=>{tables.development_projects[1].status=status;expect((await getMyCurrentWork()).contexts.some(c=>c.project.id===id(202))).toBe(false);});
it('completed Activity with approved output is explicit; archived Activity is absent',async()=>{tables.activity_instances[0].status='completed';tables.activity_instances[2].status='archived';const context=teamContext(await getMyCurrentWork());expect(context.activities.find(a=>a.instanceId===id(401))?.status).toBe('completed');expect(context.activities.some(a=>a.instanceId===id(403))).toBe(false);});
it('completed Activity without approved output does not become stale active work',async()=>{tables.activity_instances[1].status='completed';expect((await getMyCurrentWork()).contexts.find(c=>c.project.id===id(201))!.activities.some(a=>a.instanceId===id(402))).toBe(false);});
it.each(['completed','archived'])('non-active Cohort %s is excluded',async status=>{tables.cohorts[0].status=status;expect((await getMyCurrentWork()).contexts).toEqual([]);});
it('no Team/project/submission/approved output are represented safely',async()=>{tables.workspaces=[];expect(await getMyCurrentWork()).toEqual({contexts:[],unreadNotificationCount:2});});
it('role-only Admin/Master/instructor enrollment is not Student participation',async()=>{tables.enrollments[0].enrollment_role='instructor';expect((await getMyCurrentWork()).contexts).toEqual([]);});
it('Project permission loss removes only that context',async()=>{denied.add(id(202));expect((await getMyCurrentWork()).contexts.map(c=>c.project.id)).toEqual([id(201)]);});
it.each([{userId:id(2)},{projectId:id(204)},{workspaceId:id(12)},{activityId:id(401)},{role:'ADMIN'}])('client scope/identity override rejected before I/O %j',async input=>{await expect(getMyCurrentWork(input)).rejects.toMatchObject({code:'VALIDATION_ERROR'});expect(m.actor).not.toHaveBeenCalled();});
it('changed authenticated identity fails closed',async()=>{m.actor.mockResolvedValueOnce({userId:id(1),assignments:[]}).mockResolvedValue({userId:id(2),assignments:[]});await expect(getMyCurrentWork()).rejects.toMatchObject({code:'NOT_FOUND'});});
it('enumerates all contexts beyond one PostgREST page without selecting an arbitrary winner',async()=>{tables.development_projects=[];tables.project_program_links=[];for(let n=0;n<205;n++){tables.development_projects.push({id:id(1000+n),name:'Context '+n,project_type:'individual',owner_user_id:id(1),owner_team_id:null,primary_workspace_id:id(10),status:'active',archived_at:null});tables.project_program_links.push({id:id(2000+n),project_id:id(1000+n),program_id:id(61),cohort_id:id(51),completed_at:null});}expect((await getMyCurrentWork()).contexts).toHaveLength(205);});
it('aggregation is read-only, server-only, and has no privileged client or persisted progress state',async()=>{const before=JSON.stringify(tables);await getMyCurrentWork();expect(JSON.stringify(tables)).toBe(before);const source=readFileSync('features/progress/current-work.ts','utf8');expect(source).toContain("import 'server-only'");expect(source).not.toMatch(/service_role|SUPABASE_SECRET|createClient\(|\.insert\(|\.update\(|\.delete\(|\.upsert\(|selected_context|priority_score/);});
import {AuthorizationError} from '@/lib/auth/authorization';
it('unauthenticated access fails before scope or notification queries',async()=>{m.actor.mockRejectedValue(new AuthorizationError('AUTH_REQUIRED'));await expect(getMyCurrentWork()).rejects.toMatchObject({code:'AUTH_REQUIRED'});expect(queries).toEqual([]);});
it('contextual Mentor access does not become Student-owned Team work',async()=>{roles.set(id(11),'mentor');expect((await getMyCurrentWork()).contexts.map(c=>c.project.id)).toEqual([id(201)]);});
it('scope-incompatible catalog response fails closed without metadata fallback',async()=>{const original=m.rpc.getMockImplementation()!;m.rpc.mockImplementation(async(name,args)=>{const result=await original(name,args);if(name==='get_my_current_work_catalog'&&result.data)result.data={...result.data,course:{id:id(999),name:'FOREIGN COURSE',status:'active'}};return result;});await expect(getMyCurrentWork()).rejects.toMatchObject({code:'NOT_FOUND'});});

