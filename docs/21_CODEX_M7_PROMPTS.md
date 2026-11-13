# FICI Invention Education & Development Platform
## Codex M7 Execution Prompts — Activity Engine

**Document:** `21_CODEX_M7_PROMPTS.md`  
**Status:** Draft v0.1 — For Review  
**Depends on:** `01_PRODUCT_REQUIREMENTS.md` through `20_CODEX_M6_PROMPTS.md`  
**Purpose:** Provide exact copy/paste prompts for Codex to implement Milestone M7 safely and incrementally after M6 is complete.

---

# 1. Preconditions

Do not begin M7 until M6 is:

```text
IMPLEMENTED
→ TESTED
→ SECURITY-REVIEWED
→ COMMITTED
```

Required M6 state:

- Development Projects exist,
- Project Membership exists,
- Program/Project links exist,
- Development Objects exist,
- Object Relationships exist,
- Project/Object RLS works,
- cross-session object reuse works,
- cross-program Project continuity is supported,
- AT-PROJ-001 passes,
- AT-PROJ-002 passes,
- AT-PROJ-003 architecture passes,
- Codex reports READY FOR M7.

If M6 is incomplete:

```text
STOP → FINISH M6 → REVIEW → COMMIT → BEGIN M7
```

M7 must consume the approved M3 curriculum definitions and the M4–M6 Workspace/Project foundations rather than creating a parallel workflow system.

---

# 2. M7 Goal

M7 connects curriculum definitions to actual user/team Project work.

Conceptually:

```text
ACTIVITY DEFINITION
↓
AUTHORIZATION + AVAILABILITY
↓
DEPENDENCY CHECK
↓
ACTIVITY INSTANCE
├── PARTICIPANTS
├── INPUTS
├── CURRENT STATUS
├── CONFIGURATION SNAPSHOT
└── OUTPUTS
↓
COMPLETION
↓
NEXT ACTIVITY BECOMES ELIGIBLE
```

The core principle is:

# DEFINITION ≠ INSTANCE

M3 defines reusable curriculum activities.

M7 records actual execution of those activities by a user/team in a real Project/Workspace context.

---

# 3. M7 Product Boundary

M7 includes:

- `activity_instances`,
- `activity_participants`,
- `activity_inputs`,
- `activity_outputs`,
- Activity status lifecycle,
- start Activity,
- resume Activity,
- complete Activity,
- add input,
- add output,
- dependency evaluation,
- availability evaluation,
- configuration snapshot,
- participant authorization,
- Project/Workspace/Team scope validation,
- RLS,
- activity acceptance tests.

M7 does **not** yet implement:

- SCAMPER data model/runtime,
- Brainstorming entries,
- Voting,
- Affinity,
- Mind Maps,
- Artifact Versioning,
- formal Submission/Review/Approval,
- Evidence,
- Patent Workspace,
- AI,
- Sharing.

Those later features plug into the generic Activity Engine.

---

# 4. Approved Activity Instance Schema

Implement:

```text
activity_instances
```

Fields:

- `id`
- `activity_definition_id`
- `cohort_id`
- `project_id`
- `workspace_id`
- `team_id` nullable
- `started_by`
- `started_at`
- `completed_at`
- `status`
- `configuration_snapshot`

Approved statuses:

```text
not_started
active
submitted
under_review
revision_requested
completed
archived
```

M7 does not yet implement the full review system.

Therefore `submitted`, `under_review`, and `revision_requested` may be schema-supported but their business transitions should remain deferred until M8 unless an approved generic Activity flow requires them now.

---

# 5. Activity Participants

Implement:

```text
activity_participants
```

Fields:

- `id`
- `activity_instance_id`
- `user_id`
- `participant_role`
- `joined_at`
- `completed_at`

This table records actual participants in one Activity execution.

Participant access must still respect:

- Workspace scope,
- Team membership where applicable,
- Project access,
- Cohort enrollment,
- role/scope policy.

A row in `activity_participants` must not become an authorization bypass.

---

# 6. Activity Inputs

Implement:

```text
activity_inputs
```

Fields:

- `id`
- `activity_instance_id`
- `input_type`
- `artifact_id` nullable
- `artifact_version_id` nullable
- `development_object_id` nullable
- `evidence_id` nullable
- `required`

M7 currently has:

- Development Objects.

M8 later adds Artifacts/Versions.

M12 later adds Evidence.

Therefore:

- keep all approved fields,
- use `development_object_id` fully now,
- keep future fields nullable,
- defer foreign keys where target tables do not yet exist,
- document those deferred constraints,
- do not create Artifact/Evidence schema early.

---

# 7. Activity Outputs

Implement:

```text
activity_outputs
```

Fields:

- `id`
- `activity_instance_id`
- `output_type`
- `artifact_id` nullable
- `development_object_id` nullable
- `decision_id` nullable
- `evidence_id` nullable

M7 currently supports Development Objects as real structured outputs.

Artifact/Decision/Evidence outputs become fully operational in later milestones.

Preserve the approved columns without inventing future tables.

---

# 8. Activity Definition Source

Every Activity Instance must come from:

```text
activity_definitions
```

created in M3.

Do not allow arbitrary runtime Activity types disconnected from curriculum definitions.

An Activity Definition may include:

- method type,
- Workspace mode,
- instructions,
- AI role code,
- requires review,
- requires approval,
- completion rule,
- configuration,
- sequence,
- status.

M7 must read this definition and create a runtime snapshot.

---

# 9. Configuration Snapshot

`configuration_snapshot` exists so a running or completed Activity remains historically understandable even if the Activity Definition changes later.

At Activity start:

```text
Activity Definition current configuration
↓
immutable execution snapshot
```

The snapshot may include relevant fields such as:

- method type,
- Workspace mode,
- instructions,
- completion rule,
- requires review,
- requires approval,
- Activity-specific configuration.

Do not use snapshot data as a replacement for stable Definition identity.

---

# 10. Generic Course Workflow Context

The approved course workflow conceptually includes:

```text
SESSION OPENS
↓
Review Previous Approved Output
↓
Teach Method / Concept
↓
Instructor Case Study
↓
Individual or Team Practice
↓
Apply to Development Project
↓
AI Assistance where appropriate
↓
Team Review / Decision
↓
Save Structured Output
↓
Submit / Share with Master
↓
Instructor Feedback
↓
Revision if needed
↓
Approved / Current Output
↓
Feeds Next Session
```

Not every Activity uses every step.

M7 implements the generic execution spine, not every specialized tool or review workflow.

---

# 11. Dependency Principle

Activities may depend on:

- required prior completion,
- approved output,
- artifact availability,
- gate passed.

Approved dependency types:

