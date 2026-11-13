-- Runner prepends canonical approval fixture through first approval (V1 CURRENT).
create temporary table baseline_targets as
 select a.project_id,a.id artifact_id,a.current_version_id version_id from public.artifacts a
 where a.id=(select (payload->>'artifactId')::uuid from submitted_fixtures where label='Personal');
grant select on baseline_targets to authenticated,anon;
create temporary table baseline_results(label text primary key,data jsonb);grant select,insert on baseline_results to authenticated;
create temporary table baseline_content_before as select pg_temp.approval_state()-'audit' data;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
insert into baseline_results select 'V1',public.set_project_baseline_item(project_id,' CURRENT_INVENTION_CONCEPT ',artifact_id,version_id) from baseline_targets;
insert into baseline_results select 'retry',public.set_project_baseline_item(project_id,'CURRENT_INVENTION_CONCEPT',artifact_id,version_id) from baseline_targets;
-- Narrow setter has no general Personal read/edit privileges after setting.
do $$begin
 if exists(select 1 from public.project_baseline_items) or exists(select 1 from public.development_projects where id=(select project_id from baseline_targets))
 or exists(select 1 from public.workspaces where workspace_type='PERSONAL')
 then raise exception 'Baseline setter leaked general Personal access';end if;
 if public.can_read_development_project((select project_id from baseline_targets)) then raise exception 'Setter gained Project read';end if;
end$$;
reset role;
do $$begin
 if (select data from baseline_results where label='V1') is distinct from (select data from baseline_results where label='retry') then raise exception 'Retry rewrote baseline';end if;
 if (select count(*) from public.project_baseline_items)<>1 or (select count(*) from public.audit_events where event_type='BASELINE_UPDATED')<>1 then raise exception 'Retry duplicates';end if;
 if (select data from baseline_content_before) is distinct from pg_temp.approval_state()-'audit' then raise exception 'Baseline mutated content/review';end if;
end$$;

-- Draft creation/reopen and approval must never automatically replace baseline.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select public.reopen_approved_artifact((select artifact_id from baseline_targets));
insert into review_fixtures select 'Replacement',public.submit_artifact((payload->>'artifact_id')::uuid,(payload->>'id')::uuid,(select id from instances where label='Individual')) from review_fixtures where label='Future';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.start_review((select (payload->>'id')::uuid from review_fixtures where label='Replacement'));
select public.approve_artifact((select (payload->>'id')::uuid from review_fixtures where label='Replacement'));
select public.approve_artifact((select (payload->>'id')::uuid from review_fixtures where label='Team'));
reset role;
do $$begin
 if (select count(*) from public.project_baseline_items)<>1 or (select artifact_version_id from public.project_baseline_items)<>(select version_id from baseline_targets) then raise exception 'Approval/reopen auto-updated baseline';end if;
end$$;
update baseline_targets set version_id=(select current_version_id from public.artifacts where id=artifact_id);
-- Failure after close, after insert, and after audit restores the whole boundary.
create function pg_temp.fail_baseline() returns trigger language plpgsql as $$begin raise exception 'Injected baseline failure' using errcode='P0002';end$$;
do $$declare point text;before_state jsonb;t record;begin
 select * into t from baseline_targets;
 foreach point in array array['close','insert','audit'] loop
 select jsonb_build_object('rows',(select jsonb_agg(to_jsonb(b) order by id) from public.project_baseline_items b),'audit',(select jsonb_agg(to_jsonb(e) order by id) from public.audit_events e)) into before_state;
 if point='close' then create trigger baseline_failure after update on public.project_baseline_items for each row execute function pg_temp.fail_baseline();
 elsif point='insert' then create trigger baseline_failure after insert on public.project_baseline_items for each row execute function pg_temp.fail_baseline();
 else create trigger baseline_failure after insert on public.audit_events for each row execute function pg_temp.fail_baseline();end if;
 begin perform public.set_project_baseline_item(t.project_id,'CURRENT_INVENTION_CONCEPT',t.artifact_id,t.version_id);raise exception 'Failure injection bypass';exception when no_data_found then null;end;
 if before_state is distinct from jsonb_build_object('rows',(select jsonb_agg(to_jsonb(b) order by id) from public.project_baseline_items b),'audit',(select jsonb_agg(to_jsonb(e) order by id) from public.audit_events e)) then raise exception 'Partial baseline replacement';end if;
 if point='audit' then drop trigger baseline_failure on public.audit_events;else drop trigger baseline_failure on public.project_baseline_items;end if;
 end loop;
