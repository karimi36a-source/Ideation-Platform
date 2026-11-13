# FICI Invention Education & Development Platform
## Acceptance Tests & Pilot Readiness Specification

**Document:** `12_ACCEPTANCE_TESTS.md`  
**Status:** Draft v0.1 — For Review  
**Depends on:** `01_PRODUCT_REQUIREMENTS.md` through `11_API_CONTRACTS.md`  
**Purpose:** Define the acceptance criteria and end-to-end test scenarios that determine whether the MVP is functionally correct, secure, permission-safe, and ready for a pilot cohort.

---

# 1. Acceptance Testing Principle

The platform is not accepted because pages load.

The MVP is accepted only if:

- permissions are enforced,
- Development Project continuity works,
- Personal Workspace remains private,
- Team Workspace remains isolated,
- sharing behaves intentionally,
- version history is preserved,
- instructor review works,
- AI cannot bypass permissions,
- structured activities create reusable outputs,
- approved outputs correctly feed later activities,
- core workflows operate end to end.

---

# 2. Test Categories

The acceptance suite should cover:

1. Authentication
2. Roles & Scope
3. Course / Cohort
4. Personal Workspace
5. Team Workspace
6. Team Membership
7. Team Chat
8. Sharing
9. Development Project
10. Activities
11. SCAMPER
12. Brainstorming
13. Voting
14. Affinity
15. Mind Mapping
16. Decisions
17. Evidence
18. Patent Records
19. Files
20. Submission / Review / Revision / Approval
21. Versioning
22. AI
23. Realtime Collaboration
24. Development Gates
25. Audit Trail
26. Security / RLS
27. Cross-Team Leakage Prevention
28. Pilot Readiness

---

# 3. Test Data Setup

Create a standard test cohort.

## Users

### Admin
- `admin@fici.test`

### Master
- `master@fici.test`

### Mentor
- `mentor@fici.test`

### Team A Students
- `student.a1@fici.test`
- `student.a2@fici.test`

### Team B Students
- `student.b1@fici.test`
- `student.b2@fici.test`

## Cohort

```text
Professional Course — Test Cohort
```

## Teams

```text
Team A
Team B
```

## Projects

```text
Project A → Team A
Project B → Team B
```

Each student also receives a Personal Workspace.

---

# 4. Severity Levels

Acceptance failures should be classified.

## BLOCKER

Cannot pilot.

Examples:

- cross-team data leak,
- private workspace leak,
- unauthorized approval,
- artifact history overwritten,
- AI receives unauthorized data,
- direct file access bypasses permissions.

## HIGH

Major workflow broken.

Examples:

- team chat unavailable,
- artifact submission broken,
- approval transaction inconsistent,
- activity dependency not enforced.

## MEDIUM

Important but workaround exists.

## LOW

Usability/polish issue not affecting core correctness.

The pilot should have zero open BLOCKER issues.

---

# 5. Authentication Acceptance Tests

## AT-AUTH-001 — Valid Login

**Given** an active Student account  
**When** the user logs in with valid credentials  
**Then** authentication succeeds  
**And** the user is redirected to an authorized platform area.

**Priority:** MUST PASS

---

## AT-AUTH-002 — Invalid Login

**When** invalid credentials are submitted  
**Then** authentication fails  
**And** no session is created  
**And** the error does not expose sensitive account details.

**Priority:** MUST PASS

---

## AT-AUTH-003 — Unauthenticated Protected Route

**Given** no authenticated session  
**When** a protected route/resource is requested  
**Then** access is denied.

**Priority:** MUST PASS

---

## AT-AUTH-004 — Client User ID Spoofing

**Given** Student A is authenticated  
**When** the client submits Student B's user ID in a mutation  
**Then** the server continues using Student A's authenticated identity  
**And** unauthorized action is denied.

**Priority:** BLOCKER

---

# 6. Role & Scope Acceptance Tests

## AT-RBAC-001 — Student Cannot Perform Admin Action

**Given** Student A1  
**When** they call a role-assignment or platform administration operation  
**Then** the request returns `FORBIDDEN`.

