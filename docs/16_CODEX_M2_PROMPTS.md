# FICI Invention Education & Development Platform
## Codex M2 Execution Prompts — Roles, Scope & RLS Security

**Document:** `16_CODEX_M2_PROMPTS.md`  
**Status:** Draft v0.1 — For Review  
**Depends on:** `01_PRODUCT_REQUIREMENTS.md` through `15_CODEX_M1_PROMPTS.md`  
**Purpose:** Provide exact copy/paste prompts for Codex to implement Milestone M2 safely and incrementally after M1 is complete.

---

# 1. Preconditions

Do not begin M2 until M1 is complete, tested, reviewed, and committed.

Required M1 state:

- Supabase authentication plumbing works.
- Platform user profiles exist.
- Login/logout works.
- Password recovery works.
- Protected routes reject anonymous access.
- Server-side current-user resolution exists.
- Client-provided user identity is not trusted.
- No server secret is exposed to the client.
- Authentication acceptance tests pass.
- `/docs` remains the product and architecture source of truth.

If M1 is incomplete:

```text
STOP → FINISH M1 → REVIEW → COMMIT → BEGIN M2
```

Do not compensate for incomplete M1 by implementing authorization shortcuts.

---

# 2. M2 Goal

Milestone M2 establishes the authorization and database-security foundation for every later product feature.

M2 must deliver:

```text
AUTHENTICATED USER
↓
SYSTEM ROLE
↓
SCOPED ROLE ASSIGNMENT
↓
SERVER-SIDE AUTHORIZATION
↓
DATABASE SECURITY HELPERS
↓
ROW LEVEL SECURITY
↓
DIRECT SECURITY TESTS
```

The governing rule is:

# ROLE + SCOPE + RESOURCE

Role alone is never sufficient.

M2 must make it technically impossible to rely only on hidden UI controls for security.

---

# 3. M2 Product Rules

Codex must preserve the following approved rules.

## 3.1 Initial Platform Roles

Initial system roles:

```text
ADMIN
MASTER
MENTOR
STUDENT
```

Contextual roles such as Team Lead are not platform roles and are not part of M2 unless a later approved document explicitly requires them.

---

## 3.2 Least Privilege

Users receive only the access required by:

- their role,
- their assigned scope,
- the target resource,
- and any explicit share/review rule defined later.

Do not create broad “authenticated user can read everything” policies.

---

## 3.3 Workspace Isolation

Future Personal, Team, Instructor, and Shared workspaces are separate permission scopes.

M2 does not build these workspaces yet, but its authorization model must be capable of protecting them later.

---

## 3.4 Private by Default

Personal content will be private by default.

Team content will be private to authorized team members and authorized instructional roles by default.

Cross-team access must never emerge accidentally from a broad role.

---

## 3.5 Scope Is Mandatory

Examples:

```text
MASTER + Cohort A
≠
MASTER + every cohort
```

```text
MENTOR + Team A
≠
MENTOR + Team B
```

```text
STUDENT + authenticated
≠
platform administration
```

---

## 3.6 Permission Inheritance Must Be Explicit

Do not silently infer access from neighboring scopes.

Examples:

- being Master of one cohort does not imply access to another cohort,
- being Mentor of one team does not imply access to the whole program,
- Admin operational authority does not automatically imply unrestricted educational-content access,
- future access to a Personal Workspace must not be implied by course enrollment alone.

---

## 3.7 Historical Attribution Is Permanent

Role changes or later team removal must not erase authorship or historical attribution.

M2 does not implement artifact history yet, but no role schema should make future attribution depend on a user's current role.

---

## 3.8 AI Must Use the Same Authorization Layer

M2 does not implement AI.

However, authorization helpers created in M2 must be reusable later by the AI context system.

Do not create a separate future permission path for AI.

---

# 4. M2 Technical Boundary

M2 is a security-foundation milestone.

It includes:

- role records,
- scoped role assignments,
- authorization resolution,
- reusable permission helpers,
- PostgreSQL security helper functions,
- initial RLS enablement/policies for M1/M2-owned tables,
- direct RLS tests,
- RBAC/scope acceptance tests,
- security hardening.

M2 does **not** yet implement:

- programs,
- curriculum versions,
- cohorts as full product features,
- enrollment workflows,
- workspaces,
- teams,
- team chat,
- Development Projects,
- activities,
- artifacts,
- voting,
- evidence,
- patents,
- sharing,
- AI,
- live classroom,
- dashboards.

If a later resource is needed only to test scope logic, use minimal test fixtures or deferred nullable scope identifiers without implementing the later business feature.

Do not pull M3–M17 into M2.

---

# 5. Global Codex Header

Use this block at the beginning of every M2 task if project rules are not automatically retained:

