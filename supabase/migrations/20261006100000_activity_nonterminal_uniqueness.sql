begin;
-- Exact execution context; NULL Team scope denotes the same Personal context.
-- Existing contradictory data must be resolved explicitly, never discarded.
create unique index activity_instances_one_nonterminal_context
on public.activity_instances(activity_definition_id,project_id,workspace_id,team_id)
nulls not distinct
where status in ('not_started','active','submitted','under_review','revision_requested');
comment on index public.activity_instances_one_nonterminal_context is 'M7.18 database backstop for exact-context nonterminal execution uniqueness. Completed/archived history may coexist.';
commit;