**Priority:** BLOCKER

---

## AT-RBAC-002 — Master Limited to Assigned Cohort

**Given** Master is assigned to Test Cohort only  
**When** Master attempts to manage an unrelated cohort  
**Then** access is denied.

**Priority:** BLOCKER

---

## AT-RBAC-003 — Mentor Scope

**Given** Mentor is assigned only to Team A  
**When** Mentor attempts to access Team B project content  
**Then** access is denied.

**Priority:** BLOCKER

---

# 7. Personal Workspace Acceptance Tests

## AT-PW-001 — Personal Workspace Owner Access

Student A1 can:

- view,
- create,
- edit,
- use AI,
- attach files

inside their Personal Workspace.

**Priority:** MUST PASS

---

## AT-PW-002 — Personal Workspace Privacy

**Given** Student A1 creates a private Idea  
**When** Student A2 attempts access by:

- UI,
- direct route,
- guessed ID,
- API query

**Then** access is denied.

**Priority:** BLOCKER

---

## AT-PW-003 — Master Cannot Browse Unshared Personal Draft

**Given** Student A1 has not shared/submitted a private draft  
**When** Master attempts direct access  
**Then** access is denied under the default privacy model.

**Priority:** BLOCKER

---

## AT-PW-004 — Share Selected Personal Artifact

**Given** Student A1 has 10 private ideas  
**When** they share 3 with Team A  
**Then** Team A sees only those 3  
**And** the remaining 7 stay private.

**Priority:** MUST PASS

---

# 8. Team Workspace Acceptance Tests

## AT-TW-001 — Team Member Access

Students A1 and A2 can access Team A Workspace.

**Priority:** MUST PASS

---

## AT-TW-002 — Cross-Team Workspace Isolation

**Given** Student B1  
**When** they request Team A Workspace directly  
**Then** access is denied.

**Priority:** BLOCKER

---

## AT-TW-003 — Team B Cannot Query Team A Records

Test at data/API level, not only UI.

Student B1 must not retrieve:

- Team A artifacts,
- Team A decisions,
- Team A evidence,
- Team A AI outputs,
- Team A private files.

**Priority:** BLOCKER

---

# 9. Team Management Acceptance Tests

## AT-TEAM-001 — Master Creates Team

Master can create Team C in assigned cohort.

System must create:

- Team record,
- Team Workspace,
- Team Chat Channel,
- audit event.

**Priority:** MUST PASS

---

## AT-TEAM-002 — Add Member

Master adds Student A1 to Team C.

Then:

- membership is active,
- Team C becomes accessible,
- Team C chat becomes accessible,
- notification is created.

**Priority:** MUST PASS

---

## AT-TEAM-003 — Remove Member

Master removes Student A1 from Team C.

Then:

- future Team C access is denied,
- chat access is denied,
- previous authorship remains,
- prior messages remain,
- prior votes remain,
- audit record exists.

**Priority:** BLOCKER

---

## AT-TEAM-004 — Removed Member Direct ID Access

After removal, Student A1 attempts direct API access to Team C artifact ID.

Access must be denied.

**Priority:** BLOCKER

---

## AT-TEAM-005 — Move Between Teams

When Student A1 moves Team A → Team B:

- Team A future access ends,
- Team A historical contributions remain,
- Team B access begins,
- Team A private content is not copied into Team B.

**Priority:** BLOCKER

---

# 10. Team Chat Acceptance Tests

## AT-CHAT-001 — Send Message

Team A member sends message.

Then:

- message persists in database,
- authorized Team A users receive realtime update,
- sender and timestamp are stored.

**Priority:** MUST PASS

---

## AT-CHAT-002 — Team B Cannot Read Team A Chat

Test:

- list endpoint,
- direct message ID,
- realtime subscription.

All must deny Team B access.

**Priority:** BLOCKER

---

## AT-CHAT-003 — Removed Member Cannot Send Message

Removed member attempts to post.

Result: `FORBIDDEN`.

**Priority:** BLOCKER

---

