# FICI Invention Education & Development Platform
## Codex Implementation Plan

**Document:** `13_CODEX_IMPLEMENTATION_PLAN.md`  
**Status:** Draft v0.1 — For Review  
**Depends on:** `01_PRODUCT_REQUIREMENTS.md` through `12_ACCEPTANCE_TESTS.md`  
**Purpose:** Convert the approved product and technical specifications into a staged, testable implementation sequence for Codex.

---

# 1. Implementation Principle

Codex must not be asked to build the entire platform in one task.

The platform should be implemented as a sequence of bounded milestones.

Every milestone must include:

- exact objective,
- in-scope functionality,
- explicit non-goals,
- schema changes,
- business operations,
- permissions,
- tests,
- acceptance criteria,
- Codex implementation prompt,
- definition of done.

The implementation order must respect architectural dependencies.

---

# 2. Source of Truth

Codex must treat the following files as authoritative:

```text
/docs/
├── 01_PRODUCT_REQUIREMENTS.md
├── 02_PLATFORM_ARCHITECTURE.md
├── 03_ROLES_PERMISSIONS.md
├── 04_WORKSPACE_TEAM_COLLABORATION.md
├── 05_DEVELOPMENT_PROJECT_MODEL.md
├── 06_COURSE_ACTIVITY_WORKFLOWS.md
├── 07_MVP_SCOPE.md
├── 08_DATA_MODEL_SCHEMA.md
├── 09_AI_ASSISTANT_SPEC.md
├── 10_TECHNICAL_ARCHITECTURE.md
├── 11_API_CONTRACTS.md
├── 12_ACCEPTANCE_TESTS.md
└── 13_CODEX_IMPLEMENTATION_PLAN.md
```

Implementation may refine technical details, but must not contradict approved product rules.

If a requirement is ambiguous:

**STOP → FLAG → ASK**

Do not silently invent business behavior.

---

# 3. Technical Baseline

Initial implementation target:

```text
Next.js 16.3 Active LTS
React
TypeScript
pnpm
Supabase PostgreSQL
Supabase Auth
Supabase Storage
Supabase Realtime
Liveblocks
React Flow
OpenAI Responses API
Daily
Resend
Vercel
Vitest
Playwright
Zod
```

The application architecture should remain a modular monolith.

---

# 4. Milestone Structure

Recommended sequence:

```text
M0  Repository & Environment
M1  Authentication & User Foundation
M2  Roles, Scope & RLS Security
M3  Programs, Curriculum, Cohorts & Enrollment
M4  Workspaces
M5  Teams, Membership & Team Chat
M6  Development Project Core
M7  Activity Engine
M8  Artifacts, Versioning, Review & Approval
M9  SCAMPER, Brainstorming & Problem/Solution
M10 Voting & Decision Records
M11 Affinity & Mind Mapping
M12 Evidence, Files & Patent Workspace
M13 Sharing & Cross-Team Access
M14 AI Context & AI Assistance
M15 Progress, Notifications & Pilot Workflow
M16 Live Classroom Integration
M17 Pilot Hardening, Security & Release
```

Do not reorder casually.

Several later milestones depend on earlier permission and data foundations.

---

# 5. M0 — Repository & Environment

## Objective

Create a stable development foundation.

## In Scope

- Git repository structure
- Next.js application
- TypeScript strict mode
- pnpm
- linting
- formatting
- environment validation
- Supabase local/dev setup
- test framework
- CI skeleton
- `/docs` folder
- architecture folder boundaries

## Non-Goals

- business features,
- UI polish,
- AI,
- realtime collaboration.

## Required Files / Modules

```text
/app
/components
/features
/lib
/supabase
/tests
/docs
/scripts
```

## Environment Variables

Set placeholders for:

```text
NEXT_PUBLIC_SUPABASE_URL
NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY
SUPABASE_SECRET_KEY
OPENAI_API_KEY
LIVEBLOCKS_SECRET_KEY
DAILY_API_KEY
RESEND_API_KEY
```

## Tests

- application builds,
- lint passes,
- typecheck passes,
- environment schema rejects missing required variables,
- test runner executes.

