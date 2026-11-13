# FICI Invention Education & Development Platform
## Codex M9 Execution Prompts — SCAMPER, Brainstorming & Problem/Solution

**Document:** `23_CODEX_M9_PROMPTS.md`  
**Status:** Draft v0.1 — For Review  
**Depends on:** `01_PRODUCT_REQUIREMENTS.md` through `22_CODEX_M8_PROMPTS.md`  
**Purpose:** Provide exact copy/paste prompts for Codex to implement Milestone M9 safely and incrementally after M8 is complete.

---

# 1. Preconditions

Do not begin M9 until M8 is:

```text
IMPLEMENTED
→ TESTED
→ SECURITY-REVIEWED
→ COMMITTED
```

Required M8 state:

- Artifacts exist,
- immutable Artifact Versions exist,
- submission/review/revision/approval works,
- current-version handling works,
- approved versions are immutable,
- downstream approved-output dependency works,
- RLS for Artifacts/Versions works,
- AT-REV suite passes,
- AT-VER suite passes,
- approval transaction rollback passes,
- Codex reports READY FOR M9.

If M8 is incomplete:

```text
STOP → FINISH M8 → REVIEW → COMMIT → BEGIN M9
```

M9 must use the generic Activity Engine and Artifact system rather than creating a parallel workflow.

---

# 2. M9 Goal

M9 implements the first native FICI invention-method tools:

```text
SCAMPER
+
BRAINSTORMING
+
PROBLEM STORMING
+
PROBLEM BANK
+
SOLUTION BANK
+
PROMOTION TO STRUCTURED IDEA / PROBLEM / SOLUTION OBJECTS
```

The central product principles are:

# THINK PRIVATELY WHEN REQUIRED

# SHARE OR REVEAL INTENTIONALLY

# PROMOTE USEFUL OUTPUTS INTO THE PERSISTENT DEVELOPMENT PROJECT

# DO NOT LEAVE METHODOLOGY OUTPUTS AS DISCONNECTED TEXT

---

# 3. M9 Product Boundary

M9 includes:

- `scamper_entries`,
- `brainstorm_entries`,
- all seven SCAMPER lenses,
- SCAMPER create/update,
- SCAMPER → Idea promotion,
- Brainstorming create/update where appropriate,
- independent/private generation,
- reveal workflow,
- parent/extension relation,
- Brainstorm entry → Idea promotion,
- Problem Storming using Development Objects,
- Problem Bank Artifact,
- Solution Bank Artifact,
- Problem → multiple Solution relationships,
- Activity integration,
- Artifact integration,
- provenance,
- RLS/privacy,
- AT-SCAMPER acceptance tests,
- AT-BRAIN acceptance tests.

M9 does **not** yet implement:

- Dot Voting,
- Decision Records,
- Affinity grouping,
- Mind Map,
- Evidence,
- Patent tools,
- AI,
- general cross-Team sharing,
- generic Personal → Team sharing framework,
- Liveblocks collaborative board.

Those belong to later milestones.

---

# 4. Important M9/M13 Boundary

The M9 implementation plan mentions:

```text
personal-to-team sharing integration later via M13
```

Therefore M9 must distinguish:

## Activity-internal reveal

A Brainstorming Activity may intentionally support:

```text
private generation
→ authorized reveal
→ shared activity pool
```

This is M9.

## General entity sharing

A user selects a private SCAMPER/Artifact/Object and shares it across Workspaces/Teams using persistent sharing records.

This is M13.

Do not build M13 general sharing early.

---

# 5. SCAMPER Schema

Implement:

```text
scamper_entries
```

Fields:

- `id`
- `activity_instance_id`
- `project_id`
- `workspace_id`
- `created_by`
- `scamper_type`
- `original_element`
- `proposed_change`
- `result_text`
- `idea_object_id` nullable
- `status`

Approved SCAMPER types:

```text
SUBSTITUTE
COMBINE
ADAPT
MODIFY
PUT_TO_ANOTHER_USE
ELIMINATE
REVERSE_REARRANGE
```

The seven lenses must not be renamed or merged.

---

# 6. FICI SCAMPER Method

The Professional Course presents SCAMPER as a structured way to examine an existing product, component, function, process, system, or solution.

The FICI approach emphasizes:

```text
See
→ Analyze
→ Break Down
→ Understand
→ Apply
```

and all seven lenses:

```text
S — Substitute
C — Combine
A — Adapt
M — Modify
P — Put to Another Use
E — Eliminate
R — Reverse / Rearrange
```

The platform should support this methodology directly rather than reducing SCAMPER to one generic text box.

---

# 7. SCAMPER Entry Principle

Each entry records:

```text
lens
+
original element
+
proposed change
+
result
```

This supports traceability from:

```text
Original Concept
→ SCAMPER Lens
→ Proposed Change
→ Resulting Idea
→ optional Idea Development Object
```

---

# 8. Brainstorm Entry Schema

Implement:

```text
brainstorm_entries
```

Fields:

- `id`
- `activity_instance_id`
- `project_id`
- `workspace_id`
- `created_by`
- `content`
- `status`
- `revealed_at` nullable
- `development_object_id` nullable
- `parent_entry_id` nullable

This schema supports:

```text
private creation
→ reveal
→ promotion into structured Idea
```

---

# 9. Brainstorming Product Principle

The platform must support independent generation before group influence where the Activity Definition requires it.

Conceptually:

```text
A1 writes private ideas
A2 writes private ideas
A3 writes private ideas
↓
AUTHORIZED REVEAL
↓
shared pool
↓
build / extend / combine
↓
promote selected entries to Ideas / Solutions
```

Before reveal:

```text
A1 cannot read A2's unrevealed entries
A2 cannot read A1's unrevealed entries
```

This is a BLOCKER privacy rule.

---

# 10. Parent / Extension Relation

`brainstorm_entries.parent_entry_id` supports extending another Brainstorm entry.

Examples:

```text
Idea A
└── Build-on A1
    └── Build-on A2
```

The parent relation must remain inside the same authorized Activity scope.

Do not allow Team B entry to point to Team A entry.

---

# 11. Problem Storming Curriculum Principle

Professional Course Session 4 explicitly delays solving and explores problems from multiple perspectives.

Supported perspectives/categories include:

- User,
- Function,
- Technical,
- Cost,
- Safety,
- Environment,
- Accessibility,
- Maintenance.

Core pattern:

```text
Identify
→ Write
→ Keep Going
```

not:

```text
Identify
→ Solve
→ Stop
```

The output is:

```text
Problem Bank
```

---

# 12. From Problems to Solutions

The approved Session 4 workflow is:

```text
Concept V2
→ Problem Storming
→ Problem Bank
→ Brainstorming
→ Solution Bank
```

For each selected Problem:

```text
Problem
→ Solution A
→ Solution B
→ Solution C
→ ...
```

During generation:

```text
NO RANKING
NO VOTING
NO ELIMINATION
```

Evaluation happens in Session 5.

M9 must not embed M10 voting logic.

---

# 13. Problem Bank Architecture

Problem Bank must use:

```text
Development Objects of type PROBLEM
+
Artifact of type PROBLEM_BANK
+
Artifact/Object Links
```

Do not create a disconnected `problem_bank_items` text table unless source docs explicitly require it.

Each Problem should have a stable Development Object ID.

Problem-specific typed data may use the existing `problem_details` extension from M6.

---