```text
completion
approved_output
artifact_available
gate_passed
```

These originate from M3:

```text
activity_dependencies
```

M7 must evaluate dependencies server-side.

Do not rely on frontend buttons being disabled.

---

# 12. Important Dependency Limitation

Some dependency types rely on future features:

## `completion`

Can be fully implemented in M7.

## `approved_output`

M8 owns Approval/Artifact Versioning.

M7 should support the dependency type and evaluator interface.

If the required approved-output target does not yet exist:

```text
dependency unsatisfied
```

unless a clearly approved M7 fixture/simplified equivalent exists.

Do not fake approval.

## `artifact_available`

M8 owns Artifacts.

Support schema/evaluator extension point; full behavior activates in M8.

## `gate_passed`

Development Gates are not part of current M7 MVP implementation.

Support the dependency type structurally.

Do not create a fake Gate subsystem.

---

# 13. Course Dependency Example

Approved workflow example:

```text
Professional Session 4
Input: Developed Concept V2
Output: Problem Bank + Solution Bank

Professional Session 5
Required Input: Problem Bank + Solution Bank
Output: Team Decision Record
```

M7 must support this architecture.

The specific Artifact records become fully functional after M8.

---

# 14. Activity Availability

Before start, the engine must verify:

- Activity Definition exists,
- Definition is enabled/available,
- Curriculum/Cohort relation is valid,
- user has Project access,
- user has Workspace access,
- Team access is valid where team-scoped,
- dependencies are satisfied,
- no disallowed duplicate active instance exists.

Availability is a server-side determination.

---

# 15. Duplicate Active Activity Rule

Approved API rule:

```text
do not create duplicate active instance
unless Activity allows it
```

Therefore M7 needs a generic duplicate policy.

The rule should derive from Activity Definition configuration where available.

If exact repeatability settings are not defined:

Default safe behavior:

```text
one active instance for same
activity_definition + project + workspace + team context
```

unless the approved Activity Definition configuration explicitly permits more.

Do not invent method-specific exceptions.

---

# 16. Activity Status Lifecycle

M7 should safely support a lifecycle conceptually similar to:

```text
not_started
↓
active
↓
completed
```

with schema support for later:

```text
submitted
under_review
revision_requested
archived
```

Do not force every Activity through submission/review states.

M8 will own formal Review/Approval workflows.

---

# 17. Start Activity Contract

Approved operation:

```text
startActivity(input)
```

Input:

```text
activityDefinitionId
projectId
workspaceId
teamId optional
```

Rules:

- Activity available,
- dependencies satisfied,
- user authorized,
- duplicate active instance prevented unless allowed.

Output:

```text
Activity Instance
```

---

# 18. Resume Activity Contract

Approved:

```text
resumeActivity(activityInstanceId)
```

Returns:

- definition,
- instructions,
- required inputs,
- current outputs,
- participants,
- status,
- AI role.

M7 must return only data the requester is authorized to access.

Resume must not mutate or recreate the Activity.

---

# 19. Complete Activity Contract

Approved:

```text
completeActivity(activityInstanceId)
```

Rules:

- completion requirements satisfied.

May trigger:

- submission availability,
- progress update,
- dependent Activity unlock.

M7 can implement:

- status update,
- completed_at,
- dependency eligibility changes.

Formal submission/review side effects belong to M8.

---

# 20. Add Activity Input Contract

Approved:

```text
addActivityInput(input)
```

Purpose:

Link an approved/allowed:

- Development Object now,
- Artifact later,
- Artifact Version later,
- Evidence later.

M7 must validate:

- source entity exists,
- source is accessible to user,
- source belongs to acceptable Project/Workspace scope,
- input type is compatible with Activity Definition/dependency requirement,
- user cannot reference inaccessible Team/Personal data.

---

# 21. Add Activity Output Contract

Approved:

```text
addActivityOutput(input)
```

Registers a structured output produced by the Activity.

In M7:

Primary real output:

```text
development_object_id
```

Future:

- artifact,
- decision,
- evidence.

Output registration must preserve provenance:

```text
Activity Instance
→ Output Link
→ Development Object
```

Do not duplicate the Development Object itself.

---

# 22. Activity Security Rule

Activity authorization must use:

```text
Role
+
Enrollment
+
Workspace Access
+
Project Access
+
Team Membership / Scope
+
Activity Participant Context
+
Activity Definition Availability
```

A participant row by itself is insufficient.

No same-Cohort wildcard access.

No same-Program wildcard access.

---

# 23. Personal Activity Security

An Activity running in Personal Workspace:

- owner can access,
- other Students cannot,
- Master does not automatically gain access,
- Team does not automatically gain access.

This must preserve M4 privacy.

Future submission/share can expose selected outputs, not the entire Personal Activity history.

---

# 24. Team Activity Security

An Activity running in Team Workspace:

- active Team members may participate according to Activity Definition,
- assigned Master may access according to approved educational role,
- assigned Mentor only when scope permits,
- Team B cannot access Team A Activity Instance,
- removed members lose future access.

This must preserve M5 security.

---

# 25. Project Continuity Rule

Activity Instances do not own the Project.

They operate on the persistent Project.

Conceptually:

```text
Project A
├── Activity Instance S4
├── Activity Instance S5
├── Activity Instance S6
└── same Development Objects reused
```

Do not create a new Project per Activity.

---

# 26. Activity Output Reuse Rule

Outputs from one Activity should become available to later Activities by reference.

Example:

```text
Activity A
→ Development Object P123

Activity B input
→ reference Development Object P123
```

not:

```text
copy P123 into a second Problem record
```

This directly preserves M6 stable object identity.

---

# 27. Source-of-Truth Files

Before each M7 task, Codex must read relevant approved docs:

```text
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
/docs/17_CODEX_M3_PROMPTS.md
/docs/18_CODEX_M4_PROMPTS.md
/docs/19_CODEX_M5_PROMPTS.md
/docs/20_CODEX_M6_PROMPTS.md
```

---

# 28. Global Codex Header

Use this block at the beginning of every M7 task if project rules are not automatically retained:

```text
You are implementing the FICI Invention Education & Development Platform.

Before making changes:

1. Read the relevant /docs files listed in this task.
2. Treat /docs as product and architecture source of truth.
3. Do not invent missing business rules.
4. Activity Definitions come from the curriculum; Activity Instances are runtime executions.
5. Do not hard-code session-specific behavior into the generic Activity Engine unless an approved Activity Definition configuration requires it.
6. Preserve Role + Scope + Resource authorization.
7. Preserve Personal Workspace privacy.
8. Preserve Team isolation and removed-member revocation.
9. Preserve stable Project/Object IDs.
10. Never trust client-provided identity, participant role, team membership, or scope.
11. Enforce dependencies server-side.
12. Do not treat frontend availability as authorization.
13. Inputs/outputs reference canonical entities; do not duplicate them.
14. Use transactions for multi-record Activity operations where required.
15. Use migrations for schema changes.
16. Use strict TypeScript.
17. Validate runtime input.
18. Do not implement M8+ specialized systems.
19. If requirements conflict or are ambiguous, STOP → FLAG → ASK.
20. Run requested validation before finishing.
21. Report:
    - files changed,
    - migrations,
    - operations,
    - dependency rules,
    - RLS,
    - tests,
    - deferred future-entity fields,
    - results,
    - assumptions,
    - unresolved issues.
```

---

# 29. M7.1 — Activity Instance Schema

## Objective

Create runtime execution records for Activity Definitions.

## Copy/Paste Prompt

```text
TASK ID: M7.1
TASK: Activity Instance Schema

Read first:

- /docs/06_COURSE_ACTIVITY_WORKFLOWS.md
- /docs/08_DATA_MODEL_SCHEMA.md
- /docs/13_CODEX_IMPLEMENTATION_PLAN.md
- /docs/17_CODEX_M3_PROMPTS.md
- /docs/20_CODEX_M6_PROMPTS.md

OBJECTIVE

Create `activity_instances`.

FIELDS

- id
- activity_definition_id
- cohort_id
- project_id
- workspace_id
- team_id nullable
- started_by
- started_at
- completed_at
- status
- configuration_snapshot

STATUS VALUES

- not_started
- active
- submitted
- under_review
- revision_requested
- completed
- archived

RULES

1. activity_definition_id references M3 Activity Definition.
2. cohort_id references M3 Cohort.
3. project_id references M6 Development Project.
4. workspace_id references M4 Workspace.
5. team_id may reference M5 Team where team-scoped.
6. started_by references authenticated platform user.
7. validate Project/Workspace/Team/Cohort consistency.
8. configuration_snapshot captures relevant Activity Definition runtime configuration at start.
9. do not permit arbitrary client creation bypassing startActivity().
10. add indexes for:
   - project,
   - workspace,
   - team,
   - Activity Definition,
   - status.

TESTS

- valid Personal Activity shape
- valid Team Activity shape
- invalid Project/Workspace mismatch rejected
- invalid Team/Workspace mismatch rejected
- invalid Cohort/Project participation rejected where applicable
- started_by spoofing denied

VALIDATION

Run:
pnpm lint
pnpm typecheck
pnpm test:unit
pnpm test:integration
pnpm build

DEFINITION OF DONE

Activity runtime records can safely bind curriculum, Cohort, Project, Workspace, Team, and actor.

FINAL REPORT

Return:
1. schema
2. consistency constraints
3. indexes
4. files/migrations
5. tests/results
6. assumptions
7. unresolved issues
```

---

# 30. M7.2 — Activity Participants

## Objective

Represent actual participants without making participation itself a security bypass.

## Copy/Paste Prompt

```text
TASK ID: M7.2
TASK: Activity Participants

Read first:

- /docs/03_ROLES_PERMISSIONS.md
- /docs/04_WORKSPACE_TEAM_COLLABORATION.md
- /docs/08_DATA_MODEL_SCHEMA.md

OBJECTIVE

Implement `activity_participants`.

FIELDS

- id
- activity_instance_id
- user_id
- participant_role
- joined_at
- completed_at

RULES

1. participant must be authorized for Activity Workspace/Project.
2. Team Activity participant normally requires active Team access.
3. Personal Activity participant normally requires Personal owner scope.
4. prevent duplicate active participant row for same user/Activity where appropriate.
5. participant_role must not grant permissions beyond existing authorization.
6. participant removal/end must preserve historical participation.

TEST

- authorized Team member added
- Student B cannot join Team A Activity
- removed Team member cannot join/rejoin through direct insert
- Personal Activity owner allowed
- other Student denied
- participant_role spoofing does not elevate authorization

VALIDATION

Run RLS/integration tests.

DEFINITION OF DONE

Participation is explicit and historical while remaining subordinate to canonical Workspace/Project authorization.

FINAL REPORT

Return:
1. schema
2. participant-role handling
3. security
4. tests/results
5. assumptions
6. unresolved issues
```

---

# 31. M7.3 — Activity Inputs & Outputs Schema

## Objective

Create explicit links between Activity execution and canonical Project entities.

## Copy/Paste Prompt

```text
TASK ID: M7.3
TASK: Activity Input / Output Schema

Read first:

- /docs/06_COURSE_ACTIVITY_WORKFLOWS.md
- /docs/08_DATA_MODEL_SCHEMA.md
- /docs/20_CODEX_M6_PROMPTS.md

OBJECTIVE

Implement:
- activity_inputs
- activity_outputs

ACTIVITY_INPUTS FIELDS

- id
- activity_instance_id
- input_type
- artifact_id nullable
- artifact_version_id nullable
- development_object_id nullable
- evidence_id nullable
- required

ACTIVITY_OUTPUTS FIELDS

- id
- activity_instance_id
- output_type
- artifact_id nullable
- development_object_id nullable
- decision_id nullable
- evidence_id nullable

M7 IMPLEMENTATION

Fully support:
- development_object_id

Preserve but defer:
- artifact_id
- artifact_version_id
- evidence_id
- decision_id

Add deferred FKs only when owning tables exist.

RULES

1. at least one valid linked entity should exist per link row according to input/output type.
2. do not allow contradictory multiple target fields unless approved.
3. linked Development Object must be accessible.
4. Project scope must match Activity Project.
5. Workspace access must remain valid.
6. links reference canonical entity IDs; do not duplicate entity contents.

TEST

- valid Development Object input
- valid Development Object output
- inaccessible Team object rejected
- object from unrelated Project rejected
- malformed target combination rejected
- future nullable fields preserved safely

VALIDATION

Run tests.

DEFINITION OF DONE

Activities can explicitly consume and produce canonical Project Objects.

FINAL REPORT

Return:
1. schemas
2. link validation
3. deferred FKs
4. tests/results
5. assumptions
6. unresolved issues
```

---

# 32. M7.4 — Activity Availability Resolver

## Objective

Create one server-side resolver for whether an Activity can be started.

## Copy/Paste Prompt

