# FICI Invention Education & Development Platform
## Codex M4 Execution Prompts — Workspaces

**Document:** `18_CODEX_M4_PROMPTS.md`  
**Status:** Draft v0.1 — For Review  
**Depends on:** `01_PRODUCT_REQUIREMENTS.md` through `17_CODEX_M3_PROMPTS.md`  
**Purpose:** Provide exact copy/paste prompts for Codex to implement Milestone M4 safely and incrementally after M3 is complete.

---

# 1. Preconditions

Do not begin M4 until M3 is:

```text
IMPLEMENTED
→ TESTED
→ SECURITY-REVIEWED
→ COMMITTED
```

Required M3 state:

- FICI organization exists,
- Professional Course program exists,
- Professional Course 2026 v1 curriculum exists,
- sessions and curriculum definitions exist,
- cohort model exists,
- enrollment model exists,
- primary Master assignment is integrated with M2 authorization,
- cohort isolation works,
- enrollment authorization works,
- RLS for M3 resources passes,
- Codex reports READY FOR M4.

If M3 is incomplete:

```text
STOP → FINISH M3 → REVIEW → COMMIT → BEGIN M4
```

Do not introduce Workspace behavior on top of incomplete scope/enrollment security.

---

# 2. M4 Goal

Milestone M4 introduces explicit collaboration scopes.

M4 must deliver the Workspace layer that later tools, teams, projects, activities, files, AI, and review workflows will use.

The conceptual structure is:

```text
AUTHENTICATED USER
↓
AUTHORIZED PROGRAM / COHORT CONTEXT
↓
WORKSPACE
├── PERSONAL
├── TEAM
├── MASTER
├── SHARED
└── CASE_STUDY
↓
LATER: PROJECT / ACTIVITY / ARTIFACT / TOOL / AI / FILE / CHAT
```

The most important M4 security rule is:

# PERSONAL WORKSPACE IS PRIVATE BY DEFAULT

A Master, Admin, Mentor, another Student, or another Team must not automatically gain access to a user's Personal Workspace.

---

# 3. M4 Product Boundary

M4 includes:

- `workspaces` schema,
- Workspace type model,
- Personal Workspace,
- Team Workspace schema foundation,
- Master Workspace,
- Shared Workspace schema foundation,
- Case Study Workspace schema foundation,
- automatic Personal Workspace provisioning,
- workspace access resolution,
- workspace listing,
- workspace metadata retrieval,
- RLS for workspaces,
- Personal Workspace privacy acceptance tests,
- direct-ID and direct-database privacy tests.

M4 does **not** yet implement:

- Team entities,
- Team Membership,
- Team Chat,
- team creation transactions,
- Development Projects,
- Activity Instances,
- artifacts,
- files/uploads,
- sharing records,
- cross-team sharing behavior,
- AI,
- review/approval,
- realtime collaboration,
- Liveblocks,
- voting,
- mind maps,
- patent tools.

Those belong to M5+.

---

# 4. Workspace Product Principle

The approved collaboration principle is:

# PRIVATE BY DEFAULT → SHARE INTENTIONALLY → COLLABORATE IN SCOPE → PRESERVE OWNERSHIP AND HISTORY

M4 must establish the scope boundary before collaboration features are added.

A Workspace is not merely a UI container.

It is an authorization boundary and a data-ownership context.

---

# 5. Workspace Types

The approved initial Workspace types are:

```text
PERSONAL
TEAM
MASTER
SHARED
CASE_STUDY
```

## PERSONAL

Private working area for one user.

## TEAM

Private collaborative scope for an official team.

M4 creates schema/access foundations only.

M5 creates Teams and operational Team Workspace provisioning.

## MASTER

Instructor's educational oversight/planning scope.

It is separate from Team Workspaces.

## SHARED

Scope for intentionally shared material crossing normal workspace boundaries.

M4 creates schema foundation only.

M13 owns full sharing behavior.

## CASE_STUDY

Instructor-owned instructional example scope.

M4 creates schema foundation only.

The Development Project connected to the case study belongs to later project milestones.

---

# 6. Approved Workspace Schema

Implement:

```text
workspaces
```

Conceptual fields:

- `id`
- `workspace_type`
- `name`
- `owner_user_id` nullable
- `team_id` nullable
- `cohort_id` nullable
- `project_id` nullable
- `status`
- `visibility`
- `settings`

Also follow global persistence conventions where applicable:

- `created_at`
- `created_by`
- `updated_at`
- `updated_by`
- `archived_at` or equivalent

## Important Dependency Rule

M4 occurs before:

- Teams (M5),
- Development Projects (M6).

Therefore:

- preserve `team_id`,
- preserve `project_id`,
- keep them nullable,
- defer foreign keys if their target tables do not exist yet,
- document deferred constraints,
- do not create Team or Project tables prematurely.

---

# 7. Personal Workspace Rules

The Personal Workspace is the user's private development area.

It supports independent thinking before group influence.

Typical future content may include:

- notes,
- ideas,
- SCAMPER outputs,
- brainstorming,
- research notes,
- private AI conversations,
- draft problem statements,
- draft solutions,
- draft mind maps,
- uploaded files,
- reflections,
- homework drafts,
- patent notes.

M4 does not implement those content types yet.

It must implement the secure container they will later belong to.

## Default Visibility

```text
OWNER ONLY
```

No other user receives access merely because they are:

- in the same cohort,
- a Master,
- an Admin,
- a Mentor,
- another Student.

Future explicit share/submission behavior will grant selected access to selected objects, not broad access to the entire Personal Workspace.

---

# 8. Master Workspace Rules

The Master Workspace supports educational oversight and instructor work.

It may later contain:

- review queues,
- instructor notes,
- course planning,
- case-study links,
- assigned team overview,
- pending submissions.