end$$;
set local role authenticated;
insert into baseline_results select 'V2',public.set_project_baseline_item(project_id,'CURRENT_INVENTION_CONCEPT',artifact_id,version_id) from baseline_targets;
-- Team Master has no participant membership but may set exact approved baseline.
insert into baseline_results select 'Team',public.set_project_baseline_item(a.project_id,'CURRENT_INVENTION_CONCEPT',a.id,a.current_version_id) from public.artifacts a where false;
reset role;
do $$declare a public.artifacts;begin
 select * into a from public.artifacts where id=(select (payload->>'artifactId')::uuid from submitted_fixtures where label='Team');
 perform public.set_project_baseline_item(a.project_id,'CURRENT_INVENTION_CONCEPT',a.id,a.current_version_id);
 if exists(select 1 from public.team_memberships where team_id=(select owner_team_id from public.development_projects where id=a.project_id) and user_id=auth.uid() and status='active') then raise exception 'Fixture Master is a Team member';end if;
end$$;

-- Third current Version from real create/submit/review/approval workflow.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into review_fixtures select 'ThirdDraft',public.create_artifact_version(artifact_id,'{"third":true}','Third') from baseline_targets;
insert into review_fixtures select 'Third',public.submit_artifact((payload->>'artifact_id')::uuid,(payload->>'id')::uuid,(select id from instances where label='Individual')) from review_fixtures where label='ThirdDraft';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.start_review((select (payload->>'id')::uuid from review_fixtures where label='Third'));
select public.approve_artifact((select (payload->>'id')::uuid from review_fixtures where label='Third'));
reset role;
do $$begin if (select count(*) from public.project_baseline_items where project_id=(select project_id from baseline_targets))<>2 then raise exception 'Third approval auto-update';end if;end$$;
update baseline_targets set version_id=(select current_version_id from public.artifacts where id=artifact_id);
set local role authenticated;
insert into baseline_results select 'V3',public.set_project_baseline_item(project_id,'CURRENT_INVENTION_CONCEPT',artifact_id,version_id) from baseline_targets;
reset role;
do $$declare rows integer;begin
 select count(*) into rows from public.project_baseline_items where project_id=(select project_id from baseline_targets);if rows<>3 then raise exception 'Missing baseline history';end if;
 if (select count(*) from public.project_baseline_items where project_id=(select project_id from baseline_targets) and effective_to is null)<>1 then raise exception 'Effective cardinality';end if;
 if exists(select 1 from (select effective_to,lead(effective_from) over(order by effective_from,id) next_stamp from public.project_baseline_items where project_id=(select project_id from baseline_targets)) b where next_stamp is not null and effective_to is distinct from next_stamp) then raise exception 'Historical boundary mismatch';end if;
 if exists(select 1 from public.audit_events where event_type='BASELINE_UPDATED' and (metadata<>'{}' or actor_user_id<>'00000000-0000-4000-8000-000000006002')) then raise exception 'Unsafe audit';end if;
 begin delete from public.project_baseline_items;raise exception 'History deleted';exception when check_violation then null;end;
 begin update public.project_baseline_items set artifact_version_id=gen_random_uuid();raise exception 'History overwritten';exception when check_violation then null;end;
 begin insert into public.project_baseline_items select gen_random_uuid(),project_id,baseline_type,artifact_id,artifact_version_id,effective_from,null,set_by from public.project_baseline_items where effective_to is null limit 1;raise exception 'Duplicate effective';exception when unique_violation then null;end;
 begin insert into public.project_baseline_items select gen_random_uuid(),gen_random_uuid(),'FOREIGN',artifact_id,artifact_version_id,clock_timestamp(),null,set_by from public.project_baseline_items limit 1;raise exception 'Cross Project';exception when foreign_key_violation then null;end;
 begin insert into public.project_baseline_items select gen_random_uuid(),project_id,'FOREIGN_VERSION',artifact_id,gen_random_uuid(),clock_timestamp(),null,set_by from public.project_baseline_items limit 1;raise exception 'Foreign Version';exception when foreign_key_violation then null;end;
end$$;