```text
TASK ID: M7.4
TASK: Activity Availability Resolver

Read first:

- /docs/06_COURSE_ACTIVITY_WORKFLOWS.md
- /docs/11_API_CONTRACTS.md
- /docs/03_ROLES_PERMISSIONS.md
- /docs/17_CODEX_M3_PROMPTS.md
- /docs/20_CODEX_M6_PROMPTS.md

OBJECTIVE

Implement a reusable server-side Activity availability evaluator.

INPUT CONCEPT

- activityDefinitionId
- projectId
- workspaceId
- teamId optional
- authenticated actor

CHECK

1. Activity Definition exists and is enabled.
2. Activity Definition belongs to curriculum relevant to target Cohort/Program.
3. actor is enrolled/authorized in Cohort as required.
4. actor can access Project.
5. actor can access Workspace.
6. actor can access Team if team-scoped.
7. Workspace mode is compatible with requested Workspace type where configured.
8. required Activity Dependencies are satisfied.
9. duplicate active Activity rule is satisfied.
10. archived Project/Workspace/Team cannot start normal Activity.

RETURN

Typed availability result such as:
- available
- unavailable reason code
- missing dependencies
- existing active instance if relevant

Do not leak inaccessible resource details.

TEST

- available Personal Activity
- available Team Activity
- Team B denied Team A
- removed member denied
- inaccessible Personal Workspace denied
- missing dependency denied
- duplicate active instance denied

VALIDATION

Run tests.

DEFINITION OF DONE

Activity-start eligibility has one authoritative server-side implementation.

FINAL REPORT

Return:
1. algorithm
2. reason codes
3. files changed
4. tests/results
5. assumptions
6. unresolved issues
```

---

# 33. M7.5 — Dependency Evaluator

## Objective

Evaluate `activity_dependencies` from M3 against actual runtime state.

## Copy/Paste Prompt

```text
TASK ID: M7.5
TASK: Activity Dependency Evaluator

Read first:

- /docs/06_COURSE_ACTIVITY_WORKFLOWS.md
- /docs/08_DATA_MODEL_SCHEMA.md
- /docs/12_ACCEPTANCE_TESTS.md
- /docs/17_CODEX_M3_PROMPTS.md

OBJECTIVE

Implement generic dependency evaluation.

SUPPORTED TYPES

- completion
- approved_output
- artifact_available
- gate_passed

M7 BEHAVIOR

COMPLETION
- fully evaluate from prior Activity Instance completed state.

APPROVED_OUTPUT
- evaluate only against actual approved-output data if such data exists.
- M8 owns the approval system.
- otherwise unsatisfied / explicit not-yet-satisfied.
- never fake approval.

ARTIFACT_AVAILABLE
- M8 owns Artifacts.
- preserve evaluator branch/interface.
- if target artifact does not exist, unsatisfied.

GATE_PASSED
- do not invent Development Gate system.
- unsatisfied unless actual approved gate data exists in repository.

ERROR

When required dependency fails:
`DEPENDENCY_NOT_MET`

RETURN

Include safe structured details identifying dependency requirements without leaking inaccessible private resources.

TEST

- completion dependency satisfied
- completion missing → DEPENDENCY_NOT_MET
- optional dependency does not block
- required dependency blocks
- inaccessible upstream Activity does not become usable input
- future dependency types do not auto-pass

VALIDATION

Run unit/integration tests.

DEFINITION OF DONE

Dependencies are enforced server-side and unsupported future dependency types fail safely rather than bypassing workflow.

FINAL REPORT

Return:
1. evaluator design
2. behavior per dependency type
3. tests/results
4. deferred integrations
5. assumptions
6. unresolved issues
```

---

# 34. M7.6 — Start Activity

## Objective

Implement `startActivity(input)` transactionally.

## Copy/Paste Prompt

```text
TASK ID: M7.6
TASK: Start Activity

Read first:

- /docs/06_COURSE_ACTIVITY_WORKFLOWS.md
- /docs/11_API_CONTRACTS.md
- /docs/12_ACCEPTANCE_TESTS.md
- /docs/21_CODEX_M7_PROMPTS.md

OBJECTIVE

Implement `startActivity(input)`.

INPUT

activityDefinitionId
projectId
workspaceId
teamId optional

FLOW

1. resolve authenticated actor.
2. call Activity availability resolver.
3. fail if unavailable.
4. snapshot Activity Definition configuration.
5. create Activity Instance with status active.
6. create initiating Activity Participant row.
7. add Team participants only if approved Activity participation policy explicitly requires automatic enrollment.
8. do not invent participant auto-enrollment rules.
9. return created Activity Instance.

DUPLICATE RULE

Prevent duplicate active instance for same execution context unless definition explicitly allows repeated/concurrent instances.

SECURITY

Never trust:
- startedBy
- participant user IDs
- Team role
from client.

TEST

- authorized start succeeds
- dependency missing fails
- duplicate active fails
- Team B cannot start Team A Activity
- removed member denied
- Personal Activity other Student denied
- configuration snapshot stored

VALIDATION

Run full tests.

DEFINITION OF DONE

AT-ACT-001 start path works securely.

FINAL REPORT

Return:
1. transaction
2. availability checks
3. snapshot contents
4. participant behavior
5. tests/results
6. assumptions
7. unresolved issues
```

---

# 35. M7.7 — Resume Activity

## Objective

Return the canonical current Activity execution state after reconnect/logout.

## Copy/Paste Prompt

```text
TASK ID: M7.7
TASK: Resume Activity

Read first:

- /docs/11_API_CONTRACTS.md
- /docs/12_ACCEPTANCE_TESTS.md
- /docs/21_CODEX_M7_PROMPTS.md

OBJECTIVE

Implement `resumeActivity(activityInstanceId)`.

RETURN

- Activity Instance identity
- Activity Definition
- instructions
- required inputs
- current registered inputs
- current outputs
- participants
- status
- AI role code
- relevant configuration snapshot

RULES

1. requester must still be authorized.
2. removed Team member cannot resume.
3. inactive Project/Workspace rules respected.
4. do not recreate Activity.
5. do not overwrite snapshot from current definition.
6. canonical DB state survives logout/reconnect.

TEST

- participant starts Activity
- adds input/output fixture
- logs out / new request context
- resumes same Activity ID
- same state returned
- Team B denied
- removed member denied

VALIDATION

Run tests.

DEFINITION OF DONE

AT-ACT-003 passes.

FINAL REPORT

Return:
1. returned state
2. authorization
3. persistence behavior
4. tests/results
5. assumptions
6. unresolved issues
```

---

# 36. M7.8 — Add Activity Input

## Objective

Attach allowed canonical Project data as Activity inputs.

## Copy/Paste Prompt