## Definition of Done

```text
pnpm install
pnpm lint
pnpm typecheck
pnpm test
pnpm build
```

all pass.

## Codex Prompt

> Read `/docs/10_TECHNICAL_ARCHITECTURE.md`, `/docs/12_ACCEPTANCE_TESTS.md`, and this milestone. Initialize the FICI platform repository as a Next.js 16.3 Active LTS TypeScript application using pnpm. Use strict TypeScript, Zod environment validation, Vitest, Playwright, and the approved folder structure. Do not implement product features yet. Add a README with local setup instructions and a CI workflow that runs lint, typecheck, tests, and build. Do not invent business rules.

---

# 6. M1 — Authentication & User Foundation

## Objective

Allow secure user authentication and platform profile creation.

## In Scope

- Supabase Auth
- email/password login
- logout
- password reset
- email verification support
- user profile record
- authenticated protected routes
- current-user server helper

## Schema

Implement:

- `users`
- minimal account status fields

## Business Operations

- `getCurrentUser()`
- `updateOwnProfile()`

## Security

- server derives user identity,
- no client-provided trusted user ID,
- protected routes require authenticated session.

## Acceptance Tests

From `12_ACCEPTANCE_TESTS.md`:

- AT-AUTH-001
- AT-AUTH-002
- AT-AUTH-003
- AT-AUTH-004

## Definition of Done

A valid test user can:

- sign in,
- sign out,
- access protected routes,
- update own profile,
- fail safely when unauthenticated.

## Codex Prompt

> Implement M1 only. Read the authentication, user, API, and acceptance-test sections of `/docs`. Use Supabase Auth. Create the platform profile table and server-side current-user helper. Protect authenticated routes. Do not implement roles beyond the minimal structures needed for later migrations. Add unit/integration/E2E tests for AT-AUTH-001 through AT-AUTH-004.

---

# 7. M2 — Roles, Scope & RLS Security

## Objective

Establish the permission foundation before collaborative product features.

## In Scope

- roles
- scoped role assignments
- permission helper functions
- Row Level Security
- server-side authorization helpers
- RLS test suite

## Schema

Implement:

- `roles`
- `role_assignments`
- organization shell if required for scope
- authorization helper functions

Seed roles:

```text
ADMIN
MASTER
MENTOR
STUDENT
```

## Important Rule

Role alone is insufficient.

Authorization uses:

```text
Role + Scope + Resource
```

## RLS Test Foundation

Create reusable test identities:

- Admin
- Master
- Mentor
- Student A
- Student B

## Acceptance Tests

- AT-RBAC-001
- AT-RBAC-002
- AT-RBAC-003
- relevant RLS security tests

## Definition of Done

A student cannot execute Admin operations.

A Master outside the target scope cannot access it.

RLS enforcement is tested directly.

## Codex Prompt

> Implement M2 only. Read `/docs/03_ROLES_PERMISSIONS.md`, `/docs/08_DATA_MODEL_SCHEMA.md`, `/docs/10_TECHNICAL_ARCHITECTURE.md`, `/docs/11_API_CONTRACTS.md`, and the RLS tests in `/docs/12_ACCEPTANCE_TESTS.md`. Create roles, scoped assignments, authorization helpers, and database RLS foundations. Add direct RLS tests. Do not rely on frontend visibility for security.

---

# 8. M3 — Programs, Curriculum, Cohorts & Enrollment

## Objective

Create the educational structure required to run a cohort.

## In Scope

- organization
- programs
- curriculum versions
- session definitions
- activity definitions
- cohorts
- enrollments
- assigned Master

## Schema

Implement:

- `organizations`
- `programs`
- `curriculum_versions`
- `session_definitions`
- `activity_definitions`
- `activity_dependencies`
- `cohorts`
- `enrollments`

## Admin Operations

- create cohort
- update cohort
- enroll user
- remove enrollment
- assign Master

## Initial Seed Data

Seed at least:

```text
FICI
Professional Course
Curriculum Version 2026 v1
Sessions 1–10
```

Detailed activities may initially be partial seed data.

## Definition of Done

