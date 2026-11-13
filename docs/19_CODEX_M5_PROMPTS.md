# FICI Invention Education & Development Platform
## Codex M5 Execution Prompts — Teams, Membership & Team Chat

**Document:** `19_CODEX_M5_PROMPTS.md`  
**Status:** Draft v0.1 — For Review  
**Depends on:** `01_PRODUCT_REQUIREMENTS.md` through `18_CODEX_M4_PROMPTS.md`  
**Purpose:** Provide exact copy/paste prompts for Codex to implement Milestone M5 safely and incrementally after M4 is complete.

---

# 1. Preconditions

Do not begin M5 until M4 is:

```text
IMPLEMENTED
→ TESTED
→ SECURITY-REVIEWED
→ COMMITTED
```

Required M4 state:

- `workspaces` exists,
- PERSONAL / TEAM / MASTER / SHARED / CASE_STUDY types exist,
- Personal Workspace provisioning works,
- Personal Workspace is private by default,
- Workspace access resolver exists,
- Team Workspace type exists as a schema foundation,
- direct-ID Workspace privacy tests pass,
- RLS protects Workspace data,
- Codex reports READY FOR M5.

If M4 is incomplete:

```text
STOP → FINISH M4 → REVIEW → COMMIT → BEGIN M5
```

M5 must not weaken any Personal Workspace privacy rule.

---

# 2. M5 Goal

M5 delivers the platform's first real private collaborative environment.

M5 must implement:

```text
COHORT
↓
OFFICIAL TEAM
↓
TEAM MEMBERSHIP
↓
TEAM WORKSPACE
↓
PRIVATE TEAM CHAT
↓
MEMBERSHIP CHANGES
↓
REALTIME UPDATES
↓
AUDITABLE ACCESS CHANGES
```

The core privacy rule is:

# TEAM A PRIVATE CONTENT MUST NOT BE ACCESSIBLE TO TEAM B

The core history rule is:

# MEMBER REMOVAL REVOKES FUTURE ACCESS — IT DOES NOT ERASE HISTORY

---

# 3. M5 Product Boundary

M5 includes:

- `teams`,
- `team_memberships`,
- Team Workspace provisioning,
- Team Lead field/role,
- add member,
- remove member,
- move member,
- archive team,
- `chat_channels`,
- `chat_memberships`,
- `chat_messages`,
- private Team Chat,
- canonical chat persistence,
- Supabase Realtime/Broadcast notification,
- Team/Chat RLS,
- initial `audit_events`,
- minimal notification persistence if required by existing acceptance tests,
- Team and Chat acceptance tests.

M5 does **not** yet implement:

- Development Project core,
- project membership,
- Development Objects,
- activity execution,
- artifacts/versioning,
- sharing,
- voting,
- Affinity,
- Mind Mapping,
- patent tools,
- AI,
- review/approval,
- full notification center,
- Liveblocks collaborative canvases.

Those belong to later milestones.

---

# 4. Approved Team Lifecycle

An official Team follows this lifecycle:

```text
Created
↓
Members Assigned
↓
Active
↓
Optional Membership Changes
↓
Course / Project Continues
↓
Completed
↓
Archived
```

Archiving must not erase Team history.

---

# 5. Approved Team Schema

Implement:

```text
teams
```

Conceptual fields:

- `id`
- `cohort_id`
- `name`
- `description`
- `status`
- `team_lead_user_id` nullable
- `master_user_id`
- `workspace_id`
- `created_by`
- `archived_at`

Follow global record conventions where appropriate.

## Important M5/M6 Boundary

The Team API contract includes:

```text
projectId optional
```

but Development Projects belong to M6.

Therefore M5 must not create Development Project schema early.

Until M6:

- keep Team creation independent of a Project,
- if a `projectId` parameter already exists in a shared contract, reject/defer it safely unless the M6 schema exists,
- document the deferred project-link side effect,
- do not invent a temporary project table.

---

# 6. Approved Team Membership Schema

Implement:

```text
team_memberships
```

Conceptual fields:

- `id`
- `team_id`
- `user_id`
- `membership_role`
- `joined_at`
- `left_at`
- `status`
- `added_by`
- `removed_by` nullable

Initial membership roles:

```text
member
team_lead
mentor
```

Historical memberships must remain persisted after removal.

---

# 7. Team Lead Rule

Team Lead is optional.

Possible responsibilities include:

- coordinate internal work,
- organize meetings,
- launch permitted internal activities,
- submit team work,
- coordinate decisions,
- manage task coordination.

Team Lead must **not** automatically gain the authority to:

- add/remove official Team members,
- change platform roles,
- expose private teammate content,
- override Master decisions,
- change Team ownership.

Do not convert `team_lead` into an administrative shortcut.

---

# 8. Team Creation Authorization

Default authorized creators:

```text
ADMIN
MASTER assigned to the target cohort
```

Default unauthorized creators:

```text
STUDENT
MENTOR
unrelated MASTER
```

unless later explicit delegation is approved.

Students may eventually create informal working groups, but M5 official Teams must not be confused with informal groups.

---

# 9. Team Creation Transaction

Approved `createTeam(input)` input:

```text
cohortId
name
description optional
projectId optional
teamLeadUserId optional
```

Authorized:

```text
Admin
Master assigned to cohort
```

The Team creation transaction must create:

```text
1. Team record
2. Team Workspace
3. Team Chat Channel
4. assigned Master relationship/access
5. optional Project link — DEFERRED TO M6 if Project model not yet present
6. audit event
```

All core M5 records must succeed or fail transactionally.

A half-created Team is not acceptable.

---

# 10. Team Workspace Provisioning

M4 already introduced `workspace_type = TEAM`.

M5 now makes it operational.

Each official Team should have exactly one primary Team Workspace.

Conceptually:

```text
Team
↔
Team Workspace
```

The Team Workspace must:

- reference the Team,
- reference the Cohort,
- have `workspace_type = TEAM`,
- be private to authorized Team scope,
- use the M4 Workspace access resolver extended with M5 Team membership logic.

Team B must not access Team A Workspace.

---

# 11. Member Addition Rules

When a user is added:

1. Team Membership becomes active.
2. Team Workspace becomes accessible.
3. Team Chat becomes accessible.
4. Team tools may become accessible in later milestones.
5. Team project content may become accessible in later milestones according to authorization.
6. Restricted Personal Workspace content must not become visible.
7. notification/audit behavior must be preserved according to the API/acceptance requirements.

Eligibility must be validated.

At minimum:

- user exists,
- Team exists,
- Team is in valid state,
- user is eligible for target Cohort/Program according to enrollment rules,
- duplicate active Team Membership is forbidden.

---

# 12. Member Removal Rules

When a user is removed:

```text
FUTURE TEAM ACCESS = REVOKED
FUTURE CHAT ACCESS = REVOKED
HISTORICAL CONTRIBUTIONS = PRESERVED
```

Must preserve:

- prior authored content,
- prior messages,
- prior votes,
- comments,
- authorship,
- audit history.

M5 currently owns historical Team membership and Chat messages.

Later content types will follow the same rule.

Removing a member must not delete their user account or Personal Workspace.

---

# 13. Move Between Teams

Approved operation:

```text
moveTeamMember(userId, fromTeamId, toTeamId, reason?)
```

Transaction:

```text
1. close old Team Membership
2. close/revoke old Chat Membership
3. create new Team Membership
4. create new Chat Membership
5. preserve old contribution history
6. notify user where notification foundation exists
7. audit
```

Important:

Moving Team A → Team B must **not** copy Team A private content into Team B.

---

# 14. Multiple Team Membership

Approved product guidance:

```text
multiple Teams only when explicitly allowed by Program
```

For a standard course configuration:

```text
one primary Team per Project by default
```

However M6 owns Projects.

Therefore M5 should not invent Project-based exclusivity.

If the Program/Cohort configuration does not yet define multiple-Team policy:

```text
STOP → FLAG → ASK
```