```text
You are implementing the FICI Invention Education & Development Platform.

Before making changes:

1. Read the relevant /docs files listed in this task.
2. Treat /docs as the product and architecture source of truth.
3. Do not invent missing business rules.
4. Do not implement features outside this task.
5. Preserve least privilege and private-by-default behavior.
6. Authorization is Role + Scope + Resource.
7. Never trust client-provided identity, role, or membership.
8. Enforce security server-side and in PostgreSQL RLS where applicable.
9. Do not rely on hidden UI controls for authorization.
10. Use strict TypeScript.
11. Validate runtime inputs.
12. Use migrations for schema/database changes.
13. Add direct security tests for every new authorization rule.
14. If requirements conflict or are ambiguous, STOP → FLAG → ASK.
15. Run the requested validation commands before finishing.
16. Report:
    - files changed,
    - migrations added,
    - authorization rules implemented,
    - RLS policies/helpers added,
    - commands run,
    - test results,
    - assumptions,
    - unresolved issues.
```

---

# 6. M2.1 — Role Schema & Seed

## Objective

Create the system-role foundation only.

## Read First

```text
/docs/03_ROLES_PERMISSIONS.md
/docs/08_DATA_MODEL_SCHEMA.md
/docs/10_TECHNICAL_ARCHITECTURE.md
/docs/11_API_CONTRACTS.md
/docs/12_ACCEPTANCE_TESTS.md
/docs/13_CODEX_IMPLEMENTATION_PLAN.md
/docs/15_CODEX_M1_PROMPTS.md
```

## Copy/Paste Prompt

```text
TASK ID: M2.1
TASK: Role Schema & Seed

Assume M1 is complete.

OBJECTIVE

Create the system-role schema and deterministic seed data required by M2.

IN SCOPE

1. Create the `roles` table from the approved schema.

Required conceptual fields:

- id
- code
- name
- description
- is_system_role

2. Seed exactly these initial system roles:

ADMIN
MASTER
MENTOR
STUDENT

3. Make role codes stable and unique.

4. Ensure system roles are not accidentally duplicated by repeated migrations/seeding.

5. Add appropriate created/updated metadata if the existing schema conventions require it.

6. Add server-side typed role-code definitions that remain synchronized with the database seed.

7. Add tests confirming:
   - all four roles exist,
   - role codes are unique,
   - duplicate seed execution does not create duplicates,
   - arbitrary client input cannot create a new system role through any M2 path.

OUT OF SCOPE

Do NOT implement:

- role assignment UI,
- scoped assignments,
- Admin dashboard,
- programs,
- cohorts,
- teams,
- workspaces,
- project roles,
- Team Lead,
- permission matrix UI.

SECURITY REQUIREMENTS

- Role code must not be accepted as proof of authorization.
- No browser-controlled value may make a user ADMIN/MASTER/MENTOR.
- System role records are configuration/security data.

VALIDATION

Run:

pnpm lint
pnpm typecheck
pnpm test:unit
pnpm test:integration
pnpm build

DEFINITION OF DONE

- `roles` exists,
- ADMIN/MASTER/MENTOR/STUDENT are seeded,
- seeds are idempotent,
- role types are represented safely in TypeScript,
- no role-management product UI exists,
- validation passes.

FINAL REPORT

Return:
1. Summary
2. Files changed
3. Migration(s)
4. Seed approach
5. Tests added
6. Commands/results
7. Assumptions
8. Unresolved issues
```

---

# 7. M2.2 — Scoped Role Assignments

## Objective

Implement role assignments that are always evaluated in a defined scope.

## Approved Concept

The conceptual model is:

```text
role_assignments
```

with:

- `id`
- `user_id`
- `role_id`
- `organization_id` nullable
- `program_id` nullable
- `cohort_id` nullable
- `team_id` nullable
- `project_id` nullable
- `starts_at`
- `ends_at`
- `status`
- `assigned_by`

M2 must not assume that a role is global merely because a role code exists.

## Important M2 Dependency Rule

M3 creates the full Program/Curriculum/Cohort model.

M4/M5/M6 create Workspace/Team/Project models.

Therefore M2 must **not** build those later domains prematurely.

If scope columns reference resources that do not exist yet:

- preserve the approved column model,
- use nullable UUID identifiers where necessary,
- defer foreign keys until the owned resource table exists if required,
- document every deferred constraint,
- do not invent substitute business entities,
- do not replace the approved scope columns with a different generic authorization model unless the docs are formally changed.

## Copy/Paste Prompt

