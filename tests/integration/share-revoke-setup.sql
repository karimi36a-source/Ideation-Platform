reset role;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.add_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006005','member');
create table public.revoke_test_context(label text primary key,payload jsonb);
insert into public.revoke_test_context select 'Team'||label,payload from acceptance_teams where label in ('A','B');
insert into public.revoke_test_context select 'Project',payload from logged_projects where label='Team';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$declare p jsonb;a jsonb;v jsonb;r jsonb;u jsonb;f jsonb;label0 text;begin
 select payload into p from logged_projects where label='Team';
 foreach label0 in array array['Main','Sibling','Race','CommentRace','Rollback','Transition'] loop
  a:=public.create_artifact((p->>'id')::uuid,(p->>'primary_workspace_id')::uuid,'DEVELOPED_CONCEPT','Revoke '||label0,null,false,false);
  v:=public.create_artifact_version((a->>'artifactId')::uuid,'{"notes":"Exact selected V2"}','V2');
  insert into public.revoke_test_context values(label0||'Artifact',jsonb_build_object('id',a->>'artifactId')), (label0||'Version',v);
  if label0='Sibling' then continue;end if;
  r:=public.share_entity(pg_temp.share_request('ARTIFACT',(a->>'artifactId')::uuid)||jsonb_build_object('sourceVersionId',v->>'id','permissionLevel',case when label0 in ('Main','CommentRace','Transition') then 'COMMENT' else 'VIEW' end));
  insert into public.revoke_test_context values(label0||'Share',r);
  if label0='Main' then
   r:=public.share_entity(pg_temp.share_request('ARTIFACT',(a->>'artifactId')::uuid)||jsonb_build_object('sourceVersionId',v->>'id'));
   insert into public.revoke_test_context values('ViewShare',r);
  end if;
 end loop;
 r:=public.share_entity(pg_temp.share_request(source=>pg_temp.research_source('PersonalPatent'),target=>(select (payload->>'teamId')::uuid from acceptance_teams where label='A')));
 insert into public.revoke_test_context values('PersonalShare',r);
 u:=public.request_file_upload((p->>'primary_workspace_id')::uuid,(p->>'id')::uuid,'revoke.txt','text/plain',3);
 insert into storage.objects(bucket_id,name,metadata) values('fici-private-files',u->>'storage_reference','{"size":3,"mimetype":"text/plain"}');
 f:=public.register_uploaded_file((u->>'id')::uuid);
 insert into public.revoke_test_context values('File',f);
 r:=public.share_entity(pg_temp.share_request('FILE',(f->>'id')::uuid));insert into public.revoke_test_context values('FileShare',r);
end$$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006006',true);
insert into public.revoke_test_context select 'Comment',public.add_share_comment(jsonb_build_object('shareId',(select payload->>'id' from public.revoke_test_context where label='MainShare'),'content','Preserve this historical comment'));
commit;
