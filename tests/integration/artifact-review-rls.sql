-- M8.15: appended to artifactReviewSecurityFixture; real authenticated roles.
-- Helpers are SECURITY INVOKER. Only fixture preparation uses the cluster owner.
create function pg_temp.denied(command text) returns void language plpgsql as $$
begin
 begin execute command; exception when insufficient_privilege then return; end;
 raise exception 'Expected permission denial: %',command;
end $$;
create function pg_temp.empty_result(command text) returns void language plpgsql as $$
declare n bigint;begin
 execute 'select count(*) from ('||command||') denied_rows' into n;
 assert n=0,'Private rows exposed: '||command;
end $$;

-- Catalog inventory is checked from actual loaded migrations, not source mocks.
do $$declare t text;p record;permission text;allowed text[]:=array[
 'create_artifact','create_artifact_version','update_artifact_draft','archive_artifact','submit_artifact',
 'can_review_submission','can_review_artifact_version','can_review_linked_object',
 'get_submitted_artifact_metadata','start_review','add_feedback','request_revision',
 'create_revision_draft','approve_artifact','reopen_approved_artifact','set_project_baseline_item',
 'list_activity_artifact_candidates','add_activity_artifact_input','add_activity_artifact_output'];
begin
 foreach t in array array['artifacts','artifact_versions','artifact_object_links','submissions','feedback_items','review_actions','project_baseline_items'] loop
  assert exists(select 1 from pg_class where oid=('public.'||t)::regclass and relrowsecurity and not relforcerowsecurity), 'RLS enable/force convention: '||t;
  assert has_table_privilege('authenticated','public.'||t,'SELECT');
  foreach permission in array array['INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER'] loop
   assert not has_table_privilege('authenticated','public.'||t,permission),t||' grants '||permission;
  end loop;
  assert not has_any_column_privilege('authenticated','public.'||t,'INSERT');
  assert not has_any_column_privilege('authenticated','public.'||t,'UPDATE');
  assert not has_table_privilege('anon','public.'||t,'SELECT,INSERT,UPDATE,DELETE');
  assert not exists(select 1 from pg_policy where polrelid=('public.'||t)::regclass and polpermissive and polcmd in ('a','w','d','*')),'Unexpected mutation policy';
 end loop;
 assert (select count(*) from m8_function_inventory)>30;
 for p in select proc.* from pg_proc proc join pg_namespace n on n.oid=proc.pronamespace join m8_function_inventory f on f.name=proc.proname where n.nspname='public' loop
  assert p.proconfig=array['search_path=""'], 'Unsafe path: '||p.proname;
  assert not has_function_privilege('anon',p.oid,'EXECUTE'), 'Anonymous function: '||p.proname;
  assert not has_function_privilege('service_role',p.oid,'EXECUTE'), 'Unnecessary service execute: '||p.proname;
  assert not exists(select 1 from aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) where grantee=0 and privilege_type='EXECUTE'),'PUBLIC execute';
  assert has_function_privilege('authenticated',p.oid,'EXECUTE')=(p.proname=any(allowed)), 'Unexpected authenticated function: '||p.proname;
  assert p.proowner not in (select oid from pg_roles where rolname in ('authenticated','anon','service_role'));
  if p.prosecdef then
   assert p.prosrc !~* '\mexecute\M','Unexpected dynamic SQL in definer: '||p.proname;
   assert not coalesce(p.proargnames && array['actor','actor_id','actor_user_id','user_id','reviewer_user_id','approved_by'],false),'Caller-controlled identity';
  end if;
 end loop;
end $$;
select c.relname,c.relrowsecurity,c.relforcerowsecurity,p.polname,p.polcmd,p.polpermissive,pg_get_expr(p.polqual,p.polrelid) as predicate
from pg_class c join pg_policy p on p.polrelid=c.oid
where c.relname in ('artifacts','artifact_versions','artifact_object_links','submissions','feedback_items','review_actions','project_baseline_items') order by c.relname,p.polname;

