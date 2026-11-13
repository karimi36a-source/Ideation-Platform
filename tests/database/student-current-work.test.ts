import {spawnSync} from 'node:child_process';
import {readFileSync} from 'node:fs';
import {join} from 'node:path';
import {beforeAll,beforeEach,expect,it,vi} from 'vitest';
vi.mock('server-only',()=>({}));
vi.mock('next/server',()=>({after:vi.fn()}));
const actor=vi.hoisted(()=>({id:'00000000-0000-4000-8000-000000006004'}));
vi.mock('@/lib/auth/authorization',async original=>({...await original<typeof import('@/lib/auth/authorization')>(),getAuthorizationContext:async()=>({userId:actor.id,assignments:[]})}));
vi.mock('@/lib/db/server',()=>({createServerSupabaseClient:async()=>({from:table,rpc:transport})}));
import {getMyCurrentWork} from '@/features/progress/current-work';
import {getMasterCohortOverview} from '@/features/progress/master-cohort-overview';
import {getMyLearningProgress} from '@/features/progress/learning-progress';
import {getPendingReviewQueue} from '@/features/progress/pending-review';
import {getMyRevisionStatus,getMasterRevisionStatus} from '@/features/progress/revision-status';
import {listMyNotifications} from '@/features/notifications/list';
import {markNotificationRead} from '@/features/notifications/read';
import {createNotificationRealtimeController} from '@/features/notifications/realtime-controller';
import type {NotificationRealtimeItem} from '@/features/notifications/realtime-schema';
import {createNotificationEmailDelivery} from '@/features/notifications/email-delivery';
import {pilotEmailDefaults} from '@/features/notifications/email-policy-config';
import {notificationEmailTemplate} from '@/features/notifications/email-template';
import {ResendEmailProvider} from '@/features/email/providers/resend';
const id=(n:number)=>'00000000-0000-4000-8000-'+String(n).padStart(12,'0');
const lit=(v:unknown)=>v===null?'null':typeof v==='number'?String(v):"'"+String(v).replaceAll("'","''")+"'";
function sql(query:string){
 const port=process.env.FICI_CURRENT_WORK_TEST_PORT;if(!port||!/^\d+$/.test(port)||!process.env.POSTGRES_BIN)throw Error('Disposable database required');
 const result=spawnSync(join(process.env.POSTGRES_BIN,process.platform==='win32'?'psql.exe':'psql'),['-X','-h','127.0.0.1','-p',port,'-U','postgres','-d','fici_current_work','-v','ON_ERROR_STOP=1','-qAt','-c',query],{encoding:'utf8',windowsHide:true,timeout:45000});
 if(result.error||result.status!==0)throw Error('Disposable SQL denied');return result.stdout.trim();
}
function current(query:string){const output=sql(`begin;set local role authenticated;select set_config('request.jwt.claim.sub',${lit(actor.id)},true);select 'RESULT='||coalesce(to_jsonb((${query}))::text,'null');commit;`);const value=output.split(/\r?\n/).find(v=>v.startsWith('RESULT='));if(!value)throw Error('Missing result');return JSON.parse(value.slice(7));}
function root(query:string){return JSON.parse(sql('select ('+query+')::text;'));}
function fixture(label:string){return root(`(select payload from public.current_work_fixture where label=${lit(label)})`);}
const allowedTables=['enrollments','workspaces','teams','development_projects','project_program_links','cohorts','programs','curriculum_versions','session_definitions','activity_definitions','activity_instances','activity_outputs','submissions','artifacts','artifact_versions','notifications'];
function table(name:string){
 if(!allowedTables.includes(name))throw Error('Unexpected table');let columns='',head=false;const filters:string[]=[],order:string[]=[];
 const key=(k:string)=>{if(!/^[a-z_]+$/.test(k))throw Error('Unsafe column');return k;};
 const execute=async(start=0,end=199)=>{const suffix=filters.length?' where '+filters.join(' and '):'';return head?{data:null,error:null,count:current(`(select count(*) from public.${name}${suffix})`)}:{data:current(`(select coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb) from (select ${columns} from public.${name}${suffix}${order.length?' order by '+order.join(','):''} limit ${end-start+1} offset ${start}) x)`),error:null};};
 const q={select:(v:string,options?:{head?:boolean})=>{if(!/^[a-z_,]+$/.test(v))throw Error('Unsafe projection');columns=v;head=options?.head??false;return q;},eq:(k:string,v:unknown)=>{filters.push(key(k)+'='+lit(v));return q;},neq:(k:string,v:unknown)=>{filters.push(key(k)+'<>'+lit(v));return q;},is:(k:string,v:unknown)=>{if(v!==null)throw Error('Unexpected null filter');filters.push(key(k)+' is null');return q;},in:(k:string,values:unknown[])=>{filters.push(key(k)+' in ('+values.map(lit).join(',')+')');return q;},order:(k:string,options?:{ascending?:boolean})=>{order.push(key(k)+(options?.ascending===false?' desc':' asc'));return q;},range:execute,limit:(n:number)=>execute(0,n-1),then:(resolve:unknown,reject:unknown)=>execute().then(resolve as never,reject as never)};return q;
}
async function transport(name:string,args:Record<string,unknown>){
 if(!['can_read_development_project','get_team_workspace_access','resolve_activity_availability','get_my_current_work_catalog','get_revision_status','get_master_cohort_overview','get_my_learning_progress','get_pending_review_queue','mark_notification_read'].includes(name))throw Error('Unexpected RPC');
 try{return {data:current('public.'+name+'('+Object.entries(args).map(([k,v])=>k+'=>'+lit(v)).join(',')+')'),error:null};}catch{return {data:null,error:{code:'42501'}};}
}
beforeAll(()=>{
 const t=fixture('Team B');sql(`update public.teams set status='active' where id=${lit(t.teamId)};`);
 actor.id=id(6001);const p=current(`public.create_development_project('TEAM B PRIVATE PROJECT','team',${lit(t.workspaceId)},null,null,${lit(t.teamId)})`);
 sql(`insert into public.project_memberships(project_id,user_id) values(${lit(p.id)},'${id(6006)}');insert into public.project_program_links(project_id,program_id,cohort_id) select ${lit(p.id)},program_id,id from public.cohorts where id=(select cohort_id from public.teams where id=${lit(t.teamId)});`);
 const iid=sql(`insert into public.activity_instances(activity_definition_id,cohort_id,project_id,workspace_id,team_id,started_by,started_at,status,configuration_snapshot) select '00000000-0000-4000-8000-000000098001',cohort_id,${lit(p.id)},${lit(t.workspaceId)},${lit(t.teamId)},'${id(6006)}',clock_timestamp(),'active','{}' from public.teams where id=${lit(t.teamId)} returning id;`);
 actor.id=id(6006);const a=current(`public.create_artifact(${lit(p.id)},${lit(t.workspaceId)},'DEVELOPED_CONCEPT','TEAM B PRIVATE ARTIFACT',${lit(iid)},false,false)`);
 sql(`insert into public.current_work_fixture values('B Project',${lit(JSON.stringify(p))}::jsonb),('B Artifact',${lit(JSON.stringify(a))}::jsonb);`);
});
beforeEach(()=>{actor.id=id(6004);});
/** M15.23 compares real service projections under each caller's authenticated RLS.
 * Expected identity is supplied by the canonical lifecycle, never max(version).
 */
