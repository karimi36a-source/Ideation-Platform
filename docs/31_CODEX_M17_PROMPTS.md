# FICI Invention Education & Development Platform
## Codex M17 Execution Prompts — Pilot Hardening, Security & Release

**Document:** `31_CODEX_M17_PROMPTS.md`  
**Status:** Draft v0.1 — Final Implementation Milestone  
**Depends on:** `01_PRODUCT_REQUIREMENTS.md` through `30_CODEX_M16_PROMPTS.md`  
**Purpose:** Provide exact copy/paste prompts for Codex to harden the completed MVP, execute the full release-gate test suite, fix defects without changing business rules, and produce a final pilot-readiness report.

---

# 1. M17 Is Different From M0–M16

M17 is not a feature milestone.

It is:

```text
HARDEN
→ ATTACK
→ VERIFY
→ FIX
→ RETEST
→ RELEASE-GATE
```

Do not use M17 to add unrelated features.

The Implementation Plan explicitly defines M17 as:

```text
Pilot Hardening, Security & Release
```

Its objective is:

```text
Prepare the platform for a real Professional Course pilot.
```

---

# 2. Preconditions

Do not begin M17 until M16 is:

```text
IMPLEMENTED
→ TESTED
→ SECURITY-REVIEWED
→ COMMITTED
```

Required overall state:

- M0–M16 implemented,
- migrations committed,
- core Professional Course workflow functional,
- RLS enabled,
- Team isolation functional,
- Personal Workspace privacy functional,
- Project history/versioning functional,
- Activities functional,
- core tools functional,
- Evidence/Patent workflow functional,
- Sharing functional,
- AI governance functional,
- Progress/Notifications functional,
- Live Classroom functional,
- no known unresolved architectural contradiction.

If any milestone remains structurally incomplete:

```text
STOP
→ identify incomplete prerequisite
→ finish/fix prerequisite
→ return to M17
```

---

# 3. M17 Release Rule

The release rule is exact:

# NO OPEN BLOCKER DEFECT

A pilot must not launch with a known BLOCKER.

This includes, among others:

- cross-Team private data leak,
- Personal Workspace leak,
- unauthorized approval,
- AI unauthorized-context leak,
- private File access bypass,
- approved Artifact mutation,
- direct-ID bypass,
- contradictory final transaction state,
- unshared resource exposure.

HIGH/MEDIUM/LOW issues may remain only if:

- documented,
- impact understood,
- workaround known where necessary,
- Ahmad/FICI explicitly accepts the risk for pilot.

---

# 4. M17 Mandatory Acceptance

Run at minimum:

```text
AT-E2E-001
AT-E2E-PRIV-001
AT-E2E-MEMBER-001
AT-E2E-AI-001
ALL BLOCKER TESTS IN 12_ACCEPTANCE_TESTS.md
```

Also execute:

- full RLS review,
- direct-ID attacks,
- AI leakage tests,
- transaction rollback tests,
- concurrency tests,
- browser testing,
- accessibility review,
- backup/restore test,
- logging review,
- rate-limiting review,
- file-limit/security review,
- error-handling review,
- full Professional Course E2E,
- MVP Release Checklist.

---

# 5. M17 Definition of Done

M17 is complete only when:

```text
THE MVP RELEASE CHECKLIST
IN 12_ACCEPTANCE_TESTS.md
IS FULLY COMPLETED
```

Codex must not declare READY FOR PILOT because:

- build passes,
- app loads,
- happy-path demo works,
- unit tests pass.

Completion requires:

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
+
ZERO OPEN BLOCKER
```

---

# 6. Source-of-Truth Files

Before M17 work, Codex must read:

```text
/docs/01_PRODUCT_REQUIREMENTS.md
/docs/02_PLATFORM_ARCHITECTURE.md
/docs/03_ROLES_PERMISSIONS.md
/docs/04_WORKSPACE_TEAM_COLLABORATION.md
/docs/05_DEVELOPMENT_PROJECT_MODEL.md
/docs/06_COURSE_ACTIVITY_WORKFLOWS.md
/docs/07_MVP_SCOPE.md
/docs/08_DATA_MODEL_SCHEMA.md
/docs/09_AI_ASSISTANT_SPEC.md
/docs/10_TECHNICAL_ARCHITECTURE.md
/docs/11_API_CONTRACTS.md
/docs/12_ACCEPTANCE_TESTS.md
/docs/13_CODEX_IMPLEMENTATION_PLAN.md
/docs/14_CODEX_M0_PROMPTS.md
/docs/15_CODEX_M1_PROMPTS.md
/docs/16_CODEX_M2_PROMPTS.md
/docs/17_CODEX_M3_PROMPTS.md
/docs/18_CODEX_M4_PROMPTS.md
/docs/19_CODEX_M5_PROMPTS.md
/docs/20_CODEX_M6_PROMPTS.md
/docs/21_CODEX_M7_PROMPTS.md
/docs/22_CODEX_M8_PROMPTS.md
/docs/23_CODEX_M9_PROMPTS.md
/docs/24_CODEX_M10_PROMPTS.md
/docs/25_CODEX_M11_PROMPTS.md
/docs/26_CODEX_M12_PROMPTS.md
/docs/27_CODEX_M13_PROMPTS.md
/docs/28_CODEX_M14_PROMPTS.md
/docs/29_CODEX_M15_PROMPTS.md
/docs/30_CODEX_M16_PROMPTS.md
```

Do not "simplify" a business rule during hardening.

Fix implementation defects while preserving approved behavior.

---

# 7. Global M17 Codex Header

Use this block at the beginning of every M17 task if the repository context is not guaranteed:

```text
You are executing M17 — Pilot Hardening, Security & Release for the FICI Invention Education & Development Platform.

RULES

1. M17 is hardening only.
2. Do not add unrelated features.
3. Read 12_ACCEPTANCE_TESTS.md in full before making release decisions.
4. Read all relevant architecture/permission/API documents before fixing defects.
5. Never change business rules merely to make a failing test pass.
6. If a test exposes a documentation contradiction, STOP → FLAG → ASK.
7. Privacy/security failures are release blockers.
8. AI permission leakage is a release blocker.
9. Historical integrity is required.
10. Approval must remain transactionally correct.
11. RLS tests are mandatory.
12. Direct-ID tests are mandatory.
13. Provider/client-side validation is never a substitute for server authorization.
14. Fix root causes rather than hiding failing tests.
15. Do not weaken assertions.
16. Do not skip tests because they are inconvenient.
17. Do not change BLOCKER severity.
18. Do not silently disable features to produce green CI unless explicitly accepted.
19. Record every remaining HIGH/MEDIUM/LOW issue.
20. Zero open BLOCKER issues are required for pilot.
21. Run lint/typecheck/tests/build after fixes.
22. Produce a final Pilot Readiness Report with evidence.
```

---

# 8. M17.1 — Freeze Feature Scope

## Objective

Prevent release-hardening from becoming another development phase.

## Copy/Paste Prompt

```text
TASK ID: M17.1
TASK: Freeze Feature Scope

OBJECTIVE

Create an M17 scope freeze.

DO

1. Read M17 section of 13_CODEX_IMPLEMENTATION_PLAN.md.
2. List currently implemented M0–M16 feature areas.
3. Identify any unfinished prerequisite.
4. Mark unrelated feature requests as POST-PILOT / DEFERRED.
5. Do not add new product modules during M17.

ALLOWED CHANGES

- defect fixes
- security fixes
- transaction fixes
- RLS corrections
- error handling
- logging
- rate limiting
- file validation
- accessibility fixes
- browser compatibility fixes
- test coverage
- deployment/recovery documentation
- small UX corrections necessary to pass acceptance

NOT ALLOWED

- new business modules
- new curriculum phases
- major redesign
- new AI roles unrelated to acceptance
- new advanced-course modules
- marketplace
- investor CRM
- public sharing
- unrelated analytics

OUTPUT

