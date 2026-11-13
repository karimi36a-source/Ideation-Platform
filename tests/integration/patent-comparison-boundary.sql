-- M12.17: comparison is DEFERRED — SHOULD-HAVE; catalog verification only.
begin;
do $$declare writers text[];begin
 assert not exists(select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname not in ('pg_catalog','information_schema') and c.relname='patent_comparisons'),'No comparison persistence';
 assert not exists(select 1 from public.ai_outputs),'No automatic AI generation/persistence from Patent research';
 assert not exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in ('public','private') and p.proname ~* '(compare.*patent|patent.*compar|run_ai_task|novelty_score|patentability_score)'),'No comparison, AI or legal-scoring RPC';
 select array_agg(n.nspname||'.'||p.proname order by p.proname) into writers from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in ('public','private') and p.prokind='f' and p.prosrc ~* 'insert\s+into\s+(public\.)?"?patent_records"?\s*\(';
 assert writers=array['public.create_patent_record'],'Only the explicit human source-creation RPC writes Patent Records';
 select array_agg(n.nspname||'.'||p.proname order by p.proname) into writers from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in ('public','private') and p.prokind='f' and p.prosrc ~* 'insert\s+into\s+(public\.)?"?evidence"?\s*\(';
 assert writers=array['public.create_evidence','public.link_patent_to_evidence'],'Only explicit source-backed operations create Evidence';
 assert not exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in ('public','private') and p.prokind='f' and p.proname<>'create_patent_record' and p.prosrc ~* '(public[.])?create_patent_record\s*[(]'),'No automatic Patent creation from another database operation';
 assert not has_table_privilege('authenticated','public.patent_records','INSERT');
 assert not has_table_privilege('authenticated','public.patent_records','UPDATE');
 assert not has_table_privilege('authenticated','public.evidence','INSERT');
 assert not has_table_privilege('authenticated','public.evidence','UPDATE');
 assert (select relrowsecurity from pg_class where oid='public.patent_records'::regclass);
 assert (select relrowsecurity from pg_class where oid='public.evidence'::regclass);
 assert exists(select 1 from pg_policies where schemaname='public' and tablename='patent_records' and qual like '%can_read_development_project%'),'Current canonical scope still protects retained research';
 assert (select array_agg(enumlabel::text order by enumsortorder) from pg_enum where enumtypid='public.patent_relevance_status'::regtype)=array['NOT_REVIEWED','RELEVANT','POSSIBLY_RELEVANT','NOT_RELEVANT'],'Relevance is research classification only';
 assert not exists(select 1 from information_schema.columns where table_schema='public' and table_name in ('patent_records','evidence') and column_name in ('comparison_score','similarity_score','novelty_score','patentability_status','infringement_risk','legal_status_conclusion','fto_conclusion')),'No legal-conclusion or scoring fields';
end$$;
select 'M12.17 comparison DEFERRED SHOULD-HAVE / no table-RPC-AI-scoring / explicit source-Evidence writers / research relevance / RLS-grants preserved PASS';
rollback;
