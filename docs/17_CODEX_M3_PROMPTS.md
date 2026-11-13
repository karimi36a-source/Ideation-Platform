# FICI Invention Education & Development Platform
## Codex M3 Execution Prompts — Programs, Curriculum, Cohorts & Enrollment

**Document:** `17_CODEX_M3_PROMPTS.md`  
**Status:** Draft v0.1 — For Review  
**Depends on:** `01_PRODUCT_REQUIREMENTS.md` through `16_CODEX_M2_PROMPTS.md`  
**Purpose:** Provide exact copy/paste prompts for Codex to implement Milestone M3 safely and incrementally after M2 is complete.

---

# 1. Preconditions

Do not begin M3 until M2 is:

```text
IMPLEMENTED
→ TESTED
→ SECURITY-REVIEWED
→ COMMITTED
```

Required M2 state:

- system roles exist,
- scoped role assignments exist,
- server authorization context exists,
- authorization uses verified server identity,
- Role + Scope + Resource logic is enforced,
- RLS is enabled for sensitive M1/M2 tables,
- role escalation is blocked,
- AT-RBAC-001 passes,
- AT-RBAC-002 passes,
- AT-RBAC-003 passes,
- Codex reports READY FOR M3.

If M2 is incomplete:

```text
STOP → FINISH M2 → REVIEW → COMMIT → BEGIN M3
```

Do not weaken the security model to make M3 easier.

---

# 2. M3 Goal

Milestone M3 creates the educational structure required to run a real FICI cohort.

M3 must deliver:

```text
ORGANIZATION
↓
PROGRAM
↓
CURRICULUM VERSION
↓
SESSION DEFINITIONS
↓
ACTIVITY DEFINITIONS
↓
ACTIVITY DEPENDENCIES
↓
COHORT
↓
ENROLLMENTS
↓
ASSIGNED MASTER
```

The key product rule is:

# A cohort runs against a defined curriculum version.

Historical cohorts must not silently change when a future curriculum version is created.

---

# 3. M3 Product Boundary

M3 includes:

- organization foundation,
- programs,
- curriculum versions,
- session definitions,
- activity definitions,
- activity dependencies,
- cohorts,
- enrollments,
- assigned Master,
- relevant admin/master operations,
- RLS/security for these resources,
- curriculum seed data for the Professional Course,
- tests for cohort isolation and enrollment behavior.

M3 does **not** yet implement:

- Personal Workspace,
- Team Workspace,
- Master Workspace,
- Team creation,
- Team membership,
- Team Chat,
- Development Projects,
- activity execution/instances,
- artifacts,
- voting,
- affinity boards,
- mind maps,
- patents,
- AI,
- sharing,
- live classroom.

Those belong to M4+.

---

# 4. Architectural Principle

The platform separates:

```text
PROGRAM DEFINITION
```

from:

```text
COHORT DELIVERY
```

A Program defines the educational offering.

A Curriculum Version freezes one approved curriculum structure.

A Cohort is a scheduled delivery of a Program using one specific Curriculum Version.

Conceptually:

```text
Organization: FICI
└── Program: Professional Course
    └── Curriculum Version: 2026 v1
        ├── Session 1
        ├── Session 2
        ├── ...
        └── Session 10

Cohort: Professional Course — Test Cohort
├── Program: Professional Course
├── Curriculum Version: 2026 v1
├── Primary Master
└── Enrollments
```

Do not model the course as unrelated pages.

---

# 5. Source-of-Truth Rule

Before each M3 task, Codex must read the relevant files from `/docs`.

The primary source files for M3 are:

```text
/docs/01_PRODUCT_REQUIREMENTS.md
/docs/02_PLATFORM_ARCHITECTURE.md
/docs/03_ROLES_PERMISSIONS.md
/docs/06_COURSE_ACTIVITY_WORKFLOWS.md
/docs/07_MVP_SCOPE.md
/docs/08_DATA_MODEL_SCHEMA.md
/docs/10_TECHNICAL_ARCHITECTURE.md
/docs/11_API_CONTRACTS.md
/docs/12_ACCEPTANCE_TESTS.md
/docs/13_CODEX_IMPLEMENTATION_PLAN.md
/docs/16_CODEX_M2_PROMPTS.md
```

Do not infer curriculum labels from memory when the approved course files/documents define them.

---

# 6. Global Codex Header

Use this block at the beginning of every M3 task if project rules are not automatically retained:

```text
You are implementing the FICI Invention Education & Development Platform.

Before making changes:

1. Read the relevant /docs files listed in this task.
2. Treat /docs as product and architecture source of truth.
3. Do not invent missing business rules.
4. Do not change curriculum order or labels to simplify implementation.
5. Preserve the M2 Role + Scope + Resource authorization model.
6. Never trust client-provided identity, role, enrollment, or cohort membership.
7. Use migrations for schema/database changes.
8. Use strict TypeScript.
9. Validate runtime input.
10. Use business operations rather than generic client CRUD for privileged mutations.
11. Preserve historical curriculum/cohort records.
12. Prefer archive/deactivation over destructive deletion where history matters.
13. Add RLS and server authorization for every sensitive new resource.
14. If requirements conflict or are ambiguous, STOP → FLAG → ASK.
15. Do not implement M4+ features.
16. Run required validation before finishing.
17. Report:
    - files changed,
    - migrations added,
    - seed data added,
    - business operations added,
    - RLS policies added,
    - tests run,
    - results,
    - assumptions,
    - unresolved issues.
```

---

# 7. M3.1 — Organization Foundation

