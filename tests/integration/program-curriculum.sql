\set ON_ERROR_STOP on
begin;
create temporary table seeded_program as select * from public.programs where code='PROFESSIONAL_COURSE';
create temporary table seeded_version as select * from public.curriculum_versions where version_label='2026 v1';
select public.seed_professional_curriculum();select public.seed_professional_curriculum();
do $$ begin
 assert (select count(*) from public.programs)=1, 'only Professional Course seed';
 assert (select p.organization_id=o.id and p.program_type='professional_course' and p.name='Professional Course' from public.programs p join public.organizations o on o.slug='fici'), 'Professional Course belongs to FICI';
 assert (select v.program_id=p.id and v.status='approved' and p.current_curriculum_version_id=v.id from public.curriculum_versions v join public.programs p on p.id=v.program_id where v.version_label='2026 v1'), 'approved current 2026 v1';
 assert not exists(select * from public.programs except select * from seeded_program), 'seed idempotent program';
 assert not exists(select * from public.curriculum_versions except select * from seeded_version), 'seed idempotent curriculum';
 begin insert into public.curriculum_versions(program_id,version_label) values('00000000-0000-4000-8000-000000000601','2026 v1');raise exception 'duplicate label';exception when unique_violation then null;end;
 begin update public.curriculum_versions set notes='changed' where version_label='2026 v1';raise exception 'approved mutable';exception when check_violation then null;end;
end $$;
insert into auth.users(id,email) values('00000000-0000-4000-8000-000000000603','program-admin@example.test');
select public.provision_user_profile('00000000-0000-4000-8000-000000000603','active');select public.provision_user_profile('00000000-0000-4000-8000-000000000001','active');
insert into public.role_assignments(user_id,role_id,organization_id,assigned_by) values
 ('00000000-0000-4000-8000-000000000603','00000000-0000-4000-8000-000000000101','00000000-0000-4000-8000-000000000501','00000000-0000-4000-8000-000000000603'),
 ('00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000104','00000000-0000-4000-8000-000000000501','00000000-0000-4000-8000-000000000603');
insert into public.organizations(id,name,slug) values('00000000-0000-4000-8000-000000000604','Other','program-other');
insert into public.programs(id,organization_id,name,code,program_type) values('00000000-0000-4000-8000-000000000605','00000000-0000-4000-8000-000000000604','Other fixture','FIXTURE','professional_course');
insert into public.curriculum_versions(id,program_id,version_label,status) values('00000000-0000-4000-8000-000000000606','00000000-0000-4000-8000-000000000605','Other approved','approved');
-- Transaction-only historical reference fixture, not a cohort/product domain.
create schema m32_history_fixture;
create table m32_history_fixture.reference(id integer primary key,version_id uuid references public.curriculum_versions(id) on delete restrict);
insert into m32_history_fixture.reference values(1,'00000000-0000-4000-8000-000000000602');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',true);
do $$ begin
 assert public.has_active_role('STUDENT'), 'real Student fixture';
 assert (select count(*) from public.programs)=0 and (select count(*) from public.curriculum_versions)=0, 'ordinary/Student definition read denied';
 begin perform public.manage_program('00000000-0000-4000-8000-000000000501',null,'Attack','ATTACK','','professional_course','active');raise exception 'ordinary create';exception when insufficient_privilege then null;end;
 begin perform public.manage_curriculum('00000000-0000-4000-8000-000000000601',null,'Attack',null,null,'');raise exception 'ordinary curriculum';exception when insufficient_privilege then null;end;
 begin update public.programs set name='Attack';raise exception 'direct mutation';exception when insufficient_privilege then null;end;
 begin update public.curriculum_versions set notes='Attack';raise exception 'direct version mutation';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000603',true);
do $$ declare v uuid; r jsonb; begin
 assert (select count(*) from public.programs)=1, 'Admin exact parent read';
 r:=public.manage_program('00000000-0000-4000-8000-000000000501','00000000-0000-4000-8000-000000000601','Professional Course','PROFESSIONAL_COURSE','Updated description','professional_course','active');assert r->>'description'='Updated description', 'Admin program edit';
 r:=public.manage_curriculum('00000000-0000-4000-8000-000000000601',null,'2027 v2',null,null,'Draft');v:=(r->>'id')::uuid;
 r:=public.manage_curriculum('00000000-0000-4000-8000-000000000601',v,'2027 v2',null,null,'Edited draft');assert r->>'notes'='Edited draft', 'draft edit';
 begin perform public.set_current_curriculum('00000000-0000-4000-8000-000000000601',v);raise exception 'draft current';exception when foreign_key_violation then null;end;
 perform public.transition_curriculum(v,'approved');
 perform public.set_current_curriculum('00000000-0000-4000-8000-000000000601',v);
 begin perform public.manage_curriculum('00000000-0000-4000-8000-000000000601',v,'2027 v2',null,null,'Attack');raise exception 'approved edit';exception when insufficient_privilege then null;end;
 begin perform public.transition_curriculum(v,'retired');raise exception 'retired current';exception when foreign_key_violation then null;end;
 begin perform public.set_current_curriculum('00000000-0000-4000-8000-000000000601','00000000-0000-4000-8000-000000000606');raise exception 'cross program pointer';exception when foreign_key_violation then null;end;
 begin perform public.manage_curriculum('00000000-0000-4000-8000-000000000605',null,'Attack',null,null,'');raise exception 'other organization';exception when insufficient_privilege then null;end;
 begin perform public.manage_program('00000000-0000-4000-8000-000000000604',null,'Attack','ATTACK','','professional_course','active');raise exception 'unrelated organization admin';exception when insufficient_privilege then null;end;
 perform public.transition_curriculum('00000000-0000-4000-8000-000000000602','retired');
end $$;
reset role;
select public.seed_professional_curriculum();
do $$ begin
 assert (select version_id='00000000-0000-4000-8000-000000000602' from m32_history_fixture.reference), 'history retains v1';
 assert (select v.status='retired' and v.version_label='2026 v1' and v.notes=s.notes from public.curriculum_versions v join seeded_version s on s.id=v.id), 'retired definition preserved';
 assert (select v.version_label='2027 v2' from public.programs p join public.curriculum_versions v on v.id=p.current_curriculum_version_id where p.code='PROFESSIONAL_COURSE'), 'seed retry does not reset pointer';
 begin delete from public.curriculum_versions where id='00000000-0000-4000-8000-000000000602';raise exception 'deleted historical version';exception when check_violation then null;end;
 begin update public.curriculum_versions set status='draft' where id='00000000-0000-4000-8000-000000000602';raise exception 'retired mutated';exception when check_violation then null;end;
 assert (select count(*) from pg_class where oid in ('public.programs'::regclass,'public.curriculum_versions'::regclass) and relrowsecurity)=2, 'RLS flags';
 assert not has_function_privilege('anon','public.manage_curriculum(uuid,uuid,text,timestamptz,timestamptz,text)','EXECUTE'), 'anonymous command denied';
 assert not has_function_privilege('service_role','public.manage_curriculum(uuid,uuid,text,timestamptz,timestamptz,text)','EXECUTE'), 'service key not product Admin';
 assert not has_function_privilege('authenticated','public.seed_professional_curriculum()','EXECUTE'), 'owner-only seed';
end $$;
rollback;
\echo Program curriculum seed, approved immutability, current pointer, history and exact-org Admin RLS PASS