before enforcing a permanent business constraint beyond duplicate same-Team membership.

---

# 15. Approved Chat Schema

Implement:

```text
chat_channels
chat_memberships
chat_messages
```

## `chat_channels`

Fields:

- `id`
- `channel_type`
- `workspace_id`
- `team_id` nullable
- `cohort_id` nullable
- `name`
- `status`
- `created_at`

Channel types defined by the schema:

```text
TEAM
COHORT
MASTER_TEAM
ACTIVITY
OTHER
```

MVP M5 priority:

```text
TEAM
```

Do not build other channel products unless required as internal fixtures.

---

## `chat_memberships`

Fields:

- `id`
- `chat_channel_id`
- `user_id`
- `access_level`
- `joined_at`
- `left_at`

M5 must define only the minimum access levels necessary for Team Chat.

Do not invent a large chat-role model.

---

## `chat_messages`

Fields:

- `id`
- `chat_channel_id`
- `sender_user_id`
- `parent_message_id` nullable
- `content`
- `message_type`
- `created_at`
- `edited_at`
- `deleted_at`

Message types:

```text
TEXT
FILE
LINK
SYSTEM
```

M5 should prioritize TEXT.

FILE behavior depends on the File system milestone and must not be faked with insecure URLs.

---

# 16. Team Chat Product Principle

Each Team must have one dedicated private Team communication channel.

Default authorized audience:

- active Team members,
- assigned Master according to final approved policy,
- assigned Mentor only if explicitly enabled.

Unauthorized:

- other Teams,
- unrelated Students,
- unrelated Mentors,
- unrelated Masters,
- removed members.

---

# 17. Master Chat Access — Important Approval Point

Existing product documents recommend:

```text
Assigned Master: Read + Post
visible identity/presence
no hidden monitoring
```

However the permission document marks this as a proposed/recommended policy requiring final approval.

Therefore Codex must not silently hard-code a disputed policy.

Before implementing Master Chat access:

- use the latest approved FICI policy if it exists in `/docs`,
- otherwise STOP → FLAG → ASK.

Regardless of the final access mode:

# HIDDEN INSTRUCTOR SURVEILLANCE MUST NOT BE IMPLEMENTED

If Master can access Team Chat, the identity/access must be visible and auditable.

---

# 18. Mentor Chat Access

Mentor Chat access is not global.

It requires:

- explicit assignment,
- appropriate Team scope,
- enabled policy.

A Mentor assigned to Team A must not gain Team B Chat access.

Do not treat platform role MENTOR as sufficient.

---

# 19. Chat Is Not the Project Source of Truth

Chat is communication.

Important project decisions must later become structured records.

Do not treat a message as:

- formal Decision,
- approved Feature,
- Evidence,
- Project baseline,
- approval.

M5 stores communication only.

---

# 20. Realtime Architecture

Use:

```text
PostgreSQL = canonical message storage
Supabase Realtime/Broadcast = realtime notification/delivery signal
```

Flow:

```text
User sends message
↓
Server validates Team/Chat access
↓
Message inserted into PostgreSQL
↓
Realtime event notifies authorized connected clients
↓
Clients render/fetch canonical stored message
```

Do not use ephemeral Broadcast as permanent message storage.

---

# 21. Realtime Privacy

Realtime itself must be private.

Team B must not:

- subscribe to Team A private channel,
- receive Team A message payload,
- infer Team A message activity through unauthorized private channel access.

Realtime authorization must reuse FICI Team/Chat permissions.

Do not create a parallel realtime permission model.

---

# 22. Audit Events

M5 introduces initial `audit_events` if not already created.

Conceptual fields:

- `id`
- `actor_user_id`
- `event_type`
- `entity_type`
- `entity_id`
- `scope_type`
- `scope_id`
- `metadata`
- `created_at`

Required M5 event types include at least:

```text
TEAM_CREATED
MEMBER_ADDED
MEMBER_REMOVED
```

Also add clearly required M5 events for:

- member moved,
- team archived,
- Team Lead changed,

if consistent with the audit design.

Do not put sensitive Chat content into audit metadata.

---

# 23. Minimal Notification Dependency

The API/acceptance documents require notifications when members are added/removed/moved.

Full notification UX belongs to a later milestone.

M5 may therefore implement only the **minimum persistence/event foundation** necessary to satisfy the approved Team side effect, if it does not already exist.

Do not build:

- notification center UI,
- email notification system,
- complex preference settings.

If the repository intentionally defers notification persistence to M15, report the corresponding Team acceptance sub-step as blocked/deferred rather than silently omitting it.

---

# 24. Source-of-Truth Files

Before each M5 task, Codex must read the relevant approved files:

```text
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
/docs/18_CODEX_M4_PROMPTS.md
```

---

# 25. Global Codex Header

Use at the beginning of every M5 task if project rules are not automatically retained:

```text
You are implementing the FICI Invention Education & Development Platform.

Before making changes:

1. Read the relevant /docs files listed in this task.
2. Treat /docs as source of truth.
3. Do not invent missing business rules.
4. Preserve Role + Scope + Resource authorization.
5. Preserve Personal Workspace privacy.
6. Team Workspaces and Team Chats are private by default.
7. Never trust client-provided identity, role, Team membership, Master scope, or Chat membership.
8. Enforce security server-side and with PostgreSQL RLS.
9. Realtime authorization must follow the same canonical Team permissions.
10. PostgreSQL is canonical Chat storage.
11. Member removal revokes future access but never erases historical attribution.
12. Use transactions for multi-record Team membership operations.
13. Use migrations for schema changes.
14. Use strict TypeScript.
15. Validate runtime input.
16. Do not implement M6+ product features.
17. If requirements conflict or are ambiguous, STOP → FLAG → ASK.
18. Run required validation before finishing.
19. Report:
    - files changed,
    - migrations,
    - operations,
    - RLS policies,
    - realtime approach,
    - audit events,
    - tests,
    - results,
    - assumptions,
    - deferred behavior,
    - unresolved issues.
```

---

# 26. M5.1 — Team Schema

## Objective

Create the official Team entity linked to a Cohort.

## Copy/Paste Prompt

```text
TASK ID: M5.1
TASK: Team Schema

Read first:

- /docs/03_ROLES_PERMISSIONS.md
- /docs/04_WORKSPACE_TEAM_COLLABORATION.md
- /docs/08_DATA_MODEL_SCHEMA.md
- /docs/17_CODEX_M3_PROMPTS.md
- /docs/18_CODEX_M4_PROMPTS.md

OBJECTIVE

Create the official Team schema only.

IN SCOPE

1. Create `teams`.

Required conceptual fields:
- id
- cohort_id
- name
- description
- status
- team_lead_user_id nullable
- master_user_id
- workspace_id
- created_by
- archived_at

2. Add foreign keys to:
- cohort,
- user/profile for team_lead_user_id,
- user/profile for master_user_id,
- Team Workspace.

3. Team Workspace relation must require workspace_type = TEAM through application/database validation where practical.

4. Team Master must be valid for the Team's cohort according to M2/M3 scope rules.

5. Add statuses needed for approved Team lifecycle:
- Created
- Active
- Completed
- Archived
or equivalent repository-normalized values.

Do not invent additional business states without source support.

6. Add useful uniqueness/indexes:
- cohort lookup,
- Master lookup,
- Workspace link,
- active Team name uniqueness only if approved/appropriate.

7. Add tests:
- Team belongs to Cohort,
- Team Workspace link valid,
- invalid/unrelated Master rejected,
- Student cannot create Team through direct client mutation,
- archived Team history remains.

OUT OF SCOPE

- Project link implementation,
- Team Membership,
- Chat,
- Team UI.

VALIDATION

Run:
pnpm lint
pnpm typecheck
pnpm test:unit
pnpm test:integration
pnpm build

DEFINITION OF DONE

Official Team records can exist securely inside a Cohort without implementing collaboration yet.

FINAL REPORT

Return:
1. Schema
2. Constraints
3. RLS foundation
4. Files/migrations
5. Tests/results
6. Assumptions
7. Unresolved issues
```

