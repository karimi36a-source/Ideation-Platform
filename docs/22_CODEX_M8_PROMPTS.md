# FICI Invention Education & Development Platform
## Codex M8 Execution Prompts — Artifacts, Versioning, Review & Approval

**Document:** `22_CODEX_M8_PROMPTS.md`  
**Status:** Draft v0.1 — For Review  
**Depends on:** `01_PRODUCT_REQUIREMENTS.md` through `21_CODEX_M7_PROMPTS.md`  
**Purpose:** Provide exact copy/paste prompts for Codex to implement Milestone M8 safely and incrementally after M7 is complete.

---

# 1. Preconditions

Do not begin M8 until M7 is:

```text
IMPLEMENTED
→ TESTED
→ SECURITY-REVIEWED
→ COMMITTED
```

Required M7 state:

- Activity Instances exist,
- Activity Participants exist,
- Activity Inputs/Outputs exist,
- start/resume/complete Activity works,
- dependency engine works,
- Project/Workspace/Team scope is enforced,
- canonical Development Object handoff works,
- AT-ACT-001 passes,
- AT-ACT-002 passes,
- AT-ACT-003 passes,
- AT-ACT-004 generic handoff passes,
- Codex reports READY FOR M8.

If M7 is incomplete:

```text
STOP → FINISH M7 → REVIEW → COMMIT → BEGIN M8
```

M8 must not duplicate the Activity Engine.

---

# 2. M8 Goal

M8 creates the formal development-history mechanism for structured outputs.

The required lifecycle is:

```text
DRAFT
↓
SUBMITTED
↓
UNDER REVIEW
↓
REVISION REQUESTED
↓
NEW DRAFT VERSION
↓
RESUBMITTED
↓
APPROVED / CURRENT
↓
LATER SUPERSEDED BY A NEW APPROVED VERSION
```

The central rule is:

# APPROVED VERSIONS ARE IMMUTABLE

A revised artifact must create a new version.

Approved content must never be silently overwritten.

---

# 3. M8 Product Boundary

M8 includes:

- `artifacts`,
- `artifact_versions`,
- `artifact_object_links`,
- `feedback_items`,
- `submissions`,
- `review_actions`,
- `project_baseline_items`,
- Draft version creation,
- immutable version history,
- submission,
- review start,
- feedback,
- revision request,
- resubmission,
- approval,
- current-version pointer,
- supersession,
- reopen approved artifact,
- baseline foundation,
- Activity approved-output integration,
- RLS,
- approval transaction rollback,
- approval/revision concurrency protection.

M8 does **not** yet implement:

- SCAMPER-specific UI/data,
- Brainstorming-specific UI/data,
- Voting,
- Decision Records,
- Affinity,
- Mind Maps,
- Evidence,
- Patent Workspace,
- Sharing,
- AI,
- Files.

Those later milestones use the M8 Artifact system.

---

# 4. Artifact Principle

An Artifact is a higher-level structured project output.

Examples defined by the approved schema include:

```text
PROBLEM_BANK
SOLUTION_BANK
TEAM_DECISION_RECORD
INVENTION_STRUCTURE
GAP_LIST
MIND_MAP
INVENTION_CONCEPT
PATENT_LANDSCAPE
VALIDATION_PLAN
RISK_MAP
PRODUCT_ROADMAP
BUSINESS_CASE
MARKET_VALIDATION_MAP
TEAM_DEVELOPMENT_MAP
GTM_MAP
FINANCIAL_MAP
PITCH_PACKAGE
FUNDING_STRATEGY
```

Not every artifact type must have specialized UI in M8.

M8 implements the generic Artifact + Version + Review model.

---

# 5. Artifact Schema

Implement:

```text
artifacts
```

Fields:

- `id`
- `project_id`
- `workspace_id`
- `artifact_type`
- `title`
- `status`
- `current_version_id`
- `created_by`
- `activity_instance_id`
- `review_required`
- `approval_required`

Follow global metadata conventions where appropriate:

- `created_at`
- `updated_at`
- `archived_at`

Important:

`current_version_id` must point to the currently effective approved/current version where one exists.

Do not use `artifacts` row body as the versioned content store.

---

# 6. Artifact Version Schema

Implement:

```text
artifact_versions
```

Fields:

- `id`
- `artifact_id`
- `version_number`
- `version_label`
- `content_snapshot`
- `change_summary`
- `status`
- `created_by`
- `created_at`
- `previous_version_id`
- `approved_by` nullable
- `approved_at` nullable
- `approval_note` nullable

Approved statuses:

```text
DRAFT
SUBMITTED
UNDER_REVIEW
REVISION_REQUESTED
APPROVED
CURRENT
SUPERSEDED
ARCHIVED
```

Critical implementation rule:

# Version number is assigned server-side.

Clients must not choose arbitrary version numbers.

---

# 7. Approved Version Immutability

Once a version reaches approved/current state:

- content body is immutable,
- creator is immutable,
- version number is immutable,
- approval metadata is immutable except through controlled correction policy if later approved.

Do not allow:

```text
UPDATE artifact_versions
SET content_snapshot = ...
WHERE status IN ('APPROVED', 'CURRENT')
```

through ordinary application operations or user database credentials.

A change requires:

```text
reopen approved artifact
→ create new DRAFT version
→ edit new version
→ submit
→ review
→ approve
```

---

# 8. Artifact/Object Links

Implement:

```text
artifact_object_links
```

Fields:

- `id`
- `artifact_id`
- `artifact_version_id`
- `development_object_id`
- `role_in_artifact`
- `sequence`
- `metadata`

Purpose:

An Artifact version references stable Development Objects rather than duplicating them.

Example:

```text
Mind Map V2
├── System S1
├── Component C4
└── Gap G3
```

M8 must preserve both:

- artifact-level identity,
- Development Object identity.

---

# 9. Feedback Schema

Implement:

```text
feedback_items
```

Fields:

- `id`
- `project_id`
- `target_entity_type`
- `target_entity_id`
- `target_version_id` nullable
- `author_user_id`
- `feedback_type`
- `content`
- `status`
- `created_at`
- `resolved_at`

Feedback types:

```text
COMMENT
QUESTION
CORRECTION
SUGGESTION
REVISION_REQUEST
APPROVAL_NOTE
WARNING
```

Feedback must remain tied to the relevant version when it is version-specific.

Do not move old feedback onto a new revision silently.

---

# 10. Submission Schema

Implement:

```text
submissions
```

Fields:

- `id`
- `activity_instance_id`
- `artifact_id`
- `artifact_version_id`
- `submitted_by`
- `submitted_at`
- `status`
- `reviewer_user_id`

Statuses:

```text
SUBMITTED
UNDER_REVIEW
REVISION_REQUESTED
APPROVED
REJECTED
```

A Submission references one specific Artifact Version.

Do not submit a floating Artifact without a concrete version.

---

# 11. Review Action Schema

Implement:

```text
review_actions
```

Fields:

- `id`
- `submission_id`
- `reviewer_user_id`
- `action_type`
- `note`
- `created_at`

Actions:

```text
COMMENTED
REQUESTED_REVISION
APPROVED
REOPENED
REJECTED
```

Review actions form durable review history.

Do not overwrite previous Review Actions.

---

# 12. Project Baseline Schema

Implement:

```text
project_baseline_items
```

Fields:

- `id`
- `project_id`
- `baseline_type`
- `artifact_id`
- `artifact_version_id`
- `effective_from`
- `effective_to`
- `set_by`

Examples:

```text
CURRENT_INVENTION_CONCEPT
CURRENT_MIND_MAP
CURRENT_ARCHITECTURE_MAP
CURRENT_REQUIREMENTS
CURRENT_PRODUCT_ROADMAP
CURRENT_BUSINESS_CASE
```

The baseline must not be stored as one giant JSON document.

It is a collection of approved current references.

---