Admin can create a cohort and enroll users.

Master sees assigned cohort only.

## Codex Prompt

> Implement M3 only. Create the program/curriculum/cohort/enrollment model from the approved schema. Seed the Professional Course 2026 v1 structure without changing curriculum order or labels. Implement create/update cohort and enrollment operations. Preserve cohort-to-curriculum-version linkage.

---

# 9. M4 — Workspaces

## Objective

Introduce explicit collaboration scopes.

## In Scope

- Personal Workspace
- Team Workspace schema foundation
- Master Workspace
- Case Study Workspace
- workspace access resolution

## Schema

Implement:

- `workspaces`

Workspace types:

```text
PERSONAL
TEAM
MASTER
SHARED
CASE_STUDY
```

## Operations

- `createPersonalWorkspace()`
- `getWorkspace()`
- `listMyWorkspaces()`
- `getWorkspaceAccess()`

## Security

Personal Workspace must be private by default.

## Acceptance Tests

- AT-PW-001
- AT-PW-002
- AT-PW-003

## Definition of Done

Student A cannot access Student B Personal Workspace using:

- UI,
- API,
- direct ID,
- database query under user auth.

## Codex Prompt

> Implement M4 only. Create workspace entities and access-resolution logic. Automatically provision one Personal Workspace per user. Implement RLS so Personal Workspaces are private by default. Add tests for AT-PW-001 through AT-PW-003.

---

# 10. M5 — Teams, Membership & Team Chat

## Objective

Deliver the first real collaborative environment.

## In Scope

- team creation
- Team Workspace provisioning
- team membership
- Team Lead field
- add/remove/move member
- private Team Chat
- chat membership
- realtime chat updates
- audit events

## Schema

Implement:

- `teams`
- `team_memberships`
- `chat_channels`
- `chat_memberships`
- `chat_messages`
- initial `audit_events`

## Transaction

`createTeam()` must create:

- Team
- Team Workspace
- Team Chat
- assigned Master relationship
- audit event

## Chat Realtime

Use:

- PostgreSQL as canonical storage
- Supabase Realtime/Broadcast for realtime notification

## Acceptance Tests

- AT-TEAM-001 to AT-TEAM-005
- AT-CHAT-001 to AT-CHAT-004
- team RLS tests

## Definition of Done

Team A can chat privately.

Team B cannot access Team A workspace or chat.

Removed member immediately loses future access without losing prior attribution.

## Codex Prompt

> Implement M5 only. Build Team, Team Membership, Team Workspace creation, and private Team Chat using PostgreSQL canonical storage plus Supabase Realtime. Implement add/remove/move member transactions and audit events. Apply RLS so teams are isolated. Run all AT-TEAM and AT-CHAT acceptance tests.

---

# 11. M6 — Development Project Core

## Objective

Create the persistent project model.

## In Scope

- Development Project
- project membership
- program/project links
- Development Objects
- object relationships
- current project stage
- archive
- project change log foundation

## Schema

Implement:

- `development_projects`
- `project_memberships`
- `project_program_links`
- `development_objects`
- `development_object_relationships`
- `problem_details`
- `idea_details`
- `change_log`

## Object Types

Initially support:

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

## Operations

- create project
- update project metadata
- link project to program
- create object
- update object
- archive object
- relate objects

## Acceptance Tests

- AT-PROJ-001
- AT-PROJ-002
- architecture support for AT-PROJ-003

## Definition of Done

One project can persist across sessions and structured objects can be referenced later without duplication.

## Codex Prompt

> Implement M6 only. Build the persistent Development Project and generic structured object model from `/docs/05_DEVELOPMENT_PROJECT_MODEL.md` and `/docs/08_DATA_MODEL_SCHEMA.md`. Preserve stable IDs, provenance, ownership, workspace scope, and relationships. Do not collapse project state into one mutable JSON blob.

---

# 12. M7 — Activity Engine

## Objective

Connect curriculum definitions to actual project work.

## In Scope

- Activity Instances
- participants
- inputs
- outputs
- dependencies
- start/resume/complete
- activity status

## Schema

Implement:

- `activity_instances`
- `activity_participants`
- `activity_inputs`
- `activity_outputs`

## Operations

- start activity
- resume activity
- complete activity
- add activity input
- add activity output

## Dependency Rules

Support:

- completion
- approved output
- artifact available
- gate passed

## Acceptance Tests

- AT-ACT-001
- AT-ACT-002
- AT-ACT-003
- AT-ACT-004

## Definition of Done

Approved/required output from one activity can become the actual input to a later activity.

## Codex Prompt

> Implement M7 only. Build the generic Activity Engine. Activities must come from curriculum definitions and create Activity Instances. Enforce dependencies server-side. Do not hard-code session-specific logic unless required by an approved activity configuration.

---

# 13. M8 — Artifacts, Versioning, Review & Approval

## Objective

Create the core development-history mechanism.

## In Scope

- artifacts
- artifact versions
- artifact/object links
- submissions
- feedback
- review actions
- approval
- revision
- current version pointer
- baseline foundation

## Schema

Implement:

- `artifacts`
- `artifact_versions`
- `artifact_object_links`
- `feedback_items`
- `submissions`
- `review_actions`
- `project_baseline_items`

## Critical Rule

Approved versions are immutable.

## Approval Transaction

Must atomically:

1. approve submitted version,
2. supersede previous current version,
3. update current pointer,
4. update baseline if configured,
5. close submission,
6. audit,
7. notify later when notification layer exists.

## Acceptance Tests

- AT-REV-001 to AT-REV-005
- AT-VER-001 to AT-VER-003
- AT-TX-001
- AT-CON-002

## Definition of Done

The complete:

```text
Draft → Submit → Revision → Resubmit → Approve
```

workflow works without destroying history.

## Codex Prompt

> Implement M8 only. Build artifacts, immutable versions, submission/review/revision/approval, feedback, and current baseline handling. Approval must be transactional. Write integration tests for revision history and rollback. Do not allow direct mutation of approved version bodies.

---

# 14. M9 — SCAMPER, Brainstorming & Problem/Solution

## Objective

Implement the first core FICI methodology tools.

## In Scope

- SCAMPER
- individual brainstorming
- team brainstorming
- private-before-share
- reveal
- Problem Bank
- Solution Bank
- promotion from brainstorm item to Idea
- personal-to-team sharing integration later via M13

## Schema

Implement:

- `scamper_entries`
- `brainstorm_entries`
- required Artifact types
- Development Object links

## SCAMPER

Support all seven lenses.

## Brainstorming

Support:

- personal/private creation
- team creation
- optional hidden-before-reveal
- parent/extension relation

## Problem/Solution

Use Development Objects, not separate disconnected text records.

## Acceptance Tests

- AT-SCAMPER-001 to 003
- AT-BRAIN-001 to 004

## Definition of Done

Students can work independently, reveal selectively, and convert outputs into structured project objects.

## Codex Prompt

> Implement M9 only. Create native SCAMPER, Brainstorming, Problem Bank, and Solution Bank workflows. Preserve private-before-share behavior. SCAMPER and brainstorming outputs must link into the Development Project rather than remain isolated text submissions.

---

# 15. M10 — Voting & Decision Records

## Objective

Support structured convergence and human decisions.

## In Scope

- Dot Voting
- voting options
- votes
- open/close
- configurable vote limit
- Decision Records
- link decision to vote/evidence/artifact

## Schema

Implement:

- `voting_sessions`
- `voting_options`
- `votes`
- `decisions`
- `decision_options`
- `decision_participants`
- `decision_links`

## MVP Voting Type

Required:

- DOT_VOTE

Should be architected to later support:

- FIST_TO_FIVE
- PLANNING_POKER

## Important Rule

Voting does not automatically finalize a Decision.

## Acceptance Tests

- AT-VOTE-001 to 003
- AT-DEC-001
- AT-DEC-002

## Definition of Done

Team can vote, discuss outside the voting system, and explicitly record the final human decision.

## Codex Prompt

> Implement M10 only. Build Dot Voting and formal Decision Records. Enforce vote limits server-side. Do not automatically convert the top vote result into a final decision. Preserve decisions and supersession history.

