# M9.5 Brainstorm schema foundation

Status is active/archived; reveal is exclusively represented by revealed_at. Creator reads require current canonical Activity/Project/Workspace/Team access. M9.8 adds exact authorized Team-pool reads only for revealed entries whose execution snapshot has the approved reveal policy; unrevealed entries remain creator-only. Ordinary clients cannot write any field.

Parents remain in the exact same Activity/Project/Workspace (and Team) scope. Auth-context integrity checks reject inaccessible parents. Creation revalidates parent visibility and locks a matching active parent. Server-generated new IDs cannot refer to themselves or create a parent cycle; no reparent operation exists. M9.6 creation and M9.8 reveal are the only ordinary write paths; no update/promotion/archive/restore service exists. Explicit identities without auth context are trusted fixtures/administration only.

Optional Object links allow same-context IDEA/SOLUTION only. Personal privacy and removed-member revocation remain authoritative.

## M9.6 private creation

`createBrainstormEntry({activityInstanceId, content, visibilityState: "private", parentEntryId?})` rejects all additional writable fields. The RPC derives actor and scope; content is stored unchanged. Only an active writable Brainstorm Activity whose immutable snapshot contains `configuration.brainstorming.visibility_mode = "private_before_reveal"` may create. Missing/unsupported configuration fails with `DEPENDENCY_NOT_MET`; inaccessible/missing scope or parent returns the same safe unavailable error. Definition configuration is not consulted at execution time.

No separate visibility state is stored. Creation always leaves revealed_at, archived_at and development_object_id null. Unrevealed creator-only RLS and ordinary table write denial remain unchanged. No automatic participants, Activity I/O, Objects, Artifacts, reveal or promotion are created.
## M9.7 pre-reveal security regression

`pnpm test:db -- --brainstorm-privacy` runs AT-BRAIN-002 against a fresh disposable PostgreSQL cluster, using the canonical M9.6 creation/start fixture. It checks owner reads, peer exact-ID/nonexistent equivalence, unfiltered and Activity/Workspace/creator-filtered queries and counts, parent lookup equivalence, denied writes/reveal spoofing, Team B isolation, removed-member revocation, Personal privacy, archived-entry privacy, grants and publication/trigger inventory.

No separate Brainstorm retrieval/list endpoint exists at this milestone: ordinary authenticated reads use the table's RLS predicate (creator-only before reveal; the approved exact Team pool after M9.8 reveal). At M9.7 there was no reveal path. Brainstorm realtime/subscription, update and promotion remain absent. Team Chat realtime is separate. M9.7 adds tests only; it does not expand access or introduce later behavior.

## M9.8 Activity-local reveal

`revealBrainstormEntries({activityInstanceId, entryIds})` accepts a nonempty set of unique UUIDs and no extra fields. The server-only service returns only `{activityInstanceId, entries:[{entryId,revealedAt}]}`, ordered by entry ID. No private content is returned by the command.

The immutable runtime snapshot must contain `configuration.brainstorming.visibility_mode = "private_before_reveal"` and `configuration.brainstorming.reveal_authority = "team_lead_or_scoped_master"`. Only active Team Workspace Activities may reveal. Missing/unsupported configuration and Personal reveal fail closed. Historical snapshots are never rewritten.

Authority is the exact current Team Lead or exact cohort/team-scoped MASTER, plus the existing M7 canonical Project/Workspace/Team access requirements. MASTER alone does not bypass explicit Project participation or Team access. An Activity Participant row is neither sufficient nor required for current access. Ordinary members, creators, unrelated roles and removed members cannot reveal.

The database validates and locks the entire target set in deterministic ID order before mutation, rechecks authority after waiting, and updates only previously unrevealed active rows. New rows share one server timestamp; retries retain historical timestamps. Revealed timestamps cannot be cleared or replaced, including by trusted row updates. Identity, content, ownership, scope, parent and Object links remain unchanged; update metadata records the actor.

