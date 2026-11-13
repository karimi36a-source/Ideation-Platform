# Professional Session 10

`runSession10Reconstruction({projectId, workspaceId, activityInstanceId,
baselineItemId, idempotencyKey, selectedContextRefs?}, {provider})` uses the
effective M8 `CURRENT_INVENTION_CONCEPT` baseline and its exact CURRENT
INVENTION_CONCEPT Version. Missing baseline fails explicitly; it never falls
back to a Draft or invents missing facts. Additional explicitly selected source
Versions, Evidence, Patents, Decisions and feedback use the existing comparative
Task Contract and Context Builder. Search history is available through canonical
research Artifacts/references; SEARCH_LOG, Chat and Files are not new AI sources.
Reconstruction uses COMPARATIVE_ANALYSIS, without a Gap requirement. Its result
is an ordinary immutable, UNVERIFIED AI Output, not a baseline or Evidence.

`confirmSession10Reconstruction({activityInstanceId, reconstructionAiOutputId,
confirmed: true})` records current authenticated human review. PostgreSQL binds
the exact completed comparative Output to the same active Session 10 Activity,
Project, Workspace and effective invention baseline. Confirmations are immutable,
attributed to their confirmer and idempotent. Currently authorized Team users may
use the same confirmed reconstruction; confirmer identity is provenance, not an
authorization grant. Confirmation is not an AI disposition, verification,
candidate acceptance, formal review, Team Decision or approval. Clients cannot
write checkpoint rows or choose the confirmer/time.

`runAiTask()` for SESSION10_GAP_REFINEMENT additionally requires
`session10CheckpointId` and `reconstructionAiOutputId`. Exactly one GAP selector
is required before deduplication. The confirmed baseline Version must remain in
CURRENT_ARTIFACT context; other explicitly selected authorized Artifact Versions
may supplement it. TEAM_DECISION is optional, selected and independently
authorized. No Decision is loaded implicitly. The normal closed six-field schema
separates current state, selected gap, candidate directions, impact analysis,
uncertainties and verification needed. Patent safeguards are mandatory.

Runtime rechecks the checkpoint before assembly, provider invocation, persistence
and completed-result retrieval. Database begin/save wrappers independently
validate checkpoint, actor, scope, effective baseline and exact selected Gap.
Operation identity permanently binds checkpoint/Gap/Share selectors. Existing
frozen Share authorization remains required; a checkpoint is never a capability.
Changed baseline or lost current access fails closed without rewriting history.

Human decisions reuse KEEP_FOR_REVIEW, MODIFIED, REJECTED and
INVESTIGATE_FURTHER. Candidate acceptance is a separate explicit
ACCEPT_AS_CANDIDATE command followed by M14.15 conversion with `confirmed: true`.
No second conversion engine, Team acceptance or automatic Project mutation exists.
Candidates retain AI origin and the human creator, with canonical null
status/verification defaults unless their established subtype defines otherwise.

Refinement can return to the existing Root Cause, Problem Storming, SCAMPER,
Brainstorming, Mind Map, Patent Search, Evidence and Critical Review activities;
their original access and lifecycle commands remain authoritative. Concept V1,
Mind Map, Evidence, Patent records, Decisions, current pointers and baselines are
not changed by generation or confirmation. Generic M14.16 revision still rejects
specialized INVENTION_CONCEPT/Mind Map Artifacts. This workflow does not invent a
Concept V2 revision adapter or skip normal M8/specialized composition governance.

Validation: `node scripts/test-db.mjs --ai-session10` plus the AI session/runtime,
registry, context, conversion, Artifact revision and payload suites. The same
database scenario is mandatory in the full cumulative integration suite.