Return:
- scope freeze summary
- incomplete prerequisites
- deferred feature list
- BLOCKER to starting M17, if any
```

---

# 9. M17.2 — Acceptance Inventory

## Objective

Create a machine-readable/testable inventory of every required acceptance test.

## Copy/Paste Prompt

```text
TASK ID: M17.2
TASK: Acceptance Inventory

Read 12_ACCEPTANCE_TESTS.md in full.

Create a release matrix containing:

- Test ID
- Name
- Priority
- Milestone owner
- Automated?
- Manual?
- Current status
- Evidence location
- Failure severity
- Notes

INCLUDE

- Authentication
- RBAC
- Personal Workspace
- Team
- Chat
- Sharing
- Development Project
- Activity
- Artifacts/Versions
- SCAMPER
- Brainstorming
- Affinity
- Mind Map
- Voting
- Decisions
- Evidence
- Patent
- Files
- AI
- Realtime
- Gates if included
- Audit
- Direct-ID
- RLS
- Transactions
- Concurrency
- Curriculum dependency
- E2E
- Privacy
- Member removal
- AI governance
- Accessibility
- Browser
- Responsive
- Backup/Recovery
- Logging
- Pilot Admin/Master/Student

Do not omit BLOCKER tests.

DEFINITION OF DONE

One authoritative release-test inventory exists.
```

---

# 10. M17.3 — Full RLS Policy Review

## Objective

Audit every protected table/resource.

## Copy/Paste Prompt

```text
TASK ID: M17.3
TASK: Full RLS Review

OBJECTIVE

Review every table containing user/project/workspace/team/private data.

FOR EACH TABLE

Document:
- RLS enabled?
- SELECT policy
- INSERT policy
- UPDATE policy
- DELETE/archive policy
- trusted server-only path
- role/scope dependencies
- Share dependencies
- Team membership dependencies
- removed-member behavior
- direct-ID behavior

AT MINIMUM REVIEW

- users/profiles
- role assignments
- enrollments
- workspaces
- workspace membership/access structures
- teams
- team memberships
- chat channels/messages
- projects
- project memberships
- project-program links
- development objects/details/relationships
- activity instances/participants/inputs/outputs
- artifacts
- artifact versions
- submissions
- feedback/review actions
- SCAMPER
- brainstorm entries
- affinity
- mind maps/nodes/edges
- voting sessions/options/votes
- decisions/options/participants/links
- evidence/evidence links
- files/file links
- patent records/search logs
- shares/share snapshots
- AI outputs/context references
- AI usage where applicable
- notifications
- any live-room mapping table if added

LOOK FOR

- broad `auth.uid() IS NOT NULL`
- missing Workspace predicate
- missing Team predicate
- join path that exposes private row
- UPDATE policy broader than SELECT
- missing WITH CHECK
- service-role dependency leaking to client
- revoked Share still usable
- removed Team member still matching historical membership
- archived/inactive membership accidentally treated active

OUTPUT

For each table:
PASS / FAIL / NOT APPLICABLE
plus policy reference and fix.

Any cross-Team/private leak = BLOCKER.
```

---

# 11. M17.4 — Database-Level RLS Acceptance Suite

## Objective

Run exact RLS BLOCKER tests.

## Copy/Paste Prompt

```text
TASK ID: M17.4
TASK: RLS Acceptance Suite

RUN

AT-RLS-001
Student A1 cannot select Student A2 private object.

AT-RLS-002
Team B user cannot select Team A artifact.

AT-RLS-003
Removed member cannot select future Team A content.

AT-RLS-004
Student cannot update approved Artifact Version.

AT-RLS-005
Unauthorized user cannot insert Team A chat message.

AT-RLS-006
Unauthorized user cannot read private storage metadata.

AT-RLS-007
Unshared artifact cannot be exposed by join/query path.

All are BLOCKER.

IMPORTANT

Execute under actual authenticated database contexts.
Do not simulate only in application code.

RETURN

- SQL/test command
- test identity
- expected
- actual
- PASS/FAIL
- fix if failed
```

---

# 12. M17.5 — Direct-ID Attack Matrix

## Objective

Attempt unauthorized access using known valid IDs.

## Copy/Paste Prompt

```text
TASK ID: M17.5
TASK: Direct-ID Attacks

ATTACK AS UNAUTHORIZED USER

Known-valid IDs for:

- workspace
- project
- team
- chat message
- artifact
- artifact version
- activity instance
- development object
- evidence
- file
- patent record
- share
- AI output
- mind map
- vote/decision
- notification
- live room mapping if applicable

ROUTES

Attempt through:

- UI direct URL
- server route/action
- API
- database query under auth
- realtime subscription where applicable
- file signed-access endpoint
- AI context selection
- provider token endpoint

EXPECTED

`FORBIDDEN`
or safe `NOT_FOUND`

Never return protected content.

Check response metadata too:
- title
- filename
- project name
- owner
- existence hints

Priority:
BLOCKER.

DEFINITION OF DONE

Known IDs provide no authorization advantage.
```

---

# 13. M17.6 — End-to-End Privacy Attack

## Objective

Run AT-E2E-PRIV-001 exactly.

## Copy/Paste Prompt

```text
TASK ID: M17.6
TASK: AT-E2E-PRIV-001

SETUP

Team A has private:
- Workspace
- Project
- Chat
- Artifacts
- Files
- Evidence
- AI Outputs
- Patent research
- Mind Map
- Decisions

Team B has no Share unless explicitly created for one test.

ATTACK TEAM A FROM TEAM B THROUGH

- UI navigation
- direct URL
- API request
- database query under user auth
- realtime channel
- file URL/access
- shared-object relationship traversal
- AI context selection

ALSO TEST

- guessed IDs
- pagination/list endpoints
- search/filter endpoints
- error messages
- notification entity routes
- live-room routes if applicable

EXPECTED

No unauthorized content returned.

Priority:
BLOCKER / RELEASE GATE.

If any content leaks:
STOP RELEASE
FIX ROOT CAUSE
RERUN ENTIRE PRIVACY MATRIX
```

---

# 14. M17.7 — Member Removal End-to-End

## Objective

Run AT-E2E-MEMBER-001 exactly.

## Copy/Paste Prompt

```text
TASK ID: M17.7
TASK: AT-E2E-MEMBER-001

SCENARIO

1. A1 contributes:
   - Idea
   - Vote
   - Message
   - Artifact edit
2. Master removes A1 from Team A.
3. Verify future Team A access ends.
4. Verify Team A retains historical contributions.
5. A1 attempts Team A access via:
   - UI
   - API
   - direct IDs
   - chat
   - files
   - evidence
   - AI
   - live breakout token
6. Verify all future private access denied.
7. Verify audit records removal.
8. Verify A1 Personal Workspace remains intact.

Priority:
RELEASE GATE.

IMPORTANT

Do not remove historical attribution merely to simplify access.

DEFINITION OF DONE

Removal affects future authorization while preserving history.
```

---

# 15. M17.8 — AI Leakage Release Suite

## Objective

Run complete AI leakage tests again against release build.

## Copy/Paste Prompt

```text
TASK ID: M17.8
TASK: AI Leakage Release Suite

RUN

AT-AI-002
Team A AI receives Team A authorized context only.

AT-AI-003
A1 Personal AI cannot expose A2 Personal content.

AT-AI-004
Removed member gets no former Team context.

AT-AI-LEAK-001
A1 asks for best solution from other teams.

AT-AI-LEAK-002
B1 manually supplies Team A Artifact ID.

AT-AI-LEAK-003
Previously shared Team A Artifact is revoked, then B1 requests AI analysis.

VERIFY PROVIDER PAYLOAD

Do not test response only.
Inspect mocked/instrumented provider request.

UNAUTHORIZED CONTENT MUST NOT LEAVE FICI.

Also verify:
- hidden Brainstorm entries excluded
- private Chat excluded unless explicitly selected
- revoked Share excluded
- inaccessible Evidence/Patent IDs rejected
- File IDs do not reveal content to model

All unauthorized-context leaks = BLOCKER.
```

---

# 16. M17.9 — AI Governance Release Scenario

## Objective

Run AT-E2E-AI-001 exactly.

## Copy/Paste Prompt

```text
TASK ID: M17.9
TASK: AT-E2E-AI-001