# 13. Baseline Policy — Important Open Question

The approved source documents explicitly leave open whether:

```text
artifact approval automatically updates project baseline
```

Therefore M8 must not silently decide this.

Safe implementation direction:

- implement `project_baseline_items`,
- implement explicit baseline update capability,
- make automatic baseline update configurable or disabled by default unless current approved docs define it,
- approval transaction may update baseline only if configured/approved.

If no policy exists:

```text
STOP → FLAG → ASK
```

before hard-coding auto-baseline behavior.

---

# 14. Review Workflow Principle

Approved review lifecycle:

```text
Draft
↓
Submitted
↓
Under Review
↓
Revision Requested
↓
Revised
↓
Resubmitted
↓
Approved
```

Feedback remains tied to the relevant Artifact Version.

A revision request must not erase the submitted version.

---

# 15. Source-of-Truth Files

Before each M8 task, Codex must read:

```text
/docs/02_PLATFORM_ARCHITECTURE.md
/docs/03_ROLES_PERMISSIONS.md
/docs/04_WORKSPACE_TEAM_COLLABORATION.md
/docs/05_DEVELOPMENT_PROJECT_MODEL.md
/docs/06_COURSE_ACTIVITY_WORKFLOWS.md
/docs/07_MVP_SCOPE.md
/docs/08_DATA_MODEL_SCHEMA.md
/docs/10_TECHNICAL_ARCHITECTURE.md
/docs/11_API_CONTRACTS.md
/docs/12_ACCEPTANCE_TESTS.md
/docs/13_CODEX_IMPLEMENTATION_PLAN.md
/docs/18_CODEX_M4_PROMPTS.md
/docs/19_CODEX_M5_PROMPTS.md
/docs/20_CODEX_M6_PROMPTS.md
/docs/21_CODEX_M7_PROMPTS.md
```

---

# 16. Global Codex Header

Use this block at the beginning of every M8 task if project rules are not automatically retained:

```text
You are implementing the FICI Invention Education & Development Platform.

Before making changes:

1. Read the relevant /docs files listed in this task.
2. Treat /docs as product and architecture source of truth.
3. Do not invent missing business rules.
4. Approved Artifact Versions are immutable.
5. Revision creates a new Version; it never overwrites an approved Version.
6. Artifact and Artifact Version are separate entities.
7. Feedback must remain tied to the correct version.
8. Approval must be transactional.
9. Project baseline is composite, not one JSON blob.
10. Preserve Role + Scope + Resource authorization.
11. Preserve Personal Workspace privacy.
12. Preserve Team isolation and removed-member revocation.
13. Preserve Project/Object stable identities.
14. Never trust client-provided actor, reviewer, approver, owner, or version number.
15. Use business commands rather than generic client CRUD for high-risk transitions.
16. Enforce server authorization and PostgreSQL RLS.
17. Do not implement M9+ methodology-specific features.
18. If requirements conflict or are ambiguous, STOP → FLAG → ASK.
19. Run requested validation before finishing.
20. Report:
    - files changed,
    - migrations,
    - status transitions,
    - transactions,
    - RLS,
    - tests,
    - concurrency handling,
    - rollback handling,
    - assumptions,
    - unresolved issues.
```

---

# 17. M8.1 — Artifact Schema

## Objective

Create stable Artifact identity separately from Artifact Versions.

## Copy/Paste Prompt

```text
TASK ID: M8.1
TASK: Artifact Schema

Read first:

- /docs/05_DEVELOPMENT_PROJECT_MODEL.md
- /docs/08_DATA_MODEL_SCHEMA.md
- /docs/20_CODEX_M6_PROMPTS.md
- /docs/21_CODEX_M7_PROMPTS.md

OBJECTIVE

Create `artifacts`.

FIELDS

- id
- project_id
- workspace_id
- artifact_type
- title
- status
- current_version_id
- created_by
- activity_instance_id
- review_required
- approval_required

RULES

1. Artifact belongs to one Project.
2. Artifact belongs to one Workspace.
3. Optional Activity Instance must belong to compatible Project/Workspace.
4. created_by is server-derived.
5. current_version_id is nullable until an initial Version exists.
6. Do not store versioned body/content directly on Artifact.
7. Archive rather than hard-delete.
8. Add indexes for Project, Workspace, type, Activity.

SECURITY

Artifact visibility follows Project + Workspace scope.
Team B cannot query Team A Artifact.
Another student cannot query private Personal Artifact.

TESTS

- valid Team Artifact
- valid Personal Artifact
- invalid Project/Workspace relation rejected
- inaccessible Artifact denied
- archived Artifact preserved

VALIDATION

Run:
pnpm lint
pnpm typecheck
pnpm test:unit
pnpm test:integration
pnpm build

DEFINITION OF DONE

Artifact identity exists independently of Version content.

FINAL REPORT

Return:
1. schema
2. constraints
3. RLS foundation
4. tests/results
5. assumptions
6. unresolved issues
```

---

# 18. M8.2 — Artifact Version Schema

## Objective

Create immutable historical Version records.

## Copy/Paste Prompt

```text
TASK ID: M8.2
TASK: Artifact Version Schema

Read first:

- /docs/05_DEVELOPMENT_PROJECT_MODEL.md
- /docs/08_DATA_MODEL_SCHEMA.md
- /docs/12_ACCEPTANCE_TESTS.md

OBJECTIVE

Create `artifact_versions`.

FIELDS

- id
- artifact_id
- version_number
- version_label
- content_snapshot
- change_summary
- status
- created_by
- created_at
- previous_version_id
- approved_by nullable
- approved_at nullable
- approval_note nullable

STATUS VALUES

- DRAFT
- SUBMITTED
- UNDER_REVIEW
- REVISION_REQUESTED
- APPROVED
- CURRENT
- SUPERSEDED
- ARCHIVED

RULES

1. server assigns monotonically increasing version_number per Artifact.
2. previous_version_id links version lineage.
3. approved/current versions are immutable.
4. DRAFT may be editable only through controlled business operation.
5. approval metadata may only be set by approval transaction.
6. current pointer lives on Artifact; version rows remain historical.
7. prevent duplicate version number per Artifact.

RLS / DATABASE INTEGRITY

Direct user UPDATE of approved/current content must fail.

TEST

- create V1 Draft
- create V2 Draft from V1 where allowed
- unique version numbering
- immutable approved body
- unauthorized version access denied

VALIDATION

Run database/RLS tests plus normal suite.

DEFINITION OF DONE

Version history can never be collapsed into one mutable record.

FINAL REPORT

Return:
1. schema
2. immutability enforcement
3. numbering strategy
4. tests/results
5. assumptions
6. unresolved issues
```

---

# 19. M8.3 — Artifact/Object Links

## Objective

Connect Artifact Versions to canonical Development Objects.

## Copy/Paste Prompt

```text
TASK ID: M8.3
TASK: Artifact/Object Links

Read first:

- /docs/05_DEVELOPMENT_PROJECT_MODEL.md
- /docs/08_DATA_MODEL_SCHEMA.md
- /docs/20_CODEX_M6_PROMPTS.md

OBJECTIVE

Implement `artifact_object_links`.

FIELDS

- id
- artifact_id
- artifact_version_id
- development_object_id
- role_in_artifact
- sequence
- metadata

RULES

1. Artifact Version must belong to Artifact.
2. Development Object must belong to same authorized Project unless later explicit cross-project sharing exists.
3. Workspace privacy must remain valid.
4. Link does not duplicate Development Object.
5. Same Object can appear in multiple Artifact Versions.
6. Sequence may represent ordered presentation.
7. role_in_artifact describes contextual function without changing Object type.

TEST

- link Problem to Problem Bank V1
- same Problem reused in V2
- cross-Team Object rejected
- unrelated Project Object rejected
- direct ID link bypass denied

VALIDATION

Run tests.

DEFINITION OF DONE

Artifacts can represent higher-level structured outputs using stable Project Objects.

FINAL REPORT

Return:
1. schema
2. validation
3. security
4. tests/results
5. assumptions
6. unresolved issues
```

