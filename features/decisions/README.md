# Team Decision Record composition (M10.13)

`createTeamDecisionRecordArtifact(decisionId)` accepts only a UUID. Current exact Team Lead/scoped Master authority, a FINALIZED Team Decision and its immutable Activity snapshot are required. The approved output contract is `configuration.outputs.artifact_types`; execution reads it at `configuration_snapshot.configuration.outputs.artifact_types`. All values must be approved Artifact types and the array must include `TEAM_DECISION_RECORD`. Existing top-level snapshot review/approval flags remain separate. Historical snapshots are never backfilled.

One transaction reuses M8 initial Artifact/V1 creation, snapshots deterministically ordered Decision/Option/Participant/reference data, links selected canonical Objects, records immutable `artifact_decision_sources` and registers the M7 Artifact output. Decision locking and source uniqueness converge retries/concurrent Lead/Master calls to one initial Artifact/Version. Generic Artifact creation cannot manufacture this configured output. Source references follow Version RLS and cannot be client-created, retargeted or deleted. Subsequent Draft/version/review/approval behavior remains M8-owned; composition performs no approval, baseline or source mutation.

Run `node scripts/test-db.mjs --decision-artifact` for focused local/disposable composition, rollback, security and independent-session concurrency coverage. The full integration/database runner includes this suite. No hosted migration push or M10.14 behavior is included.

## Decision database boundary (M10.15)

Authenticated SELECT on Decisions and children requires current canonical Project/Workspace access. Personal rows are owner-only; Team reads reuse current Team context. Owner and participant rows are historical provenance, not independent authorization. All direct writes remain revoked and restrictive denial guards protect against accidental broad grants. No create/finalize/link/supersede business rules change.

Artifact Decision sources retain M10.13 Version RLS and now require both visible Artifact and authorized Decision. Narrow submitted-Version reviewer access alone does not reveal Decision IDs. The STABLE SECURITY DEFINER read predicate uses an empty fixed search_path, UUID resource input only and authenticated-only EXECUTE to avoid policy recursion.

Run `node scripts/test-db.mjs --decision-rls` for local/disposable privacy, direct CRUD, parent/child/source, and historical attribution attacks. The cumulative runner retains controlled-operation, supersession and Team Decision Record regressions. No hosted push or M10.16 behavior.

## M10.17 acceptance coverage

`node scripts/test-db.mjs --decision-acceptance` exercises AT-DEC-001 and AT-DEC-002 using the canonical operations and PostgreSQL persistence. It checks explicit reasoning, server timestamps, non-top human selection, Object/Artifact/Voting links, existing participant preservation, identity clearing/reload, idempotent finalization, complete D1/D2 snapshots, exact supersession events, and the D3 → D2 → D1 history chain. Existing authorization, direct-RLS attacks, controlled-link, Team Decision Record and voting-separation regressions are retained. The Evidence extension is now covered by the M12.18 canonical Decision/Evidence scenario. No business RPC, hosted migration or M10.18 behavior is added.

## M10.18 Session 5 integration

`node scripts/test-db.mjs --session5` extends the committed Session 4 acceptance fixture through canonical Dot Voting, a non-top human Decision, configured Team Decision Record composition, optional explicit M8 review, and downstream availability/approval dependencies. The existing false review/approval flags are retained; this fixture does not resolve the production Session 5 approval-policy question. Definition configuration is applied before approval and Activity start. Reconnect and removed-member/Team B checks use actual PostgreSQL state. Canonical Problem/Solution IDs, source Banks, and baselines remain unchanged. No production curriculum, business API, or hosted migration is changed.

## M10.19 concurrency acceptance

`node scripts/test-db.mjs --m10-concurrency` starts a clean disposable cluster
and repeats the core races three times with separately authenticated PostgreSQL
connections. Coverage includes fresh same-option contention, 2-of-3 budget
contention, single/multiple casts versus close, identical/conflicting cross-actor
finalization, and all three linear supersession races. Assertions verify exact
events/timestamps, complete winner payloads, losing-contender rollback, preserved
history, and zero worker connections/databases after cleanup. The cumulative
integration runner includes the same repeated group and existing authority, RLS,
rollback, Team Decision Record and Session 5 regressions. No product policy changes.

Finalize versus Activity transition is not a separate coordinated race in this
harness; existing approved completed/archived lifecycle denial regressions remain
required. No new Activity transition or runtime behavior is introduced.

## M10.20 cross-Team leakage acceptance

`node scripts/test-db.mjs --m10-leakage` runs an integrated attack matrix against
a fresh disposable PostgreSQL cluster. It covers exact IDs, parent/child joins,
raw votes, hidden named/anonymous and LIVE results, reveal/close/finalize/link/
supersede attempts, direct CRUD, Artifact/Version source traversal, preserved
supersession history, removed contributors/owners and role-only scope bypasses.
Full-row snapshots verify denial never mutates protected data or deletes history.
Existing service tests verify stable safe errors; Decision reads use canonical
authenticated database SELECT because no dedicated Decision retrieval API exists.

M10.20 found delegated `Access denied` errors could differ from nonexistent-ID
`Resource unavailable` errors on public Decision RPCs. The incremental migration
normalizes that scope-helper failure to generic SQLSTATE 42501, preserving all
authority, locking, lifecycle and grants. Both private helpers remain inaccessible
to clients. Exact-ID and nonexistent-ID calls must now return the same denial.

Revoked Master authority denies elevated operations. An independently valid
Team/Project membership still preserves its approved ordinary read rights; the
role-only denial fixture separately removes that independent authorization. No
new Master, Mentor or Admin read bypass is added. No hosted migrations are pushed.

## M12.18 canonical Evidence integration

finalizeDecision accepts real linkedEvidenceIds and creates/reuses evidence_links with DECISION / SUPPORTS inside the same PostgreSQL transaction. IDs are deduplicated; all five verification states are accepted without modifying Evidence or verification history. Current Decision finalization authority and independent source/target read access remain required, with exact Project/Workspace compatibility. No Evidence rows or legacy decision_links EVIDENCE rows are manufactured.

Identical retries preserve the canonical Decision, timestamp, participants, links and event. Retry comparison follows the existing complete-set semantics: after a separate authorized attachment changes the support set, callers must include that current set; stale/inconsistent sets conflict without mutation. Existing linkEvidence can attach to finalized Decisions under its already-approved write/both-endpoint authorization; it never reopens or edits a Decision. Supersession preserves old links and does not copy them automatically.

Both operations acquire Decision locks before Evidence locks. The M12.18 race test holds Evidence in a third session while real linking and finalization contend, covering the lock-order boundary. Focused gate: node scripts/test-db.mjs --decision-evidence. Full cumulative integration is required for this business-operation migration.
