# FICI Invention Education & Development Platform
## Codex M6 Execution Prompts — Development Project Core

**Document:** `20_CODEX_M6_PROMPTS.md`  
**Status:** Draft v0.1 — For Review  
**Depends on:** `01_PRODUCT_REQUIREMENTS.md` through `19_CODEX_M5_PROMPTS.md`  
**Purpose:** Provide exact copy/paste prompts for Codex to implement Milestone M6 safely and incrementally after M5 is complete.

---

# 1. Preconditions

Do not begin M6 until M5 is:

```text
IMPLEMENTED
→ TESTED
→ SECURITY-REVIEWED
→ COMMITTED
```

Required M5 state:

- official Teams exist,
- Team Membership works,
- Team Workspace provisioning works,
- Team Chat works,
- Team RLS works,
- removed-member access revocation works,
- Team A cannot access Team B private scope,
- Team and Chat acceptance tests pass,
- Codex reports READY FOR M6.

If M5 is incomplete:

```text
STOP → FINISH M5 → REVIEW → COMMIT → BEGIN M6
```

Do not build persistent Development Projects on top of unresolved Team/Workspace security.

---

# 2. M6 Goal

M6 creates the long-lived Development Project model that persists across:

```text
Workshop
→ Professional Course
→ Advanced Course
→ Specialized Programs
→ Mentoring
→ Acceleration
→ Later Project Development
```

The Development Project is the persistent core of the FICI platform.

The project must not be reduced to:

```text
Project
└── Files
```

or:

```text
one mutable JSON blob
```

Instead, M6 must establish:

```text
DEVELOPMENT PROJECT
├── MEMBERSHIP
├── PROGRAM / COHORT LINKS
├── STRUCTURED OBJECTS
├── OBJECT RELATIONSHIPS
├── WORKSPACE SCOPE
├── OWNERSHIP
├── ORIGIN / PROVENANCE
├── CURRENT STAGE
├── ARCHIVE STATE
└── CHANGE LOG FOUNDATION
```

The key M6 rule is:

# STABLE PROJECT ID + STABLE OBJECT IDs + EXPLICIT RELATIONSHIPS

---

# 3. M6 Product Boundary

M6 includes:

- `development_projects`,
- `project_memberships`,
- `project_program_links`,
- `development_objects`,
- `development_object_relationships`,
- `problem_details`,
- `idea_details`,
- current project stage,
- project archive,
- object archive,
- project change-log foundation,
- project ownership,
- project/workspace authorization,
- project RLS,
- object RLS,
- cross-session reuse,
- cross-program continuity architecture,
- AT-PROJ acceptance tests.

M6 does **not** yet implement:

- Activity Instances,
- Artifacts,
- Artifact Versions,
- Submission/Review/Approval,
- SCAMPER-specific workflow execution,
- Voting,
- Affinity,
- Mind Map,
- Evidence records,
- Patent records,
- AI outputs,
- Sharing,
- Files,
- Liveblocks.

Those belong to M7+.

---

# 4. Development Project Principle

A Development Project represents the evolving invention/product/business development state.

Conceptually:

```text
Project
├── Problems
├── Ideas
├── Solutions
├── Features
├── Functions
├── Components
├── Systems
├── Subsystems
├── Requirements
├── Risks
├── Gaps
├── Open Questions
├── Relationships
├── Decisions      [later specialized system]
├── Evidence       [later specialized system]
├── Artifacts      [M8+]
└── Development History
```

M6 implements the Project container and generic structured-object foundation.

---

# 5. Project Types

The approved initial project types are:

```text
individual
team
instructor_case_study
```

Future organization-level project type is not required in the MVP.

## Individual Project

Owned by one user.

May later become a Team Project.

## Team Project

Owned operationally by one Team.

Contains contributions from multiple authorized members.

## Instructor Case Study Project

Owned by Master / Instructor.

Used for teaching demonstrations.

---

# 6. Project Schema

Implement:

```text
development_projects
```

Conceptual fields:

- `id`
- `name`
- `description`
- `project_type`
- `owner_user_id` nullable
- `owner_team_id` nullable
- `primary_workspace_id`
- `status`
- `current_stage`
- `confidentiality_level`
- `created_at`
- `archived_at`

Follow global metadata conventions where appropriate:

- `created_by`
- `updated_at`
- `updated_by`

Approved status values:

```text
active
paused
completed
archived
```

Do not invent additional lifecycle states unless required by source documents.

---

# 7. Ownership Rules

Ownership must match project type.

## Individual

Expected:

```text
project_type = individual
owner_user_id != null
owner_team_id = null
primary_workspace_id = owner's Personal Workspace
```

## Team

Expected:

```text
project_type = team
owner_team_id != null
owner_user_id = null or non-owner metadata only
primary_workspace_id = Team Workspace
```

## Instructor Case Study

Expected:

```text
project_type = instructor_case_study
owner_user_id = Master/Instructor
primary_workspace_id = authorized Case Study Workspace
```

Do not allow contradictory ownership combinations.

---

# 8. Primary Workspace Rule

Project and Workspace are separate concepts.

Workspace controls collaboration scope.

Development Project stores persistent long-term project state.

Required model:

```text
WORKSPACE
= who can collaborate here

DEVELOPMENT PROJECT
= what persistent project is being developed
```

Do not collapse Project into Workspace or Workspace into Project.

A Project should have one `primary_workspace_id`, but future objects may exist in authorized related Workspaces.

---

# 9. Project Membership

Implement:

```text
project_memberships
```

Fields:

- `id`
- `project_id`
- `user_id`
- `project_role`
- `starts_at`
- `ends_at`
- `status`

Important:

```text
Project Membership ≠ Team Membership
```

A Team-owned Project may derive default eligible users from active Team Membership, but Project Membership remains its own model.

Do not silently duplicate or replace Team Membership semantics.

---

# 10. Program / Project Continuity

Implement:

```text
project_program_links
```

Purpose:

Allow one Project to continue across programs without recreating Project history.

Fields:

- `id`
- `project_id`
- `program_id`
- `cohort_id`
- `entered_at`
- `completed_at`
- `entry_artifact_version_id`
- `exit_artifact_version_id`

M6 does not yet have Artifact Versions.

Therefore:

- preserve the two artifact-version ID fields,
- keep nullable,
- defer foreign keys until M8 if necessary,
- document deferred constraints,
- do not create Artifact tables early.

Example:

```text
Project A
→ Professional Course
→ Advanced Course
```

Same Project ID.

---

# 11. Structured Development Object Model

Implement:

```text
development_objects
```

Fields:

- `id`
- `project_id`
- `workspace_id`
- `object_type`
- `title`
- `content`
- `status`
- `verification_status`
- `origin_type`
- `origin_reference_id`
- `created_by`
- `current_version_number`
- `archived_at`
- `metadata`

The object must have a stable ID.

Do not create a new Problem record every time the same Problem is used in a later session.

---

# 12. Initial M6 Object Types

The Implementation Plan requires initial support for:

```text
PROBLEM
IDEA
SOLUTION
FEATURE
FUNCTION
COMPONENT
SYSTEM
SUBSYSTEM
GAP
OPEN_QUESTION
REQUIREMENT
RISK
```

The broader schema supports more object types, including:

- ASSUMPTION
- CONSTRAINT
- VALIDATION_QUESTION
- CUSTOMER_INSIGHT
- TASK
- MILESTONE
- FINANCIAL_ASSUMPTION
- PITCH_CLAIM
- OTHER

M6 should implement the required initial set first.

Do not expand to all later Advanced Course objects unless needed by schema design and clearly non-invasive.

---

# 13. Object Model Philosophy

Store structured information when the platform needs to:

- search it,
- compare it,
- connect it,
- reuse it,
- trace it,
- review it,
- use it in AI context later,
- reference it across sessions.

Each important object should preserve:

- stable ID,
- object type,
- title/label,
- content,
- creator,
- owning Workspace,
- Project,
- timestamps,
- status,
- verification state where relevant,
- source/origin,
- relationships,
- archive state.

---

# 14. Problem Extension

Implement:

```text
problem_details
```

Optional one-to-one extension of a `development_objects` row where:

```text
object_type = PROBLEM
```

Fields:

- `development_object_id`
- `problem_category`
- `priority`
- `perspective`

Supported problem categories may include:

```text
user
functional
technical
cost
safety
environmental
accessibility
maintenance
manufacturing
market
```

Do not allow `problem_details` for non-PROBLEM objects.

---

# 15. Idea Extension

Implement:

```text
idea_details
```

Fields:

- `development_object_id`
- `technique`
- `acceptance_state`
- `original_private_workspace_id`

Acceptance states:

```text
private
shared
candidate
accepted
rejected
archived
```

Important M6 limitation:

Full Personal → Team sharing is not implemented until M13.

Therefore M6 can store the fields but must not invent Sharing behavior.

---

# 16. Object Relationships

Implement:

```text
development_object_relationships
```

Fields:

- `id`
- `project_id`
- `source_object_id`
- `target_object_id`
- `relationship_type`
- `description`
- `created_by`
- `status`

Initial supported relationships may include:

```text
SOLVES
IMPLEMENTS
SUPPORTS
DEPENDS_ON
BELONGS_TO
CONNECTED_TO
DERIVED_FROM
VALIDATES
CONTRADICTS
TESTED_BY
EVIDENCE_FOR
EVIDENCE_AGAINST
REPLACES
SUPERSEDES
IDENTIFIED_IN
```

M6 should only allow relationships between objects in authorized Project scope.

---

# 17. Example Traceability Chain

The Project model must be capable of representing a future chain such as:

```text
Problem P12
↓ SOLVES
Solution S07
↓ DELIVERED BY / IMPLEMENTS
Function F04
↓ IMPLEMENTED BY
Component C09
↓ constrained by
Requirement R06
↓ exposed to
Risk RK03
↓ investigated by
Test T05
↓ produces
Evidence EV12
↓ informs
Decision D08
↓ updates
Invention Concept V2
```

Not every node exists in M6.

M6 must make the relationship structure possible without redesign later.

---

# 18. Object Reuse Across Sessions

Required behavior:

A Problem created in Session 4 may later be referenced in:

- Session 5 Voting,
- Session 6 Affinity,
- Session 7 Mind Map,
- Session 9 patent analysis,
- Session 10 AI refinement.

It must remain the same object ID.

This is a core acceptance requirement.

---

# 19. Cross-Program Continuity

The same Project may continue from:

```text
Professional Course
→ Advanced Course
```

without recreating:

- Project,
- Project Objects,
- history.

`project_program_links` records participation in each Program/Cohort.

The Project remains one long-lived entity.

---

# 20. Current Baseline — Foundation Only

The Project model eventually maintains a current approved baseline.

The baseline is not one document.

It is a composite of current approved states such as:

- Invention Concept,
- Mind Map,
- Architecture,
- Requirements,
- Product Roadmap,
- Business assumptions,
- Pitch claims.

M8+ implements Artifacts/approval/versioning.

M6 must **not** create a simplistic single `current_baseline_json` field to fake this.

Provide only architectural compatibility.

---

# 21. Current vs Historical

The architecture must support important objects becoming:

```text
Current
Historical
Archived
Superseded
```

M6 should preserve records rather than destructively overwrite important project state.

Formal Artifact versioning belongs to M8.

---

# 22. Project Change Log Foundation

Implement:

```text
change_log
```

Data-model fields:

- `id`
- `project_id`
- `entity_type`
- `entity_id`
- `previous_version_id` nullable
- `new_version_id` nullable
- `change_type`
- `change_summary`
- `reason`
- `changed_by`
- `related_decision_id` nullable
- `related_evidence_id` nullable
- `related_ai_output_id` nullable
- `created_at`

M6 creates the foundation only.

Decision/Evidence/AI foreign keys may need to remain deferred until their tables exist.

Do not create those future domains early.

---

# 23. Change Log vs Audit Log

Do not confuse:

```text
audit_events
```

with:

```text
change_log
```

## Audit Event

Security/admin action.

Example:

```text
MEMBER_REMOVED
```

## Change Log

Project-development change.

Example:

```text
Problem statement updated
Solution archived
Component relationship changed
Project stage updated
```

Both histories may coexist.

---

# 24. Provenance

Every important Development Object should record origin.

Possible origins conceptually include:

- User,
- Team,
- Master,
- Mentor,
- AI,
- Patent,
- Technical Source,
- Customer Research,
- Test,
- Calculation,
- External Expert,
- Imported File.

M6 should implement `origin_type` in a controlled way.

Do not falsely mark AI output as a normal human-created object without origin.

AI itself is implemented later.

---

# 25. Verification State

The Project Model supports states such as:

```text
Unverified
Partially Verified
Verified
Contradicted
Needs Review
```

Not every object requires formal verification.

M6 can support the field generically.

Do not implement verification workflows or authority rules unless approved in later milestones.

---

# 26. Project Security Rule

Project authorization must use:

```text
Authenticated User
+
Workspace Access
+
Project Ownership / Membership
+
Team Scope if Team-owned
+
Role Scope
=
Project Capability
```

No single field should bypass the rest.

Do not implement:

```text
same Cohort = can read every Project
```

or:

```text
MASTER = can read every Project
```

---

# 27. Personal Project Security

For an Individual Project:

Default:

- owner can access,
- another Student cannot,
- Master cannot automatically browse it unless later course workflow/shared/submitted rule permits,
- Admin private-content access remains policy-limited,
- Personal Workspace privacy still applies.

M6 must not weaken M4.

---

# 28. Team Project Security

For a Team Project:

Default:

- active authorized Team members can access,
- assigned Master may access according to Team/educational scope,
- assigned Mentor only if explicitly scoped,
- other Teams cannot access,
- removed Team members cannot access future private Project data.

M6 must reuse M5 membership rules.

---

# 29. Instructor Case Study Security

For `instructor_case_study`:

- authorized Master owns/manages,
- students do not automatically edit,
- student viewing/publishing behavior belongs to later curriculum/publication logic.

---

# 30. Source-of-Truth Files

Before each M6 task, Codex must read relevant source documents:

```text
/docs/02_PLATFORM_ARCHITECTURE.md
/docs/03_ROLES_PERMISSIONS.md
/docs/04_WORKSPACE_TEAM_COLLABORATION.md
/docs/05_DEVELOPMENT_PROJECT_MODEL.md
/docs/07_MVP_SCOPE.md
/docs/08_DATA_MODEL_SCHEMA.md
/docs/10_TECHNICAL_ARCHITECTURE.md
/docs/11_API_CONTRACTS.md
/docs/12_ACCEPTANCE_TESTS.md
/docs/13_CODEX_IMPLEMENTATION_PLAN.md
/docs/16_CODEX_M2_PROMPTS.md
/docs/18_CODEX_M4_PROMPTS.md
/docs/19_CODEX_M5_PROMPTS.md
```

---

# 31. Global Codex Header

Use this block at the beginning of every M6 task if project rules are not automatically retained:

```text
You are implementing the FICI Invention Education & Development Platform.

Before making changes:

1. Read the relevant /docs files listed in this task.
2. Treat /docs as product and architecture source of truth.
3. Do not invent missing business rules.
4. Development Project is long-lived across sessions and Programs.
5. Do not model the Project as files-only or one mutable JSON blob.
6. Preserve stable Project and Development Object IDs.
7. Preserve Workspace boundaries.
8. Preserve Team isolation and removed-member revocation from M5.
9. Never trust client-provided identity, ownership, membership, or scope.
10. Enforce authorization server-side and through RLS.
11. Important records prefer archive/supersede over destructive deletion.
12. Use explicit object relationships.
13. Preserve provenance.
14. Do not silently overwrite approved/historical data.
15. Use migrations for schema changes.
16. Use strict TypeScript.
17. Validate runtime inputs.
18. Do not implement M7+ features.
19. If requirements conflict or are ambiguous, STOP → FLAG → ASK.
20. Run required validation before finishing.
21. Report:
    - files changed,
    - migrations,
    - operations,
    - RLS,
    - object types,
    - relationship types,
    - deferred foreign keys,
    - tests,
    - results,
    - assumptions,
    - unresolved issues.
```

---

# 32. M6.1 — Development Project Schema

## Objective

Create the persistent Project entity.

## Copy/Paste Prompt

```text
TASK ID: M6.1
TASK: Development Project Schema

Read first:

- /docs/05_DEVELOPMENT_PROJECT_MODEL.md
- /docs/08_DATA_MODEL_SCHEMA.md
- /docs/18_CODEX_M4_PROMPTS.md
- /docs/19_CODEX_M5_PROMPTS.md

OBJECTIVE

Create `development_projects`.

FIELDS

- id
- name
- description
- project_type
- owner_user_id nullable
- owner_team_id nullable
- primary_workspace_id
- status
- current_stage
- confidentiality_level
- created_at
- archived_at

Add global metadata fields according to repository conventions.

PROJECT TYPES

- individual
- team
- instructor_case_study

STATUS

- active
- paused
- completed
- archived

RULES

1. Validate ownership based on project_type.
2. primary_workspace_id must be accessible and compatible.
3. Team Project must reference valid Team.
4. Individual Project must reference valid user owner.
5. Instructor Case Study must reference authorized Master owner/workspace.
6. Avoid contradictory owner_user_id + owner_team_id states.
7. Do not store whole Project state in one JSON blob.
8. Add indexes for owner, Team, Workspace, status.

SECURITY

Add initial RLS foundation:
- Individual owner can access own Project.
- Team scope uses authorized Team membership.
- other Teams denied.
- removed Team member denied.
- unrelated Student denied.

TESTS

- valid Individual Project
- valid Team Project
- valid Instructor Case Study Project
- invalid ownership combinations rejected
- invalid primary Workspace rejected
- Team B cannot access Team A Project
- Student B cannot access Student A Individual Project

VALIDATION

Run:
pnpm lint
pnpm typecheck
pnpm test:unit
pnpm test:integration
pnpm build

DEFINITION OF DONE

Persistent Project identity exists with correct ownership and Workspace scope.

FINAL REPORT

Return:
1. Schema
2. Ownership constraints
3. RLS
4. Files/migrations
5. Tests/results
6. Assumptions
7. Unresolved issues
```

---

# 33. M6.2 — Project Membership

## Objective

Create explicit Project Membership without replacing Team Membership.

## Copy/Paste Prompt

```text
TASK ID: M6.2
TASK: Project Membership

Read first:

- /docs/05_DEVELOPMENT_PROJECT_MODEL.md
- /docs/08_DATA_MODEL_SCHEMA.md
- /docs/03_ROLES_PERMISSIONS.md

OBJECTIVE

Implement `project_memberships`.

FIELDS

- id
- project_id
- user_id
- project_role
- starts_at
- ends_at
- status

RULES

1. Project Membership is separate from Team Membership.
2. Preserve historical memberships after access ends.
3. Prevent duplicate active membership for same user/project where appropriate.
4. Ignore inactive/future/expired memberships for authorization.
5. Do not invent a large project_role vocabulary if not approved.
6. Team-owned Project may use Team Membership to create/validate initial Project Membership where product architecture requires, but do not make the two tables identical.
7. Removed Team member must not remain active in Team-owned Project through stale Project Membership.

SECURITY

- ordinary Student cannot self-add to restricted Project.
- Project membership mutation requires authorized operation.
- Team A cannot add Team B user without valid authority/eligibility.

TESTS

- active membership grants intended Project scope
- expired/inactive membership denied
- duplicate active membership rejected
- self-escalation denied
- Team removal cannot leave stale Project access

VALIDATION

Run relevant unit/integration/RLS tests.

DEFINITION OF DONE

Project participation can be represented explicitly and safely.

FINAL REPORT

Return:
1. Schema
2. project_role approach
3. lifecycle
4. Team Membership interaction
5. tests/results
6. assumptions
7. unresolved issues
```

---

# 34. M6.3 — Create Development Project

## Objective

Implement the approved Project creation business operation.

## Approved Contract

```text
createDevelopmentProject(input)
```

Input:

```text
name
description optional
projectType = individual | team | instructor_case_study
ownerUserId optional
ownerTeamId optional
primaryWorkspaceId
```

## Copy/Paste Prompt

```text
TASK ID: M6.3
TASK: Create Development Project

Read first:

- /docs/05_DEVELOPMENT_PROJECT_MODEL.md
- /docs/11_API_CONTRACTS.md
- /docs/03_ROLES_PERMISSIONS.md
- /docs/18_CODEX_M4_PROMPTS.md
- /docs/19_CODEX_M5_PROMPTS.md

OBJECTIVE

Implement `createDevelopmentProject(input)`.

AUTHORIZATION

Use authenticated server identity and relevant Workspace/Team/Master scope.

INDIVIDUAL

- authenticated owner or approved creator in valid Personal Workspace.
- do not allow creating a Project owned by arbitrary other user.

TEAM

- ownerTeamId must exist.
- primaryWorkspaceId must be that Team's authorized Team Workspace.
- creator must have Project-create authority in Team scope.
- unrelated Team user denied.

INSTRUCTOR CASE STUDY

- owner must be authorized Master/Instructor.
- primary Workspace must be authorized CASE_STUDY Workspace.

TRANSACTION

1. Validate identity.
2. Validate project_type.
3. Validate ownership.
4. Validate primary Workspace.
5. Create Project.
6. Create initial Project Memberships only if approved/required.
7. Create initial change/audit entry where architecture requires.

OUTPUT

Created Project.

DO NOT

- create Activity Instance,
- create Artifact,
- create default Problem automatically unless approved,
- create M7+ data.

TEST

- create all three project types
- spoof ownerUserId denied
- spoof ownerTeamId denied
- invalid Workspace denied
- removed Team member cannot create Team Project
- unrelated Master cannot create case study outside scope

VALIDATION

Run full Project security tests.

DEFINITION OF DONE

Project creation preserves ownership and Workspace scope.

FINAL REPORT

Return:
1. operation flow
2. authorization
3. side effects
4. tests/results
5. assumptions
6. unresolved issues
```