---

# 16. M11 — Affinity & Mind Mapping

## Objective

Implement structured collaborative organization and invention mapping.

## In Scope

- Affinity groups
- grouped structured objects
- Mind Map
- typed nodes
- typed edges
- React Flow UI
- Liveblocks collaborative room
- normalized save to PostgreSQL
- Draft Artifact Version checkpoints

## Schema

Implement:

- `affinity_groups`
- `affinity_group_items`
- `mind_maps`
- `mind_map_nodes`
- `mind_map_edges`

## Liveblocks Rule

Liveblocks is realtime collaboration state only.

Canonical saved versions remain in PostgreSQL.

## Acceptance Tests

- AT-AFF-001
- AT-AFF-002
- AT-MM-001 to 004
- AT-CON-001

## Definition of Done

A Team can collaboratively build a Mind Map using structured project objects, save a Draft Version, reload it, and continue without silent data loss.

## Codex Prompt

> Implement M11 only. Use React Flow for structured Mind Maps and Liveblocks only for high-frequency collaborative state. Persist normalized canonical Mind Map data and version snapshots to Supabase. Deleting a visual node must not delete the linked Development Object automatically.

---

# 17. M12 — Evidence, Files & Patent Workspace

## Objective

Implement evidence-backed invention research.

## In Scope

- Evidence Records
- evidence links
- files
- private storage
- signed access
- Patent Records
- Patent Search Log
- basic patent workspace
- external source links

## Schema

Implement:

- `evidence`
- `evidence_links`
- `files`
- `file_links`
- `patent_records`
- `patent_search_logs`

## Patent Sources

MVP may link users to:

- PATENTSCOPE
- USPTO
- Google Patents

No proprietary patent search engine yet.

## Acceptance Tests

- AT-EV-001 to 003
- AT-PAT-001 to 003
- AT-FILE-001 to 003

## Definition of Done

Team can save a patent, attach evidence, link evidence to project objects/decisions, and access files securely.

## Codex Prompt

> Implement M12 only. Build Evidence, private file storage, Patent Records, and Patent Search Logs. Keep AI analysis separate from evidence. All confidential files must use authorized signed access. Do not build automated patentability conclusions.

---

# 18. M13 — Sharing & Cross-Team Access

## Objective

Implement intentional sharing across workspace boundaries.

## In Scope

- share records
- View
- Comment
- Snapshot
- Live Reference if approved
- revoke share
- share history
- Personal → Team
- Team → Master
- optional Team → Team

## Schema

Implement:

- `shares`
- `share_snapshots` if used

## Core Rules

- sharing does not transfer ownership,
- only selected entity is shared,
- source workspace remains private,
- revocation removes future access.

## Acceptance Tests

- AT-PW-004
- AT-SHARE-001 to 005
- AT-E2E-PRIV-001 relevant sharing paths

## Definition of Done

Selected content can cross a workspace boundary without exposing the source workspace.

## Codex Prompt

> Implement M13 only. Build explicit object-level sharing. Preserve ownership and provenance. Ensure sharing one artifact never grants access to its source workspace, chat, files, AI history, or unrelated artifacts. Add cross-team leakage tests.

---

# 19. M14 — AI Context & AI Assistance

## Objective

Add permission-aware, activity-aware AI.

## In Scope

- provider abstraction
- OpenAI Responses API
- AI task service
- AI roles
- Context Builder
- context references
- AI Outputs
- human disposition
- candidate conversion
- usage event foundation
- structured response validation

## Schema

Implement:

- `ai_outputs`
- `ai_context_references`
- `ai_prompt_templates`
- `ai_usage_events`
- optional conversation tables only if needed

## Initial AI Roles

- Structured Creativity Assistant
- Brainstorming Facilitator
- System Structure Analyst
- Patent Research Assistant
- Comparative / Critical Analyst
- Critical Reviewer

## Security Flow

```text
Authenticate
↓
Resolve permission
↓
Resolve workspace/project/activity
↓
Retrieve only authorized context
↓
Call provider
↓
Validate output
↓
Store provenance
↓
Wait for human disposition
```