# 14. Solution Bank Architecture

Solution Bank must use:

```text
Development Objects of type SOLUTION
+
Artifact of type SOLUTION_BANK
+
Artifact/Object Links
```

A Solution should be connected to its relevant Problem through explicit Development Object Relationships.

Use the approved relationship semantics.

Do not store only a flat list of solution text if structured Objects already exist.

---

# 15. Brainstorm → Idea Promotion

Approved operation:

```text
promoteBrainstormEntryToIdea(input)
```

Creates an Idea Development Object with provenance back to the Brainstorm entry.

Required behavior:

```text
Brainstorm Entry
→ Idea Development Object
```

The original Brainstorm entry remains.

Promotion must not erase source history.

---

# 16. SCAMPER → Idea Promotion

Approved API output allows:

```text
SCAMPER Entry + optional linked Idea object
```

Therefore the platform should support promotion from a SCAMPER entry to an Idea Development Object.

Required traceability:

```text
SCAMPER Entry
→ Idea Object
```

using:

- `idea_object_id`,
- origin/provenance metadata,
- Project/Workspace scope.

---

# 17. Private SCAMPER Rule

A SCAMPER entry created in Personal Workspace remains private unless:

- it is created directly inside an authorized Team Activity/Team Workspace,
- or later explicitly shared/promoted according to approved sharing workflow.

M9 must not infer that enrollment/team membership automatically exposes Personal SCAMPER work.

---

# 18. SCAMPER Share-to-Team Contract Boundary

The API defines:

```text
shareScamperEntryToTeam(input)
```

and says:

```text
Uses standard sharing/promote logic.
```

However the general sharing system is scheduled for M13.

Therefore in M9:

- do not invent a second ad hoc sharing model,
- implement only if the approved project already has the standard sharing primitive,
- otherwise keep the operation adapter/interface ready and mark full persistence as dependent on M13,
- AT-SCAMPER-003 may be implemented through a safe explicit promotion/copy mechanism only if the approved docs define it.

Do not silently expose the source Personal Workspace.

---

# 19. Brainstorm Reveal vs General Sharing

`revealBrainstormEntries()` is Activity-local and can be implemented now.

It is not equivalent to general `shareEntity()`.

Reveal means:

```text
entry belongs to this Brainstorming Activity
+
entry state changes from hidden/private-within-activity
to visible to authorized activity participants
```

It does not transfer ownership.

It does not grant access outside the Activity/Team scope.

---

# 20. Source-of-Truth Files

Before each M9 task, Codex must read:

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
/docs/18_CODEX_M4_PROMPTS.md
/docs/20_CODEX_M6_PROMPTS.md
/docs/21_CODEX_M7_PROMPTS.md
/docs/22_CODEX_M8_PROMPTS.md
```

Also consult the approved Professional Course Session 2, Session 3, and Session 4 curriculum source material for exact methodology behavior.

---

# 21. Global Codex Header

Use this block at the beginning of every M9 task if project rules are not automatically retained:

```text
You are implementing the FICI Invention Education & Development Platform.

Before making changes:

1. Read the relevant /docs files and approved curriculum sources listed in this task.
2. Treat them as product and curriculum source of truth.
3. Do not invent missing business rules.
4. Preserve all seven SCAMPER lenses exactly.
5. Preserve private-before-reveal behavior.
6. Do not expose unrevealed Brainstorm entries.
7. Do not expose Personal Workspace SCAMPER/idea content merely because users share a Team/Cohort.
8. Promote useful methodology outputs into stable Development Objects.
9. Use existing Activity Engine and Artifact/Version system.
10. Do not create disconnected duplicate Problem/Solution records.
11. Preserve creator/provenance when promoting entries.
12. Do not implement Voting in M9.
13. Do not invent general Sharing; M13 owns it.
14. Never trust client-provided identity, workspace, team, or creator.
15. Enforce authorization server-side and with RLS.
16. Use migrations for schema changes.
17. Use strict TypeScript.
18. Validate runtime input.
19. If requirements conflict or are ambiguous, STOP → FLAG → ASK.
20. Run required validation before finishing.
21. Report:
    - files changed,
    - migrations,
    - operations,
    - privacy rules,
    - promotion behavior,
    - artifact integration,
    - RLS,
    - tests,
    - results,
    - assumptions,
    - deferred M13 behavior,
    - unresolved issues.
```

---

# 22. M9.1 — SCAMPER Schema

## Objective

Create structured SCAMPER entries linked to Activity, Project and Workspace.

## Copy/Paste Prompt

```text
TASK ID: M9.1
TASK: SCAMPER Schema

Read first:

- /docs/06_COURSE_ACTIVITY_WORKFLOWS.md
- /docs/08_DATA_MODEL_SCHEMA.md
- /docs/21_CODEX_M7_PROMPTS.md

OBJECTIVE

Create `scamper_entries`.

FIELDS

- id
- activity_instance_id
- project_id
- workspace_id
- created_by
- scamper_type
- original_element
- proposed_change
- result_text
- idea_object_id nullable
- status

SCAMPER TYPES

- SUBSTITUTE
- COMBINE
- ADAPT
- MODIFY
- PUT_TO_ANOTHER_USE
- ELIMINATE
- REVERSE_REARRANGE

RULES

1. Entry belongs to one SCAMPER Activity Instance.
2. Activity, Project and Workspace must be consistent.
3. created_by is server-derived.
4. scamper_type must be one approved lens.
5. idea_object_id, if populated, must reference an IDEA Development Object in same authorized Project.
6. status must not be used to bypass privacy.
7. preserve stable entry ID.

TEST

- each of 7 lens values accepted
- invalid lens rejected
- Project/Workspace mismatch rejected
- creator spoof denied
- cross-Team Idea link denied

VALIDATION

Run:
pnpm lint
pnpm typecheck
pnpm test:unit
pnpm test:integration
pnpm build

DEFINITION OF DONE

SCAMPER is represented as structured methodology data, not one free-text document.

FINAL REPORT

Return:
1. schema
2. lens constraints
3. RLS foundation
4. tests/results
5. assumptions
6. unresolved issues
```

---

# 23. M9.2 — Create / Update SCAMPER Entry

## Objective

Implement the approved SCAMPER business operations.

## Approved Contracts

```text
createScamperEntry(input)
updateScamperEntry(input)
```

Create input:

```text
activityInstanceId
scamperType
originalElement
proposedChange
resultText
```

## Copy/Paste Prompt

```text
TASK ID: M9.2
TASK: SCAMPER Entry Operations

Read first:

- /docs/11_API_CONTRACTS.md
- /docs/06_COURSE_ACTIVITY_WORKFLOWS.md
- /docs/12_ACCEPTANCE_TESTS.md

OBJECTIVE

Implement:
- createScamperEntry(input)
- updateScamperEntry(input)

CREATE

1. resolve authenticated actor.
2. verify Activity Instance is SCAMPER-compatible.
3. verify Activity access.
4. derive Project/Workspace from authorized Activity context where possible.
5. validate approved scamperType.
6. persist:
   - original_element
   - proposed_change
   - result_text
7. created_by server-derived.

UPDATE

Allowed only while entry/activity is editable.

Do not allow:
- changing created_by,
- changing to inaccessible Project/Workspace,
- changing Activity ownership,
- editing locked/submitted/approved derived output through SCAMPER update.

TEST

AT-SCAMPER-001:
student saves:
- lens,
- original element,
- proposed change,
- result.