```text
TASK ID: M7.8
TASK: Add Activity Input

Read first:

- /docs/06_COURSE_ACTIVITY_WORKFLOWS.md
- /docs/11_API_CONTRACTS.md
- /docs/20_CODEX_M6_PROMPTS.md

OBJECTIVE

Implement `addActivityInput(input)`.

M7 SUPPORTED SOURCE

Development Object.

VALIDATE

1. Activity exists and is editable/active as appropriate.
2. actor has Activity access.
3. Development Object exists.
4. actor can access Object.
5. Object belongs to same Project unless Activity configuration explicitly allows external/shared source.
6. Workspace privacy is not bypassed.
7. input type is accepted by Activity Definition/configuration where specified.
8. duplicate identical input link prevented where appropriate.

IMPORTANT

A Team Activity must not pull an unshared private Personal Object merely because:
- same user owns both,
- same Project,
- same Cohort.

Workspace privacy remains authoritative.

TEST

- valid same-Project Team Object input
- valid owner Personal Object for Personal Activity
- Team A Activity cannot consume Team B Object
- Team Activity cannot consume private Personal Object without future sharing rule
- duplicate input handling

VALIDATION

Run tests.

DEFINITION OF DONE

Activity inputs preserve canonical entity identity and Workspace privacy.

FINAL REPORT

Return:
1. validation rules
2. privacy handling
3. tests/results
4. assumptions
5. unresolved issues
```

---

# 37. M7.9 — Add Activity Output

## Objective

Register outputs without duplicating Project Objects.

## Copy/Paste Prompt

```text
TASK ID: M7.9
TASK: Add Activity Output

Read first:

- /docs/06_COURSE_ACTIVITY_WORKFLOWS.md
- /docs/11_API_CONTRACTS.md
- /docs/20_CODEX_M6_PROMPTS.md

OBJECTIVE

Implement `addActivityOutput(input)`.

M7 SUPPORTED OUTPUT

Development Object.

RULES

1. Activity exists.
2. actor can contribute to Activity.
3. output Object exists.
4. Object belongs to same Project.
5. Object Workspace is valid for Activity output.
6. output type matches configuration where specified.
7. create link; do not duplicate Object.
8. preserve provenance from Activity to Object.
9. duplicate identical output link should be handled safely.

OPTIONAL CREATION FLOW

If tool/service first creates a Development Object and then registers it as output:
- perform transactionally where practical.
- creator/provenance must remain correct.

TEST

- register Problem/Solution Object output
- same Object reused later
- cross-Project Object rejected
- Team B object rejected
- duplicate output link safe

VALIDATION

Run tests.

DEFINITION OF DONE

Activity outputs are reusable canonical Project entities.

FINAL REPORT

Return:
1. output rules
2. provenance
3. transaction behavior
4. tests/results
5. assumptions
6. unresolved issues
```

---

# 38. M7.10 — Complete Activity

## Objective

Complete an Activity only after generic completion rules are satisfied.

## Copy/Paste Prompt

```text
TASK ID: M7.10
TASK: Complete Activity

Read first:

- /docs/06_COURSE_ACTIVITY_WORKFLOWS.md
- /docs/11_API_CONTRACTS.md
- /docs/12_ACCEPTANCE_TESTS.md

OBJECTIVE

Implement `completeActivity(activityInstanceId)`.

VALIDATE

1. authenticated actor authorized.
2. Activity status allows completion.
3. required participants/rules satisfied where configured.
4. required inputs present.
5. required outputs present.
6. completion_rule from configuration_snapshot satisfied where generic engine can evaluate it.
7. do not bypass future required review/approval.
8. if formal review is required but M8 not implemented:
   - do not pretend Activity is approved,
   - transition only to the correct pre-review state if approved by docs,
   - otherwise STOP/FLAG the unresolved transition.

ON COMPLETION

- set completed_at,
- update status,
- make completion dependency available to downstream evaluator,
- do not auto-approve artifacts,
- do not auto-change Project baseline.

TEST

- valid completion
- missing required input blocks
- missing required output blocks
- completed Activity satisfies downstream completion dependency
- unauthorized completion denied
- already completed retry handled safely

VALIDATION

Run tests.

DEFINITION OF DONE

Activity completion is durable and dependency-aware without faking approval.

FINAL REPORT

Return:
1. completion checks
2. status transitions
3. downstream effects
4. tests/results
5. assumptions
6. unresolved issues
```

---

# 39. M7.11 — Activity RLS

## Objective

Protect Activity execution records directly in PostgreSQL.

## Copy/Paste Prompt

```text
TASK ID: M7.11
TASK: Activity Engine RLS

Read first:

- /docs/03_ROLES_PERMISSIONS.md
- /docs/04_WORKSPACE_TEAM_COLLABORATION.md
- /docs/08_DATA_MODEL_SCHEMA.md
- /docs/16_CODEX_M2_PROMPTS.md
- /docs/18_CODEX_M4_PROMPTS.md
- /docs/19_CODEX_M5_PROMPTS.md
- /docs/20_CODEX_M6_PROMPTS.md

OBJECTIVE

Implement RLS for:
- activity_instances
- activity_participants
- activity_inputs
- activity_outputs

RULES

Activity access requires underlying:
- Workspace access,
- Project access,
- Team access if applicable,
- participant/instructional scope.

PERSONAL
- other Student denied.
- Master not automatically allowed.

TEAM
- Team B denied Team A.
- removed member denied.
- assigned Master only according to approved Team/Activity scope.

MUTATION

Normal client must not:
- forge started_by,
- self-add to inaccessible Activity,
- add inaccessible input,
- add Team B Object to Team A Activity,
- register inaccessible output,
- mark Activity completed without business-command validation,
- modify configuration_snapshot after start.

DIRECT ID TESTS

Known Activity Instance ID must not bypass authorization.

VALIDATION

Run dedicated RLS suite.

DEFINITION OF DONE

Direct database access cannot bypass Activity scope or dependency-sensitive business boundaries.

FINAL REPORT

Return:
1. policies
2. helper functions
3. attack tests
4. files/migrations
5. results
6. assumptions
7. unresolved issues
```

---

# 40. M7.12 — AT-ACT-001 Start Activity

## Objective

Implement the approved Activity start acceptance test.

## Copy/Paste Prompt

```text
TASK ID: M7.12
TASK: AT-ACT-001

Read first:

- /docs/12_ACCEPTANCE_TESTS.md
- /docs/21_CODEX_M7_PROMPTS.md

SCENARIO

Given:
- authorized participant,
- available Activity Definition,
- valid Project,
- valid Workspace,
- Team if required,
- dependencies satisfied.

When:
- startActivity() called.

Then:
- Activity Instance created,
- linked to Activity Definition,
- linked to Project,
- linked to Workspace,
- linked to Team where applicable,
- participant recorded,
- configuration snapshot stored,
- status active.

PRIORITY

MUST PASS

Also verify:
- unrelated user cannot start same scoped Activity,
- duplicate active instance prevented unless allowed.

FINAL REPORT

Return PASS/FAIL and created identifiers.
```