## Acceptance Tests

- AT-AI-001 to 009
- AT-AI-LEAK-001 to 003
- AT-E2E-AI-001

## Definition of Done

AI can assist Team A without any path to Team B private data and cannot approve project content.

## Codex Prompt

> Implement M14 only. Read `/docs/09_AI_ASSISTANT_SPEC.md` in full. Create the AI provider abstraction, permission-aware Context Builder, task roles, saved AI Outputs, Context References, and human disposition. Use OpenAI Responses API behind the abstraction. No AI request may include content that the user cannot access. Add the full AI leakage acceptance suite.

---

# 20. M15 — Progress, Notifications & Pilot Workflow

## Objective

Make the course operational for a real pilot.

## In Scope

- basic progress
- activity status
- submission status
- notification records
- realtime notifications
- selected email notifications
- Master cohort overview
- Student current-work overview

## Schema

Implement:

- `notifications`

## Notifications

Required events may include:

- team membership change
- artifact shared
- submission received
- revision requested
- approval
- mention later if implemented

## Email

Use Resend for high-value async notifications only.

## Definition of Done

Master can identify:

- current teams,
- current session/activity,
- pending review,
- revision requested,
- approved work.

Student can identify:

- current activity,
- work in progress,
- revision requested,
- approved output.

## Codex Prompt

> Implement M15 only. Add lightweight progress and notifications sufficient for a pilot cohort. Do not build a large analytics dashboard. Prioritize current activity, submission/review status, team membership events, and revision/approval notifications.

---

# 21. M16 — Live Classroom Integration

## Objective

Connect the live teaching environment without rebuilding video infrastructure.

## In Scope

- Daily integration
- live session room
- join token
- Master room creation
- student authorized join
- optional team breakout room mapping
- link current Activity from live session

## Provider

Daily.

## Non-Goals

- proprietary WebRTC stack,
- advanced video recording management,
- Zoom feature parity.

## Operations

- get/create live session room
- get join token
- optional breakout room mapping

## Definition of Done

A cohort can join a live session and continue structured activity work in the FICI platform.

## Codex Prompt

> Implement M16 only. Integrate Daily for live classroom media. Keep course/session/project/activity state in FICI. Daily must remain a replaceable media provider. Do not store canonical educational state in Daily.

---

# 22. M17 — Pilot Hardening, Security & Release

## Objective

Prepare the platform for a real Professional Course pilot.

## In Scope

- full RLS review
- direct ID attack tests
- AI leakage tests
- transaction rollback tests
- browser testing
- accessibility review
- backup/restore test
- logging
- rate limiting
- file limits
- error handling
- E2E Professional Course scenario
- release checklist

## Mandatory Acceptance

Run:

- AT-E2E-001
- AT-E2E-PRIV-001
- AT-E2E-MEMBER-001
- AT-E2E-AI-001
- all BLOCKER tests from `12_ACCEPTANCE_TESTS.md`

## Release Rule

No open BLOCKER defect.

## Definition of Done

The MVP Release Checklist in `12_ACCEPTANCE_TESTS.md` is fully completed.

## Codex Prompt

> Execute M17 as hardening only. Do not add unrelated features. Run the complete BLOCKER acceptance suite, RLS/security tests, direct-ID tests, AI leakage tests, transaction rollback tests, and the full Professional Course E2E scenario. Fix defects without changing business rules. Produce a pilot-readiness report listing all remaining HIGH/MEDIUM/LOW issues.

---

# 23. Implementation Dependency Graph

```text
M0
↓
M1
↓
M2
↓
M3
↓
M4
↓
M5
↓
M6
↓
M7
↓
M8
├───────────────┐
↓               ↓
M9              M12
↓               │
M10             │
↓               │
M11             │
└───────┬───────┘
        ↓
       M13
        ↓
       M14
        ↓
       M15
        ↓
       M16
        ↓
       M17
```

Some implementation work can be parallelized later, but Codex should initially follow the dependency order.

---

# 24. What Must Not Be Built During This Plan

Do not allow scope expansion into:

- full Advanced Course specialized modules,
- investor CRM,
- marketplace,
- native mobile apps,
- proprietary video infrastructure,
- semantic patent search engine,
- autonomous agents,
- automatic legal conclusions,
- advanced university tenancy,
- advanced analytics warehouse,
- full custom whiteboard.

These belong after pilot validation.

---

# 25. Advanced Course Readiness During MVP

Although specialized Advanced tools are deferred, the foundation must preserve compatibility with:

- Requirement
- Assumption
- Constraint
- Risk
- Test
- Evidence
- Task
- Milestone
- Development Gate
- Finance extensions
- Pitch Claims

Do not hard-code the platform around Professional Course-only entity assumptions.

---

# 26. Codex Task Size Rule

Each Codex task should be bounded enough to review.

Preferred size:

- one migration set,
- one domain operation cluster,
- one UI workflow,
- one acceptance-test group.

Avoid prompts like:

> "Build M5 completely."

Instead, M5 may be split into:

```text
M5.1 Team schema + RLS
M5.2 Team creation transaction
M5.3 Add/remove/move membership
M5.4 Team chat persistence
M5.5 Team chat realtime
M5.6 Team security tests
```

---

# 27. Sub-Milestone Template

Each implementation task should use:

```text
TASK ID
OBJECTIVE
SOURCE DOCS
IN SCOPE
OUT OF SCOPE
SCHEMA CHANGES
API / COMMANDS
UI
PERMISSIONS
TESTS
ACCEPTANCE CRITERIA
FILES EXPECTED TO CHANGE
DEFINITION OF DONE
```

---

# 28. Codex Prompt Template

Use a prompt structure like:

> **Task:** M5.2 — Team Creation Transaction  
> **Read first:** `/docs/03_ROLES_PERMISSIONS.md`, `/docs/04_WORKSPACE_TEAM_COLLABORATION.md`, `/docs/08_DATA_MODEL_SCHEMA.md`, `/docs/11_API_CONTRACTS.md`, `/docs/12_ACCEPTANCE_TESTS.md`.  
> **Objective:** Implement `createTeam()` only.  
> **Requirements:** Team creation must atomically create Team, Team Workspace, Team Chat Channel, Master assignment, and audit event. Only Admin or assigned Master may create the team.  
> **Do not:** implement member movement, chat UI, or unrelated features.  
> **Tests:** add success, unauthorized, invalid cohort, rollback tests.  
> **Before finishing:** run lint, typecheck, targeted tests, and report changed files plus any ambiguity.  
> **Rule:** do not change business rules without approval.

---

# 29. Pull Request Standard

Every significant implementation PR should contain:

## Summary

What was implemented.

## Source Docs

Which `/docs` sections govern the change.

## Schema Changes

Migrations added.

## Security

Permissions/RLS affected.

## Tests

Tests added and results.

## Open Questions

Any unresolved requirement.

## Screenshots

For UI features where useful.

---

# 30. Migration Standard

Every migration must:

- have descriptive name,
- be committed,
- include RLS changes when relevant,
- avoid destructive production behavior unless explicitly approved,
- include backfill strategy if existing data is affected.

Codex should never "fix production manually."

---

# 31. RLS Review Gate

Any milestone that introduces a protected table is incomplete until:

- SELECT policy tested,
- INSERT policy tested,
- UPDATE policy tested,
- DELETE/archive policy tested,
- unauthorized direct-ID access tested.

---

# 32. UI Implementation Rule

UI implementation must reflect the approved product model.

Do not create UI patterns that imply incorrect behavior.

Examples:

Wrong:

```text
"Everyone in the course can browse all team artifacts"
```

Wrong:

```text
"AI-generated solution automatically appears in approved project"
```

Wrong:

```text
"Editing approved artifact updates it in place"
```

The UI must respect underlying permissions and state.

---

# 33. Seed Data Strategy

Development seed data should include:

- FICI Organization
- Professional Course
- 2026 curriculum version
- test cohort
- Admin
- Master
- Team A
- Team B
- sample Student accounts
- sample Development Projects

Seed data must never be used as production credentials.

---

# 34. Test Data Strategy