Also test:
- Team B denied Team A entry,
- other Student denied Personal entry,
- creator spoof denied,
- invalid Activity type denied.

VALIDATION

Run tests.

DEFINITION OF DONE

AT-SCAMPER-001 passes.

FINAL REPORT

Return:
1. operations
2. editability rules
3. privacy
4. tests/results
5. assumptions
6. unresolved issues
```

---

# 24. M9.3 — Promote SCAMPER Entry to Idea

## Objective

Create a persistent Idea Development Object from selected SCAMPER output.

## Copy/Paste Prompt

```text
TASK ID: M9.3
TASK: Promote SCAMPER Entry to Idea

Read first:

- /docs/05_DEVELOPMENT_PROJECT_MODEL.md
- /docs/08_DATA_MODEL_SCHEMA.md
- /docs/20_CODEX_M6_PROMPTS.md
- /docs/11_API_CONTRACTS.md

OBJECTIVE

Implement an explicit SCAMPER → Idea promotion path.

FLOW

1. resolve SCAMPER Entry.
2. verify actor can access/promote it.
3. create Development Object:
   object_type = IDEA
4. preserve:
   - Project,
   - authorized Workspace,
   - creator,
   - origin/provenance reference to SCAMPER Entry.
5. populate `scamper_entries.idea_object_id`.
6. create Idea Details only if required by approved object model.
7. do not delete or replace SCAMPER Entry.
8. prevent accidental duplicate promotion or handle idempotently.

CONTENT

Use the entry's result/proposed change as source material without silently inventing additional idea content.

TEST

- selected SCAMPER Entry → Idea
- same Project
- provenance retained
- source entry remains
- duplicate promotion safe
- unauthorized user denied

VALIDATION

Run tests.

DEFINITION OF DONE

SCAMPER output can enter the persistent Project model without losing methodology provenance.

FINAL REPORT

Return:
1. transaction
2. provenance
3. resulting Object
4. tests/results
5. assumptions
6. unresolved issues
```

---

# 25. M9.4 — SCAMPER Privacy & Share Boundary

## Objective

Protect Personal SCAMPER entries and prepare for later explicit sharing.

## Copy/Paste Prompt

```text
TASK ID: M9.4
TASK: SCAMPER Privacy & Share Boundary

Read first:

- /docs/04_WORKSPACE_TEAM_COLLABORATION.md
- /docs/11_API_CONTRACTS.md
- /docs/12_ACCEPTANCE_TESTS.md
- /docs/18_CODEX_M4_PROMPTS.md

OBJECTIVE

Enforce SCAMPER privacy.

PERSONAL

Student A1 Personal SCAMPER Entry:
- A1 can access.
- A2 cannot.
- Master cannot automatically browse it.
- Team A membership alone does not expose it.

TEAM

Team-scoped SCAMPER Entry:
- active Team members according to Activity rule can access.
- Team B cannot.

SHARE TO TEAM CONTRACT

Review `shareScamperEntryToTeam()`.

If standard M13 Sharing is not implemented:
- do not create a conflicting ad hoc share table.
- expose a deferred adapter/service contract OR an approved explicit promotion path only if source documents define it.
- clearly mark AT-SCAMPER-003 dependency on M13 if full sharing cannot yet be completed.

SECURITY TEST

- exact Entry ID cannot bypass Workspace privacy.
- direct DB query blocked.
- same Cohort does not imply access.

DEFINITION OF DONE

AT-SCAMPER-002 passes now.
AT-SCAMPER-003 is either safely implemented using approved standard sharing or explicitly tracked as M13-dependent.

FINAL REPORT

Return:
1. privacy matrix
2. AT-SCAMPER-002 result
3. AT-SCAMPER-003 status
4. M13 dependency
5. tests/results
```

---

# 26. M9.5 — Brainstorm Entry Schema

## Objective

Create Brainstorm entries supporting private generation and reveal.

## Copy/Paste Prompt

```text
TASK ID: M9.5
TASK: Brainstorm Entry Schema

Read first:

- /docs/06_COURSE_ACTIVITY_WORKFLOWS.md
- /docs/08_DATA_MODEL_SCHEMA.md
- /docs/12_ACCEPTANCE_TESTS.md

OBJECTIVE

Create `brainstorm_entries`.

FIELDS

- id
- activity_instance_id
- project_id
- workspace_id
- created_by
- content
- status
- revealed_at nullable
- development_object_id nullable
- parent_entry_id nullable

RULES

1. Entry belongs to Brainstorming-compatible Activity.
2. Activity/Project/Workspace consistent.
3. creator server-derived.
4. unrevealed entry hidden from unauthorized peer participants.
5. revealed_at set only by authorized reveal workflow.
6. development_object_id, if populated, must point to authorized compatible Development Object.
7. parent_entry_id must refer to entry inside compatible Activity/scope.
8. preserve stable Entry ID.

TEST

- valid private entry
- parent relation within Activity
- cross-Team parent rejected
- creator spoof denied
- direct query privacy enforced

VALIDATION

Run tests.

DEFINITION OF DONE

Brainstorm entries can represent independent generation and later reveal.

FINAL REPORT

Return:
1. schema
2. state model
3. privacy constraints
4. tests/results
5. assumptions
6. unresolved issues
```

---

# 27. M9.6 — Create Brainstorm Entry

## Objective

Allow independent generation according to Activity configuration.

## Approved Contract

```text
createBrainstormEntry(input)
```

Input:

```text
activityInstanceId
content
visibilityState
parentEntryId optional
```

## Copy/Paste Prompt

```text
TASK ID: M9.6
TASK: Create Brainstorm Entry

Read first:

- /docs/11_API_CONTRACTS.md
- /docs/06_COURSE_ACTIVITY_WORKFLOWS.md
- /docs/12_ACCEPTANCE_TESTS.md

OBJECTIVE

Implement `createBrainstormEntry(input)`.

FLOW

1. resolve authenticated actor.
2. verify Brainstorming-compatible Activity.
3. verify Activity participation.
4. derive Project/Workspace scope.
5. validate visibilityState against Activity configuration.
6. create private/unrevealed entry where private-before-reveal is configured.
7. validate optional parentEntryId is visible/allowed in current stage.

RULES

- do not reveal peer entries during private generation.
- do not allow client to set created_by.
- do not allow a user to parent from an unrevealed entry they cannot access.
- entry must survive refresh/reconnect.

TEST

AT-BRAIN-001:
each Team member creates independent private entries.

Also test:
- Team B denied,
- direct creator spoof denied,
- invalid parent rejected.

VALIDATION

Run tests.

DEFINITION OF DONE

AT-BRAIN-001 passes.

FINAL REPORT

Return:
1. creation flow
2. visibility handling
3. parent handling
4. tests/results
5. assumptions
6. unresolved issues
```

---

# 28. M9.7 — No Premature Reveal Security

## Objective

Enforce private-before-reveal as a database and server boundary.

## Copy/Paste Prompt

```text
TASK ID: M9.7
TASK: No Premature Brainstorm Reveal

Read first:

- /docs/04_WORKSPACE_TEAM_COLLABORATION.md
- /docs/12_ACCEPTANCE_TESTS.md
- /docs/08_DATA_MODEL_SCHEMA.md

OBJECTIVE

Implement AT-BRAIN-002.

FIXTURE

Team A:
- Student A1
- Student A2