---

# 27. M5.2 — Team Membership Schema

## Objective

Create membership history that supports add/remove/move without destructive deletion.

## Copy/Paste Prompt

```text
TASK ID: M5.2
TASK: Team Membership Schema

Read first:

- /docs/03_ROLES_PERMISSIONS.md
- /docs/04_WORKSPACE_TEAM_COLLABORATION.md
- /docs/08_DATA_MODEL_SCHEMA.md
- /docs/12_ACCEPTANCE_TESTS.md

OBJECTIVE

Implement Team Membership as historical, scoped access data.

IN SCOPE

1. Create `team_memberships`.

Fields:
- id
- team_id
- user_id
- membership_role
- joined_at
- left_at
- status
- added_by
- removed_by nullable

2. Support membership roles:
- member
- team_lead
- mentor

3. Preserve historical membership after removal.

4. Prevent duplicate active membership for same user/team.

5. Model active membership so access checks can reliably resolve:
- active,
- removed/left,
- time validity if used.

6. Do not delete membership row on removal.

7. Add indexes for:
- team membership lookup,
- user active Teams,
- authorization checks.

8. Add tests:
- active membership created,
- duplicate active membership rejected,
- removed membership preserved,
- removed membership not treated as active,
- role values constrained,
- Student cannot self-insert official Team membership via direct client access.

OUT OF SCOPE

- Project membership,
- invitation acceptance policy unless explicitly approved.

VALIDATION

Run:
pnpm lint
pnpm typecheck
pnpm test:unit
pnpm test:integration
pnpm build

DEFINITION OF DONE

Team Membership can reliably grant and revoke future Team scope while preserving history.

FINAL REPORT

Return:
1. Schema
2. Lifecycle
3. Constraints
4. RLS
5. Tests/results
6. Assumptions
7. Unresolved issues
```

---

# 28. M5.3 — Chat Schema

## Objective

Create canonical private Team Chat storage.

## Copy/Paste Prompt

```text
TASK ID: M5.3
TASK: Team Chat Schema

Read first:

- /docs/04_WORKSPACE_TEAM_COLLABORATION.md
- /docs/08_DATA_MODEL_SCHEMA.md
- /docs/10_TECHNICAL_ARCHITECTURE.md
- /docs/12_ACCEPTANCE_TESTS.md

OBJECTIVE

Create canonical PostgreSQL Team Chat tables.

IN SCOPE

1. Create `chat_channels`.

Fields:
- id
- channel_type
- workspace_id
- team_id nullable
- cohort_id nullable
- name
- status
- created_at

2. Support defined channel types but implement TEAM as M5 priority.

3. Create `chat_memberships`.

Fields:
- id
- chat_channel_id
- user_id
- access_level
- joined_at
- left_at

4. Create `chat_messages`.

Fields:
- id
- chat_channel_id
- sender_user_id
- parent_message_id nullable
- content
- message_type
- created_at
- edited_at
- deleted_at

5. Support message types:
- TEXT
- FILE
- LINK
- SYSTEM

6. Implement TEXT fully.

7. For FILE:
- do not implement insecure ad hoc file upload,
- defer actual file attachment storage to the File milestone.

8. Add referential integrity:
- Team Chat → Team Workspace,
- Team Chat → Team,
- Team Chat → Cohort,
- Chat Membership → Chat Channel/User,
- Message → Channel/User,
- parent_message_id → message where valid.

9. Add indexes for ordered message loading and membership authorization.

10. Add tests:
- one Team Chat can be associated with Team,
- message persists,
- sender stored,
- timestamp stored,
- parent reference valid,
- invalid cross-channel parent reference rejected if applicable.

OUT OF SCOPE

- cohort chat product,
- Master-Team direct chat product,
- Activity chat product,
- file upload implementation,
- message search unless trivial,
- pins/mentions/reactions unless already required by existing schema.

VALIDATION

Run:
pnpm lint
pnpm typecheck
pnpm test:unit
pnpm test:integration
pnpm build

DEFINITION OF DONE

Team Chat has canonical persistent database storage ready for authorization/realtime.

FINAL REPORT

Return:
1. Schema
2. Indexes/constraints
3. Implemented message types
4. Deferred capabilities
5. Tests/results
6. Assumptions
7. Unresolved issues
```

---

# 29. M5.4 — Create Team Transaction

## Objective

Create Team + Team Workspace + Team Chat atomically.

## Copy/Paste Prompt

```text
TASK ID: M5.4
TASK: Create Team Transaction

Read first:

- /docs/03_ROLES_PERMISSIONS.md
- /docs/04_WORKSPACE_TEAM_COLLABORATION.md
- /docs/11_API_CONTRACTS.md
- /docs/12_ACCEPTANCE_TESTS.md
- /docs/18_CODEX_M4_PROMPTS.md

OBJECTIVE

Implement `createTeam(input)` as one authorized transaction.

INPUT

cohortId
name
description optional
projectId optional
teamLeadUserId optional

AUTHORIZATION

Allow:
- Admin
- Master assigned to target Cohort

Deny:
- Student
- Mentor by default
- unrelated Master

TRANSACTION

1. Validate target Cohort.
2. Validate actor scope.
3. Validate assigned Master.
4. Create Team Workspace:
   - type TEAM
   - cohort_id target Cohort
5. Create Team record linked to Workspace.
6. Backfill Workspace team_id if schema requires after Team ID exists.
7. Create TEAM Chat Channel linked to Team + Workspace.
8. Create Master Chat Membership only if final approved Master Chat policy permits it.
9. If teamLeadUserId supplied:
   - validate user/enrollment/eligibility,
   - create membership consistently,
   - do not grant member-management powers automatically.
10. Create TEAM_CREATED audit event.
11. Handle minimal notification side effects only where approved/available.
12. Return:
   Team ID
   Workspace ID
   Chat Channel ID

PROJECT ID

M6 owns Projects.
If projectId is supplied before M6:
- reject with a stable unsupported/dependency error or
- defer according to existing contract adapter,
but do not create Project schema in M5.

TRANSACTION SAFETY

If Workspace or Chat creation fails:
- Team creation must roll back.

TEST

- assigned Master creates Team C,
- Team record exists,
- Team Workspace exists,
- Team Chat exists,
- audit event exists,
- unrelated Master denied,
- Student denied,
- partial failure rolls back.

VALIDATION

Run:
pnpm lint
pnpm typecheck
pnpm test:unit
pnpm test:integration
pnpm test:e2e
pnpm build

DEFINITION OF DONE

AT-TEAM-001 core behavior passes transactionally.

FINAL REPORT

Return:
1. Transaction steps
2. Authorization
3. Files changed
4. Audit behavior
5. Project-link handling
6. Tests/results
7. Assumptions
8. Unresolved issues
```

---

# 30. M5.5 — Add Team Member

## Objective

Grant Team Workspace and Chat access through an explicit active Team Membership.

## Copy/Paste Prompt