Automated tests should generate isolated records and clean up or run in resettable test databases.

Security tests should use distinct accounts and explicit scope boundaries.

---

# 35. Documentation Change Rule

If implementation reveals a required product change:

1. identify conflict,
2. identify affected document,
3. propose change,
4. obtain approval,
5. update docs,
6. implement.

Never reverse the order.

---

# 36. Pilot Sequence

Recommended pilot rollout:

## Phase A — Internal Technical Test

FICI internal team only.

## Phase B — Small Instructor Simulation

1 Master + 2–4 test users.

## Phase C — Small Pilot Cohort

Approximately one small real cohort.

## Phase D — Full Professional Course Pilot

Run the complete workflow.

After each phase:

- collect defects,
- collect workflow friction,
- record product decisions,
- update docs when approved.

---

# 37. Pilot Metrics

Track practical MVP metrics:

- login success,
- activity completion,
- artifact submission success,
- revision cycles,
- approval time,
- AI usage,
- AI candidate acceptance/rejection,
- chat use,
- cross-team privacy incidents,
- permission errors,
- failed AI calls,
- collaboration disconnects,
- instructor workload.

Do not overbuild analytics before the pilot.

---

# 38. Release Branch / Deployment Approach

Recommended:

```text
feature/*
↓
Pull Request
↓
Preview Deployment
↓
Review / Tests
↓
main
↓
Production
```

Use Vercel preview deployments for feature verification.

---

# 39. Definition of Done — Global

A milestone is complete only when:

```text
IMPLEMENTED
+
MIGRATIONS COMMITTED
+
RLS VERIFIED
+
TYPES VALID
+
LINT PASSES
+
TYPECHECK PASSES
+
UNIT/INTEGRATION TESTS PASS
+
RELEVANT E2E TESTS PASS
+
ACCEPTANCE CRITERIA PASS
+
NO DOC CONTRADICTION
```

---

# 40. First Codex Task Recommendation

The first actual implementation task should be:

# `M0.1 — Repository Initialization`

Then:

# `M0.2 — Supabase Local Development Setup`

Then:

# `M0.3 — CI + Test Foundation`

Only after M0 is complete should Codex begin M1.

---

# 41. Implementation Decisions Captured

## IMP-001 — Milestone-Based Build

The platform will be built incrementally rather than through one large Codex prompt.

**Status:** Required.

## IMP-002 — Security Foundation Before Collaboration

RLS and permission architecture are implemented before Team/Project features.

**Status:** Required.

## IMP-003 — Project Foundation Before AI

AI is not implemented until Development Project, Activity, Evidence, and Versioning foundations exist.

**Status:** Required.

## IMP-004 — Professional Course First

The first working product validates the Professional Course.

**Status:** Required.

## IMP-005 — Advanced Compatibility Without Advanced Scope

The data architecture remains extensible to Advanced Course, but specialized Advanced tools are deferred.

**Status:** Required.

## IMP-006 — Acceptance Tests Are Release Criteria

Features are not considered finished simply because they compile.

**Status:** Required.

---

# 42. Next Working Document

After this implementation plan is approved, the next useful file is:

# `14_CODEX_M0_PROMPTS.md`

It should contain the exact copy/paste prompts for:

- M0.1 Repository Initialization
- M0.2 Supabase Local Setup
- M0.3 Test / CI Foundation
- M0.4 Documentation & Development Rules Validation

This allows implementation to begin with very controlled Codex tasks.

After M0 is complete, create:

```text
15_CODEX_M1_PROMPTS.md
```

and continue milestone by milestone.

---

# 43. Final Rule for Codex

Codex is an implementation agent, not the product owner.

Codex must:

```text
READ
→ IMPLEMENT
→ TEST
→ REPORT
```

Codex must not:

```text
GUESS
→ CHANGE PRODUCT RULES
→ HIDE AMBIGUITY
```

When requirements conflict or are incomplete:

**STOP AND FLAG THE ISSUE.**

---

# End of Document

**Current Status:** Draft v0.1 — Ready for Ahmad/FICI review.  
**Next Recommended File:** `14_CODEX_M0_PROMPTS.md`