Same Brainstorming Activity configured private-before-reveal.

A1 creates Entry E1.
A2 creates Entry E2.

BEFORE REVEAL

A1 may see E1.
A2 may see E2.

A1 must NOT see E2.
A2 must NOT see E1.

Test through:
- normal query,
- direct Entry ID,
- list endpoint,
- direct database query,
- parent-entry lookup,
- realtime/subscription path if any exists.

Master access must follow approved Activity policy and must not accidentally expose peer entries to students.

PRIORITY

BLOCKER

DEFINITION OF DONE

No peer participant can access another participant's unrevealed entry.

FINAL REPORT

Return attack matrix and PASS/FAIL.
```

---

# 29. M9.8 — Reveal Brainstorm Entries

## Objective

Reveal eligible entries to the authorized Activity pool.

## Approved Contract

```text
revealBrainstormEntries(input)
```

Authorization:

```text
Activity host / Master / team workflow
according to Activity Definition
```

Rule:

```text
Only entries in the Activity may be revealed.
```

## Copy/Paste Prompt

```text
TASK ID: M9.8
TASK: Reveal Brainstorm Entries

Read first:

- /docs/11_API_CONTRACTS.md
- /docs/12_ACCEPTANCE_TESTS.md
- /docs/06_COURSE_ACTIVITY_WORKFLOWS.md

OBJECTIVE

Implement `revealBrainstormEntries(input)`.

AUTHORIZATION

Resolve reveal authority from Activity Definition/configuration.

Do not hard-code Master-only if the Activity configuration allows another host role.
Do not give every participant reveal authority unless approved.

FLOW

1. validate Activity.
2. validate actor reveal authority.
3. validate all target entries belong to Activity.
4. mark eligible entries revealed.
5. set revealed_at.
6. preserve creator identity.
7. do not transfer ownership.
8. make revealed entries visible only to authorized Activity pool.

TEST

AT-BRAIN-003:
after authorized reveal, eligible Team A participants see shared pool.

Also test:
- unauthorized participant cannot reveal,
- Team B cannot reveal/read,
- entry from another Activity rejected,
- creator remains recorded.

VALIDATION

Run tests.

DEFINITION OF DONE

AT-BRAIN-003 passes.

FINAL REPORT

Return:
1. authorization rule
2. reveal transition
3. visibility after reveal
4. tests/results
5. assumptions
6. unresolved issues
```

---

# 30. M9.9 — Promote Brainstorm Entry to Idea

## Objective

Convert selected Brainstorm output into a structured Idea while preserving provenance.

## Approved Contract

```text
promoteBrainstormEntryToIdea(input)
```

## Copy/Paste Prompt

```text
TASK ID: M9.9
TASK: Promote Brainstorm Entry to Idea

Read first:

- /docs/11_API_CONTRACTS.md
- /docs/05_DEVELOPMENT_PROJECT_MODEL.md
- /docs/20_CODEX_M6_PROMPTS.md

OBJECTIVE

Implement `promoteBrainstormEntryToIdea(input)`.

FLOW

1. resolve Brainstorm Entry.
2. verify actor has access and promotion authority.
3. create Development Object:
   object_type = IDEA
4. copy/derive only source-supported content.
5. set Project/Workspace consistently.
6. preserve creator/provenance:
   origin references Brainstorm Entry.
7. set `development_object_id` on Brainstorm Entry.
8. do not delete Brainstorm Entry.
9. avoid duplicate promotion.

PRIVATE ENTRY RULE

If entry is private/unrevealed:
- promotion into Personal Workspace may be allowed for creator.
- promotion into Team-visible scope must not bypass reveal/share rules.

TEST

AT-BRAIN-004:
Brainstorm Entry → structured Idea with provenance.

Also test:
- same entry not duplicated accidentally,
- Team B denied,
- source Entry remains.

VALIDATION

Run tests.

DEFINITION OF DONE

AT-BRAIN-004 passes.

FINAL REPORT

Return:
1. transaction
2. provenance
3. privacy behavior
4. tests/results
5. assumptions
6. unresolved issues
```

---

# 31. M9.10 — Problem Storming Workflow

## Objective

Implement Session 4 Problem Storming using Development Objects rather than disconnected text.

## Copy/Paste Prompt

```text
TASK ID: M9.10
TASK: Problem Storming Workflow

Read first:

- /docs/06_COURSE_ACTIVITY_WORKFLOWS.md
- /docs/05_DEVELOPMENT_PROJECT_MODEL.md
- /docs/08_DATA_MODEL_SCHEMA.md
- approved Professional Course Session 4 curriculum

OBJECTIVE

Implement the structured Problem Storming workflow.

METHOD

Problem Storming deliberately delays solutions and challenges Concept V2 from multiple perspectives.

SUPPORTED PROBLEM CATEGORIES/PERSPECTIVES

Use the existing Problem Details model and approved categories where applicable:
- user
- functional
- technical
- cost
- safety
- environmental
- accessibility
- maintenance

FLOW

1. user/team opens Problem Storming Activity.
2. select/reference current Concept input where configured.
3. create Development Objects type PROBLEM.
4. create/populate problem_details.
5. associate each Problem with Activity output.
6. preserve creator and Workspace.
7. allow many Problems without evaluation/ranking.
8. build Problem Bank Artifact from the canonical Problem Objects.

IMPORTANT

Do not:
- score Problems,
- vote,
- eliminate,
- auto-select winner,
- generate Solutions in the same "Problem creation" action.

TEST

- create Problems across categories
- stable Problem IDs
- Problem Bank references same Problems
- Team B denied
- Session 5 can later reference same Problem IDs

VALIDATION

Run tests.

DEFINITION OF DONE

Problem Storming produces structured Problems and a Problem Bank suitable for later evaluation.

FINAL REPORT

Return:
1. workflow
2. categories
3. Object creation
4. Artifact integration
5. tests/results
6. assumptions
7. unresolved issues
```

---

# 32. M9.11 — Problem Bank Artifact

## Objective

Create a versioned higher-level Problem Bank output from stable Problem Objects.

## Copy/Paste Prompt

```text
TASK ID: M9.11
TASK: Problem Bank Artifact

Read first:

- /docs/08_DATA_MODEL_SCHEMA.md
- /docs/22_CODEX_M8_PROMPTS.md
- approved Professional Course Session 4 curriculum

OBJECTIVE

Implement PROBLEM_BANK Artifact composition.

FLOW

1. create or resolve Problem Bank Artifact for Activity/Project context.
2. create Draft Artifact Version.
3. add artifact_object_links for selected/current Problem Objects.
4. preserve ordering through sequence where applicable.
5. do not duplicate Problem Objects.
6. register Artifact as Activity Output.
7. allow M8 review/version workflow when Activity requires review/approval.

CONTENT

Artifact content snapshot may contain presentation/summary structure,
but canonical Problems remain Development Objects.

TEST

- Problem Bank V1 created
- links Problem P1/P2/P3
- same Problem IDs reused
- Artifact Version history works
- Team B denied
- approved Problem Bank can satisfy downstream Activity dependency

VALIDATION

Run Activity + Artifact integration tests.

DEFINITION OF DONE

Session 4 Problem Bank is a versioned Artifact backed by stable Problem Objects.

FINAL REPORT