SCENARIO

1. Team A runs AI on Gap G1.
2. AI suggests Solution S-AI.
3. Save output as AI_SUGGESTION / UNVERIFIED.
4. Team reviews.
5. Team saves as Candidate.
6. Evidence added.
7. Team records Decision.
8. New Draft Artifact Version created.
9. Master reviews.
10. Only after human approval does new Version become CURRENT.

VERIFY

AI never:
- becomes Evidence automatically
- votes
- decides
- approves
- sets CURRENT
- changes permissions
- alters baseline silently

Priority:
RELEASE GATE.
```

---

# 17. M17.10 — Approval Transaction Rollback

## Objective

Run AT-TX-001.

## Copy/Paste Prompt

```text
TASK ID: M17.10
TASK: Approval Rollback

SCENARIO

Artificially fail one step of approval transaction.

EXPECTED

No partial state:
- current pointer unchanged
- Version statuses unchanged
- no false approval audit
- no false approval notification
- dependent Activity not incorrectly unlocked
- no email claiming success

Priority:
BLOCKER.

TEST FAILURE POINTS

- after validation
- after Version status change
- before current pointer update
- before audit insert
- before notification insert

Use transaction boundaries.

DEFINITION OF DONE

Approval is all-or-nothing.
```

---

# 18. M17.11 — Team Creation Rollback

## Objective

Run AT-TX-002.

## Copy/Paste Prompt

```text
TASK ID: M17.11
TASK: Team Creation Rollback

SCENARIO

Force Chat Channel creation failure during official Team creation.

EXPECTED

No inconsistent half-created Team
unless documented recovery design explicitly supports it.

VERIFY

- Team row
- membership
- Workspace
- Chat Channel
- audit
- notification

Priority:
HIGH.

If recovery model exists:
verify deterministic recoverability.

DEFINITION OF DONE

Team creation does not leave ambiguous official state.
```

---

# 19. M17.12 — Concurrency Release Tests

## Objective

Run concurrency tests against release candidate.

## Copy/Paste Prompt

```text
TASK ID: M17.12
TASK: Concurrency Tests

RUN

AT-CON-001
Two users edit same Draft.
System merges safely or detects conflict.
No silent overwrite.

AT-CON-002
Competing approval/revision actions.
Prevent contradictory final state.
BLOCKER.

ALSO RETEST HIGH-RISK CONCURRENCY

- Dot Vote limit
- duplicate Activity start
- Mind Map checkpoint save
- Share create/revoke race
- Candidate conversion retry
- Notification retry
- live-room create retry

DEFINITION OF DONE

No known race can produce contradictory canonical state.
```

---

# 20. M17.13 — Full Professional Course E2E

## Objective

Run AT-E2E-001 exactly.

## Copy/Paste Prompt

```text
TASK ID: M17.13
TASK: AT-E2E-001 — Full Professional Course Core Scenario

RUN THIS EXACT SCENARIO

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
25. Approved output becomes available to dependent next Activity.
26. Previous Versions remain accessible.
27. Team B never sees Team A private content.

EXPECTED

All steps succeed with correct:
- permissions
- provenance
- history
- state transitions
- RLS
- notifications where relevant

Priority:
MVP RELEASE GATE.

CAPTURE

- test run ID
- screenshots/log references if appropriate
- IDs of key entities
- final PASS/FAIL
```

---

# 21. M17.14 — Curriculum Dependency Release Tests

## Objective

Reconfirm downstream reuse and baseline correctness.

## Copy/Paste Prompt

```text
TASK ID: M17.14
TASK: Curriculum Dependency Tests

RUN

AT-CUR-001
Session 4 Problem Bank becomes valid input to Session 5.

AT-CUR-002
Session 10 AI refinement receives intended current/approved baseline, not arbitrary old Draft.

VERIFY

- stable Project IDs
- stable Development Object IDs
- approved Artifact Version references
- Activity dependency resolution
- no duplicate Project Objects

DEFINITION OF DONE

The platform actually carries work forward across Sessions.
```

---

# 22. M17.15 — Historical Integrity Review

## Objective

Verify project history cannot be silently destroyed.

## Copy/Paste Prompt

```text
TASK ID: M17.15
TASK: Historical Integrity Review

VERIFY

- removed member historical authorship retained
- prior chat messages retained
- prior votes retained
- old Artifact Versions retained
- superseded Decisions retained
- revoked Shares retained as history
- prior AI Outputs retained if referenced
- Evidence history not overwritten
- approved Version immutable
- Project continues across Sessions
- object reuse preserves stable IDs

ATTACK

Try destructive update/delete paths through:
- client
- API
- direct DB under normal auth

Any path that erases required development history is at least HIGH and may be BLOCKER if it violates acceptance.

DEFINITION OF DONE

Traceability is preserved.
```

---

# 23. M17.16 — File Security & Limits

## Objective

Harden file handling before pilot.

## Copy/Paste Prompt

```text
TASK ID: M17.16
TASK: File Security & Limits

Read:
- Technical Architecture File Security
- M12 File implementation

VERIFY

- allowed MIME validation
- configured file-size limit
- uploader permission
- private bucket/storage
- signed access
- signed URL expiry
- no raw public URL
- storage path generated server-side
- Team isolation
- Personal file privacy
- removed-member denial
- Share-aware access
- archive behavior

ATTACK

- spoof MIME
- oversized upload
- arbitrary storage path
- guessed File ID
- guessed storage reference
- expired signed URL
- revoked Share
- cross-Team link

Do not add malware scanning unless already approved/required.

DEFINITION OF DONE

File upload/access passes pilot security requirements.
```

---

# 24. M17.17 — Rate Limiting

## Objective

Apply practical rate limits to abuse-sensitive endpoints.

## Copy/Paste Prompt

```text
TASK ID: M17.17
TASK: Rate Limiting

Technical Architecture requires rate limiting for:

- login-sensitive endpoints
- AI endpoints
- invitations
- share endpoints
- file upload signing
- realtime authentication endpoints

VERIFY

1. server-side enforcement.
2. consistent error response.
3. no client-only limit.
4. user/IP/key strategy appropriate to endpoint.
5. legitimate pilot flows not blocked unnecessarily.
6. retry-after behavior where supported.
7. limits configurable by environment.

AI additionally needs product-level usage hooks already created in M14.

Do not invent commercial pricing quotas.

TEST

- burst request
- authenticated burst
- cross-account abuse
- reset/window behavior

DEFINITION OF DONE

Abuse-sensitive endpoints have practical pilot protection.
```

---

# 25. M17.18 — Error Handling Review

## Objective

Ensure errors are safe, understandable, and non-leaking.

## Copy/Paste Prompt

```text
TASK ID: M17.18
TASK: Error Handling Review

VERIFY

User-facing errors are:

- readable
- actionable where appropriate
- stable
- free of stack traces
- free of secrets
- free of SQL internals
- free of provider API keys
- free of inaccessible-resource details

SECURITY RULE

Permission errors must not reveal whether protected resources exist.

TEST

- unauthorized ID
- invalid state
- malformed input
- provider timeout
- database conflict
- AI validation failure
- file access denial
- share revoked
- Activity dependency failure
- live room provider failure

DEFINITION OF DONE

Errors help legitimate users without helping attackers.
```

---

# 26. M17.19 — Structured Logging

## Objective

Ensure production debugging is possible without leaking secrets.

## Copy/Paste Prompt

```text
TASK ID: M17.19
TASK: Structured Logging

MVP OBSERVABILITY

Use:
- Vercel deployment/runtime logs
- Supabase logs
- provider dashboards
- structured application logs

ERROR LOGS SHOULD INCLUDE WHEN APPROPRIATE

- request/correlation ID
- user ID
- operation
- project/workspace ID
- error code
- provider/task identifier
- safe timing metadata

MUST NOT LOG

- passwords
- API secrets
- session tokens
- signed URLs if sensitive
- full private files
- entire confidential prompts
- full private Evidence content unless explicitly safe

VERIFY

- log format structured
- correlation possible across server request
- provider failures traceable
- auth failures safe