## AT-CHAT-004 — Message Persists After Refresh

Team chat must load canonical stored messages after reconnect/refresh.

**Priority:** MUST PASS

---

# 11. Sharing Acceptance Tests

## AT-SHARE-001 — Share Artifact to Master

Team A shares artifact with Master.

Then:

- Master gains specified access,
- ownership remains Team A,
- share record exists,
- audit/notification exists.

**Priority:** MUST PASS

---

## AT-SHARE-002 — Sharing Does Not Expose Workspace

Team A shares Mind Map with Team B.

Team B must not gain access to:

- Team A chat,
- Team A other artifacts,
- Team A files,
- Team A AI history.

**Priority:** BLOCKER

---

## AT-SHARE-003 — View-Only Enforcement

Team B receives VIEW permission.

Attempt to edit must fail.

**Priority:** BLOCKER

---

## AT-SHARE-004 — Comment Permission

With COMMENT permission:

- Team B may comment,
- Team B may not edit source artifact.

**Priority:** MUST PASS

---

## AT-SHARE-005 — Revoke Share

After Team A revokes share:

- Team B loses future access,
- share history remains,
- existing audit record remains.

**Priority:** MUST PASS

---

# 12. Development Project Acceptance Tests

## AT-PROJ-001 — Project Persists Across Sessions

Project A created during early course remains the same Project ID in later sessions.

**Priority:** MUST PASS

---

## AT-PROJ-002 — Same Objects Reused

Problem created in Session 4 can be referenced in Session 5 and Session 6 without creating duplicate records.

**Priority:** MUST PASS

---

## AT-PROJ-003 — Project Continues Across Programs

A Professional Course project can be linked into Advanced Course without recreating project history.

**Priority:** MUST PASS for architecture / MAY be deferred in UI

---

# 13. Activity Engine Acceptance Tests

## AT-ACT-001 — Start Activity

Authorized participant starts available activity.

System creates Activity Instance linked to:

- definition,
- project,
- workspace,
- participant/team.

**Priority:** MUST PASS

---

## AT-ACT-002 — Dependency Enforcement

If an activity requires approved prior output and dependency is missing:

Result:

`DEPENDENCY_NOT_MET`

**Priority:** MUST PASS

---

## AT-ACT-003 — Resume Activity

Participant returns after logout.

Current activity state and outputs persist.

**Priority:** MUST PASS

---

## AT-ACT-004 — Activity Output Available to Next Stage

Approved output becomes selectable/available as required input to dependent activity.

**Priority:** MUST PASS

---

# 14. SCAMPER Acceptance Tests

## AT-SCAMPER-001 — Create Entry

Student can save:

- lens,
- original element,
- proposed change,
- result.

**Priority:** MUST PASS

---

## AT-SCAMPER-002 — Personal Before Share

Student A1's SCAMPER entry stays private until shared.

**Priority:** BLOCKER

---

## AT-SCAMPER-003 — Share to Team

Selected SCAMPER entry becomes available to Team A while original creator remains recorded.

**Priority:** MUST PASS

---

# 15. Brainstorming Acceptance Tests

## AT-BRAIN-001 — Independent Generation

Each team member can create private entries before reveal when activity is configured that way.

**Priority:** MUST PASS

---

## AT-BRAIN-002 — No Premature Reveal

Student A1 cannot see A2's unrevealed ideas.

**Priority:** BLOCKER

---

## AT-BRAIN-003 — Reveal

Once authorized reveal occurs, eligible team members see the shared pool.

**Priority:** MUST PASS

---

## AT-BRAIN-004 — Promote Entry

Brainstorm entry can be promoted to structured Idea with provenance.

**Priority:** MUST PASS

---

# 16. Voting Acceptance Tests

## AT-VOTE-001 — Dot Vote Limit

If vote limit = 3, user cannot cast a fourth valid vote.

**Priority:** MUST PASS

---

## AT-VOTE-002 — Unauthorized User Cannot Vote

Team B user cannot vote in Team A voting session.

**Priority:** BLOCKER

---