```text
TASK ID: M2.2
TASK: Scoped Role Assignments

Read first:

- /docs/03_ROLES_PERMISSIONS.md
- /docs/08_DATA_MODEL_SCHEMA.md
- /docs/11_API_CONTRACTS.md
- /docs/12_ACCEPTANCE_TESTS.md
- /docs/13_CODEX_IMPLEMENTATION_PLAN.md

OBJECTIVE

Implement scoped role assignments without implementing M3+ product domains.

IN SCOPE

1. Create `role_assignments`.

Required conceptual fields:

- id
- user_id
- role_id
- organization_id nullable
- program_id nullable
- cohort_id nullable
- team_id nullable
- project_id nullable
- starts_at
- ends_at
- status
- assigned_by

2. Link user_id and assigned_by to the platform user/profile identity according to the existing M1 schema.

3. Link role_id to `roles`.

4. Use the approved project conventions for:
   - timestamps,
   - UUIDs,
   - status values,
   - archive/deactivation behavior.

5. Support active/inactive or equivalent status so permission resolution can ignore inactive assignments.

6. Permission resolution must also ignore:
   - assignments that have not started,
   - assignments that have expired.

7. Prevent exact duplicate active assignments where practical.

8. Add read/query helpers for retrieving the authenticated user's active role assignments.

9. Do not create broad “user has role” helpers that ignore scope.

10. Add tests for:
   - active assignment recognized,
   - inactive assignment ignored,
   - future assignment ignored,
   - expired assignment ignored,
   - role assignment bound to the correct user,
   - scope fields preserved,
   - duplicate/retry handling.

OUT OF SCOPE

Do NOT create:

- cohort management,
- team management,
- project management,
- enrollment workflows,
- role-management UI,
- self-service role requests.

IMPORTANT

If a foreign key cannot yet exist because the owned scope table belongs to M3/M5/M6:
- keep the approved field,
- defer only that FK,
- document the deferred FK clearly,
- do not invent the later resource.

VALIDATION

Run:

pnpm lint
pnpm typecheck
pnpm test:unit
pnpm test:integration
pnpm build

DEFINITION OF DONE

A user's role assignment can be resolved with its exact scope and time/status validity.

FINAL REPORT

Return:
1. Summary
2. Files changed
3. Migration(s)
4. Assignment validity rules
5. Deferred foreign keys, if any
6. Tests/results
7. Assumptions
8. Unresolved issues
```

---

# 8. M2.3 — Authorization Service

## Objective

Create one reusable server-side authorization layer for later business operations.

## Core Rule

Never authorize from client claims such as:

```text
"I am Admin"
"I am Master"
"I belong to Team X"
```

Trusted identity comes from the authenticated Supabase session.

Trusted authorization comes from server/database state.

## Required Direction

Authorization helpers should resolve:

```text
authenticated user
+
active role assignments
+
requested scope
+
target resource
=
ALLOW / DENY
```

## Initial Server-Side Capabilities

M2 may implement generic helpers such as:

```text
getAuthorizationContext()
getActiveRoleAssignments()
hasScopedRole()
requireScopedRole()
requireAdminScope()
```

Exact names may vary.

Avoid helpers such as:

```text
isMaster(userId)
```

if they do not include scope.

## Copy/Paste Prompt

```text
TASK ID: M2.3
TASK: Authorization Service

Read first:

- /docs/03_ROLES_PERMISSIONS.md
- /docs/08_DATA_MODEL_SCHEMA.md
- /docs/10_TECHNICAL_ARCHITECTURE.md
- /docs/11_API_CONTRACTS.md
- /docs/12_ACCEPTANCE_TESTS.md

OBJECTIVE

Create the reusable server-side authorization service for Role + Scope + Resource checks.

IN SCOPE

1. Resolve authenticated identity from the verified server session only.

2. Load only active, currently valid role assignments.

3. Create typed authorization-context structures.

4. Add scoped-role helpers.

5. Return stable authorization failures using the approved API error model.

6. Do not leak existence/details of inaccessible resources.

7. Ensure authorization code can later be reused by:
   - API operations,
   - server actions/routes,
   - AI context retrieval,
   - Liveblocks room authorization,
   - file access,
   - review operations.

8. Add unit tests for:
   - STUDENT denied Admin-only action,
   - MASTER allowed only inside assigned scope,
   - MASTER denied outside assigned scope,
   - MENTOR allowed only inside assigned scope,
   - expired assignment denied,
   - inactive assignment denied,
   - client-provided role ignored,
   - client-provided user ID ignored.

9. Preserve the distinction between:
   - operational administration,
   - educational/content access.

Do not implement unrestricted Admin content access merely because ADMIN exists.

OUT OF SCOPE

- resource-specific workspace permissions,
- team membership authorization,
- artifact approval,
- sharing,
- AI,
- chat,
- programs/cohorts UI.

ERROR BEHAVIOR

Use the approved stable errors, including:

AUTH_REQUIRED
FORBIDDEN
NOT_FOUND
VALIDATION_ERROR

Permission failures must not reveal sensitive resource details.

VALIDATION

Run:

pnpm lint
pnpm typecheck
pnpm test:unit
pnpm test:integration
pnpm build

DEFINITION OF DONE

All future server operations can call one authorization layer instead of recreating role logic.

FINAL REPORT

Return:
1. Summary
2. Authorization service structure
3. Files changed
4. Permission-resolution algorithm
5. Error behavior
6. Tests/results
7. Assumptions
8. Unresolved issues
```

