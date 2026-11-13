import {spawnSync} from 'node:child_process';
import {join} from 'node:path';
import {artifactReviewSecurityFixture} from './artifact-review-security-fixture.mjs';
export function testPersonalSharing({run,args,childEnv,root}){
 const name='fici_personal_sharing';run('psql',[...args,'-c',`create database ${name} template postgres`]);
 const db=args.map((v,i)=>args[i-1]==='-d'?name:v);
 try{
  run('psql',[...db,'-f','-'],artifactReviewSecurityFixture(root)+`
reset role;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
create table public.personal_share_context(label text primary key,payload jsonb);
insert into personal_share_context select 'Project',payload from logged_projects where label='Individual';
insert into personal_share_context select 'Workspace',to_jsonb(w) from public.workspaces w where id=(select (payload->>'primary_workspace_id')::uuid from logged_projects where label='Individual');
insert into personal_share_context select 'TeamA',payload from acceptance_teams where label='A';
insert into personal_share_context select 'TeamB',payload from acceptance_teams where label='B';
insert into personal_share_context select 'Activity',jsonb_build_object('id',id) from instances where label='Individual';
insert into personal_share_context select 'Idea'||n,public.create_development_object((payload->>'id')::uuid,(payload->>'primary_workspace_id')::uuid,'IDEA','Private idea '||n,'Personal content '||n,'User') from logged_projects cross join generate_series(1,10) n where label='Individual';
insert into personal_share_context select 'Scamper'||n,public.create_scamper_entry((select id from instances where label='Individual'),'SUBSTITUTE','Original '||n,'Proposed '||n,'Result '||n) from generate_series(1,10) n;
do $$declare p jsonb;a jsonb;v jsonb;u jsonb;f jsonb;begin
 select payload into p from logged_projects where label='Individual';
 insert into personal_share_context values('Evidence',public.create_evidence((p->>'id')::uuid,(p->>'primary_workspace_id')::uuid,'MEASUREMENT','Private Personal evidence','Observed source information','Personal lab notebook',null,null));
 a:=public.create_artifact((p->>'id')::uuid,(p->>'primary_workspace_id')::uuid,'DEVELOPED_CONCEPT','Selected Personal Artifact',null,false,false);
 v:=public.create_artifact_version((a->>'artifactId')::uuid,'{"notes":"Explicit Personal V2"}','V2');
 insert into personal_share_context values('Artifact',a),('Version',v);
 u:=public.request_file_upload((p->>'primary_workspace_id')::uuid,(p->>'id')::uuid,'unshared-attachment.txt','text/plain',3);
 insert into storage.objects(bucket_id,name,metadata) values('fici-private-files',u->>'storage_reference','{"size":3,"mimetype":"text/plain"}');
 f:=public.register_uploaded_file((u->>'id')::uuid);
 insert into personal_share_context values('File',f),('FileLink',public.link_file(jsonb_build_object('fileId',f->>'id','entityType','DEVELOPMENT_OBJECT','entityId',(select payload->>'id' from personal_share_context where label='Idea1'),'relationshipType','ATTACHMENT')));
end$$;
commit;`);
  const result=spawnSync(process.execPath,[join(root,'node_modules/vitest/vitest.mjs'),'run','--config','vitest.personal-sharing.config.mts'],{cwd:root,encoding:'utf8',windowsHide:true,timeout:180000,env:{...childEnv,FICI_PERSONAL_SHARE_TEST_PORT:String(args[args.indexOf('-p')+1])}});
  if(result.error||result.status!==0)throw Error(`Personal sharing acceptance failed: ${result.error?.message??result.stderr}\n${result.stdout}`);
  const ids=run('psql',[...db,'-t','-A','-c',`select jsonb_build_object(
   'shared',coalesce(jsonb_agg(o.id order by o.title) filter(where s.id is not null),'[]'),
   'denied',coalesce(jsonb_agg(o.id order by o.title) filter(where s.id is null),'[]'),
   'sharedCount',count(s.id),'deniedCount',count(*) filter(where s.id is null))
   from public.development_objects o join public.development_projects p on p.id=o.project_id
   left join public.shares s on s.shared_entity_type='DEVELOPMENT_OBJECT' and s.shared_entity_id=o.id and s.source_workspace_id=o.workspace_id
   where p.name='AT-PW-004 exactly ten'`]).trim();
  const counts=JSON.parse(ids);if(counts.sharedCount!==3||counts.deniedCount!==7)throw Error('Missing exact Personal acceptance identities');
  console.log('M13.21 AT_PW_004_ENTITIES='+ids);
  console.log(result.stdout);console.log('M13.6 AT-PW-004/AT-SCAMPER-003 actual services/selected-only/provenance/route/privacy/removal PASS');
  console.log('M13.18 AT-SCAMPER-003 three-of-ten/frozen/VIEW-COMMENT/source-RLS/revocation/history/audit PASS');
  console.log('M13.21 AT-PW-004 exactly-ten/three-selected/seven-private/ownership/records/collections/RLS/revoke/removal PASS');
 }finally{run('psql',[...args,'-c',`drop database ${name} with (force)`]);}
}