Sentry is SHOULD HAVE after foundation, not mandatory if not already selected.

DEFINITION OF DONE

Pilot incidents can be investigated safely.
```

---

# 27. M17.20 — Security Headers & Session Protection

## Objective

Harden production HTTP/session behavior.

## Copy/Paste Prompt

```text
TASK ID: M17.20
TASK: Security Headers & Session Protection

VERIFY PRODUCTION CONFIG

- HTTPS only
- secure cookies
- Content Security Policy where practical
- frame restrictions compatible with embedded Daily
- referrer policy
- MIME sniffing protection
- framework/provider-recommended CSRF/session handling

IMPORTANT

Daily embedded video may require CSP exceptions.
Use exact minimal provider domains.
Do not disable CSP globally just to make embedding easier.

SERVER MUTATIONS

- authenticated session required
- authorization required
- never trust client user ID

TEST

- cookie flags
- iframe behavior
- Daily still works
- protected mutation without session denied

DEFINITION OF DONE

Baseline web-security headers/session handling are pilot-ready.
```

---

# 28. M17.21 — Backup Configuration Review

## Objective

Confirm production backup capability.

## Copy/Paste Prompt

```text
TASK ID: M17.21
TASK: Backup Configuration

VERIFY

1. production database backup plan is enabled.
2. backup retention is documented.
3. environment/project identifiers documented.
4. responsible operator identified.
5. restore permissions/access understood.
6. file-storage recovery limitations documented.

Technical Architecture expects paid production backups before pilot.

Do not claim backup readiness from provider marketing alone.

Provide evidence/configuration reference.

DEFINITION OF DONE

Backup configuration is confirmed and documented.
```

---

# 29. M17.22 — Non-Production Database Restore Test

## Objective

Perform at least one actual recovery test.

## Copy/Paste Prompt

```text
TASK ID: M17.22
TASK: Database Restore Test

REQUIREMENT

Perform one recovery test in non-production.

SAFE PLAN

1. create/select non-production environment.
2. record known test data.
3. take/use backup according to provider method.
4. restore into safe non-production target.
5. verify:
   - users/profiles where appropriate
   - Projects
   - Artifacts/Versions
   - Evidence metadata
   - Shares
   - AI Outputs
   - Notifications
6. run integrity checks.
7. document elapsed time and manual steps.
8. do not overwrite production.

FILE STORAGE

Document separately whether/how storage objects are recovered.

OUTPUT

Create restore runbook + test result.

Priority:
HIGH.
```

---

# 30. M17.23 — Data Portability Check

## Objective

Verify FICI does not depend on inaccessible provider-only state.

## Copy/Paste Prompt

```text
TASK ID: M17.23
TASK: Data Portability

VERIFY FICI CAN EXPORT / RECOVER

- PostgreSQL database
- storage files
- Project data
- Artifact Versions
- AI Outputs
- Evidence metadata
- Decision history
- Share history

PROVIDER-SPECIFIC EXTERNAL STATE

- Liveblocks
- Daily
- OpenAI
- Resend

must not contain the only copy of business-critical canonical state.

DEFINITION OF DONE

Provider replacement does not erase FICI project memory.
```

---

# 31. M17.24 — Accessibility Review

## Objective

Run required MVP accessibility checks.

## Copy/Paste Prompt

```text
TASK ID: M17.24
TASK: Accessibility Review

VERIFY

- keyboard access to standard forms/buttons
- visible focus
- labels for inputs
- meaningful button text
- dialog focus behavior
- color is not the only status indicator
- readable error messages
- structured/list alternative for canvas-like tools where practical

TEST HIGH-VALUE FLOWS

- login
- course navigation
- Activity start
- SCAMPER/Brainstorming
- submit/review
- notifications
- sharing
- AI request/result
- Mind Map fallback/list
- live classroom surrounding controls

FIX defects without redesigning product.

OUTPUT

PASS/FAIL per flow + remaining limitations.
```

---

# 32. M17.25 — Browser Compatibility

## Objective

Test current major browsers.

## Copy/Paste Prompt

```text
TASK ID: M17.25
TASK: Browser Acceptance

TEST CURRENT VERSIONS OF

- Chrome
- Edge
- Safari
- Firefox

Desktop web is primary MVP target.

RUN CORE FLOWS

- auth
- Student current work
- Team Workspace
- chat
- sharing
- file access
- submit/review
- AI
- Mind Map
- Daily live classroom

RECORD

- browser version
- OS
- PASS/FAIL
- known issue
- severity
- workaround

Prioritize actual pilot audience.

Do not claim support for an untested browser.
```

---

# 33. M17.26 — Responsive Acceptance

## Objective

Verify core non-canvas workflows remain usable.

## Copy/Paste Prompt

```text
TASK ID: M17.26
TASK: Responsive Acceptance

TEST

- desktop
- tablet
- reasonable mobile viewport

CORE NON-CANVAS FLOWS

- login
- course/session navigation
- Activity instructions
- notifications
- chat
- share
- submit
- feedback/revision
- AI output
- file access

MIND MAP / COMPLEX COLLABORATION

May be optimized for desktop/tablet in MVP.

Do not force full mobile parity for complex node editing.

DEFINITION OF DONE

Core pilot workflow is usable across required viewports.
```

---

# 34. M17.27 — Performance Smoke Tests

## Objective

Measure practical pilot responsiveness.

## Copy/Paste Prompt

```text
TASK ID: M17.27
TASK: Performance Smoke Tests

Acceptance guidance:

PAGE / DATA
Normal Workspace navigation should feel responsive under pilot load.

CHAT
New Team message should normally appear to connected teammates within a few seconds.

AI
AI may take longer, but UI must show progress and not block unrelated platform actions.

COLLABORATIVE TOOLS
Mind Map/Affinity should feel interactive for normal small Teams.

TEST WITH PILOT-LIKE FIXTURE

- multiple Teams
- realistic Project history
- Artifact Versions
- Chat history
- Evidence/Patents
- AI Outputs

MEASURE

- initial key page load
- common query latency
- chat delivery
- collaborative interaction
- AI UI responsiveness/non-blocking behavior

No need to invent enterprise SLA.

Document measured baseline.
```

---

# 35. M17.28 — Realtime Security/Recovery

## Objective

Retest realtime boundaries globally.

## Copy/Paste Prompt

```text
TASK ID: M17.28
TASK: Realtime Release Tests

RUN

AT-RT-001
Authorized Team receives Team events.

AT-RT-002
Unauthorized Team subscription denied.
BLOCKER.

AT-RT-003
After disconnect, canonical database state reloads.

COVER

- Team Chat
- Notifications
- Affinity/Mind Map where applicable

VERIFY

- channel naming not authorization
- removed member denied future subscription
- reconnect reloads canonical PostgreSQL state

DEFINITION OF DONE

Realtime cannot bypass RLS/scope and is not source of truth.
```

---

# 36. M17.29 — Share Security Regression

## Objective

Retest Sharing after all later integrations.

## Copy/Paste Prompt

```text
TASK ID: M17.29
TASK: Sharing Security Regression

RUN

AT-SHARE-001
AT-SHARE-002 BLOCKER
AT-SHARE-003 BLOCKER
AT-SHARE-004
AT-SHARE-005

ALSO VERIFY

- Files through Share
- AI through Share
- Notifications after revoke
- Mind Map rendering
- direct source relationship traversal
- version history exposure
- recipient re-share denied by default

DEFINITION OF DONE

Later features have not widened Share boundaries.
```

---

# 37. M17.30 — File Authorization Regression

## Objective

Retest M12 file acceptance under final app.

## Copy/Paste Prompt

```text
TASK ID: M17.30
TASK: File Authorization Release Tests

RUN

AT-FILE-001
Personal File privacy.
BLOCKER.

AT-FILE-002
Team File isolation.
BLOCKER.

AT-FILE-003
Signed access expires.

ATTACK THROUGH

- direct ID
- guessed path
- old signed URL
- Share relationship
- Notification route
- AI context
- archived File

DEFINITION OF DONE