Return:
1. Artifact flow
2. Object links
3. version behavior
4. dependency integration
5. tests/results
```

---

# 33. M9.12 — Solution Generation Workflow

## Objective

Generate multiple possible Solutions for selected Problems without evaluation.

## Curriculum Rule

For each selected Problem:

```text
Select Problem
→ Choose Brainstorming Method
→ Generate Multiple Solutions
→ Keep All During Divergence
```

No ranking/voting/elimination in M9.

## Copy/Paste Prompt

```text
TASK ID: M9.12
TASK: Solution Generation Workflow

Read first:

- /docs/06_COURSE_ACTIVITY_WORKFLOWS.md
- /docs/05_DEVELOPMENT_PROJECT_MODEL.md
- approved Professional Course Session 4 curriculum

OBJECTIVE

Implement Problem → multiple Solution generation using Development Objects.

FLOW

1. select existing PROBLEM Development Object.
2. start/use Brainstorming Activity.
3. generate entries.
4. promote selected entries to Development Objects type SOLUTION.
5. create explicit Object Relationship:
   Solution → relevant Problem
using approved SOLVES semantic/direction.
6. preserve Brainstorm provenance.
7. do not rank/evaluate in M9.

RULES

- Problem must belong to same authorized Project.
- Team B cannot create Solution relationship to Team A Problem.
- one Brainstorm Entry promotion should be idempotent.
- multiple Solutions per Problem supported.

TEST

Problem P1:
- S1
- S2
- S3

Verify:
- all are stable SOLUTION Objects,
- all link to P1,
- no vote/selection state created.

VALIDATION

Run tests.

DEFINITION OF DONE

Brainstorming can produce structured Solution alternatives linked to specific Problems.

FINAL REPORT

Return:
1. workflow
2. relationship semantics
3. provenance
4. tests/results
5. assumptions
6. unresolved issues
```

---

# 34. M9.13 — Solution Bank Artifact

## Objective

Create a versioned Solution Bank that preserves Problem/Solution structure.

## Copy/Paste Prompt

```text
TASK ID: M9.13
TASK: Solution Bank Artifact

Read first:

- /docs/08_DATA_MODEL_SCHEMA.md
- /docs/22_CODEX_M8_PROMPTS.md
- approved Professional Course Session 4 curriculum

OBJECTIVE

Implement SOLUTION_BANK Artifact composition.

FLOW

1. create/resolve Solution Bank Artifact.
2. create Draft Artifact Version.
3. link canonical SOLUTION Development Objects.
4. preserve Problem relationships separately in Development Object Relationships.
5. optionally include structural grouping in content_snapshot/metadata.
6. register Solution Bank as Activity Output.
7. use M8 review/approval if Activity configuration requires.

IMPORTANT

Do not:
- duplicate Solution Objects,
- flatten away Problem/Solution relationships,
- select winning Solution,
- invoke Voting.

TEST

- Problem P1 has S1/S2/S3
- Problem P2 has S4/S5
- Solution Bank references S1-S5
- Project relationships remain intact
- approved Solution Bank available to Session 5 dependency

VALIDATION

Run tests.

DEFINITION OF DONE

Solution Bank is a versioned structured Artifact suitable for M10 evaluation.

FINAL REPORT

Return:
1. Artifact composition
2. Object linkage
3. Problem/Solution traceability
4. tests/results
```

---

# 35. M9.14 — Activity Integration

## Objective

Connect SCAMPER, Brainstorming, Problem Storming and Bank outputs to the generic M7 Activity Engine.

## Copy/Paste Prompt

```text
TASK ID: M9.14
TASK: M9 Activity Integration

Read first:

- /docs/21_CODEX_M7_PROMPTS.md
- /docs/22_CODEX_M8_PROMPTS.md
- /docs/06_COURSE_ACTIVITY_WORKFLOWS.md

OBJECTIVE

Integrate methodology tools with Activity Instances.

SCAMPER

- SCAMPER Entries belong to SCAMPER Activity Instance.
- promoted Ideas register as Activity Outputs where configured.

BRAINSTORMING

- Brainstorm Entries belong to Brainstorming Activity Instance.
- promoted Ideas/Solutions register as Activity Outputs.

PROBLEM STORMING

- PROBLEM Objects register as Activity Outputs.
- Problem Bank Artifact registers as Activity Output.

SOLUTION GENERATION

- SOLUTION Objects register as Activity Outputs.
- Solution Bank Artifact registers as Activity Output.

INPUTS

Use canonical approved inputs where required:
- current concept,
- Problem Bank,
- selected Problems.

DEPENDENCIES

Preserve M7/M8 server-side dependency checks.

TEST

- Activity resume returns methodology output references.
- outputs survive logout.
- approved Problem/Solution Bank can feed next Activity.
- no duplicate Project Object on reuse.

VALIDATION

Run integration tests.

DEFINITION OF DONE

M9 tools behave as native Activity implementations rather than standalone pages.

FINAL REPORT

Return:
1. integration map
2. input/output types
3. dependency behavior
4. tests/results
```

---

# 36. M9.15 — SCAMPER RLS

## Objective

Protect SCAMPER entries at the database boundary.

## Copy/Paste Prompt

```text
TASK ID: M9.15
TASK: SCAMPER RLS

Read first:

- /docs/03_ROLES_PERMISSIONS.md
- /docs/04_WORKSPACE_TEAM_COLLABORATION.md
- /docs/12_ACCEPTANCE_TESTS.md

OBJECTIVE

Implement RLS for `scamper_entries`.

RULES

PERSONAL
- owner/creator in authorized Personal Activity can read/write while editable.
- another Student denied.
- Master not automatically granted.
- Team membership does not expose Personal entry.

TEAM
- authorized Team Activity participants according to scope.
- Team B denied.
- removed member denied.

MUTATION
Normal client cannot:
- spoof created_by,
- move entry to another Workspace/Project,
- link Team B Idea,
- mutate locked entry after workflow state forbids it.

DIRECT ID TESTS

Known SCAMPER Entry ID must not bypass Workspace/Project privacy.

VALIDATION

Run RLS/security suite.

DEFINITION OF DONE

AT-SCAMPER-002 is enforced by database security as well as service logic.

FINAL REPORT

Return policies, attack tests and results.
```

---

# 37. M9.16 — Brainstorm RLS & Reveal Security

## Objective

Enforce hidden-before-reveal behavior directly.

## Copy/Paste Prompt

```text
TASK ID: M9.16
TASK: Brainstorm RLS & Reveal Security

Read first:

- /docs/04_WORKSPACE_TEAM_COLLABORATION.md
- /docs/08_DATA_MODEL_SCHEMA.md
- /docs/12_ACCEPTANCE_TESTS.md

OBJECTIVE

Implement database protections for `brainstorm_entries`.

BEFORE REVEAL

Creator may read own entry.
Peer participants may NOT read it.

AFTER REVEAL

Authorized Activity pool may read according to Activity/Team scope.

OTHER TEAM

Never allowed.

REMOVED MEMBER

No future access to Team Brainstorm pool.

MUTATION

Normal client cannot:
- set revealed_at directly to bypass reveal command,
- set created_by,
- attach inaccessible parent_entry_id,
- attach inaccessible Development Object,
- move entry to another Team Workspace.

TEST

- A1 cannot SELECT A2 hidden entry
- exact Entry ID denied
- direct DB query denied
- A1/A2 can read revealed pool after authorized reveal
- Team B never sees pool
- removed A1 denied future Team entries

PRIORITY

AT-BRAIN-002 = BLOCKER