M4 does not implement those features.

Important:

```text
MASTER WORKSPACE ≠ TEAM WORKSPACE
```

Instructor internal notes/planning should remain separate from student spaces unless intentionally shared.

---

# 9. Team Workspace Foundation Rule

M4 must support `workspace_type = TEAM`.

However, M5 owns:

- Team creation,
- Team Membership,
- Team Workspace provisioning transaction,
- Team Chat.

Therefore in M4:

- define the type,
- define authorization extension points,
- do not create functional Team Workspaces from fake Team records,
- do not implement Team membership logic.

If tests need a Team Workspace shape, use controlled schema fixtures only and do not create M5 business behavior.

---

# 10. Shared Workspace Foundation Rule

M4 must support `workspace_type = SHARED`.

But full sharing belongs later.

M4 must not invent:

- share recipients,
- share types,
- snapshot/live sharing,
- cross-team permissions,
- revoke logic.

The Shared Workspace type is a schema/access foundation only.

---

# 11. Case Study Workspace Foundation Rule

M4 must support `workspace_type = CASE_STUDY`.

This supports the continuing Instructor Case Study model.

In M4:

- allow authorized Master-owned Case Study Workspace creation/provisioning if clearly defined,
- or create schema foundation only if project linkage is not yet available.

Do not create the actual Development Project in M4.

M6 owns Development Projects.

---

# 12. Workspace Context Principle

Later development tools must operate inside a Workspace scope.

Conceptually:

```text
TOOL
↓
WORKSPACE SCOPE
↓
ACTIVITY INSTANCE
↓
OUTPUT
```

Examples later:

```text
Brainstorming
├── Personal Workspace
├── Team Workspace
└── Shared Activity
```

M4 therefore must provide stable Workspace identity that later entities can reference.

---

# 13. Source-of-Truth Files

Before each M4 task, Codex must read the relevant approved files.

Primary M4 sources:

```text
/docs/02_PLATFORM_ARCHITECTURE.md
/docs/03_ROLES_PERMISSIONS.md
/docs/04_WORKSPACE_TEAM_COLLABORATION.md
/docs/07_MVP_SCOPE.md
/docs/08_DATA_MODEL_SCHEMA.md
/docs/10_TECHNICAL_ARCHITECTURE.md
/docs/11_API_CONTRACTS.md
/docs/12_ACCEPTANCE_TESTS.md
/docs/13_CODEX_IMPLEMENTATION_PLAN.md
/docs/16_CODEX_M2_PROMPTS.md
/docs/17_CODEX_M3_PROMPTS.md
```

---

# 14. Global Codex Header

Use this block at the beginning of every M4 task if project rules are not automatically retained:

```text
You are implementing the FICI Invention Education & Development Platform.

Before making changes:

1. Read the relevant /docs files listed in this task.
2. Treat /docs as product and architecture source of truth.
3. Do not invent missing business rules.
4. Preserve the M2 Role + Scope + Resource security model.
5. Preserve M3 cohort/enrollment scope.
6. Personal Workspace is private by default.
7. Do not grant Master/Admin automatic access to private Personal Workspace content.
8. Never trust client-provided user identity, workspace ownership, role, cohort, or scope.
9. Enforce authorization server-side and with PostgreSQL RLS.
10. Do not rely on hidden UI controls for privacy.
11. Use strict TypeScript.
12. Validate runtime inputs.
13. Use migrations for schema changes.
14. Preserve stable Workspace IDs and historical state.
15. Defer Team and Project business behavior to M5/M6.
16. If requirements conflict or are ambiguous, STOP → FLAG → ASK.
17. Run all requested validation before finishing.
18. Report:
    - files changed,
    - migrations added,
    - RLS policies,
    - business operations,
    - tests run,
    - results,
    - assumptions,
    - deferred foreign keys,
    - unresolved issues.
```

---

# 15. M4.1 — Workspace Schema

## Objective

Create the central `workspaces` table and type-safe Workspace model.

## Copy/Paste Prompt

```text
TASK ID: M4.1
TASK: Workspace Schema

Read first:

- /docs/04_WORKSPACE_TEAM_COLLABORATION.md
- /docs/08_DATA_MODEL_SCHEMA.md
- /docs/10_TECHNICAL_ARCHITECTURE.md
- /docs/13_CODEX_IMPLEMENTATION_PLAN.md
- /docs/17_CODEX_M3_PROMPTS.md

OBJECTIVE

Create the Workspace schema only.

IN SCOPE

1. Create `workspaces`.

Required conceptual fields:
- id
- workspace_type
- name
- owner_user_id nullable
- team_id nullable
- cohort_id nullable
- project_id nullable
- status
- visibility
- settings

2. Add standard metadata according to repository conventions:
- created_at
- created_by
- updated_at
- updated_by
- archived_at or equivalent where appropriate.

3. Support exactly these initial Workspace types:
- PERSONAL
- TEAM
- MASTER
- SHARED
- CASE_STUDY

4. Add safe status and visibility representation consistent with approved docs.

5. Add foreign keys that can exist now:
- owner_user_id → platform user/profile
- cohort_id → cohorts

6. For fields whose resources do not yet exist:
- team_id
- project_id

preserve the columns,
defer the FK if required,
document the deferred FK,
do not create Team or Project schema early.

7. Add indexes needed for:
- owner lookup,
- cohort lookup,
- workspace type lookup.

8. Add constraints supporting Personal Workspace uniqueness where appropriate:
- one active Personal Workspace per user.

9. Add tests:
- valid workspace types accepted,
- invalid workspace type rejected,
- Personal owner relation valid,
- duplicate active Personal Workspace prevented,
- archived state does not silently create duplicate active ownership ambiguity.

OUT OF SCOPE

Do NOT implement:
- Teams,
- Projects,
- sharing,
- chat,
- files,
- artifacts,
- AI.

VALIDATION

Run:
pnpm lint
pnpm typecheck
pnpm test:unit
pnpm test:integration
pnpm build

DEFINITION OF DONE

The Workspace entity exists as a stable security/data scope for later features.

FINAL REPORT

Return:
1. Summary
2. Schema
3. Constraints/indexes
4. Deferred foreign keys
5. Files/migrations
6. Tests/results
7. Assumptions
8. Unresolved issues
```