-- Exact IDs for every child, without relying on an empty fixture to prove denial.
create temporary table security_ids(label text primary key,id uuid);grant select,insert on security_ids to authenticated,anon;
insert into security_ids select label||' Artifact',(payload->>'artifactId')::uuid from submitted_fixtures;
insert into security_ids select label||' Version',(payload->>'initialVersionId')::uuid from submitted_fixtures;
insert into public.artifact_object_links(artifact_id,artifact_version_id,development_object_id)
select (f.payload->>'artifactId')::uuid,(f.payload->>'initialVersionId')::uuid,(o.payload->>'id')::uuid from submitted_fixtures f join logged_objects o on o.label='Team' where f.label='Team';
insert into security_ids select f.label||' Link',l.id from artifact_object_links l join submitted_fixtures f on l.artifact_id=(f.payload->>'artifactId')::uuid;

set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
do $$begin
 assert not exists(select 1 from public.artifacts);
 assert not exists(select 1 from public.artifact_versions);
 assert public.get_submitted_artifact_metadata((select id from security_ids where label='Personal Artifact')) is null;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into security_ids select 'Personal Submission',(public.submit_artifact((payload->>'artifactId')::uuid,(payload->>'initialVersionId')::uuid,(select id from instances where label='Individual'))->>'id')::uuid from submitted_fixtures where label='Personal';
insert into security_ids select 'Future Version',(public.create_artifact_version((payload->>'artifactId')::uuid,'{"private_future":true}','Future')->>'id')::uuid from submitted_fixtures where label='Personal';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
insert into security_ids select 'Team Submission',(public.submit_artifact((payload->>'artifactId')::uuid,(payload->>'initialVersionId')::uuid,(select id from instances where label='Team'))->>'id')::uuid from submitted_fixtures where label='Team';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.start_review(id) from security_ids where label in ('Personal Submission','Team Submission');
insert into security_ids select 'Personal Feedback',(public.add_feedback('ARTIFACT',(select id from security_ids where label='Personal Artifact'),(select id from security_ids where label='Personal Version'),'COMMENT','Private Personal feedback')->>'id')::uuid;
insert into security_ids select 'Object Feedback',(public.add_feedback('DEVELOPMENT_OBJECT',(select (payload->>'id')::uuid from logged_objects where label='Problem'),(select id from security_ids where label='Personal Version'),'COMMENT','Private Object feedback')->>'id')::uuid;
insert into security_ids select 'Team Feedback',(public.add_feedback('ARTIFACT',(select id from security_ids where label='Team Artifact'),(select id from security_ids where label='Team Version'),'COMMENT','Private Team feedback')->>'id')::uuid;
reset role;
insert into security_ids select 'Personal Action',id from public.review_actions where submission_id=(select id from security_ids where label='Personal Submission') and action_type='STARTED_REVIEW';
insert into security_ids select 'Team Action',id from public.review_actions where submission_id=(select id from security_ids where label='Team Submission') and action_type='STARTED_REVIEW';

-- Review entitlement exposes exact Version/Object, sanitized Artifact metadata,
-- never direct whole Artifact rows, sibling Versions, Project or Workspace.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
do $$begin
 assert public.get_submitted_artifact_metadata((select id from security_ids where label='Personal Artifact'))->>'title'='Submission fixture';
 assert public.get_submitted_artifact_metadata((select id from security_ids where label='Sibling Artifact')) is null;
 assert exists(select 1 from public.artifact_versions where id=(select id from security_ids where label='Personal Version'));
 assert not exists(select 1 from public.artifact_versions where id=(select id from security_ids where label='Future Version'));
 assert exists(select 1 from public.artifact_object_links where id=(select id from security_ids where label='Personal Link'));
 assert exists(select 1 from public.development_objects where id=(select (payload->>'id')::uuid from logged_objects where label='Problem'));
 assert not exists(select 1 from public.development_objects where id=(select (payload->>'id')::uuid from logged_objects where label='Solution'));
 assert not exists(select 1 from public.workspaces where workspace_type='PERSONAL');
 assert not exists(select 1 from public.development_projects where project_type='individual');
