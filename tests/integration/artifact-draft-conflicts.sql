-- Appended to the existing canonical Artifact review fixture transaction.
reset role;
create temporary table draft_before as select to_jsonb(v) data from public.artifact_versions v;
do $$begin assert not exists(select 1 from public.artifact_versions where draft_revision<>0),'Initial Draft counters start at zero';end$$;
create temporary table draft_side_effects as select (select count(*) from public.change_log) logs,(select count(*) from public.audit_events) audits,(select count(*) from public.artifact_versions) versions;
create temporary table draft_resources_before as select jsonb_build_object('artifacts',(select jsonb_agg(to_jsonb(a) order by id) from public.artifacts a),'links',(select jsonb_agg(to_jsonb(l) order by id) from public.artifact_object_links l),'activities',(select jsonb_agg(to_jsonb(i) order by id) from public.activity_instances i),'baselines',(select jsonb_agg(to_jsonb(b) order by id) from public.project_baseline_items b)) data;
grant select on draft_before,draft_side_effects to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$declare vid uuid; saved jsonb; before jsonb;begin
 select (payload->>'initialVersionId')::uuid into vid from submitted_fixtures where label='Personal';
 select data into before from draft_before where data->>'id'=vid::text;
 assert (before->>'draft_revision')::int=0;
 saved:=public.update_artifact_draft(vid,0,'{"writer":"A"}','Saved',true);
 assert saved->>'draft_revision'='1';
 assert saved-'content_snapshot'-'change_summary'-'draft_revision'=before-'content_snapshot'-'change_summary'-'draft_revision';
 begin perform public.update_artifact_draft(vid,0,'{"writer":"B"}');raise exception 'Lost update';exception when unique_violation then null;end;
 begin perform public.update_artifact_draft(vid,0,'{"writer":"A"}','Competing summary',true);raise exception 'Field merge bypass';exception when unique_violation then null;end;
 assert (select content_snapshot from public.artifact_versions where id=vid)='{"writer":"A"}'::jsonb;
 assert (select change_summary from public.artifact_versions where id=vid)='Saved';
 -- Reload/retry uses the new token; identical saves still increment once.
 saved:=public.update_artifact_draft(vid,1,'{"writer":"B"}');assert saved->>'draft_revision'='2' and saved->>'change_summary'='Saved';
 saved:=public.update_artifact_draft(vid,2,'{"writer":"B"}',null,true);assert saved->>'draft_revision'='3' and saved->'change_summary'='null'::jsonb;
 begin perform public.update_artifact_draft(vid,-1,'{}');raise exception 'Negative token';exception when invalid_parameter_value then null;end;
 begin update public.artifact_versions set draft_revision=0 where id=vid;raise exception 'Client counter bypass';exception when insufficient_privilege then null;end;
 begin update public.artifact_versions set content_snapshot='{}' where id=vid;raise exception 'Client update bypass';exception when insufficient_privilege then null;end;
end$$;
-- Foreign Personal IDs and unknown IDs produce the same database denial.
do $$declare vid uuid;begin
 select (payload->>'initialVersionId')::uuid into vid from submitted_fixtures where label='Personal';
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
 begin perform public.update_artifact_draft(vid,3,'{}');raise exception 'Private Draft';exception when insufficient_privilege then null;end;
 begin perform public.update_artifact_draft('00000000-0000-4000-8000-000000999999',3,'{}');raise exception 'Unknown Draft';exception when insufficient_privilege then null;end;
end$$;
do $$declare n integer;vid uuid;begin
 foreach n in array array[6001,6002,6003,6006,6007,6008] loop
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(n::text,12,'0'),true);
  select (payload->>'initialVersionId')::uuid into vid from submitted_fixtures where label='Personal';
  begin perform public.update_artifact_draft(vid,3,'{}');raise exception 'Personal role bypass';exception when insufficient_privilege then null;end;
 end loop;
 foreach n in array array[6006,6007] loop
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(n::text,12,'0'),true);
  select (payload->>'initialVersionId')::uuid into vid from submitted_fixtures where label='Team';
  begin perform public.update_artifact_draft(vid,0,'{}');raise exception 'Foreign Team';exception when insufficient_privilege then null;end;
 end loop;