## AT-VOTE-003 — Voting Does Not Auto-Finalize Decision

After voting closes, the top result does not automatically become final Team Decision unless workflow explicitly says so.

**Priority:** MUST PASS

---

# 17. Affinity Acceptance Tests

## AT-AFF-001 — Group Existing Objects

Team can group existing Problems/Solutions without duplicating canonical Development Objects.

**Priority:** MUST PASS

---

## AT-AFF-002 — Collaborative Movement

Two Team A members can update Affinity Board without silent loss of each other's changes.

**Priority:** MUST PASS

---

# 18. Mind Map Acceptance Tests

## AT-MM-001 — Structured Node Creation

Team can create nodes typed as:

- System,
- Subsystem,
- Component,
- Function,
- Problem,
- Solution,
- Gap.

**Priority:** MUST PASS

---

## AT-MM-002 — Link Node to Project Object

Mind Map node can reference an existing Development Object.

**Priority:** MUST PASS

---

## AT-MM-003 — Delete Node Does Not Delete Canonical Object

Removing a visual Mind Map node must not automatically delete the underlying Development Object.

**Priority:** BLOCKER

---

## AT-MM-004 — Collaborative Save

Live state can be saved as a Draft Artifact Version.

**Priority:** MUST PASS

---

# 19. Decision Acceptance Tests

## AT-DEC-001 — Decision Records Reasoning

Finalized decision stores:

- issue,
- outcome,
- reasoning,
- participants,
- linked evidence,
- timestamp.

**Priority:** MUST PASS

---

## AT-DEC-002 — Supersede Without Erasing

A later decision may supersede earlier decision.

Earlier decision remains in history.

**Priority:** MUST PASS

---

# 20. Evidence Acceptance Tests

## AT-EV-001 — Create Evidence

User creates Evidence with:

- source,
- type,
- title,
- verification state,
- link/file.

Default state = UNVERIFIED.

**Priority:** MUST PASS

---

## AT-EV-002 — AI Output Is Not Evidence

Saved AI output must not appear automatically in Evidence records.

**Priority:** BLOCKER

---

## AT-EV-003 — Link Evidence

Evidence can be linked to:

- Decision,
- Requirement,
- Gap,
- Artifact,
- Patent Record.

**Priority:** MUST PASS

---

# 21. Patent Record Acceptance Tests

## AT-PAT-001 — Save Patent Record

User can save:

- publication number,
- title,
- database/source,
- URL,
- notes,
- relevance.

**Priority:** MUST PASS

---

## AT-PAT-002 — Patent Analysis Label

AI analysis of a patent remains labeled AI Analysis, while Patent Record remains source/evidence metadata.

**Priority:** BLOCKER

---

## AT-PAT-003 — Search Log

Search query can be stored with:

- database,
- query,
- method,
- date,
- user,
- notes.

**Priority:** MUST PASS

---

# 22. File Acceptance Tests

## AT-FILE-001 — Private File

Student A1 uploads file to Personal Workspace.

Student A2 must not download using direct URL/reference.

**Priority:** BLOCKER

---

## AT-FILE-002 — Team File

Team A file is accessible only to authorized Team A users / authorized instructional roles.

**Priority:** BLOCKER

---

## AT-FILE-003 — Signed Access Expires

Temporary authorized file URL should not become permanent public access.

**Priority:** MUST PASS

---

# 23. Submission / Review Acceptance Tests

## AT-REV-001 — Submit Draft

Team submits Draft Version.

Then:

- Submission created,
- status = SUBMITTED,
- Master notified.

**Priority:** MUST PASS

---

## AT-REV-002 — Master Requests Revision

Master requests revision.

Then:

- submission status updates,
- feedback stored,
- team notified,
- prior submitted version retained.

**Priority:** MUST PASS

---

## AT-REV-003 — Team Resubmits New Version

Team creates revised version.

Previous version remains unchanged.

**Priority:** MUST PASS

---

## AT-REV-004 — Master Approves

Approval transaction:

- submitted version becomes APPROVED/CURRENT,
- previous current becomes SUPERSEDED,
- artifact current pointer updates,
- audit created,
- notification sent.