end $$;
select pg_temp.denied(format('select public.archive_artifact(%L)',(select id from security_ids where label='Personal Artifact')));
select pg_temp.denied(format('select public.create_artifact_version(%L,''{}'',''forged'')',(select id from security_ids where label='Personal Artifact')));

-- Independent target RLS must remain authoritative even when Submission is
-- visible. A restrictive test-only policy models target access revocation.
reset role;
create policy m815_object_denial on public.development_objects as restrictive for select to authenticated using(id<>(select (payload->>'id')::uuid from logged_objects where label='Problem'));
set local role authenticated;
do $$begin
 assert exists(select 1 from public.submissions where id=(select id from security_ids where label='Personal Submission'));
 assert not exists(select 1 from public.development_objects where id=(select (payload->>'id')::uuid from logged_objects where label='Problem'));
 assert not exists(select 1 from public.artifact_object_links where id=(select id from security_ids where label='Personal Link'));
 assert not exists(select 1 from public.feedback_items where id=(select id from security_ids where label='Object Feedback')),'Feedback bypassed independently denied Object';
 assert exists(select 1 from public.feedback_items where id=(select id from security_ids where label='Personal Feedback'));
end $$;
reset role;drop policy m815_object_denial on public.development_objects;
create policy m815_version_denial on public.artifact_versions as restrictive for select to authenticated using(id<>(select id from security_ids where label='Personal Version'));
set local role authenticated;
do $$begin
 assert exists(select 1 from public.submissions where id=(select id from security_ids where label='Personal Submission'));
 assert not exists(select 1 from public.artifact_versions where id=(select id from security_ids where label='Personal Version'));
 assert not exists(select 1 from public.feedback_items where id in (select id from security_ids where label in ('Personal Feedback','Object Feedback'))),'Feedback bypassed independently denied submitted Version';
 assert exists(select 1 from public.feedback_items where id=(select id from security_ids where label='Team Feedback'));
end $$;
reset role;drop policy m815_version_denial on public.artifact_versions;

-- All fields are attempted separately: valid syntax must fail at permission
-- boundary before FK/constraint errors can disclose protected resource existence.
create temporary table m8_attacks(command text);grant select on m8_attacks to authenticated,anon;
do $$declare t text;column_name text;begin
 foreach t in array array['artifacts','artifact_versions','artifact_object_links','submissions','feedback_items','review_actions','project_baseline_items','audit_events'] loop
  insert into m8_attacks values(format('insert into public.%I default values',t)),(format('delete from public.%I where id in (select id from security_ids)',t));
  for column_name in select attname from pg_attribute where attrelid=('public.'||t)::regclass and attnum>0 and not attisdropped and attgenerated='' loop
   insert into m8_attacks values(format('update public.%I set %I=%I where id in (select id from security_ids)',t,column_name,column_name));
  end loop;
 end loop;
end $$;
-- Approval escalation fields, actual forged foreign identities and content.
insert into m8_attacks values
 ('update public.artifact_versions set content_snapshot=''"forged"'',approved_by=auth.uid(),approved_at=now(),approval_note=''forged'',status=''CURRENT'',previous_version_id=gen_random_uuid()'),
 ('update public.artifacts set current_version_id=(select id from security_ids where label=''Future Version'')'),
 ('update public.submissions set status=''APPROVED'',reviewer_user_id=auth.uid()'),
 ('insert into public.review_actions(submission_id,reviewer_user_id,action_type) values((select id from security_ids where label=''Team Submission''),auth.uid(),''APPROVED'')'),
 ('insert into public.artifact_object_links(artifact_id,artifact_version_id,development_object_id) values((select id from security_ids where label=''Personal Artifact''),(select id from security_ids where label=''Team Version''),(select (payload->>''id'')::uuid from logged_objects where label=''Team''))');