RLS allows revealed exact-Team pool reads only with current canonical Activity access and the approved snapshot. Personal privacy, pre-reveal creator privacy and removed-member revocation remain authoritative. An accessible active revealed peer entry can be a same-context parent through existing creation, without granting shared editing. No realtime, promotion, sharing, Objects, Artifacts or Activity Outputs are created.

`pnpm test:db -- --brainstorm-reveal` runs AT-BRAIN-003, both authority paths, hostile targets, retry, forced mutation rollback, lifecycle, parent, privacy and grant checks in a fresh disposable database. Existing audit event vocabulary has no Brainstorm reveal event; no new audit subsystem/event vocabulary is invented. Canonical row update metadata is retained.

## M9.9 promotion

`promoteBrainstormEntryToIdea({ entryId })` is server-only and returns the canonical IDEA. Unknown input fields are rejected. Current Activity contribution authorization is required. Personal promotion requires the source creator/owner; Team promotion requires an already revealed, currently visible entry. No other Workspace type is supported.

The RPC locks and revalidates the source, preserves its author, copies content verbatim (also used as title, with `Brainstorm Idea` for blank content), and stores `BRAINSTORM` plus the exact source UUID as provenance. Optional IDEA details are omitted. Object creation, source linking, and the acting promoter's OBJECT_CREATED Change Log entry are atomic. Retry validates the linked Object and returns it; inconsistent links conflict. Source-row locking serializes concurrent promotions.

Only the link and update metadata change on the source. No reveal, sharing, parent/child promotion, Artifact mutation, Activity Output registration, or later synchronization occurs. Authenticated clients retain SELECT-only table grants; the narrow caller-bound definer RPC has an empty search path and no anonymous/service-role execute grant.

Run `node scripts/test-db.mjs --brainstorm-promotion` for isolated AT-BRAIN-004, privacy, rollback, and independent-session concurrency tests.

## M9.12 Solution promotion

`promoteBrainstormEntryToSolution({ entryId, problemId })` accepts exactly two UUIDs and returns the canonical SOLUTION. Current Activity contribution authority and exact Project/Workspace/Team binding are required. Personal sources require their creator/owner; Team sources must already be revealed. No automatic reveal or sharing occurs.

The source locks serialize Idea/Solution promotions. A same-scope unarchived PROBLEM is required. Content is copied verbatim, with the same text as title or `Brainstorm Solution` for blank content; source author and structured BRAINSTORM provenance are retained. The verified promoter is logged separately. The transaction creates the Object, source link, exact `SOLUTION SOLVES PROBLEM` relationship, canonical Development Object Activity Output, and existing Object/Relationship creation history together. Optional typed details are not invented.

Retry returns the existing Solution only if its provenance, same Problem relationship and canonical output are consistent. IDEA links, other Problems, archived Objects, missing/inactive relationships and incomplete linkage fail closed without repair. Different entries may create independent Solutions for the same Problem, even with identical content. Source content/reveal/history and prior Artifacts remain unchanged. No ranking, voting, Solution Bank, automatic synchronization or M9.13 behavior.

Focused local validation: `node scripts/test-db.mjs --solution-promotion`, including independent-session concurrency. No hosted migration push.

## M9.13 Solution Bank
`composeSolutionBank({ activityInstanceId, solutionIds, title? })` composes explicit ordered canonical Solution outputs of the exact Brainstorm Activity. One Bank per Activity; every successful command appends a Draft, including identical selections. Initial title defaults to Solution Bank; later commands do not rename it. Snapshot contains only solution_count. SOLVES relationships, source entries and prior Versions remain unchanged. Existing current contribution, M8 review/dependency rules and immutable audit apply. No voting, sharing or hosted migration push.

## M9.14 Activity integration
IDEA promotion registers a canonical `development_object` output only when the immutable Activity snapshot contains `configuration.output_registration.promoted_ideas: true`. Missing/false preserves previous behavior. Promotion and output registration are atomic and retry-safe; historical snapshots are not backfilled. SOLUTION, PROBLEM and Bank output behavior is unchanged. Generic `resumeActivity()` remains generic; feature state reloads through existing authorized retrieval/RLS queries using the canonical Activity/output IDs. No methodology payload or new resume operation is introduced.