**Priority:** BLOCKER

---

## AT-REV-005 — Student Cannot Approve

Student attempts direct approval endpoint.

Result: `FORBIDDEN`.

**Priority:** BLOCKER

---

# 24. Versioning Acceptance Tests

## AT-VER-001 — Approved Version Immutable

Attempt to edit approved version body directly must fail.

**Priority:** BLOCKER

---

## AT-VER-002 — New Revision Creates New Version

Revision produces new Draft Version rather than overwriting approved version.

**Priority:** BLOCKER

---

## AT-VER-003 — Version History Visible

Authorized user can view:

- version number,
- creator,
- timestamp,
- change summary,
- approval state.

**Priority:** MUST PASS

---

# 25. AI Acceptance Tests

## AT-AI-001 — Activity-Specific Role

When AI is launched from SCAMPER activity, AI role resolves to Structured Creativity Assistant or configured equivalent.

**Priority:** MUST PASS

---

## AT-AI-002 — Team Context Authorization

Team A AI request may use Team A authorized content.

It must not retrieve Team B private data.

**Priority:** BLOCKER

---

## AT-AI-003 — Private AI Context

Student A1 Personal AI may use A1 private content.

Student A2 AI must not receive it.

**Priority:** BLOCKER

---

## AT-AI-004 — Removed Member AI Access

After A1 is removed from Team A, AI context retrieval for A1 must not include Team A private data.

**Priority:** BLOCKER

---

## AT-AI-005 — Context References Stored

Saved AI Output includes meaningful Context References.

**Priority:** MUST PASS

---

## AT-AI-006 — AI Output Label

Output visibly/data-wise classified as:

- AI_ANALYSIS,
- AI_SUGGESTION,
- etc.

**Priority:** BLOCKER

---

## AT-AI-007 — AI Cannot Auto-Approve

No AI operation can directly mark an Artifact Version APPROVED/CURRENT.

**Priority:** BLOCKER

---

## AT-AI-008 — Convert to Candidate

Human-confirmed AI output may create Draft/Candidate object with origin/provenance retained.

**Priority:** MUST PASS

---

## AT-AI-009 — AI Provider Failure

If provider fails:

- user project remains intact,
- no corrupt output saved as approved,
- error shown safely,
- retry possible.

**Priority:** MUST PASS

---

# 26. AI Leakage Penetration Tests

These tests should deliberately try to break isolation.

## AT-AI-LEAK-001

Student A1 asks:

> "Summarize the best solution from other teams."

Expected:

AI must not retrieve private Team B content.

**Priority:** BLOCKER

---

## AT-AI-LEAK-002

Student B1 supplies Team A artifact ID manually in AI request.

Expected:

context resolver rejects it.

**Priority:** BLOCKER

---

## AT-AI-LEAK-003

A previously shared Team A artifact is revoked.

Student B1 asks AI about it afterward.

Expected:

revoked source must not be included in new AI context.

**Priority:** BLOCKER

---

# 27. Realtime Acceptance Tests

## AT-RT-001 — Authorized Team Broadcast

Team A receives Team A realtime events.

**Priority:** MUST PASS

---

## AT-RT-002 — Unauthorized Channel Subscription

Team B attempts to subscribe to Team A private channel.

Expected: denied.

**Priority:** BLOCKER

---

## AT-RT-003 — Reconnect

After temporary disconnect, canonical database state reloads correctly.

**Priority:** MUST PASS

---

# 28. Development Gate Acceptance Tests

## AT-GATE-001 — Master Evaluates Gate

Authorized Master can record:

- outcome,
- reasoning,
- evidence,
- next action.

**Priority:** SHOULD PASS if gates included in pilot.

---

## AT-GATE-002 — Course Completion Does Not Force GO

A learner may complete a session while gate remains:

- MODIFY,
- HOLD,
- MORE_EVIDENCE_REQUIRED.

**Priority:** MUST PASS conceptually.

---

# 29. Audit Acceptance Tests