insert into m8_attacks select format('insert into public.audit_events(actor_user_id,event_type,entity_type,entity_id,scope_type,scope_id,metadata) values(auth.uid(),%L,''submission'',%L,''submission'',%L,''{}'')',event,id,id)
from security_ids cross join (values('REVISION_REQUESTED'),('ARTIFACT_APPROVED'),('ARTIFACT_REOPENED'),('BASELINE_UPDATED')) e(event) where label='Personal Submission';
set local role authenticated;
do $$declare actor integer;attack text;begin
 foreach actor in array array[6001,6002,6003,6004,6005,6006,6008] loop
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(actor::text,12,'0'),true);
  for attack in select command from m8_attacks loop perform pg_temp.denied(attack);end loop;
 end loop;
end $$;

-- The role never owns the tables. Catalog RLS and hostile grants below prove
-- denial comes from policies too, independently of missing DML privileges.
reset role;
grant update,delete on public.artifacts,public.artifact_versions,public.artifact_object_links,public.submissions,public.feedback_items,public.review_actions,public.project_baseline_items to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$declare t text;n bigint;begin
 foreach t in array array['artifacts','artifact_versions','artifact_object_links','submissions','feedback_items','review_actions','project_baseline_items'] loop
  execute format('update public.%I set id=id',t);get diagnostics n=row_count;assert n=0,'RLS UPDATE bypass';
  execute format('delete from public.%I',t);get diagnostics n=row_count;assert n=0,'RLS DELETE bypass';
 end loop;
end $$;
reset role;
revoke insert,update,delete on public.artifacts,public.artifact_versions,public.artifact_object_links,public.submissions,public.feedback_items,public.review_actions,public.project_baseline_items from authenticated;

-- Denied readers query each child independently and through left joins, so an
-- invisible parent cannot mask a leaking child. Exact known IDs and enumeration.
create function pg_temp.no_private_rows() returns void language plpgsql as $$
declare t text;begin
 foreach t in array array['artifacts','artifact_versions','artifact_object_links','submissions','feedback_items','review_actions','project_baseline_items'] loop
  perform pg_temp.empty_result(format('select * from public.%I',t));
  perform pg_temp.empty_result(format('select * from public.%I where id in (select id from security_ids)',t));
  perform pg_temp.empty_result(format('select child.* from public.%I child left join public.artifacts a on a.id=child.id',t));
 end loop;
 assert not exists(select 1 from public.activity_inputs where artifact_id is not null);
 assert not exists(select 1 from public.activity_outputs where artifact_id is not null);
 assert public.get_submitted_artifact_metadata((select id from security_ids where label='Personal Artifact')) is null;
 assert public.get_submitted_artifact_metadata('00000000-0000-4000-8000-000000999999') is null;
 assert not public.can_review_artifact_version((select id from security_ids where label='Personal Version'));
end $$;
set local role authenticated;
do $$declare actor integer;begin
 foreach actor in array array[6001,6003,6006,6007,6008] loop
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(actor::text,12,'0'),true);
  perform pg_temp.no_private_rows();
  perform pg_temp.denied(format('select public.approve_artifact(%L)',(select id from security_ids where label='Personal Submission')));
 end loop;
end $$;
\echo M8.15 AT-RLS-002 cross-Team / Personal exact-ID / reviewer boundary PASS

-- Revoke reviewer authority, preserving exact historical author identities.
reset role;
create temporary table review_history_before as select jsonb_agg(to_jsonb(r) order by id) data from public.review_actions r;
update public.role_assignments set status='inactive' where user_id='00000000-0000-4000-8000-000000006002';
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select pg_temp.no_private_rows();
select pg_temp.denied(format('select public.start_review(%L)',(select id from security_ids where label='Personal Submission')));
reset role;
do $$begin assert (select data from review_history_before)=(select jsonb_agg(to_jsonb(r) order by id) from public.review_actions r);end $$;
update public.role_assignments set status='active' where user_id='00000000-0000-4000-8000-000000006002';