---

# 35. M6.4 — Program / Project Links

## Objective

Enable cross-program continuity using the same Project ID.

## Copy/Paste Prompt

```text
TASK ID: M6.4
TASK: Program / Project Participation Links

Read first:

- /docs/05_DEVELOPMENT_PROJECT_MODEL.md
- /docs/08_DATA_MODEL_SCHEMA.md
- /docs/11_API_CONTRACTS.md
- /docs/17_CODEX_M3_PROMPTS.md

OBJECTIVE

Implement `project_program_links` and `linkProjectToProgram(input)`.

FIELDS

- id
- project_id
- program_id
- cohort_id
- entered_at
- completed_at
- entry_artifact_version_id nullable
- exit_artifact_version_id nullable

CONTRACT INPUT

projectId
programId
cohortId
entryArtifactVersionId optional

RULES

1. Project remains same Project ID.
2. Program exists.
3. Cohort exists.
4. Cohort belongs to Program.
5. Actor is authorized for Project and target Program/Cohort transition.
6. Avoid duplicate active Project/Program/Cohort link.
7. entry/exit Artifact Version fields remain nullable until M8.
8. Do not create duplicate Project on transition.

TEST

- Professional Project linked to Professional Cohort.
- same Project linked later to Advanced Program fixture if available.
- Project ID unchanged.
- Development Object IDs unchanged.
- history remains.
- invalid Program/Cohort pairing rejected.
- unauthorized cross-program link denied.

UI

Cross-program UI may be deferred.

ARCHITECTURE MUST PASS AT-PROJ-003.

VALIDATION

Run relevant tests.

DEFINITION OF DONE

One Project can participate in multiple Programs without history recreation.

FINAL REPORT

Return:
1. schema
2. link operation
3. deferred artifact FKs
4. tests/results
5. assumptions
6. unresolved issues
```

---

# 36. M6.5 — Development Object Schema

## Objective

Create stable reusable structured Project Objects.

## Copy/Paste Prompt

```text
TASK ID: M6.5
TASK: Generic Development Object Schema

Read first:

- /docs/05_DEVELOPMENT_PROJECT_MODEL.md
- /docs/08_DATA_MODEL_SCHEMA.md

OBJECTIVE

Implement `development_objects`.

FIELDS

- id
- project_id
- workspace_id
- object_type
- title
- content
- status
- verification_status
- origin_type
- origin_reference_id
- created_by
- current_version_number
- archived_at
- metadata

INITIAL REQUIRED OBJECT TYPES

- PROBLEM
- IDEA
- SOLUTION
- FEATURE
- FUNCTION
- COMPONENT
- SYSTEM
- SUBSYSTEM
- GAP
- OPEN_QUESTION
- REQUIREMENT
- RISK

RULES

1. Stable UUID/object identity.
2. Every Object belongs to one Project.
3. Every Object has one owning/current Workspace scope.
4. creator derived from server identity.
5. metadata must not become a dumping ground replacing typed core fields.
6. archive rather than hard delete for important objects.
7. current_version_number is foundation only; formal versioning comes later.
8. do not silently clone objects across sessions.

SECURITY

Object access must require accessible Project + accessible Workspace.

TEST

- create each initial object type.
- invalid type rejected.
- cross-Project Workspace mismatch rejected.
- unauthorized Team cannot query object.
- archived object retained.

VALIDATION

Run unit/integration/RLS tests.

DEFINITION OF DONE

Structured Project Objects have stable reusable IDs.

FINAL REPORT

Return:
1. schema
2. object types
3. validation
4. RLS
5. tests/results
6. assumptions
7. unresolved issues
```

---

# 37. M6.6 — Create / Update / Archive Development Object

## Objective

Implement business operations for structured objects.

## Approved Contracts

```text
createDevelopmentObject(input)
updateDevelopmentObject(input)
archiveDevelopmentObject(objectId)
```

## Copy/Paste Prompt

```text
TASK ID: M6.6
TASK: Development Object Operations

Read first:

- /docs/05_DEVELOPMENT_PROJECT_MODEL.md
- /docs/11_API_CONTRACTS.md
- /docs/12_ACCEPTANCE_TESTS.md

OBJECTIVE

Implement Development Object create/update/archive operations.

CREATE INPUT

projectId
workspaceId
objectType
title
content
originType
metadata optional

CREATE RULES

- actor can create in both Project and Workspace.
- Project/Workspace relation is valid.
- created_by derived server-side.
- output is a new Draft/current object according to current M6 status vocabulary.

UPDATE RULES

- actor must have edit rights.
- stable Object ID remains unchanged.
- do not silently destroy approved history.
- if update requires formal version behavior not yet available, record Change Log and preserve compatibility for M8.
- ownership changes are not generic updates.

ARCHIVE

- preferred over destructive delete.
- archived object remains in history.
- normal active queries should distinguish archive state.

TEST

- create Problem
- update same Problem ID
- reuse same Problem in later-context fixture
- archive retains row
- unauthorized update denied
- direct-ID update by Team B denied

VALIDATION

Run Project/Object security tests.

DEFINITION OF DONE

Structured objects can evolve without identity loss.

FINAL REPORT

Return:
1. operations
2. identity preservation
3. change-log behavior
4. tests/results
5. assumptions
6. unresolved issues
```

---

# 38. M6.7 — Problem & Idea Extensions

## Objective

Implement the two explicitly specified typed extensions.

## Copy/Paste Prompt

```text
TASK ID: M6.7
TASK: Problem & Idea Typed Extensions

Read first:

- /docs/05_DEVELOPMENT_PROJECT_MODEL.md
- /docs/08_DATA_MODEL_SCHEMA.md

OBJECTIVE

Implement `problem_details` and `idea_details`.

PROBLEM_DETAILS

Fields:
- development_object_id
- problem_category
- priority
- perspective

Rules:
- one-to-one with Development Object.
- target object_type must be PROBLEM.

IDEA_DETAILS

Fields:
- development_object_id
- technique
- acceptance_state
- original_private_workspace_id

Acceptance states:
- private
- shared
- candidate
- accepted
- rejected
- archived

Rules:
- one-to-one with IDEA.
- full Sharing behavior is NOT implemented here.
- original_private_workspace_id must point to authorized Personal Workspace when populated.

TEST

- valid Problem extension
- invalid extension on SOLUTION rejected
- valid Idea extension
- invalid acceptance state rejected
- original Personal Workspace scope validated
- cross-user private Workspace reference denied

OUT OF SCOPE

- SCAMPER entry workflow
- share records
- team acceptance workflow

VALIDATION

Run relevant tests.

DEFINITION OF DONE

Problem/Idea typed data extends the generic Object model without duplicating Object identity.

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

# 39. M6.8 — Object Relationships

## Objective

Create explicit semantic links between stable Project Objects.

## Approved Contract

```text
relateDevelopmentObjects(input)
unlinkDevelopmentObjects(relationshipId)
```

Input:

```text
sourceObjectId
targetObjectId
relationshipType
description optional
```

## Copy/Paste Prompt

```text
TASK ID: M6.8
TASK: Development Object Relationships

