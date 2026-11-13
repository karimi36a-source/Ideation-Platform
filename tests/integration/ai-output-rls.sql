-- M14.22 uses canonical M14.2 fixtures; every change rolls back.
reset role;
create temporary table output_rls_before as select
 (select jsonb_agg(to_jsonb(o) order by id) from public.ai_outputs o) outputs,
 (select jsonb_agg(to_jsonb(r) order by id) from public.ai_context_references r) refs;
grant select on output_rls_before to authenticated;
-- Existing fixture Mentor has an actual Team membership; create a genuinely
-- role-only Mentor so this attack does not accidentally grant canonical scope.
insert into auth.users(id,email) values('00000000-0000-4000-8000-000000006020','m1422-role-only-mentor@example.test');
select public.provision_user_profile('00000000-0000-4000-8000-000000006020','active');
insert into public.role_assignments(user_id,role_id,organization_id,assigned_by)
 select '00000000-0000-4000-8000-000000006020',role_id,organization_id,assigned_by from public.role_assignments where user_id='00000000-0000-4000-8000-000000006008';
-- Project participation alone must never open another Personal or Team scope.
insert into public.project_memberships(project_id,user_id)
 select (p.payload->>'id')::uuid,u.id from logged_projects p cross join public.users u
 where p.label in ('Individual','Team') and u.id in ('00000000-0000-4000-8000-000000006001','00000000-0000-4000-8000-000000006002','00000000-0000-4000-8000-000000006003','00000000-0000-4000-8000-000000006006','00000000-0000-4000-8000-000000006007','00000000-0000-4000-8000-000000006020')
 on conflict do nothing;
insert into auth.users(id,email) values('00000000-0000-4000-8000-000000006019','m1422-peer@example.test');
select public.provision_user_profile('00000000-0000-4000-8000-000000006019','active');
insert into public.enrollments(cohort_id,user_id,enrollment_role,status) select id,'00000000-0000-4000-8000-000000006019','participant','active' from acceptance_cohorts where label='Test';
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.add_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006019','member');
insert into public.project_memberships(project_id,user_id) select (payload->>'id')::uuid,'00000000-0000-4000-8000-000000006019' from logged_projects where label='Team';
-- Owner and ordinary peer positive controls, with exact parent/ref IDs.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
set local role authenticated;
do $$begin
 assert exists(select 1 from public.ai_outputs where id=pg_temp.ctx_id('PersonalOutput'));
 assert exists(select 1 from public.ai_context_references where ai_output_id=pg_temp.ctx_id('PersonalOutput'));
 assert exists(select 1 from public.ai_outputs where id=pg_temp.ctx_id('TeamOutput'));
 assert exists(select 1 from public.ai_context_references where ai_output_id=pg_temp.ctx_id('TeamOutput'));
end$$;
reset role;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006019',true);
set local role authenticated;
do $$begin
 assert exists(select 1 from public.ai_outputs where id=pg_temp.ctx_id('TeamOutput'));
 assert exists(select 1 from public.ai_context_references where ai_output_id=pg_temp.ctx_id('TeamOutput'));
 assert not exists(select 1 from public.ai_outputs where id=pg_temp.ctx_id('PersonalOutput'));
 assert not exists(select 1 from public.ai_context_references where ai_output_id=pg_temp.ctx_id('PersonalOutput'));
end$$;
reset role;
do $$declare u text;begin
 foreach u in array array['00000000-0000-4000-8000-000000006001','00000000-0000-4000-8000-000000006002','00000000-0000-4000-8000-000000006003','00000000-0000-4000-8000-000000006006','00000000-0000-4000-8000-000000006007','00000000-0000-4000-8000-000000006020'] loop
  perform set_config('request.jwt.claim.sub',u,true);execute 'set local role authenticated';
  assert not exists(select 1 from public.ai_outputs),'Role/Project membership opened AI collection: '||u;
  assert not exists(select 1 from public.ai_outputs where id in(pg_temp.ctx_id('TeamOutput'),pg_temp.ctx_id('PersonalOutput')));
  assert not exists(select 1 from public.ai_context_references),'Role/Project membership opened provenance';
  assert not exists(select 1 from public.ai_context_references where id in(select (value->>'id')::uuid from output_rls_before cross join lateral jsonb_array_elements(refs)));
  assert not exists(select 1 from public.ai_outputs where id='ffffffff-ffff-4fff-8fff-ffffffffffff');
  assert not exists(select 1 from public.ai_context_references where id='ffffffff-ffff-4fff-8fff-ffffffffffff');
  execute 'reset role';
 end loop;
