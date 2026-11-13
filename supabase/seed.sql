-- M2.1: fixed configuration only. No users, assignments or product fixtures.
-- Same owner-only seed used by the migration; repeated runs preserve identities.
select public.seed_system_roles();
select public.seed_initial_organization();
select public.seed_professional_curriculum();
select public.seed_professional_sessions();
select public.seed_professional_activity();