---

# 9. M2.4 — PostgreSQL / RLS Security Helper Functions

## Objective

Create audited database helper functions that future RLS policies can reuse safely.

## Architecture Principle

Complex RLS logic should not be duplicated across every table.

The approved technical direction includes helpers conceptually similar to:

```text
can_access_workspace(user_id, workspace_id)
can_edit_workspace(user_id, workspace_id)
can_access_project(user_id, project_id)
can_review_project(user_id, project_id)
can_access_artifact(user_id, artifact_id)
```

Most target resources do not exist yet in M2.

Therefore M2 should implement only the **foundational scope/role helpers that can be correct now**, while reserving resource-specific helpers for the milestone that owns the resource.

## Suggested M2-Level Database Helpers

Names may vary, but capabilities should include:

```text
current_platform_user_id()
has_active_role(role_code)
has_active_role_in_organization(role_code, organization_id)
has_active_role_in_program(role_code, program_id)
has_active_role_in_cohort(role_code, cohort_id)
has_active_role_in_team(role_code, team_id)
has_active_role_in_project(role_code, project_id)
```

Important:

A generic `has_active_role(role_code)` must not be used for scoped product authorization unless the relevant approved rule is truly global.

## Security Requirements

Database helpers must be reviewed for:

- SQL injection resistance,
- search_path safety,
- SECURITY DEFINER implications,
- recursion with RLS policies,
- correct use of authenticated identity,
- inactive/expired assignment filtering,
- no caller-controlled user impersonation.

## Copy/Paste Prompt

```text
TASK ID: M2.4
TASK: RLS Security Helper Functions

Read first:

- /docs/03_ROLES_PERMISSIONS.md
- /docs/08_DATA_MODEL_SCHEMA.md
- /docs/10_TECHNICAL_ARCHITECTURE.md
- /docs/12_ACCEPTANCE_TESTS.md

OBJECTIVE

Add the minimum safe PostgreSQL authorization helper functions required for M2 RLS.

IN SCOPE

1. Create database helper functions for:
   - resolving current authenticated platform user where required,
   - checking active role assignment,
   - checking role within specific approved scope columns.

2. Every helper must:
   - derive identity from authenticated context,
   - ignore inactive/future/expired assignments,
   - avoid trusting arbitrary user_id supplied by the client.

3. If a helper uses SECURITY DEFINER:
   - explain why,
   - use a safe fixed search_path,
   - restrict exposure appropriately,
   - add direct tests.

4. Avoid circular RLS dependency.

5. Keep helpers small, deterministic, and auditable.

6. Do not create resource-specific workspace/team/project/artifact access logic before those resources exist.

7. Add SQL/integration tests proving:
   - assigned scope returns true,
   - unassigned scope returns false,
   - expired assignment returns false,
   - inactive assignment returns false,
   - another user's assignment cannot be impersonated,
   - unrelated role returns false.

OUT OF SCOPE

- workspace access functions whose workspace schema is not built,
- project/artifact access functions whose resource tables do not exist,
- sharing logic,
- approval logic.

VALIDATION

Run the project's database/RLS test command plus:

pnpm lint
pnpm typecheck
pnpm test:unit
pnpm test:integration
pnpm build

DEFINITION OF DONE

M2 has a tested database authorization foundation that later RLS policies can compose.

FINAL REPORT

Return:
1. Functions added
2. Security properties
3. SECURITY DEFINER usage, if any
4. Migrations/files changed
5. Tests/results
6. Deferred resource helpers
7. Assumptions
8. Unresolved issues
```

---

# 10. M2.5 — Base Row Level Security Policies

## Objective

Enable and test Row Level Security for the tables owned by M1/M2 without pretending later resource policies already exist.

## Principle

RLS is defense in depth and a required enforcement layer.

Application checks do not replace RLS.

RLS does not replace server-side business-operation checks.

Use both:

```text
SERVER AUTHORIZATION
+
DATABASE RLS
```

## Tables in M2 Scope

At minimum review:

```text
users / profiles
roles
role_assignments
```

Use the actual M1 table names.

## Policy Direction

### Own Profile

An authenticated user may read/update only the portions of their own profile allowed by M1.

Never allow arbitrary cross-user profile mutation.

### Roles