```text
TASK ID: M5.5
TASK: Add Team Member

Read first:

- /docs/03_ROLES_PERMISSIONS.md
- /docs/04_WORKSPACE_TEAM_COLLABORATION.md
- /docs/11_API_CONTRACTS.md
- /docs/12_ACCEPTANCE_TESTS.md

OBJECTIVE

Implement `addTeamMember(input)` transactionally.

INPUT

teamId
userId
membershipRole = member | team_lead | mentor

AUTHORIZATION

Allow:
- Admin in valid scope
- Master assigned to Team/Cohort

Deny:
- Student
- Team Lead by default
- Mentor by default
- unrelated Master

RULES

1. Team exists and is active/eligible for membership changes.
2. User exists.
3. User is eligible for target Cohort.
4. Duplicate active Team Membership forbidden.
5. Program multiple-Team rule must not be invented if unresolved.
6. Membership role must be valid.

TRANSACTION

1. Create active Team Membership.
2. Create/activate Team Chat Membership.
3. Ensure Team Workspace access resolves immediately.
4. If role = team_lead:
   synchronize Team's team_lead_user_id safely.
5. Create MEMBER_ADDED audit event.
6. Create minimal notification record/event if required by the approved acceptance contract.

IMPORTANT

Adding a user to Team does NOT grant access to:
- another member's Personal Workspace,
- restricted historical Personal content,
- other Teams.

TEST

- Master adds Student A1,
- membership active,
- Team Workspace accessible,
- Team Chat accessible,
- duplicate add rejected,
- Student cannot self-add,
- unrelated Master denied,
- audit exists,
- notification side effect handled according to approved M5 approach.

VALIDATION

Run full relevant tests.

DEFINITION OF DONE

AT-TEAM-002 passes or any notification-only deferred sub-step is explicitly reported if notification infrastructure is formally deferred.

FINAL REPORT

Return:
1. Transaction
2. Access effects
3. Audit/notification effects
4. Tests/results
5. Assumptions
6. Unresolved issues
```

---

# 31. M5.6 — Remove Team Member

## Objective

Revoke all future Team/Chat access without erasing historical membership or messages.

## Copy/Paste Prompt

```text
TASK ID: M5.6
TASK: Remove Team Member

Read first:

- /docs/03_ROLES_PERMISSIONS.md
- /docs/04_WORKSPACE_TEAM_COLLABORATION.md
- /docs/11_API_CONTRACTS.md
- /docs/12_ACCEPTANCE_TESTS.md

OBJECTIVE

Implement `removeTeamMember(input)` safely and transactionally.

INPUT

teamId
userId
reason optional

AUTHORIZATION

Allow:
- Admin
- assigned Master

Deny:
- Student
- Team Lead by default
- Mentor by default
- unrelated Master

TRANSACTION

1. Resolve active Team Membership.
2. Close membership:
   - set inactive/removed status,
   - set left_at,
   - set removed_by.
3. Close/revoke Chat Membership.
4. Ensure Team Workspace authorization fails immediately after transaction.
5. Ensure Chat read/post authorization fails immediately.
6. Preserve:
   - Team Membership row,
   - authored Chat messages,
   - sender identity,
   - historical attribution.
7. Do not delete Personal Workspace.
8. Create MEMBER_REMOVED audit event.
9. Create minimal notification event/record if approved/available.

TEAM LEAD EDGE CASE

If removed user is current Team Lead:
- do not silently assign a new Team Lead.
- clear or update Team Lead only according to approved rule.
- if unresolved, STOP → FLAG → ASK.

TEST

- remove Student A1,
- future Workspace denied,
- Chat denied,
- prior message remains,
- historical membership remains,
- audit exists,
- direct ID access denied.

VALIDATION

Run full Team/RLS/Chat tests.

DEFINITION OF DONE

AT-TEAM-003 and Team-level portion of AT-TEAM-004 pass.

FINAL REPORT

Return:
1. Removal behavior
2. Preserved history
3. Revoked access
4. Team Lead edge handling
5. Tests/results
6. Assumptions
7. Unresolved issues
```

---

# 32. M5.7 — Move Team Member

## Objective

Move a member between Teams without leaking source-Team data.

## Copy/Paste Prompt

```text
TASK ID: M5.7
TASK: Move Team Member

Read first:

- /docs/03_ROLES_PERMISSIONS.md
- /docs/04_WORKSPACE_TEAM_COLLABORATION.md
- /docs/11_API_CONTRACTS.md
- /docs/12_ACCEPTANCE_TESTS.md

OBJECTIVE

Implement `moveTeamMember(input)` as one transaction.

INPUT

userId
fromTeamId
toTeamId
reason optional

AUTHORIZATION

Admin / assigned Master with authority over both required Team scopes.

RULES

1. Source active membership must exist.
2. Target Team must exist.
3. User must be eligible for target Cohort.
4. If moving across Cohorts is not explicitly approved, reject.
5. Do not copy source-Team content.

TRANSACTION

1. Close source Team Membership.
2. Close source Chat Membership.
3. Create target Team Membership.
4. Create target Chat Membership.
5. Preserve source historical membership.
6. Preserve source messages/contributions.
7. Create appropriate audit events.
8. Notification event/record if approved/available.

POSTCONDITION

User:
- cannot access source Team Workspace,
- cannot access source Team Chat,
- can access target Team Workspace,
- can access target Team Chat.

No Team A private record becomes visible in Team B merely because the member moved.

TEST

Implement AT-TEAM-005.

VALIDATION

Run full integration/RLS/E2E suite.

DEFINITION OF DONE

AT-TEAM-005 passes with no cross-Team information transfer.

FINAL REPORT

Return:
1. Transaction
2. Scope validation
3. Access before/after
4. Audit events
5. Tests/results
6. Assumptions
7. Unresolved issues
```

---

# 33. M5.8 — Team Lead Operation

## Objective

Support Team Lead assignment without administrative privilege escalation.

## Copy/Paste Prompt

```text
TASK ID: M5.8
TASK: Team Lead Assignment

Read first:

- /docs/03_ROLES_PERMISSIONS.md
- /docs/04_WORKSPACE_TEAM_COLLABORATION.md
- /docs/11_API_CONTRACTS.md

OBJECTIVE

Implement `assignTeamLead(input)` without turning Team Lead into Admin/Master.

IN SCOPE

1. Validate target user has active Team Membership.
2. Update:
   - team_lead_user_id
   - membership_role where required for consistency.
3. Preserve only approved Team Lead capabilities.
4. Team Lead must NOT automatically:
   - add members,
   - remove members,
   - change platform roles,
   - change Master,
   - access other Teams,
   - override instructor approvals.
5. Add audit event.
6. Add tests for privilege boundaries.

OUT OF SCOPE

- activity launch permissions not yet implemented,
- artifact sharing permissions not yet implemented.

VALIDATION

Run:
pnpm lint
pnpm typecheck
pnpm test:unit
pnpm test:integration
pnpm build

DEFINITION OF DONE

Team Lead identity is represented consistently without authorization escalation.

FINAL REPORT

Return:
1. Operation
2. Capability boundaries
3. Tests/results
4. Assumptions
5. Unresolved issues
```

---

# 34. M5.9 — Team Chat Send / Load Operations

## Objective

Implement persistent private Team Chat.

## Suggested Operations

Exact names may vary:

```text
sendTeamChatMessage()
listTeamChatMessages()
getTeamChatChannel()
```

## Copy/Paste Prompt

```text
TASK ID: M5.9
TASK: Team Chat Operations

Read first:

- /docs/03_ROLES_PERMISSIONS.md
- /docs/04_WORKSPACE_TEAM_COLLABORATION.md
- /docs/10_TECHNICAL_ARCHITECTURE.md
- /docs/11_API_CONTRACTS.md
- /docs/12_ACCEPTANCE_TESTS.md

OBJECTIVE

Implement canonical Team Chat read/write operations.

SEND MESSAGE

1. Resolve authenticated user from server session.
2. Resolve Team Chat.
3. Verify active Chat/Team access.
4. Validate message content.
5. Insert canonical message in PostgreSQL.
6. Store sender and timestamp.
7. Publish authorized realtime event after successful persistence.
8. Return saved message.

LOAD MESSAGES

1. Verify active Chat/Team access.
2. Query canonical PostgreSQL messages.
3. Order deterministically.
4. Support reasonable pagination.
5. Do not expose deleted/edited behavior beyond approved policy.

THREADS

parent_message_id may be supported as the schema allows.
Do not build advanced thread UI unless necessary.

MESSAGE EDIT/DELETE

The API docs identify this as an open question.
If no approved policy exists:
- do not implement user editing/deletion behavior,
- preserve fields for future support,
- STOP/FLAG if implementation requires a decision.

TEST

- active Team member sends,
- message persists,
- refresh loads same message,
- Team B cannot list Team A messages,
- direct message ID access denied,
- removed member cannot send,
- removed member cannot list,
- sender spoofing ignored/denied.

VALIDATION

Run full Chat tests.

DEFINITION OF DONE

AT-CHAT-001, AT-CHAT-003, and AT-CHAT-004 pass.

FINAL REPORT

Return:
1. Operations
2. Persistence behavior
3. Authorization
4. Pagination/thread support
5. Edit/delete policy status
6. Tests/results
7. Assumptions
8. Unresolved issues
```