---

# 16. M4.2 — Personal Workspace Provisioning

## Objective

Automatically provide one private Personal Workspace per eligible platform user.

## Approved Operation

```text
createPersonalWorkspace()
```

Usually system-created automatically.

It should be idempotent per user.

## Provisioning Rule

The Workspace owner must be derived from authenticated/server-controlled identity.

Never accept arbitrary browser input such as:

```text
ownerUserId = someone_else
```

for ordinary Personal Workspace creation.

## Copy/Paste Prompt

```text
TASK ID: M4.2
TASK: Personal Workspace Provisioning

Read first:

- /docs/04_WORKSPACE_TEAM_COLLABORATION.md
- /docs/08_DATA_MODEL_SCHEMA.md
- /docs/11_API_CONTRACTS.md
- /docs/12_ACCEPTANCE_TESTS.md
- /docs/16_CODEX_M2_PROMPTS.md

OBJECTIVE

Implement safe idempotent Personal Workspace provisioning.

IN SCOPE

1. Implement `createPersonalWorkspace()`.

2. Owner identity must come from verified server/session context unless the operation is an explicitly authorized administrative system-provisioning path.

3. Create:
- workspace_type = PERSONAL
- owner_user_id = authenticated user
- private/default visibility
- active status
- clear default name such as "My Workspace" or equivalent repository-approved label.

4. Enforce one active Personal Workspace per user.

5. Make operation idempotent:
- repeated call returns/reuses existing active Personal Workspace,
- does not create duplicates.

6. Define when provisioning occurs:
- on first authenticated platform use,
- or explicit server provisioning hook,
according to existing M1/M3 application architecture.

Do not invent a second user lifecycle.

7. Add tests:
- Student A gets one Personal Workspace,
- repeated provisioning yields same Workspace,
- Student A cannot create Personal Workspace owned by Student B,
- anonymous user cannot create Personal Workspace,
- owner is derived server-side,
- direct database insert cannot bypass ownership rules under normal user credentials.

OUT OF SCOPE

- Personal content,
- files,
- AI,
- sharing,
- Personal Project creation.

VALIDATION

Run:
pnpm lint
pnpm typecheck
pnpm test:unit
pnpm test:integration
pnpm test:e2e
pnpm build

DEFINITION OF DONE

Every eligible authenticated user can have exactly one active private Personal Workspace.

FINAL REPORT

Return:
1. Provisioning approach
2. Idempotency behavior
3. Files changed
4. RLS/security
5. Tests/results
6. Assumptions
7. Unresolved issues
```

---

# 17. M4.3 — Workspace Access Resolver

## Objective

Create a reusable server-side capability resolver for Workspace access.

## Approved Operation

```text
getWorkspaceAccess(workspaceId)
```

It should return resolved capabilities conceptually such as:

```text
canView
canCreate
canEdit
canComment
canShare
canReview
canApprove
canManageMembers
canAccessChat
```

Backend enforcement remains authoritative.

## M4 Scope

Not every capability can be fully implemented in M4 because later milestones own:

- sharing,
- review,
- approval,
- team membership,
- chat.

Therefore M4 may return conservative false/default values for unavailable capabilities.

Do not grant a capability merely because the future feature is not yet implemented.

## Copy/Paste Prompt

```text
TASK ID: M4.3
TASK: Workspace Access Resolver

Read first:

- /docs/03_ROLES_PERMISSIONS.md
- /docs/04_WORKSPACE_TEAM_COLLABORATION.md
- /docs/11_API_CONTRACTS.md
- /docs/16_CODEX_M2_PROMPTS.md
- /docs/17_CODEX_M3_PROMPTS.md

OBJECTIVE

Implement one reusable server-side Workspace access-resolution service.

IN SCOPE

1. Implement `getWorkspaceAccess(workspaceId)` or equivalent typed domain service.

2. Resolve:
- authenticated identity,
- active scoped roles,
- enrollment/cohort context,
- Workspace type,
- Workspace owner,
- relevant existing scope.

3. Return explicit capabilities.

4. For PERSONAL:
- owner: view/create/edit = true where applicable,
- non-owner: false by default,
- Master: false unless later explicit share/submission path grants object access,
- Mentor: false by default,
- another Student: false,
- Admin: do not automatically grant private content access merely because ADMIN.

5. For MASTER:
- assigned Master may access their own authorized Master Workspace,
- unrelated Master denied,
- Students denied internal Master scope.

6. For TEAM:
- M4 only provides extension points/default deny until M5 Team Membership exists.

7. For SHARED:
- M4 default deny until explicit sharing model exists.

8. For CASE_STUDY:
- authorized Master ownership/control foundation only,
- student view requires later publication/course rule, not automatic broad access.

9. Do not rely on client role claims.

10. Add unit/integration tests for each Workspace type default policy.

ERROR BEHAVIOR

Inaccessible Workspace should return safe authorization behavior without leaking sensitive metadata.

OUT OF SCOPE

- share resolution,
- team membership,
- chat,
- review,
- approval.

VALIDATION

Run:
pnpm lint
pnpm typecheck
pnpm test:unit
pnpm test:integration
pnpm build

DEFINITION OF DONE

All later Workspace-aware services can call one access resolver rather than reimplementing privacy rules.

FINAL REPORT

Return:
1. Capability model
2. Resolution algorithm
3. Workspace-type rules
4. Files changed
5. Tests/results
6. Deferred capabilities
7. Assumptions
8. Unresolved issues
```