-- All unapproved statuses and relation/context/archive corruptions fail closed.
-- Flush coherent approval transitions before trusted fixture-only trigger DDL.
set constraints all immediate;
set constraints all deferred;
do $$declare scenario text;t record;begin
 select * into t from baseline_targets;
 foreach scenario in array array['DRAFT','SUBMITTED','UNDER_REVIEW','REVISION_REQUESTED','APPROVED','SUPERSEDED','ARCHIVED','pointer','approval','project','artifact','context','inactive','future','expired','scope'] loop
 begin
 if scenario in ('DRAFT','SUBMITTED','UNDER_REVIEW','REVISION_REQUESTED','APPROVED','SUPERSEDED','ARCHIVED','approval') then
  alter table public.artifact_versions disable trigger user;
  if scenario='approval' then update public.artifact_versions set approved_by=null,approved_at=null where id=t.version_id;
  else update public.artifact_versions set status=scenario::public.artifact_version_status where id=t.version_id;end if;
  alter table public.artifact_versions enable trigger user;
 elsif scenario='pointer' then update public.artifacts set current_version_id=null where id=t.artifact_id;
 elsif scenario='project' then update public.development_projects set status='archived',archived_at=clock_timestamp() where id=t.project_id;
 elsif scenario='artifact' then update public.artifacts set status='ARCHIVED',archived_at=clock_timestamp() where id=t.artifact_id;
 elsif scenario='context' then update public.submissions set status='UNDER_REVIEW' where artifact_version_id=t.version_id;
 elsif scenario='inactive' then update public.role_assignments set status='inactive' where user_id=auth.uid();
 elsif scenario='future' then update public.role_assignments set starts_at=now()+interval '1 day' where user_id=auth.uid();
 elsif scenario='expired' then update public.role_assignments set starts_at=now()-interval '2 days',ends_at=now()-interval '1 day' where user_id=auth.uid();
 else update public.role_assignments set cohort_id=(select id from acceptance_cohorts where label='Unrelated') where user_id=auth.uid();end if;
 begin perform public.set_project_baseline_item(t.project_id,'INVALID',t.artifact_id,t.version_id);raise exception 'Invalid baseline accepted: %',scenario;exception when insufficient_privilege then null;end;
 raise exception 'Undo fixture' using errcode='P0002';exception when no_data_found or check_violation then null;end;
 end loop;
 begin perform public.set_project_baseline_item(gen_random_uuid(),'CURRENT_INVENTION_CONCEPT',t.artifact_id,t.version_id);raise exception 'Foreign Project command';exception when insufficient_privilege then null;end;
 begin perform public.set_project_baseline_item(t.project_id,'CURRENT_INVENTION_CONCEPT',t.artifact_id,gen_random_uuid());raise exception 'Foreign Version command';exception when insufficient_privilege then null;end;
end$$;

-- Unauthorized exact-ID reads and ordinary mutation attacks, including spoofed
-- actor fields, are tested at PostgreSQL, independently of application helpers.
set local role authenticated;
do $$declare n integer;t record;begin
 select * into t from baseline_targets;
 foreach n in array array[6001,6003,6004,6005,6006,6007,6008] loop
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-'||lpad(n::text,12,'0'),true);
 begin perform public.set_project_baseline_item(t.project_id,'CURRENT_INVENTION_CONCEPT',t.artifact_id,t.version_id);raise exception 'Unauthorized setter';exception when insufficient_privilege then null;end;
 if n not in (6004) and exists(select 1 from public.project_baseline_items where project_id=t.project_id) then raise exception 'Private baseline leaked';end if;
 begin insert into public.project_baseline_items(project_id,baseline_type,artifact_id,artifact_version_id,set_by) values(t.project_id,'SPOOF',t.artifact_id,t.version_id,auth.uid());raise exception 'Client insert';exception when insufficient_privilege then null;end;
 begin update public.project_baseline_items set effective_to=null;raise exception 'Client update/reactivation';exception when insufficient_privilege then null;end;
 begin delete from public.project_baseline_items;raise exception 'Client delete';exception when insufficient_privilege then null;end;
 begin perform public.baseline_approval_context(t.project_id,t.artifact_id,t.version_id);raise exception 'Private helper exposed';exception when insufficient_privilege then null;end;
 end loop;
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
 if (select count(*) from public.project_baseline_items where project_id=t.project_id)<>3 then raise exception 'Owner history unavailable';end if;
end$$;
reset role;
select set_config('request.jwt.claim.sub','',true);
set local role anon;
do $$declare t record;begin select * into t from baseline_targets;
 begin perform public.set_project_baseline_item(t.project_id,'CURRENT_INVENTION_CONCEPT',t.artifact_id,t.version_id);raise exception 'Anonymous RPC';exception when insufficient_privilege then null;end;
 begin perform 1 from public.project_baseline_items;raise exception 'Anonymous read';exception when insufficient_privilege then null;end;
end$$;
reset role;

-- Trusted Primary Master reassignment changes command authority, not history.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006001',true);
select public.assign_master_to_cohort((select id from acceptance_cohorts where label='Test'),'00000000-0000-4000-8000-000000006003');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
do $$declare t record;begin select * into t from baseline_targets;
 begin perform public.set_project_baseline_item(t.project_id,'NEW_DIRECTION',t.artifact_id,t.version_id);raise exception 'Former Master allowed';exception when insufficient_privilege then null;end;end$$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006003',true);
select public.set_project_baseline_item(project_id,'NEW_DIRECTION',artifact_id,version_id) from baseline_targets;
do $$begin if not exists(select 1 from public.artifact_versions where id=(select version_id from baseline_targets) and approved_by='00000000-0000-4000-8000-000000006002') then raise exception 'Historical reviewer changed';end if;end$$;
select 'M8.13 baseline history / exact approval authority / privacy / rollback / no auto-update PASS';
rollback;