Authenticated users may need limited role-code visibility for normal application behavior, but role records must not be client-mutable.

If role-table read access is unnecessary from the browser, prefer server-side access only.

### Role Assignments

A user may be allowed to read their own effective assignments if needed for user experience.

A user must not:

- assign themselves ADMIN,
- assign themselves MASTER,
- alter assigned scope,
- create arbitrary role assignments,
- update `assigned_by`.

Admin assignment operations will later use explicit business commands and server authorization.

Do not expose generic client CRUD for role assignments.

## Copy/Paste Prompt

```text
TASK ID: M2.5
TASK: Base RLS Policies

Read first:

- /docs/03_ROLES_PERMISSIONS.md
- /docs/08_DATA_MODEL_SCHEMA.md
- /docs/10_TECHNICAL_ARCHITECTURE.md
- /docs/11_API_CONTRACTS.md
- /docs/12_ACCEPTANCE_TESTS.md

OBJECTIVE

Enable and implement direct PostgreSQL RLS protection for M1/M2-owned sensitive tables.

IN SCOPE

1. Identify all sensitive M1/M2 tables.

2. Enable RLS explicitly.

3. Add least-privilege policies.

4. Protect profile ownership rules from M1.

5. Protect `roles` against unauthorized mutation.

6. Protect `role_assignments` against self-escalation and cross-user mutation.

7. Do not create permissive catch-all policies.

8. Ensure server/service-level administrative paths remain explicit and isolated.

9. Add direct SQL/RLS tests for:
   - anonymous access denial where required,
   - Student cannot modify role records,
   - Student cannot assign own role,
   - Student cannot edit another user's assignment,
   - Student cannot alter assignment scope,
   - user cannot update another user's profile,
   - valid own-profile operation still works,
   - valid server-authorized path works where designed.

10. Test direct database access behavior, not only application routes.

OUT OF SCOPE

- future workspace policies,
- team policies,
- project policies,
- artifact policies,
- chat policies,
- share policies.

SECURITY RULE

No M2 acceptance test may pass merely because the UI does not show a button.

VALIDATION

Run database/RLS tests plus:

pnpm lint
pnpm typecheck
pnpm test:unit
pnpm test:integration
pnpm build

DEFINITION OF DONE

Sensitive M1/M2 tables are RLS-protected and privilege escalation attempts fail directly at the database boundary.

FINAL REPORT

Return:
1. Tables with RLS enabled
2. Policies added
3. Policies intentionally deferred
4. Attack cases tested
5. Files/migrations changed
6. Commands/results
7. Assumptions
8. Unresolved issues
```

---

# 11. M2.6 — RBAC / Scope Acceptance Tests

## Objective

Implement the approved BLOCKER role/scope acceptance tests and direct RLS coverage.

## Mandatory Product Acceptance Tests

M2 must implement:

```text
AT-RBAC-001
AT-RBAC-002
AT-RBAC-003
```

### AT-RBAC-001 — Student Cannot Perform Admin Action

```text
Given Student A1
When they call a role-assignment or platform administration operation
Then the request returns FORBIDDEN
```

Priority:

```text
BLOCKER
```

### AT-RBAC-002 — Master Limited to Assigned Cohort

```text
Given Master is assigned to Test Cohort only
When Master attempts to manage an unrelated cohort
Then access is denied
```

Priority:

```text
BLOCKER
```

M3 owns the real cohort domain.

For M2, implement the security test using the approved scoped `cohort_id` assignment model without building the full cohort feature.

### AT-RBAC-003 — Mentor Scope

```text
Given Mentor is assigned only to Team A
When Mentor attempts to access Team B project content
Then access is denied
```

Priority:

```text
BLOCKER
```

M5/M6 own real teams/projects.

For M2, test scope resolution at the authorization layer with deterministic fixture UUIDs or another minimal non-product fixture approach.

Do not implement Team or Project business features just to satisfy this M2 security test.

## Additional Required Security Tests

At minimum:

- client user-ID spoofing does not change identity,
- client role spoofing does not change role,
- direct SQL cannot self-escalate privileges,
- inactive assignment denied,
- expired assignment denied,
- future assignment denied,
- unrelated scope denied,
- permission denial does not expose restricted resource details,
- service/server privileged path is not reachable from browser credentials.

## Copy/Paste Prompt