---

# 18. M4.4 — Workspace Retrieval Operations

## Objective

Implement authorized Workspace retrieval without exposing inaccessible metadata.

## Approved Operations

```text
getWorkspace(workspaceId)
listMyWorkspaces()
```

## Copy/Paste Prompt

```text
TASK ID: M4.4
TASK: Workspace Retrieval

Read first:

- /docs/04_WORKSPACE_TEAM_COLLABORATION.md
- /docs/11_API_CONTRACTS.md
- /docs/12_ACCEPTANCE_TESTS.md

OBJECTIVE

Implement authorized Workspace metadata retrieval.

IN SCOPE

1. Implement `getWorkspace(workspaceId)`.

Rule:
Return Workspace metadata only if the authenticated user has access.

2. Implement `listMyWorkspaces()`.

Return only Workspaces the authenticated user is currently authorized to access.

3. Do not return:
- inaccessible workspace names,
- owner identities,
- settings,
- cohort/project/team relationships,
if access is denied.

4. Personal Workspace:
- owner can retrieve it,
- others cannot.

5. Master Workspace:
- only authorized Master scope.

6. TEAM/SHARED:
- default deny unless a valid existing authorization path exists.

7. CASE_STUDY:
- creator/authorized Master only by default at M4.

8. Add tests:
- owner retrieves Personal Workspace,
- Student B cannot retrieve Student A Personal Workspace by ID,
- guessed UUID does not reveal existence/details,
- listMyWorkspaces excludes inaccessible Workspaces,
- unrelated Master cannot retrieve private Personal Workspace.

OUT OF SCOPE

- Workspace contents,
- artifacts,
- files,
- chat,
- project data.

VALIDATION

Run:
pnpm lint
pnpm typecheck
pnpm test:unit
pnpm test:integration
pnpm test:e2e
pnpm build

DEFINITION OF DONE

Workspace discovery itself respects privacy and scope.

FINAL REPORT

Return:
1. Operations
2. Authorization behavior
3. Metadata exposure rules
4. Tests/results
5. Files changed
6. Assumptions
7. Unresolved issues
```

---

# 19. M4.5 — Personal Workspace RLS

## Objective

Enforce Personal Workspace privacy directly at PostgreSQL level.

## Required Security Principle

Application authorization is necessary.

RLS is also mandatory.

Required pattern:

```text
SERVER AUTHORIZATION
+
POSTGRESQL RLS
```

## Personal Workspace Policy

Conceptually:

```text
ALLOW SELECT
WHERE workspace_type = PERSONAL
AND owner_user_id = current authenticated platform user
```

Future explicit sharing/review rules must be added later through explicit records.

Do not pre-authorize future share behavior in M4.

## Copy/Paste Prompt

```text
TASK ID: M4.5
TASK: Personal Workspace RLS

Read first:

- /docs/03_ROLES_PERMISSIONS.md
- /docs/04_WORKSPACE_TEAM_COLLABORATION.md
- /docs/10_TECHNICAL_ARCHITECTURE.md
- /docs/12_ACCEPTANCE_TESTS.md
- /docs/16_CODEX_M2_PROMPTS.md

OBJECTIVE

Protect Personal Workspaces at the database boundary.

IN SCOPE

1. Enable RLS on `workspaces`.

2. Add least-privilege policies for Personal Workspace:
- owner can SELECT own Personal Workspace,
- owner can perform only approved metadata updates,
- owner cannot change owner_user_id to another user,
- owner cannot change PERSONAL to privileged workspace type,
- another Student cannot SELECT,
- unrelated Master cannot SELECT,
- Mentor cannot SELECT by default,
- normal Admin product role does not automatically bypass private educational content.

3. Service/server privileged paths must remain server-only and explicitly justified.

4. Add direct database tests under actual user auth contexts.

5. Test:
- Student A SELECT own Workspace = allow,
- Student B SELECT Student A Workspace = deny/no rows,
- Student B direct ID = deny,
- Master direct SELECT unshared Student A Personal Workspace = deny,
- Student A tries owner_user_id = Student B = deny,
- Student A tries workspace_type PERSONAL → MASTER = deny,
- anonymous SELECT = deny.

6. Avoid permissive "authenticated can select all workspaces" policy.

OUT OF SCOPE

- share-based exceptions,
- submission-based exceptions,
- team membership policies.

VALIDATION

Run all configured Supabase/RLS tests plus:
pnpm lint
pnpm typecheck
pnpm test:unit
pnpm test:integration
pnpm build

DEFINITION OF DONE

Personal Workspace privacy cannot be bypassed by direct database query under normal authenticated credentials.

FINAL REPORT

Return:
1. RLS policies
2. Attack tests
3. Files/migrations
4. Results
5. Service-role handling
6. Assumptions
7. Unresolved issues
```

---

# 20. M4.6 — Master Workspace Foundation

## Objective

Create the instructor's private operational Workspace scope without implementing review features.

## Product Rule

The Master Workspace is separate from:

- Personal Student Workspace,
- Team Workspace,
- Case Study source,
- Shared Workspace.

It may later aggregate authorized cohort/team information, but it must not copy private student content into Master ownership.

## Provisioning Principle

A Master Workspace may be scoped to a Master and optionally a Cohort.

Recommended M4 model:

```text
workspace_type = MASTER
owner_user_id = Master
cohort_id = assigned cohort
```

If one Master may need more than one cohort-specific Master Workspace, do not impose "one per Master globally" unless approved.

## Copy/Paste Prompt