end$$;
reset role;
do $$begin
 assert (select data from draft_resources_before)=jsonb_build_object('artifacts',(select jsonb_agg(to_jsonb(a) order by id) from public.artifacts a),'links',(select jsonb_agg(to_jsonb(l) order by id) from public.artifact_object_links l),'activities',(select jsonb_agg(to_jsonb(i) order by id) from public.activity_instances i),'baselines',(select jsonb_agg(to_jsonb(b) order by id) from public.project_baseline_items b));
 assert (select count(*) from public.change_log)=(select logs from draft_side_effects);
 assert (select count(*) from public.audit_events)=(select audits from draft_side_effects);
 assert (select count(*) from public.artifact_versions)=(select versions from draft_side_effects);
 assert not has_table_privilege('authenticated','public.artifact_versions','UPDATE');
 assert not has_function_privilege('anon','public.update_artifact_draft(uuid,integer,jsonb,text,boolean)','EXECUTE');
 assert not has_function_privilege('service_role','public.update_artifact_draft(uuid,integer,jsonb,text,boolean)','EXECUTE');
end$$;
-- All non-Draft states retain their save counter and reject the operation.
create temporary table frozen_drafts(id uuid primary key);
insert into public.artifact_versions(artifact_id,version_number,status,content_snapshot,created_by,approved_by,approved_at,draft_revision)
 select (payload->>'artifactId')::uuid,100+n,s::public.artifact_version_status,'{"frozen":true}','00000000-0000-4000-8000-000000006004',
 case when s in ('APPROVED','CURRENT') then '00000000-0000-4000-8000-000000006002'::uuid end,
 case when s in ('APPROVED','CURRENT') then now() end,17
 from submitted_fixtures cross join unnest(array['SUBMITTED','UNDER_REVIEW','REVISION_REQUESTED','APPROVED','CURRENT','SUPERSEDED','ARCHIVED']) with ordinality x(s,n) where label='Sibling';
insert into frozen_drafts select id from public.artifact_versions where version_number>100;
grant select on frozen_drafts to authenticated;
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$declare vid uuid;begin for vid in select id from frozen_drafts loop
 begin perform public.update_artifact_draft(vid,17,'{}');raise exception 'Non-Draft save';exception when sqlstate '55000' then null;end;
 assert (select draft_revision from public.artifact_versions where id=vid)=17;
end loop;end$$;
reset role;
-- Overflow fails atomically rather than wrapping or losing the saved body.
insert into public.artifact_versions(artifact_id,version_number,status,content_snapshot,created_by,draft_revision)
 select (payload->>'artifactId')::uuid,200,'DRAFT','{"max":true}','00000000-0000-4000-8000-000000006004',2147483647 from submitted_fixtures where label='Sibling';
set local role authenticated;
do $$declare vid uuid;begin select id into vid from public.artifact_versions where version_number=200;
 begin perform public.update_artifact_draft(vid,2147483647,'{}');raise exception 'Overflow accepted';exception when numeric_value_out_of_range then null;end;
 assert (select draft_revision from public.artifact_versions where id=vid)=2147483647;
 assert (select content_snapshot from public.artifact_versions where id=vid)='{"max":true}'::jsonb;
end$$;
reset role;
-- Forced post-write failure must roll back content, summary and counter.
create function pg_temp.fail_draft_save() returns trigger language plpgsql as $$begin raise exception 'Forced save failure' using errcode='P0099';end$$;
create trigger draft_save_failure after update on public.artifact_versions for each row execute function pg_temp.fail_draft_save();
set local role authenticated;
do $$declare vid uuid;before jsonb;begin select (payload->>'initialVersionId')::uuid into vid from submitted_fixtures where label='Personal';
 select to_jsonb(v) into before from public.artifact_versions v where id=vid;
 begin perform public.update_artifact_draft(vid,3,'{"must":"rollback"}','Rollback',true);raise exception 'Failure missing';exception when sqlstate 'P0099' then null;end;
 assert (select to_jsonb(v) from public.artifact_versions v where id=vid)=before;
end$$;
reset role;drop trigger draft_save_failure on public.artifact_versions;
-- Removed Team editor cannot use a stale token or historical membership.
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006004');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin begin perform public.update_artifact_draft((select (payload->>'initialVersionId')::uuid from submitted_fixtures where label='Team'),0,'{}');raise exception 'Removed editor';exception when insufficient_privilege then null;end;end$$;
reset role;set local role anon;
do $$begin begin perform public.update_artifact_draft(null,0,'{}');raise exception 'Anonymous save';exception when insufficient_privilege then null;end;end$$;
reset role;
rollback;
\echo M8.20 stale/reload/identical-save/immutability/privacy/CAS PASS