async function expectApproved(versionId:string){
 const artifactId=fixture('Artifact Team').artifactId;
 const student=await getMyCurrentWork();
 const approved=student.contexts.flatMap(c=>c.activities.flatMap(a=>a.work)).find(a=>a.id===artifactId)!.approvedOutput;
 expect(approved).toMatchObject({id:versionId,status:'CURRENT'});
 const saved=actor.id;actor.id=id(6002);
 try{
  const cid=sql(`select cohort_id from public.teams where id=${lit(fixture('Team A').teamId)};`);
  const master=await getMasterCohortOverview(cid);
  const outputs=master.teams.flatMap(t=>t.projects.flatMap(p=>p.approvedOutputs)).filter(a=>a.artifactId===artifactId);
  expect(outputs).toEqual([{artifactId,artifactType:'PROBLEM_BANK',versionId,versionNumber:approved!.versionNumber,status:'CURRENT'}]);
  // Scoped Master may see safe metadata for both Teams in this Cohort, but
  // receives neither private Artifact bodies nor another user's Personal work.
  expect(JSON.stringify(master)).not.toMatch(/DO_NOT_RETURN|content_snapshot|A2 PRIVATE|TEAM B PRIVATE ARTIFACT/);
 }finally{actor.id=saved;}
}
it('authenticated Student receives own simultaneous Personal/Team contexts, all active candidates, exact revision/approval and one unread count',async()=>{
 const before=root(`jsonb_build_object('artifacts',(select md5(jsonb_agg(to_jsonb(a) order by id)::text) from public.artifacts a),'versions',(select md5(jsonb_agg(to_jsonb(a) order by id)::text) from public.artifact_versions a),'notifications',(select md5(jsonb_agg(to_jsonb(a) order by id)::text) from public.notifications a))`);
 const result=await getMyCurrentWork();expect(result.contexts).toHaveLength(2);const ownTeam=result.contexts.find(c=>c.team!==null)!;expect(ownTeam.project.id).toBe(fixture('Project Team').id);expect(ownTeam.activities.filter(a=>a.instanceId!==null)).toHaveLength(2);
 const work=ownTeam.activities.flatMap(a=>a.work).find(a=>a.id===fixture('Artifact Team').artifactId)!;
 expect(work.approvedOutput?.id).toBe(fixture('Artifact Team').initialVersionId);expect(work.drafts.map(v=>v.id)).toContain(fixture('V3').id);expect(work.submissions.find(v=>v.id===fixture('Revision').id)).toMatchObject({status:'REVISION_REQUESTED',revisionRequested:true,artifactVersionId:fixture('V2').id});
 expect(result.unreadNotificationCount).toBe(root(`(select count(*) from public.notifications where recipient_user_id=${lit(actor.id)} and read_at is null)`));expect(JSON.stringify(result)).not.toMatch(/A2 PRIVATE|TEAM B PRIVATE|DO_NOT_RETURN|Private sibling|configuration_snapshot|feedback|content_snapshot/);
 expect(root(`jsonb_build_object('artifacts',(select md5(jsonb_agg(to_jsonb(a) order by id)::text) from public.artifacts a),'versions',(select md5(jsonb_agg(to_jsonb(a) order by id)::text) from public.artifact_versions a),'notifications',(select md5(jsonb_agg(to_jsonb(a) order by id)::text) from public.notifications a))`)).toEqual(before);
});
it('explicit Share remains resolvable but never becomes owned current work or exposes A2 Personal metadata',async()=>{const share=fixture('Share');const access=current(`public.resolve_shared_entity_access(jsonb_build_object('shareId',${lit(share.id)}))`);expect(access.allowed).toBe(true);const result=await getMyCurrentWork();expect(result.contexts.some(c=>c.project.id===fixture('A2 Project').id)).toBe(false);expect(result.contexts.flatMap(c=>c.activities.flatMap(a=>a.work)).some(a=>a.id===fixture('A2 Artifact').artifactId)).toBe(false);});
it.each([6001,6002])('role-only/unrelated Student %i cannot inherit A1 private contexts',async n=>{actor.id=id(n);expect((await getMyCurrentWork()).contexts).toEqual([]);});
it('Team B Student sees exactly own active context, never Team A or A1 Personal work',async()=>{actor.id=id(6006);const result=await getMyCurrentWork();expect(result.contexts).toHaveLength(1);expect(result.contexts[0].project.id).toBe(fixture('B Project').id);expect(JSON.stringify(result)).not.toContain(fixture('Project Team').id);expect(result.contexts[0].activities.flatMap(a=>a.work).map(a=>a.id)).toContain(fixture('B Artifact').artifactId);});
it('canonical M7 availability for ordinary member is not broadened into Team launch authority',async()=>{const result=await getMyCurrentWork();for(const candidate of result.contexts.find(c=>c.team!==null)!.activities)expect(candidate.availability.available).toBe(false);});
it('direct identity/scope inputs cannot enumerate known private contexts',async()=>{for(const input of [{userId:id(6005)},{projectId:fixture('A2 Project').id},{teamId:fixture('Team B').teamId}])await expect(getMyCurrentWork(input)).rejects.toMatchObject({code:'VALIDATION_ERROR'});});
it('narrow catalog denies direct foreign IDs/role-only access and hides dependency-locked future metadata',()=>{
 const args=(p:Record<string,string>,teamId:string|null)=>`target_project=>${lit(p.id)},target_workspace=>${lit(p.primary_workspace_id)},target_cohort=>(select cohort_id from public.teams where id=${lit(fixture('Team A').teamId)}),target_team=>${lit(teamId)}`;
 expect(current(`public.get_my_current_work_catalog(${args(fixture('A2 Project'),null)})`)).toBeNull();
 expect(current(`public.get_my_current_work_catalog(${args(fixture('B Project'),fixture('Team B').teamId)})`)).toBeNull();
 actor.id=id(6002);expect(current(`public.get_my_current_work_catalog(${args(fixture('Project Team'),fixture('Team A').teamId)})`)).toBeNull();
 actor.id=id(6005);const catalog=current(`public.get_my_current_work_catalog(${args(fixture('Project Team'),fixture('Team A').teamId)})`);
 expect(JSON.stringify(catalog)).not.toContain('LOCKED_FUTURE_PRIVATE_TITLE');expect(catalog.definitions.some((d:{id:string;availability:{available:boolean}})=>d.id===id(98004)&&d.availability.available)).toBe(true);
 expect(root(`has_function_privilege('anon','public.get_my_current_work_catalog(uuid,uuid,uuid,uuid)','execute')`)).toBe(false);
 expect(root(`has_function_privilege('service_role','public.get_my_current_work_catalog(uuid,uuid,uuid,uuid)','execute')`)).toBe(false);
});
it('M15.24 real service returns separate exact Personal/Team learning counts including locked future work, no hidden labels',async()=>{
 const result=await getMyLearningProgress();expect(result.contexts).toHaveLength(2);
 const team=result.contexts.find(c=>c.team!==null)!,personal=result.contexts.find(c=>c.team===null)!;
 expect(team.progress).toMatchObject({requiredActivitiesTotal:4,completedRequiredActivities:0,inProgressActivities:2,blockedActivities:1,notStartedActivities:1,completionPercentage:0});
 expect(personal.progress).toMatchObject({requiredActivitiesTotal:1,completedRequiredActivities:0,inProgressActivities:1,completionPercentage:0});
 expect(JSON.stringify(result)).not.toMatch(/LOCKED_FUTURE_PRIVATE_TITLE|A2 PRIVATE|TEAM B PRIVATE|content_snapshot|DO_NOT_RETURN/);
});
it('M15.25 all Master service projections deny known valid source identifiers used as Cohort scope',async()=>{
 actor.id=id(6002);
 const known=[fixture('A2 Artifact').artifactId,fixture('Revision').id,fixture('V3').id,fixture('Share').id];
 for(const value of known)for(const surface of [getMasterCohortOverview,getPendingReviewQueue,getMasterRevisionStatus])await expect(surface(value)).rejects.toMatchObject({code:'FORBIDDEN'});
});
it('M15.25 Team B service results omit Team A current work, revision and learning context',async()=>{
 actor.id=id(6006);
 const progress=await getMyLearningProgress();expect(progress.contexts).toHaveLength(1);expect(progress.contexts[0].project.id).toBe(fixture('B Project').id);
 expect(await getMyRevisionStatus()).toEqual({outstanding:[],history:[]});
 expect(JSON.stringify(progress)).not.toContain(fixture('Project Team').id);expect(JSON.stringify(progress)).not.toContain(fixture('A2 Project').id);
});
it('canonical resubmission closes historical revision callout without rewriting history',async()=>{
 actor.id=id(6005);const s=current(`public.submit_artifact(${lit(fixture('Artifact Team').artifactId)},${lit(fixture('V3').id)},${lit(fixture('Instance Team').id)})`);
 actor.id=id(6004);const result=await getMyCurrentWork();const rows=result.contexts.flatMap(c=>c.activities.flatMap(a=>a.work.flatMap(w=>w.submissions)));
 expect(rows.find(r=>r.id===fixture('Revision').id)).toMatchObject({status:'REVISION_REQUESTED',revisionRequested:false});
 expect(rows.find(r=>r.id===s.id)).toMatchObject({status:'SUBMITTED',revisionRequested:false});
});