```text
TASK ID: M4.6
TASK: Master Workspace Foundation

Read first:

- /docs/03_ROLES_PERMISSIONS.md
- /docs/04_WORKSPACE_TEAM_COLLABORATION.md
- /docs/08_DATA_MODEL_SCHEMA.md
- /docs/17_CODEX_M3_PROMPTS.md

OBJECTIVE

Implement the minimum Master Workspace foundation.

IN SCOPE

1. Support `workspace_type = MASTER`.

2. Allow a Master Workspace to be associated with:
- owner Master user,
- authorized cohort where appropriate.

3. Provision only for users with valid MASTER scope.

4. An unrelated Master must not access another Master's internal Workspace by default.

5. Students must not access Master internal Workspace.

6. Do not populate it with:
- team artifacts,
- submissions,
- private student drafts,
- review queue,
until later milestones.

7. Add tests:
- assigned Master can access own Master Workspace,
- Student denied,
- unrelated Master denied,
- invalid MASTER scope cannot provision,
- workspace remains separate from student Personal Workspace.

OUT OF SCOPE

- review queue,
- comments,
- approval,
- instructor dashboards,
- team supervision UI.

VALIDATION

Run:
pnpm lint
pnpm typecheck
pnpm test:unit
pnpm test:integration
pnpm build

DEFINITION OF DONE

The platform has a secure instructor Workspace scope ready for later review/oversight features.

FINAL REPORT

Return:
1. Provisioning approach
2. Scope relationship
3. RLS/access
4. Tests/results
5. Assumptions
6. Unresolved issues
```

---

# 21. M4.7 — Team / Shared / Case Study Schema Foundations

## Objective

Complete the Workspace type foundation without prematurely building M5/M6/M13 behavior.

## Copy/Paste Prompt

```text
TASK ID: M4.7
TASK: Team, Shared & Case Study Workspace Foundations

Read first:

- /docs/04_WORKSPACE_TEAM_COLLABORATION.md
- /docs/08_DATA_MODEL_SCHEMA.md
- /docs/13_CODEX_IMPLEMENTATION_PLAN.md

OBJECTIVE

Confirm schema/access foundations for TEAM, SHARED, and CASE_STUDY Workspace types while keeping later business logic deferred.

TEAM

- Workspace type exists.
- team_id field exists.
- Team FK may remain deferred until M5.
- No functional Team Workspace provisioning without a Team.
- Default access resolver denies ordinary access until M5 membership rules exist.

SHARED

- Workspace type exists.
- Do not create sharing recipient schema in M4.
- Default access deny unless explicitly system-owned fixture.
- Full sharing is deferred.

CASE_STUDY

- Workspace type exists.
- May be Master-owned/cohort-scoped.
- Do not create Development Project in M4.
- Student access is not automatic.
- Publication/view rules are deferred.

TESTS

1. Types are accepted by schema.
2. Unauthorized users cannot gain access merely by choosing a workspace_type.
3. Student cannot create MASTER/TEAM/SHARED/CASE_STUDY Workspace through ordinary Personal Workspace API.
4. Deferred FKs are documented.
5. Access resolver returns conservative default permissions.

OUT OF SCOPE

- Team creation,
- Shared recipients,
- Case Study Project,
- publication logic.

VALIDATION

Run:
pnpm lint
pnpm typecheck
pnpm test:unit
pnpm test:integration
pnpm build

DEFINITION OF DONE

All five Workspace types exist in the architecture, while M5+ behavior remains unimplemented.

FINAL REPORT

Return:
1. Type foundations
2. Deferred behavior
3. Deferred FKs
4. Tests/results
5. Assumptions
6. Unresolved issues
```

---

# 22. M4.8 — Personal Workspace Acceptance Tests

## Objective

Implement the required M4 acceptance suite.

## Mandatory Tests

### AT-PW-001 — Personal Workspace Owner Access

Student A1 can access their Personal Workspace.

At M4, access means Workspace-level access.

Future content operations such as AI/files are tested in their owning milestones.

### AT-PW-002 — Personal Workspace Privacy

Given Student A1 owns a Personal Workspace:

Student A2 attempts access by:

```text
UI
direct route
guessed ID
API query
database query under user auth
```

Result:

```text
DENIED
```

Priority:

```text
BLOCKER
```

### AT-PW-003 — Master Cannot Browse Unshared Personal Draft

M4 does not yet implement a draft artifact.

Therefore test the Workspace-level equivalent:

```text
Master cannot browse Student A1 Personal Workspace
without explicit later share/submission authorization.
```

Priority:

```text
BLOCKER
```

### AT-PW-004

"Share selected Personal Artifact" belongs to later sharing/artifact milestones.

Do not falsely mark it complete in M4.

Record it as:

```text
DEFERRED — requires Artifacts + Sharing
```

## Copy/Paste Prompt

```text
TASK ID: M4.8
TASK: Personal Workspace Acceptance Tests

Read first:

- /docs/12_ACCEPTANCE_TESTS.md
- /docs/04_WORKSPACE_TEAM_COLLABORATION.md
- /docs/16_CODEX_M2_PROMPTS.md
- /docs/18_CODEX_M4_PROMPTS.md

OBJECTIVE

Implement automated acceptance coverage for Personal Workspace privacy.

TEST USERS

Use deterministic:
- Student A1
- Student A2
- Master

REQUIRED

1. AT-PW-001 Workspace-level owner access.
2. AT-PW-002 privacy across:
   - application route,
   - API/service,
   - direct ID,
   - direct database query under Student A2 auth.
3. AT-PW-003 Master cannot browse unshared Student A1 Personal Workspace.
4. Anonymous access denied.
5. Owner spoofing denied.
6. Workspace type escalation denied.

IMPORTANT

Do not create fake Artifact/Sharing features to satisfy AT-PW-004.

Record AT-PW-004 as deferred to the milestone owning Artifacts + Sharing.

RUN

pnpm lint
pnpm typecheck
pnpm test:unit
pnpm test:integration
pnpm test:e2e
pnpm build

Run configured RLS tests.

DEFINITION OF DONE

AT-PW-001 PASS
AT-PW-002 PASS
AT-PW-003 PASS
AT-PW-004 DEFERRED with correct dependency reason

FINAL REPORT

Return:
1. Test matrix
2. PASS/FAIL/DEFERRED
3. Attack paths tested
4. Files changed
5. Commands/results
6. Remaining issues
```