## Objective

Create the minimum organization structure required by the approved schema.

## Approved Model

`organizations` fields:

- `id`
- `name`
- `slug`
- `status`
- `settings`

Initial deployment may use one FICI organization, but the model must support future expansion.

## Initial Seed

Seed:

```text
FICI
```

Use a stable slug appropriate to repository conventions.

## Copy/Paste Prompt

```text
TASK ID: M3.1
TASK: Organization Foundation

Read first:

- /docs/02_PLATFORM_ARCHITECTURE.md
- /docs/03_ROLES_PERMISSIONS.md
- /docs/08_DATA_MODEL_SCHEMA.md
- /docs/10_TECHNICAL_ARCHITECTURE.md
- /docs/16_CODEX_M2_PROMPTS.md

OBJECTIVE

Create the minimum organization foundation required for programs, cohorts, and scoped authorization.

IN SCOPE

1. Create or verify `organizations`.

Required conceptual fields:
- id
- name
- slug
- status
- settings

2. Seed the initial organization:
- FICI

3. Make the seed idempotent.

4. Add appropriate:
- unique slug constraint,
- timestamps/metadata according to repository conventions,
- archive/deactivation behavior where appropriate.

5. Integrate organization scope with the M2 authorization layer.

6. Add RLS appropriate to M3:
   - normal students must not mutate organization records,
   - ordinary authenticated users must not gain broad organization administration merely by being logged in.

7. Add tests for:
   - FICI seed exists,
   - duplicate seed does not duplicate,
   - Student cannot mutate organization,
   - authorized Admin path works.

OUT OF SCOPE

Do NOT build:
- organization settings UI,
- multi-tenant billing,
- university organization onboarding,
- organization analytics,
- organization switching UX.

VALIDATION

Run:
pnpm lint
pnpm typecheck
pnpm test:unit
pnpm test:integration
pnpm build

DEFINITION OF DONE

The FICI organization exists as the parent scope for M3 resources.

FINAL REPORT

Return:
1. Summary
2. Files changed
3. Migration(s)
4. Seed details
5. RLS/security
6. Tests/results
7. Assumptions
8. Unresolved issues
```

---

# 8. M3.2 — Program & Curriculum Version Schema

## Objective

Create Program and Curriculum Version entities so curriculum can evolve without rewriting historical cohort records.

## Approved `programs` Fields

- `id`
- `organization_id`
- `name`
- `code`
- `description`
- `program_type`
- `status`
- `current_curriculum_version_id`

Initial examples include:

```text
Innovation & Invention Workshop
Professional Course
Advanced Course
```

M3 initial seed requirement is at least:

```text
Professional Course
```

## Approved `curriculum_versions` Fields

- `id`
- `program_id`
- `version_label`
- `status`
- `effective_from`
- `effective_to`
- `notes`

Possible statuses:

```text
draft
approved
retired
```

## Historical Rule

Creating a new curriculum version must not modify old cohort curriculum references.

## Copy/Paste Prompt

```text
TASK ID: M3.2
TASK: Program & Curriculum Version Schema

Read first:

- /docs/01_PRODUCT_REQUIREMENTS.md
- /docs/02_PLATFORM_ARCHITECTURE.md
- /docs/06_COURSE_ACTIVITY_WORKFLOWS.md
- /docs/08_DATA_MODEL_SCHEMA.md
- /docs/11_API_CONTRACTS.md
- /docs/13_CODEX_IMPLEMENTATION_PLAN.md

OBJECTIVE

Implement the Program and Curriculum Version model.

IN SCOPE

1. Create `programs`.

Required conceptual fields:
- id
- organization_id
- name
- code
- description
- program_type
- status
- current_curriculum_version_id

2. Create `curriculum_versions`.

Required conceptual fields:
- id
- program_id
- version_label
- status
- effective_from
- effective_to
- notes

3. Add referential integrity between:
organization → program → curriculum version

4. Support statuses:
- draft
- approved
- retired

5. Ensure a Program can point to its current curriculum version.

6. Ensure historical cohorts can retain a prior curriculum version even after the Program current version changes.

7. Seed:
- Program: Professional Course
- Curriculum Version: 2026 v1

8. Keep seed data idempotent.

9. Add authorization:
- Admin can manage Program/Curriculum definitions,
- ordinary Student cannot mutate them.

10. Add tests for:
- program belongs to FICI,
- curriculum belongs to Professional Course,
- version labels remain distinct,
- current version pointer works,
- historical-version model is preserved,
- unauthorized mutation denied.

OUT OF SCOPE

Do NOT seed Workshop or Advanced Course unless needed for test fixtures or explicitly requested.
Do NOT implement curriculum editor UI.

VALIDATION

Run:
pnpm lint
pnpm typecheck
pnpm test:unit
pnpm test:integration
pnpm build

DEFINITION OF DONE

Professional Course exists under FICI with an approved/usable 2026 v1 curriculum version.

FINAL REPORT

Return:
1. Summary
2. Schema
3. Seed data
4. Authorization/RLS
5. Tests/results
6. Historical-version behavior
7. Assumptions
8. Unresolved issues
```

---

# 9. M3.3 — Session Definitions

## Objective

Represent the approved Professional Course as ordered session definitions.

## Approved Entity

`session_definitions`

Fields:

- `id`
- `curriculum_version_id`
- `session_number`
- `title`
- `description`
- `learning_goal`
- `sequence`
- `status`

## Required Professional Course Session Seed

Seed exactly these 10 sessions in this order:

```text
1. Think Like an Inventor
2. The SCAMPER Framework
3. SCAMPER Applied Workshop
4. Brainstorming & Problem Storming
5. Idea Evaluation & Voting
6. Affinity Diagram
7. Mind Mapping
8. Patent Document & Reading Basics
9. Patent Search & Comparative Analysis
10. AI-Assisted Invention Refinement
```

Do not rename or reorder these titles.

## Curriculum Continuity

The sequence intentionally evolves from:

```text
Inventor Mindset
→ Structured Creativity
→ Developed Concept
→ Divergence
→ Evaluation
→ Structure
→ Whole-Invention Map
→ Patent Literacy
→ Patent Search & Comparative Analysis
→ AI-Assisted Refinement
```

## Copy/Paste Prompt

```text
TASK ID: M3.3
TASK: Professional Course Session Definitions

Read first:

- /docs/06_COURSE_ACTIVITY_WORKFLOWS.md
- /docs/08_DATA_MODEL_SCHEMA.md
- /docs/13_CODEX_IMPLEMENTATION_PLAN.md

OBJECTIVE

Create and seed the ordered Professional Course 2026 v1 session definitions exactly from the approved curriculum.

IN SCOPE

1. Create `session_definitions`.

Required conceptual fields:
- id
- curriculum_version_id
- session_number
- title
- description
- learning_goal
- sequence
- status

2. Seed exactly these session titles in order:

1 Think Like an Inventor
2 The SCAMPER Framework
3 SCAMPER Applied Workshop
4 Brainstorming & Problem Storming
5 Idea Evaluation & Voting
6 Affinity Diagram
7 Mind Mapping
8 Patent Document & Reading Basics
9 Patent Search & Comparative Analysis
10 AI-Assisted Invention Refinement

3. Use the approved workflow document for learning_goal/description values where practical.

4. Add constraints preventing duplicate session number/sequence inside the same curriculum version.

5. Ensure session definitions are immutable enough that historical curriculum versions are not silently rewritten by normal cohort operations.

6. Add tests for:
- exactly 10 seeded sessions,
- correct order,
- exact titles,
- all sessions point to Professional Course 2026 v1,
- duplicate sequence rejected.

OUT OF SCOPE

Do NOT implement:
- live classes,
- session attendance,
- activity instances,
- video,
- session release scheduling UI.

VALIDATION

Run:
pnpm lint
pnpm typecheck
pnpm test:unit
pnpm test:integration
pnpm build

DEFINITION OF DONE

Professional Course 2026 v1 has the approved 10-session ordered structure.

FINAL REPORT

Return:
1. Seeded session table
2. Files/migrations changed
3. Constraints
4. Tests/results
5. Assumptions
6. Unresolved issues
```

---

# 10. M3.4 — Activity Definitions

## Objective

Define reusable curriculum activities under each session without implementing activity execution yet.

## Approved Entity

`activity_definitions`

Fields:

- `id`
- `session_definition_id`
- `name`
- `description`
- `method_type`
- `workspace_mode`
- `sequence`
- `instructions`
- `ai_role_code`
- `requires_review`
- `requires_approval`
- `completion_rule`
- `configuration`
- `status`

Possible `method_type` values include:

```text
teaching
reflection
scamper
brainstorming
problem_storming
voting
affinity
mind_map
patent_research
comparison
validation
roadmap
kanban
decision
review
custom
```

## Important Scope Rule

Detailed activity seed data may be partial in M3.

The implementation plan explicitly allows detailed activities to be initially partial seed data.

Do not invent a full activity catalog beyond what the approved curriculum supports.

## Copy/Paste Prompt

```text
TASK ID: M3.4
TASK: Activity Definition Foundation

Read first:

- /docs/06_COURSE_ACTIVITY_WORKFLOWS.md
- /docs/08_DATA_MODEL_SCHEMA.md
- /docs/09_AI_ASSISTANT_SPEC.md
- /docs/13_CODEX_IMPLEMENTATION_PLAN.md

OBJECTIVE

Create reusable Activity Definitions under Session Definitions without implementing Activity Instances.

IN SCOPE

1. Create `activity_definitions`.

Required conceptual fields:
- id
- session_definition_id
- name
- description
- method_type
- workspace_mode
- sequence
- instructions
- ai_role_code
- requires_review
- requires_approval
- completion_rule
- configuration
- status

2. Implement a controlled method_type vocabulary consistent with approved schema.

3. Seed only the minimum useful activity definitions needed to represent the Professional Course structure.

4. Prefer clear curriculum-derived activity names.

5. Do not invent business behavior for:
- review,
- approval,
- AI,
- workspace execution.

Store the definition flags/configuration only.

6. Add constraints for sequence uniqueness per session where appropriate.

7. Add tests proving:
- activity belongs to one Session Definition,
- activity ordering works,
- invalid method type is rejected,
- Student cannot mutate curriculum definition records.

OUT OF SCOPE

Do NOT implement:
- activity execution,
- activity participants,
- activity inputs/outputs,
- artifacts,
- live collaboration,
- AI invocation,
- tool UIs.

VALIDATION

Run:
pnpm lint
pnpm typecheck
pnpm test:unit
pnpm test:integration
pnpm build

DEFINITION OF DONE

The curriculum can describe structured activities without yet running them.

FINAL REPORT

Return:
1. Schema
2. Seeded activity definitions
3. method_type handling
4. Security
5. Tests/results
6. Assumptions
7. Unresolved issues
```

---

# 11. M3.5 — Activity Dependencies

## Objective