---

# 41. M7.13 — AT-ACT-002 Dependency Enforcement

## Objective

Prove required upstream dependency cannot be bypassed.

## Copy/Paste Prompt

```text
TASK ID: M7.13
TASK: AT-ACT-002

Read first:

- /docs/12_ACCEPTANCE_TESTS.md
- /docs/06_COURSE_ACTIVITY_WORKFLOWS.md

SCENARIO

Create:
- Activity Definition A
- Activity Definition B
- required dependency B → A using dependency_type = completion

Attempt to start B before A completes.

EXPECTED

`DEPENDENCY_NOT_MET`

Then:
1. start A,
2. satisfy generic completion,
3. complete A,
4. start B.

EXPECTED

B can start if all other rules pass.

Also test:
- optional dependency does not block,
- unsupported/future dependency type never auto-passes,
- inaccessible upstream output cannot satisfy dependency.

PRIORITY

MUST PASS

FINAL REPORT

Return dependency matrix and PASS/FAIL.
```

---

# 42. M7.14 — AT-ACT-003 Resume Activity

## Objective

Prove Activity execution persists across logout/request lifecycle.

## Copy/Paste Prompt

```text
TASK ID: M7.14
TASK: AT-ACT-003

SCENARIO

1. Authorized participant starts Activity.
2. Add one valid input.
3. Add one valid Development Object output.
4. End session/request context.
5. Re-authenticate same user.
6. resumeActivity(instanceId).

VERIFY

- same Activity Instance ID,
- same status,
- same input,
- same output,
- same participants,
- same configuration snapshot,
- no duplicate Activity created.

Then attempt as unauthorized user.

Expected:
DENIED.

PRIORITY

MUST PASS

FINAL REPORT

Return PASS/FAIL and persistence checks.
```

---

# 43. M7.15 — AT-ACT-004 Output Available to Next Stage

## Objective

Prove prior Activity output can be used as downstream input by reference.

## Important M7 Interpretation

The official test says:

```text
Approved output becomes selectable/available as required input
```

Formal approval belongs to M8.

Therefore M7 must test the generic reference pipeline now, and M8 must later extend it to true approved Artifact Versions.

## Copy/Paste Prompt

```text
TASK ID: M7.15
TASK: AT-ACT-004 Foundation

Read first:

- /docs/12_ACCEPTANCE_TESTS.md
- /docs/06_COURSE_ACTIVITY_WORKFLOWS.md
- /docs/21_CODEX_M7_PROMPTS.md

OBJECTIVE

Implement the M7 foundation for downstream output reuse.

SCENARIO

1. Activity A creates/registers Development Object O1 as output.
2. Activity A completes.
3. Activity B is a dependent later Activity.
4. Activity B input selection/query can reference O1.
5. Add O1 as Activity B input.

VERIFY

- same Object ID O1,
- no duplicate Object,
- provenance to Activity A remains,
- Activity B input points to O1.

APPROVAL NOTE

If dependency requires formally approved output:
- do not mark approval complete in M7.
- record that formal approval-specific portion of AT-ACT-004 is deferred to M8.
- generic canonical-output handoff must pass now.

PRIORITY

MUST PASS for generic Activity Engine.
Formal approved-output path completed in M8.

FINAL REPORT

Return:
1. generic handoff PASS/FAIL
2. Object ID reuse proof
3. formal approval sub-check status
```

---

# 44. M7.16 — Cross-Team / Personal Activity Leakage Tests

## Objective

Attack Activity boundaries directly.

## Copy/Paste Prompt

```text
TASK ID: M7.16
TASK: Activity Leakage Security Tests

FIXTURES

- Student A1 Personal Activity PA
- Team A Activity TA
- Team B Activity TB
- removed former Team A member
- Master assigned only to Team A/Cohort scope as appropriate

ATTEMPTS

As Student B1:
- fetch TA by exact ID
- list TA participants
- list TA inputs
- list TA outputs
- add own Object as TA input
- add Team B Object as TA output
- complete TA
- direct DB query

As Student A2:
- fetch A1 Personal Activity PA without explicit access

As removed A1:
- resume TA
- add input/output
- complete TA

As unrelated Master:
- fetch TA outside assigned scope

EXPECTED

All unauthorized operations denied.

DEFINITION OF DONE

No Activity Instance/Input/Output leakage across Workspace/Team/Project boundaries.

FINAL REPORT

Return attack matrix and results.
```

---

# 45. M7.17 — Configuration Snapshot Integrity

## Objective

Ensure historical Activity execution does not change when curriculum definition is later edited/versioned.

## Copy/Paste Prompt

```text
TASK ID: M7.17
TASK: Configuration Snapshot Integrity

Read first:

- /docs/08_DATA_MODEL_SCHEMA.md
- /docs/17_CODEX_M3_PROMPTS.md

SCENARIO

1. Activity Definition has configuration V1.
2. Start Activity Instance I1.
3. Verify I1 stores configuration_snapshot V1.
4. Modify/update definition in an isolated test scenario according to allowed admin behavior.
5. Verify I1 snapshot remains V1.
6. Start new Activity I2.
7. Verify I2 receives current definition configuration.

IMPORTANT

If approved curriculum versions are immutable and editing approved definitions is forbidden:
- simulate a new Definition/Curriculum Version instead of mutating approved data.

EXPECTED

Historical Activity behavior remains explainable.

FINAL REPORT

Return PASS/FAIL and snapshot comparison.
```

---

# 46. M7.18 — M7 Security & Integrity Hardening

## Objective

Review the Activity Engine before specialized tools begin using it.

## Copy/Paste Prompt