it('M15.23 V3 submitted and under review cannot replace approved V1 in either service',async()=>{
 await expectApproved(fixture('Artifact Team').initialVersionId);
 actor.id=id(6002);
 const sid=sql(`select id from public.submissions where artifact_version_id=${lit(fixture('V3').id)};`);
 current(`public.start_review(${lit(sid)})`);
 actor.id=id(6004);await expectApproved(fixture('Artifact Team').initialVersionId);
});
it('M15.23 human approval moves both views to exact V3 and retains historical V1',async()=>{
 const old=fixture('Artifact Team').initialVersionId;
 const before=root(`(select to_jsonb(v) from public.artifact_versions v where id=${lit(old)})`);
 actor.id=id(6002);
 const sid=sql(`select id from public.submissions where artifact_version_id=${lit(fixture('V3').id)};`);
 current(`public.approve_artifact(${lit(sid)},null)`);
 actor.id=id(6004);await expectApproved(fixture('V3').id);
 const after=root(`(select to_jsonb(v) from public.artifact_versions v where id=${lit(old)})`);
 expect(after.status).toBe('SUPERSEDED');expect(after.content_snapshot).toEqual(before.content_snapshot);
 expect(after.approved_at).toBe(before.approved_at);expect(after.approved_by).toBe(before.approved_by);
});
it('M15.23 newer V4 Draft and revision cycle preserve V3 current output without exposing private content',async()=>{
 actor.id=id(6005);
 const v=current(`public.create_artifact_version(${lit(fixture('Artifact Team').artifactId)},'{"private":"DO_NOT_RETURN"}','New Draft')`);
 actor.id=id(6004);await expectApproved(fixture('V3').id);
 actor.id=id(6005);
 const s=current(`public.submit_artifact(${lit(fixture('Artifact Team').artifactId)},${lit(v.id)},${lit(fixture('Instance Team').id)})`);
 actor.id=id(6002);current(`public.start_review(${lit(s.id)})`);current(`public.request_revision(${lit(s.id)},'DO_NOT_RETURN_PRIVATE_FEEDBACK')`);
 actor.id=id(6004);await expectApproved(fixture('V3').id);
});
it('M15.23 no prior approval is explicit null; completed Activity or AI/Decision identities cannot fabricate approval',async()=>{
 const result=await getMyCurrentWork();
 const personal=result.contexts.find(c=>c.workspace.type==='PERSONAL')!;
 expect(personal.activities.flatMap(a=>a.work)).not.toHaveLength(0);
 for(const work of personal.activities.flatMap(a=>a.work))expect(work.approvedOutput).toBeNull();
 // Only canonical Artifact/Version metadata is queried: no AI/Decision discovery surface.
 expect(allowedTables).not.toContain('ai_outputs');expect(allowedTables).not.toContain('development_objects');
});

it('completed Activity retains exact approved output clearly marked completed',async()=>{const instanceId=fixture('Instance Team').id;sql(`update public.activity_instances set status='completed',completed_at=clock_timestamp() where id=${lit(instanceId)};`);const result=await getMyCurrentWork();const candidate=result.contexts.find(c=>c.team!==null)!.activities.find(a=>a.instanceId===instanceId)!;expect(candidate.status).toBe('completed');expect(candidate.work.some(a=>a.approvedOutput?.id===fixture('V3').id)).toBe(true);});
it('removed Team member loses Team context despite historical notifications and still sees own Personal context',async()=>{const teamId=fixture('Team A').teamId;sql(`begin;set local role authenticated;select set_config('request.jwt.claim.sub','${id(6002)}',true);select public.remove_team_member(${lit(teamId)},'${id(6004)}',null);commit;`);expect(root(`(select count(*) from public.notifications where recipient_user_id='${id(6004)}')`)).toBeGreaterThan(0);const result=await getMyCurrentWork();expect(result.contexts).toHaveLength(1);expect(result.contexts[0].workspace.type).toBe('PERSONAL');});
it('M15.24 removed membership removes Team progress from real service',async()=>{const result=await getMyLearningProgress();expect(result.contexts).toHaveLength(1);expect(result.contexts[0].workspace.type).toBe('PERSONAL');});
it('archived Project is omitted safely without rewriting workflow/history',async()=>{const project=fixture('Project Individual').id;sql(`update public.development_projects set status='archived',archived_at=clock_timestamp() where id=${lit(project)};`);expect((await getMyCurrentWork()).contexts).toEqual([]);});