Represent curriculum sequencing and required prior outputs at the definition level.

## Approved Entity

`activity_dependencies`

Fields:

- `id`
- `activity_definition_id`
- `required_activity_definition_id`
- `dependency_type`
- `required_artifact_type`
- `is_mandatory`

Possible dependency types:

```text
completion
approved_output
artifact_available
gate_passed
```

## Approved Curriculum Principle

An activity may specify:

- Required Inputs
- Optional Inputs
- Output Artifact Type
- Required Review
- Completion Condition
- Next Activity Dependency

Example:

```text
Professional Session 4
Input: Developed Concept V2
Output: Problem Bank + Solution Bank

Professional Session 5
Required Input: Problem Bank + Solution Bank
Output: Team Decision Record
```

## Copy/Paste Prompt

```text
TASK ID: M3.5
TASK: Activity Dependencies

Read first:

- /docs/06_COURSE_ACTIVITY_WORKFLOWS.md
- /docs/08_DATA_MODEL_SCHEMA.md
- /docs/12_ACCEPTANCE_TESTS.md

OBJECTIVE

Create curriculum-level dependency definitions between activities.

IN SCOPE

1. Create `activity_dependencies`.

Required conceptual fields:
- id
- activity_definition_id
- required_activity_definition_id
- dependency_type
- required_artifact_type
- is_mandatory

2. Support dependency types:
- completion
- approved_output
- artifact_available
- gate_passed

3. Add referential integrity between dependent activities.

4. Prevent obvious self-dependency.

5. Prevent duplicate dependency records.

6. Seed only dependencies clearly supported by the approved curriculum.

7. At minimum preserve the Professional Course sequencing logic where:
- Session 4 outputs feed Session 5,
- Session 6 outputs feed Session 7,
- Session 8 prepares Session 9,
- Session 9 Patent Landscape Snapshot feeds Session 10.

8. Do not enforce runtime dependencies yet; M7 Activity Engine owns execution.

9. Add tests for:
- valid dependency creation,
- self-dependency rejected,
- invalid activity ID rejected,
- duplicate dependency rejected.

OUT OF SCOPE

- activity runtime gating,
- artifact runtime resolution,
- development gate execution.

VALIDATION

Run:
pnpm lint
pnpm typecheck
pnpm test:unit
pnpm test:integration
pnpm build

DEFINITION OF DONE

The approved curriculum can express definition-level prerequisites without implementing runtime activities.

FINAL REPORT

Return:
1. Dependencies seeded
2. Files/migrations
3. Constraints
4. Tests/results
5. Deferred runtime behavior
6. Assumptions
7. Unresolved issues
```

---

# 12. M3.6 — Cohort Schema & Operations

## Objective

Create scheduled delivery instances of a Program and Curriculum Version.

## Approved Entity

`cohorts`

Fields:

- `id`
- `program_id`
- `curriculum_version_id`
- `name`
- `start_date`
- `end_date`
- `status`
- `primary_master_id`
- `settings`

## Approved API Operations

### `createCohort(input)`

Input:

```text
programId
curriculumVersionId
name
startDate
endDate optional
primaryMasterId
```

Authorization:

```text
Admin
```

### `updateCohort(input)`

Authorization:

```text
Admin
or appropriately scoped Master for limited fields
```

Do not invent which Master-editable fields are allowed if docs do not specify them.

If unresolved:

```text
Admin-only update for M3
or STOP → FLAG → ASK
```

Do not silently broaden Master authority.

## Copy/Paste Prompt

```text
TASK ID: M3.6
TASK: Cohort Schema & Operations

Read first:

- /docs/03_ROLES_PERMISSIONS.md
- /docs/08_DATA_MODEL_SCHEMA.md
- /docs/11_API_CONTRACTS.md
- /docs/12_ACCEPTANCE_TESTS.md
- /docs/16_CODEX_M2_PROMPTS.md

OBJECTIVE

Implement cohort creation and retrieval with secure Program/Curriculum linkage.

IN SCOPE

1. Create `cohorts`.

Required conceptual fields:
- id
- program_id
- curriculum_version_id
- name
- start_date
- end_date
- status
- primary_master_id
- settings

2. Add foreign keys to:
- programs
- curriculum_versions
- primary Master user/profile identity

3. Validate:
- curriculum version belongs to selected program,
- end_date is not before start_date where both exist,
- primaryMasterId references a valid user,
- selected Master has or receives the correct scoped MASTER assignment according to approved authorization flow.

4. Implement:
- createCohort(input)
- getCohort(id)
- list authorized cohorts
- updateCohort(input) only within approved authority

5. Admin creates cohorts.

6. Do not trust primaryMasterId from client without validation.

7. Ensure Master cannot manage unrelated cohort.

8. Add RLS so:
- Student does not gain broad cohort administration,
- Master sees/manages only assigned scope,
- unrelated Master access is denied.

9. Add audit event only if the audit foundation already exists safely; otherwise document deferral to the milestone that owns audit infrastructure.

10. Add tests for:
- Admin creates cohort,
- invalid curriculum/program pairing rejected,
- unrelated Master denied,
- Student denied administration,
- assigned Master can read authorized cohort,
- cohort keeps fixed curriculum_version_id even if Program current version later changes.

OUT OF SCOPE

- teams,
- workspaces,
- live rooms,
- attendance,
- calendar integration.

VALIDATION

Run:
pnpm lint
pnpm typecheck
pnpm test:unit
pnpm test:integration
pnpm test:e2e
pnpm build

DEFINITION OF DONE

Admin can create a Professional Course cohort tied to a specific curriculum version and scoped Master.

FINAL REPORT

Return:
1. Operations added
2. Validation rules
3. Authorization/RLS
4. Files/migrations
5. Tests/results
6. Audit behavior
7. Assumptions
8. Unresolved issues
```