---

# 23. M4.9 — Direct-ID / Metadata Leakage Tests

## Objective

Ensure inaccessible Workspace existence and metadata are not exposed through guessed IDs or error differences.

## Threat Model

An unauthorized user may know or guess:

- Workspace UUID,
- owner user ID,
- cohort ID.

They must not gain useful private metadata.

## Copy/Paste Prompt

```text
TASK ID: M4.9
TASK: Direct-ID & Metadata Leakage Tests

Read first:

- /docs/03_ROLES_PERMISSIONS.md
- /docs/04_WORKSPACE_TEAM_COLLABORATION.md
- /docs/11_API_CONTRACTS.md
- /docs/12_ACCEPTANCE_TESTS.md

OBJECTIVE

Test Workspace privacy against direct resource enumeration.

ATTEMPTS

As Student B:

1. Request Student A Personal Workspace by exact ID.
2. Query database by exact ID.
3. Query by owner_user_id.
4. Query by cohort_id + PERSONAL type.
5. Call getWorkspace() with inaccessible ID.
6. Compare inaccessible ID vs nonexistent ID responses.
7. Attempt update/delete/archive by exact ID.

EXPECTED

- no private Workspace row returned,
- no sensitive metadata returned,
- no unauthorized mutation succeeds,
- error behavior does not reveal sensitive inaccessible-resource details.

Also test Master against unshared Student Personal Workspace.

VALIDATION

Run all security tests.

DEFINITION OF DONE

Known Workspace IDs do not bypass privacy.

FINAL REPORT

Return:
1. Enumeration cases
2. Results
3. Any metadata leakage found/fixed
4. Commands/results
```

---

# 24. M4.10 — M4 Security Hardening

## Objective

Perform a final Workspace security review before Team collaboration is introduced.

## Required Negative Tests

Attempt:

```text
Student A → read Student B PERSONAL
Student A → change owner to Student B
Student A → change PERSONAL type to MASTER
Student A → create TEAM Workspace directly
Student A → create MASTER Workspace directly
Student A → create SHARED Workspace directly
Student A → browse Master Workspace
Master → browse Student A PERSONAL
Unrelated Master → browse another Master Workspace
Anonymous → query Workspace table
Client → spoof owner_user_id
Client → spoof role
Client → spoof cohort scope
Client → bypass server through direct database query
```

All unauthorized attempts must fail.

## Copy/Paste Prompt

```text
TASK ID: M4.10
TASK: M4 Security Hardening

Read first:

- /docs/03_ROLES_PERMISSIONS.md
- /docs/04_WORKSPACE_TEAM_COLLABORATION.md
- /docs/08_DATA_MODEL_SCHEMA.md
- /docs/10_TECHNICAL_ARCHITECTURE.md
- /docs/11_API_CONTRACTS.md
- /docs/12_ACCEPTANCE_TESTS.md
- /docs/16_CODEX_M2_PROMPTS.md
- /docs/17_CODEX_M3_PROMPTS.md
- /docs/18_CODEX_M4_PROMPTS.md

OBJECTIVE

Perform security hardening of M4 only.

VERIFY

1. Personal Workspace private by default.
2. Owner identity cannot be spoofed.
3. Workspace type cannot be privilege-escalated.
4. Master cannot browse unshared Personal Workspace.
5. Admin product role does not automatically mean private-content superuser.
6. listMyWorkspaces cannot expose unauthorized Workspaces.
7. direct ID cannot bypass access.
8. database RLS blocks direct client access.
9. Team/Shared/Case Study default policies are conservative.
10. M5+ features were not implemented.

RUN

pnpm lint
pnpm typecheck
pnpm test:unit
pnpm test:integration
pnpm test:e2e
pnpm build

Run all configured Supabase/RLS tests.

DEFINITION OF DONE

- AT-PW-001 PASS
- AT-PW-002 PASS
- AT-PW-003 PASS
- zero known private Workspace leakage
- zero known Workspace privilege escalation
- no M5+ scope creep

FINAL REPORT

Return:
1. Security review summary
2. Issues found
3. Issues fixed
4. Remaining issues
5. BLOCKER status
6. Test results
7. Recommendation: READY FOR M5 or NOT READY FOR M5
```

---

# 25. Workspace Access Capability Model

M4 should establish a typed capability shape suitable for later milestones.

Conceptually:

```ts
type WorkspaceAccess = {
  canView: boolean;
  canCreate: boolean;
  canEdit: boolean;
  canComment: boolean;
  canShare: boolean;
  canReview: boolean;
  canApprove: boolean;
  canManageMembers: boolean;
  canAccessChat: boolean;
};
```

At M4, many later capabilities remain false.

Example Personal Workspace owner in M4:

```text
canView = true
canCreate = true
canEdit = true

canComment = false or not-applicable until content exists
canShare = false until sharing implementation
canReview = false
canApprove = false
canManageMembers = false
canAccessChat = false
```

Do not misrepresent unavailable feature capabilities as authorized merely because the owner may gain them later.

---

# 26. Workspace Visibility vs Authorization

A `visibility` field does not replace authorization.

Examples:

```text
visibility = private
```

still requires RLS/access checks.

Future values such as shared/cohort-visible must be implemented through explicit policy and records.

Do not allow:

```text
client sets visibility = public
→ privacy disappears
```

No ordinary client-controlled metadata field may override Role + Scope + Resource authorization.

---

# 27. Personal Workspace Ownership Rule

For `workspace_type = PERSONAL`:

```text
owner_user_id MUST NOT be null
```

and:

```text
one active Personal Workspace per owner
```

should be enforced if compatible with archive semantics.

A Personal Workspace must not be owned by:

- Team,
- Cohort,
- Program.

It belongs to one user.

---

# 28. Master Workspace Ownership Rule

For `workspace_type = MASTER`:

- `owner_user_id` should identify the Master,
- `cohort_id` may define instructional scope,
- valid MASTER authorization must exist.

Do not assume one global Master Workspace can expose every cohort.

---

# 29. Team Workspace Ownership Rule — Deferred

For `workspace_type = TEAM`:

M5 will define:

- required Team link,
- team membership access,
- assigned Master access,
- creation transaction,
- archive behavior.

M4 must not finalize these rules without Team schema.

---

# 30. Shared Workspace Rule — Deferred

For `workspace_type = SHARED`:

M4 provides only type/schema support.

Later sharing rules may expose selected objects to:

- Master,
- Mentor,
- selected user,
- another team,
- several teams,
- entire cohort.

Sharing one object must not expose the source Workspace.

That rule must remain architecturally possible.

---

# 31. Case Study Workspace Rule

Case Study Workspace is instructor-controlled.

Students must not accidentally edit the instructor source.

M4 should therefore default to:

```text
Master owner/editor
Students = no access until explicit later publication/view rule
```

Later course workflow may allow students to view a published Case Study reference without edit authority.

---

# 32. Workspace Selector — Data Foundation Only

The collaboration spec expects users eventually to know where they are working, such as:

```text
My Workspace
Team 1 Workspace
Instructor Case Study
Shared Activity
```

M4 may expose enough metadata for a future Workspace selector.

Do not build polished selector UI if not required.

Security is the priority.

---

# 33. No Whole-Personal-Workspace Sharing

The approved product rule is:

```text
share selected artifact/object
≠
share entire Personal Workspace
```

M4 should not create an operation like:

```text
sharePersonalWorkspace()
```

Full sharing later must be object-specific.

---

# 34. Workspace Access and Enrollment

Enrollment may allow:

- course access,
- session access.

Enrollment alone must **not** imply:

- another student's Personal Workspace access,
- Master Workspace access,
- Team Workspace access before membership,
- Shared Workspace access without explicit share.

Do not derive Workspace visibility from enrollment alone.

---

# 35. Workspace Access and Role

Role alone must **not** imply Workspace access.

Examples:

```text
MASTER
≠
all Personal Workspaces
```

```text
ADMIN
≠
all private educational content
```

```text
MENTOR
≠
all Team Workspaces
```

Authorization continues to use:

```text
Role + Scope + Resource
```

---

# 36. RLS Helper Extension

M4 may now add actual resource helpers such as:

```text
can_access_workspace(workspace_id)
can_edit_workspace(workspace_id)
```

These should reuse M2 authentication/scoped-role helpers.

Security requirements:

- derive current user from auth context,
- safe search_path if SECURITY DEFINER is used,
- no caller-supplied user impersonation,
- automated RLS tests,
- no circular policy recursion.

Do not add Project/Artifact helpers before their resources exist.

---

# 37. Archive Behavior

Archiving a Workspace should not erase future historical links.

M4 does not yet have artifacts/projects inside Workspaces, but schema behavior should anticipate later history.

Preferred:

```text
ACTIVE
→ ARCHIVED
```

not destructive deletion.

Archived Personal Workspace handling must not accidentally permit creation of multiple conflicting active Workspaces without an intentional restore/recreate policy.

If exact restore policy is not defined:

```text
STOP → FLAG → ASK
```

before implementing destructive behavior.

---

# 38. Error Behavior

Permission failures must not reveal sensitive inaccessible-resource details.

Use approved stable errors such as:

```text
AUTH_REQUIRED
FORBIDDEN
NOT_FOUND
VALIDATION_ERROR
CONFLICT
RESOURCE_ARCHIVED
```

For direct-ID access to a private Workspace, choose behavior consistent with the API security policy so inaccessible resources cannot be enumerated.

Do not include:

- owner's email,
- Workspace name,
- Workspace type details,
- cohort details,

in unauthorized error payloads.

---

# 39. M4 Expected Repository Additions

Conceptually:

```text
features/
└── workspaces/
    ├── types.ts
    ├── access.ts
    ├── operations.ts
    └── validation.ts

lib/
├── permissions/
│   └── workspace.ts
└── db/

supabase/
├── migrations/
│   ├── ...workspaces...
│   ├── ...workspace_rls...
│   └── ...workspace_helpers...
└── tests/
    └── rls/
        └── workspaces...

tests/
├── unit/
│   └── workspaces/
├── integration/
│   └── workspaces/
└── e2e/
    └── personal-workspace-privacy.spec.ts
```

Exact names may vary.

---

# 40. M4 Completion Gate

M4 is complete only when:

```text
[ ] workspaces table exists

[ ] PERSONAL type exists
[ ] TEAM type exists
[ ] MASTER type exists
[ ] SHARED type exists
[ ] CASE_STUDY type exists

[ ] Personal Workspace owner required
[ ] one active Personal Workspace per user enforced
[ ] createPersonalWorkspace() implemented
[ ] Personal Workspace provisioning is idempotent

[ ] getWorkspace() implemented
[ ] listMyWorkspaces() implemented
[ ] getWorkspaceAccess() implemented

[ ] Personal owner can access own Workspace
[ ] Student A cannot access Student B Personal Workspace
[ ] Master cannot browse unshared Student Personal Workspace
[ ] anonymous user cannot access protected Workspace

[ ] owner spoofing blocked
[ ] Workspace type escalation blocked
[ ] direct-ID access blocked
[ ] direct database access blocked by RLS

[ ] Master Workspace foundation exists
[ ] TEAM Workspace behavior deferred to M5
[ ] SHARED behavior deferred
[ ] CASE_STUDY Project behavior deferred

[ ] AT-PW-001 PASS
[ ] AT-PW-002 PASS
[ ] AT-PW-003 PASS
[ ] AT-PW-004 correctly DEFERRED

[ ] lint passes
[ ] typecheck passes
[ ] unit tests pass
[ ] integration tests pass
[ ] E2E tests pass
[ ] database/RLS tests pass
[ ] build passes

[ ] no M5+ feature implemented prematurely
[ ] Codex reports READY FOR M5
```

Any Personal Workspace privacy leak is:

```text
BLOCKER
```

and means:

```text
NOT READY FOR M5
```

---

# 41. Recommended Commit Sequence

Example:

```text
feat(workspaces): add workspace schema and types
feat(workspaces): add personal workspace provisioning
feat(authz): add workspace access resolver
feat(workspaces): add authorized workspace retrieval
feat(security): add personal workspace RLS
feat(workspaces): add master workspace foundation
feat(workspaces): add deferred team/shared/case-study foundations
test(workspaces): add personal workspace acceptance tests
test(security): add direct-id workspace leakage coverage
chore(security): complete M4 hardening
```

---

# 42. M4 Non-Goals

Do not accept these as "helpful additions" during M4:

- Team creation,
- Team Membership,
- Team Lead,
- Team Chat,
- realtime chat,
- Development Project creation,
- Project membership,
- Project objects,
- Workspace file uploads,
- SCAMPER data,
- Brainstorming,
- Voting,
- Affinity,
- Mind Map,
- sharing records,
- cross-team sharing,
- artifact system,
- review/approval,
- AI assistant,
- Liveblocks,
- Daily,
- notifications,
- polished dashboards,
- final Workspace selector design.

---

# 43. Potential M4 Ambiguities Codex Must Flag

Do not silently decide if approved docs do not resolve:

- whether Personal Workspace is provisioned at account creation, first login, or first platform entry,
- exact default Personal Workspace name,
- exact `visibility` enum,
- exact `status` enum,
- whether archived Personal Workspace may be restored,
- whether a user may ever have multiple Personal Workspaces,
- whether Master Workspace is one per Master or one per Master per Cohort,
- whether CASE_STUDY Workspace is one per Master, Cohort, Program, or Case Study Project,
- whether Shared Workspace should exist as a physical Workspace row before M13,
- whether Admin may access Personal Workspace metadata for support without educational content access,
- whether Admin may archive a Personal Workspace operationally,
- whether Students may view a published Case Study Workspace itself or only published artifacts from it,
- whether Workspace `name` is editable by the owner,
- whether a Student may archive their own Personal Workspace,
- what happens to Personal Workspace when user account is suspended/archived,
- exact read-only behavior for archived Workspaces.

If unresolved:

```text
STOP → FLAG → ASK
```

---

# 44. Recommended Safe Defaults for Purely Technical Decisions

Only where they do not change product policy:

- stable UUID Workspace IDs,
- one active Personal Workspace per user,
- Personal visibility = private,
- RLS enabled,
- owner derived from server identity,
- no broad authenticated SELECT policy,
- no ordinary client creation of privileged Workspace types,
- server operations for privileged provisioning,
- TEAM/SHARED access defaults to deny until explicit rules exist,
- archive rather than hard delete,
- deterministic Workspace security test fixtures,
- defer Team/Project FKs until those tables exist.

---

# 45. Review Checklist for Ahmad/FICI

Before implementation, confirm M4 reflects the intended Workspace model:

```text
1. Every major tool will eventually operate inside a Workspace.

2. Personal Workspace is private by default.

3. A student gets one Personal Workspace.

4. Master does not automatically browse private Personal Workspace.

5. Admin does not automatically become educational-content superuser.

6. Master Workspace is separate from Team Workspace.

7. Team Workspace type exists now, but Team behavior starts in M5.

8. Shared Workspace type exists now, but sharing behavior comes later.

9. Case Study Workspace is instructor-controlled.

10. Sharing later must expose selected objects, not the whole Personal Workspace.

11. Workspace access is enforced both server-side and in RLS.

12. Direct IDs must not bypass privacy.

13. M4 does not yet build Teams, Chat, Projects, Artifacts, or AI.
```

---

# 46. Next File After M4

After M4 has actually been:

```text
IMPLEMENTED
→ TESTED
→ SECURITY-REVIEWED
→ COMMITTED
```

create:

# `19_CODEX_M5_PROMPTS.md`

M5 will cover:

```text
Teams
Team Membership
Team Lead
Team Workspace provisioning
Add / Remove / Move Member
Private Team Chat
Chat Membership
Realtime Chat
Audit Events
Team Isolation RLS
```

M5 will convert the TEAM Workspace foundation into the first real collaborative environment.

---

# 47. Final Execution Rule

For M4:

```text
WORKSPACE SCHEMA
→ PERSONAL WORKSPACE
→ ACCESS RESOLUTION
→ AUTHORIZED RETRIEVAL
→ RLS
→ MASTER WORKSPACE FOUNDATION
→ DEFERRED TEAM/SHARED/CASE-STUDY FOUNDATIONS
→ PRIVACY TESTS
→ DIRECT-ID TESTS
→ SECURITY HARDENING
```

Do not skip directly to Team collaboration.

---

# End of Document

**Current Status:** Draft v0.1 — Ready for Ahmad/FICI review.  
**Execution Step After M3 Completion:** Start with **M4.1 — Workspace Schema**.