---

# 35. M5.10 — Team Chat Realtime

## Objective

Deliver realtime notification without making Realtime the source of truth.

## Copy/Paste Prompt

```text
TASK ID: M5.10
TASK: Team Chat Realtime

Read first:

- /docs/04_WORKSPACE_TEAM_COLLABORATION.md
- /docs/10_TECHNICAL_ARCHITECTURE.md
- /docs/12_ACCEPTANCE_TESTS.md

OBJECTIVE

Add private Team Chat realtime updates using Supabase Realtime/Broadcast.

ARCHITECTURE

PostgreSQL = canonical message
Realtime = authorized notification

FLOW

1. Authorized send persists message.
2. Realtime event emitted.
3. Only authorized channel members may subscribe/receive.
4. Client reconciles with canonical message ID/data.

SECURITY

- private channels,
- server-authorized access,
- no Team B subscription to Team A,
- removed member loses realtime access,
- unrelated Master/Mentor denied,
- do not trust room/channel name alone.

PRESENCE

If basic presence is added:
- do not implement hidden Master presence.
- any instructor presence must comply with approved policy.

TEST

1. Team A users receive Team A message update.
2. Team B does not receive it.
3. Removed A1 cannot subscribe after removal.
4. Reconnect loads canonical stored messages.
5. Duplicate realtime event does not duplicate canonical database message.

VALIDATION

Run realtime/integration/E2E tests.

DEFINITION OF DONE

Realtime improves responsiveness without creating a second source of truth or bypassing authorization.

FINAL REPORT

Return:
1. Realtime architecture
2. Channel authorization
3. Reconnect behavior
4. Tests/results
5. Assumptions
6. Unresolved issues
```

---

# 36. M5.11 — Team & Chat RLS

## Objective

Enforce Team, Team Workspace, Team Membership, Chat Channel, Chat Membership, and Chat Message isolation at the database layer.

## Core Authorization Inputs

Use:

- authenticated user,
- active Team Membership,
- scoped Master assignment according to approved policy,
- scoped Mentor assignment according to approved policy,
- Team/Cohort relation,
- Workspace relation.

Role alone is insufficient.

## Copy/Paste Prompt

```text
TASK ID: M5.11
TASK: Team & Chat RLS

Read first:

- /docs/03_ROLES_PERMISSIONS.md
- /docs/04_WORKSPACE_TEAM_COLLABORATION.md
- /docs/08_DATA_MODEL_SCHEMA.md
- /docs/10_TECHNICAL_ARCHITECTURE.md
- /docs/12_ACCEPTANCE_TESTS.md
- /docs/16_CODEX_M2_PROMPTS.md
- /docs/18_CODEX_M4_PROMPTS.md

OBJECTIVE

Implement direct database isolation for Team and Team Chat resources.

TABLES

Review/protect:
- teams
- team_memberships
- workspaces (TEAM extension)
- chat_channels
- chat_memberships
- chat_messages
- audit_events where client access exists

RULES

ACTIVE TEAM MEMBER:
- can read own Team metadata as needed,
- can access own Team Workspace,
- can read/post own Team Chat.

OTHER TEAM:
- cannot access private Team Workspace,
- cannot read Team metadata beyond any explicitly public/non-sensitive fields,
- cannot read Chat,
- cannot subscribe realtime.

REMOVED MEMBER:
- no future Team Workspace access,
- no future Chat read/post access.

MASTER:
- only assigned scope and only according to approved Chat policy.

MENTOR:
- explicit assignment + enabled access only.

STUDENT:
- cannot mutate official Team membership.

MUTATION SECURITY

Do not allow direct client:
- self-add to Team,
- remove others,
- change Team Lead,
- change Team Master,
- reactivate removed membership,
- insert Chat Membership,
- spoof message sender.

DIRECT TESTS

As Team B:
- SELECT Team A Workspace = denied/no rows
- SELECT Team A Chat Channel = denied/no rows
- SELECT Team A Chat Messages = denied/no rows
- INSERT Team A Chat Message = denied
- subscribe/read realtime = denied

As removed A1:
- Team Workspace = denied
- Team Chat = denied
- send = denied

VALIDATION

Run dedicated RLS/security suite.

DEFINITION OF DONE

Cross-Team access is blocked at the database boundary even when exact IDs are known.

FINAL REPORT

Return:
1. RLS policies
2. Helper functions
3. Direct attack tests
4. Files/migrations
5. Results
6. Assumptions
7. Unresolved issues
```

---

# 37. M5.12 — Audit & Minimal Notification Foundation

## Objective

Satisfy M5-required history/side effects without implementing the later full notification product.

## Copy/Paste Prompt

```text
TASK ID: M5.12
TASK: M5 Audit & Notification Foundation

Read first:

- /docs/08_DATA_MODEL_SCHEMA.md
- /docs/11_API_CONTRACTS.md
- /docs/12_ACCEPTANCE_TESTS.md
- /docs/13_CODEX_IMPLEMENTATION_PLAN.md

OBJECTIVE

Implement only the audit and minimal notification persistence required by M5.

AUDIT

Ensure `audit_events` can record:
- TEAM_CREATED
- MEMBER_ADDED
- MEMBER_REMOVED
- MEMBER_MOVED if used
- TEAM_LEAD_CHANGED if used
- TEAM_ARCHIVED if used

Each event should capture:
- actor,
- entity,
- scope,
- timestamp,
- non-sensitive metadata.

NOTIFICATION

The Team acceptance/API specs expect a notification when members are added/removed/moved.

If notifications table already exists:
- create the minimum relevant rows.

If it does not exist and M15 owns the full notification system:
- add only the smallest schema/service foundation needed to satisfy these M5 events,
- do not build notification center UI,
- do not build email delivery.

If project architecture explicitly forbids early notification schema:
- report the exact AT-TEAM side effect as DEFERRED rather than pretending it passed.

SECURITY

Users may not forge administrative audit events.
Audit rows should not expose private Team data to unrelated users.

VALIDATION

Run relevant tests.

DEFINITION OF DONE

Team lifecycle actions have durable audit history and approved notification side effects are either implemented minimally or explicitly documented as formally deferred.

FINAL REPORT

Return:
1. Audit events
2. Notification approach
3. Deferred features
4. Tests/results
5. Assumptions
6. Unresolved issues
```

---

# 38. M5.13 — Team Archiving

## Objective

Archive Team without erasing Team/Chat history.

## Copy/Paste Prompt

```text
TASK ID: M5.13
TASK: Archive Team

Read first:

- /docs/04_WORKSPACE_TEAM_COLLABORATION.md
- /docs/08_DATA_MODEL_SCHEMA.md
- /docs/11_API_CONTRACTS.md

OBJECTIVE

Implement `archiveTeam(teamId)`.

AUTHORIZATION

Admin / assigned Master.

BEHAVIOR

1. Mark Team archived.
2. Preserve Team row.
3. Preserve Team Membership history.
4. Preserve Team Workspace.
5. Preserve Chat Channel/Messages.
6. Prevent ordinary new Team activity.
7. Make Team Workspace read-only where appropriate.
8. Create audit event.

Do not:
- hard-delete messages,
- hard-delete memberships,
- erase authorship.

RESTORE

If Team restoration behavior is not approved:
do not invent it.
STOP → FLAG → ASK if a restore operation is required.

TEST

- archived Team cannot accept normal new message/member mutation,
- history remains queryable by authorized historical/administrative scope according to policy,
- unrelated users remain denied.

VALIDATION

Run relevant tests.

DEFINITION OF DONE

Archive changes lifecycle state without destroying history.

FINAL REPORT

Return:
1. Archive semantics
2. Access changes
3. Preserved records
4. Tests/results
5. Assumptions
6. Unresolved issues
```