---

# 20. M8.4 — Create Artifact & Initial Draft

## Objective

Implement `createArtifact(input)` and automatically create initial Draft Version.

## Approved Contract

Input:

```text
projectId
workspaceId
artifactType
title
activityInstanceId optional
reviewRequired
approvalRequired
```

Creates initial Draft Version.

## Copy/Paste Prompt

```text
TASK ID: M8.4
TASK: Create Artifact & Initial Draft

Read first:

- /docs/11_API_CONTRACTS.md
- /docs/08_DATA_MODEL_SCHEMA.md
- /docs/21_CODEX_M7_PROMPTS.md

OBJECTIVE

Implement `createArtifact(input)` transactionally.

FLOW

1. resolve authenticated actor.
2. verify Project access.
3. verify Workspace access.
4. validate optional Activity Instance scope.
5. create Artifact.
6. create Version 1 with status DRAFT.
7. set artifact.current_version_id only according to the approved meaning of "current":
   - if current_version_id is intended only for approved/current versions, leave null until approval;
   - if approved docs define Draft pointer behavior differently, follow them.
8. link Activity Output if appropriate and requested by approved operation flow.
9. write Project Change Log / audit where required.

IMPORTANT

Do not invent current-pointer semantics.
If source docs are ambiguous:
STOP → FLAG → ASK.

TEST

- Team Artifact creation
- Personal Artifact creation
- V1 created
- version number = 1 server-side
- invalid Workspace denied
- Team B denied
- actor spoofing denied

VALIDATION

Run full relevant tests.

DEFINITION OF DONE

Artifact and initial Draft Version are created consistently without leaking scope.

FINAL REPORT

Return:
1. transaction
2. current pointer behavior
3. files changed
4. tests/results
5. assumptions
6. unresolved issues
```

---

# 21. M8.5 — Create Artifact Version

## Objective

Create new Draft Versions without overwriting prior history.

## Approved Contract

```text
createArtifactVersion(input)
```

Input:

```text
artifactId
contentSnapshot
changeSummary
sourceDecisionIds optional
sourceEvidenceIds optional
sourceAiOutputIds optional
```

Version number server-assigned.

## M8 Boundary

Decision/Evidence/AI entities belong to later milestones.

Keep source-reference inputs unsupported/deferred unless those tables already exist.

Do not invent placeholder source records.

## Copy/Paste Prompt

```text
TASK ID: M8.5
TASK: Create Artifact Version

Read first:

- /docs/11_API_CONTRACTS.md
- /docs/08_DATA_MODEL_SCHEMA.md
- /docs/12_ACCEPTANCE_TESTS.md

OBJECTIVE

Implement `createArtifactVersion(input)`.

RULES

1. actor has edit permission for Artifact.
2. Artifact not archived.
3. next version_number assigned atomically server-side.
4. previous_version_id points to intended prior Version.
5. content_snapshot stored as new immutable historical snapshot.
6. status starts DRAFT.
7. previous approved/current Version remains unchanged.
8. direct update of approved body is never used for revision.
9. source Decision/Evidence/AI references remain deferred until owning milestones.

CONCURRENCY

Two simultaneous requests must not create duplicate version numbers.

Use transaction/locking/unique constraint/retry strategy.

TEST

- V1 → create V2
- V1 unchanged
- concurrent V2 attempts do not duplicate number
- Team B denied
- archived Artifact denied
- client-supplied version number ignored/rejected

VALIDATION

Run integration/concurrency tests.

DEFINITION OF DONE

Revisions always produce distinct Version records.

FINAL REPORT

Return:
1. numbering algorithm
2. concurrency protection
3. lineage behavior
4. tests/results
5. assumptions
6. unresolved issues
```

---

# 22. M8.6 — Artifact Retrieval & Version History

## Objective

Implement authorized retrieval of current Artifact metadata and full Version history.

## Approved Contracts

```text
getArtifact(artifactId)
getArtifactVersion(versionId)
listArtifactVersions(artifactId)
archiveArtifact(artifactId)
```

## Copy/Paste Prompt

```text
TASK ID: M8.6
TASK: Artifact Retrieval, Version History & Archive

Read first:

- /docs/11_API_CONTRACTS.md
- /docs/12_ACCEPTANCE_TESTS.md

OBJECTIVE

Implement secure Artifact retrieval/history operations.

GET ARTIFACT

Return authorized metadata.

GET VERSION

Respect Artifact/Workspace/Project permissions.

LIST VERSIONS

Authorized user can inspect:
- version number,
- creator,
- timestamp,
- change summary,
- approval state.

ARCHIVE

Preserve all Versions.
Do not hard-delete.

SECURITY

- direct version ID must not bypass Artifact privacy.
- removed Team member denied future private Team Artifact access.
- unshared Personal Artifact remains private.
- archived Artifact does not become public.

TEST

- AT-VER-003 data visible to authorized user
- Team B direct version ID denied
- Student B Personal Artifact history denied
- archive preserves all Versions

VALIDATION

Run tests.

DEFINITION OF DONE

Historical Version inspection works without exposing inaccessible artifacts.

FINAL REPORT

Return:
1. operations
2. metadata returned
3. privacy behavior
4. tests/results
5. assumptions
6. unresolved issues
```

---

# 23. M8.7 — Submission Schema & Submit Artifact

## Objective

Create formal submission of one specific Draft Version.

## Copy/Paste Prompt

```text
TASK ID: M8.7
TASK: Submission & Submit Artifact

Read first:

- /docs/08_DATA_MODEL_SCHEMA.md
- /docs/11_API_CONTRACTS.md
- /docs/12_ACCEPTANCE_TESTS.md

OBJECTIVE

Implement `submissions` and `submitArtifact(input)`.

SUBMISSION FIELDS

- id
- activity_instance_id
- artifact_id
- artifact_version_id
- submitted_by
- submitted_at
- status
- reviewer_user_id

STATUS

- SUBMITTED
- UNDER_REVIEW
- REVISION_REQUESTED
- APPROVED
- REJECTED

INPUT

artifactId
artifactVersionId
activityInstanceId

RULES

1. Version belongs to Artifact.
2. Version is in Draft/editable state.
3. actor owns/is authorized to submit.
4. Activity scope compatible.
5. required Artifact fields are complete.
6. reviewer must be valid for Project/Cohort scope.
7. duplicate active Submission for same Version prevented.

TRANSACTION

1. Version → SUBMITTED.
2. create Submission.
3. set Activity state if appropriate.
4. create audit event.
5. create minimal notification event/row if current notification foundation supports it.

Do not build full notification center.

TEST

- Team submits Draft
- Submission created
- status SUBMITTED
- prior Version retained
- Student from Team B denied
- stale/approved Version cannot be resubmitted as Draft
- duplicate submit handled safely

VALIDATION

Run tests.

DEFINITION OF DONE

AT-REV-001 core workflow passes.

FINAL REPORT

Return:
1. schema
2. transaction
3. reviewer resolution
4. audit/notification
5. tests/results
6. assumptions
7. unresolved issues
```

---

# 24. M8.8 — Start Review & Feedback

## Objective

Create formal review history and version-specific feedback.

## Copy/Paste Prompt