Final application has no file authorization bypass.
```

---

# 38. M17.31 — Artifact / Version Integrity Regression

## Objective

Confirm M8 guarantees after all integrations.

## Copy/Paste Prompt

```text
TASK ID: M17.31
TASK: Artifact Version Integrity

VERIFY

- approved Version immutable
- new revision creates new Version
- current pointer transactionally correct
- AI cannot overwrite approved Version
- COMMENT Share cannot edit source
- Student cannot update approved Version
- prior Versions remain accessible
- review history retained
- dependent Activities consume intended approved output

Any mutable approved Version path = BLOCKER.
```

---

# 39. M17.32 — Voting / Decision Governance Regression

## Objective

Ensure no later features changed human decision rules.

## Copy/Paste Prompt

```text
TASK ID: M17.32
TASK: Voting & Decision Governance Regression

VERIFY

- vote limit enforced
- Team B cannot vote Team A
- closing vote does not auto-finalize Decision
- AI does not vote
- Decision reasoning retained
- superseded Decision retained
- AI recommendation does not become Decision
- Decision links Evidence safely

Re-run:
AT-VOTE suite
AT-DEC suite

Any automatic vote/AI → final Decision path is a governance defect.
```

---

# 40. M17.33 — Evidence / Patent Integrity Regression

## Objective

Ensure source/analysis separation survives AI integration.

## Copy/Paste Prompt

```text
TASK ID: M17.33
TASK: Evidence & Patent Integrity

VERIFY

- Evidence defaults UNVERIFIED
- AI Output is not Evidence
- Patent Record remains source metadata
- Patent AI Analysis remains labeled Analysis
- no novelty/patentability auto-conclusion
- Evidence links preserve source
- Team B cannot read private patent research notes

RUN

AT-EV suite
AT-PAT suite

AT-EV-002 and AT-PAT-002 are especially critical.

DEFINITION OF DONE

Source evidence, analysis, and decisions remain distinct.
```

---

# 41. M17.34 — Activity Dependency Regression

## Objective

Ensure dependency enforcement still works.

## Copy/Paste Prompt

```text
TASK ID: M17.34
TASK: Activity Dependency Regression

VERIFY

- unavailable Activity cannot start
- missing dependency → DEPENDENCY_NOT_MET
- completed/approved output becomes available to dependent Activity
- current approved baseline used
- later Sharing/AI does not bypass dependency logic
- no UI-only enforcement

RUN

AT-ACT-001
AT-ACT-002
AT-ACT-003
AT-ACT-004

DEFINITION OF DONE

Curriculum progression remains server-enforced.
```

---

# 42. M17.35 — Authentication / RBAC Regression

## Objective

Re-run auth/security foundation.

## Copy/Paste Prompt

```text
TASK ID: M17.35
TASK: Authentication & RBAC Regression

RUN

AT-AUTH-001
AT-AUTH-002
AT-AUTH-003
AT-AUTH-004 BLOCKER

AT-RBAC-001 BLOCKER
AT-RBAC-002 BLOCKER
AT-RBAC-003 BLOCKER

VERIFY

- client user ID spoofing fails
- Student cannot Admin
- Master limited to assigned Cohort
- Mentor limited to assigned scope
- protected routes deny anonymous access
- suspended/inactive account handling matches implementation policy

DEFINITION OF DONE

Foundation security remains intact.
```

---

# 43. M17.36 — Personal Workspace Regression

## Objective

Retest private-first behavior.

## Copy/Paste Prompt

```text
TASK ID: M17.36
TASK: Personal Workspace Regression

RUN

AT-PW-001
AT-PW-002 BLOCKER
AT-PW-004 selected sharing

VERIFY

- A1 private data not visible to A2
- selected Personal → Team Share only exposes selected entities
- Personal AI respects owner privacy
- Personal Files private
- Personal work not leaked in Master progress overview

DEFINITION OF DONE

Personal Workspace remains private by default.
```

---

# 44. M17.37 — Team / Chat Regression

## Objective

Retest Team lifecycle and chat.

## Copy/Paste Prompt

```text
TASK ID: M17.37
TASK: Team & Chat Regression

RUN

AT-TEAM-003 BLOCKER
AT-TEAM-004 BLOCKER
AT-TEAM-005 BLOCKER

AT-CHAT-001
AT-CHAT-002 BLOCKER
AT-CHAT-003 BLOCKER
AT-CHAT-004

VERIFY

- removal ends future access
- move Team A → B does not copy Team A private content
- chat persists
- Team B cannot read Team A chat via list/direct/realtime
- removed user cannot send

DEFINITION OF DONE

Team collaboration remains isolated and historically correct.
```

---

# 45. M17.38 — Audit Review

## Objective

Verify critical events remain traceable.

## Copy/Paste Prompt

```text
TASK ID: M17.38
TASK: Audit Release Review

RUN

AT-AUD-001
Membership add/remove/move audit.

AT-AUD-002
Approval audit includes actor/timestamp/artifact/version.

AT-AUD-003
Share/revoke audit.

ALSO REVIEW

- AI Candidate conversion
- Decision supersession
- Evidence verification if implemented
- sensitive role assignment

VERIFY

Audit does not contain:
- secrets
- passwords
- full sensitive content

DEFINITION OF DONE

Critical governance events are traceable.
```

---

# 46. M17.39 — Pilot Admin Acceptance

## Objective

Confirm real pilot administration works.

## Copy/Paste Prompt

```text
TASK ID: M17.39
TASK: Pilot Admin Acceptance

VERIFY ADMIN CAN

- create Cohort
- add Master
- invite/enroll Students
- create/manage Teams
- view active users
- resolve membership errors

Priority:
MUST PASS.

Run as realistic production-role user.

Do not use service-role shortcuts to "prove" the flow.
```

---

# 47. M17.40 — Pilot Master Acceptance

## Objective

Confirm the Master can operate the course.

## Copy/Paste Prompt

```text
TASK ID: M17.40
TASK: Pilot Master Acceptance

VERIFY MASTER CAN

- open assigned Cohort
- see Teams
- launch Activities
- inspect submitted work
- comment
- request revision
- approve
- see basic progress
- open live classroom where applicable

VERIFY ALSO

- unrelated Cohort denied
- notifications correct
- approval transaction safe

Priority:
MUST PASS.
```

---

# 48. M17.41 — Pilot Student Acceptance

## Objective

Confirm normal Student workflow.

## Copy/Paste Prompt

```text
TASK ID: M17.41
TASK: Pilot Student Acceptance

VERIFY STUDENT CAN

- log in
- access Course
- use Personal Workspace
- access assigned Team
- use core tools
- chat
- share
- submit
- receive feedback
- revise
- see approval/current output
- use AI where allowed
- join live class where allowed

VERIFY

No unauthorized Team/Personal access.

Priority:
MUST PASS.
```

---

# 49. M17.42 — Production Environment Validation

## Objective

Verify deployment configuration without exposing secrets.

## Copy/Paste Prompt

```text
TASK ID: M17.42
TASK: Production Environment Validation

VERIFY REQUIRED ENVIRONMENT VARIABLES EXIST

Examples based on implemented stack:
- Supabase URL / public client key
- server/service credentials where used
- OpenAI server key
- Resend server key
- Daily server key
- Liveblocks server secret
- application URL/base URL

DO NOT PRINT SECRET VALUES.

VERIFY

- production URLs correct
- no localhost callback
- no development bypass
- no test account seeded with known weak password unless intentionally isolated
- correct Supabase project
- private Storage
- migrations applied
- production build successful

DEFINITION OF DONE

Production environment is configured without secret exposure.
```

---

# 50. M17.43 — Migration Integrity

## Objective

Verify database can be reproduced from committed migrations.

## Copy/Paste Prompt

```text
TASK ID: M17.43
TASK: Migration Integrity

OBJECTIVE

On a clean non-production database:

1. apply all committed migrations from M0–M16.
2. verify schema matches expected production structure.
3. seed only approved test/reference data.
4. run migration-related smoke tests.
5. verify RLS enabled.
6. verify no manual production-only schema drift.

CHECK