```text
TASK ID: M2.6
TASK: RBAC / Scope Acceptance Tests

Read first:

- /docs/12_ACCEPTANCE_TESTS.md
- /docs/03_ROLES_PERMISSIONS.md
- /docs/11_API_CONTRACTS.md
- /docs/13_CODEX_IMPLEMENTATION_PLAN.md

OBJECTIVE

Convert the approved M2 role/scope requirements into automated acceptance and direct-RLS tests.

IN SCOPE

1. Implement AT-RBAC-001.
2. Implement AT-RBAC-002.
3. Implement AT-RBAC-003.
4. Add direct RLS privilege-escalation tests.
5. Add assignment validity tests.
6. Add identity/role spoofing tests.
7. Test both:
   - server authorization layer,
   - direct database/RLS enforcement.

TEST IDENTITIES

Use deterministic test identities corresponding conceptually to:

- Admin
- Master
- Mentor
- Student A
- Student B

Do not depend on manually configured production users.

SCOPE FIXTURES

Use deterministic IDs for:
- Cohort A
- Cohort B
- Team A
- Team B
- Project A
- Project B

These are authorization fixtures only in M2.
Do not implement M3/M5/M6 product behavior.

MANDATORY RESULT

All BLOCKER M2 security tests must pass.

If a BLOCKER test cannot be implemented because an approved rule is genuinely ambiguous:
STOP and report it.
Do not weaken the test.

VALIDATION

Run:

pnpm lint
pnpm typecheck
pnpm test:unit
pnpm test:integration
pnpm test:e2e
pnpm build

Also run any dedicated Supabase/RLS test command configured by the repository.

DEFINITION OF DONE

- AT-RBAC-001 PASS
- AT-RBAC-002 PASS
- AT-RBAC-003 PASS
- direct RLS self-escalation tests PASS
- direct cross-scope tests PASS
- identity spoofing tests PASS

FINAL REPORT

Return:
1. Test matrix
2. PASS/FAIL by test
3. Files changed
4. Commands/results
5. Any blocked/ambiguous requirement
```

---

# 12. M2.7 — Security Hardening & Completion Review

## Objective

Review M2 as a security boundary before M3 starts.

## Security Review Areas

Review:

- authenticated identity source,
- role seed integrity,
- active role-assignment resolution,
- scope handling,
- time-bound assignments,
- server authorization helpers,
- database helper functions,
- RLS policies,
- service-role isolation,
- browser/server environment separation,
- direct ID manipulation,
- privilege escalation,
- error leakage,
- test coverage.

## Required Negative Tests

Attempt:

```text
STUDENT → assign self ADMIN
STUDENT → assign another user a role
STUDENT → change own assignment scope
MASTER Cohort A → act in Cohort B
MENTOR Team A → act in Team B
CLIENT → submit fake user ID
CLIENT → submit fake role
CLIENT → bypass server and query database directly
ANONYMOUS → access protected authorization data
EXPIRED ASSIGNMENT → retain access
INACTIVE ASSIGNMENT → retain access
```

All must fail according to approved rules.

## Copy/Paste Prompt

```text
TASK ID: M2.7
TASK: M2 Security Hardening

Read first:

- /docs/03_ROLES_PERMISSIONS.md
- /docs/08_DATA_MODEL_SCHEMA.md
- /docs/10_TECHNICAL_ARCHITECTURE.md
- /docs/11_API_CONTRACTS.md
- /docs/12_ACCEPTANCE_TESTS.md
- /docs/13_CODEX_IMPLEMENTATION_PLAN.md
- /docs/16_CODEX_M2_PROMPTS.md

OBJECTIVE

Perform a security-focused review of M2 only and close defects without adding later product features.

REVIEW

1. Verify every authorization decision starts from authenticated server identity.
2. Verify Role + Scope + Resource is preserved.
3. Verify inactive/future/expired assignments cannot authorize.
4. Verify no browser code can use privileged service credentials.
5. Verify role_assignments cannot be self-escalated through direct database access.
6. Verify RLS is enabled on all sensitive M1/M2 tables.
7. Verify no permissive policy accidentally allows broad authenticated access.
8. Verify error responses do not expose inaccessible resource details.
9. Verify database helper functions cannot be abused through caller-supplied user IDs.
10. Verify all M2 BLOCKER tests pass.

DO NOT

- add dashboards,
- implement M3,
- create workspaces,
- create teams,
- create projects,
- add AI,
- add chat,
- redesign UI.

RUN

pnpm lint
pnpm typecheck
pnpm test:unit
pnpm test:integration
pnpm test:e2e
pnpm build

Run all configured Supabase/RLS tests.

DEFINITION OF DONE

M2 is complete only if:
- security tests pass,
- all M2 BLOCKER tests pass,
- no privilege-escalation path remains known,
- no scope-bypass path remains known,
- no later product feature was added.

FINAL REPORT

Return:
1. Security review summary
2. Issues found
3. Issues fixed
4. Remaining issues
5. BLOCKER status
6. Test results
7. Recommendation: READY FOR M3 or NOT READY FOR M3
```

---

# 13. Required Test Identity Model

M2 should establish reusable test identities for later milestones.

Conceptually:

```text
Admin
Master
Mentor
Student A
Student B
```