```text
TASK ID: M8.8
TASK: Start Review & Feedback

Read first:

- /docs/08_DATA_MODEL_SCHEMA.md
- /docs/11_API_CONTRACTS.md
- /docs/02_PLATFORM_ARCHITECTURE.md

OBJECTIVE

Implement:
- review_actions
- feedback_items
- startReview(submissionId)
- addFeedback(input)

START REVIEW

- assigned reviewer only,
- Submission → UNDER_REVIEW,
- Artifact Version → UNDER_REVIEW where appropriate,
- review action recorded.

ADD FEEDBACK INPUT

targetEntityType
targetEntityId
targetVersionId optional
feedbackType
content

RULES

1. author identity server-derived.
2. reviewer must have access to target.
3. version-specific feedback must retain targetVersionId.
4. Team cannot edit reviewer feedback as author.
5. feedback status/resolution history preserved.
6. feedback on V1 stays tied to V1 after V2 is created.

TEST

- assigned Master starts review
- unrelated Master denied
- Student cannot impersonate reviewer
- feedback tied to submitted Version
- old feedback remains after revision

VALIDATION

Run tests.

DEFINITION OF DONE

Formal review and feedback are durable and version-aware.

FINAL REPORT

Return:
1. review transition
2. feedback model
3. security
4. tests/results
5. assumptions
6. unresolved issues
```

---

# 25. M8.9 — Request Revision

## Objective

Request revision without modifying the submitted Version.

## Approved Contract

```text
requestRevision(input)
```

Input:

```text
submissionId
note
```

Transaction:

```text
Submission → REVISION_REQUESTED
Artifact Version → REVISION_REQUESTED
notify submitter
audit
```

## Copy/Paste Prompt

```text
TASK ID: M8.9
TASK: Request Revision

Read first:

- /docs/11_API_CONTRACTS.md
- /docs/12_ACCEPTANCE_TESTS.md

OBJECTIVE

Implement `requestRevision(input)` transactionally.

AUTHORIZATION

Assigned Master / authorized reviewer only.

FLOW

1. validate Submission is reviewable.
2. validate reviewer authority.
3. Submission → REVISION_REQUESTED.
4. submitted Artifact Version → REVISION_REQUESTED.
5. create Review Action REQUESTED_REVISION.
6. create Feedback item of type REVISION_REQUEST or link note appropriately.
7. audit.
8. minimal notification event/record if available.

CRITICAL

Do not modify:
- submitted Version content,
- version number,
- creator,
- historical feedback.

TEST

- Master requests revision
- feedback stored
- submission updated
- prior submitted Version retained unchanged
- unrelated Master denied
- Student denied
- duplicate conflicting transition protected

VALIDATION

Run tests.

DEFINITION OF DONE

AT-REV-002 passes.

FINAL REPORT

Return:
1. transaction
2. preserved history
3. feedback link
4. tests/results
5. assumptions
6. unresolved issues
```

---

# 26. M8.10 — Revision / Resubmission

## Objective

Create a new Draft Version after revision request and resubmit it.

## Copy/Paste Prompt

```text
TASK ID: M8.10
TASK: Revision & Resubmission

Read first:

- /docs/11_API_CONTRACTS.md
- /docs/12_ACCEPTANCE_TESTS.md

OBJECTIVE

Implement the revision cycle.

FLOW

1. existing submitted/revision-requested Version V1 remains immutable.
2. authorized Team/User creates new Draft Version V2.
3. V2.previous_version_id = V1.
4. user edits V2 through controlled Draft path.
5. submit V2 as new Submission or approved resubmission model according to schema.
6. old Submission/Version history remains.

RULES

- never reset V1 to DRAFT.
- never overwrite V1 content.
- V2 gets new server-assigned version_number.
- review feedback from V1 remains attached to V1.

TEST

- AT-REV-003
- AT-VER-002
- V1 unchanged
- V2 new Draft
- resubmit V2
- history lists both
- Team B denied

VALIDATION

Run tests.

DEFINITION OF DONE

Revision means new Version, not mutation of historical Version.

FINAL REPORT

Return:
1. lifecycle
2. lineage
3. resubmission behavior
4. tests/results
5. assumptions
6. unresolved issues
```

---

# 27. M8.11 — Approval Transaction

## Objective

Implement atomic formal Artifact approval.

## Approved Transaction

Must atomically:

```text
1. approve submitted version
2. supersede previous current version
3. update current pointer
4. update baseline if configured
5. close submission
6. audit
7. notify later/current minimal notification layer
```

## Copy/Paste Prompt

```text
TASK ID: M8.11
TASK: Approve Artifact Transaction

Read first:

- /docs/08_DATA_MODEL_SCHEMA.md
- /docs/11_API_CONTRACTS.md
- /docs/12_ACCEPTANCE_TESTS.md
- /docs/13_CODEX_IMPLEMENTATION_PLAN.md

OBJECTIVE

Implement `approveArtifact(input)` as one atomic transaction.

INPUT

submissionId
approvalNote optional

AUTHORIZATION

Master / explicitly authorized approver in correct Project/Cohort/Team scope.

SERVER CHECKS

1. Submission exists.
2. Submission is in approvable state.
3. caller is authorized reviewer.
4. submitted Artifact Version exists.
5. submitted Version belongs to Submission Artifact.
6. required fields complete.
7. no competing terminal review state already committed.

TRANSACTION

1. identify prior artifact.current_version_id if any.
2. submitted Version → APPROVED/CURRENT according to schema strategy.
3. previous current Version → SUPERSEDED where applicable.
4. set approved_by.
5. set approved_at.
6. set approval_note.
7. artifact.current_version_id → approved Version.
8. update project_baseline_items ONLY if approved/configured baseline policy says so.
9. Submission → APPROVED.
10. create Review Action APPROVED.
11. create audit event.
12. create minimal notification side effect where available.

ATOMICITY

Every step succeeds or entire transaction rolls back.

NO PARTIAL APPROVAL.

IMMUTABILITY

After commit:
approved/current Version body is immutable.

TEST

- first approval
- second approval supersedes prior current
- Student approval denied
- unrelated Master denied
- stale submission denied
- artificial failure midway rolls back all state

VALIDATION

Run integration + transaction + RLS tests.

DEFINITION OF DONE

AT-REV-004, AT-REV-005 and AT-TX-001 pass.

FINAL REPORT

Return:
1. transaction algorithm
2. locking/concurrency strategy
3. baseline behavior
4. rollback tests
5. authorization
6. results
7. assumptions
8. unresolved issues
```

---

# 28. M8.12 — Reopen Approved Artifact

## Objective

Create a new Draft from current approved Version without altering approved history.

## Approved Contract

```text
reopenApprovedArtifact(input)
```

## Copy/Paste Prompt

```text
TASK ID: M8.12
TASK: Reopen Approved Artifact

Read first:

- /docs/11_API_CONTRACTS.md
- /docs/12_ACCEPTANCE_TESTS.md

OBJECTIVE

Implement `reopenApprovedArtifact(input)`.

RULES

1. Artifact has an approved/current Version.
2. actor has edit/revision authority.
3. current approved Version remains immutable.
4. create new Draft Version:
   - next server version number,
   - previous_version_id = current approved Version,
   - content_snapshot copied as starting point only,
   - new Version has distinct ID.
5. current approved pointer remains unchanged until new Version is later approved.
6. record change/audit history.

TEST

- approve V1
- reopen → V2 Draft
- V1 remains current/approved
- edit V2
- V1 unchanged
- unauthorized user denied

VALIDATION

Run tests.

DEFINITION OF DONE

AT-VER-001 and AT-VER-002 behavior are structurally enforced.

FINAL REPORT

Return:
1. reopen behavior
2. current pointer behavior
3. version lineage
4. tests/results
5. assumptions
6. unresolved issues
```

---

# 29. M8.13 — Project Baseline Foundation

## Objective

Implement composite current baseline references.

## Copy/Paste Prompt