---

# 13. M3.7 — Enrollment Schema & Operations

## Objective

Enroll users into a cohort without losing historical participation records when access ends.

## Approved Entity

`enrollments`

Fields:

- `id`
- `cohort_id`
- `user_id`
- `enrollment_role`
- `status`
- `joined_at`
- `completed_at`

Possible statuses:

```text
invited
active
completed
withdrawn
removed
```

## Approved API Operation

### `enrollUser(input)`

Input:

```text
cohortId
userId
enrollmentRole
```

Authorization:

```text
Admin
assigned Master according to policy
```

Rule:

```text
Must not duplicate active enrollment.
```

### `removeEnrollment(input)`

Required behavior:

```text
Removal affects future access.
Historic work must remain preserved.
Audit required.
```

If audit infrastructure is not yet present, do not fake it; document the deferred audit event while preserving the data behavior.

## Copy/Paste Prompt

```text
TASK ID: M3.7
TASK: Enrollment Schema & Operations

Read first:

- /docs/03_ROLES_PERMISSIONS.md
- /docs/08_DATA_MODEL_SCHEMA.md
- /docs/11_API_CONTRACTS.md
- /docs/12_ACCEPTANCE_TESTS.md
- /docs/16_CODEX_M2_PROMPTS.md

OBJECTIVE

Implement secure cohort enrollment and enrollment lifecycle.

IN SCOPE

1. Create `enrollments`.

Required conceptual fields:
- id
- cohort_id
- user_id
- enrollment_role
- status
- joined_at
- completed_at

2. Support statuses:
- invited
- active
- completed
- withdrawn
- removed

3. Add referential integrity to:
- cohort
- user/profile

4. Prevent duplicate active enrollment for the same user/cohort.

5. Implement:
- enrollUser(input)
- removeEnrollment(input)
- listCohortEnrollments(cohortId)
- listMyEnrollments()

6. Authorization:
- Admin may enroll/remove,
- assigned Master may act only where approved by existing policy,
- Student cannot enroll themselves through privileged mutation,
- unrelated Master cannot modify cohort enrollment.

7. Removal must:
- revoke future course access according to enrollment state,
- preserve enrollment/history,
- not delete user account,
- not imply deletion of future authored project history.

8. Add tests for:
- valid enrollment,
- duplicate active enrollment rejected,
- removed enrollment no longer treated as active,
- historical enrollment row remains,
- Student cannot self-enroll by direct mutation,
- unrelated Master denied,
- assigned Master scope respected.

OUT OF SCOPE

- Team membership,
- Personal Workspace provisioning,
- Project membership,
- certificate completion logic.

VALIDATION

Run:
pnpm lint
pnpm typecheck
pnpm test:unit
pnpm test:integration
pnpm test:e2e
pnpm build

DEFINITION OF DONE

Users can be securely enrolled and removed from a cohort while preserving historical enrollment records.

FINAL REPORT

Return:
1. Enrollment schema
2. Lifecycle rules
3. Operations
4. RLS/security
5. Tests/results
6. History-preservation behavior
7. Assumptions
8. Unresolved issues
```

---

# 14. M3.8 — Primary Master Assignment Integration

## Objective

Connect Cohort ownership/supervision to the M2 scoped MASTER role system.

## Required Model

A cohort has:

```text
primary_master_id
```

The authorization system also requires scoped role assignment.

Do not rely only on the `primary_master_id` column for authorization.

The correct pattern is:

```text
Cohort.primary_master_id
+
MASTER scoped role assignment
+
server authorization
+
RLS
```

## Copy/Paste Prompt

```text
TASK ID: M3.8
TASK: Primary Master Assignment Integration

Read first:

- /docs/03_ROLES_PERMISSIONS.md
- /docs/08_DATA_MODEL_SCHEMA.md
- /docs/11_API_CONTRACTS.md
- /docs/16_CODEX_M2_PROMPTS.md

OBJECTIVE

Integrate primary cohort Master assignment with the scoped M2 authorization model.

IN SCOPE

1. Ensure `primary_master_id` does not act as an authorization bypass.

2. When a cohort is created/assigned:
   - verify the target user,
   - create or validate MASTER scope for that cohort,
   - preserve idempotency.

3. If primary Master changes:
   - define safe reassignment behavior,
   - do not silently leave stale broad access,
   - preserve assignment history where supported.

4. Add an explicit `assignMasterToCohort()` business operation if consistent with API architecture.

5. Add tests:
   - assigned Master can access own cohort,
   - same Master cannot access unrelated cohort,
   - Student cannot assign Master,
   - client spoofed role has no effect,
   - reassignment updates effective authorization correctly.

IMPORTANT

Do not infer that cohort MASTER automatically gains:
- Personal Workspace access,
- future Team access outside assigned cohort,
- educational approval beyond later workflow rules.

OUT OF SCOPE

- Mentor assignment to teams,
- Team Master mapping,
- Case Study Workspace.

VALIDATION

Run:
pnpm lint
pnpm typecheck
pnpm test:unit
pnpm test:integration
pnpm test:e2e
pnpm build

DEFINITION OF DONE

Primary Master display/reference and actual authorization remain synchronized without bypassing M2.

FINAL REPORT

Return:
1. Assignment approach
2. Operations
3. Role-assignment behavior
4. Tests/results
5. Assumptions
6. Unresolved issues
```

