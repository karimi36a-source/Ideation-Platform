\set ON_ERROR_STOP on
begin;
-- Run against pristine migrations/seeds, before isolated domain fixture transactions.
create temporary table curriculum_seed_snapshot as
select 'organizations' as kind,to_jsonb(t) as value from public.organizations t
union all select 'programs',to_jsonb(t) from public.programs t
union all select 'curriculum_versions',to_jsonb(t) from public.curriculum_versions t
union all select 'session_definitions',to_jsonb(t) from public.session_definitions t
union all select 'activity_definitions',to_jsonb(t) from public.activity_definitions t
union all select 'activity_dependencies',to_jsonb(t) from public.activity_dependencies t;
select public.seed_initial_organization();select public.seed_professional_curriculum();
select public.seed_professional_sessions();select public.seed_professional_activity();
select public.seed_initial_organization();select public.seed_professional_curriculum();
select public.seed_professional_sessions();select public.seed_professional_activity();
do $$ declare version_id uuid; begin
 assert (select count(*) from public.organizations)=1,'only initial organization';
 assert (select count(*) from public.programs)=1,'no invented Workshop/Advanced Course';
 assert (select count(*) from public.curriculum_versions)=1,'only approved initial curriculum';
 select v.id into version_id from public.organizations o join public.programs p on p.organization_id=o.id
 join public.curriculum_versions v on v.program_id=p.id
 where o.name='FICI' and o.slug='fici' and p.name='Professional Course' and p.program_type='professional_course'
 and v.version_label='2026 v1' and v.status='approved' and p.current_curriculum_version_id=v.id;
 assert version_id is not null,'FICI -> Professional Course -> approved current 2026 v1';
 assert (select count(*) from public.session_definitions)=10,'exactly ten sessions';
 assert (select array_agg(session_number order by sequence) from public.session_definitions)=array[1,2,3,4,5,6,7,8,9,10],'number/order no gaps';
 assert (select array_agg(sequence order by sequence) from public.session_definitions)=array[1,2,3,4,5,6,7,8,9,10],'sequence no gaps';
 assert (select array_agg(title order by sequence) from public.session_definitions)=array[
 'Think Like an Inventor','The SCAMPER Framework','SCAMPER Applied Workshop','Brainstorming & Problem Storming',
 'Idea Evaluation & Voting','Affinity Diagram','Mind Mapping','Patent Document & Reading Basics',
 'Patent Search & Comparative Analysis','AI-Assisted Invention Refinement'],'approved exact titles';
 assert not exists(select 1 from public.session_definitions where curriculum_version_id<>version_id or status<>'active'),'all sessions approved parent and active';
 assert (select count(*) from public.activity_definitions)=1,'no fabricated activities';
 assert exists(select 1 from public.activity_definitions a join public.session_definitions s on s.id=a.session_definition_id
 where s.curriculum_version_id=version_id and s.session_number=2 and a.name='SCAMPER Example Set' and a.method_type='scamper' and a.status='active'),'approved minimum activity';
 assert not exists(select 1 from public.activity_dependencies),'no fabricated prerequisites for absent activities';
 -- Required workflow edges become testable as definition pairs when both endpoints exist.
 assert not exists(select 1 from (values(4,5),(6,7),(8,9),(9,10)) edge(source,target)
 where exists(select 1 from public.activity_definitions a join public.session_definitions s on s.id=a.session_definition_id where s.curriculum_version_id=version_id and s.session_number=edge.source)
 and exists(select 1 from public.activity_definitions a join public.session_definitions s on s.id=a.session_definition_id where s.curriculum_version_id=version_id and s.session_number=edge.target)
 and not exists(select 1 from public.activity_dependencies d join public.activity_definitions a on a.id=d.activity_definition_id
 join public.session_definitions s on s.id=a.session_definition_id join public.activity_definitions r on r.id=d.required_activity_definition_id
 join public.session_definitions rs on rs.id=r.session_definition_id where s.curriculum_version_id=version_id and rs.curriculum_version_id=version_id and s.session_number=edge.target and rs.session_number=edge.source)), 'supported workflow edges preserved';
end $$;
create temporary table curriculum_seed_after as
select 'organizations' as kind,to_jsonb(t) as value from public.organizations t
union all select 'programs',to_jsonb(t) from public.programs t
union all select 'curriculum_versions',to_jsonb(t) from public.curriculum_versions t
union all select 'session_definitions',to_jsonb(t) from public.session_definitions t
union all select 'activity_definitions',to_jsonb(t) from public.activity_definitions t
union all select 'activity_dependencies',to_jsonb(t) from public.activity_dependencies t;
do $$ begin
 assert not exists((select * from curriculum_seed_snapshot except all select * from curriculum_seed_after)
 union all (select * from curriculum_seed_after except all select * from curriculum_seed_snapshot)), 'seed retries preserve every field and row';
end $$;
rollback;
\echo M3.9 Professional Course parent chain, exact sessions, minimal activity, deferred dependencies and full seed idempotency PASS