```text
TASK ID: M8.13
TASK: Project Baseline Foundation

Read first:

- /docs/05_DEVELOPMENT_PROJECT_MODEL.md
- /docs/08_DATA_MODEL_SCHEMA.md
- /docs/12_ACCEPTANCE_TESTS.md

OBJECTIVE

Implement `project_baseline_items`.

FIELDS

- id
- project_id
- baseline_type
- artifact_id
- artifact_version_id
- effective_from
- effective_to
- set_by

RULES

1. baseline Version must belong to Artifact.
2. Artifact must belong to Project.
3. baseline Version should be approved/current unless approved policy says otherwise.
4. old baseline item should be closed with effective_to rather than deleted when replaced.
5. one effective baseline item per Project + baseline_type where applicable.
6. baseline is composite; no giant baseline JSON.

AUTO-UPDATE POLICY

Do not hard-code automatic baseline update unless approved.
If configured:
- approval transaction may replace matching baseline_type atomically.

If not configured:
- provide explicit server operation for authorized baseline setting or leave foundation only.

TEST

- set CURRENT_INVENTION_CONCEPT to approved V1
- replace later with approved V2
- V1 baseline history retained
- unrelated Artifact/Project rejected
- Draft Version rejected if policy requires approved only

VALIDATION

Run tests.

DEFINITION OF DONE

Project can identify intended current approved outputs while preserving prior baseline history.

FINAL REPORT

Return:
1. schema
2. replacement semantics
3. auto-update policy status
4. tests/results
5. assumptions
6. unresolved issues
```

---

# 30. M8.14 — Approved Output Dependency Integration

## Objective

Complete the M7 dependency paths that required M8 approval/versioning.

## Copy/Paste Prompt

```text
TASK ID: M8.14
TASK: Approved Output Dependency Integration

Read first:

- /docs/06_COURSE_ACTIVITY_WORKFLOWS.md
- /docs/12_ACCEPTANCE_TESTS.md
- /docs/17_CODEX_M3_PROMPTS.md
- /docs/21_CODEX_M7_PROMPTS.md

OBJECTIVE

Extend the M7 dependency evaluator for:
- approved_output
- artifact_available

APPROVED_OUTPUT

A required upstream output satisfies dependency only when:
- expected Artifact exists,
- required Version is approved/current according to rule,
- Artifact/Version belongs to correct Project/Activity context,
- requester is authorized.

ARTIFACT_AVAILABLE

Satisfy when required Artifact type exists in valid accessible state according to dependency definition.

Do not satisfy using:
- arbitrary Draft,
- another Team's Artifact,
- unrelated Project,
- superseded Version if current-approved is required.

ACTIVITY INPUT

Allow approved Artifact/Artifact Version to be added as downstream Activity Input.

TEST

- Session-style Activity A approved Artifact becomes valid Activity B input
- Draft does not satisfy approved_output
- Team B approved Artifact does not satisfy Team A dependency
- old superseded Version handling follows dependency configuration
- AT-ACT-004 formal approved-output path now passes
- AT-CUR-001 where applicable

VALIDATION

Run Activity + Artifact integration tests.

DEFINITION OF DONE

M7 approved-output dependencies are now fully functional.

FINAL REPORT

Return:
1. dependency behavior
2. accepted states
3. input linking
4. tests/results
5. assumptions
6. unresolved issues
```

---

# 31. M8.15 — Artifact / Review RLS

## Objective

Protect Artifacts, Versions, Submissions, Feedback and Review Actions directly in PostgreSQL.

## Copy/Paste Prompt

```text
TASK ID: M8.15
TASK: Artifact, Version & Review RLS

Read first:

- /docs/03_ROLES_PERMISSIONS.md
- /docs/04_WORKSPACE_TEAM_COLLABORATION.md
- /docs/08_DATA_MODEL_SCHEMA.md
- /docs/12_ACCEPTANCE_TESTS.md
- /docs/18_CODEX_M4_PROMPTS.md
- /docs/19_CODEX_M5_PROMPTS.md
- /docs/20_CODEX_M6_PROMPTS.md

OBJECTIVE

Implement RLS for:
- artifacts
- artifact_versions
- artifact_object_links
- submissions
- feedback_items
- review_actions
- project_baseline_items

RULES

ARTIFACT
- follows Project + Workspace privacy.

VERSION
- same access as Artifact.
- approved/current body immutable under ordinary user credentials.

SUBMISSION
- submitter/team + authorized reviewer scope only.

FEEDBACK
- only authorized target/review scope.

REVIEW ACTION
- cannot be forged by Student.
- reviewer_user_id server-controlled.

BASELINE
- follows Project access.
- only authorized baseline setter may mutate.

DIRECT ATTACK TESTS

- Team B SELECT Team A Artifact = denied
- Team B SELECT exact Team A Version ID = denied
- removed Team member SELECT future Team Artifact = denied
- Student UPDATE approved Version body = denied
- Student INSERT approval Review Action = denied
- Student UPDATE artifact.current_version_id = denied
- Student UPDATE approved_by = self = denied
- unauthorized baseline mutation = denied

VALIDATION

Run dedicated RLS tests.

DEFINITION OF DONE

AT-RLS-002, AT-RLS-003, AT-RLS-004 and relevant direct-ID protections pass.

FINAL REPORT

Return:
1. policies
2. immutable fields enforcement
3. attack tests
4. results
5. files/migrations
6. assumptions
7. unresolved issues
```

---

# 32. M8.16 — AT-REV-001 to AT-REV-005

## Objective

Implement the complete Submission / Review acceptance suite.

## Required Tests

### AT-REV-001 — Submit Draft

Expected:

- Submission created,
- status SUBMITTED,
- Master notified.

### AT-REV-002 — Master Requests Revision

Expected:

- Submission updated,
- feedback stored,
- Team notified,
- prior submitted Version retained.

### AT-REV-003 — Team Resubmits New Version

Expected:

- revised Version is new,
- previous Version unchanged.

### AT-REV-004 — Master Approves

Expected atomically:

- submitted Version APPROVED/CURRENT,
- prior current SUPERSEDED,
- artifact pointer updated,
- audit created,
- notification sent.

Priority:

```text
BLOCKER
```

### AT-REV-005 — Student Cannot Approve

Expected:

```text
FORBIDDEN
```

Priority:

```text
BLOCKER
```

## Copy/Paste Prompt

```text
TASK ID: M8.16
TASK: Submission / Review Acceptance Tests

Read first:

- /docs/12_ACCEPTANCE_TESTS.md
- /docs/22_CODEX_M8_PROMPTS.md

OBJECTIVE

Implement AT-REV-001 through AT-REV-005.

FIXTURE

Team A
Project A
Master
Student A1/A2
Artifact A
Draft V1

RUN WORKFLOW

1. Team submits V1.
2. Master starts review.
3. Master requests revision.
4. Team creates V2.
5. Team resubmits V2.
6. Master approves V2.
7. Student attempts approval endpoint.

VERIFY

- every state transition,
- feedback retained,
- V1 retained,
- V2 current/approved,
- audit,
- minimal notification side effects,
- Student approval denied.

RUN

pnpm lint
pnpm typecheck
pnpm test:unit
pnpm test:integration
pnpm test:e2e
pnpm build
plus RLS tests.

DEFINITION OF DONE

AT-REV-001 PASS
AT-REV-002 PASS
AT-REV-003 PASS
AT-REV-004 PASS
AT-REV-005 PASS

FINAL REPORT

Return test matrix and results.
```

---

# 33. M8.17 — AT-VER-001 to AT-VER-003

## Objective

Prove immutable Version history.

## Copy/Paste Prompt

```text
TASK ID: M8.17
TASK: Versioning Acceptance Tests

Read first:

- /docs/12_ACCEPTANCE_TESTS.md

OBJECTIVE

Implement:

AT-VER-001
Approved Version immutable.

AT-VER-002
Revision creates a new Draft Version.

AT-VER-003
Authorized user can view:
- version number,
- creator,
- timestamp,
- change summary,
- approval state.

ATTACKS

Attempt:
- application edit of approved content,
- direct database UPDATE,
- forged current pointer,
- forged approved_by,
- deleting previous Version.

EXPECTED

All unauthorized/destructive paths fail.

FINAL REPORT

Return:
1. test matrix
2. PASS/FAIL
3. database immutability result
4. history inspection result
```