-- Real workflow creates revision-requested, CURRENT and SUPERSEDED snapshots.
set local role authenticated;
select public.request_revision((select id from security_ids where label='Personal Submission'),'Preserve original review');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into security_ids select 'Next Submission',(public.submit_artifact((select id from security_ids where label='Personal Artifact'),(select id from security_ids where label='Future Version'),(select id from instances where label='Individual'))->>'id')::uuid;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.start_review((select id from security_ids where label='Next Submission'));
select public.approve_artifact((select id from security_ids where label='Next Submission'));
select public.approve_artifact((select id from security_ids where label='Team Submission'));
insert into security_ids select 'Personal Baseline',(public.set_project_baseline_item((select (payload->>'id')::uuid from logged_projects where label='Individual'),'CURRENT_PROBLEM_BANK',(select id from security_ids where label='Personal Artifact'),(select id from security_ids where label='Future Version'))->>'id')::uuid;
insert into security_ids select 'Team Baseline',(public.set_project_baseline_item((select (payload->>'id')::uuid from logged_projects where label='Team'),'CURRENT_PROBLEM_BANK',(select id from security_ids where label='Team Artifact'),(select id from security_ids where label='Team Version'))->>'id')::uuid;
do $$begin
 assert not exists(select 1 from public.project_baseline_items);
 assert not exists(select 1 from public.artifacts);
 assert not exists(select 1 from public.artifact_versions where id=(select id from security_ids where label='Future Version'));
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into security_ids select 'Reopen Version',(public.reopen_approved_artifact((select id from security_ids where label='Personal Artifact'))->'version'->>'id')::uuid;
insert into security_ids select 'Last Submission',(public.submit_artifact((select id from security_ids where label='Personal Artifact'),(select id from security_ids where label='Reopen Version'),(select id from instances where label='Individual'))->>'id')::uuid;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.start_review((select id from security_ids where label='Last Submission'));
select public.approve_artifact((select id from security_ids where label='Last Submission'));
insert into security_ids select 'New Baseline',(public.set_project_baseline_item((select (payload->>'id')::uuid from logged_projects where label='Individual'),'CURRENT_PROBLEM_BANK',(select id from security_ids where label='Personal Artifact'),(select id from security_ids where label='Reopen Version'))->>'id')::uuid;
select pg_temp.denied('insert into public.project_baseline_items default values');
select pg_temp.denied('update public.project_baseline_items set effective_to=null');
select pg_temp.denied('delete from public.project_baseline_items');
reset role;
insert into security_ids select 'Audit '||id::text,id from public.audit_events where event_type in ('REVISION_REQUESTED','ARTIFACT_APPROVED','ARTIFACT_REOPENED','BASELINE_UPDATED');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$declare attack text;begin
 assert (select status from public.artifact_versions where id=(select id from security_ids where label='Personal Version'))='REVISION_REQUESTED';
 assert (select status from public.artifact_versions where id=(select id from security_ids where label='Future Version'))='SUPERSEDED';
 assert (select status from public.artifact_versions where id=(select id from security_ids where label='Reopen Version'))='CURRENT';
 assert (select count(*) from public.project_baseline_items where project_id=(select (payload->>'id')::uuid from logged_projects where label='Individual'))=2;
 for attack in select command from m8_attacks loop perform pg_temp.denied(attack);end loop;
end $$;
\echo M8.15 AT-RLS-004 CURRENT/SUPERSEDED/revision history / approval forgery / baseline escalation PASS