DEFINITION OF DONE

Private-before-reveal cannot be bypassed through direct database access.

FINAL REPORT

Return:
1. RLS design
2. reveal condition handling
3. attack matrix
4. results
```

---

# 38. M9.17 — AT-SCAMPER-001 to 003

## Objective

Implement the complete SCAMPER acceptance suite at the maximum scope M9 supports.

## Copy/Paste Prompt

```text
TASK ID: M9.17
TASK: SCAMPER Acceptance Tests

Read first:

- /docs/12_ACCEPTANCE_TESTS.md
- /docs/23_CODEX_M9_PROMPTS.md

AT-SCAMPER-001

Student saves:
- lens
- original element
- proposed change
- result

Expected: PASS.

AT-SCAMPER-002

A1 Personal SCAMPER Entry stays private until explicitly shared.

Test:
- UI/service
- direct ID
- direct DB query

Expected: PASS.
Priority: BLOCKER.

AT-SCAMPER-003

Selected SCAMPER Entry becomes available to Team A while original creator remains recorded.

IMPORTANT

If M13 general sharing is not yet implemented:
- do not fake a share.
- test any approved M9 promotion path if it satisfies the actual source requirement.
- otherwise record AT-SCAMPER-003 as `DEFERRED — standard sharing dependency M13`.

The original Personal Workspace must never be exposed.

FINAL REPORT

Return:
1. AT-SCAMPER-001 PASS/FAIL
2. AT-SCAMPER-002 PASS/FAIL
3. AT-SCAMPER-003 PASS/FAIL/DEFERRED
4. reason for any deferral
5. attack results
```

---

# 39. M9.18 — AT-BRAIN-001 to 004

## Objective

Implement the complete Brainstorming acceptance suite.

## Copy/Paste Prompt

```text
TASK ID: M9.18
TASK: Brainstorming Acceptance Tests

Read first:

- /docs/12_ACCEPTANCE_TESTS.md
- /docs/23_CODEX_M9_PROMPTS.md

AT-BRAIN-001 — Independent Generation

Each Team member creates private entries before reveal when configured.

Expected: PASS.

AT-BRAIN-002 — No Premature Reveal

A1 cannot see A2 unrevealed entry.

Test:
- list
- exact ID
- database
- parent-reference path

Expected: PASS.
Priority: BLOCKER.

AT-BRAIN-003 — Reveal

Authorized reveal makes eligible entries visible to authorized Team participants.

Expected: PASS.

AT-BRAIN-004 — Promote Entry

Brainstorm Entry converts to IDEA Development Object with provenance.

Expected: PASS.

Also verify:
- source entry remains,
- creator recorded,
- Team B denied,
- no duplicate Idea on retry.

FINAL REPORT

Return test matrix and results.
```

---

# 40. M9.19 — Professional Session 4 Integration Scenario

## Objective

Validate the actual approved Session 4 methodology flow.

## Curriculum-Derived Scenario

```text
Concept V2
↓
Problem Storming
↓
Problem Bank
↓
Select Problem
↓
Brainstorming
↓
Multiple Solutions
↓
Solution Bank
↓
Bring Problem Bank + Solution Bank forward to Session 5
```

## Copy/Paste Prompt

```text
TASK ID: M9.19
TASK: Professional Session 4 Integration Scenario

Read first:

- /docs/06_COURSE_ACTIVITY_WORKFLOWS.md
- approved Professional Course Session 4 curriculum
- /docs/23_CODEX_M9_PROMPTS.md

OBJECTIVE

Implement a test scenario matching the approved Session 4 flow.

SCENARIO

1. Project A has Concept V2 input fixture.
2. Team A starts Problem Storming Activity.
3. Team creates Problems across multiple approved perspectives.
4. System stores PROBLEM Development Objects.
5. Problem Bank Artifact Draft created.
6. Problem Objects linked into Problem Bank.
7. Select one Problem.
8. Start Brainstorming for Solutions.
9. Team members generate independently if configured.
10. reveal occurs.
11. selected entries promoted to SOLUTION Development Objects.
12. each Solution linked to selected Problem.
13. Solution Bank Artifact created.
14. Solution Objects linked into Solution Bank.
15. Problem Bank + Solution Bank are registered as Activity Outputs.
16. after required review/approval configuration, both are available to Session 5 dependency/input.

VERIFY

- no Voting occurred,
- no Solution winner auto-selected,
- all Problems/Solutions have stable IDs,
- provenance preserved,
- Team B cannot access,
- outputs persist after logout.

DEFINITION OF DONE

The platform reproduces the Session 4 learning/development flow without reducing it to text submissions.

FINAL REPORT

Return lifecycle table and PASS/FAIL.
```

---

# 41. M9.20 — Cross-Team / Private Methodology Leakage Tests

## Objective

Attack M9 privacy boundaries.

## Copy/Paste Prompt

```text
TASK ID: M9.20
TASK: M9 Leakage Security Tests

FIXTURES

- A1 Personal SCAMPER Entry
- A2 Personal SCAMPER Entry
- Team A hidden Brainstorm entries
- Team A revealed pool
- Team A Problem Bank
- Team A Solution Bank
- Team B user
- removed Team A user

ATTEMPT

As Team B:
- exact SCAMPER Entry ID
- exact Brainstorm Entry ID
- list Team A hidden/revealed entries
- query Problem/Solution Objects
- fetch Problem Bank/Solution Bank
- create parent relation to Team A entry
- promote Team A entry
- direct DB queries

As A1 before reveal:
- read A2 hidden Brainstorm entry

As removed Team A user:
- read new Team Brainstorm entries
- promote Team entry
- access Team Problem/Solution Bank

EXPECTED

All unauthorized access/mutations denied.

DEFINITION OF DONE

No M9 cross-Team or hidden-entry leak remains.

FINAL REPORT

Return attack matrix and results.
```

---

# 42. M9.21 — M9 Security & Integrity Hardening

## Objective

Review the first methodology layer before Voting/Decision tools are introduced.

## Copy/Paste Prompt

```text
TASK ID: M9.21
TASK: M9 Security & Integrity Hardening

Read first:

- /docs/03_ROLES_PERMISSIONS.md
- /docs/04_WORKSPACE_TEAM_COLLABORATION.md
- /docs/05_DEVELOPMENT_PROJECT_MODEL.md
- /docs/06_COURSE_ACTIVITY_WORKFLOWS.md
- /docs/08_DATA_MODEL_SCHEMA.md
- /docs/11_API_CONTRACTS.md
- /docs/12_ACCEPTANCE_TESTS.md
- /docs/20_CODEX_M6_PROMPTS.md
- /docs/21_CODEX_M7_PROMPTS.md
- /docs/22_CODEX_M8_PROMPTS.md
- /docs/23_CODEX_M9_PROMPTS.md

OBJECTIVE

Perform M9 security and integrity hardening.

VERIFY

1. all seven SCAMPER lenses supported.
2. invalid SCAMPER lens rejected.
3. Personal SCAMPER remains private.
4. Brainstorm private-before-reveal enforced.
5. direct DB query cannot reveal hidden entries.
6. authorized reveal only affects entries in Activity.
7. promoted Idea preserves provenance.
8. promoted Solution preserves Brainstorm provenance.
9. Problem Bank references canonical Problems.
10. Solution Bank references canonical Solutions.
11. Problem/Solution IDs remain stable.
12. Team B cannot access Team A methodology data.
13. removed member cannot access future Team methodology data.
14. M9 does not perform Voting.
15. M9 does not implement general Sharing records unless M13 primitive already exists.
16. no M10+ feature implemented prematurely.