Later acceptance tests may expand this into:

```text
Admin
Master
Mentor
Student A1
Student A2
Student B1
Student B2
```

Do not hard-code production behavior around test emails.

Use repository test fixtures/seeds.

---

# 14. Authorization Context — Recommended Shape

Exact implementation may differ, but the application should have a typed server-side concept similar to:

```ts
type AuthorizationContext = {
  userId: string;
  roles: Array<{
    roleCode: "ADMIN" | "MASTER" | "MENTOR" | "STUDENT";
    organizationId?: string | null;
    programId?: string | null;
    cohortId?: string | null;
    teamId?: string | null;
    projectId?: string | null;
  }>;
};
```

This is an implementation aid, not a replacement for the approved database model.

Never accept this object directly from the browser as trusted authorization state.

---

# 15. Assignment Validity Rule

A role assignment is authorization-eligible only when:

```text
status = active
AND
starts_at <= now, when starts_at exists
AND
ends_at > now, when ends_at exists
```

Use the repository's approved time semantics consistently.

Do not treat archived/inactive assignments as active permissions.

---

# 16. Scope-Matching Rule

A role assignment should authorize only within its relevant scope.

Conceptually:

```text
ROLE MATCH
+
SCOPE MATCH
+
RESOURCE BELONGS TO THAT SCOPE
=
POSSIBLE AUTHORIZATION
```

The final resource rule may still deny access.

Example:

A Master assigned to Cohort A may eventually review Team A artifacts if Team A belongs to Cohort A and the workflow grants review access.

That does **not** imply access to:

- Cohort B,
- Team B,
- private personal drafts,
- unrelated projects.

M2 builds the foundation.

Later milestones add resource-specific rules.

---

# 17. Operational Admin vs Content Oversight

Do not collapse these into one unrestricted superuser rule.

Approved product direction distinguishes:

```text
Operational Admin Access
```

from:

```text
Content Oversight Access
```

M2 should therefore avoid patterns such as:

```text
IF ADMIN → bypass every educational-content rule
```

unless a specific approved resource policy later grants that access.

The Supabase service role is technical infrastructure, not a product-role equivalent of FICI Admin.

Do not map:

```text
ADMIN = service_role
```

---

# 18. Server Authorization vs RLS

The platform uses two enforcement layers.

## Application Layer

Responsible for:

- business operation authorization,
- command validation,
- state validation,
- explicit error behavior,
- transaction orchestration.

## Database RLS Layer

Responsible for:

- preventing unauthorized row access,
- preventing direct-client privilege escalation,
- providing defense in depth.

Required model:

```text
CLIENT
↓
SERVER BUSINESS OPERATION
↓
AUTHENTICATION
↓
AUTHORIZATION
↓
VALIDATION
↓
DATABASE
↓
RLS
```

Do not replace one layer with the other.

---

# 19. M2 Expected Repository Additions

After M2, the repository may include structures conceptually similar to:

```text
features/
├── auth/
├── users/
└── authorization/
    ├── context.ts
    ├── roles.ts
    ├── scope.ts
    └── require-permission.ts

lib/
├── auth/
├── permissions/
│   ├── authorization.ts
│   ├── role-assignments.ts
│   └── errors.ts
└── db/

supabase/
├── migrations/
│   ├── ...roles...
│   ├── ...role_assignments...
│   ├── ...auth_helpers...
│   └── ...rls_policies...
└── tests/
    └── rls/

tests/
├── unit/
│   └── authorization/
├── integration/
│   └── authorization/
└── e2e/
    └── rbac.spec.ts
```

Exact paths may vary.

Keep architecture boundaries clean.

---

# 20. M2 Completion Gate

M2 is complete only when:

```text
[ ] roles table exists
[ ] ADMIN role seeded
[ ] MASTER role seeded
[ ] MENTOR role seeded
[ ] STUDENT role seeded

[ ] role_assignments exists
[ ] assignments are scoped
[ ] inactive assignments do not authorize
[ ] future assignments do not authorize
[ ] expired assignments do not authorize

[ ] server authorization context exists
[ ] authorization uses verified session identity
[ ] client role spoofing fails
[ ] client user-ID spoofing fails

[ ] database authorization helpers exist
[ ] helper security reviewed
[ ] direct helper tests pass

[ ] RLS enabled on sensitive M1/M2 tables
[ ] profile RLS remains correct
[ ] roles cannot be client-mutated
[ ] role assignments cannot be self-escalated
[ ] unrelated user assignment cannot be modified

[ ] AT-RBAC-001 PASS
[ ] AT-RBAC-002 PASS
[ ] AT-RBAC-003 PASS

[ ] direct RLS privilege-escalation tests PASS
[ ] direct cross-scope tests PASS

[ ] lint passes
[ ] typecheck passes
[ ] unit tests pass
[ ] integration tests pass
[ ] E2E security tests pass
[ ] build passes

[ ] no M3+ product feature implemented prematurely
[ ] Codex reports READY FOR M3
```