---

# 39. M5.14 — Team Management Acceptance Tests

## Objective

Implement all approved Team management acceptance tests.

## Required Tests

### AT-TEAM-001 — Master Creates Team

Expected:

- Team record,
- Team Workspace,
- Team Chat Channel,
- audit event.

Priority:

```text
MUST PASS
```

### AT-TEAM-002 — Add Member

Expected:

- active membership,
- Team Workspace accessible,
- Team Chat accessible,
- notification side effect.

Priority:

```text
MUST PASS
```

### AT-TEAM-003 — Remove Member

Expected:

- future Team access denied,
- Chat denied,
- previous authorship remains,
- prior messages remain,
- prior votes remain when voting later exists,
- audit exists.

M5 can test currently existing history types and must architecturally preserve future vote history.

Priority:

```text
BLOCKER
```

### AT-TEAM-004 — Removed Member Direct ID Access

After removal, direct Team-resource access must be denied.

M5 can test:

- Team,
- Team Workspace,
- Chat Channel,
- Chat Message.

Artifact-specific direct ID test will be extended when Artifacts exist.

Priority:

```text
BLOCKER
```

### AT-TEAM-005 — Move Between Teams

Expected:

- source future access ends,
- source history remains,
- target access begins,
- source private content not copied.

Priority:

```text
BLOCKER
```

## Copy/Paste Prompt

```text
TASK ID: M5.14
TASK: Team Management Acceptance Tests

Read first:

- /docs/12_ACCEPTANCE_TESTS.md
- /docs/19_CODEX_M5_PROMPTS.md

OBJECTIVE

Implement AT-TEAM-001 through AT-TEAM-005 at the maximum scope supported by M5.

FIXTURES

Use:
- Admin
- Master
- Student A1
- Student A2
- Student B1
- Student B2
- Team A
- Team B
- Team C
- Professional Course Test Cohort

TEST

AT-TEAM-001
AT-TEAM-002
AT-TEAM-003
AT-TEAM-004
AT-TEAM-005

For later entity types not yet present:
- do not fabricate them,
- mark only that sub-check as deferred,
- verify the generic historical-preservation model now.

RUN

pnpm lint
pnpm typecheck
pnpm test:unit
pnpm test:integration
pnpm test:e2e
pnpm build
plus all Supabase/RLS tests.

DEFINITION OF DONE

All M5-applicable Team tests pass and every BLOCKER access rule is enforced now.

FINAL REPORT

Return:
1. Test matrix
2. PASS/FAIL/DEFERRED by sub-check
3. Direct-ID attack results
4. Files changed
5. Commands/results
6. Remaining issues
```

---

# 40. M5.15 — Team Chat Acceptance Tests

## Objective

Implement the complete M5 Chat acceptance suite.

## Required Tests

### AT-CHAT-001 — Send Message

- persists in database,
- authorized Team users receive realtime update,
- sender stored,
- timestamp stored.

### AT-CHAT-002 — Team B Cannot Read Team A Chat

Test:

- list endpoint,
- direct message ID,
- direct database query,
- realtime subscription.

All denied.

Priority:

```text
BLOCKER
```

### AT-CHAT-003 — Removed Member Cannot Send

Result:

```text
FORBIDDEN
```

Priority:

```text
BLOCKER
```

### AT-CHAT-004 — Message Persists After Refresh

Must reload from canonical PostgreSQL data.

## Copy/Paste Prompt

```text
TASK ID: M5.15
TASK: Team Chat Acceptance Tests

Read first:

- /docs/12_ACCEPTANCE_TESTS.md
- /docs/10_TECHNICAL_ARCHITECTURE.md
- /docs/19_CODEX_M5_PROMPTS.md

OBJECTIVE

Implement AT-CHAT-001 through AT-CHAT-004.

FIXTURES

Team A:
- A1
- A2

Team B:
- B1
- B2

TEST PATHS

1. authorized API/service send
2. canonical DB persistence
3. realtime delivery
4. refresh/reconnect loading
5. cross-Team list request
6. direct message ID
7. direct DB query under user auth
8. realtime unauthorized subscription
9. removed-member post
10. sender spoofing

MANDATORY

AT-CHAT-001 PASS
AT-CHAT-002 PASS
AT-CHAT-003 PASS
AT-CHAT-004 PASS

RUN

full lint/type/unit/integration/e2e/build/RLS/realtime suite.

FINAL REPORT

Return:
1. Test matrix
2. Results
3. Realtime authorization results
4. Persistence results
5. Files changed
6. Remaining issues
```

---

# 41. M5.16 — Cross-Team Leakage Security Test

## Objective

Attack the Team boundary directly before M6 adds Project data.

## Copy/Paste Prompt

```text
TASK ID: M5.16
TASK: Cross-Team Leakage Security Test

Read first:

- /docs/03_ROLES_PERMISSIONS.md
- /docs/04_WORKSPACE_TEAM_COLLABORATION.md
- /docs/12_ACCEPTANCE_TESTS.md

OBJECTIVE

Attempt all currently possible routes from Team B to Team A private M5 resources.

AS STUDENT B1 TRY

- Team A Workspace by ID
- Team A record by ID
- Team A Membership list
- Team A Chat Channel
- Team A Chat message list
- exact Team A message ID
- direct DB SELECT
- direct DB INSERT
- realtime subscribe
- forged teamId in API
- forged chatChannelId
- forged userId
- forged membershipRole

EXPECTED

No unauthorized Team A private content is returned.
No unauthorized Team A mutation succeeds.

Also test:
- unrelated Master,
- unrelated Mentor,
- removed former member.

DEFINITION OF DONE

No known M5 cross-Team leakage remains.

FINAL REPORT

Return:
1. Attack matrix
2. Results
3. Any leakage found
4. Fixes
5. Remaining issues
```

---

# 42. M5.17 — Member Removal Security Scenario

## Objective

Implement the M5-relevant foundation of the end-to-end member-removal release scenario.

Approved later full scenario includes:

```text
A1 contributes Idea, Vote, Message, Artifact edit
Master removes A1
A1 loses future Team A access
Team A retains historical contributions
A1 cannot access via API/direct IDs/chat/AI
Audit records removal
A1 Personal Workspace remains intact
```

M5 currently owns:

- Team Membership,
- Chat Message,
- Team Workspace,
- audit,
- Personal Workspace preservation.

Ideas/Votes/Artifacts/AI belong later.

## Copy/Paste Prompt

```text
TASK ID: M5.17
TASK: Member Removal Security Scenario

Read first:

- /docs/12_ACCEPTANCE_TESTS.md
- /docs/19_CODEX_M5_PROMPTS.md

OBJECTIVE

Implement the M5 portion of AT-E2E-MEMBER-001.

SCENARIO

1. A1 is active in Team A.
2. A1 sends Team Chat message.
3. Verify A1 can access Team A Workspace/Chat.
4. Master removes A1.
5. Verify A1:
   - cannot read Team A Workspace,
   - cannot read Team A Chat,
   - cannot post Team A Chat,
   - cannot subscribe Team A realtime,
   - cannot reactivate own membership.
6. Verify:
   - A1 Chat message remains,
   - sender attribution remains,
   - Team Membership history remains,
   - audit removal exists,
   - A1 Personal Workspace remains accessible to A1 and unaffected.

Record future Idea/Vote/Artifact/AI checks as deferred to their owning milestones.

DEFINITION OF DONE

The M5 access revocation model is proven suitable for later project/content entities.

FINAL REPORT

Return:
1. Scenario result
2. Preserved history
3. Revoked routes
4. Deferred later-entity checks
5. Commands/results
```

---

# 43. M5.18 — M5 Security Hardening

## Objective

Perform final Team/Chat privacy review before Development Projects are introduced.

## Required Negative Tests

Attempt:

```text
Student → create official Team
Student → add self to Team
Student → add another member
Student → remove member
Team Lead → remove member
Mentor → create Team
Unrelated Master → manage Team
Team B → read Team A Workspace
Team B → read Team A Chat
Team B → realtime subscribe to Team A
Removed member → read Team A Chat
Removed member → send Team A message
Removed member → query Team A Workspace
Client → spoof sender_user_id
Client → spoof membership role
Client → spoof Master role
Client → direct database insert membership
Client → direct database insert chat membership
Client → change team_lead_user_id without authorization
```

All unauthorized actions must fail.

## Copy/Paste Prompt

```text
TASK ID: M5.18
TASK: M5 Security Hardening

Read first:

- /docs/03_ROLES_PERMISSIONS.md
- /docs/04_WORKSPACE_TEAM_COLLABORATION.md
- /docs/08_DATA_MODEL_SCHEMA.md
- /docs/10_TECHNICAL_ARCHITECTURE.md
- /docs/11_API_CONTRACTS.md
- /docs/12_ACCEPTANCE_TESTS.md
- /docs/16_CODEX_M2_PROMPTS.md
- /docs/18_CODEX_M4_PROMPTS.md
- /docs/19_CODEX_M5_PROMPTS.md

OBJECTIVE

Perform security hardening of M5 only.

VERIFY

1. Official Team creation restricted.
2. Membership mutation restricted.
3. Team Lead has no accidental Admin/Master power.
4. Team Workspace isolation enforced.
5. Team Chat isolation enforced.
6. Realtime channel isolation enforced.
7. Removed member access revoked immediately.
8. Historical membership/messages remain.
9. Audit rows cannot be forged by ordinary users.
10. Personal Workspace remains unaffected by Team membership changes.
11. No M6+ feature was implemented.

RUN

pnpm lint
pnpm typecheck
pnpm test:unit
pnpm test:integration
pnpm test:e2e
pnpm build
plus all configured RLS/realtime security tests.

DEFINITION OF DONE

- AT-TEAM-001 PASS
- AT-TEAM-002 PASS or notification-only dependency explicitly resolved
- AT-TEAM-003 PASS for M5 entities
- AT-TEAM-004 PASS for M5 entities
- AT-TEAM-005 PASS
- AT-CHAT-001 PASS
- AT-CHAT-002 PASS
- AT-CHAT-003 PASS
- AT-CHAT-004 PASS
- no known cross-Team leakage
- no known removed-member bypass
- no M6+ scope creep

FINAL REPORT

Return:
1. Security review
2. Issues found
3. Issues fixed
4. Remaining issues
5. BLOCKER status
6. Test results
7. Recommendation: READY FOR M6 or NOT READY FOR M6
```

---

# 44. Team Access Resolution

M5 extends the M4 Workspace access resolver.

Conceptually:

```text
can_access_team_workspace(user, team)
=
active Team membership
OR authorized assigned Master
OR explicitly assigned Mentor if policy enables
OR authorized Admin policy path
```

But every path remains scoped.

Do not use:

```text
role = MASTER → all Teams
```

or:

```text
same Cohort → all private Team Chat
```

unless a specific approved instructional policy grants that exact access.

---

# 45. Team Membership vs Enrollment

Do not conflate:

```text
COHORT ENROLLMENT
```

with:

```text
TEAM MEMBERSHIP
```

Enrollment means the user participates in the Cohort.

Team Membership means the user belongs to one specific Team.

Therefore:

```text
enrolled in Cohort
≠
can access every Team in Cohort
```

This separation is security-critical.

---

# 46. Team Membership vs Project Membership

Do not conflate:

```text
TEAM MEMBERSHIP
```

with:

```text
PROJECT MEMBERSHIP
```

M6 introduces Project Membership.

A future Team may be linked to a Development Project, but these remain distinct records.

M5 must not create Project Membership implicitly.

---

# 47. Chat Membership vs Team Membership

Team Membership is the main product relationship.

Chat Membership is the Chat access record.

They must remain synchronized.

For normal Team members:

```text
active Team Membership
→ active Team Chat access
```

Removal:

```text
Team Membership closes
→ Chat Membership closes
```

Do not let stale Chat Membership survive as a privacy bypass.

---

# 48. Team Lead Consistency

If `teams.team_lead_user_id` is set:

- that user must have active Team Membership,
- Team membership role should remain consistent,
- removing the Team Lead must not leave a dangling Team Lead reference.

If replacement behavior is not approved:

- clear Team Lead safely,
- do not auto-appoint another member.

---

# 49. Team Master Consistency

`teams.master_user_id` should correspond to an authorized MASTER in the Team's Cohort scope.

Changing Master must not be a generic Team edit.

If reassignment is needed, use an explicit authorized operation and keep scope roles synchronized.

Do not allow Team member to change `master_user_id`.

---

# 50. Chat Message Sender Integrity

`sender_user_id` must come from authenticated server identity.

Never trust:

```text
senderUserId
```

from browser input.

A client must not be able to post a message as another student or Master.

---

# 51. Chat Edit/Delete — Deferred Decision

The API specification identifies Chat message editing/deletion as unresolved.

Therefore:

- keep `edited_at`,
- keep `deleted_at`,
- do not implement end-user edit/delete behavior until approved.

System moderation behavior, if later required, must be separately authorized and audited.

---

# 52. Chat Files — Deferred

The collaboration specification lists image/file sharing as desired MVP Chat capability.

However secure File Storage has its own later architecture/tests.

M5 should not introduce insecure file links.

Until File subsystem exists:

```text
TEXT = implemented
LINK = may be implemented safely
FILE = schema-supported but upload flow deferred
```

If the current implementation plan expects file attachment in M5, STOP and reconcile with the File milestone before coding.

---

# 53. Chat Mentions / Pins / Search

The collaboration specification lists:

- replies/threads,
- mentions,
- links,
- image sharing,
- file sharing,
- timestamps,
- author identity,
- pinned messages,
- message search if practical.

The Data Model only explicitly defines core message/thread fields.

Therefore M5 priority is:

```text
persistent text chat
private access
realtime delivery
reply/thread foundation
```

Do not expand into a Slack clone.

Mentions, pins, search, rich uploads may be deferred unless already represented in approved schema.

---

# 54. Archive vs Delete

Use archive/state transitions for Teams.

Do not hard-delete:

- Team,
- Team Workspace,
- Team Chat,
- Membership history,
- Chat history associated with formal project activity.

Historical attribution is a platform requirement.

---

# 55. Audit vs Change Log

M5 uses `audit_events` for administrative/security history.

Do not confuse it with later Project `change_log`.

Examples:

```text
MEMBER_REMOVED
→ audit event
```

Later:

```text
approved invention version changed
→ project change log
```

---

# 56. Transaction Requirements

The following must be transactional:

- create Team,
- add Team member,
- remove Team member,
- move Team member,
- assign Team Lead where multiple records change,
- archive Team where related access states change.

Failure must not leave partial security state.

Example unacceptable state:

```text
membership removed
BUT
chat_membership still active
```

---

# 57. Idempotency

Retry-prone operations should be safely repeatable where practical.

Examples:

- create Team request with idempotency key,
- add member,
- remove member,
- move member.

Do not allow duplicate memberships or duplicate Team creation from accidental retries if API infrastructure supports idempotency.

---

# 58. M5 Expected Repository Additions

Conceptually:

```text
features/
├── teams/
│   ├── operations/
│   ├── validation/
│   ├── membership/
│   └── access/
└── chat/
    ├── operations/
    ├── realtime/
    ├── access/
    └── types/

lib/
├── permissions/
│   ├── team.ts
│   └── chat.ts
├── realtime/
└── audit/

supabase/
├── migrations/
│   ├── ...teams...
│   ├── ...team_memberships...
│   ├── ...chat_channels...
│   ├── ...chat_memberships...
│   ├── ...chat_messages...
│   ├── ...audit_events...
│   └── ...team_chat_rls...
└── tests/
    └── rls/
        ├── teams...
        └── chat...

tests/
├── unit/
│   ├── teams/
│   └── chat/
├── integration/
│   ├── teams/
│   └── chat/
└── e2e/
    ├── teams.spec.ts
    └── team-chat.spec.ts
```