---

# 34. M8.18 — AT-TX-001 Approval Rollback

## Objective

Prove approval is all-or-nothing.

## Copy/Paste Prompt

```text
TASK ID: M8.18
TASK: Approval Transaction Rollback

Read first:

- /docs/12_ACCEPTANCE_TESTS.md
- /docs/11_API_CONTRACTS.md

OBJECTIVE

Implement AT-TX-001.

SETUP

Artifact:
- current V1
- submitted V2

Artificially fail one approval transaction step after some earlier steps have executed inside the transaction.

EXPECTED AFTER ROLLBACK

- artifact.current_version_id remains V1,
- V1 remains current state,
- V2 does not become falsely approved/current,
- Submission does not become falsely approved,
- no false approval Review Action,
- no false approval audit,
- no baseline partial update.

Then run successful approval and verify all intended state changes commit.

PRIORITY

BLOCKER

FINAL REPORT

Return transaction-state matrix before/failure/after/success.
```

---

# 35. M8.19 — AT-CON-002 Competing Approval / Revision

## Objective

Prevent contradictory final state during concurrent reviewer actions.

## Copy/Paste Prompt

```text
TASK ID: M8.19
TASK: Competing Approval / Revision Concurrency

Read first:

- /docs/12_ACCEPTANCE_TESTS.md

OBJECTIVE

Implement AT-CON-002.

SCENARIO

Same Submission receives nearly simultaneous:
- approveArtifact()
- requestRevision()

or two competing approve attempts.

SYSTEM MUST

- serialize or detect conflict,
- allow only one valid terminal transition,
- reject stale competing transition,
- preserve coherent Artifact current pointer,
- preserve coherent Submission state,
- avoid duplicate approval audit/review action,
- avoid two current Versions.

Use appropriate:
- row locking,
- optimistic concurrency,
- state-condition UPDATE,
- transaction isolation,
- unique/current constraints.

Silent last-write-wins is unacceptable.

PRIORITY

BLOCKER

FINAL REPORT

Return:
1. concurrency approach
2. race test
3. committed final state
4. rejected stale action
```

---

# 36. M8.20 — Simultaneous Draft Edit Protection

## Objective

Address the M8-relevant foundation of AT-CON-001.

The approved acceptance rule states:

```text
Two users edit same Draft.
System must merge safely through collaboration layer,
or detect version conflict.
Silent overwrite is unacceptable.
```

Liveblocks collaborative editing comes later for specific tools.

M8 therefore must at minimum detect conflicting non-realtime Draft writes.

## Copy/Paste Prompt

```text
TASK ID: M8.20
TASK: Draft Write Conflict Protection

Read first:

- /docs/12_ACCEPTANCE_TESTS.md
- /docs/10_TECHNICAL_ARCHITECTURE.md

OBJECTIVE

Prevent silent overwrite of the same Draft Version.

IMPLEMENT

Use one approved technical pattern such as:
- optimistic revision counter,
- updated_at precondition,
- content hash/version token,
- explicit Draft edit revision field.

Do not introduce Liveblocks globally in M8.

TEST

1. User A loads Draft state X.
2. User B loads same X.
3. A saves X→Y.
4. B attempts stale X→Z.

EXPECTED

B receives conflict or safe merge mechanism.
Y must not be silently overwritten.

PRIORITY

HIGH

FINAL REPORT

Return:
1. conflict mechanism
2. API behavior
3. test result
4. later Liveblocks integration note
```

---

# 37. M8.21 — End-to-End Revision Cycle

## Objective

Prove the core M8 lifecycle as one integrated scenario.

## Copy/Paste Prompt

```text
TASK ID: M8.21
TASK: End-to-End Artifact Revision Cycle

SCENARIO

1. Team A Activity creates Artifact A.
2. Artifact A V1 Draft created.
3. Link Development Objects to V1.
4. Team submits V1.
5. Master starts review.
6. Master adds feedback.
7. Master requests revision.
8. Team creates V2 Draft from V1.
9. Team edits V2.
10. V1 remains unchanged.
11. Team resubmits V2.
12. Master approves V2.
13. V2 becomes current approved Version.
14. V1 remains historical.
15. downstream Activity can consume approved V2.
16. version history lists V1 + V2.
17. direct mutation of V2 approved body fails.

VERIFY

No history is destroyed at any point.

DEFINITION OF DONE

The complete:
Draft → Submit → Revision → Resubmit → Approve
workflow works.

FINAL REPORT

Return lifecycle table with states at each step.
```

---

# 38. M8.22 — M8 Security & Integrity Hardening

## Objective

Review the entire Artifact/Review system before methodology tools begin producing artifacts.

## Copy/Paste Prompt

```text
TASK ID: M8.22
TASK: M8 Security & Integrity Hardening

Read first:

- /docs/03_ROLES_PERMISSIONS.md
- /docs/04_WORKSPACE_TEAM_COLLABORATION.md
- /docs/05_DEVELOPMENT_PROJECT_MODEL.md
- /docs/06_COURSE_ACTIVITY_WORKFLOWS.md
- /docs/08_DATA_MODEL_SCHEMA.md
- /docs/10_TECHNICAL_ARCHITECTURE.md
- /docs/11_API_CONTRACTS.md
- /docs/12_ACCEPTANCE_TESTS.md
- /docs/20_CODEX_M6_PROMPTS.md
- /docs/21_CODEX_M7_PROMPTS.md
- /docs/22_CODEX_M8_PROMPTS.md

OBJECTIVE

Perform final M8 security and integrity hardening.

VERIFY

1. approved Version body immutable.
2. version numbers server-controlled.
3. previous Versions never overwritten.
4. artifact.current_version_id cannot be forged.
5. Student cannot approve.
6. unrelated Master cannot review/approve.
7. Team B cannot access Team A Artifact/Version/Feedback/Submission.
8. removed member cannot access future Team Artifacts.
9. Personal Artifact remains private.
10. feedback remains tied to correct Version.
11. submission references exact Version.
12. approval is atomic.
13. competing approval/revision cannot create contradictory state.
14. baseline cannot point to inaccessible/unapproved invalid Version.
15. Activity approved-output dependency uses authorized current/approved output.
16. no M9+ tool implementation was added.

RUN

pnpm lint
pnpm typecheck
pnpm test:unit
pnpm test:integration
pnpm test:e2e
pnpm build
plus all RLS, transaction, and concurrency tests.

DEFINITION OF DONE

- AT-REV-001 PASS
- AT-REV-002 PASS
- AT-REV-003 PASS
- AT-REV-004 PASS
- AT-REV-005 PASS
- AT-VER-001 PASS
- AT-VER-002 PASS
- AT-VER-003 PASS
- AT-TX-001 PASS
- AT-CON-002 PASS
- AT-CON-001 M8 conflict-detection foundation PASS
- zero known approved-version mutation path
- zero known cross-Team Artifact leak
- no M9+ scope creep

FINAL REPORT

Return:
1. security review
2. integrity review
3. issues found
4. issues fixed
5. remaining issues
6. BLOCKER status
7. test results
8. recommendation: READY FOR M9 or NOT READY FOR M9
```

---

# 39. Artifact Status vs Version Status

Do not conflate:

```text
Artifact.status
```

with:

```text
ArtifactVersion.status
```

Artifact represents the long-lived structured output.

Version status represents lifecycle of one specific snapshot.

If exact Artifact-level status semantics are not defined, keep them minimal and do not duplicate every Version state at Artifact level.

---

# 40. Current Version Semantics

The schema uses:

```text
artifacts.current_version_id
```

The approval contract implies this points to the currently approved/current Version.

Do not silently point it to every latest Draft unless an approved rule says so.

This distinction matters:

```text
latest draft
≠
current approved baseline
```