---

# 15. M3.9 — Professional Course Seed Validation

## Objective

Validate that the seeded curriculum matches the approved Professional Course structure.

## Required Seed Minimum

```text
Organization:
FICI

Program:
Professional Course

Curriculum Version:
2026 v1

Sessions:
1 Think Like an Inventor
2 The SCAMPER Framework
3 SCAMPER Applied Workshop
4 Brainstorming & Problem Storming
5 Idea Evaluation & Voting
6 Affinity Diagram
7 Mind Mapping
8 Patent Document & Reading Basics
9 Patent Search & Comparative Analysis
10 AI-Assisted Invention Refinement
```

## Key Curriculum Dependencies to Preserve

Examples supported by the workflow:

```text
Session 4
Developed Concept V2
→ Problem Bank + Solution Bank

Session 5
Problem Bank + Solution Bank
→ Team Decision Record
```

```text
Session 6
Organized invention structure
→ Session 7 whole-invention map
```

```text
Session 8
Patent Reading Framework
→ Session 9 Patent Search & Comparative Analysis
```

```text
Session 9
Patent Landscape Snapshot
→ Session 10 AI-Assisted Invention Refinement
```

## Copy/Paste Prompt

```text
TASK ID: M3.9
TASK: Professional Course Seed Validation

Read first:

- /docs/06_COURSE_ACTIVITY_WORKFLOWS.md
- /docs/08_DATA_MODEL_SCHEMA.md
- /docs/13_CODEX_IMPLEMENTATION_PLAN.md

OBJECTIVE

Validate seeded Professional Course curriculum data against approved FICI source-of-truth documents.

CHECK

1. Organization = FICI.
2. Program = Professional Course.
3. Curriculum Version = 2026 v1.
4. Exactly 10 Professional Course sessions exist.
5. Session order is 1 through 10 with no gaps.
6. Session titles exactly match approved labels.
7. Every Session points to the correct Curriculum Version.
8. Seed is idempotent.
9. Defined activity/dependency seed data does not contradict course workflow.
10. No Workshop or Advanced Course data was invented unless explicitly added as a documented fixture.

TEST

Create automated seed validation where practical.

Do not silently “improve” names, reorder sessions, or merge sessions.

DEFINITION OF DONE

The database curriculum matches the approved Professional Course structure.

FINAL REPORT

Return:
1. Curriculum validation table
2. PASS/FAIL
3. Any discrepancy
4. Files changed
5. Tests/results
```

---

# 16. M3.10 — Cohort & Enrollment Acceptance Tests

## Objective

Prove that the platform can securely create a Professional Course cohort and enroll authorized users.

## Required M3 Acceptance Scenario

At minimum support the beginning of the approved end-to-end scenario:

```text
1. Admin creates Professional Course cohort.
2. Master adds four students.
```

M5 will continue with:

```text
3. Master creates Team A and Team B.
```

Do not implement step 3 during M3.

## Mandatory Security Coverage

Test:

```text
Admin → create cohort = ALLOW
Student → create cohort = DENY
Assigned Master → read assigned cohort = ALLOW
Master → unrelated cohort = DENY
Admin → enroll user = ALLOW
Assigned Master → enroll user if current approved policy allows = ALLOW
Unrelated Master → enroll user = DENY
Student → self-enroll privileged path = DENY
Removed enrollment → future access denied
Historical enrollment → preserved
```

## Copy/Paste Prompt

```text
TASK ID: M3.10
TASK: M3 Acceptance Tests

Read first:

- /docs/12_ACCEPTANCE_TESTS.md
- /docs/03_ROLES_PERMISSIONS.md
- /docs/11_API_CONTRACTS.md
- /docs/16_CODEX_M2_PROMPTS.md
- /docs/17_CODEX_M3_PROMPTS.md

OBJECTIVE

Add automated acceptance coverage for Program/Curriculum/Cohort/Enrollment behavior.

TEST FIXTURE

Use:
- Admin
- Master
- Student A1
- Student A2
- Student B1
- Student B2

Create:
- Professional Course — Test Cohort

REQUIRED TESTS

1. Admin creates Professional Course cohort.
2. Cohort points to Professional Course 2026 v1.
3. Assigned Master can access Test Cohort.
4. Unrelated Master cannot access another cohort.
5. Admin enrolls four students.
6. Duplicate active enrollment fails.
7. Student cannot self-administer enrollment.
8. Removed enrollment is no longer active.
9. Removed enrollment history remains.
10. Curriculum version remains stable if Program current version changes later.
11. Direct database/RLS access does not bypass the same rules.

Do NOT create Teams yet.

RUN

pnpm lint
pnpm typecheck
pnpm test:unit
pnpm test:integration
pnpm test:e2e
pnpm build

Run configured Supabase/RLS tests.

DEFINITION OF DONE

The first two steps of AT-E2E-001 are securely supported and M3 does not implement later workflow steps.

FINAL REPORT

Return:
1. Test matrix
2. PASS/FAIL
3. Files changed
4. Commands/results
5. Remaining issues
```

---

# 17. M3.11 — M3 Security Hardening

## Objective

Review M3 for curriculum integrity, cohort isolation, enrollment escalation, and authorization consistency.

## Required Negative Tests

Attempt:

```text
STUDENT → create cohort
STUDENT → change curriculum
STUDENT → change Program current curriculum version
STUDENT → enroll self
STUDENT → enroll another user
MASTER Cohort A → update Cohort B
MASTER Cohort A → enroll into Cohort B
CLIENT → fake cohort scope
CLIENT → fake enrollment role
CLIENT → direct database mutation
REMOVED ENROLLMENT → access cohort as active student
```

All must fail where not explicitly authorized.

## Curriculum Integrity Tests

Attempt:

```text
Cohort → curriculum version from another Program
Duplicate session number in same curriculum
Duplicate sequence in same curriculum
Delete curriculum version used by historical cohort
Silently rewrite old cohort to new curriculum
```

These must be rejected or safely prevented according to schema rules.

## Copy/Paste Prompt

```text
TASK ID: M3.11
TASK: M3 Security & Integrity Hardening

Read first:

- /docs/03_ROLES_PERMISSIONS.md
- /docs/06_COURSE_ACTIVITY_WORKFLOWS.md
- /docs/08_DATA_MODEL_SCHEMA.md
- /docs/11_API_CONTRACTS.md
- /docs/12_ACCEPTANCE_TESTS.md
- /docs/16_CODEX_M2_PROMPTS.md
- /docs/17_CODEX_M3_PROMPTS.md

OBJECTIVE

Perform a security and data-integrity review of M3 only.

VERIFY

1. Program/Curriculum relations are valid.
2. Cohort must use Curriculum Version belonging to its Program.
3. Historical cohort curriculum reference cannot drift automatically.
4. Unauthorized curriculum mutation fails.
5. Unauthorized cohort administration fails.
6. Unauthorized enrollment mutation fails.
7. Removed/withdrawn enrollment does not behave as active.
8. M2 scope authorization remains authoritative.
9. RLS blocks direct client bypass.
10. No M4+ resources were added.

RUN

pnpm lint
pnpm typecheck
pnpm test:unit
pnpm test:integration
pnpm test:e2e
pnpm build

Run all configured database/RLS tests.

DEFINITION OF DONE

M3 is complete only when:
- curriculum integrity tests pass,
- cohort isolation tests pass,
- enrollment escalation tests pass,
- no known BLOCKER remains.

FINAL REPORT

Return:
1. Security review summary
2. Integrity issues found
3. Issues fixed
4. Remaining issues
5. Test results
6. Recommendation: READY FOR M4 or NOT READY FOR M4
```

---

# 18. Enrollment Role vs Platform Role

Do not conflate:

```text
platform role
```

with:

```text
enrollment_role
```

Examples:

A user may have:

```text
Platform Role: STUDENT
Enrollment Role: participant
```

or:

```text
Platform Role: MASTER
Enrollment/Cohort Relation: instructor/master
```

The exact enrollment_role vocabulary should follow approved docs or be kept minimal if not fully defined.

Do not replace M2 role authorization with enrollment_role.

---

# 19. Course Material Access Principle

Course-material access may depend on:

- enrollment,
- program,
- session release,
- instructor publication,
- cohort schedule.

M3 only establishes the structural basis.

M3 does not need to implement final content-release logic.

Important:

```text
Course material access
≠
access to another user's project content
```

Later workspace/project permission boundaries remain separate.

---

# 20. Curriculum Definition vs Activity Instance

M3 defines:

```text
Activity Definition
```

M7 later creates:

```text
Activity Instance
```

Do not confuse them.

Example:

```text
Activity Definition:
Session 5 — Dot Voting
```

Later:

```text
Activity Instance:
Team A / Fall Cohort / Session 5 / Dot Voting Run #1
```

M3 stores the reusable educational blueprint.

M7 stores actual execution.

---

# 21. Cohort Curriculum Lock Principle

When a cohort is created:

```text
Cohort
→ curriculum_version_id
```

must be explicit.

If the Program later changes:

```text
current_curriculum_version_id
```

the old Cohort must continue pointing to its original version.

This prevents historical inconsistency.

---

# 22. Archive / Removal Rules

For M3:

### Program / Curriculum
Do not destructively delete records that are referenced by Cohorts.

### Cohort
Prefer status/archive behavior over destructive deletion once used.

### Enrollment
Removing a learner should update enrollment lifecycle/status rather than erase history.

Future project/artifact authorship must remain preservable.

---

# 23. M3 Expected Repository Additions

Conceptually:

```text
features/
├── programs/
├── curriculum/
├── cohorts/
└── enrollments/

lib/
├── permissions/
├── validation/
└── db/

supabase/
├── migrations/
│   ├── organizations
│   ├── programs
│   ├── curriculum_versions
│   ├── session_definitions
│   ├── activity_definitions
│   ├── activity_dependencies
│   ├── cohorts
│   ├── enrollments
│   └── m3_rls
└── tests/
    └── rls/

tests/
├── unit/
│   ├── curriculum/
│   └── enrollment/
├── integration/
│   ├── cohorts/
│   └── enrollments/
└── e2e/
    └── cohort-enrollment.spec.ts
```

Exact names may vary.

---

# 24. M3 Completion Gate

M3 is complete only when:

```text
[ ] FICI organization exists

[ ] Professional Course program exists
[ ] Professional Course 2026 v1 curriculum exists
[ ] Program/Curriculum relationship is valid

[ ] session_definitions exists
[ ] exactly 10 Professional Course sessions seeded
[ ] session titles match approved curriculum
[ ] session order is correct

[ ] activity_definitions exists
[ ] minimum curriculum-derived activity definitions seeded
[ ] activity_dependencies exists
[ ] only supported dependencies seeded

[ ] cohorts exists
[ ] cohort points to Program
[ ] cohort points to fixed Curriculum Version
[ ] primary Master integrated with M2 authorization

[ ] enrollments exists
[ ] duplicate active enrollment blocked
[ ] enrollment lifecycle works
[ ] removed enrollment history preserved

[ ] Admin can create cohort
[ ] Student cannot create cohort
[ ] Admin can enroll users
[ ] Student cannot self-escalate enrollment
[ ] assigned Master scope works
[ ] unrelated Master denied

[ ] curriculum mutation protected by RLS/server checks
[ ] cohort mutation protected by RLS/server checks
[ ] enrollment mutation protected by RLS/server checks

[ ] lint passes
[ ] typecheck passes
[ ] unit tests pass
[ ] integration tests pass
[ ] E2E tests pass
[ ] database/RLS tests pass
[ ] build passes

[ ] no M4+ feature implemented prematurely
[ ] Codex reports READY FOR M4
```

Any open security/integrity BLOCKER means:

```text
NOT READY FOR M4
```

---

# 25. Recommended Commit Sequence

Example:

```text
feat(org): add FICI organization foundation
feat(programs): add programs and curriculum versions
feat(curriculum): add Professional Course sessions
feat(curriculum): add activity definitions and dependencies
feat(cohorts): add cohort model and operations
feat(enrollments): add enrollment lifecycle
feat(authz): integrate primary Master cohort scope
test(curriculum): validate Professional Course 2026 v1 seed
test(cohorts): add cohort and enrollment acceptance coverage
chore(security): complete M3 hardening
```

---

# 26. M3 Non-Goals

Do not accept these as “helpful additions” during M3:

- course dashboard polish,
- LMS-style content player,
- video classroom,
- attendance tracking,
- Personal Workspace,
- Team Workspace,
- Team management,
- Team Chat,
- activity execution,
- Development Project creation,
- artifacts,
- SCAMPER tool UI,
- voting UI,
- affinity UI,
- mind map UI,
- patent search integration,
- AI assistant,
- notifications,
- certificates,
- payments,
- public course catalog,
- final design system.

---

# 27. Potential M3 Ambiguities Codex Must Flag

Do not silently decide if the approved documents do not resolve:

- exact `program_type` vocabulary,
- exact `enrollment_role` vocabulary,
- whether Master can invite/enroll students directly in M3,
- which cohort fields a Master may edit,
- whether a Cohort can have multiple Masters in M3,
- whether primary Master reassignment should deactivate old cohort scope automatically,
- whether students may see future unreleased session definitions,
- exact session publication/release rules,
- whether curriculum definitions can be edited after approval,
- whether approved curriculum version should be immutable,
- whether retired curriculum can still be used for a new Cohort,
- whether cohort end date is required,
- whether completed enrollment still grants read-only course access,
- whether withdrawn vs removed have different access semantics,
- whether enrollment invites require acceptance,
- whether curriculum seed descriptions must reproduce course document wording exactly or may be concise summaries,
- whether activity definitions should be fully seeded now or incrementally in later tool milestones.

If unresolved:

```text
STOP → FLAG → ASK
```

---

# 28. Recommended Safe Defaults for Purely Technical Decisions

Only where they do not alter approved product policy:

- stable UUID identifiers,
- idempotent seed scripts,
- unique Program code within Organization,
- unique Curriculum version label within Program,
- unique session number within Curriculum Version,
- unique session sequence within Curriculum Version,
- no destructive deletion of curriculum used by Cohorts,
- no broad authenticated client write access,
- server business commands for cohort/enrollment mutation,
- RLS on all sensitive M3 tables,
- archive/status lifecycle rather than hard delete,
- deterministic test cohort fixtures.

---

# 29. Review Checklist for Ahmad/FICI

Before implementation, confirm M3 reflects the intended educational structure:

```text
1. FICI is the initial organization.

2. Professional Course is the first fully seeded Program.

3. Curriculum Version 2026 v1 is explicit.

4. The Professional Course has 10 sessions.

5. The 10 approved titles and order remain unchanged.

6. Activities are definitions only in M3.

7. Runtime activity execution comes later.

8. A Cohort is tied to one specific Curriculum Version.

9. New curriculum versions must not rewrite old cohorts.

10. Admin can create cohorts.

11. Cohort Master access remains scoped.

12. Enrollment controls course participation.

13. Removing enrollment affects future access, not historical authorship.

14. M3 does not yet create Teams or Workspaces.
```

---

# 30. Next File After M3

After M3 has actually been:

```text
IMPLEMENTED
→ TESTED
→ SECURITY-REVIEWED
→ COMMITTED
```

create:

# `18_CODEX_M4_PROMPTS.md`

M4 will cover:

```text
Personal Workspace
Team Workspace schema foundation
Master Workspace
Shared Workspace
Case Study Workspace
workspace access resolution
Personal Workspace privacy
```

The next milestone must build on M2/M3 authorization and enrollment data.

---

# 31. Final Execution Rule

For M3:

```text
ORGANIZATION
→ PROGRAM
→ CURRICULUM VERSION
→ SESSIONS
→ ACTIVITY DEFINITIONS
→ DEPENDENCIES
→ COHORT
→ ENROLLMENT
→ MASTER SCOPE
→ ACCEPTANCE TESTS
→ SECURITY HARDENING
```

Do not skip directly to Teams, Workspaces, Projects, or AI.

---

# End of Document

**Current Status:** Draft v0.1 — Ready for Ahmad/FICI review.  
**Execution Step After M2 Completion:** Start with **M3.1 — Organization Foundation**.