// Selected alone by --pilot-student on a fresh copy of the same fixture. The
// normal regression file keeps its original lifecycle and mutation order.
if(process.env.FICI_PILOT_STUDENT==='1')it('M15.30 integrated Student pilot: self scopes, tools, Chat, selected Share, revision/approval, progress and membership history',async()=>{
 const student=id(6005),other=id(6004),master=id(6002),teamA=fixture('Team A'),teamB=fixture('Team B');
 const personal=fixture('A2 Project'),foreignPersonal=fixture('Project Individual'),project=fixture('Project Team');
 const artifact=fixture('Artifact Team').artifactId,instance=fixture('Instance Team').id,v3=fixture('V3').id;
 const cohort=sql(`select cohort_id from public.teams where id=${lit(teamA.teamId)}`);
 const foreignCohort=sql(`select id from public.cohorts where primary_master_id='${id(6003)}'`);
 const dispatcher=readFileSync(new URL('../integration/pilot-master-acceptance.sql',import.meta.url),'utf8').match(/create function pg_temp\.pm_notify\b[\s\S]+?\nend\$\$;/)?.[0];
 if(!dispatcher)throw Error('Accepted M15.29 notification helper required');
 // Actual post-commit dispatch through the accepted service-only selectors and
 // notification RPC. No mocked recipients or direct notification inserts.
 function deliver(kind:string,sid:string){sql(`begin;${dispatcher}set local role service_role;select pg_temp.pm_notify(${lit(kind)},${lit(sid)});select pg_temp.pm_notify(${lit(kind)},${lit(sid)});commit;`);}
 function privateBoundaries(){
  const saved=actor.id;actor.id=student;
  expect(current(`(select jsonb_build_object('personal',(select count(*) from public.workspaces where id=${lit(foreignPersonal.primary_workspace_id)}),'artifact',(select count(*) from public.artifacts where id=${lit(fixture('Artifact Personal').artifactId)}),'bArtifact',(select count(*) from public.artifacts where id=${lit(fixture('B Artifact').artifactId)}),'bWorkspace',(select count(*) from public.workspaces where id=${lit(teamB.workspaceId)}),'bChat',(select count(*) from public.chat_messages where chat_channel_id=${lit(teamB.chatChannelId)}),'foreignCohort',(select count(*) from public.cohorts where id=${lit(foreignCohort)})))`)).toEqual({personal:0,artifact:0,bArtifact:0,bWorkspace:0,bChat:0,foreignCohort:0});
  expect(current(`public.get_my_learning_progress(${lit(foreignPersonal.id)},${lit(foreignPersonal.primary_workspace_id)},${lit(cohort)},null)`)).toBeNull();
  actor.id=saved;
 }
 actor.id=student;
 const initial=await getMyCurrentWork();expect(initial.contexts).toHaveLength(2);
 expect(initial.contexts.every(c=>c.cohort.id===cohort&&c.course.id==='00000000-0000-4000-8000-000000000601')).toBe(true);
 expect(initial.contexts.map(c=>c.project.id).sort()).toEqual([personal.id,project.id].sort());privateBoundaries();
 await expect(getMyCurrentWork({userId:other})).rejects.toMatchObject({code:'VALIDATION_ERROR'});
 await expect(getMyLearningProgress({userId:other})).rejects.toMatchObject({code:'VALIDATION_ERROR'});
 expect(current(`public.resume_activity(${lit(instance)})`)).toMatchObject({activity:{id:instance,status:'active'}});
 // Core tool writes use existing Development Object and Activity I/O commands.
 const selected=current(`public.create_development_object(${lit(personal.id)},${lit(personal.primary_workspace_id)},'IDEA','Pilot selected','M1530_SELECTED','User')`);
 const sibling=current(`public.create_development_object(${lit(personal.id)},${lit(personal.primary_workspace_id)},'IDEA','Pilot unselected','M1530_UNSELECTED','User')`);
 const object=current(`public.create_development_object(${lit(project.id)},${lit(project.primary_workspace_id)},'PROBLEM','Pilot Team problem','Student-authored problem','User')`);
 current(`public.write_problem_details(${lit(object.id)},'{}',true)`);
 current(`public.add_activity_input(${lit(instance)},${lit(object.id)},true)`);
 current(`public.add_activity_output(${lit(instance)},${lit(object.id)})`);
 const chat=current(`public.send_team_chat_message(${lit(teamA.teamId)},'M1530 private Team A message')`);
 expect(chat.sender_user_id).toBe(student);expect(current(`(select count(*) from public.chat_messages where id=${lit(chat.id)})`)).toBe(1);privateBoundaries();
 // Selected-only Personal -> Team Share: receiver gets frozen content, no source ACL.
 const share=current(`public.share_entity(${lit(JSON.stringify({entityType:'DEVELOPMENT_OBJECT',entityId:selected.id,destinationType:'TEAM',destinationId:teamA.teamId,permissionLevel:'VIEW',shareMode:'SNAPSHOT'}))}::jsonb)`);
 actor.id=other;
 const shared=current(`public.resolve_shared_entity_access(jsonb_build_object('shareId',${lit(share.id)}))`);
 expect(shared).toMatchObject({allowed:true,canEdit:false,canReshare:false,sharedEntityId:selected.id});
 expect(JSON.stringify(shared)).not.toContain(sibling.id);expect(JSON.stringify(shared)).not.toContain('M1530_UNSELECTED');
 expect(current(`(select count(*) from public.workspaces where id=${lit(personal.primary_workspace_id)})`)).toBe(0);
 expect(current(`(select count(*) from public.development_objects where id in(${lit(selected.id)},${lit(sibling.id)}))`)).toBe(0);
 actor.id=student;current(`public.revoke_share(jsonb_build_object('shareId',${lit(share.id)}))`);
 actor.id=other;expect(current(`public.resolve_shared_entity_access(jsonb_build_object('shareId',${lit(share.id)}))`)).toMatchObject({allowed:false});
 actor.id=student;expect(current(`(select count(*) from public.development_objects where id in(${lit(selected.id)},${lit(sibling.id)}))`)).toBe(2);privateBoundaries();
 // Student submits exact revision Draft V3; Master comment/revision stays bound to it.
 const s1=current(`public.submit_artifact(${lit(artifact)},${lit(v3)},${lit(instance)})`);deliver('SUBMISSION_RECEIVED',s1.id);
 expect(s1).toMatchObject({artifact_version_id:v3,submitted_by:student,reviewer_user_id:master});
 actor.id=master;current(`public.start_review(${lit(s1.id)})`);
 const feedback=current(`public.add_feedback('ARTIFACT',${lit(artifact)},${lit(v3)},'COMMENT','M1530 exact V3 feedback')`);
 current(`public.request_revision(${lit(s1.id)},'M1530 revise the exact submitted work')`);deliver('REVISION_REQUESTED',s1.id);
 actor.id=student;expect(current(`(select content from public.feedback_items where id=${lit(feedback.id)})`)).toBe('M1530 exact V3 feedback');
 actor.id=id(6006);expect(current(`(select count(*) from public.feedback_items where submission_id=${lit(s1.id)})`)).toBe(0);actor.id=student;
 const revision=await getMyRevisionStatus();expect(revision.outstanding.some(s=>s.submissionId===s1.id&&s.version.id===v3)).toBe(true);
 const requested=await getMyCurrentWork(),requestedWork=requested.contexts.flatMap(c=>c.activities.flatMap(a=>a.work)).find(w=>w.id===artifact)!;
 expect(requestedWork.submissions.find(s=>s.id===s1.id)).toMatchObject({revisionRequested:true,status:'REVISION_REQUESTED',artifactVersionId:v3});privateBoundaries();
 // Canonical successor submission; later unapproved V5 can never replace V4.
 const v4=current(`public.create_revision_draft(${lit(s1.id)},'{"private":"M1530_REVISED_V4"}','Pilot Student revision')`);
 const s2=current(`public.submit_artifact(${lit(artifact)},${lit(v4.id)},${lit(instance)})`);deliver('SUBMISSION_RECEIVED',s2.id);
 const v5=current(`public.create_artifact_version(${lit(artifact)},'{"private":"M1530_UNAPPROVED_V5"}','Later unapproved draft')`);
 expect(v4.previous_version_id).toBe(v3);expect(s2.artifact_version_id).toBe(v4.id);
 const resubmitted=await getMyRevisionStatus();expect(resubmitted.outstanding.some(s=>s.submissionId===s1.id)).toBe(false);expect(resubmitted.history.some(s=>s.submissionId===s1.id&&s.successors.some(next=>next.submissionId===s2.id&&next.versionId===v4.id))).toBe(true);
 actor.id=master;current(`public.start_review(${lit(s2.id)})`);current(`public.approve_artifact(${lit(s2.id)},'Pilot Student exact V4 approval')`);deliver('ARTIFACT_APPROVED',s2.id);actor.id=student;
 const approved=await getMyCurrentWork(),approvedWork=approved.contexts.flatMap(c=>c.activities.flatMap(a=>a.work)).find(w=>w.id===artifact)!;
 expect(approvedWork.approvedOutput).toMatchObject({id:v4.id,status:'CURRENT'});expect(approvedWork.drafts.map(v=>v.id)).toContain(v5.id);
 expect(approvedWork.submissions.find(s=>s.id===s1.id)).toMatchObject({status:'REVISION_REQUESTED',revisionRequested:false});
 expect(approvedWork.submissions.find(s=>s.id===s2.id)).toMatchObject({status:'APPROVED',artifactVersionId:v4.id});
 expect(approved.unreadNotificationCount).toBe(root(`(select count(*) from public.notifications where recipient_user_id=${lit(student)} and read_at is null)`));
 const notices=current(`(select jsonb_agg(jsonb_build_object('kind',notification_type,'source',entity_id)) from public.notifications where entity_id in(${lit(s1.id)},${lit(s2.id)}))`);
 expect(notices).toHaveLength(2);expect(notices).toEqual(expect.arrayContaining([{kind:'REVISION_REQUESTED',source:s1.id},{kind:'ARTIFACT_APPROVED',source:s2.id}]));
 expect(root(`(select count(*) from public.notifications where recipient_user_id=${lit(master)} and notification_type='SUBMISSION_RECEIVED' and entity_id in(${lit(s1.id)},${lit(s2.id)}))`)).toBe(2);
 expect(root(`(select count(*) from public.notifications where recipient_user_id='${id(6006)}' and entity_id in(${lit(s1.id)},${lit(s2.id)}))`)).toBe(0);privateBoundaries();
 const progressBefore=await getMyLearningProgress();expect(progressBefore.contexts.find(c=>c.team?.id===teamA.teamId)!.progress).toMatchObject({completedRequiredActivities:0,completionPercentage:0});
 current(`public.complete_activity(${lit(instance)})`);
 const progress=await getMyLearningProgress();expect(progress.contexts.find(c=>c.team?.id===teamA.teamId)!.progress).toMatchObject({requiredActivitiesTotal:4,completedRequiredActivities:1,completionPercentage:25});
 const completed=await getMyCurrentWork();expect(completed.contexts.flatMap(c=>c.activities).find(a=>a.instanceId===instance)).toMatchObject({status:'completed'});
 expect(completed.contexts.flatMap(c=>c.activities.flatMap(a=>a.work)).find(w=>w.id===artifact)!.approvedOutput!.id).toBe(v4.id);privateBoundaries();
 // Movement/removal revoke future access but never rewrite authored history.
 const history=()=>root(`jsonb_build_object('versions',(select jsonb_agg(to_jsonb(v) order by id) from public.artifact_versions v where artifact_id=${lit(artifact)}),'feedback',(select to_jsonb(f) from public.feedback_items f where id=${lit(feedback.id)}),'chat',(select to_jsonb(m) from public.chat_messages m where id=${lit(chat.id)}),'object',(select to_jsonb(o) from public.development_objects o where id=${lit(object.id)}),'submission',(select to_jsonb(s) from public.submissions s where id=${lit(s2.id)}))`);
 const before=history();actor.id=master;current(`public.move_team_member(${lit(student)},${lit(teamA.teamId)},${lit(teamB.teamId)},'M15.30 move')`);actor.id=student;
 expect(current(`public.get_team_workspace_access(${lit(teamA.workspaceId)})`)).toBeNull();expect(current(`public.get_team_workspace_access(${lit(teamB.workspaceId)})`)).toBe('member');
 expect(current(`(select count(*) from public.chat_messages where id=${lit(chat.id)})`)).toBe(0);expect(current(`(select count(*) from public.artifact_versions where id=${lit(v4.id)})`)).toBe(0);
 expect((await getMyCurrentWork()).contexts.some(c=>c.team?.id===teamA.teamId)).toBe(false);expect((await getMyLearningProgress()).contexts.some(c=>c.team?.id===teamA.teamId)).toBe(false);expect(history()).toEqual(before);
 actor.id=master;current(`public.remove_team_member(${lit(teamB.teamId)},${lit(student)},'M15.30 remove')`);actor.id=student;
 expect(current(`public.get_team_workspace_access(${lit(teamB.workspaceId)})`)).toBeNull();expect(current(`public.can_access_team_chat(${lit(teamB.chatChannelId)})`)).toBe(false);
 const removed=await getMyCurrentWork();expect(removed.contexts).toHaveLength(1);expect(removed.contexts[0].project.id).toBe(personal.id);expect(history()).toEqual(before);
 expect(root(`(select count(*) from public.team_memberships where user_id=${lit(student)} and team_id in(${lit(teamA.teamId)},${lit(teamB.teamId)}) and status='removed' and left_at is not null)`)).toBe(2);
},240000);