Any open security BLOCKER means:

```text
NOT READY FOR M3
```

---

# 21. Recommended Commit Sequence

Example:

```text
feat(authz): add system role schema and seed
feat(authz): add scoped role assignments
feat(authz): add server authorization context
feat(db): add authorization helper functions
feat(security): add base RLS policies
test(authz): add scoped RBAC acceptance tests
test(security): add direct RLS escalation coverage
chore(security): complete M2 hardening
```

Keep migrations and their tests in the same logical commit/PR where practical.

---

# 22. M2 Technical Non-Goals

Do not accept these as “helpful additions” during M2:

- role-management dashboard,
- Admin dashboard,
- Master dashboard,
- Student dashboard,
- program management,
- cohort management,
- enrollment UI,
- workspace UI,
- team creation,
- team chat,
- project creation,
- artifact system,
- file sharing,
- voting,
- patent tools,
- AI assistant,
- Liveblocks integration,
- Daily integration,
- notification center,
- final design system.

M2 is authorization/security infrastructure.

---

# 23. Potential M2 Ambiguities Codex Must Flag

Codex must flag instead of inventing behavior if it encounters questions such as:

- Does ADMIN automatically receive educational-content oversight?
- Which Admin scope levels are allowed in the first deployment?
- Can one role assignment contain more than one non-null scope column?
- If multiple scope columns are set, are they cumulative constraints or alternate scopes?
- Should expired assignments remain visible in standard user-facing queries?
- Can a user hold multiple roles in the same scope?
- Can a user hold the same role in multiple scopes?
- Who may create the very first Admin assignment in a fresh environment?
- Are system roles editable by Admin, or immutable configuration?
- Should users be able to see their role labels directly from the browser?
- Which M2 administrative operations, if any, should be exposed before the M3 Admin workflows exist?
- Should organization-level MASTER imply all cohorts in that organization, or must cohort assignment always be explicit?
- Should program-level MASTER imply all cohorts under that program?
- How will later team/project scope inherit from cohort scope?

If the approved docs do not resolve a question:

```text
STOP → FLAG → ASK
```

Do not silently define product policy.

---

# 24. Recommended Safe Defaults for Purely Technical Decisions

Only where the decision does not change approved business behavior:

- system role codes should be immutable,
- role seeds should be idempotent,
- security-sensitive tables should use RLS,
- no authenticated-wide wildcard policy,
- no client write access to role definitions,
- no client write access to role assignments,
- use server-side business operations for privileged mutations,
- keep service-role credentials server-only,
- preserve inactive/expired assignment history rather than destructively deleting it,
- add foreign keys to later-owned scope resources only when those resources are introduced,
- use deterministic security fixtures in tests.

Any user-facing permission-policy decision must still be flagged.

---

# 25. M2 Review Checklist for Ahmad/FICI

Before implementation, confirm that this document correctly reflects the intended security model:

```text
1. Four initial platform roles:
   ADMIN / MASTER / MENTOR / STUDENT

2. Role alone is insufficient.

3. Access depends on:
   Role + Scope + Resource

4. Master is limited to assigned educational scope.

5. Mentor is limited to explicitly assigned scope.

6. Student cannot perform platform administration.

7. Personal/private content is not made visible simply because someone is Master or Admin.

8. Admin operational authority is distinct from educational-content oversight.

9. Authorization is enforced on the server.

10. RLS provides a second database-level enforcement layer.

11. AI, realtime, and later systems must reuse the same authorization model.

12. M2 builds security foundations only; no course/team/project features yet.
```

---

# 26. Next File After M2

After M2 has actually been:

```text
IMPLEMENTED
→ TESTED
→ SECURITY-REVIEWED
→ COMMITTED
```

create:

# `17_CODEX_M3_PROMPTS.md`

M3 will cover:

```text
Programs
Curriculum Versions
Session Definitions
Activity Definitions
Activity Dependencies
Cohorts
Enrollments
Assigned Master
```

M3 must build on the M2 security foundation rather than creating a second permission model.

---

# 27. Final Execution Rule

For M2:

```text
ROLES
→ SCOPED ASSIGNMENTS
→ SERVER AUTHORIZATION
→ DATABASE HELPERS
→ RLS
→ BLOCKER TESTS
→ SECURITY HARDENING
```

Do not skip directly to product features.

---

# End of Document

**Current Status:** Draft v0.1 — Ready for Ahmad/FICI review.  
**Execution Step After M1 Completion:** Start with **M2.1 — Role Schema & Seed**.