---

# 41. APPROVED vs CURRENT

The schema lists both:

```text
APPROVED
CURRENT
```

while the API contract says:

```text
submitted version → APPROVED/CURRENT
```

Codex must inspect current schema conventions before deciding whether:

- CURRENT is a separate status,
- APPROVED + artifact pointer implies current,
- approval performs APPROVED then CURRENT,
- only one current Version is enforced per Artifact.

If not already resolved in implementation docs:

```text
STOP → FLAG → ASK
```

Do not invent contradictory status semantics.

---

# 42. Submission Identity

A Submission is immutable historical context for one review cycle.

If V1 is revision-requested and V2 is resubmitted, do not silently retarget old Submission from V1 to V2 unless the approved contract explicitly defines that behavior.

Preferred historical model:

```text
Submission S1 → V1
Submission S2 → V2
```

if consistent with implementation docs.

If current approved schema expects one Submission lifecycle object, flag and follow the source-of-truth decision.

---

# 43. Feedback Version Binding

Feedback should normally bind to:

```text
target entity
+
target version
```

when feedback concerns versioned content.

Example:

```text
"Component relation is unclear"
```

given on V1 must remain historically attached to V1 after V2 is created.

Do not silently move it to V2.

---

# 44. Revision Request vs Feedback

A revision request is both:

- a formal workflow transition,
- a review statement.

M8 should preserve:

```text
Review Action = REQUESTED_REVISION
```

and version-specific explanatory feedback/note.

Do not store the reason only in ephemeral UI state.

---

# 45. Rejection Policy

Schema supports:

```text
Submission status = REJECTED
Review Action = REJECTED
```

but the exact user workflow after rejection may be underdefined.

Do not invent whether rejection:

- permanently closes Artifact,
- allows reopen,
- requires new Artifact,
- permits new Version.

If needed:

```text
STOP → FLAG → ASK
```

---

# 46. Withdrawal Policy

API includes:

```text
withdrawSubmission(submissionId)
```

but only:

```text
if review has not passed a policy-defined point
```

The policy-defined point is an open question.

Therefore do not implement broad withdrawal semantics without approval.

If no policy exists:

- preserve API placeholder,
- mark operation deferred,
- flag decision.

---

# 47. Review Authority

Review/Approval is not granted merely by role name.

Authorization requires:

```text
MASTER / authorized approver
+
correct Cohort/Project/Team scope
+
Submission assignment / reviewer scope
```

Do not implement:

```text
role = MASTER → approve any Artifact
```

---

# 48. Student Cannot Approve

This is a BLOCKER rule.

Even if a Student:

- owns the Artifact,
- created the Version,
- is Team Lead,
- submitted it,

they cannot call an approval endpoint requiring Master/authorized approver authority.

RLS and server authorization must both prevent escalation.

---

# 49. Team Lead Approval

Team Lead is not a Master.

Do not grant approval authority from `team_lead` membership role unless a future explicit workflow does so.

---

# 50. Artifact Version Content Storage

`content_snapshot` is the immutable snapshot of one Version.

Do not use it to replace canonical Development Objects.

An Artifact Version may contain:

- structured snapshot data,
- references,
- layout,
- presentation state,

while `artifact_object_links` connects canonical Project Objects.

This preserves reuse and history.

---

# 51. Version Source References

The API contract anticipates future:

- sourceDecisionIds,
- sourceEvidenceIds,
- sourceAiOutputIds.

Those entity systems are not all available in M8.

Do not invent them.

Preserve extension points and add actual source linkage when owning milestones are implemented.

---

# 52. Activity Completion vs Submission

M7 Activity completion and M8 Artifact submission are distinct.

Possible workflow:

```text
Activity work complete
↓
Artifact Draft exists
↓
Submit Artifact
↓
Review
```

or an Activity may remain submitted/review-oriented depending on its definition.

Do not globally equate:

```text
completeActivity()
=
submitArtifact()
```

unless configured.

---

# 53. Approval vs Decision

Formal Artifact approval is not the same as a Team Decision Record.

M10 creates formal human Decision entities.

Do not create fake Decision records during M8 approval.

An approval is a Review Action / Artifact lifecycle event.

---

# 54. Approval vs Evidence

Approval does not mean evidence is verified.

An Artifact can be approved as course/project output while containing items whose verification state differs.

Evidence verification belongs later.

---

# 55. Baseline vs Current Version

An Artifact may have a current approved Version without necessarily being part of the Project baseline.

Baseline inclusion is a separate Project-level selection.

Do not automatically equate all approved Artifacts with baseline items.

---

# 56. Baseline History

When baseline changes:

```text
old baseline item effective_to = timestamp
new baseline item effective_from = timestamp
```

Do not delete the old reference.

This preserves historical project state.

---

# 57. Archive Behavior

Artifact archive must preserve:

- all Versions,
- object links,
- submissions,
- feedback,
- review actions,
- approval history,
- baseline history references.

Archiving must not cascade-delete history.

---

# 58. Notification Scope

M8 workflows expect notifications for:

- submission,
- revision request,
- approval.

Full notification center belongs later.

Use the existing minimal notification foundation if present.

Do not build email infrastructure or notification-center UI unless already in scope.

If notification infrastructure is formally deferred, report only that side effect as deferred; do not pretend it passed.

---

# 59. Audit Events

M8 should record security/workflow audit events such as:

```text
ARTIFACT_SUBMITTED
REVIEW_STARTED
REVISION_REQUESTED
ARTIFACT_APPROVED
ARTIFACT_REOPENED
ARTIFACT_ARCHIVED
BASELINE_UPDATED
```

Exact event names may follow repository naming conventions.

Do not store full Artifact content in audit metadata.

---

# 60. Change Log Integration

Project `change_log` from M6 may record meaningful development changes such as:

- Artifact created,
- Version created,
- approved Version changed,
- baseline changed.

Audit log and Project Change Log remain distinct.

---

# 61. Transaction Requirements

The following must be transactional:

- Artifact + initial Version creation,
- Submission transition,
- revision-request transition,
- approval,
- baseline replacement,
- reopen approved Artifact where multiple writes occur.

Failure must not leave partial state.

---

# 62. Concurrency Requirements

Concurrency protection is mandatory for:

- version numbering,
- approval,
- revision request,
- current pointer updates,
- baseline replacement.

Forbidden outcome:

```text
two CURRENT versions
```

or:

```text
submission = APPROVED
but artifact.current_version_id still old
```

or:

```text
revision requested and approved simultaneously
```

---

# 63. M8 Expected Repository Additions

Conceptually:

```text
features/
├── artifacts/
│   ├── operations/
│   ├── versions/
│   ├── links/
│   ├── access/
│   └── validation/
├── reviews/
│   ├── submissions/
│   ├── feedback/
│   ├── actions/
│   └── approval/
└── baseline/
    └── operations/

lib/
├── permissions/
│   ├── artifact.ts
│   └── review.ts
├── transactions/
│   └── approval.ts
└── concurrency/

supabase/
├── migrations/
│   ├── ...artifacts...
│   ├── ...artifact_versions...
│   ├── ...artifact_object_links...
│   ├── ...feedback_items...
│   ├── ...submissions...
│   ├── ...review_actions...
│   ├── ...project_baseline_items...
│   └── ...artifact_review_rls...
└── tests/
    └── rls/
        └── artifacts...

tests/
├── unit/
│   ├── versions/
│   ├── review/
│   └── baseline/
├── integration/
│   ├── artifacts/
│   └── approval/
└── e2e/
    └── artifact-review-cycle.spec.ts
```

Exact paths may vary.

---

# 64. M8 Completion Gate

M8 is complete only when:

```text
[ ] artifacts exists
[ ] artifact_versions exists
[ ] artifact_object_links exists
[ ] feedback_items exists
[ ] submissions exists
[ ] review_actions exists
[ ] project_baseline_items exists

[ ] createArtifact() implemented
[ ] initial Draft created
[ ] createArtifactVersion() implemented
[ ] server-controlled version numbering
[ ] Version lineage works
[ ] approved Version immutable

[ ] getArtifact() implemented
[ ] getArtifactVersion() implemented
[ ] listArtifactVersions() implemented
[ ] archiveArtifact() implemented

[ ] submitArtifact() implemented
[ ] startReview() implemented
[ ] addFeedback() implemented
[ ] requestRevision() implemented
[ ] revision creates new Draft
[ ] resubmission works
[ ] approveArtifact() implemented atomically
[ ] reopenApprovedArtifact() implemented

[ ] current pointer cannot be forged
[ ] previous current becomes superseded safely
[ ] baseline foundation implemented
[ ] baseline auto-update policy not invented
[ ] approved-output dependency integration works

[ ] Team B cannot access Team A Artifact
[ ] direct Version ID does not bypass security
[ ] removed member cannot access future Team Artifact
[ ] Student cannot mutate approved Version
[ ] Student cannot approve
[ ] unrelated Master cannot approve

[ ] AT-REV-001 PASS
[ ] AT-REV-002 PASS
[ ] AT-REV-003 PASS
[ ] AT-REV-004 PASS
[ ] AT-REV-005 PASS

[ ] AT-VER-001 PASS
[ ] AT-VER-002 PASS
[ ] AT-VER-003 PASS

[ ] AT-TX-001 PASS
[ ] AT-CON-002 PASS
[ ] AT-CON-001 M8 conflict-detection foundation PASS

[ ] AT-ACT-004 formal approved-output path PASS

[ ] lint passes
[ ] typecheck passes
[ ] unit tests pass
[ ] integration tests pass
[ ] E2E tests pass
[ ] RLS tests pass
[ ] transaction tests pass
[ ] concurrency tests pass
[ ] build passes

[ ] no M9+ feature implemented prematurely
[ ] Codex reports READY FOR M9
```

Any approved-Version overwrite is:

```text
BLOCKER
```

Any unauthorized approval is:

```text
BLOCKER
```

Any partial approval transaction is:

```text
BLOCKER
```

---

# 65. Recommended Commit Sequence

Example:

```text
feat(artifacts): add Artifact schema
feat(versions): add immutable Artifact Versions
feat(artifacts): add Artifact/Object links
feat(artifacts): add create/retrieve/archive operations
feat(reviews): add Submission schema and submit flow
feat(reviews): add Feedback and Review Actions
feat(reviews): add revision request flow
feat(versions): add revision/resubmission flow
feat(reviews): add atomic approval transaction
feat(versions): add reopen approved Artifact
feat(baseline): add Project baseline items
feat(workflow): enable approved-output dependencies
feat(security): add Artifact/Review RLS
test(reviews): add AT-REV suite
test(versions): add AT-VER suite
test(transactions): add approval rollback
test(concurrency): add competing approval/revision
test(concurrency): add Draft conflict detection
test(e2e): add Artifact revision cycle
chore(security): complete M8 hardening
```

---

# 66. M8 Non-Goals

Do not accept these as "helpful additions" during M8:

- SCAMPER entries,
- Brainstorm entries,
- Dot Voting,
- Decision Records,
- Affinity groups,
- Mind Map editor,
- Liveblocks collaborative canvas,
- Evidence records,
- Patent records,
- AI outputs,
- Sharing,
- File storage,
- public publishing,
- advanced annotation engine,
- rich document editor,
- email notification infrastructure,
- automatic Project baseline mutation without approved policy.

---

# 67. Potential M8 Ambiguities Codex Must Flag

Do not silently decide if approved docs do not resolve:

- exact Artifact-level `status` vocabulary,
- exact semantics of APPROVED vs CURRENT Version status,
- whether `current_version_id` may ever point to Draft,
- whether Submission is one record per Version or reused across revisions,
- whether Student can withdraw before review,
- exact point after which withdrawal is forbidden,
- whether reviewer can reject Artifact,
- what rejection means for future revisions,
- whether Master may directly edit Team Artifact or only review/comment,
- whether one Artifact can have multiple simultaneous Draft Versions,
- whether multiple reviewers are allowed,
- whether Mentor may review or approve,
- whether Team Lead may submit,
- who may reopen approved Artifact,
- whether approval automatically updates baseline,
- which Artifact types map to which baseline types,
- whether all approved Artifacts become current automatically,
- whether version label is auto-generated or user-entered,
- whether DRAFT content is mutable in place before explicit checkpoint,
- whether every Draft save creates a new Version,
- autosave vs explicit Draft checkpoint behavior,
- whether approved Version can be administratively corrected,
- exact baseline replacement policy,
- whether archived Artifact may be restored.

If unresolved:

```text
STOP → FLAG → ASK
```

---

# 68. Recommended Safe Defaults for Purely Technical Decisions

Only where they do not alter approved product policy:

- UUID Artifact/Version IDs,
- server-assigned version numbers,
- unique version number per Artifact,
- approved/current content immutable,
- revision creates a new Version,
- feedback remains version-bound,
- RLS on all review/version tables,
- direct client cannot mutate approval fields,
- approval uses one database transaction,
- one current pointer per Artifact,
- no hard delete of historical Versions,
- optimistic conflict detection for Draft writes,
- unique/locking protection against two current approvals,
- baseline history uses effective_from/effective_to,
- future Decision/Evidence/AI references deferred safely.

---

# 69. Review Checklist for Ahmad/FICI

Before implementation, confirm M8 reflects the intended review/version model:

```text
1. Artifact and Artifact Version are separate.

2. Every important submitted output has explicit Version history.

3. Approved Version can never be overwritten.

4. Revision always creates a new Version.

5. Old Version remains accessible to authorized users.

6. Feedback stays tied to the Version it reviewed.

7. Team submits a specific Version.

8. Master/authorized reviewer requests revision or approves.

9. Student cannot approve.

10. Approval is one atomic transaction.

11. Previous current Version becomes superseded.

12. Artifact current pointer updates only through authorized workflow.

13. Project baseline is a collection of current approved references.

14. Baseline auto-update must not be invented if policy is unresolved.

15. Approved output can now satisfy downstream Activity dependency.

16. M8 does not yet build SCAMPER, Brainstorming, Voting, Mind Map, Evidence, Patent, AI, or Sharing.
```

---

# 70. Next File After M8

After M8 has actually been:

```text
IMPLEMENTED
→ TESTED
→ SECURITY-REVIEWED
→ COMMITTED
```

create:

# `23_CODEX_M9_PROMPTS.md`

M9 will cover:

```text
SCAMPER
Brainstorming
Private-Before-Reveal
Problem Bank
Solution Bank
Brainstorm Entry → Idea
SCAMPER Entry → Idea
Structured Development Object Integration
Artifact Integration
```

M9 will be the first milestone that exposes the FICI invention methodology through native platform tools built on the Project, Activity and Artifact foundations.

---

# 71. Final Execution Rule

For M8:

```text
ARTIFACT SCHEMA
→ VERSION SCHEMA
→ OBJECT LINKS
→ CREATE ARTIFACT
→ CREATE VERSION
→ VERSION HISTORY
→ SUBMIT
→ REVIEW
→ FEEDBACK
→ REVISION
→ RESUBMIT
→ APPROVE
→ REOPEN
→ BASELINE
→ APPROVED-OUTPUT DEPENDENCY
→ RLS
→ TRANSACTION TESTS
→ CONCURRENCY TESTS
→ END-TO-END REVISION CYCLE
→ SECURITY HARDENING
```

Do not skip directly to methodology tools.

---

# End of Document

**Current Status:** Draft v0.1 — Ready for Ahmad/FICI review.  
**Execution Step After M7 Completion:** Start with **M8.1 — Artifact Schema**.