- enum values
- foreign keys
- indexes
- constraints
- RLS policies
- functions/triggers
- storage configuration docs

DEFINITION OF DONE

Database is reproducible from repository.
```

---

# 51. M17.44 — Dependency / Package Security Review

## Objective

Perform practical dependency review before pilot.

## Copy/Paste Prompt

```text
TASK ID: M17.44
TASK: Dependency Security Review

VERIFY

- lockfile committed
- no accidental `latest` production pin where architecture says exact versions
- production dependencies necessary
- known severe vulnerabilities reviewed
- deprecated/abandoned package warnings reviewed
- no secret-containing package config committed

Do not blindly major-upgrade packages during release hardening.

Only upgrade when:
- required for security,
- compatible,
- tested.

Document remaining dependency risk.
```

---

# 52. M17.45 — Build / Type / Static Validation

## Objective

Create a clean release candidate build.

## Copy/Paste Prompt

```text
TASK ID: M17.45
TASK: Build Validation

RUN

pnpm lint
pnpm typecheck
pnpm test:unit
pnpm test:integration
pnpm test:e2e
pnpm build

Also run:
- RLS test suite
- migration test
- security-specific tests
- provider mocks/integration tests

RULE

Do not ignore warnings that indicate:
- unsafe TypeScript
- missing React keys affecting state
- server/client secret boundary issue
- unreachable error path
- hydration issue
- failed database type generation

OUTPUT

Exact commands + exit results + remaining warnings.
```

---

# 53. M17.46 — Release Candidate Smoke Test

## Objective

Run a short production-like smoke test after deployment.

## Copy/Paste Prompt

```text
TASK ID: M17.46
TASK: Release Candidate Smoke Test

ON STAGING / RELEASE CANDIDATE

VERIFY

- login
- protected routing
- Cohort access
- Student overview
- Master overview
- Team Chat
- Activity open/start
- Artifact load
- file signed access
- Share
- AI provider call
- notification
- Daily live room
- logout

Do not use production user confidential data.

DEFINITION OF DONE

Deployed build matches local/CI behavior.
```

---

# 54. M17.47 — MVP Release Checklist

## Objective

Complete the exact checklist from `12_ACCEPTANCE_TESTS.md`.

## Copy/Paste Prompt

```text
TASK ID: M17.47
TASK: MVP Release Checklist

Mark each only with evidence:

[ ] Authentication passes
[ ] Roles/scopes pass
[ ] Personal privacy passes
[ ] Team isolation passes
[ ] Member removal passes
[ ] Team chat passes
[ ] Sharing passes
[ ] Project continuity passes
[ ] Activity dependency passes
[ ] Core method tools pass
[ ] Evidence separation passes
[ ] Patent Record workflow passes
[ ] Submission/revision/approval passes
[ ] Version history passes
[ ] AI context security passes
[ ] AI provenance passes
[ ] AI cannot auto-approve
[ ] RLS tests pass
[ ] Direct-ID attack tests pass
[ ] File authorization passes
[ ] Transaction rollback tests pass
[ ] E2E core workflow passes
[ ] E2E privacy scenario passes
[ ] No open BLOCKER defects

FOR EACH CHECKBOX

Attach:
- test ID(s)
- command/test evidence
- status
- relevant issue reference if failed

DO NOT CHECK A BOX WITHOUT EVIDENCE.

DEFINITION OF DONE

Every checkbox is evidence-backed.
```

---

# 55. M17.48 — Defect Triage

## Objective

Classify every remaining issue consistently.

## Copy/Paste Prompt

```text
TASK ID: M17.48
TASK: Final Defect Triage

CLASSIFY

BLOCKER
Cannot pilot.

HIGH
Major workflow broken; workaround may exist but risk is substantial.

MEDIUM
Important but workable.

LOW
Usability/polish.

FOR EACH ISSUE

Record:
- ID
- title
- severity
- affected module
- reproduction
- expected
- actual
- security/privacy impact
- workaround
- owner
- status
- release decision

RULE

Do not downgrade severity just to launch.

Any:
- cross-Team leak
- private Workspace leak
- unauthorized approval
- AI unauthorized-context leak
- file authorization bypass
must remain BLOCKER.
```

---

# 56. M17.49 — Final Pilot Readiness Report

## Objective

Produce the final release artifact.

## Copy/Paste Prompt

```text
TASK ID: M17.49
TASK: Pilot Readiness Report

CREATE

/docs/PILOT_READINESS_REPORT.md

INCLUDE

# 1 Executive Summary
- release candidate version/commit
- environment
- overall status:
  READY FOR PILOT
  or
  NOT READY FOR PILOT

# 2 Scope
- M0–M16 implemented areas
- explicit deferred/non-goal areas

# 3 Release Gates
Status of:
- AT-E2E-001
- AT-E2E-PRIV-001
- AT-E2E-MEMBER-001
- AT-E2E-AI-001
- all BLOCKER tests

# 4 MVP Release Checklist
Copy exact checklist with evidence.

# 5 Security Review
- RLS
- direct ID
- file
- AI
- sharing
- realtime
- live classroom

# 6 Transaction / Concurrency
- approval rollback
- Team creation rollback
- competing review
- collaborative edits

# 7 Browser / Accessibility / Responsive
Results and limitations.

# 8 Backup / Recovery
- backup configuration
- restore test
- storage recovery limitations

# 9 Observability / Rate Limits
- logging
- error handling
- rate-limit coverage

# 10 Pilot Acceptance
- Admin
- Master
- Student

# 11 Remaining Issues
Separate:
- BLOCKER
- HIGH
- MEDIUM
- LOW

# 12 Known Limitations / Deferred
Only approved/deferred items.

# 13 Operational Runbook
- deploy
- rollback
- restore
- provider outage notes
- key support contacts/roles placeholders

# 14 Final Recommendation
If zero BLOCKER and all release gates pass:
READY FOR PILOT.
Otherwise:
NOT READY FOR PILOT.

IMPORTANT

Do not hide failed tests.
Do not use vague language.
Provide evidence references.
```

---

# 57. M17.50 — Final Release Decision Gate

## Objective

Make the release state unambiguous.

## Copy/Paste Prompt

```text
TASK ID: M17.50
TASK: Final Release Decision Gate

CHECK

1. All mandatory acceptance tests executed?
2. All BLOCKER tests pass?
3. AT-E2E-001 pass?
4. AT-E2E-PRIV-001 pass?
5. AT-E2E-MEMBER-001 pass?
6. AT-E2E-AI-001 pass?
7. MVP Release Checklist complete?
8. Backup/recovery tested?
9. Browser/accessibility review done?
10. Pilot Admin/Master/Student acceptance pass?
11. No known private-data leak?
12. No unauthorized approval path?
13. No AI permission leak?

IF ANY REQUIRED ANSWER = NO

STATUS:
NOT READY FOR PILOT

IF ALL REQUIRED ANSWERS = YES

STATUS:
READY FOR PILOT

Do not return "mostly ready" as the release-gate status.

List remaining non-BLOCKER issues separately.
```

---

# 58. Full E2E Must Use Real Role Boundaries

Do not execute the entire E2E as one privileged service role.

Use actual test identities:

```text
Admin
Master
Mentor where relevant
Student A1
Student A2
Student B1
Student B2
```

Switch identities as the real product would.

Otherwise permission behavior is not tested.

---

# 59. Release Test Fixtures

Use the standard acceptance fixture where defined:

```text
Professional Course — Test Cohort

Team A
Team B

Project A → Team A
Project B → Team B