// Dedicated disposable run: reuse accepted pilot lifecycle, with real recipient
// RLS and production list/read/controller/email services. Broadcast transport and
// external email are controlled seams; no live provider or email is contacted.
if(process.env.FICI_PILOT_NOTIFICATIONS==='1')it('M15.31 integrated membership/Share/submission/revision/resubmission/approval notification pilot',async()=>{
 const student=id(6004),lead=id(6005),master=id(6002),outsider=id(6006),team=fixture('Team A');
 const artifact=fixture('Artifact Team').artifactId,instance=fixture('Instance Team').id,v3=fixture('V3').id;
 const baseline=root(`(select coalesce(jsonb_agg(id),'[]') from public.notifications)`) as string[];
 const teamBBefore=root(`(select coalesce(jsonb_agg(to_jsonb(n) order by id),'[]') from public.notifications n where recipient_user_id in('${id(6006)}','${id(6007)}'))`);
 const reviewHelper=readFileSync(new URL('../integration/pilot-master-acceptance.sql',import.meta.url),'utf8').match(/create function pg_temp\.pm_notify\b[\s\S]+?\nend\$\$;/)?.[0];
 const shareHelper=readFileSync(new URL('../integration/share-notifications.sql',import.meta.url),'utf8').match(/create function pg_temp\.sn_deliver\b[\s\S]+?\nend \$\$;/)?.[0];
 if(!reviewHelper||!shareHelper)throw Error('Accepted canonical notification dispatch helpers required');
 function deliver(kind:string,sid:string){sql(`begin;${reviewHelper}set local role service_role;select pg_temp.pm_notify(${lit(kind)},${lit(sid)});select pg_temp.pm_notify(${lit(kind)},${lit(sid)});commit;`);}
 const allNotices=()=>root(`(select coalesce(jsonb_agg(to_jsonb(n) order by id),'[]') from public.notifications n)`) as {id:string;recipient_user_id:string;notification_type:string;entity_id:string;read_at:string|null}[];
 const fresh=()=>allNotices().filter(n=>!baseline.includes(n.id));
 function recipients(kind:string,source:string){return fresh().filter(n=>n.notification_type===kind&&n.entity_id===source).map(n=>n.recipient_user_id).sort();}
 const broadcastState=(noticeId:string)=>root(`(select coalesce(jsonb_agg(jsonb_build_object('topic',topic,'private',private,'payload',payload)),'[]') from realtime.messages where event='notification.changed' and payload->>'id'=${lit(noticeId)})`);
 // A1 joins through the existing membership command; retries keep event identity.
 actor.id=master;current(`public.remove_team_member(${lit(team.teamId)},${lit(student)},'M15.31 initial setup')`);
 const added=current(`public.add_team_member(${lit(team.teamId)},${lit(student)},'member')`);
 const addEvent=sql(`select id from public.audit_events where event_type='MEMBER_ADDED' and metadata->>'membershipId'=${lit(added.membershipId)};`);
 const request={notificationType:'MEMBER_ADDED',recipientContext:{sourceId:addEvent},formatterInput:{},entityReference:{entityType:'team',entityId:team.teamId},title:'Team membership updated',body:'You have been added to a Team.',recipientStrategy:'AFFECTED_MEMBERSHIP_USER'};
 const membershipCount=allNotices().length;
 sql(`begin;set local role service_role;select public.create_domain_notification(${lit(JSON.stringify({...request,idempotencyKey:'M1531:first'}))}::jsonb);select public.create_domain_notification(${lit(JSON.stringify({...request,idempotencyKey:'M1531:retry'}))}::jsonb);commit;`);
 expect(allNotices()).toHaveLength(membershipCount);expect(recipients('MEMBER_ADDED',team.teamId)).toEqual([student]);
 actor.id=student;expect((await listMyNotifications({limit:100})).items.some(n=>n.notification_type==='MEMBER_ADDED'&&n.entity_id===team.teamId)).toBe(true);
 // Team -> assigned Master Share uses the existing enabled in-app policy.
 const assignment=sql(`select ra.id from public.role_assignments ra join public.roles r on r.id=ra.role_id where ra.user_id=${lit(master)} and r.code='MASTER' and ra.status='active' and ra.cohort_id=(select cohort_id from public.teams where id=${lit(team.teamId)}) limit 1;`);
 actor.id=lead;const share=current(`public.share_entity(${lit(JSON.stringify({entityType:'ARTIFACT',entityId:artifact,sourceVersionId:v3,destinationType:'MASTER',destinationId:assignment,permissionLevel:'VIEW',shareMode:'SNAPSHOT'}))}::jsonb)`);
 sql(`begin;${shareHelper}set local role service_role;select pg_temp.sn_deliver(${lit(share.id)});select pg_temp.sn_deliver(${lit(share.id)});commit;`);
 expect(recipients('ARTIFACT_SHARED',share.id)).toEqual([master]);
 actor.id=master;expect(current(`public.resolve_shared_entity_access(jsonb_build_object('shareId',${lit(share.id)}))`)).toMatchObject({allowed:true,canEdit:false});
 expect(current(`(select count(*) from public.workspaces where id=${lit(team.workspaceId)})`)).toBe(0);
 actor.id=lead;const submitted=current(`public.submit_artifact(${lit(artifact)},${lit(v3)},${lit(instance)})`);deliver('SUBMISSION_RECEIVED',submitted.id);
 expect(submitted).toMatchObject({reviewer_user_id:master,artifact_version_id:v3});expect(recipients('SUBMISSION_RECEIVED',submitted.id)).toEqual([master]);
 actor.id=master;current(`public.start_review(${lit(submitted.id)})`);current(`public.request_revision(${lit(submitted.id)},'M15.31 exact Version revision')`);deliver('REVISION_REQUESTED',submitted.id);
 expect(recipients('REVISION_REQUESTED',submitted.id)).toEqual([student,lead].sort());
 actor.id=lead;const next=current(`public.create_revision_draft(${lit(submitted.id)},'{"pilot":"M1531"}','Notification pilot revision')`);
 const resubmitted=current(`public.submit_artifact(${lit(artifact)},${lit(next.id)},${lit(instance)})`);deliver('SUBMISSION_RECEIVED',resubmitted.id);
 expect(resubmitted.artifact_version_id).toBe(next.id);expect(recipients('SUBMISSION_RECEIVED',resubmitted.id)).toEqual([master]);
 actor.id=master;current(`public.start_review(${lit(resubmitted.id)})`);current(`public.approve_artifact(${lit(resubmitted.id)},'M15.31 approval')`);deliver('ARTIFACT_APPROVED',resubmitted.id);
 expect(recipients('ARTIFACT_APPROVED',resubmitted.id)).toEqual([student,lead].sort());
 expect(root(`(select current_version_id=${lit(next.id)} from public.artifacts where id=${lit(artifact)})`)).toBe(true);
 expect(root(`(select coalesce(jsonb_agg(to_jsonb(n) order by id),'[]') from public.notifications n where recipient_user_id in('${id(6006)}','${id(6007)}'))`)).toEqual(teamBBefore);
 const notices=fresh();expect(notices).toHaveLength(9); // includes the setup removal, one canonical record/event/recipient
 for(const n of notices)expect(broadcastState(n.id)).toEqual([{topic:'notifications:'+n.recipient_user_id,private:true,payload:{id:n.id,read_at:null}}]);
 // A known link never grants access: revoked Share target and unrelated reviewer
 // IDs are reauthorized, while historical notification remains readable.
 actor.id=lead;current(`public.revoke_share(jsonb_build_object('shareId',${lit(share.id)}))`);
 actor.id=master;expect(current(`public.resolve_shared_entity_access(jsonb_build_object('shareId',${lit(share.id)}))`)).toMatchObject({allowed:false});
 expect((await listMyNotifications({limit:100})).items.some(n=>n.entity_id===share.id)).toBe(true);
 actor.id=outsider;expect(current(`public.resolve_shared_entity_access(jsonb_build_object('shareId',${lit(share.id)}))`)).toMatchObject({allowed:false});
 expect(current(`public.can_review_submission(${lit(resubmitted.id)})`)).toBe(false);
 expect(current(`(select count(*) from public.submissions where id in(${lit(submitted.id)},${lit(resubmitted.id)}))`)).toBe(0);
 expect(current(`(select count(*) from public.workspaces where id=${lit(team.workspaceId)})`)).toBe(0);
 // Production list/read and controller; simulated delivery carries actual private
 // DB broadcast payloads. Every load runs fresh authenticated RLS, including rejoin.
 const approval=notices.find(n=>n.notification_type==='ARTIFACT_APPROVED'&&n.recipient_user_id===student)!;
 const views=new Map<string,readonly NotificationRealtimeItem[]>(),listeners=new Map<string,(event:unknown)=>void>();let unavailable=0;
 function controller(user:string){return createNotificationRealtimeController({
  authorize:async()=>{actor.id=user;expect(current(`public.can_receive_notification_broadcast(${lit('notifications:'+user)})`)).toBe(true);return {userId:user,topic:'notifications:'+user};},
  load:async()=>{actor.id=user;return {userId:user,page:await listMyNotifications({limit:100})};},
  subscribe:async(access,event)=>{listeners.set(access.userId,event);return async()=>{listeners.delete(access.userId);};},
  items:items=>{views.set(user,items);},unavailable:()=>{unavailable++;},
 });}
 const a=controller(student),b=controller(outsider);await a.connect();await b.connect();
 expect(views.get(student)!.some(n=>n.id===approval.id&&n.read_at===null)).toBe(true);
 expect(views.get(outsider)!.some(n=>notices.some(x=>x.id===n.id))).toBe(false);
 actor.id=student;const read=await markNotificationRead(approval.id);expect(await markNotificationRead(approval.id)).toEqual(read);
 const events=broadcastState(approval.id);expect(events).toHaveLength(2);expect(events[1].payload.read_at??events[0].payload.read_at).toBe(read.read_at);
 const bBefore=views.get(outsider);listeners.get(student)!({id:approval.id,read_at:read.read_at});await a.refresh();
 expect(views.get(student)!.find(n=>n.id===approval.id)!.read_at).toBe(read.read_at);expect(views.get(outsider)).toEqual(bBefore);
 await a.disconnect();actor.id=student;const unread=notices.find(n=>n.recipient_user_id===student&&n.id!==approval.id)!;await markNotificationRead(unread.id);
 await a.reconnect();expect(views.get(student)!.find(n=>n.id===unread.id)!.read_at).not.toBeNull();expect(views.get(student)!.find(n=>n.id===approval.id)!.read_at).toBe(read.read_at);expect(unavailable).toBe(0);
 actor.id=outsider;await expect(markNotificationRead(approval.id)).rejects.toMatchObject({code:'NOT_FOUND'});
 expect(current(`public.can_receive_notification_broadcast(${lit('notifications:'+student)})`)).toBe(false);
 expect(sql(`begin;set local role authenticated;select set_config('request.jwt.claim.sub',${lit(outsider)},true);select set_config('realtime.topic',${lit('notifications:'+student)},true);select 'COUNT='||count(*) from realtime.messages;rollback;`)).toContain('COUNT=0');
 await a.disconnect();await b.disconnect();
 // Actual service-only committed email projection and production scheduler; fake
 // external provider failures cannot change notifications, approval or membership.
 expect(pilotEmailDefaults).toEqual({MEMBER_ADDED:true,MEMBER_REMOVED:true,MEMBER_MOVED:true,SUBMISSION_RECEIVED:true,REVISION_REQUESTED:true,ARTIFACT_APPROVED:true,ARTIFACT_SHARED:false,COMMENT_RECEIVED:false});
 const state=()=>root(`jsonb_build_object('notifications',(select md5(jsonb_agg(to_jsonb(n) order by id)::text) from public.notifications n),'submissions',(select md5(jsonb_agg(to_jsonb(s) order by id)::text) from public.submissions s),'artifacts',(select md5(jsonb_agg(to_jsonb(a) order by id)::text) from public.artifacts a),'versions',(select md5(jsonb_agg(to_jsonb(v) order by id)::text) from public.artifact_versions v),'memberships',(select md5(jsonb_agg(to_jsonb(m) order by id)::text) from public.team_memberships m))`);
 const before=state(),queue:(()=>Promise<void>)[]=[],logs:unknown[]=[];
 const fetcher=vi.fn<typeof fetch>().mockResolvedValue(new Response(null,{status:503}));
 const provider=new ResendEmailProvider({apiKey:'re_mock_M1531',from:'notices@example.test',siteOrigin:'https://fici.example.test',timeoutMs:20},[notificationEmailTemplate],fetcher);
 const delivery=createNotificationEmailDelivery({read:async input=>JSON.parse(sql(`set role service_role;select public.notification_email_contexts(${lit(JSON.stringify(input))}::jsonb);`)),provider:()=>provider,schedule:work=>{queue.push(work);},log:event=>{logs.push(event);}});
 for(const n of notices){const count=queue.length;await delivery.schedule({notificationId:n.id});expect(queue.length-count).toBe(n.notification_type==='ARTIFACT_SHARED'?0:1);}
 expect(queue).toHaveLength(8);expect(fetcher).not.toHaveBeenCalled();for(const work of queue)await work();
 expect(fetcher).toHaveBeenCalledTimes(8);expect(logs).toHaveLength(8);expect(logs.every(e=>(e as {outcome:string}).outcome==='UNAVAILABLE')).toBe(true);expect(state()).toEqual(before);
 await delivery.schedule({notificationId:approval.id});await queue.at(-1)!();
 const calls=fetcher.mock.calls;expect(calls.at(-1)![1]!.headers).toEqual(calls[notices.filter(n=>n.notification_type!=='ARTIFACT_SHARED').findIndex(n=>n.id===approval.id)][1]!.headers);expect(state()).toEqual(before);
 expect(root(`has_function_privilege('authenticated','public.notification_email_contexts(jsonb)','execute')`)).toBe(false);
},240000);
// M15.32 uses the accepted M15.24 curriculum/team provisioning pattern inside
// the existing disposable pilot fixture. All workflow transitions are real RPCs.
if(process.env.FICI_PILOT_PROGRESS==='1')it('M15.32 integrated canonical Activity progress, review/revision/exact approval and dependency handoff',async()=>{
 const student=id(6004),lead=id(6005),master=id(6002),foreign=id(6006),cv=id(983100),session=id(983101),aDef=id(983102),bDef=id(983103),optional=id(983104);
 const program=id(601),foreignPersonal=fixture('A2 Project'),foreignTeam=fixture('Team B');
 actor.id=student;const personalBefore=(await getMyLearningProgress()).contexts.find(c=>c.workspace.type==='PERSONAL')!;
 // Same DRAFT -> definitions -> APPROVED setup used by denominator regressions.
 sql(`begin;insert into public.curriculum_versions(id,program_id,version_label,status) values(${lit(cv)},${lit(program)},'M15.32 pilot','draft');
 insert into public.session_definitions(id,curriculum_version_id,session_number,title,description,learning_goal,sequence,status) values(${lit(session)},${lit(cv)},1,'Pilot progress','Fixture','Canonical progression',1,'active');
 insert into public.activity_definitions(id,session_definition_id,name,method_type,workspace_mode,sequence,status,requires_review,configuration) values
 (${lit(aDef)},${lit(session)},'Activity A','custom','Team Workspace',1,'active',true,'{}'),
 (${lit(bDef)},${lit(session)},'Activity B','custom','Team Workspace',2,'active',false,'{}'),
 (${lit(optional)},${lit(session)},'Optional Activity','custom','Team Workspace',3,'active',false,'{"learning_progress":{"required":false}}');
 insert into public.activity_dependencies(activity_definition_id,required_activity_definition_id,dependency_type,is_mandatory) values(${lit(bDef)},${lit(aDef)},'approved_output',true),(${lit(bDef)},${lit(aDef)},'completion',true);
 update public.curriculum_versions set status='approved' where id=${lit(cv)};commit;`);
 actor.id=id(6001);const cohort=current(`public.create_cohort(${lit(program)},${lit(cv)},'M15.32 Cohort','2026-10-01',null,${lit(master)},'active','{}')`).id;
 sql(`insert into public.enrollments(cohort_id,user_id,enrollment_role,status) values(${lit(cohort)},${lit(student)},'participant','active'),(${lit(cohort)},${lit(lead)},'participant','active'),(${lit(cohort)},${lit(master)},'participant','active');`);
 actor.id=master;const team=current(`public.create_team(${lit(cohort)},'M15.32 Team A',null,${lit(lead)})`);
 current(`public.add_team_member(${lit(team.teamId)},${lit(student)},'member')`);
 sql(`update public.teams set status='active' where id=${lit(team.teamId)};`);
 const project=current(`public.create_development_project('M15.32 Team project','team',${lit(team.workspaceId)},null,null,${lit(team.teamId)})`);
 sql(`insert into public.project_memberships(project_id,user_id) values(${lit(project.id)},${lit(student)}),(${lit(project.id)},${lit(lead)}),(${lit(project.id)},${lit(master)});insert into public.project_program_links(project_id,program_id,cohort_id) values(${lit(project.id)},${lit(program)},${lit(cohort)});`);
 const args=(definition:string)=>`${lit(definition)},${lit(project.id)},${lit(team.workspaceId)},${lit(team.teamId)}`;
 // Assignment and even Project participation alone do not manufacture Team ACL.
 expect(current(`public.start_activity(${args(aDef)})`)).toMatchObject({started:false});
 current(`public.add_team_member(${lit(team.teamId)},${lit(master)},'member')`);
 const launched=current(`public.start_activity(${args(aDef)})`);expect(launched).toMatchObject({started:true,activity:{started_by:master,status:'active'}});const instance=launched.activity.id;
 actor.id=lead;expect(current(`public.resume_activity(${lit(instance)})`)).toMatchObject({activity:{id:instance,status:'active'}});
 expect(current(`public.start_activity(${args(aDef)})`)).toMatchObject({started:false,reasonCode:'ACTIVE_INSTANCE_EXISTS',existingActiveInstanceId:instance});
 expect(root(`(select count(*) from public.activity_instances where activity_definition_id=${lit(aDef)} and project_id=${lit(project.id)})`)).toBe(1);
 const canonical=()=>root(`jsonb_build_object('instances',(select md5(jsonb_agg(to_jsonb(x) order by id)::text) from public.activity_instances x),'participants',(select md5(jsonb_agg(to_jsonb(x) order by id)::text) from public.activity_participants x),'artifacts',(select md5(jsonb_agg(to_jsonb(x) order by id)::text) from public.artifacts x),'versions',(select md5(jsonb_agg(to_jsonb(x) order by id)::text) from public.artifact_versions x),'submissions',(select md5(jsonb_agg(to_jsonb(x) order by id)::text) from public.submissions x),'outputs',(select md5(jsonb_agg(to_jsonb(x) order by id)::text) from public.activity_outputs x),'notifications',(select md5(jsonb_agg(to_jsonb(x) order by id)::text) from public.notifications x))`);
 async function studentView(){actor.id=student;const work=await getMyCurrentWork();
  // Exercise the canonical count RPC per transition. The production aggregate
  // wrapper is verified separately at entry/exit; it redundantly reconstructs
  // every dashboard twice, which is costly with this subprocess SQL adapter.
  const progress=current(`public.get_my_learning_progress(${lit(project.id)},${lit(team.workspaceId)},${lit(cohort)},${lit(team.teamId)})`);
  expect(work.contexts.some(c=>c.project.id===foreignPersonal.id||c.team?.id===foreignTeam.teamId)).toBe(false);
  expect(current(`public.get_my_learning_progress(${lit(personalBefore.project.id)},${lit(personalBefore.workspace.id)},${lit(personalBefore.cohort.id)},null)`)).toEqual(personalBefore.progress);
  expect(current(`(select count(*) from public.workspaces where id in(${lit(foreignPersonal.primary_workspace_id)},${lit(foreignTeam.workspaceId)}))`)).toBe(0);
  return {work:work.contexts.find(c=>c.project.id===project.id)!,progress};
 }
 const initial=await studentView();expect(initial.work.activities.find(a=>a.instanceId===instance)!.status).toBe('active');
 expect(initial.progress).toEqual({requiredActivitiesTotal:2,completedRequiredActivities:0,inProgressActivities:1,blockedActivities:1,notStartedActivities:0,optionalActivities:{total:1,completed:0},completionPercentage:0});
 actor.id=lead;expect(current(`public.resolve_activity_availability(${args(bDef)})`)).toMatchObject({available:false,reasonCode:'DEPENDENCY_NOT_MET'});
 const artifact=current(`public.create_artifact(${lit(project.id)},${lit(team.workspaceId)},'PROBLEM_BANK','M15.32 output',${lit(instance)},true,true)`);
 current(`public.add_activity_artifact_output(${lit(instance)},${lit(artifact.artifactId)})`);
 const draftView=await studentView();expect(draftView.work.activities.flatMap(a=>a.work).find(w=>w.id===artifact.artifactId)).toMatchObject({approvedOutput:null,drafts:[{id:artifact.initialVersionId,status:'DRAFT'}]});
 // A deliberately misleading historical notice cannot approve work or queue it.
 sql(`insert into public.notifications(recipient_user_id,notification_type,title,body,entity_type,entity_id) values(${lit(student)},'ARTIFACT_APPROVED','Artifact approved','A notification is not workflow authority.','artifact',${lit(artifact.artifactId)});`);
 expect(await studentView()).toEqual(draftView);
 actor.id=master;expect((await getPendingReviewQueue(cohort)).items).toEqual([]);
 actor.id=lead;const s1=current(`public.submit_artifact(${lit(artifact.artifactId)},${lit(artifact.initialVersionId)},${lit(instance)})`);
 actor.id=master;expect((await getPendingReviewQueue(cohort)).items).toMatchObject([{submissionId:s1.id,version:{id:artifact.initialVersionId},reviewState:'SUBMITTED'}]);
 let overview=await getMasterCohortOverview(cohort);expect(overview.teams.map(t=>t.team.id)).toEqual([team.teamId]);
 expect(overview.teams[0].projects.find(p=>p.project.id===project.id)!.pendingReview.targets).toMatchObject([{submissionId:s1.id,versionId:artifact.initialVersionId}]);
 current(`public.start_review(${lit(s1.id)})`);expect((await getPendingReviewQueue(cohort)).items[0].reviewState).toBe('UNDER_REVIEW');
 current(`public.request_revision(${lit(s1.id)},'M15.32 canonical revision')`);expect((await getPendingReviewQueue(cohort)).items).toEqual([]);
 const requested=await studentView(),requestedWork=requested.work.activities.flatMap(a=>a.work).find(w=>w.id===artifact.artifactId)!;
 expect(requestedWork.submissions).toMatchObject([{id:s1.id,status:'REVISION_REQUESTED',revisionRequested:true,artifactVersionId:artifact.initialVersionId}]);
 expect((await getMyRevisionStatus()).outstanding.some(s=>s.submissionId===s1.id)).toBe(true);expect(requested.progress).toEqual(initial.progress);
 actor.id=lead;const v2=current(`public.create_revision_draft(${lit(s1.id)},'{"private":"M1532 revision"}','Pilot revision')`);
 const s2=current(`public.submit_artifact(${lit(artifact.artifactId)},${lit(v2.id)},${lit(instance)})`);
 const v3=current(`public.create_artifact_version(${lit(artifact.artifactId)},'{"private":"M1532 newer unapproved"}','Later Draft')`);
 const resubmitted=await studentView(),pendingWork=resubmitted.work.activities.flatMap(a=>a.work).find(w=>w.id===artifact.artifactId)!;
 expect(pendingWork.approvedOutput).toBeNull();expect(pendingWork.drafts.map(v=>v.id)).toContain(v3.id);
 expect(pendingWork.submissions.find(s=>s.id===s1.id)!.revisionRequested).toBe(false);expect((await getMyRevisionStatus()).outstanding.some(s=>s.submissionId===s1.id)).toBe(false);
 actor.id=master;expect((await getPendingReviewQueue(cohort)).items).toMatchObject([{submissionId:s2.id,version:{id:v2.id},reviewState:'SUBMITTED'}]);
 current(`public.start_review(${lit(s2.id)})`);current(`public.approve_artifact(${lit(s2.id)},'M15.32 exact successor approval')`);
 expect((await getPendingReviewQueue(cohort)).items).toEqual([]);overview=await getMasterCohortOverview(cohort);
 expect(overview.teams[0].projects[0].approvedOutputs).toMatchObject([{artifactId:artifact.artifactId,versionId:v2.id,status:'CURRENT'}]);
 const approved=await studentView(),approvedWork=approved.work.activities.flatMap(a=>a.work).find(w=>w.id===artifact.artifactId)!;
 expect(approvedWork.approvedOutput).toMatchObject({id:v2.id,status:'CURRENT'});expect(approvedWork.drafts.map(v=>v.id)).toContain(v3.id);expect(approved.progress).toEqual(initial.progress);
 // Approval is distinct from Activity completion: B also requires completion.
 actor.id=lead;expect(current(`public.resolve_activity_availability(${args(bDef)})`)).toMatchObject({available:false,reasonCode:'DEPENDENCY_NOT_MET'});
 expect(current(`public.evaluate_activity_dependencies(${args(bDef)})`).missingRequiredDependencies).toHaveLength(1);
 current(`public.complete_activity(${lit(instance)})`);expect(current(`public.resolve_activity_availability(${args(bDef)})`)).toEqual({available:true});
 const completed=await studentView();expect(completed.work.activities.find(a=>a.instanceId===instance)!.status).toBe('completed');expect(completed.progress).toMatchObject({requiredActivitiesTotal:2,completedRequiredActivities:1,inProgressActivities:0,blockedActivities:0,notStartedActivities:1,completionPercentage:50,optionalActivities:{total:1,completed:0}});
 actor.id=lead;const opt=current(`public.start_activity(${args(optional)})`);current(`public.complete_activity(${lit(opt.activity.id)})`);
 const withOptional=await studentView();expect(withOptional.progress).toMatchObject({requiredActivitiesTotal:2,completedRequiredActivities:1,completionPercentage:50,optionalActivities:{total:1,completed:1}});
 actor.id=lead;expect(current(`public.start_activity(${args(bDef)})`)).toMatchObject({started:true});
 // Fresh service calls reconstruct identical projections without writes/caches.
 const before=canonical(),refresh1=await studentView(),refresh2=await studentView();expect(refresh2).toEqual(refresh1);expect(canonical()).toEqual(before);
 expect(refresh2.progress).toMatchObject({completedRequiredActivities:1,inProgressActivities:1,completionPercentage:50});
 const aggregate=await getMyLearningProgress();expect(aggregate.contexts.find(c=>c.project.id===project.id)!.progress).toEqual(refresh2.progress);expect(aggregate.contexts.find(c=>c.workspace.type==='PERSONAL')).toEqual(personalBefore);expect(canonical()).toEqual(before);
 await expect(getMyLearningProgress({completionPercentage:100})).rejects.toMatchObject({code:'VALIDATION_ERROR'});
 await expect(getMyCurrentWork({progress:'complete'})).rejects.toMatchObject({code:'VALIDATION_ERROR'});
 actor.id=foreign;expect((await getMyCurrentWork()).contexts.some(c=>c.project.id===project.id)).toBe(false);
 expect((await getMyLearningProgress()).contexts.some(c=>c.project.id===project.id)).toBe(false);
 expect(current(`public.get_my_learning_progress(${lit(project.id)},${lit(team.workspaceId)},${lit(cohort)},${lit(team.teamId)})`)).toBeNull();
 expect(current(`(select count(*) from public.submissions where id in(${lit(s1.id)},${lit(s2.id)}))`)).toBe(0);
 await expect(getMasterCohortOverview(cohort)).rejects.toMatchObject({code:'FORBIDDEN'});await expect(getPendingReviewQueue(cohort)).rejects.toMatchObject({code:'FORBIDDEN'});
 actor.id=id(6003);await expect(getMasterCohortOverview(cohort)).rejects.toMatchObject({code:'FORBIDDEN'});
 expect(root(`(select count(*) from public.activity_instances where activity_definition_id=${lit(aDef)} and project_id=${lit(project.id)})`)).toBe(1);
},360000);