Read first:

- /docs/05_DEVELOPMENT_PROJECT_MODEL.md
- /docs/08_DATA_MODEL_SCHEMA.md
- /docs/11_API_CONTRACTS.md

OBJECTIVE

Implement `development_object_relationships`.

FIELDS

- id
- project_id
- source_object_id
- target_object_id
- relationship_type
- description
- created_by
- status

INITIAL RELATIONSHIP TYPES

- SOLVES
- IMPLEMENTS
- SUPPORTS
- DEPENDS_ON
- BELONGS_TO
- CONNECTED_TO
- DERIVED_FROM
- VALIDATES
- CONTRADICTS
- TESTED_BY
- EVIDENCE_FOR
- EVIDENCE_AGAINST
- REPLACES
- SUPERSEDES
- IDENTIFIED_IN

RULES

1. Source and target must exist.
2. Both must belong to same accessible Project unless a later explicit cross-project rule is approved.
3. actor must have permission in Project/Workspace scope.
4. prevent self-relationship where semantically invalid.
5. prevent accidental duplicate identical active relationship where practical.
6. stable Object IDs remain unchanged.

UNLINK

- do not hard-delete historically significant relationship if it participated in approved version/history.
- if M8 approval/history is not yet present, use inactive/archive status foundation.

TEST

- Problem SOLVES? Direction should follow approved relationship semantics.
- Solution solves Problem through correct source/target test fixture.
- Component BELONGS_TO System.
- cross-Project relation rejected.
- Team B cannot relate Team A objects.
- relationship survives Object reuse across sessions.

VALIDATION

Run tests.

DEFINITION OF DONE

Project logic can be represented structurally rather than only in text.

FINAL REPORT

Return:
1. relationship schema
2. supported types
3. direction rules
4. tests/results
5. assumptions
6. unresolved issues
```

---

# 40. M6.9 — Project Metadata & Stage

## Objective

Support safe Project metadata updates without ownership mutation.

## Approved Contract

```text
updateProjectMetadata(input)
```

Editable fields may include:

- name,
- description,
- status,
- current stage.

Sensitive ownership changes require separate operations.

## Copy/Paste Prompt

```text
TASK ID: M6.9
TASK: Update Project Metadata & Current Stage

Read first:

- /docs/05_DEVELOPMENT_PROJECT_MODEL.md
- /docs/11_API_CONTRACTS.md

OBJECTIVE

Implement `updateProjectMetadata(input)`.

ALLOWED

- name
- description
- approved status transitions
- current_stage

NOT ALLOWED THROUGH GENERIC METADATA UPDATE

- owner_user_id
- owner_team_id
- primary_workspace_id
- project_type
- authorization-sensitive confidentiality changes if not explicitly approved.

RULES

1. actor must have Project edit authority.
2. current_stage should be controlled/validated.
3. changing stage does not delete prior stage objects.
4. write Change Log entry for meaningful metadata/stage updates.
5. archived Project should not accept normal edits unless restored through explicit future operation.

TEST

- authorized rename
- authorized stage update
- unauthorized ownership field rejected
- Team B update denied
- removed member update denied
- Change Log created

VALIDATION

Run tests.

DEFINITION OF DONE

Project metadata evolves without permitting ownership/security escalation.

FINAL REPORT

Return:
1. editable fields
2. stage handling
3. security
4. change-log behavior
5. tests/results
6. assumptions
7. unresolved issues
```

---

# 41. M6.10 — Project Change Log Foundation

## Objective

Create persistent project-development history foundation.

## Copy/Paste Prompt

```text
TASK ID: M6.10
TASK: Project Change Log Foundation

Read first:

- /docs/05_DEVELOPMENT_PROJECT_MODEL.md
- /docs/08_DATA_MODEL_SCHEMA.md

OBJECTIVE

Implement `change_log` for M6-owned project changes.

FIELDS

- id
- project_id
- entity_type
- entity_id
- previous_version_id nullable
- new_version_id nullable
- change_type
- change_summary
- reason
- changed_by
- related_decision_id nullable
- related_evidence_id nullable
- related_ai_output_id nullable
- created_at

M6 USAGE

Record meaningful changes such as:
- PROJECT_CREATED if project-change logging includes creation
- PROJECT_METADATA_UPDATED
- PROJECT_STAGE_CHANGED
- OBJECT_CREATED
- OBJECT_UPDATED
- OBJECT_ARCHIVED
- RELATIONSHIP_CREATED
- RELATIONSHIP_ARCHIVED
- PROJECT_ARCHIVED

Do not log every low-value technical write unless architecture requires it.

DEFERRED FOREIGN KEYS

Decision/Evidence/AI tables do not exist yet.
Keep fields nullable and defer FKs if required.

SECURITY

- clients must not forge arbitrary Change Log rows.
- log writer should be server/business-operation controlled.
- `changed_by` comes from authenticated actor/system context.

TEST

- update operation produces correct log
- spoof changed_by denied
- Team B cannot read private Team A Project Change Log
- archived Project history remains

VALIDATION

Run tests.

DEFINITION OF DONE

M6 Project changes are traceable without pretending to implement M8 full version history.

FINAL REPORT

Return:
1. schema
2. events/change types
3. security
4. deferred FKs
5. tests/results
6. assumptions
7. unresolved issues
```

---

# 42. M6.11 — Archive Development Project

## Objective

Archive without destroying Project history.

## Approved Contract

```text
archiveProject(projectId)
```

Must preserve future domains including:

- versions,
- evidence,
- decisions,
- memberships,
- audit history.

In M6, preserve all currently available Project data.

## Copy/Paste Prompt

```text
TASK ID: M6.11
TASK: Archive Development Project

Read first:

- /docs/05_DEVELOPMENT_PROJECT_MODEL.md
- /docs/08_DATA_MODEL_SCHEMA.md
- /docs/11_API_CONTRACTS.md

OBJECTIVE

Implement `archiveProject(projectId)`.

AUTHORIZATION

Only authorized Project owner/Team instructional/admin scope according to approved policy.

BEHAVIOR

1. mark Project archived.
2. set archived_at.
3. preserve Project row.
4. preserve Project Membership history.
5. preserve Program links.
6. preserve Development Objects.
7. preserve Object Relationships.
8. preserve typed details.
9. preserve Change Log.
10. prevent ordinary new Project mutations while archived.
11. create Change Log entry.

DO NOT

- cascade delete Objects,
- delete Memberships,
- delete Program links,
- delete Team history.

RESTORE

If restore policy is not approved:
do not invent it.

TEST

- archived Project read behavior follows policy
- ordinary edits denied
- Objects/history remain
- direct delete path unavailable to normal user

VALIDATION

Run tests.

DEFINITION OF DONE

Archive changes lifecycle without destroying development history.

FINAL REPORT