Personal Workspace per Student
```

Use stable fixtures to make security tests reproducible.

---

# 60. Never Weaken RLS to Fix E2E

If a feature works only after broadening an RLS policy such as:

```text
authenticated users can SELECT all
```

the fix is invalid.

Instead:

```text
identify required scope
→ authorize exactly
→ test positive and negative paths
```

---

# 61. Never Replace Server Authorization With UI Hiding

Example invalid fix:

```text
Hide "Approve" button from Students
```

if Students can still call approval endpoint.

M17 must attack backend directly.

---

# 62. Never Replace Database Security With API Security Alone

For protected data, application authorization and RLS should reinforce each other where the architecture requires RLS.

A direct authenticated database query must still be safe.

---

# 63. Never Fix Privacy Leak by Obscuring IDs

UUIDs reduce guessing.

They do not provide authorization.

Known valid IDs must still fail for unauthorized users.

---

# 64. Error Response Safety

For protected resources, safe outcomes include:

```text
FORBIDDEN
```

or:

```text
NOT_FOUND
```

depending on established API semantics.

Do not return:

```text
"Artifact exists but belongs to Team A"
```

to Team B.

---

# 65. Historical Attribution

M17 must protect the principle:

```text
Access can end.
History remains.
```

Removed user contributions stay attributed.

Do not anonymize/delete authorship as an authorization fix unless policy requires it.

---

# 66. Approval Integrity

Approval is a high-risk multi-step operation.

The final state must never contain contradictions such as:

```text
Version = APPROVED
but
Artifact.current_version_id = old version
```

or:

```text
notification says approved
but transaction rolled back
```

AT-TX-001 must actively inject failure.

---

# 67. Share Revocation Integrity

After Share revocation:

- future entity access denied,
- future signed File access denied,
- future AI context denied,
- Share history retained,
- notification history may remain,
- recipient does not gain source Workspace.

Retest all integrations, not only M13 endpoint.

---

# 68. AI Provider Payload Is the Security Boundary

A response filter is too late.

Unauthorized content must not be sent to provider in the first place.

M17 must inspect provider payloads in tests.

---

# 69. File URLs Are Capabilities

Signed File URLs should:

- be temporary,
- be issued after authorization,
- not be stored as permanent public references.

Do not log reusable signed URLs broadly.

---

# 70. Realtime Is Not Canonical

For:

- chat,
- notifications,
- Affinity,
- Mind Map,

disconnect/reconnect must recover from canonical saved state.

Realtime event loss must not equal data loss.

---

# 71. Liveblocks Is Not Canonical

Mind Map/Affinity final saved state must remain reconstructable from PostgreSQL/Artifact Versions.

If Liveblocks is unavailable, previously saved canonical work must remain.

---

# 72. Daily Is Not Canonical

Live video outage must not affect:

- Projects,
- Activities,
- Artifacts,
- Decisions,
- course state.

---

# 73. OpenAI Is Not Canonical

AI provider outage must not affect existing Project history.

Saved AI Outputs belong to FICI database.

---

# 74. Resend Is Not Canonical

Email delivery failure must not roll back:

- Submission,
- Review,
- Approval,
- Team membership,
- Share.

In-app canonical state remains.

---

# 75. Backup Test Must Be Real

A backup checkbox cannot be satisfied by:

```text
"Supabase says backups exist"
```

At least one non-production restore test is required.

---

# 76. File Recovery Limitation Must Be Explicit

Database backup and object-storage recovery are not necessarily the same.

Document:

- database restore,
- storage restore/export,
- irreversible limitations,
- manual steps.

Do not imply storage recovery exists if untested.

---

# 77. Logging Must Not Become a Data Leak

Structured logs can leak data.

Redact/minimize:

- secrets,
- tokens,
- signed URLs,
- private prompts,
- private files,
- full chat content,
- raw Evidence.

---

# 78. Rate Limiting Is Defense-in-Depth

Rate limiting does not replace:

- auth,
- authorization,
- validation,
- RLS.

A slow unauthorized attack is still unauthorized.

---

# 79. File Size and MIME Limits

Exact product-facing limits may be configuration values.

M17 should verify:

- a limit exists,
- it is enforced server-side,
- oversized files fail safely.

If exact values remain open, record them as configuration requiring Ahmad/FICI approval.

Do not invent business limits silently.

---

# 80. Accessibility Is a Release Quality Requirement

Do not treat accessibility only as post-pilot polish.

Fix straightforward HIGH-impact issues such as:

- unlabeled form fields,
- inaccessible dialog focus,
- no keyboard submission,
- status shown only by color.

Complex canvas alternative may remain a documented limitation if the structured alternative is practical.

---

# 81. Browser Testing Must Include Real Provider Components

Where feasible, include:

- Liveblocks collaborative tool,
- Daily embedded room,
- AI UI,
- signed file flows.

A page-only smoke test is insufficient.

---

# 82. Performance Is Practical, Not Enterprise SLA

M17 should measure realistic pilot behavior.

Do not redesign architecture for millions of users.

Only fix performance problems that materially impair pilot use.

---

# 83. Release Candidate Versioning

The final report must name:

- Git commit SHA,
- deployment URL/environment,
- migration state,
- release date/time,
- test-run identifier.

Do not release from an untracked local tree.

---

# 84. Clean Working Tree

Before final release:

```text
git status
```

should show no accidental uncommitted release code.

Generated local debug files/secrets must not be committed.

---

# 85. Secret Scan

Search for accidental secrets:

- Supabase service role key
- OpenAI key
- Daily API key
- Resend key
- Liveblocks secret
- tokens/passwords

Check:

- repository files
- tests
- snapshots
- logs
- example env
- client bundle references

Any real secret committed:
BLOCKER until revoked/rotated and removed appropriately.

---

# 86. Production Data Safety

M17 tests should primarily run in isolated test/staging environments.

Do not:

- destructively run rollback tests on production,
- restore over production,
- create fake pilot artifacts in production unless explicitly planned,
- expose real user confidential data in screenshots/logs.

---

# 87. Security Defect Fix Rule

When a BLOCKER is found:

```text
REPRODUCE
→ IDENTIFY ROOT CAUSE
→ FIX
→ ADD REGRESSION TEST
→ RERUN RELATED SUITE
→ RERUN RELEASE-GATE SCENARIO
```

Do not merely patch the exact test input.

---

# 88. Documentation Contradiction Rule

If code behavior required to pass one acceptance test contradicts another approved document:

```text
STOP
→ DOCUMENT CONFLICT
→ IDENTIFY BOTH SOURCES
→ ASK AHMAD/FICI FOR DECISION
```

Do not invent precedence.

---

# 89. Remaining HIGH Issues

A HIGH issue may be pilot-acceptable only if explicitly reviewed.

Final report must state:

- why it remains,
- user impact,
- workaround,
- risk,
- owner,
- post-pilot plan.

Do not bury HIGH issues inside notes.

---

# 90. Remaining MEDIUM / LOW Issues

These may be accepted for pilot but must remain visible in backlog/report.

Examples:

- polish,
- minor browser inconsistency,
- non-critical wording,
- low-impact layout issue.

---

# 91. Pilot Operational Runbook

M17 should leave a lightweight runbook covering:

```text
Deploy
Rollback
Check logs
Check Supabase
Check provider status
Restore database
Disable/limit AI if provider issue
Handle failed email
Handle Daily outage
Support user login/reset
Resolve Team membership mistake
```

Do not create a huge enterprise operations manual.

---

# 92. Provider Outage Behavior

Document expected fallback:

## Supabase issue
Core platform may be unavailable.

## OpenAI issue
AI unavailable; existing project work remains.

## Liveblocks issue
High-frequency collaboration unavailable; saved data remains.

## Daily issue
Video unavailable; structured FICI work remains.

## Resend issue
Email unavailable; in-app state remains.

## Vercel issue
Web app unavailable.

This helps pilot support distinguish critical vs partial outages.

---

# 93. Incident Classification

For pilot support, classify incidents simply:

```text
SECURITY/PRIVACY
DATA INTEGRITY
AUTH/ACCESS
CORE WORKFLOW
PROVIDER OUTAGE
PERFORMANCE
USABILITY
```

Security/privacy incidents receive immediate release/operation priority.

---

# 94. Post-Pilot Success Indicators

After launch, evaluate the source-defined product validation indicators:

- users understand Workspace scope,
- students move selected work Personal → Team,
- instructors review without outside tools,
- structured outputs are reused,
- teams use private chat,
- AI suggestions are understandable and distinguished,
- privacy incidents = zero,
- version history is useful,
- platform reduces disconnected tools/files,
- participants complete Professional Course workflow.

These are post-pilot product signals, not M17 release tests.

---

# 95. M17 Expected Repository Additions

Conceptually:

```text
docs/
├── PILOT_READINESS_REPORT.md
├── RELEASE_RUNBOOK.md
├── BACKUP_RESTORE_RUNBOOK.md
└── KNOWN_ISSUES.md