```text
TASK ID: M7.18
TASK: M7 Security & Integrity Hardening

Read first:

- /docs/03_ROLES_PERMISSIONS.md
- /docs/04_WORKSPACE_TEAM_COLLABORATION.md
- /docs/05_DEVELOPMENT_PROJECT_MODEL.md
- /docs/06_COURSE_ACTIVITY_WORKFLOWS.md
- /docs/08_DATA_MODEL_SCHEMA.md
- /docs/10_TECHNICAL_ARCHITECTURE.md
- /docs/11_API_CONTRACTS.md
- /docs/12_ACCEPTANCE_TESTS.md
- /docs/17_CODEX_M3_PROMPTS.md
- /docs/18_CODEX_M4_PROMPTS.md
- /docs/19_CODEX_M5_PROMPTS.md
- /docs/20_CODEX_M6_PROMPTS.md
- /docs/21_CODEX_M7_PROMPTS.md

OBJECTIVE

Perform M7 security and integrity hardening only.

VERIFY

1. every Activity Instance references a valid Activity Definition.
2. Project/Workspace/Team/Cohort scopes are consistent.
3. no duplicate active Activity unless allowed.
4. configuration snapshot is immutable after start.
5. dependencies enforced server-side.
6. unsupported future dependency types do not auto-pass.
7. inputs reference canonical authorized entities.
8. outputs reference canonical authorized entities.
9. Team B cannot access Team A Activity.
10. removed member cannot resume/mutate Team Activity.
11. Personal Activity stays private.
12. direct Activity IDs do not bypass access.
13. participant row does not bypass Workspace/Project security.
14. completeActivity cannot fake approval.
15. no M8+ specialized feature was implemented.

RUN

pnpm lint
pnpm typecheck
pnpm test:unit
pnpm test:integration
pnpm test:e2e
pnpm build
plus configured RLS tests.

DEFINITION OF DONE

- AT-ACT-001 PASS
- AT-ACT-002 PASS
- AT-ACT-003 PASS
- AT-ACT-004 generic handoff PASS
- formal approval sub-check correctly deferred to M8
- zero known Activity privacy leakage
- zero known dependency bypass
- no M8+ scope creep

FINAL REPORT

Return:
1. security review
2. integrity review
3. issues found
4. issues fixed
5. remaining issues
6. BLOCKER status
7. test results
8. recommendation: READY FOR M8 or NOT READY FOR M8
```

---

# 47. Activity Definition vs Runtime Configuration

Do not read mutable Activity Definition fields as if they were the historical configuration of an already-running Activity.

Use:

```text
Activity Definition
= curriculum source

configuration_snapshot
= execution-time configuration
```

This preserves historic meaning.

---

# 48. Participant Role vs Platform Role

Do not conflate:

```text
participant_role
```

with:

```text
ADMIN / MASTER / MENTOR / STUDENT
```

Participant role is contextual to one Activity.

It must not grant global permissions.

---

# 49. Activity Input vs Copy

An Activity Input is a link.

Example:

```text
Activity B input
→ Development Object P123
```

not:

```text
clone P123
→ P456
```

unless later workflow explicitly requires a snapshot.

This preserves Project traceability.

---

# 50. Activity Output vs Artifact

M7 `activity_outputs` can point to Development Objects now.

M8 introduces Artifacts.

Do not model every Activity output as an Artifact prematurely.

Some Activities may produce:

- Development Object,
- Artifact,
- Decision,
- Evidence,

depending on the tool/workflow.

---

# 51. Completion vs Approval

Critical distinction:

```text
Activity Completed
≠
Artifact Approved
```

An Activity may finish its participant work while its output still requires:

- submission,
- review,
- revision,
- approval.

M8 implements those formal stages.

M7 must never mark an output approved solely because Activity status is completed.

---

# 52. Availability vs Authorization

Another critical distinction:

```text
Activity appears available
≠
user is authorized
```

The server must always re-check:

- user identity,
- Workspace,
- Project,
- Team,
- enrollment,
- dependencies.

Frontend display is advisory only.

---

# 53. Dependency Scope

Dependency evaluation should apply to the same relevant execution context.

Avoid accidentally satisfying a Team A dependency using:

- Team B's completed Activity,
- another student's Personal Activity,
- unrelated Project output,
- another Cohort's Activity.

The dependency source must match required Project/Workspace/Team/Cohort context.

---

# 54. Optional Inputs

Activity Definitions may support optional inputs.

Optional input absence must not block start/completion unless the Activity Definition's completion rule says otherwise.

Do not convert all input links into mandatory dependencies.

---

# 55. Required Inputs

Required inputs should be explicit.

If a required input is missing:

- start may be denied if dependency is precondition,
- or completion may be denied if workflow permits input collection after start.

Use the Activity Definition/configuration rule.

Do not invent one global behavior for every Activity if docs/config specify otherwise.

---

# 56. Instructor Case Study Activities

An Instructor Case Study should use the same Activity Engine.

Do not build a separate instructor-only Activity architecture.

Expected:

```text
CASE_STUDY Workspace
+
Instructor Case Study Project
+
same Activity Definition
+
Activity Instance
```

Student view/edit behavior follows Workspace/publication rules.

---

# 57. Workshop Reuse

The Workshop must use the same generic Activity Engine in simplified configuration.

Do not build a separate Workshop execution system.

This preserves:

```text
Workshop Project
→ Professional Course
```

continuity.

---

# 58. Cross-Program Reuse

Advanced Course Activities should later use the same M7 engine.

The Activity Engine must be curriculum-driven, not hard-wired to Professional Course session numbers.

---

# 59. Activity State Persistence

Canonical state must live in PostgreSQL.

Do not use:

- browser local state,
- transient realtime state,
- client cache,

as the source of truth for Activity completion, inputs, outputs, or participants.

---

# 60. RLS and Business Rules

RLS is defense-in-depth.

Some rules require server business logic, such as:

- dependency evaluation,
- completion rules,
- duplicate active-instance policy.

Do not attempt to encode every workflow rule only in RLS.

Required:

```text
SERVER BUSINESS OPERATION
+
RLS
```

---

# 61. Idempotency

Retry-prone operations should be safe.

Examples:

- start Activity,
- add input,
- add output,
- complete Activity.

Avoid:

- duplicate active Activity,
- duplicate input links,
- duplicate output links,
- multiple completion timestamps from retries.

---

# 62. Archive Behavior

Archived Activity Instance should remain historical.

Do not hard-delete:

- participants,
- inputs,
- outputs,
- completion data.

Archived Activity should not accept normal new mutations unless explicit restore/reactivation policy exists.

---

# 63. M7 Expected Repository Additions

Conceptually:

```text
features/
└── activities/
    ├── availability/
    ├── dependencies/
    ├── operations/
    ├── participants/
    ├── inputs/
    ├── outputs/
    └── validation/

lib/
├── permissions/
│   └── activity.ts
└── workflow/
    ├── dependencies.ts
    └── completion.ts

supabase/
├── migrations/
│   ├── ...activity_instances...
│   ├── ...activity_participants...
│   ├── ...activity_inputs...
│   ├── ...activity_outputs...
│   └── ...activity_rls...
└── tests/
    └── rls/
        └── activities...

tests/
├── unit/
│   ├── activity-availability/
│   └── dependencies/
├── integration/
│   └── activities/
└── e2e/
    └── activity-engine.spec.ts
```

Exact paths may vary.

---

# 64. M7 Completion Gate

M7 is complete only when:

```text
[ ] activity_instances exists
[ ] activity_participants exists
[ ] activity_inputs exists
[ ] activity_outputs exists

[ ] Activity Instance linked to Definition
[ ] Activity Instance linked to Cohort
[ ] Activity Instance linked to Project
[ ] Activity Instance linked to Workspace
[ ] Team link supported where applicable
[ ] configuration_snapshot stored

[ ] Activity availability resolver exists
[ ] dependency evaluator exists
[ ] completion dependency fully works
[ ] future dependency types do not auto-pass

[ ] startActivity() implemented
[ ] resumeActivity() implemented
[ ] completeActivity() implemented
[ ] addActivityInput() implemented
[ ] addActivityOutput() implemented

[ ] duplicate active Activity protected
[ ] participant identity cannot be spoofed
[ ] input source authorization enforced
[ ] output source authorization enforced

[ ] Team B cannot access Team A Activity
[ ] removed member cannot access Team Activity
[ ] Personal Activity private
[ ] direct ID access blocked
[ ] RLS tests pass

[ ] Activity completion does not imply Artifact approval

[ ] AT-ACT-001 PASS
[ ] AT-ACT-002 PASS
[ ] AT-ACT-003 PASS
[ ] AT-ACT-004 generic canonical-output handoff PASS
[ ] formal approval portion of AT-ACT-004 deferred to M8

[ ] lint passes
[ ] typecheck passes
[ ] unit tests pass
[ ] integration tests pass
[ ] E2E tests pass
[ ] RLS tests pass
[ ] build passes

[ ] no M8+ feature implemented prematurely
[ ] Codex reports READY FOR M8
```

Any dependency bypass is:

```text
BLOCKER
```

Any cross-Team/Personal Activity leak is:

```text
BLOCKER
```

---

# 65. Recommended Commit Sequence

Example:

```text
feat(activities): add Activity Instance schema
feat(activities): add Activity participants
feat(activities): add input/output links
feat(workflow): add Activity availability resolver
feat(workflow): add dependency evaluator
feat(activities): add start Activity operation
feat(activities): add resume Activity operation
feat(activities): add input/output operations
feat(activities): add complete Activity operation
feat(security): add Activity RLS
test(activities): add AT-ACT-001
test(workflow): add dependency enforcement
test(activities): add resume persistence coverage
test(activities): add downstream output reuse coverage
test(security): add Activity leakage tests
test(integrity): add configuration snapshot coverage
chore(security): complete M7 hardening
```

---

# 66. M7 Non-Goals

Do not accept these as "helpful additions" during M7:

- SCAMPER implementation,
- Brainstorm Entry implementation,
- Voting,
- Affinity,
- Mind Map,
- Artifact tables,
- Artifact Versions,
- Review/Approval system,
- Evidence,
- Patent records,
- AI Assistant,
- Sharing,
- File upload,
- Liveblocks,
- Daily video,
- advanced progress dashboards,
- hard-coded Professional Session logic.

---

# 67. Potential M7 Ambiguities Codex Must Flag

Do not silently decide if approved docs do not resolve:

- exact `participant_role` vocabulary,
- whether Team Activity auto-adds all Team members as participants,
- whether Master is auto-added as participant,
- whether Mentor is auto-added,
- exact duplicate/repeat Activity policy,
- whether completed Activity may be reopened,
- whether archived Activity may be restored,
- whether Activity can move back from completed to active,
- whether `submitted` state is used before M8,
- exact completion-rule DSL/format,
- exact `input_type` vocabulary,
- exact `output_type` vocabulary,
- whether Activity can consume input from a different Workspace in same Project,
- whether Personal Activity output can become Team Activity input before M13 Sharing,
- whether optional dependencies appear as warnings,
- whether Activity availability is time/release-date controlled,
- who may start Team Activity,
- whether Team Lead can start specific Activities,
- whether Master can start Activity on behalf of Team,
- whether Activity Instance is one per Team or one per participant for each method,
- whether completion is individual or collective for Team Activities,
- whether a participant may mark themselves completed independently,
- whether unfinished Activity survives Cohort completion.

If unresolved:

```text
STOP → FLAG → ASK
```

---

# 68. Recommended Safe Defaults for Purely Technical Decisions

Only where they do not alter approved product policy:

- UUID Activity IDs,
- server-derived `started_by`,
- immutable configuration snapshot,
- canonical PostgreSQL state,
- RLS enabled,
- no cross-Team access,
- no cross-Personal access,
- one active execution per definition/project/workspace/team context unless configured otherwise,
- completion dependencies enforced now,
- unsupported future dependency types fail closed,
- future Artifact/Evidence/Decision foreign keys deferred,
- input/output links reference canonical objects,
- archive over hard delete,
- deterministic Activity test fixtures.

---

# 69. Review Checklist for Ahmad/FICI

Before implementation, confirm M7 reflects the intended Activity model:

```text
1. Curriculum Activity Definition and actual Activity execution are separate.

2. Every runtime Activity belongs to a real Project and Workspace.

3. Team Activities remain private to authorized Team scope.

4. Personal Activities remain private.

5. Activity participants cannot bypass Workspace/Project permissions.

6. Dependencies are checked on the server.

7. One Activity can require earlier completion/output.

8. The same Development Object should pass between Activities by reference.

9. Activity completion does not mean approval.

10. Formal Artifact/Version/Approval starts in M8.

11. Activity configuration is snapshotted at start.

12. The generic Activity Engine is reused by Workshop, Professional, Advanced, and future Programs.

13. M7 does not hard-code Professional Course-specific tools.
```

---

# 70. Next File After M7

After M7 has actually been:

```text
IMPLEMENTED
→ TESTED
→ SECURITY-REVIEWED
→ COMMITTED
```

create:

# `22_CODEX_M8_PROMPTS.md`

M8 will cover:

```text
Artifacts
Artifact Versions
Artifact/Object Links
Submissions
Feedback
Review Actions
Revision
Approval
Current Version Pointer
Baseline Foundation
Approved Output Dependencies
```

M8 will complete the formal development-history and review mechanism that M7 deliberately leaves separate from Activity completion.

---

# 71. Final Execution Rule

For M7:

```text
ACTIVITY INSTANCE SCHEMA
→ PARTICIPANTS
→ INPUT / OUTPUT LINKS
→ AVAILABILITY
→ DEPENDENCIES
→ START
→ RESUME
→ INPUTS
→ OUTPUTS
→ COMPLETE
→ RLS
→ ACCEPTANCE TESTS
→ LEAKAGE TESTS
→ SNAPSHOT INTEGRITY
→ SECURITY HARDENING
```

Do not skip directly to Artifacts or specialized method tools.

---

# End of Document

**Current Status:** Draft v0.1 — Ready for Ahmad/FICI review.  
**Execution Step After M6 Completion:** Start with **M7.1 — Activity Instance Schema**.
