# M9.10 Problem Storming

`createProblemStormingProblem({ activityInstanceId, content, problemCategory, perspective? })` returns the canonical PROBLEM with nested `problem_details`. Only the eight approved categories are accepted; unknown fields and blank supplied perspectives are rejected. Content is copied verbatim, also used as title, with `Problem` for blank content. Identity/scope/lifecycle/provenance are derived server-side.

The caller-bound RPC reuses existing M7/M8 contribution locks, requires an active exact-scope `problem_storming` Activity in a Personal or Team Workspace, and atomically creates one Object, required details, one generic `development_object` Activity Output, and one OBJECT_CREATED Change Log. Each explicit call creates a new Problem, including identical text. There is no content deduplication or idempotency key.

Professional-course Session 4 requires exactly one effective current DEVELOPED_CONCEPT from registered `activity_inputs`. Canonical session/program relationships identify Session 4; titles do not. Existing mandatory DEVELOPED_CONCEPT dependencies and required registered Concept inputs also require resolution. Generic isolated definitions without such requirements may omit Concept input. No new configuration key or historical snapshot mutation is introduced. The repository has no CONCEPT Object type, so M8 Artifact/Version inputs are used. Current pointer/status/approval, same Project/Workspace and current authorization are checked and locked. Missing inputs fail DEPENDENCY_NOT_MET; conflicting current Concepts fail CONFLICT. Existing superseded fixed Version inputs are never retargeted.

Origin fields reference PROBLEM_STORMING and the Activity UUID; metadata retains the resolved canonical input/Artifact/Version references when present. Source Concept, Versions and inputs remain unchanged. Priority and verification/status remain neutral. Ordinary clients retain existing deny-write grants/RLS; the narrow RPC uses fixed empty search_path and authenticated-only execution.

Problem Bank Artifact created in M9.10: NO
Problem Bank Artifact deferred to M9.11: YES

No Solutions, evaluation, ranking, voting, sharing, AI, or Session 5 execution is implemented. Stable Object IDs and generic output links are available for later reuse without cloning.

Focused database validation: `node scripts/test-db.mjs --problem-storming` using disposable local PostgreSQL.

## M9.11 Problem Bank composition

`composeProblemBank({ activityInstanceId, problemIds, title? })` returns `{ artifact, version }`, both canonical persisted rows. The strict input rejects all identity/scope/lifecycle fields. Selection is nonempty and unique, preserves caller ordering, and requires current active, unarchived PROBLEM outputs of this exact active Problem Storming Activity. Personal owner and Team contributor authority remain the existing M7/M8 authority; role alone grants no content access.

Exactly one PROBLEM_BANK identity exists per Activity, including archived history. Initial title defaults to `Problem Bank`; later calls never rename it. Each successful command appends the next M8 Draft with latest predecessor, revision 0 and minimal `{ problem_count }` snapshot. Identical deliberate calls create distinct Versions: there is no client retry key or content-based suppression. Without such a key, a retry after an unknown network outcome is indistinguishable from a new command and creates another Version. First-creation races serialize on the Activity key and parent Artifact; a unique index also protects generic Artifact creation paths.

Links contain the existing Problem IDs, sequence 1..N and role `problem`. No source content is copied or changed. One stable Artifact Activity Output is registered through the existing M8 operation. Flags derive from the immutable Activity snapshot; reuse rejects an existing Bank with mismatched requirements rather than rewriting it; no submission/approval/current-pointer mutation occurs. Existing approved_output/artifact_available evaluation and M8 review operations remain authoritative.

Every composition appends an empty-metadata `PROBLEM_BANK_COMPOSED` event to the existing immutable audit table with verified actor and exact Artifact identity. No content is copied into audit. Artifact/Version/links/output/audit writes roll back together. Archived Bank restoration, voting, Solutions, sharing, and M9.12+ remain out of scope.

Focused local validation: `node scripts/test-db.mjs --problem-bank`; includes two independent sessions racing first composition. No hosted migration push.