tests/
├── security/
│   ├── direct-id/
│   ├── rls/
│   ├── ai-leakage/
│   ├── file-access/
│   └── sharing/
├── transaction/
├── concurrency/
├── accessibility/
├── browser/
└── e2e/
    ├── professional-course-core.spec.ts
    ├── privacy.spec.ts
    ├── member-removal.spec.ts
    └── ai-governance.spec.ts
```

Exact paths may vary.

M17 should mostly add:
- tests,
- fixes,
- docs,
- configuration hardening.

Not new product domains.

---

# 96. Recommended Commit Sequence

Example:

```text
test(release): add acceptance inventory
test(security): expand RLS release suite
test(security): add direct-id matrix
test(security): add E2E privacy attacks
test(security): add member-removal release test
test(ai): rerun leakage/provider-payload suite
test(transaction): add approval rollback matrix
test(concurrency): add competing-state release tests
fix(security): resolve discovered authorization defects
fix(integrity): resolve transaction/history defects
fix(files): harden limits/access
feat(security): add required rate limits
fix(errors): harden safe error handling
chore(logging): add structured safe logging
test(accessibility): add release checklist
test(browser): add supported browser matrix
docs(ops): add backup/restore runbook
test(recovery): record non-production restore result
test(e2e): add full Professional Course release scenario
docs(release): add pilot readiness report
```

Commit names may differ.

---

# 97. M17 Non-Goals

Do not add:

- new Advanced Course modules,
- investor CRM,
- marketplace,
- new patent engine,
- public sharing,
- public profiles,
- social feed,
- complex analytics,
- new AI agent framework,
- AI voting,
- automatic grading,
- recording/transcription system,
- calendar platform,
- mobile-native app,
- enterprise SSO,
- billing/subscription,
- multi-tenant institution administration beyond existing approved model.

---

# 98. Potential M17 Ambiguities Codex Must Flag

Do not silently decide:

- exact file size limits if still unresolved,
- exact AI usage quotas,
- exact email event policy if unresolved,
- data retention periods,
- notification retention,
- recording/attendance policy,
- final CSP domains if provider configuration differs,
- whether Sentry is required for pilot,
- exact HIGH-issue acceptance authority,
- restore RTO/RPO targets,
- supported browser version cutoff,
- exact mobile support commitment.

If required for release decision and not documented:

```text
STOP → FLAG → ASK
```

---

# 99. M17 Completion Gate

M17 is complete only when:

```text
[ ] Feature scope frozen
[ ] Acceptance inventory complete

[ ] Full RLS review complete
[ ] AT-RLS-001 PASS
[ ] AT-RLS-002 PASS
[ ] AT-RLS-003 PASS
[ ] AT-RLS-004 PASS
[ ] AT-RLS-005 PASS
[ ] AT-RLS-006 PASS
[ ] AT-RLS-007 PASS

[ ] Direct-ID attack suite PASS

[ ] AT-E2E-PRIV-001 PASS
[ ] AT-E2E-MEMBER-001 PASS

[ ] AI leakage suite PASS
[ ] AT-E2E-AI-001 PASS

[ ] AT-TX-001 PASS
[ ] AT-TX-002 PASS or documented acceptable recovery design
[ ] AT-CON-001 PASS
[ ] AT-CON-002 PASS

[ ] AT-CUR-001 PASS
[ ] AT-CUR-002 PASS

[ ] AT-E2E-001 PASS

[ ] File authorization PASS
[ ] Sharing regression PASS
[ ] Artifact/version integrity PASS
[ ] Voting/Decision governance PASS
[ ] Evidence/Patent separation PASS
[ ] Activity dependencies PASS
[ ] Auth/RBAC regression PASS
[ ] Personal privacy PASS
[ ] Team/Chat isolation PASS
[ ] Audit tests PASS

[ ] Rate limits applied to required endpoint classes
[ ] Error handling reviewed
[ ] Structured logging reviewed
[ ] Security headers/session protection reviewed
[ ] Secret scan clean

[ ] Backup configuration confirmed
[ ] Non-production restore test completed
[ ] File-storage recovery approach documented
[ ] Data portability reviewed

[ ] Accessibility review complete
[ ] Browser tests complete
[ ] Responsive review complete
[ ] Performance smoke tests complete

[ ] Pilot Admin Acceptance PASS
[ ] Pilot Master Acceptance PASS
[ ] Pilot Student Acceptance PASS

[ ] Production environment validated
[ ] Migrations reproducible
[ ] Dependency review complete
[ ] lint PASS
[ ] typecheck PASS
[ ] unit PASS
[ ] integration PASS
[ ] E2E PASS
[ ] build PASS

[ ] MVP Release Checklist fully checked with evidence
[ ] Pilot Readiness Report created
[ ] Zero open BLOCKER defects
```

---

# 100. Final Release Status

There are only two formal outputs:

```text
READY FOR PILOT
```

or:

```text
NOT READY FOR PILOT
```

The final status must be evidence-based.

If any BLOCKER remains:

```text
NOT READY FOR PILOT
```

---

# 101. What Comes After M17

M17 completes the approved MVP implementation plan.

Do **not** automatically create M18.

After M17, the next step is:

```text
PILOT
→ OBSERVE
→ COLLECT EVIDENCE
→ IDENTIFY PRODUCT GAPS
→ PRIORITIZE POST-PILOT BACKLOG
```

Any next implementation phase should be based on:

- pilot feedback,
- defects,
- usage patterns,
- curriculum needs,
- FICI product priorities.

---

# 102. Final Codex Master Prompt for M17

```text
Execute M17 — Pilot Hardening, Security & Release only.

This is not a feature-development milestone.

Read:
- all approved FICI source-of-truth documents,
- 12_ACCEPTANCE_TESTS.md in full,
- 13_CODEX_IMPLEMENTATION_PLAN.md,
- all M0–M16 prompt documents relevant to the implementation.

Your job is to:

1. freeze scope,
2. create the complete acceptance inventory,
3. perform a full RLS review,
4. run direct-ID attack tests,
5. run AI leakage tests,
6. run transaction rollback tests,
7. run concurrency tests,
8. run the exact full Professional Course E2E scenario,
9. run the E2E privacy scenario,
10. run the member-removal scenario,
11. run the AI-governance scenario,
12. verify file authorization,
13. verify sharing and version-history integrity,
14. verify evidence/patent separation,
15. verify auth/RBAC/team/chat regressions,
16. verify browser/accessibility/responsive behavior,
17. verify backup configuration and perform one non-production restore test,
18. verify logging, rate limiting, security headers, file limits, and error handling,
19. validate the release deployment,
20. complete every item in the MVP Release Checklist with evidence,
21. fix defects without changing approved business rules,
22. rerun failed and related regression suites,
23. produce /docs/PILOT_READINESS_REPORT.md,
24. list every remaining HIGH/MEDIUM/LOW issue,
25. report READY FOR PILOT only if there are zero open BLOCKER defects and all release gates pass.

Do not:
- weaken tests,
- bypass RLS,
- use service-role shortcuts as acceptance evidence,
- hide known failures,
- downgrade BLOCKER severity to launch,
- add unrelated product features,
- change business rules merely to make tests pass.

Final report must include:
- Git commit/release candidate,
- environment,
- test commands,
- release-gate results,
- RLS/direct-ID results,
- AI leakage results,
- transaction/concurrency results,
- browser/accessibility results,
- backup/restore result,
- remaining defects by severity,
- exact MVP Release Checklist,
- final status: READY FOR PILOT or NOT READY FOR PILOT.
```

---

# End of Document

**Current Status:** Draft v0.1 — Final Codex Execution File  
**Milestone:** M17 — Pilot Hardening, Security & Release  
**Next Step After M17:** Pilot execution and evidence-based post-pilot planning.