end$$;
-- First prove real browser grants deny every operation, then temporarily grant
-- DML inside this disposable transaction to prove restrictive RLS independently.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
set local role authenticated;
do $$declare t text;begin
 foreach t in array array['ai_outputs','ai_context_references'] loop
  perform pg_temp.ctx_bad(format('insert into public.%I default values',t));
  perform pg_temp.ctx_bad(format('update public.%I set id=id',t));
  perform pg_temp.ctx_bad(format('delete from public.%I',t));
 end loop;
end$$;
reset role;
grant insert,update,delete on public.ai_outputs,public.ai_context_references to authenticated;
set local role authenticated;
do $$declare col text;n bigint;begin
 foreach col in array array['id','requested_by','project_id','workspace_id','activity_instance_id','ai_role','task_type','prompt_text','response_text','output_type','verification_status','disposition','disposition_revision','model_provider_reference','created_at','metadata'] loop
  execute format('update public.ai_outputs set %I=%I where id=%L',col,col,pg_temp.ctx_id('TeamOutput'));get diagnostics n=row_count;assert n=0,'Output UPDATE policy bypass';
 end loop;
 foreach col in array array['id','ai_output_id','context_role','entity_type','entity_id','share_snapshot_id','permission_scope','included_snapshot_hash'] loop
  execute format('update public.ai_context_references set %I=%I',col,col);get diagnostics n=row_count;assert n=0,'Reference UPDATE policy bypass';
 end loop;
 update public.ai_outputs set disposition='CONVERTED_TO_PROJECT_OBJECT';get diagnostics n=row_count;assert n=0;
 update public.ai_outputs set response_text='forged',verification_status='VERIFIED_AGAINST_SOURCES';get diagnostics n=row_count;assert n=0;
 update public.ai_context_references set ai_output_id=pg_temp.ctx_id('PersonalOutput');get diagnostics n=row_count;assert n=0;
 delete from public.ai_outputs;get diagnostics n=row_count;assert n=0;
 delete from public.ai_context_references;get diagnostics n=row_count;assert n=0;
 perform pg_temp.ctx_bad('insert into public.ai_outputs select (jsonb_populate_record(null::public.ai_outputs,(select value||jsonb_build_object(''id'',gen_random_uuid()) from output_rls_before cross join lateral jsonb_array_elements(outputs) where value->>''id''='''||pg_temp.ctx_id('TeamOutput')||'''))).*');
 perform pg_temp.ctx_bad(format('select pg_temp.ctx_ref(%L,''PROJECT'',%L,''CURRENT_PROJECT'')',pg_temp.ctx_id('TeamOutput'),(select (payload->>'id')::uuid from logged_projects where label='Team')));
end$$;
reset role;
revoke insert,update,delete on public.ai_outputs,public.ai_context_references from authenticated;
do $$begin
 assert (select outputs from output_rls_before)=(select jsonb_agg(to_jsonb(o) order by id) from public.ai_outputs o);
 assert (select refs from output_rls_before)=(select jsonb_agg(to_jsonb(r) order by id) from public.ai_context_references r);
 assert exists(select 1 from pg_policies where schemaname='public' and tablename='ai_outputs' and policyname='ai_outputs_brainstorm_read_guard' and permissive='RESTRICTIVE');
 assert exists(select 1 from pg_policies where schemaname='public' and tablename='ai_context_references' and policyname='ai_context_references_parent_read');
 assert not has_table_privilege('authenticated','public.ai_outputs','INSERT,UPDATE,DELETE');
 assert not has_table_privilege('authenticated','public.ai_context_references','INSERT,UPDATE,DELETE');
end$$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006004','M14.22 former requester');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
set local role authenticated;
do $$begin
 assert not exists(select 1 from public.ai_outputs where id=pg_temp.ctx_id('TeamOutput'));
 assert not exists(select 1 from public.ai_context_references where ai_output_id=pg_temp.ctx_id('TeamOutput'));
 assert exists(select 1 from public.ai_outputs where id=pg_temp.ctx_id('PersonalOutput'));
 assert exists(select 1 from public.ai_context_references where ai_output_id=pg_temp.ctx_id('PersonalOutput'));
end$$;
reset role;
do $$begin
 assert (select outputs from output_rls_before)=(select jsonb_agg(to_jsonb(o) order by id) from public.ai_outputs o);
 assert (select refs from output_rls_before)=(select jsonb_agg(to_jsonb(r) order by id) from public.ai_context_references r);
end$$;
select 'M14.22 AI-output/reference RLS Personal/Team/current-membership/role-only/direct-ID/immutable/insert-update-delete/history PASS';
rollback;