Exact paths may vary.

---

# 59. M5 Completion Gate

M5 is complete only when:

```text
[ ] teams exists
[ ] team_memberships exists
[ ] historical memberships preserved

[ ] Team Workspace is provisioned with Team
[ ] one Team has one primary Team Workspace
[ ] Team B cannot access Team A Workspace

[ ] chat_channels exists
[ ] chat_memberships exists
[ ] chat_messages exists
[ ] Team Chat uses PostgreSQL canonical storage
[ ] Team Chat realtime works for authorized users

[ ] createTeam() implemented transactionally
[ ] addTeamMember() implemented transactionally
[ ] removeTeamMember() implemented transactionally
[ ] moveTeamMember() implemented transactionally
[ ] assignTeamLead() implemented safely
[ ] archiveTeam() implemented safely

[ ] Team Lead has no automatic member-management privilege
[ ] Team Membership and Chat Membership remain synchronized

[ ] removed member loses Team Workspace access
[ ] removed member loses Chat read access
[ ] removed member loses Chat post access
[ ] removed member cannot realtime subscribe
[ ] removed member historical membership remains
[ ] removed member messages remain

[ ] Team B cannot list Team A Chat
[ ] Team B cannot fetch Team A message by ID
[ ] Team B cannot query Team A Chat under user DB auth
[ ] Team B cannot realtime subscribe to Team A

[ ] sender identity cannot be spoofed
[ ] client cannot self-add membership
[ ] client cannot reactivate removed membership

[ ] TEAM_CREATED audit exists
[ ] MEMBER_ADDED audit exists
[ ] MEMBER_REMOVED audit exists

[ ] AT-TEAM-001 PASS
[ ] AT-TEAM-002 PASS or any formally deferred notification-only sub-check clearly documented
[ ] AT-TEAM-003 PASS for M5 entities
[ ] AT-TEAM-004 PASS for M5 entities
[ ] AT-TEAM-005 PASS

[ ] AT-CHAT-001 PASS
[ ] AT-CHAT-002 PASS
[ ] AT-CHAT-003 PASS
[ ] AT-CHAT-004 PASS

[ ] lint passes
[ ] typecheck passes
[ ] unit tests pass
[ ] integration tests pass
[ ] E2E tests pass
[ ] RLS tests pass
[ ] realtime tests pass
[ ] build passes

[ ] no M6+ feature implemented prematurely
[ ] Codex reports READY FOR M6
```

Any cross-Team privacy leak is:

```text
BLOCKER
```

Any removed-member access bypass is:

```text
BLOCKER
```

---

# 60. Recommended Commit Sequence

Example:

```text
feat(teams): add Team schema
feat(teams): add historical Team memberships
feat(chat): add Team Chat schema
feat(teams): add transactional Team creation
feat(teams): add member add/remove/move operations
feat(teams): add Team Lead assignment
feat(chat): add persistent Team Chat operations
feat(realtime): add private Team Chat broadcast
feat(security): add Team and Chat RLS
feat(audit): add Team lifecycle audit events
feat(teams): add archive behavior
test(teams): add Team acceptance suite
test(chat): add Chat acceptance suite
test(security): add cross-Team leakage tests
test(security): add member-removal scenario
chore(security): complete M5 hardening
```

---

# 61. M5 Non-Goals

Do not accept these as "helpful additions" during M5:

- Development Project schema,
- Project Membership,
- Problem/Idea/Solution objects,
- Activity Instances,
- SCAMPER tool,
- Brainstorming tool,
- Voting,
- Affinity,
- Mind Map,
- file repository,
- cross-Team artifact sharing,
- artifact system,
- versioning,
- evidence,
- patent search,
- AI,
- review/approval,
- Liveblocks,
- Daily video,
- full notification center,
- analytics dashboard,
- advanced moderation system.

---

# 62. Potential M5 Ambiguities Codex Must Flag

Do not silently decide if approved docs do not resolve:

- whether Master always has Team Chat read/post or only when invited,
- whether Admin can read Team Chat for support/security,
- exact Mentor Chat access mode,
- whether Team membership invitation requires acceptance,
- whether a Student may belong to multiple official Teams in one Cohort,
- whether a Team Lead can launch future internal activities,
- whether a Team Lead can submit Team work,
- whether Team Lead can share externally,
- what happens when current Team Lead is removed,
- whether Team may have multiple Team Leads,
- whether Team may have multiple Masters,
- whether Master reassignment automatically updates Chat Membership,
- exact Team status vocabulary,
- exact Chat access_level vocabulary,
- whether messages may be edited,
- whether messages may be deleted,
- retention period after Cohort ends,
- whether archived Team Chat is read-only or completely inaccessible to former members,
- exact notification implementation timing,
- whether projectId should be rejected or ignored before M6,
- whether cross-Cohort Team move is ever allowed.

If unresolved:

```text
STOP → FLAG → ASK
```

---

# 63. Recommended Safe Defaults for Purely Technical Decisions

Only where they do not change approved product policy:

- stable UUID Team/Chat IDs,
- one primary Team Workspace per Team,
- one primary TEAM Chat Channel per Team,
- duplicate active membership prohibited,
- removed memberships retained,
- sender identity derived server-side,
- canonical messages stored in PostgreSQL,
- private Realtime channels,
- RLS on all Team/Chat tables,
- no ordinary client membership mutations,
- archive rather than hard delete,
- deterministic test fixtures,
- no Project link until M6,
- no file upload in Chat until secure File subsystem exists.

---

# 64. Review Checklist for Ahmad/FICI

Before implementation, confirm that M5 reflects the intended Team model:

```text
1. Admin and assigned Master can create official Teams.

2. Students cannot create official course Teams by default.

3. Every Team gets a private Team Workspace.

4. Every Team gets a private Team Chat.

5. Team A cannot access Team B private Workspace/Chat.

6. Adding a member activates Team Workspace + Chat access.

7. Removing a member revokes future access immediately.

8. Removal never deletes prior messages/authorship/history.

9. Moving Team A → Team B does not copy Team A private content.

10. Team Lead is a coordination role, not an Admin/Master role.

11. Chat is stored in PostgreSQL.

12. Realtime is only the delivery/update layer.

13. Master Chat access must follow the finally approved policy and must never be hidden.

14. Mentor access is explicit and scoped.

15. M5 does not yet create Development Projects.

16. Project-linked Team work starts in M6.
```

---

# 65. Next File After M5

After M5 has actually been:

```text
IMPLEMENTED
→ TESTED
→ SECURITY-REVIEWED
→ COMMITTED
```

create:

# `20_CODEX_M6_PROMPTS.md`

M6 will cover:

```text
Development Project
Project Membership
Program / Project Links
Development Objects
Object Relationships
Problem Details
Idea Details
Project Stage
Archive
Change Log Foundation
```

M6 will connect the now-secure Personal/Team Workspace architecture to the persistent Development Project model.

---

# 66. Final Execution Rule

For M5:

```text
TEAM SCHEMA
→ MEMBERSHIP
→ CHAT SCHEMA
→ CREATE TEAM TRANSACTION
→ ADD / REMOVE / MOVE MEMBER
→ TEAM LEAD
→ CHAT OPERATIONS
→ REALTIME
→ RLS
→ AUDIT
→ ARCHIVE
→ TEAM TESTS
→ CHAT TESTS
→ LEAKAGE TESTS
→ MEMBER-REMOVAL TEST
→ SECURITY HARDENING
```

Do not skip directly to Development Projects or structured invention tools.

---

# End of Document

**Current Status:** Draft v0.1 — Ready for Ahmad/FICI review.  
**Execution Step After M4 Completion:** Start with **M5.1 — Team Schema**.