RUN

pnpm lint
pnpm typecheck
pnpm test:unit
pnpm test:integration
pnpm test:e2e
pnpm build
plus all configured RLS tests.

DEFINITION OF DONE

- AT-SCAMPER-001 PASS
- AT-SCAMPER-002 PASS
- AT-SCAMPER-003 PASS or explicitly correct M13 dependency
- AT-BRAIN-001 PASS
- AT-BRAIN-002 PASS
- AT-BRAIN-003 PASS
- AT-BRAIN-004 PASS
- Professional Session 4 integration PASS
- zero known hidden-entry leak
- zero known cross-Team leak
- no M10+ scope creep

FINAL REPORT

Return:
1. security review
2. integrity review
3. issues found
4. issues fixed
5. remaining issues
6. BLOCKER status
7. test results
8. recommendation: READY FOR M10 or NOT READY FOR M10
```

---

# 43. SCAMPER Entry vs Idea Object

Do not conflate:

```text
SCAMPER Entry
```

with:

```text
IDEA Development Object
```

The SCAMPER Entry records methodology-specific reasoning.

The Idea Object records persistent Project content.

One SCAMPER Entry may optionally create/link an Idea.

The source SCAMPER Entry remains for provenance.

---

# 44. Brainstorm Entry vs Idea/Solution Object

Likewise:

```text
Brainstorm Entry
```

is not automatically a canonical Idea/Solution.

A Brainstorm Activity may produce many transient/raw entries.

Selected entries can be explicitly promoted.

This avoids turning every rough thought into permanent Project structure.

---

# 45. Problem vs Brainstorm Entry

Problem Storming should create structured PROBLEM Development Objects where the workflow intends persistent Problem Bank output.

Do not treat every Problem merely as a generic Brainstorm entry if it is meant to persist into later Sessions.

---

# 46. Solution vs Brainstorm Entry

Brainstorm entries may be the raw generation layer.

Promoted Solutions become:

```text
Development Object type SOLUTION
```

and can be linked to Problems, Artifacts and later Voting.

---

# 47. No Early Evaluation

Session 4 explicitly separates divergence from evaluation.

M9 must not add:

- score,
- rank,
- winner,
- top idea,
- accepted solution,
- vote count,

as automatic generation behavior.

M10 owns convergence and decisions.

---

# 48. Problem Categories

The course explicitly uses perspectives including:

- User,
- Function,
- Technical,
- Cost,
- Safety,
- Environment,
- Accessibility,
- Maintenance.

Map these to existing `problem_details.problem_category` values where the schema supports them.

Do not silently invent incompatible alternate labels.

If exact `functional` vs `function` naming differs in schema, preserve database vocabulary while keeping course labels visible at the product layer.

---

# 49. SCAMPER Lens Labels

Database values may use:

```text
PUT_TO_ANOTHER_USE
REVERSE_REARRANGE
```

while curriculum presentation may show:

```text
Put to Another Use
Reverse / Rearrange
```

Preserve the exact curriculum-facing wording without changing stable enum codes.

---

# 50. Editable States

SCAMPER/Brainstorm entries should only be editable while their Activity/workflow state allows editing.

Do not permit a raw-entry update to mutate an approved Artifact Version that references/promotes the entry.

Canonical promoted Project Objects and approved Artifacts have their own workflows.

---

# 51. Provenance

Promotion should preserve:

```text
source method
source Activity Instance
source entry ID
creator
Workspace
Project
timestamp
```

This is required so later AI/review systems can distinguish:

```text
raw brainstorm idea
vs
structured Project Idea
```

---

# 52. Reveal Is Not Approval

A revealed Brainstorm entry is merely visible to the Activity pool.

It is not:

- accepted,
- selected,
- approved,
- voted winner,
- Project baseline.

Do not change acceptance state merely because reveal occurred.

---

# 53. Promotion Is Not Approval

Promoting an entry to an Idea/Solution means:

```text
save as structured Project content
```

It does not mean:

```text
human team approved this as final direction
```

M10 Decisions and M8 Artifact approval remain separate.

---

# 54. Problem Bank / Solution Bank Versioning

Problem Bank and Solution Bank use M8 Artifact Versioning.

Therefore:

- bank content can be revised,
- prior versions remain,
- approved versions immutable,
- later Sessions can request approved/current Bank output,
- Development Objects remain stable across Bank versions.

---

# 55. Reuse Across Sessions

A Problem in Problem Bank V1 should be referenceable later by:

- Voting,
- Affinity,
- Mind Map,
- AI,
- Patent analysis.

Do not duplicate it when another tool uses it.

Likewise Solution Objects should retain stable IDs.

---

# 56. Same Project / Workspace Rules

All M9 records must bind correctly to:

```text
Activity Instance
Project
Workspace
Team if applicable
```

Do not allow mismatched foreign IDs submitted by clients.

Derive context from Activity where possible.

---

# 57. Activity Configuration Drives Privacy

Not every Brainstorming Activity must use hidden-before-reveal.

The Activity Definition/configuration determines behavior.

M9 engine must support:

- private-before-reveal,
- directly shared/team-visible generation,

if both are approved configurations.

Do not hard-code one mode globally.

---

# 58. Reveal Authority

Reveal authority should come from Activity configuration/policy.

Possible actors may include:

- Master,
- Activity host,
- Team workflow role.

Do not assume Team Lead reveal power unless approved.

---

# 59. SCAMPER Personal → Team Future Flow

The intended future flow can be:

```text
Personal SCAMPER Entry
↓
explicit share/promote
↓
Team can access selected entry/output
↓
creator remains recorded
```

M9 must preserve compatibility with this without exposing the entire Personal Workspace.

---

# 60. M9 Expected Repository Additions

Conceptually:

```text
features/
├── scamper/
│   ├── operations/
│   ├── promotion/
│   ├── access/
│   └── validation/
├── brainstorming/
│   ├── operations/
│   ├── reveal/
│   ├── promotion/
│   └── access/
└── problem-solution/
    ├── problem-storming/
    ├── problem-bank/
    ├── solution-generation/
    └── solution-bank/

lib/
├── permissions/
│   ├── scamper.ts
│   └── brainstorming.ts
└── provenance/

supabase/
├── migrations/
│   ├── ...scamper_entries...
│   ├── ...brainstorm_entries...
│   └── ...m9_rls...
└── tests/
    └── rls/
        ├── scamper...
        └── brainstorming...

tests/
├── unit/
│   ├── scamper/
│   ├── brainstorming/
│   └── problem-solution/
├── integration/
│   ├── scamper/
│   ├── brainstorming/
│   └── session4/
└── e2e/
    └── professional-session4.spec.ts
```

Exact paths may vary.

---

# 61. M9 Completion Gate

M9 is complete only when:

```text
[ ] scamper_entries exists
[ ] all seven SCAMPER lenses supported
[ ] createScamperEntry() implemented
[ ] updateScamperEntry() implemented
[ ] SCAMPER → Idea promotion implemented

[ ] Personal SCAMPER privacy enforced
[ ] exact SCAMPER ID cannot bypass privacy