## AT-AUD-001 — Membership Audit

Add/remove/move member creates audit event.

**Priority:** MUST PASS

---

## AT-AUD-002 — Approval Audit

Artifact approval records actor, timestamp, artifact/version.

**Priority:** MUST PASS

---

## AT-AUD-003 — Share Audit

Share/revoke creates audit event.

**Priority:** MUST PASS

---

# 30. Direct ID Attack Tests

For protected resource IDs, attempt direct access using an unauthorized account.

Test:

- workspace ID,
- artifact ID,
- version ID,
- evidence ID,
- file ID,
- AI output ID,
- chat message ID,
- project ID.

Expected:

`FORBIDDEN` or safe `NOT_FOUND`.

Never return protected content.

**Priority:** BLOCKER

---

# 31. RLS Acceptance Tests

Database-level tests must verify:

## AT-RLS-001
Student A1 cannot select Student A2 private object.

## AT-RLS-002
Team B user cannot select Team A artifact.

## AT-RLS-003
Removed member cannot select future Team A content.

## AT-RLS-004
Student cannot update approved Artifact Version.

## AT-RLS-005
Unauthorized user cannot insert Team A chat message.

## AT-RLS-006
Unauthorized user cannot read private storage metadata.

## AT-RLS-007
Unshared artifact cannot be exposed by join/query path.

All are **BLOCKER**.

---

# 32. Transaction Integrity Tests

## AT-TX-001 — Approval Rollback

Artificially fail one step of approval transaction.

Expected:

No partial state:

- current pointer unchanged,
- version statuses unchanged,
- no false approval audit.

**Priority:** BLOCKER

---

## AT-TX-002 — Team Creation Rollback

If Chat Channel creation fails, system should not leave inconsistent half-created official Team unless recovery design explicitly supports it.

**Priority:** HIGH

---

# 33. Concurrency Tests

## AT-CON-001 — Simultaneous Edit

Two users edit same Draft.

System must:

- merge safely through collaboration layer,
- or detect version conflict.

Silent overwrite is unacceptable.

**Priority:** HIGH

---

## AT-CON-002 — Competing Approval/Revision

Two reviewers/actions happen almost simultaneously.

System must prevent contradictory final state.

**Priority:** BLOCKER

---

# 34. Curriculum Dependency Tests

## AT-CUR-001 — Session Output Reuse

Session 4 Problem Bank appears as a valid input to Session 5.

**Priority:** MUST PASS

---

## AT-CUR-002 — Approved Baseline

Session 10 AI refinement receives the intended current/approved invention baseline, not an arbitrary older draft.

**Priority:** MUST PASS

---

# 35. End-to-End Professional Course Core Scenario

## AT-E2E-001

Run this exact scenario:

1. Admin creates Professional Course cohort.
2. Master adds four students.
3. Master creates Team A and Team B.
4. A1 enters Personal Workspace.
5. A1 creates SCAMPER entries.
6. A1 shares selected entries with Team A.
7. A2 creates independent ideas.
8. Team A reveals/combines ideas.
9. Team A creates Problem Bank.
10. Team A creates Solution Bank.
11. Team A runs Dot Voting.
12. Team A creates formal Decision Record.
13. Team A builds Affinity groups.
14. Team A builds Mind Map.
15. Team A saves Patent Record.
16. Team A creates Evidence Record.
17. Team A runs AI analysis.
18. AI output is labeled and remains unverified.
19. Team A converts one suggestion to Candidate.
20. Team A submits Artifact to Master.
21. Master requests revision.
22. Team A creates new version.
23. Team A resubmits.
24. Master approves.
25. Approved output is available to dependent next activity.
26. Previous versions remain accessible.
27. Team B never sees Team A private content.

**Expected:** all steps succeed with correct permissions/history.

**Priority:** MVP RELEASE GATE

---

# 36. End-to-End Privacy Scenario

## AT-E2E-PRIV-001

Attempt every reasonable route by which Team B could access Team A content:

- UI navigation,
- direct URL,
- API request,
- database query under user auth,
- realtime channel,
- file URL,
- shared object relationship,
- AI context selection.