Return:
1. archive semantics
2. preserved data
3. access changes
4. tests/results
5. assumptions
6. unresolved issues
```

---

# 43. M6.12 — Project & Object RLS

## Objective

Protect Projects and Development Objects at the database boundary.

## Copy/Paste Prompt

```text
TASK ID: M6.12
TASK: Project & Development Object RLS

Read first:

- /docs/03_ROLES_PERMISSIONS.md
- /docs/04_WORKSPACE_TEAM_COLLABORATION.md
- /docs/05_DEVELOPMENT_PROJECT_MODEL.md
- /docs/08_DATA_MODEL_SCHEMA.md
- /docs/16_CODEX_M2_PROMPTS.md
- /docs/18_CODEX_M4_PROMPTS.md
- /docs/19_CODEX_M5_PROMPTS.md

OBJECTIVE

Implement RLS for:
- development_projects
- project_memberships
- project_program_links
- development_objects
- development_object_relationships
- problem_details
- idea_details
- change_log

CORE RULES

INDIVIDUAL PROJECT
- owner/authorized explicit member only by default.
- another Student denied.
- Master not automatically granted Personal Project access.

TEAM PROJECT
- active authorized Team/Project member.
- assigned Master according to approved Team scope.
- explicit Mentor only if scoped.
- other Teams denied.
- removed Team member denied.

INSTRUCTOR CASE STUDY
- authorized Master scope.
- Student access not automatic.

OBJECTS
- Project access AND Workspace access required.
- exact object ID must not bypass access.

RELATIONSHIPS
- both source and target accessible.
- cross-Project private linkage denied.

CHANGE LOG
- follows Project privacy.

DIRECT MUTATION
Normal client must not:
- change ownership
- self-add project membership
- move object to inaccessible Workspace
- spoof created_by
- forge Change Log
- reactivate archived Project
- access Team A from Team B

TEST

Direct DB tests with exact IDs for all sensitive tables.

VALIDATION

Run dedicated RLS/security suite.

DEFINITION OF DONE

Known Project/Object IDs do not bypass Project/Workspace/Team privacy.

FINAL REPORT

Return:
1. policies
2. helper functions
3. attack tests
4. results
5. files/migrations
6. assumptions
7. unresolved issues
```

---

# 44. M6.13 — AT-PROJ-001 Project Persists Across Sessions

## Objective

Prove Project ID continuity independent of Session execution.

## Copy/Paste Prompt

```text
TASK ID: M6.13
TASK: AT-PROJ-001 — Project Persists Across Sessions

Read first:

- /docs/12_ACCEPTANCE_TESTS.md
- /docs/05_DEVELOPMENT_PROJECT_MODEL.md

OBJECTIVE

Implement AT-PROJ-001.

SCENARIO

1. Create Project A in an early-course fixture.
2. Associate/use same Project in later-session context fixture without creating Activity Instances.
3. Verify:
   - same Project ID,
   - same owner,
   - same Workspace relationship,
   - same existing Development Objects,
   - no duplicate Project created.

M6 does not implement Activity Engine.

Use session/context references only as test metadata/fixtures where needed.

EXPECTED

Project A remains one persistent Project.

PRIORITY

MUST PASS

FINAL REPORT

Return:
1. test
2. result
3. Project IDs observed
4. duplicate-detection result
```

---

# 45. M6.14 — AT-PROJ-002 Same Objects Reused

## Objective

Prove stable Object identity across later use.

## Copy/Paste Prompt

```text
TASK ID: M6.14
TASK: AT-PROJ-002 — Same Objects Reused

Read first:

- /docs/12_ACCEPTANCE_TESTS.md
- /docs/05_DEVELOPMENT_PROJECT_MODEL.md

OBJECTIVE

Implement AT-PROJ-002.

SCENARIO

1. Create Problem P in Project A in Session 4 context.
2. Reference P in Session 5 context.
3. Reference same P in Session 6 context.
4. Verify:
   - exactly one development_objects row for P,
   - same stable object ID,
   - later contexts reference P rather than clone it,
   - update to allowed current state is traceable,
   - object remains in same Project.

Do not implement real Activity Instances to simulate sessions.

Use relationship/context fixtures or direct service references appropriate to M6.

EXPECTED

Same Object reused without duplication.

PRIORITY

MUST PASS

FINAL REPORT

Return:
1. test
2. Object ID
3. duplicate count
4. result
```

---

# 46. M6.15 — AT-PROJ-003 Cross-Program Continuity

## Objective

Prove architecture supports one Project across Programs.

## Copy/Paste Prompt

```text
TASK ID: M6.15
TASK: AT-PROJ-003 — Project Continues Across Programs

Read first:

- /docs/12_ACCEPTANCE_TESTS.md
- /docs/05_DEVELOPMENT_PROJECT_MODEL.md
- /docs/17_CODEX_M3_PROMPTS.md

OBJECTIVE

Implement the architecture-level AT-PROJ-003 test.

SCENARIO

1. Project A exists.
2. Link Project A to Professional Course/Cohort.
3. Create/use Advanced Course Program/Cohort fixture only if approved seed/test fixture exists.
4. Link the SAME Project A to Advanced Course.
5. Verify:
   - same Project ID,
   - existing Development Object IDs unchanged,
   - previous Program link preserved,
   - new Program link added,
   - history not reset.

If Advanced Course Program is not part of production seed:
- create isolated test fixture,
- do not alter production curriculum seed.

EXPECTED

Cross-program continuity supported by architecture.

PRIORITY

MUST PASS for architecture.
UI may be deferred.

FINAL REPORT

Return:
1. links
2. Project ID before/after
3. Object IDs before/after
4. result
5. any UI deferral
```

---

# 47. M6.16 — Cross-Project / Cross-Team Leakage Tests

## Objective

Attack the new Project boundary directly.

## Copy/Paste Prompt

```text
TASK ID: M6.16
TASK: Project Leakage Security Tests

Read first:

- /docs/03_ROLES_PERMISSIONS.md
- /docs/05_DEVELOPMENT_PROJECT_MODEL.md
- /docs/12_ACCEPTANCE_TESTS.md

OBJECTIVE

Attempt unauthorized Project/Object access.

FIXTURES

Team A → Project A
Team B → Project B
Student A Personal Project PA
Student B Personal Project PB

AS B1 ATTEMPT

- GET Project A exact ID
- SELECT Project A directly
- list Project A Objects
- fetch Problem A exact ID
- create relation involving Project A Object
- update Project A metadata
- archive Project A
- add self as Project member
- move own Object into Team A Workspace
- read Project A Change Log

AS A2 ATTEMPT

- access Student A1 private Individual Project if not explicitly authorized

AS REMOVED A1 ATTEMPT

- Team A Project
- Team A Objects
- Team A relationships
- Team A Change Log

EXPECTED

All unauthorized paths denied.

DEFINITION OF DONE

No known Project/Object cross-scope leakage.

FINAL REPORT

Return:
1. attack matrix
2. results
3. leaks found/fixed
4. remaining issues
```

---

# 48. M6.17 — M6 Security & Integrity Hardening

## Objective

Review M6 before the Activity Engine begins consuming Project data.

## Copy/Paste Prompt

```text
TASK ID: M6.17
TASK: M6 Security & Integrity Hardening

Read first:

- /docs/03_ROLES_PERMISSIONS.md
- /docs/04_WORKSPACE_TEAM_COLLABORATION.md
- /docs/05_DEVELOPMENT_PROJECT_MODEL.md
- /docs/08_DATA_MODEL_SCHEMA.md
- /docs/10_TECHNICAL_ARCHITECTURE.md
- /docs/11_API_CONTRACTS.md
- /docs/12_ACCEPTANCE_TESTS.md
- /docs/16_CODEX_M2_PROMPTS.md
- /docs/18_CODEX_M4_PROMPTS.md
- /docs/19_CODEX_M5_PROMPTS.md
- /docs/20_CODEX_M6_PROMPTS.md

OBJECTIVE

Perform M6 security and data-integrity hardening only.

VERIFY

1. Stable Project IDs.
2. Stable Object IDs.
3. no session duplication.
4. cross-program links preserve Project.
5. Project/Workspace ownership consistent.
6. Team Project security reuses Team isolation.
7. removed Team member cannot access Team Project.
8. Personal Project remains private.
9. direct Object IDs do not bypass access.
10. cross-Project relationships cannot leak private data.
11. owner/creator spoofing blocked.
12. Change Log cannot be forged.
13. archive preserves history.
14. no M7+ features implemented.

RUN

pnpm lint
pnpm typecheck
pnpm test:unit
pnpm test:integration
pnpm test:e2e
pnpm build
plus all configured RLS tests.

DEFINITION OF DONE

- AT-PROJ-001 PASS
- AT-PROJ-002 PASS
- AT-PROJ-003 architecture PASS
- no known Project privacy leak
- no known Object identity duplication defect
- no known stale removed-member access
- no M7+ scope creep

FINAL REPORT

Return:
1. security review
2. integrity review
3. issues found
4. issues fixed
5. remaining issues
6. BLOCKER status
7. test results
8. recommendation: READY FOR M7 or NOT READY FOR M7
```

---

# 49. Project Stage Handling

`current_stage` is part of Project metadata.

Do not hard-code the entire educational curriculum into this field.

Project stage should describe the current development stage, not simply the current course session.

The Project persists beyond one course.

If exact stage vocabulary is not approved:

```text
STOP → FLAG → ASK
```

Do not invent permanent enum values that constrain future programs.

---

# 50. Project Confidentiality

`confidentiality_level` exists in the schema.

Do not treat this field as a replacement for access control.

Example:

```text
confidentiality_level = confidential
```

still requires Role + Scope + Resource security.

Do not allow user to set a metadata value that bypasses RLS.

If exact confidentiality levels are undefined, preserve field using a conservative validated representation and flag the policy question.

---

# 51. Ownership Changes — Separate Operation

`updateProjectMetadata()` must not allow generic changes to:

- owner user,
- owner Team,
- primary Workspace,
- Project type.

Ownership transitions are high-risk.

Example:

```text
Individual Project
→ Team Project
```

may eventually be a supported workflow.

It requires a dedicated business operation because it affects:

- ownership,
- permissions,
- Workspace,
- Project Membership,
- Team Membership,
- provenance.

M6 should not silently implement this transition unless explicitly approved.

---

# 52. Object Origin vs Creator

Do not conflate:

```text
created_by
```

with:

```text
origin_type
```

Example:

A Student may enter an object based on a Patent source.

```text
created_by = Student
origin_type = PATENT
```

Likewise future AI candidate:

```text
created_by = Student/system operation
origin_type = AI
```

Both matter for provenance.

---

# 53. Object Workspace vs Project

Every Object belongs to:

```text
Project
+
Workspace
```

Project gives persistent context.

Workspace gives collaboration/privacy scope.

This enables future cases where:

- Personal idea exists within user's Project context,
- selected content is later shared/promoted,
- Team Project uses Team Workspace,
- Instructor Case Study uses Case Study Workspace.

Do not assume Project membership alone grants access to every Workspace-linked object if Workspace policy says otherwise.

---

# 54. No Accidental Object Copying

Prefer:

```text
REFERENCE
RELATIONSHIP
LINK
```

over copying.

Copy only when later product behavior explicitly requires:

- Snapshot share,
- template instantiation,
- frozen version.

M6 object reuse should not clone the same Problem simply because another Session uses it.

---

# 55. Object Deletion

Important Project Objects should prefer:

```text
archive
supersede
deactivate
```

over hard delete.

Permanent-delete policy is not part of M6.

Do not expose generic destructive delete operation for important Objects.

---

# 56. Relationship Direction

Relationships are directional where meaningful.

For example:

```text
Solution → SOLVES → Problem
```

or another direction defined by the approved semantic convention.

Do not allow UI convenience to silently invert relationship semantics.

If a relationship type's direction is ambiguous, store clear source/target meaning in code/docs and test it.

---

# 57. Human-Visible Object Codes — Not Yet Required

The Project Model asks whether IDs such as:

```text
P01
C08
```

should be human-visible.

This is unresolved.

M6 should rely on stable internal IDs.

Do not invent a human-visible numbering system unless an approved decision exists.

---

# 58. Baseline Auto-Update — Deferred

Whether Project baseline updates automatically from approved artifacts is explicitly unresolved.

M6 must not implement automatic baseline mutation.

M8+ review/version/baseline work will address it.

---

# 59. Every Idea as Permanent Object — Unresolved

The Project Model asks whether every Idea becomes a permanent Object or only intentionally saved ideas.

M6 should only create Development Object records through explicit save/create operations.

Do not auto-persist every transient keystroke/brainstorm candidate as a canonical Object.

---

# 60. Project Membership Removal

Ending Project Membership must:

- revoke future Project access,
- preserve membership history,
- preserve authorship,
- preserve existing Change Log attribution.

Do not cascade-delete contributions.

For Team-owned Projects, Team removal must not leave an accidental backdoor through Project Membership.

---

# 61. Referential Integrity

At M6, ensure:

- Project Membership cannot exist without Project/User,
- Program link cannot exist without Project/Program/Cohort,
- Development Object cannot exist without Project/Workspace,
- Problem Details cannot exist without PROBLEM Object,
- Idea Details cannot exist without IDEA Object,
- Relationship cannot exist without source/target Objects,
- Relationship's `project_id` must match Object scope,
- Change Log cannot reference unrelated Project entity IDs through ordinary operations.

---

# 62. M6 Expected Repository Additions

Conceptually:

```text
features/
├── projects/
│   ├── operations/
│   ├── membership/
│   ├── access/
│   ├── program-links/
│   └── validation/
└── development-objects/
    ├── operations/
    ├── relationships/
    ├── problem/
    ├── idea/
    └── validation/

lib/
├── permissions/
│   ├── project.ts
│   └── development-object.ts
├── provenance/
└── change-log/

supabase/
├── migrations/
│   ├── ...development_projects...
│   ├── ...project_memberships...
│   ├── ...project_program_links...
│   ├── ...development_objects...
│   ├── ...development_object_relationships...
│   ├── ...problem_details...
│   ├── ...idea_details...
│   ├── ...change_log...
│   └── ...project_object_rls...
└── tests/
    └── rls/
        ├── projects...
        └── development_objects...

tests/
├── unit/
│   ├── projects/
│   └── development-objects/
├── integration/
│   ├── projects/
│   └── development-objects/
└── e2e/
    └── project-continuity.spec.ts