[ ] brainstorm_entries exists
[ ] createBrainstormEntry() implemented
[ ] private-before-reveal mode works
[ ] revealBrainstormEntries() implemented
[ ] promoteBrainstormEntryToIdea() implemented
[ ] parent/extension relation works safely

[ ] unrevealed peer entries hidden
[ ] direct DB hidden-entry access blocked
[ ] revealed pool visible only to authorized Activity scope

[ ] Problem Storming creates PROBLEM Objects
[ ] problem_details used where applicable
[ ] Problem Bank Artifact implemented
[ ] Problem Bank uses stable Problem Objects

[ ] Solution generation creates SOLUTION Objects
[ ] Solutions relate to Problems
[ ] Solution Bank Artifact implemented
[ ] Solution Bank uses stable Solution Objects

[ ] no automatic ranking/voting/selection
[ ] methodology outputs registered with Activity Engine
[ ] Artifact Versioning used for Banks
[ ] provenance retained through promotion

[ ] AT-SCAMPER-001 PASS
[ ] AT-SCAMPER-002 PASS
[ ] AT-SCAMPER-003 PASS or explicitly valid M13 deferral

[ ] AT-BRAIN-001 PASS
[ ] AT-BRAIN-002 PASS
[ ] AT-BRAIN-003 PASS
[ ] AT-BRAIN-004 PASS

[ ] Professional Session 4 integration PASS

[ ] lint passes
[ ] typecheck passes
[ ] unit tests pass
[ ] integration tests pass
[ ] E2E tests pass
[ ] RLS tests pass
[ ] build passes

[ ] no M10+ feature implemented prematurely
[ ] Codex reports READY FOR M10
```

Any premature reveal is:

```text
BLOCKER
```

Any Personal Workspace methodology leak is:

```text
BLOCKER
```

---

# 62. Recommended Commit Sequence

Example:

```text
feat(scamper): add SCAMPER schema and seven lenses
feat(scamper): add create/update operations
feat(scamper): add Idea promotion
feat(brainstorm): add Brainstorm entry schema
feat(brainstorm): add private generation
feat(brainstorm): add reveal workflow
feat(brainstorm): add Idea promotion
feat(problem): add Problem Storming workflow
feat(artifacts): add Problem Bank integration
feat(solution): add Solution generation and relationships
feat(artifacts): add Solution Bank integration
feat(activities): integrate M9 methodology outputs
feat(security): add SCAMPER/Brainstorm RLS
test(scamper): add AT-SCAMPER suite
test(brainstorm): add AT-BRAIN suite
test(session4): add Professional Session 4 flow
test(security): add M9 leakage coverage
chore(security): complete M9 hardening
```

---

# 63. M9 Non-Goals

Do not accept these as "helpful additions" during M9:

- Dot Voting,
- Fist to Five,
- Planning Poker,
- Decision Records,
- Affinity groups,
- Mind Map,
- Evidence records,
- Patent search,
- Patent comparison,
- AI Assistant,
- generic Sharing records,
- cross-Team share UI,
- Liveblocks canvas,
- automatic ranking,
- automatic winner selection,
- automatic idea rejection.

---

# 64. Potential M9 Ambiguities Codex Must Flag

Do not silently decide if approved docs do not resolve:

- exact SCAMPER entry `status` vocabulary,
- whether every SCAMPER entry automatically creates an Idea Object,
- whether Idea promotion is one-click or requires confirmation,
- whether promoted Idea inherits creator or promoting user,
- whether private Brainstorm entries are visible to Master before reveal,
- whether Master can reveal all entries,
- whether Team Lead can reveal,
- whether participants can reveal their own entries individually,
- whether reveal can be reversed,
- whether revealed entries can be edited afterward,
- exact `visibilityState` vocabulary,
- whether Brainstorm entry can be promoted before reveal,
- whether private Brainstorm promotion should create Personal Idea or Team Idea,
- whether Problem Storming uses Brainstorm Entry records or directly creates Problems,
- whether every identified Problem must enter Problem Bank automatically,
- whether every promoted Solution must enter Solution Bank automatically,
- whether Solution → Problem relationship direction is exactly `SOLUTION SOLVES PROBLEM`,
- whether one Solution can solve multiple Problems,
- whether Problem Bank/Solution Bank are one Artifact per Activity, Session, Team, or Project,
- whether Bank Artifact approval is mandatory for Session 5 dependency,
- how AT-SCAMPER-003 should be satisfied before M13 standard Sharing exists.

If unresolved:

```text
STOP → FLAG → ASK
```

---

# 65. Recommended Safe Defaults for Purely Technical Decisions

Only where they do not alter approved product policy:

- UUID SCAMPER/Brainstorm Entry IDs,
- creator server-derived,
- strict seven-lens enum,
- private-before-reveal fails closed,
- direct peer queries filtered by RLS,
- reveal timestamp immutable after reveal,
- promotion creates stable Development Object and retains source Entry,
- duplicate promotion prevented,
- Problem/Solution stored as Development Objects,
- Bank outputs stored as M8 Artifacts,
- canonical IDs reused across Sessions,
- no ranking or voting in M9,
- general sharing deferred to M13.

---

# 66. Review Checklist for Ahmad/FICI

Before implementation, confirm M9 reflects the intended methodology:

```text
1. SCAMPER has all seven lenses.

2. SCAMPER entry stores original element, proposed change and result.

3. Useful SCAMPER output can become a structured Idea.

4. Personal SCAMPER stays private until intentional sharing.

5. Brainstorming can support private generation before reveal.

6. Team members cannot see each other's hidden ideas before reveal.

7. Authorized reveal exposes only the Activity pool.

8. Brainstorm entry can become a structured Idea with provenance.

9. Problem Storming creates persistent Problem Objects.

10. Problems are explored before solutions.

11. Problem Bank uses stable Problem Objects.

12. Solution generation produces multiple alternatives.

13. Solutions link explicitly to Problems.

14. Solution Bank uses stable Solution Objects.

15. M9 does not evaluate or vote on solutions.

16. Problem Bank + Solution Bank can feed Session 5.

17. General cross-workspace sharing remains M13.
```

---

# 67. Next File After M9

After M9 has actually been:

```text
IMPLEMENTED
→ TESTED
→ SECURITY-REVIEWED
→ COMMITTED
```

create:

# `24_CODEX_M10_PROMPTS.md`

M10 will cover:

```text
Dot Voting
Voting Sessions
Voting Options
Votes
Open / Close Voting
Vote Limits
Decision Records
Decision Options
Decision Participants
Decision Links
Human Final Decision
```

M10 will convert the broad alternatives generated in M9 into structured convergence and explicit human decisions.

---

# 68. Final Execution Rule

For M9:

```text
SCAMPER SCHEMA
→ SCAMPER OPERATIONS
→ SCAMPER PROMOTION
→ SCAMPER PRIVACY
→ BRAINSTORM SCHEMA
→ PRIVATE GENERATION
→ REVEAL
→ IDEA PROMOTION
→ PROBLEM STORMING
→ PROBLEM BANK
→ SOLUTION GENERATION
→ SOLUTION BANK
→ ACTIVITY INTEGRATION
→ RLS
→ ACCEPTANCE TESTS
→ SESSION 4 E2E
→ SECURITY HARDENING
```

Do not skip directly to Voting or Decision Records.

---

# End of Document

**Current Status:** Draft v0.1 — Ready for Ahmad/FICI review.  
**Execution Step After M8 Completion:** Start with **M9.1 — SCAMPER Schema**.