-- Canonical removal revokes stale Project membership and all child reads. New
-- post-removal content and historical authorship are independently verified.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
do $$begin assert exists(select 1 from public.artifacts where id=(select id from security_ids where label='Team Artifact'));assert exists(select 1 from public.review_actions where id=(select id from security_ids where label='Team Action'));end $$;
reset role;
create temporary table team_history_before as select to_jsonb(a) artifact,to_jsonb(v) version from public.artifacts a join public.artifact_versions v on v.id=a.current_version_id where a.id=(select id from security_ids where label='Team Artifact');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006005',null);
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into security_ids select 'After Removal Artifact',(public.create_artifact((payload->>'id')::uuid,(payload->>'primary_workspace_id')::uuid,'PROBLEM_BANK','After removal',null,false,false)->>'artifactId')::uuid from logged_projects where label='Team';
-- Real I/O fixture rows exercise child policies independently of an empty table.
reset role;
insert into public.activity_inputs(activity_instance_id,input_type,artifact_id,required) select id,'artifact',(select id from security_ids where label='Team Artifact'),false from instances where label='Team';
insert into public.activity_outputs(activity_instance_id,output_type,artifact_id) select id,'artifact',(select id from security_ids where label='Team Artifact') from instances where label='Team';
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
select pg_temp.no_private_rows();
do $$declare attack text;begin for attack in select command from m8_attacks loop perform pg_temp.denied(attack);end loop;end $$;
reset role;
do $$begin
 assert exists(select 1 from public.team_memberships where user_id='00000000-0000-4000-8000-000000006005' and status='removed' and removed_by='00000000-0000-4000-8000-000000006002');
 assert (select artifact from team_history_before)=(select to_jsonb(a) from public.artifacts a where id=(select id from security_ids where label='Team Artifact'));
 assert (select version from team_history_before)=(select to_jsonb(v) from public.artifact_versions v where id=(select id from security_ids where label='Team Version'));
end $$;
\echo M8.15 AT-RLS-003 canonical removal / future content / stale membership / durable attribution PASS

-- Authorized archived history stays readable; archive does not share it.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select public.archive_artifact((select id from security_ids where label='Personal Artifact'));
select public.archive_artifact((select id from security_ids where label='Team Artifact'));
do $$begin
 assert (select count(*) from public.artifacts where status='ARCHIVED')=2;
 assert exists(select 1 from public.artifact_versions where id=(select id from security_ids where label='Future Version'));
 assert exists(select 1 from public.activity_inputs where artifact_id=(select id from security_ids where label='Team Artifact'));
 assert exists(select 1 from public.activity_outputs where artifact_id=(select id from security_ids where label='Team Artifact'));
end $$;
do $$declare actor integer;begin foreach actor in array array[6003,6005,6006,6007,6008] loop
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(actor::text,12,'0'),true);perform pg_temp.no_private_rows();end loop;end $$;

-- Anonymous denies actual SELECT and every mutation; all catalogued functions
-- are called with typed NULL arguments and must stop at EXECUTE permissions.
reset role;set local role anon;
do $$declare t text;attack text;p record;args text;begin
 foreach t in array array['artifacts','artifact_versions','artifact_object_links','submissions','feedback_items','review_actions','project_baseline_items'] loop perform pg_temp.denied(format('select * from public.%I',t));end loop;
 for attack in select command from m8_attacks loop perform pg_temp.denied(attack);end loop;
 for p in select proc.* from pg_proc proc join pg_namespace n on n.oid=proc.pronamespace join m8_function_inventory f on f.name=proc.proname where n.nspname='public' loop
  select string_agg('null::'||format_type(typ,null),',' order by ordinal) into args from unnest(p.proargtypes::oid[]) with ordinality arg(typ,ordinal);
  perform pg_temp.denied(format('select public.%I(%s)',p.proname,coalesce(args,'')));
 end loop;
end $$;
reset role;
rollback;
\echo M8.15 Artifact-scope AT-RLS-007 / target RLS / anonymous / catalog-grants / immutable audit PASS