```

Exact paths may vary.

---

# 63. M6 Completion Gate

M6 is complete only when:

```text
[ ] development_projects exists
[ ] project types implemented
[ ] ownership constraints implemented
[ ] primary Workspace validated

[ ] project_memberships exists
[ ] historical memberships preserved
[ ] stale removed-member Project access blocked

[ ] project_program_links exists
[ ] same Project can link across Programs
[ ] entry/exit Artifact Version fields safely deferred

[ ] development_objects exists
[ ] required initial object types supported
[ ] stable Object IDs preserved
[ ] Project + Workspace scope required

[ ] problem_details exists
[ ] idea_details exists

[ ] development_object_relationships exists
[ ] semantic relationships supported
[ ] cross-Project unauthorized relationships blocked

[ ] createDevelopmentProject() implemented
[ ] updateProjectMetadata() implemented
[ ] linkProjectToProgram() implemented
[ ] archiveProject() implemented

[ ] createDevelopmentObject() implemented
[ ] updateDevelopmentObject() implemented
[ ] archiveDevelopmentObject() implemented
[ ] relateDevelopmentObjects() implemented
[ ] unlink behavior preserves history foundation

[ ] change_log exists
[ ] Project/Object meaningful changes logged
[ ] clients cannot forge Change Log

[ ] Individual Project privacy enforced
[ ] Team Project isolation enforced
[ ] removed Team member denied
[ ] exact Project/Object ID cannot bypass access

[ ] AT-PROJ-001 PASS
[ ] AT-PROJ-002 PASS
[ ] AT-PROJ-003 architecture PASS

[ ] lint passes
[ ] typecheck passes
[ ] unit tests pass
[ ] integration tests pass
[ ] E2E tests pass
[ ] RLS tests pass
[ ] build passes

[ ] no M7+ feature implemented prematurely
[ ] Codex reports READY FOR M7
```

Any cross-Team Project leak is:

```text
BLOCKER
```

Any stable Object identity failure is:

```text
BLOCKER / architecture defect
```

---

# 64. Recommended Commit Sequence

Example:

```text
feat(projects): add Development Project schema
feat(projects): add Project Membership
feat(projects): add Program participation links
feat(objects): add Development Object schema
feat(objects): add Problem and Idea extensions
feat(objects): add Object relationships
feat(projects): add Project create/update operations
feat(objects): add Object create/update/archive operations
feat(projects): add Project archive
feat(traceability): add Project change-log foundation
feat(security): add Project/Object RLS
test(projects): add persistence across sessions
test(objects): add stable Object reuse
test(projects): add cross-program continuity
test(security): add Project leakage coverage
chore(security): complete M6 hardening
```

---

# 65. M6 Non-Goals

Do not accept these as "helpful additions" during M6:

- Activity Instance engine,
- Artifact schema,
- Artifact Versioning,
- submission/review/approval,
- SCAMPER runtime entries,
- Brainstorming runtime,
- Voting,
- Affinity Board,
- Mind Map UI,
- Liveblocks,
- Evidence system,
- Patent Workspace,
- File subsystem,
- Sharing records,
- AI assistant,
- baseline auto-approval,
- Product Roadmap system,
- Business Model UI,
- TRL UI,
- analytics dashboard.

---

# 66. Potential M6 Ambiguities Codex Must Flag

Do not silently decide if approved docs do not resolve:

- exact `current_stage` vocabulary,
- exact `confidentiality_level` vocabulary,
- exact `project_role` vocabulary,
- whether Team Membership automatically creates Project Membership,
- whether Project Membership can outlive Team Membership for Team Projects,
- who may create an Individual Project,
- who may create a Team Project,
- whether Master may create Project on behalf of Team,
- who can archive Project,
- whether owner may unarchive Project,
- whether Individual Project can be converted to Team Project,
- whether Team Project can be converted back to Individual,
- whether one Project can contain multiple inventions,
- whether every saved Idea becomes a permanent Development Object,
- whether human-visible Object codes are needed,
- whether users may manually create any Relationship type,
- whether rejected Objects remain active-view or archive-only,
- whether current Project baseline is manual or automatic,
- exact verification-status vocabulary,
- exact origin-type vocabulary,
- whether Project can link to multiple active Cohorts simultaneously.

If unresolved:

```text
STOP → FLAG → ASK
```

---

# 67. Recommended Safe Defaults for Purely Technical Decisions

Only where they do not alter approved product policy:

- UUID Project IDs,
- UUID Object IDs,
- stable identity across sessions,
- soft archive over hard delete,
- server-derived creator IDs,
- explicit Project/Workspace foreign keys,
- RLS on all Project/Object tables,
- Team-owned Project requires active Team authorization,
- same Project reused across Program links,
- no broad Cohort-wide Project access,
- no object duplication for session reuse,
- no automatic baseline mutation,
- no ownership mutation through generic metadata update,
- nullable deferred FKs to future Artifact/Evidence/Decision/AI records.

---

# 68. Review Checklist for Ahmad/FICI

Before implementation, confirm M6 reflects the intended Project model:

```text
1. Development Project is persistent across courses.

2. Project is not just a folder of files.

3. Project and Workspace are separate concepts.

4. Individual, Team, and Instructor Case Study Projects are supported.

5. Team Projects reuse M5 Team privacy.

6. Project Membership is distinct from Team Membership.

7. The same Project ID can continue from Professional to Advanced Course.

8. Problems, Ideas, Solutions, Components, etc. are structured Objects with stable IDs.

9. The same Problem is reused across Sessions instead of copied.

10. Objects can be connected through explicit semantic Relationships.

11. Problem and Idea can have specialized typed data.

12. Important Project/Object records are archived, not destructively deleted.

13. Change Log begins in M6.

14. Formal Artifact Versioning begins later in M8.

15. Evidence, AI, Patents, Sharing and Activities are not implemented in M6.

16. Cross-Team Project access is denied by server authorization and RLS.
```

---

# 69. Next File After M6

After M6 has actually been:

```text
IMPLEMENTED
→ TESTED
→ SECURITY-REVIEWED
→ COMMITTED
```

create:

# `21_CODEX_M7_PROMPTS.md`

M7 will cover:

```text
Activity Instances
Activity Participants
Activity Inputs
Activity Outputs
Activity Dependencies
Start Activity
Resume Activity
Complete Activity
Dependency Enforcement
Current Activity State
```

M7 will connect the curriculum definitions from M3 to the persistent Project/Workspace model created in M4–M6.

---

# 70. Final Execution Rule

For M6:

```text
PROJECT SCHEMA
→ PROJECT MEMBERSHIP
→ PROGRAM LINKS
→ DEVELOPMENT OBJECTS
→ TYPED EXTENSIONS
→ RELATIONSHIPS
→ PROJECT OPERATIONS
→ OBJECT OPERATIONS
→ CHANGE LOG
→ ARCHIVE
→ RLS
→ PROJECT CONTINUITY TESTS
→ CROSS-SCOPE ATTACK TESTS
→ SECURITY HARDENING
```

Do not skip directly to Activities or Artifacts.

---

# End of Document

**Current Status:** Draft v0.1 — Ready for Ahmad/FICI review.  
**Execution Step After M5 Completion:** Start with **M6.1 — Development Project Schema**.
