\set ON_ERROR_STOP on
begin;
-- Final M6 metadata/provenance audit uses isolated identities and real RPCs.
insert into auth.users(id,email) values
 ('00000000-0000-4000-8000-000000006004','m6-final-owner@example.test'),
 ('00000000-0000-4000-8000-000000006005','m6-final-other@example.test');
select public.provision_user_profile(id,'active') from auth.users where email like 'm6-final-%@example.test';
create temporary table final_project(payload jsonb);grant select,insert,update on final_project to authenticated;
create temporary table final_object(payload jsonb);grant select,insert on final_object to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select public.create_personal_workspace();
insert into final_project select public.create_development_project('M6.17 audit Project','individual',id) from public.workspaces where workspace_type='PERSONAL';
insert into final_object select public.create_development_object((payload->>'id')::uuid,(payload->>'primary_workspace_id')::uuid,'PROBLEM','Provenance audit','Source-derived Problem','Patent','{"role":"ADMIN","cohort":"untrusted metadata"}') from final_project;
select public.write_problem_details((select (payload->>'id')::uuid from final_object),'{}',true);
-- Stage is development prose, independent of educational session execution.
update final_project set payload=public.update_project_metadata((payload->>'id')::uuid,'{"current_stage":"Prototype evaluation beyond course sessions"}');
do $$declare p uuid;o uuid;begin
 select (payload->>'id')::uuid into p from final_project;select (payload->>'id')::uuid into o from final_object;
 assert public.can_read_development_project(p),'owner still authorized after stage update';
 assert exists(select 1 from public.development_objects where id=o and created_by=auth.uid() and origin_type='Patent'),'creator distinct from provenance';
 assert public.update_project_metadata(p,'{"current_stage":"Prototype evaluation beyond course sessions"}')=(select payload from final_project),'no-op stage preserves canonical metadata';
 assert (select count(*) from public.change_log where project_id=p and change_type='PROJECT_STAGE_CHANGED')=1,'no-op creates no second stage event';
end $$;
reset role;
-- Trusted fixture values exercise text representation only; no product vocabulary.
update public.development_projects set confidentiality_level='test-only unrestricted label' where id=(select (payload->>'id')::uuid from final_project);
set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006005',true);
do $$declare p uuid;o uuid;begin
 select (payload->>'id')::uuid into p from final_project;select (payload->>'id')::uuid into o from final_object;
 assert not public.can_read_development_project(p),'stage/confidentiality do not authorize outsider';
 assert not exists(select 1 from public.development_projects where id=p),'metadata grants no private row';
 assert not exists(select 1 from public.development_objects where id=o),'origin/role metadata grant no Object access';
 assert not exists(select 1 from public.problem_details where development_object_id=o),'typed details stay private';
 assert not exists(select 1 from public.change_log where project_id=p),'metadata grants no history';
 begin perform public.update_project_metadata(p,'{"current_stage":"ADMIN"}');raise exception 'outsider stage spoof';exception when insufficient_privilege then null;end;
 begin perform public.update_development_object(o,'{"metadata":{"role":"ADMIN"}}');raise exception 'outsider origin spoof';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$declare p uuid;begin
 select (payload->>'id')::uuid into p from final_project;
 assert public.can_read_development_project(p),'owner retained despite arbitrary confidentiality label';
 begin perform public.update_project_metadata(p,'{"confidentiality_level":"public"}');raise exception 'unsupported confidentiality edit';exception when invalid_parameter_value then null;end;
end $$;
reset role;
create temporary table archive_history as select 'objects' t,to_jsonb(o) data from public.development_objects o
 union all select 'details',to_jsonb(d) from public.problem_details d;
set local role authenticated;
update final_project set payload=public.archive_development_project((payload->>'id')::uuid);
do $$declare p uuid;begin
 select (payload->>'id')::uuid into p from final_project;
 assert public.archive_development_project(p)=(select payload from final_project),'archive retry stable';
 assert not public.can_read_development_project(p),'archive blocks normal read';
 begin perform public.update_development_object((select (payload->>'id')::uuid from final_object),'{"title":"Archived write"}');raise exception 'archived parent write';exception when insufficient_privilege then null;end;
end $$;
reset role;
do $$declare tab text;f record;n integer:=0;begin
 assert (select count(*) from public.change_log where project_id=(select (payload->>'id')::uuid from final_project) and change_type='PROJECT_ARCHIVED')=1,'exactly one archive event';
 assert (select to_jsonb(o) from public.development_objects o where id=(select (payload->>'id')::uuid from final_object))=(select data from archive_history where t='objects'),'Object physically preserved';
 assert (select to_jsonb(d) from public.problem_details d where development_object_id=(select (payload->>'id')::uuid from final_object))=(select data from archive_history where t='details'),'typed history preserved';
 assert (select count(*) from public.development_projects)=1,'no ownership conversion or clone';
 assert (select count(*) from public.development_objects)=1,'no context clone';
 assert (select count(*) from public.project_memberships)=0,'owner needs no automatic participation';
 assert (select atttypid='text'::regtype from pg_attribute where attrelid='public.development_projects'::regclass and attname='current_stage'),'stage not curriculum enum';
 assert (select atttypid='text'::regtype from pg_attribute where attrelid='public.development_projects'::regclass and attname='confidentiality_level'),'no permanent confidentiality enum';
 foreach tab in array array['development_projects','project_memberships','project_program_links','development_objects','problem_details','idea_details','development_object_relationships','change_log'] loop
  assert (select relrowsecurity from pg_class where oid=('public.'||tab)::regclass),'RLS required';
  assert not has_table_privilege('authenticated','public.'||tab,'INSERT,UPDATE,DELETE,TRUNCATE') and not has_any_column_privilege('authenticated','public.'||tab,'INSERT,UPDATE'),'no mutation grant';
  assert not has_table_privilege('anon','public.'||tab,'SELECT,INSERT,UPDATE,DELETE'),'no anonymous grant';
 end loop;
 for f in select x.oid,x.proname,x.proconfig,x.proowner,x.proargnames from pg_proc x where x.pronamespace='public'::regnamespace and x.prosecdef and x.proname in
 ('can_read_development_project','has_active_project_membership','can_read_project_program_link','require_development_project_write','require_development_object_write','create_development_project','get_development_project_metadata_for_edit','update_project_metadata','archive_development_project','link_project_to_program','create_development_object','update_development_object','archive_development_object','write_problem_details','write_idea_details','relate_development_objects','unlink_development_objects','append_project_change') loop
  n:=n+1;
  assert f.proconfig=array['search_path=""'],'fixed definer search_path';
  assert not has_function_privilege('anon',f.oid,'EXECUTE') and not has_function_privilege('service_role',f.oid,'EXECUTE'),'restricted execution';
  assert not exists(select 1 from pg_roles where oid=f.proowner and rolname in ('anon','authenticated','service_role')),'trusted definer owner';
  assert not (coalesce(f.proargnames,array[]::text[]) && array['actor','actor_id','changed_by','created_by','user_id']),'no actor override';
  if f.proname in ('require_development_project_write','require_development_object_write','append_project_change') then assert not has_function_privilege('authenticated',f.oid,'EXECUTE'),'private writer';end if;
 end loop;
 assert n=18,'complete M6 definer inventory';
 assert not exists(select 1 from public.activity_instances) and not exists(select 1 from public.activity_participants) and to_regclass('public.project_baselines') is null,'no M7+ schema';
end $$;
rollback;
\echo M6.17 final metadata/provenance/archive/history/grant/definer/scope audit PASS