Expected:

No unauthorized content is returned.

**Priority:** BLOCKER / RELEASE GATE

---

# 37. End-to-End Member Removal Scenario

## AT-E2E-MEMBER-001

1. A1 contributes Idea, Vote, Message, Artifact edit.
2. Master removes A1 from Team A.
3. A1 loses future Team A access.
4. Team A retains A1 historical contributions.
5. A1 cannot access Team A via API/direct IDs/chat/AI.
6. Audit records removal.
7. A1's Personal Workspace remains intact.

**Priority:** RELEASE GATE

---

# 38. End-to-End AI Governance Scenario

## AT-E2E-AI-001

1. Team A runs AI on Gap G1.
2. AI suggests Solution S-AI.
3. Output stored as AI_SUGGESTION / UNVERIFIED.
4. Team reviews it.
5. Team saves it as Candidate.
6. Evidence is added.
7. Team records Decision.
8. New Draft Artifact Version is created.
9. Master reviews.
10. Only after Master approval does new version become CURRENT.

At no point may the AI output automatically become approved content.

**Priority:** RELEASE GATE

---

# 39. Performance Acceptance — MVP

These are practical goals, not hard enterprise SLAs.

## Page / Data

Normal workspace navigation should feel responsive under pilot load.

## Chat

New team message should normally appear to connected teammates within a few seconds.

## AI

AI calls may take longer, but UI must clearly show progress and not block unrelated platform actions.

## Collaborative Tools

Mind Map/Affinity updates should feel interactive for normal small teams.

Performance benchmarks should be measured during pilot preparation.

---

# 40. Accessibility Acceptance

Basic MVP must verify:

- keyboard access to standard forms/buttons,
- visible focus,
- labels for inputs,
- meaningful button text,
- dialog focus behavior,
- color not being the only status indicator,
- readable error messages.

Canvas-like tools should have a structured alternative/list where practical.

---

# 41. Browser Acceptance

Test current versions of:

- Chrome
- Edge
- Safari
- Firefox

Priority should reflect the actual pilot audience.

Desktop web is the primary MVP target.

---

# 42. Responsive Acceptance

Core non-canvas workflows should work on:

- desktop,
- tablet,
- reasonable mobile viewport.

Complex collaborative Mind Mapping may be optimized primarily for desktop/tablet in MVP.

---

# 43. Backup / Recovery Acceptance

Before pilot:

1. Confirm production database backup configuration.
2. Document restore steps.
3. Perform at least one recovery test in non-production environment.
4. Confirm uploaded-file recovery approach.

**Priority:** HIGH

---

# 44. Logging Acceptance

Errors should contain enough structured diagnostics to troubleshoot:

- request,
- user ID where appropriate,
- operation,
- project/workspace IDs,
- error code.

Logs must not expose:

- passwords,
- API secrets,
- sensitive access tokens.

---

# 45. Pilot Admin Acceptance

Admin must be able to:

- create cohort,
- add Master,
- invite/enroll students,
- create/manage teams,
- view active users,
- resolve membership errors.

**Priority:** MUST PASS

---

# 46. Pilot Master Acceptance

Master must be able to:

- open cohort,
- see teams,
- launch activities,
- inspect submitted work,
- comment,
- request revision,
- approve,
- see basic progress.

**Priority:** MUST PASS

---

# 47. Pilot Student Acceptance

Student must be able to:

- log in,
- access course,
- use Personal Workspace,
- access assigned Team,
- use core tools,
- chat,
- share,
- submit,
- receive feedback,
- revise,
- see approval/current output.

**Priority:** MUST PASS

---

# 48. MVP Release Checklist

The MVP can enter pilot only when:

- [ ] Authentication passes
- [ ] Roles/scopes pass
- [ ] Personal privacy passes
- [ ] Team isolation passes
- [ ] Member removal passes
- [ ] Team chat passes
- [ ] Sharing passes
- [ ] Project continuity passes
- [ ] Activity dependency passes
- [ ] Core method tools pass
- [ ] Evidence separation passes
- [ ] Patent Record workflow passes
- [ ] Submission/revision/approval passes
- [ ] Version history passes
- [ ] AI context security passes
- [ ] AI provenance passes
- [ ] AI cannot auto-approve
- [ ] RLS tests pass
- [ ] Direct-ID attack tests pass
- [ ] File authorization passes
- [ ] Transaction rollback tests pass
- [ ] E2E core workflow passes
- [ ] E2E privacy scenario passes
- [ ] No open BLOCKER defects

---

# 49. Post-Pilot Success Indicators

After launch, evaluate:

- users can understand workspace scope,
- students successfully move work Personal → Team,
- instructors can review without outside tools,
- structured activity outputs are reused,
- teams use private chat,
- AI suggestions are understandable and properly distinguished,
- privacy incidents = zero,
- version history is useful,
- platform reduces disconnected files/tools,
- participants can complete the Professional Course workflow.

These are product validation signals, not purely technical tests.

---

# 50. Acceptance Decisions Captured

## AT-DECISION-001 — Privacy Is a Release Gate

Any cross-team/private-workspace leak blocks release.

**Status:** Required.

## AT-DECISION-002 — AI Permission Leakage Is a Release Gate

Any unauthorized AI context retrieval blocks release.

**Status:** Required.

## AT-DECISION-003 — Historical Integrity Is Required

Member removal/revision must not destroy development history.

**Status:** Required.

## AT-DECISION-004 — Approval Must Be Transactionally Correct

Partial approval state is unacceptable.

**Status:** Required.

## AT-DECISION-005 — One End-to-End Course Flow Must Work

The product is not MVP-ready until the full core invention workflow succeeds.

**Status:** Required.

---

# 51. Documentation Package Completion

After this document is approved, the pre-coding package consists of:

```text
01_PRODUCT_REQUIREMENTS.md
02_PLATFORM_ARCHITECTURE.md
03_ROLES_PERMISSIONS.md
04_WORKSPACE_TEAM_COLLABORATION.md
05_DEVELOPMENT_PROJECT_MODEL.md
06_COURSE_ACTIVITY_WORKFLOWS.md
07_MVP_SCOPE.md
08_DATA_MODEL_SCHEMA.md
09_AI_ASSISTANT_SPEC.md
10_TECHNICAL_ARCHITECTURE.md
11_API_CONTRACTS.md
12_ACCEPTANCE_TESTS.md
```

These documents should be stored in:

```text
/docs
```

and treated as the implementation source of truth.

---

# 52. Next Step After Approval

After all 12 files are attached and approved, do **not** immediately ask Codex to build the entire platform.

Create the first implementation planning file:

# `13_CODEX_IMPLEMENTATION_PLAN.md`

That file should break the build into small, ordered milestones such as:

```text
M0 Repository & Environment
M1 Authentication
M2 Roles / RLS
M3 Courses / Cohorts
M4 Workspaces
M5 Teams / Chat
M6 Development Project
M7 Activity Engine
M8 Review / Versioning
M9 SCAMPER / Brainstorming
M10 Voting
M11 Affinity / Mind Map
M12 Evidence / Patent
M13 AI
M14 Pilot Hardening
```

Each milestone should contain:

- exact scope,
- files/modules,
- schema migrations,
- API contracts,
- tests,
- acceptance criteria,
- Codex prompt,
- definition of done.

---

# 53. Codex Acceptance Rule

Codex must not declare a feature complete because it compiles.

A feature is complete only when:

```text
IMPLEMENTED
+
TYPECHECK PASSES
+
TESTS PASS
+
PERMISSIONS TESTED
+
ACCEPTANCE CRITERIA PASS
+
NO DOCUMENTATION CONTRADICTION
```

For security-critical features:

```text
RLS / AUTHORIZATION TESTS
```

are mandatory.

---

# End of Document

**Current Status:** Draft v0.1 — Ready for Ahmad/FICI review.  
**Next Step After Approval:** Create `13_CODEX_IMPLEMENTATION_PLAN.md`
