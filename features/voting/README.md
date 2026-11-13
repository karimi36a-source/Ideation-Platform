# Voting database boundary (M10.14)

Authenticated callers may SELECT Session and Option metadata only through current canonical Activity, Project, Workspace and Team authorization. Personal schema contexts remain owner-only; formal Dot Voting runtime remains Team-only. Creator provenance, same-Cohort enrollment and role names are not independent access grants.

`can_read_voting_session(uuid)` is a STABLE, identity-bound SECURITY DEFINER predicate with an empty fixed search_path. Owner execution avoids recursive Session RLS. Authenticated EXECUTE is required by policies; anonymous and service-role EXECUTE are revoked. Existing canonical helpers resolve active profiles, enrollment, membership and exact time-valid Master scope.

Only authenticated SELECT on Sessions/Options is retained. Ordinary direct writes are revoked and protected by restrictive denial policies. Raw Votes have no client privileges and a restrictive all-operation deny policy, including after reveal and in LIVE/non-anonymous mode. Results continue through the existing aggregate-only operation. All controlled RPCs, vote-limit locks and lifecycle rules remain unchanged.

`node scripts/test-db.mjs --voting-rls` runs focused local/disposable security tests. The full runner also executes existing creation/open/cast/reveal/close/results, rollback, concurrency and Decision/Artifact regressions. No hosted push or M10.15 behavior is included.

## M10.16 acceptance coverage

`pnpm test:db -- --voting-acceptance` runs AT-VOTE-001/002/003 using the existing canonical PostgreSQL fixtures and operations. It includes the independent-session 2-of-3 budget race, a vote-versus-close race, direct-ID/RLS attacks, removed-member history, reveal/results privacy, read-only downstream snapshots, and an explicit human Decision selecting the lower-vote alternative. The full instrumented database runner includes all these checks. No Voting business behavior, hosted migration, or M10.17 feature is added.
