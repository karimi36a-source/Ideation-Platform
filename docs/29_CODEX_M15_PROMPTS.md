# FICI Invention Education & Development Platform
## Codex M15 Execution Prompts — Progress, Notifications & Pilot Workflow

**Document:** `29_CODEX_M15_PROMPTS.md`  
**Status:** Draft v0.1 — For Review  
**Depends on:** `01_PRODUCT_REQUIREMENTS.md` through `28_CODEX_M14_PROMPTS.md`  
**Purpose:** Provide exact copy/paste prompts for Codex to implement Milestone M15 safely and incrementally after M14 is complete.

---

# 1. Preconditions

Do not begin M15 until M14 is:

```text
IMPLEMENTED
→ TESTED
→ SECURITY-REVIEWED
→ COMMITTED
```

Required M14 state:

- AI provider abstraction works,
- permission-aware Context Builder works,
- AI Output and Context References work,
- Candidate conversion requires human confirmation,
- AI cannot auto-approve,
- AI leakage suite passes,
- AT-E2E-AI-001 passes,
- Codex reports READY FOR M15.

If M14 is incomplete:

```text
STOP → FINISH M14 → REVIEW → COMMIT → BEGIN M15
```

M15 must not redesign core workflow logic.

It should make existing workflow state understandable and operational for a pilot cohort.

---

# 2. M15 Goal

M15 makes the Professional Course usable in a real pilot by adding lightweight operational visibility.

The target is:

```text
STUDENT
→ What am I working on now?
→ What is unfinished?
→ Was revision requested?
→ What is approved?

MASTER
→ Which teams exist?
→ Where is each team now?
→ What is waiting for review?
→ What needs revision?
→ What is already approved?

PLATFORM
→ Notify the right person
→ Update connected clients
→ Email only when async importance justifies it
```

M15 is not a large analytics/dashboard milestone.

---

# 3. M15 Product Boundary

M15 includes:

- basic learning progress,
- current Activity status,
- submission/review status,
- `notifications`,
- in-app notification list,
- unread/read state,
- realtime notification delivery,
- selected email notifications,
- Resend adapter/integration,
- Master cohort overview,
- Student current-work overview,
- basic Team/progress status aggregation,
- pending-review visibility,
- revision-requested visibility,
- approved-output visibility,
- membership-event notifications,
- Share notifications,
- review/approval notifications,
- pilot Admin/Master/Student workflow validation.

M15 does **not** include:

- large analytics dashboard,
- business intelligence,
- cohort performance scoring,
- AI-based student scoring,
- automated grading,
- gamification,
- badges/leaderboards,
- advanced predictive analytics,
- full email campaign system,
- SMS/push notifications,
- M16 live classroom/video,
- M17 release hardening beyond M15-specific tests.

---

# 4. Progress Principle

The Product Requirements distinguish:

```text
LEARNING PROGRESS
≠
DEVELOPMENT PROGRESS / READINESS
```

Examples of Learning Progress:

- Session completed,
- Activity completed,
- exercise submitted,
- course completion percentage.

Examples of Development Progress / Readiness:

- invention structure ready,
- patent analysis incomplete,
- product validation pending,
- market evidence insufficient,
- Team structure partially ready,
- finance not started.

M15 should implement **basic pilot progress** primarily from existing Activity/Submission/Approval state.

Do not falsely equate course completion with invention readiness.

---

# 5. M15 Progress Data Strategy

The M15 Implementation Plan adds only one new required schema table:

```text
notifications
```

Therefore basic progress should be derived from existing canonical data:

- enrollments,
- Teams,
- Development Projects,
- Activity Instances,
- Activity Outputs,
- Artifacts,
- Artifact Versions,
- Submissions,
- Review Actions,
- Decisions where needed,
- Shares where needed.

Do **not** create duplicate `progress` tables unless a concrete performance need and approved schema change require it.

Prefer:

```text
canonical workflow state
→ server aggregation/query
→ lightweight overview DTO
```

---

# 6. Activity Progress

Use M7 Activity Instance state as the primary unit of course workflow progress.

Student should be able to identify:

- current Activity,
- not started Activities where visible,
- in-progress Activity,
- completed Activity,
- blocked Activity if dependency not met.

Do not infer "complete" only because an Artifact exists.

Use approved Activity completion rules.

---

# 7. Submission / Review Progress

Use M8 Submission and Review state.

Pilot-facing status should be able to distinguish at least:

```text
WORK_IN_PROGRESS
SUBMITTED
UNDER_REVIEW
REVISION_REQUESTED
RESUBMITTED
APPROVED
```

Exact user-facing labels should map from canonical stored states.

Do not introduce a second conflicting workflow status.

---

# 8. Current Work

For Student:

"Current work" should answer:

- Program/Course,
- current Session,
- current Activity,
- Workspace/Team,
- relevant current Draft,
- Submission state,
- revision request if any,
- current approved output if any.

This is an aggregation view, not a new ownership model.

---

# 9. Master Cohort Overview

Master should be able to identify for assigned Cohort:

- current Teams,
- Team membership basics,
- current Session/Activity,
- pending review,
- revision requested,
- approved work,
- useful links to exact Project/Activity/Submission.

Do not expose unrelated Cohorts.

Do not create cross-Cohort visibility because Master is a Master somewhere.

---

# 10. Admin Pilot Overview

M15 should not rebuild M3/M5 Admin functionality.

Pilot Admin acceptance depends on existing abilities to:

- create Cohort,
- add Master,
- invite/enroll Students,
- create/manage Teams,
- view active users,
- resolve membership errors.

M15 may provide lightweight navigational overview if necessary, but do not duplicate those business operations.

---

# 11. Notification Schema

Implement:

```text
notifications
```

Fields:

- `id`
- `recipient_user_id`
- `notification_type`
- `title`
- `body`
- `entity_type`
- `entity_id`
- `read_at`
- `created_at`

MVP may implement only selected notification types.

---

# 12. Required Notification Events for M15

The Implementation Plan prioritizes:

- Team membership change,
- Artifact shared,
- Submission received,
- Revision requested,
- Approval.

Product Requirements also mention:

- comment received,
- mention in chat,
- assignment due,
- instructor announcement,
- team decision pending.

For M15, implement only required/available events.

"mention" is later if chat mention support is not already implemented.

Do not invent assignment-due scheduling if no due-date model exists.

---

# 13. Recommended M15 Notification Types

Use exact repository naming conventions.

Conceptually:

```text
TEAM_MEMBER_ADDED
TEAM_MEMBER_REMOVED
TEAM_MEMBER_MOVED
ARTIFACT_SHARED
SUBMISSION_RECEIVED
REVISION_REQUESTED
ARTIFACT_APPROVED
COMMENT_RECEIVED
SHARE_REVOKED
```

Only persist types supported by implemented events.

If enum values already exist, use them.

Do not create conflicting duplicate names.

---

# 14. Notification Ownership Principle

Notification row belongs to:

```text
one recipient_user_id
```

The recipient is server-derived from the triggering event.

Client must not freely choose arbitrary recipients for privileged events.

Example:

```text
Student submits Artifact
→ assigned Master recipient resolved server-side
```

---

# 15. Notification Content Principle

Notification should contain enough information to understand the event.

Example:

```text
Revision requested
Master requested changes to "Invention Concept V1"
```

But do not put large confidential artifact content into notification body.

Prefer:

- concise title,
- concise body,
- entity type/id,
- route resolved after authorization.

---

# 16. Notification Read State

A notification is unread when:

```text
read_at IS NULL
```

Marking read should set:

```text
read_at = server timestamp
```

Recipient only.

Do not allow A1 to mark A2 notification read.

---

# 17. Realtime Notification Architecture

Technical Architecture defines:

```text
PostgreSQL notification row = canonical
Supabase Realtime = connected-client update
```

Flow:

```text
BUSINESS EVENT
↓
INSERT notification
↓
COMMIT
↓
REALTIME EVENT
↓
AUTHORIZED RECIPIENT UI UPDATES
```

Realtime event is not the canonical notification.

After reconnect/refresh, UI reloads notifications from PostgreSQL.

---

# 18. Email Principle

Use:

```text
Resend
```

for **high-value async notifications only**.

Do not email every in-app notification.

The API contract explicitly leaves exact email-event selection open.

Therefore M15 must separate:

```text
notification event created
```

from:

```text
shouldSendEmail(eventType, userPreference, policy)
```

If exact business list is unresolved:

```text
STOP → FLAG → ASK
```

before claiming the final email matrix is complete.

---

# 19. Recommended High-Value Email Candidates

Only as a proposed configurable policy, not silently hard-coded business law:

- revision requested,
- approval granted,
- important Team membership change,
- submission needing Master review.

Possible:
- Artifact shared when recipient may otherwise miss it.

Usually avoid:
- every comment,
- every chat event,
- every realtime activity state change.

The final list requires product approval.

---

# 20. Resend Architecture

Resend must remain an external adapter.

Business logic should call an internal service such as:

```text
NotificationEmailProvider
```

or:

```text
EmailProvider
```

Initial implementation:

```text
ResendEmailProvider
```

Do not spread Resend SDK calls across domain features.

---

# 21. Email Failure Principle

If email fails:

- canonical in-app notification should remain,
- underlying Submission/Approval/Team change must remain committed,
- email failure should be logged safely,
- retry policy may apply if infrastructure exists.

Do not roll back an approved Artifact because email delivery failed.

---

# 22. Notification Transaction Principle

For critical domain events:

```text
domain transaction
+
notification record
```

should be consistent where possible.

Examples:

Submission creation:
- Submission persists,
- Master notification persists.

Revision requested:
- Review state persists,
- Student notification persists.

Approval:
- Approval transaction persists,
- Student/Team notification persists.

Email happens after/around committed canonical state, not as the source of truth.

---

# 23. Existing Notification Hooks

Earlier milestones intentionally created notification hooks for:

- M5 Team membership,
- M8 Submission/Review,
- M13 Sharing,
- potentially comments/feedback.

M15 should consolidate these into the canonical notification service.

Do not create separate feature-specific notification tables.

---

# 24. Submission Received Notification

When Team/Student submits work requiring Master review:

```text
Submission created
↓
assigned Master resolved
↓
notification created
```

Notification links to:

```text
Submission
```

or appropriate Artifact/Review target.

---

# 25. Revision Requested Notification

When Master requests revision:

```text
Review Action
↓
Submission status = REVISION_REQUESTED
↓
Team/Student recipient(s)
↓
notification
```

Do not notify unrelated Cohort members.

---

# 26. Approval Notification

When Master approves:

```text
Approval transaction
↓
approved/current Version
↓
relevant Team/Student recipient(s)
↓
notification
```

Notification does not itself change Artifact state.

It reflects already-committed state.

---

# 27. Team Membership Notification

Examples:

```text
ADDED TO TEAM
REMOVED FROM TEAM
MOVED TO TEAM
```

When removed, the user may still receive the removal notification through their own account, even though Team access is gone.

Do not require Team access to read the user's own notification.

---

# 28. Artifact Shared Notification

When M13 Share is created:

```text
Share
↓
destination users resolved
↓
notification(s)
```

For TEAM destination, notify active Team members according to policy.

Do not leak source content in body.

If Share later revoked, optional revoke notification may be generated.

---

# 29. Comment Notification

If M8 Feedback or M13 COMMENT is implemented:

- comment author is not notified about their own comment,
- target owner/team may be notified,
- notification links to exact entity/version.

Do not expose inaccessible source content through notification body.

---

# 30. Notification RLS

Recipient must be the primary read boundary.

Rules:

```text
recipient_user_id = auth.uid()
```

for normal Student/Master notification reads.

Admin/support access, if needed, must be explicitly scoped.

Team B must never read Team A user's notifications.

---

# 31. Notification Mutation Security

Normal user may:

- list own notifications,
- mark own notification read.

Normal user may not:

- create privileged notification directly,
- change recipient,
- change notification type,
- edit domain entity reference,
- mark another user's notification read,
- forge approval notification.

Domain services create notifications server-side.

---

# 32. Notification Entity Authorization

A notification may point to an entity the user could later lose access to.

When opening entity:

```text
current authorization must be rechecked
```

Notification itself is not a permission grant.

Example:

```text
Artifact shared
↓
later Share revoked
↓
notification remains historical
↓
opening Artifact now = denied
```

---

# 33. Notification Privacy

Notification title/body can leak sensitive data if careless.

Avoid content such as:

- full private idea,
- patent strategy details,
- confidential AI output,
- raw chat text,
- private evidence.

Use concise event descriptions.

---

# 34. Student Current-Work Overview

M15 should implement a lightweight Student overview.

Minimum content:

```text
Course / Cohort
Current Session
Current Activity
Activity Status
Team
Draft / Work in Progress
Submission Status
Revision Requested
Approved Output
Unread Notifications
```

Do not turn this into a full analytics dashboard.

---

# 35. Master Cohort Overview

Minimum per Team:

```text
Team Name
Project
Current Session
Current Activity
Activity Status
Pending Review?
Revision Requested?
Approved Output?
Last Meaningful Workflow Update
```

"Last Meaningful Workflow Update" may be derived from existing timestamps.

Do not build behavioral surveillance metrics.

---

# 36. Progress Source of Truth

Examples:

## Current Session

Derived from curriculum + current/most relevant Activity Instances.

## Current Activity

Derived from Activity state/dependencies.

## Pending Review

Derived from Submission state.

## Revision Requested

Derived from Submission/Review state.

## Approved Work

Derived from Artifact current/approved Version.

Do not manually maintain duplicate booleans if canonical states already answer the question.

---

# 37. Course Percentage

Product Requirements mention course percentage as an example of learning progress.

M15 does not explicitly require percentage.

If implemented:

```text
completed required Activities
/
total required Activities
```

must be defined from curriculum configuration.

Do not invent weighting.

If Activities have optional branches, percentage rules must be approved.

Safe MVP may omit percentage and show status counts.

---

# 38. Development Readiness

M15 should not calculate a single invention-readiness score.

The source explicitly distinguishes learning completion from development readiness.

If Development Gates already exist later/SHOULD-HAVE, they may be displayed.

Do not infer:

```text
90% course complete = 90% invention ready
```

---

# 39. Pilot Workflow

The pilot workflow should allow:

```text
Admin configures Cohort
↓
Master manages course delivery
↓
Students enter course
↓
Students work Personal/Team
↓
Activities progress
↓
Artifacts submitted
↓
Master reviews
↓
Revision requested if needed
↓
Student revises/resubmits
↓
Master approves
↓
Approved output becomes current
↓
next Activity continues
```

M15 adds visibility/notifications around this existing flow.

---

# 40. Pilot Admin Acceptance

Admin must be able to:

- create Cohort,
- add Master,
- invite/enroll Students,
- create/manage Teams,
- view active users,
- resolve membership errors.

M15 should validate these flows still work together after all later milestone additions.

---

# 41. Pilot Master Acceptance

Master must be able to:

- open Cohort,
- see Teams,
- launch Activities,
- inspect submitted work,
- comment,
- request revision,
- approve,
- see basic progress.

M15 specifically adds the last item and notification support.

---

# 42. Pilot Student Acceptance

Student must be able to:

- log in,
- access Course,
- use Personal Workspace,
- access assigned Team,
- use core tools,
- chat,
- share,
- submit,
- receive feedback,
- revise,
- see approval/current output.

M15 specifically improves:

- receive feedback/notifications,
- see current work/status.

---

# 43. Source-of-Truth Files

Before every M15 task, Codex must read:

```text
/docs/01_PRODUCT_REQUIREMENTS.md
/docs/03_ROLES_PERMISSIONS.md
/docs/04_WORKSPACE_TEAM_COLLABORATION.md
/docs/06_COURSE_ACTIVITY_WORKFLOWS.md
/docs/07_MVP_SCOPE.md
/docs/08_DATA_MODEL_SCHEMA.md
/docs/10_TECHNICAL_ARCHITECTURE.md
/docs/11_API_CONTRACTS.md
/docs/12_ACCEPTANCE_TESTS.md
/docs/13_CODEX_IMPLEMENTATION_PLAN.md
/docs/17_CODEX_M3_PROMPTS.md
/docs/19_CODEX_M5_PROMPTS.md
/docs/21_CODEX_M7_PROMPTS.md
/docs/22_CODEX_M8_PROMPTS.md
/docs/27_CODEX_M13_PROMPTS.md
/docs/28_CODEX_M14_PROMPTS.md
```

Do not redesign previous milestones from M15.

---

# 44. Global Codex Header

Use this block at the beginning of every M15 task if project rules are not automatically retained:

```text
You are implementing the FICI Invention Education & Development Platform.

Before making changes:

1. Read all relevant /docs files listed in this task.
2. Treat existing Activity/Artifact/Submission/Team state as canonical.
3. Do not create duplicate workflow-state tables unless required.
4. M15 is lightweight pilot operations, not analytics.
5. Learning progress is not the same as development readiness.
6. Notifications are private to recipients.
7. Notification records are canonical; realtime is delivery only.
8. A notification never grants access to its linked entity.
9. Re-check authorization when opening notification targets.
10. Domain services create privileged notifications.
11. Do not trust client-provided recipient IDs.
12. Email is secondary to in-app canonical state.
13. Email failure must not roll back domain state.
14. Use Resend behind an adapter.
15. Email only selected high-value events.
16. If exact email policy is unresolved, STOP → FLAG → ASK.
17. Master overview must stay within assigned Cohort.
18. Student overview must show only their authorized work.
19. Do not build scoring, surveillance, or large analytics dashboards.
20. Do not implement M16 Daily/video early.
21. Use strict TypeScript.
22. Validate runtime input.
23. Use migrations for schema changes.
24. Run relevant RLS/security/acceptance tests.
25. Report:
    - files changed,
    - migration,
    - notification types,
    - realtime design,
    - email adapter,
    - progress aggregation,
    - overview queries,
    - RLS,
    - tests/results,
    - assumptions,
    - unresolved policy questions.
```

---

# 45. M15.1 — Notification Schema

## Objective

Create the canonical notification table.

## Copy/Paste Prompt

```text
TASK ID: M15.1
TASK: Notification Schema

Read first:

- /docs/08_DATA_MODEL_SCHEMA.md
- /docs/13_CODEX_IMPLEMENTATION_PLAN.md

CREATE

notifications

FIELDS

- id
- recipient_user_id
- notification_type
- title
- body
- entity_type
- entity_id
- read_at
- created_at

RULES

1. recipient_user_id required.
2. recipient identity resolved server-side for domain events.
3. read_at nullable.
4. entity_type/entity_id used for navigation/context.
5. notification body concise.
6. no confidential raw content.
7. add indexes for recipient + unread + created_at.
8. preserve notifications after read.
9. archive/delete policy should not destroy required pilot history unexpectedly.

TEST

- create notification server-side.
- recipient query.
- unread query.
- mark read.
- A2 cannot read A1 notification.

DEFINITION OF DONE

Canonical in-app notification storage exists.
```

---

# 46. M15.2 — Notification Type Registry

## Objective

Centralize supported pilot notification events.

## Copy/Paste Prompt

```text
TASK ID: M15.2
TASK: Notification Type Registry

OBJECTIVE

Create a typed registry/configuration for M15-supported notification types.

REQUIRED / PRIORITY TYPES

- team membership change
- artifact shared
- submission received
- revision requested
- approval

OPTIONAL IF ALREADY SUPPORTED

- comment received
- share revoked

DO NOT IMPLEMENT YET unless source system exists:
- chat mention
- assignment due
- instructor announcement
- team decision pending

For each type define:

- code
- title formatter
- safe body formatter
- target entity type
- email eligibility flag/policy hook
- realtime eligibility
- recipient resolution strategy

Do not hard-code notification strings independently across features.

DEFINITION OF DONE

Pilot notification behavior is centrally typed and consistent.
```

---

# 47. M15.3 — Notification Service

## Objective

Create one authoritative server-side notification creation service.

## Copy/Paste Prompt

```text
TASK ID: M15.3
TASK: Notification Service

OBJECTIVE

Implement internal notification service, conceptually:

createNotification({
  recipientUserId,
  notificationType,
  title,
  body,
  entityType,
  entityId
})

IMPORTANT

This is an internal/domain service.

Normal client must not call arbitrary "create notification to user X".

SERVICE RULES

1. recipient must exist/active according to policy.
2. content formatted through registry.
3. entity reference validated.
4. avoid duplicate notification on idempotent retries where practical.
5. persist canonical row.
6. trigger realtime after commit.
7. invoke email policy after canonical notification.

DEFINITION OF DONE

All M15 feature integrations use one notification path.
```

---

# 48. M15.4 — List Own Notifications

## Objective

Implement recipient notification retrieval.

## Copy/Paste Prompt

```text
TASK ID: M15.4
TASK: List Own Notifications

OBJECTIVE

Implement an operation/query such as:

listMyNotifications(input)

INPUT MAY INCLUDE

- unreadOnly
- cursor
- limit

SERVER

- derive current user.
- query recipient_user_id = current user.
- order newest first.
- paginate.
- do not trust recipientUserId from client.

RETURN

- id
- type
- title
- body
- entity reference
- read state
- created_at

Do not automatically fetch sensitive linked entity content.

TEST

- A1 sees A1 notifications.
- A2 cannot request A1.
- pagination works.
- unread filter works.

DEFINITION OF DONE

Users can reliably retrieve their own notification history.
```

---

# 49. M15.5 — Mark Notification Read

## Objective

Implement read state.

## Copy/Paste Prompt

```text
TASK ID: M15.5
TASK: Mark Notification Read

OBJECTIVE

Implement:

markNotificationRead(notificationId)

RULES

1. authenticated recipient only.
2. notification must belong to current user.
3. set read_at server-side.
4. idempotent if already read.
5. no other notification fields editable.

Optional:
markAllMyNotificationsRead()

Only if useful for pilot and easy to secure.

TEST

- recipient marks own read.
- second call safe.
- A2 cannot mark A1 notification.
- client cannot reset read_at to forge unread if no such operation exists.

DEFINITION OF DONE

Read/unread state is secure and recipient-controlled.
```

---

# 50. M15.6 — Notification RLS

## Objective

Protect notifications directly in PostgreSQL.

## Copy/Paste Prompt

```text
TASK ID: M15.6
TASK: Notification RLS

OBJECTIVE

Implement RLS for notifications.

SELECT

Normal user:
recipient_user_id = auth.uid()

UPDATE

Normal user:
only own row
only read-state mutation through approved path/policy

INSERT

Normal client:
DENY arbitrary inserts.

Privileged server/domain path:
allowed through secure server mechanism.

DELETE

Normal client:
deny unless explicit policy exists.

ATTACK TESTS

- A2 SELECT A1 notification ID.
- A2 UPDATE A1 read_at.
- Student inserts fake APPROVAL notification.
- Student changes entity_id on own notification.
- Team B enumerates Team A notifications.

Expected:
DENIED.

DEFINITION OF DONE

Notification rows cannot be forged or read cross-user.
```

---

# 51. M15.7 — Supabase Realtime Notification Delivery

## Objective

Update connected recipients without creating a second notification system.

## Copy/Paste Prompt

```text
TASK ID: M15.7
TASK: Realtime Notification Delivery

Read first:

- /docs/10_TECHNICAL_ARCHITECTURE.md

OBJECTIVE

Use Supabase Realtime for connected-client notification updates.

FLOW

1. canonical notification inserted.
2. commit succeeds.
3. authorized recipient subscription gets event.
4. UI updates unread state/list.
5. on reconnect, canonical database is reloaded.

SECURITY

- A1 subscribes only to A1 notifications.
- Team/Cohort broadcast must not leak notification payloads.
- do not trust client channel naming alone.

TEST

- connected user receives new notification.
- disconnected/reconnected user reloads same notification.
- A2 does not receive A1 event.

DEFINITION OF DONE

Realtime improves UX while PostgreSQL remains canonical.
```

---

# 52. M15.8 — Team Membership Notifications

## Objective

Integrate M5 membership events into canonical notification service.

## Copy/Paste Prompt

```text
TASK ID: M15.8
TASK: Team Membership Notifications

Read first:

- /docs/19_CODEX_M5_PROMPTS.md
- /docs/08_DATA_MODEL_SCHEMA.md

EVENTS

- member added
- member removed
- member moved

RECIPIENT

Affected user at minimum.

Optionally Team Lead/Master if approved, but do not invent broad alerts.

RULES

ADDED:
notification links to Team where user now has access.

REMOVED:
notification remains accessible to removed user.
Opening Team after removal must fail if user no longer has access.

MOVED:
notification should clearly reflect new Team.

TEST

- add → notification.
- remove → notification + Team access denied.
- move → new Team notification.
- no Team A private content leaked in body after removal.

DEFINITION OF DONE

Membership changes are visible without weakening access rules.
```

---

# 53. M15.9 — Share Notifications

## Objective

Integrate M13 Share events.

## Copy/Paste Prompt

```text
TASK ID: M15.9
TASK: Share Notifications

Read first:

- /docs/27_CODEX_M13_PROMPTS.md

ON SHARE

Resolve recipient users from:
- USER
- TEAM
- MASTER
- COHORT
- WORKSPACE
according to approved M13 destination logic.

Create notification:
- artifact/entity shared
- permission/mode may be summarized safely

ON REVOKE

Optional/approved:
notify recipient that access was revoked.

SECURITY

Notification does not preserve access after revoke.

TEST

1. Team A shares Artifact X to Team B.
2. B1/B2 receive appropriate notification.
3. Team A revokes.
4. prior notification remains.
5. opening X now denied.

DEFINITION OF DONE

Sharing produces useful notifications without becoming a permission token.
```

---

# 54. M15.10 — Submission Received Notification

## Objective

Notify assigned Master when work is submitted.

## Copy/Paste Prompt

```text
TASK ID: M15.10
TASK: Submission Notification

Read first:

- /docs/22_CODEX_M8_PROMPTS.md

EVENT

Team/Student submits Artifact Version for review.

RECIPIENT

Assigned Master according to Cohort/Project/Activity scope.

FLOW

1. submission transaction succeeds.
2. resolve Master.
3. create SUBMISSION_RECEIVED notification.
4. link to Submission or exact review entity.
5. realtime update.
6. email policy evaluated after canonical state.

TEST

- Team A submits.
- assigned Master receives.
- unrelated Master does not.
- Student cannot spoof Master recipient.
- notification opens authorized submission.

DEFINITION OF DONE

Pending review reaches the right Master.
```

---

# 55. M15.11 — Revision Requested Notification

## Objective

Notify the working Team/Student about required revision.

## Copy/Paste Prompt

```text
TASK ID: M15.11
TASK: Revision Requested Notification

EVENT

Master performs REQUEST_REVISION.

RECIPIENT

Relevant Team members / submitter according to current submission ownership model.

FLOW

1. review transaction commits.
2. submission status = revision requested.
3. feedback exists.
4. notification(s) created.
5. realtime update.
6. selected email policy evaluated.

BODY

Concise:
"Revision requested for <Artifact>"

Do not duplicate full feedback in notification body.

TEST

- Team A receives.
- Team B does not.
- notification links to authorized Submission/Feedback.
- current-work overview reflects REVISION_REQUESTED.

DEFINITION OF DONE

Students can clearly see that work needs revision.
```

---

# 56. M15.12 — Approval Notification

## Objective

Notify Student/Team after approved version is committed.

## Copy/Paste Prompt

```text
TASK ID: M15.12
TASK: Approval Notification

EVENT

Master approval transaction completes.

RECIPIENT

Relevant Student/Team scope.

FLOW

1. approval transaction completes fully.
2. new Version becomes APPROVED/CURRENT as defined by M8.
3. only then create/commit notification.
4. realtime update.
5. email policy evaluated.

IMPORTANT

Notification must never be emitted as proof of approval before approval transaction succeeds.

TEST

- successful approval → notification.
- forced approval rollback → no false approval notification.
- Student overview shows approved output.
- Team B gets none.

DEFINITION OF DONE

Approval notification reflects canonical committed approval state.
```

---

# 57. M15.13 — Comment / Feedback Notification

## Objective

Notify users about feedback without duplicating feedback data.

## Copy/Paste Prompt

```text
TASK ID: M15.13
TASK: Feedback Notification

IMPLEMENT only for existing M8/M13 feedback/comment systems.

EVENT

- feedback added
- comment added

RECIPIENT

Relevant owner/Team member(s) according to scope.

RULES

1. do not notify commenter about own action unless product policy requires.
2. notification body does not contain entire confidential feedback.
3. entity link re-checks permission.
4. feedback record remains canonical.

TEST

- Master comments on Team A Artifact.
- Team A receives.
- Team B does not.
- opening target works only for authorized user.

DEFINITION OF DONE

Feedback is discoverable without duplicating its source of truth.
```

---

# 58. M15.14 — Email Provider Abstraction

## Objective

Integrate Resend without coupling domain logic.

## Copy/Paste Prompt

```text
TASK ID: M15.14
TASK: Email Provider Abstraction

Read first:

- /docs/10_TECHNICAL_ARCHITECTURE.md

OBJECTIVE

Create provider abstraction, conceptually:

EmailProvider.send({
  to,
  template,
  variables,
  idempotencyKey?
})

INITIAL ADAPTER

ResendEmailProvider

RULES

1. RESEND_API_KEY server-only.
2. domain features do not call Resend SDK directly.
3. normalize provider success/failure.
4. no sensitive access token in email.
5. links route into FICI and re-auth/re-authorize.
6. provider failure does not roll back domain transaction.

TEST

- mocked success.
- mocked failure.
- secrets absent from client bundle.

DEFINITION OF DONE

Transactional email is replaceable and isolated.
```

---

# 59. M15.15 — Email Policy

## Objective

Send only selected high-value async emails.

## Copy/Paste Prompt

```text
TASK ID: M15.15
TASK: Pilot Email Policy

Read first:

- /docs/11_API_CONTRACTS.md — open email-policy question
- /docs/13_CODEX_IMPLEMENTATION_PLAN.md

OBJECTIVE

Implement a configurable email-eligibility policy for notification types.

IMPORTANT

The exact final list of events requiring email is not fully specified.

Before hard-coding final product behavior:
- inspect current docs/config.
- if unresolved:
  STOP → FLAG → ASK.

TECHNICAL FOUNDATION MAY SUPPORT

- SUBMISSION_RECEIVED
- REVISION_REQUESTED
- ARTIFACT_APPROVED
- important TEAM_MEMBERSHIP_CHANGE
- ARTIFACT_SHARED

without enabling all by default.

DO NOT EMAIL

- every status refresh,
- every realtime event,
- every AI output,
- every chat message.

DEFINITION OF DONE

High-value email can be enabled by explicit policy without turning email into the canonical notification system.
```

---

# 60. M15.16 — Email Send Worker / Async Boundary

## Objective

Prevent email latency/failure from blocking workflow.

## Copy/Paste Prompt

```text
TASK ID: M15.16
TASK: Async Email Delivery Boundary

Read first:

- /docs/10_TECHNICAL_ARCHITECTURE.md

OBJECTIVE

Implement the simplest reliable M15 mechanism consistent with existing architecture.

RULES

1. canonical notification/domain state commits first.
2. email dispatch occurs asynchronously where available.
3. do not introduce a complex queue if MVP does not need one.
4. do not create request polling loops.
5. if using after-commit server dispatch, failures are logged and do not corrupt workflow.
6. maintain idempotency to avoid duplicate emails on retries.

If a persistent outbound-email queue/table is required but not in approved schema:
FLAG before adding new durable domain schema.

DEFINITION OF DONE

Email is operationally safe without unnecessary infrastructure.
```

---

# 61. M15.17 — Student Current-Work Query

## Objective

Provide a lightweight, authoritative Student status view.

## Copy/Paste Prompt

```text
TASK ID: M15.17
TASK: Student Current-Work Query

OBJECTIVE

Implement a server-side aggregation such as:

getMyCurrentWork()

RETURN

- enrollment/course/cohort
- Team
- Project
- current Session
- current Activity
- Activity status
- current Draft/Artifact where relevant
- Submission status
- revision-requested state
- current approved output
- unread notification count

SOURCE

Use existing canonical tables.
Do not persist duplicate progress state.

RULES

1. current user server-derived.
2. Personal/Team access respected.
3. no other Student private work.
4. shared entities should not redefine "own current work" unless Activity actually uses them.
5. archived/completed Projects handled safely.

TEST

- Student in active Team.
- Student with revision request.
- Student with approved output.
- A1 query never includes A2 Personal content.

DEFINITION OF DONE

Student can answer "what should I work on now?"
```

---

# 62. M15.18 — Student Current-Work UI

## Objective

Expose pilot-focused workflow state clearly.

## Copy/Paste Prompt

```text
TASK ID: M15.18
TASK: Student Current-Work UI

OBJECTIVE

Build lightweight Student overview.

SHOW

- Course / Cohort
- current Session
- current Activity
- Activity status
- current Team
- Work in Progress
- Submission state
- Revision Requested callout
- Approved Output
- Notifications/unread count

ACTIONS

Link to:
- current Activity
- current Draft
- revision feedback
- approved output

DO NOT

- show large analytics charts,
- calculate readiness score,
- show Team rankings,
- show other Students' private progress.

ACCESSIBILITY

Use semantic status text.
Color must not be the only indicator.

DEFINITION OF DONE

Pilot Student can navigate current work without external tracking.
```

---

# 63. M15.19 — Master Cohort Overview Query

## Objective

Give assigned Master a lightweight operational view of Cohort state.

## Copy/Paste Prompt

```text
TASK ID: M15.19
TASK: Master Cohort Overview Query

OBJECTIVE

Implement:

getMasterCohortOverview(cohortId)

AUTHORIZATION

Master must be assigned to Cohort.
Admin may have broader authorized access.
Unrelated Master denied.

RETURN PER TEAM

- Team ID/name
- Project
- active member count/basic membership
- current Session
- current Activity
- Activity status
- pending review count/state
- revision requested state
- approved output/current Artifact state
- last meaningful workflow update timestamp

SOURCE

Aggregate existing:
- Team
- Project
- Activity
- Submission
- Artifact Version
- Review

DO NOT

- expose Personal Workspace content.
- expose private Team Chat.
- compute behavioral performance score.

DEFINITION OF DONE

Master can quickly identify where each Team needs attention.
```

---

# 64. M15.20 — Master Cohort Overview UI

## Objective

Provide a simple pilot operations screen.

## Copy/Paste Prompt

```text
TASK ID: M15.20
TASK: Master Cohort Overview UI

OBJECTIVE

Create a compact Cohort overview for Master.

DISPLAY

Per Team:
- Team name
- current Session / Activity
- status
- pending review
- revision requested
- approved state
- action link

FILTERS MAY INCLUDE

- pending review
- revision requested
- active
- completed

DO NOT BUILD

- large KPI dashboard,
- charts for engagement,
- scoring,
- AI ranking,
- Team comparison leaderboard.

ACCESS

Only assigned Cohort scope.

DEFINITION OF DONE

Master can manage pilot workflow from one simple overview.
```

---

# 65. M15.21 — Pending Review Queue

## Objective

Make Master review workload obvious.

## Copy/Paste Prompt

```text
TASK ID: M15.21
TASK: Pending Review Queue

OBJECTIVE

Provide a lightweight query/view of Submissions waiting for Master action.

RETURN

- Team/Student
- Artifact
- Version
- Submission time
- current review state
- Activity
- Project

AUTHORIZATION

Assigned Master only.

ORDER

Oldest first or repository-approved default.

DO NOT

- duplicate Submission rows.
- create new queue state table.

TEST

- Team A submitted appears.
- after revision request leaves pending queue / changes section.
- after approval no longer pending.
- unrelated Cohort submission absent.

DEFINITION OF DONE

Master can find all work currently requiring review.
```

---

# 66. M15.22 — Revision Queue / Status

## Objective

Make revision-required work visible to both sides.

## Copy/Paste Prompt

```text
TASK ID: M15.22
TASK: Revision Status

OBJECTIVE

Derive revision-requested state from M8 canonical workflow.

MASTER VIEW

Show:
- which Team has revision pending,
- target Artifact/Submission.

STUDENT VIEW

Show:
- revision requested,
- feedback link,
- current Draft/revision action.

RULES

Do not create separate revision flag if Submission state already captures it.

TEST

- revision request visible immediately.
- realtime notification arrives.
- refresh preserves state.
- after resubmission state changes correctly.

DEFINITION OF DONE

Revision work cannot be missed during pilot.
```

---

# 67. M15.23 — Approved Output Status

## Objective

Show the current approved output without confusing Draft/AI/Candidate state.

## Copy/Paste Prompt

```text
TASK ID: M15.23
TASK: Approved Output Status

OBJECTIVE

Expose current approved Artifact Version in Student/Master overview.

RULES

1. use Artifact.current_version_id / approved Version semantics from M8.
2. Draft is never labeled approved.
3. AI Candidate is never labeled approved.
4. revised Draft after approved V1 does not replace current until approval.
5. historical Versions remain separate.

TEST

- V1 approved.
- V2 Draft exists.
- overview still shows V1 current.
- after V2 approval, overview shows V2.

DEFINITION OF DONE

Pilot users always know what output is currently approved.
```

---

# 68. M15.24 — Basic Learning Progress Aggregation

## Objective

Provide minimal progress without inventing readiness scoring.

## Copy/Paste Prompt

```text
TASK ID: M15.24
TASK: Basic Learning Progress

OBJECTIVE

Aggregate learning progress from Activity Instances.

RETURN MAY INCLUDE

- required Activities total
- completed Activities
- in-progress Activities
- blocked Activities
- current Session

If course percentage is implemented:
- define exact denominator from required Activity Definitions.
- do not weight Activities unless approved.
- exclude optional Activities only according to curriculum config.

IMPORTANT

Do not call this Development Readiness.

No invention-readiness score.

DEFINITION OF DONE

Basic course progress is derived transparently from Activity state.
```

---

# 69. M15.25 — Progress Authorization Tests

## Objective

Ensure overview queries do not become new data-leak paths.

## Copy/Paste Prompt

```text
TASK ID: M15.25
TASK: Progress Authorization Tests

ATTACKS

Student A1:
- requests A2 current-work query.
- attempts Team B progress.
- attempts unrelated Cohort overview.

Master assigned Cohort A:
- requests Cohort B overview.
- requests Student Personal Draft detail through progress endpoint.
- requests Team B private Chat through progress link.

EXPECTED

Denied or safely omitted.

IMPORTANT

Aggregated status itself can be sensitive.
Do not return hidden/private entity names unless authorized.

DEFINITION OF DONE

Progress aggregation respects the same role/scope model as source data.
```

---

# 70. M15.26 — Notification Realtime Security Tests

## Objective

Prove realtime does not leak notification events.

## Copy/Paste Prompt

```text
TASK ID: M15.26
TASK: Realtime Notification Security

FIXTURES

- A1
- A2
- B1
- Master

TEST

1. create A1 notification.
2. A1 subscription receives.
3. A2 subscription does not.
4. B1 subscription does not.
5. exact notification ID through realtime payload cannot be fetched by unauthorized user.
6. reconnect reloads canonical A1 row.
7. read-state change updates A1 only.

DEFINITION OF DONE

Realtime notification delivery is recipient-isolated.
```

---

# 71. M15.27 — Email Security Tests

## Objective

Protect email links/content.

## Copy/Paste Prompt

```text
TASK ID: M15.27
TASK: Email Notification Security

OBJECTIVE

Test selected email notifications.

VERIFY

- email sent only to resolved recipient address.
- email contains no API secret/access token.
- link points to FICI route.
- opening route requires normal auth.
- user cannot access entity only because they possess old email link.
- revoked Share email link no longer opens shared content.
- removed member email link does not restore Team access.
- provider failure does not roll back domain event.

DEFINITION OF DONE

Email is a notification channel, not a permission bypass.
```

---

# 72. M15.28 — Pilot Admin Acceptance Regression

## Objective

Validate Admin pilot setup after full platform feature build.

## Copy/Paste Prompt

```text
TASK ID: M15.28
TASK: Pilot Admin Acceptance

Read first:

- /docs/12_ACCEPTANCE_TESTS.md — Pilot Admin Acceptance

VERIFY ADMIN CAN

- create Cohort
- add Master
- invite/enroll Students
- create/manage Teams
- view active users
- resolve membership errors

IMPORTANT

This is primarily regression validation of M2/M3/M5.

Do not expand M15 into a new Admin analytics suite.

PRIORITY

MUST PASS.

DEFINITION OF DONE

Pilot can be configured/administered using built platform workflows.
```

---

# 73. M15.29 — Pilot Master Acceptance

## Objective

Validate Master pilot workflow including progress.

## Copy/Paste Prompt

```text
TASK ID: M15.29
TASK: Pilot Master Acceptance

Read first:

- /docs/12_ACCEPTANCE_TESTS.md — Pilot Master Acceptance

VERIFY MASTER CAN

1. open assigned Cohort.
2. see Teams.
3. launch Activities.
4. inspect submitted work.
5. comment.
6. request revision.
7. approve.
8. see basic progress.

M15 ADDITIONAL CHECKS

- submission notification received.
- revision/approval status visible.
- pending-review queue accurate.
- unrelated Cohort denied.

PRIORITY

MUST PASS.

DEFINITION OF DONE

Master can run the pilot without external progress tracking.
```

---

# 74. M15.30 — Pilot Student Acceptance

## Objective

Validate complete Student pilot workflow.

## Copy/Paste Prompt

```text
TASK ID: M15.30
TASK: Pilot Student Acceptance

Read first:

- /docs/12_ACCEPTANCE_TESTS.md — Pilot Student Acceptance

VERIFY STUDENT CAN

1. log in.
2. access Course.
3. use Personal Workspace.
4. access assigned Team.
5. use core tools.
6. chat.
7. share.
8. submit.
9. receive feedback.
10. revise.
11. see approval/current output.

M15 CHECKS

- current-work overview accurate.
- notifications received.
- revision clearly visible.
- approved output clearly visible.
- no other Student Personal content.

PRIORITY

MUST PASS.

DEFINITION OF DONE

Student can complete normal pilot workflow inside FICI.
```

---

# 75. M15.31 — Pilot Notification End-to-End Scenario

## Objective

Validate notification lifecycle across core events.

## Copy/Paste Prompt

```text
TASK ID: M15.31
TASK: Pilot Notification E2E

SCENARIO

1. Admin/Master adds A1 to Team A.
2. A1 gets membership notification.
3. Team A shares Artifact with Master.
4. Master receives Share notification if policy configured.
5. Team A submits Artifact.
6. Master receives submission notification.
7. Master requests revision.
8. Team A receives revision notification.
9. Team A resubmits.
10. Master receives submission/resubmission notification.
11. Master approves.
12. Team A receives approval notification.
13. A1 marks notifications read.

VERIFY

- every notification recipient correct.
- no Team B notifications.
- entity links authorized.
- read state persists.
- realtime works.
- email only for configured high-value events.

DEFINITION OF DONE

Core pilot events produce coherent notification flow.
```

---

# 76. M15.32 — Pilot Progress End-to-End Scenario

## Objective

Validate that progress reflects canonical workflow from Activity start through approval.

## Copy/Paste Prompt

```text
TASK ID: M15.32
TASK: Pilot Progress E2E

SCENARIO

1. Master launches Activity A.
2. Team A starts A.
3. Student overview:
   Current Activity = A
   Status = IN_PROGRESS.
4. Team creates Draft.
5. Team submits.
6. Master overview:
   Pending Review = yes.
7. Master requests revision.
8. Student overview:
   Revision Requested = yes.
9. Team revises/resubmits.
10. Master approves.
11. Student overview:
    Approved Output = current approved Version.
12. Master overview:
    Approved Work = yes.
13. next Activity dependency becomes available according to M7.

VERIFY

Progress is derived from source states.
No manual duplicate state becomes inconsistent.

DEFINITION OF DONE

M15 overview tracks real workflow correctly.
```

---

# 77. M15.33 — Notification / Approval Transaction Integrity

## Objective

Prevent false notifications on rolled-back critical state.

## Copy/Paste Prompt

```text
TASK ID: M15.33
TASK: Notification Transaction Integrity

SCENARIO A — APPROVAL FAILURE

Artificially fail approval transaction before commit.

Expected:
- no approved state.
- no false approval notification.
- no approval email.

SCENARIO B — SUBMISSION FAILURE

Submission fails.

Expected:
- no "submission received" notification.

SCENARIO C — NOTIFICATION FAILURE

If domain state commits but notification insert fails:
follow repository transaction/error policy.
Prefer same transaction where possible for in-app notification.

SCENARIO D — EMAIL FAILURE

Domain + in-app notification committed.
Email fails.

Expected:
- domain remains correct.
- in-app notification remains.
- email failure logged.

DEFINITION OF DONE

Notifications never lie about uncommitted workflow state.
```

---

# 78. M15.34 — M15 Security & Integrity Hardening

## Objective

Review pilot progress/notification features before live classroom integration.

## Copy/Paste Prompt

```text
TASK ID: M15.34
TASK: M15 Security & Integrity Hardening

Read first:

- /docs/01_PRODUCT_REQUIREMENTS.md
- /docs/03_ROLES_PERMISSIONS.md
- /docs/08_DATA_MODEL_SCHEMA.md
- /docs/10_TECHNICAL_ARCHITECTURE.md
- /docs/11_API_CONTRACTS.md
- /docs/12_ACCEPTANCE_TESTS.md
- /docs/13_CODEX_IMPLEMENTATION_PLAN.md
- /docs/19_CODEX_M5_PROMPTS.md
- /docs/21_CODEX_M7_PROMPTS.md
- /docs/22_CODEX_M8_PROMPTS.md
- /docs/27_CODEX_M13_PROMPTS.md
- /docs/28_CODEX_M14_PROMPTS.md
- /docs/29_CODEX_M15_PROMPTS.md

VERIFY

1. notification table canonical.
2. Realtime is delivery only.
3. recipient isolation enforced.
4. normal client cannot forge privileged notification.
5. notification entity reference grants no permission.
6. revoked Share target remains inaccessible.
7. removed Team member target remains inaccessible.
8. email links require auth.
9. email failure does not corrupt workflow.
10. Master overview limited to assigned Cohort.
11. Student overview only own authorized work.
12. Personal Workspace data not leaked through progress aggregation.
13. pending review derived from Submission.
14. approved output derived from approved/current Version.
15. revision state derived canonically.
16. learning progress not mislabeled as invention readiness.
17. no large analytics/scoring system added.
18. no M16 video code added.

RUN

pnpm lint
pnpm typecheck
pnpm test:unit
pnpm test:integration
pnpm test:e2e
pnpm build
plus notification RLS, realtime, email, and progress authorization tests.

DEFINITION OF DONE

- Pilot Admin Acceptance PASS
- Pilot Master Acceptance PASS
- Pilot Student Acceptance PASS
- Notification E2E PASS
- Progress E2E PASS
- notification transaction integrity PASS
- zero cross-user notification leak
- zero progress-scope leak
- no false approval/revision notifications
- no M16 scope creep

FINAL REPORT

Return:
1. M15 summary
2. notification architecture
3. progress aggregation architecture
4. email policy/status
5. security findings
6. issues fixed
7. remaining issues
8. test matrix
9. BLOCKER status
10. recommendation: READY FOR M16 or NOT READY FOR M16
```

---

# 79. Notification vs Audit

Do not conflate:

```text
Notification
```

with:

```text
Audit Event
```

Notification:
- user-facing,
- recipient-specific,
- may be read/unread.

Audit:
- security/administration history,
- immutable event record,
- not a user inbox.

An Approval may produce both.

---

# 80. Notification vs Activity Status

Do not store Activity status in notification.

Notification reflects an event.

Activity Instance remains source of truth.

---

# 81. Notification vs Submission Status

Likewise:

```text
"Revision requested" notification
```

does not make the Submission revision-requested.

The M8 workflow state does.

---

# 82. Notification vs Permission

Receiving notification never grants access.

All target routes re-check current permissions.

---

# 83. Notification vs Email

In-app notification is canonical.

Email is optional delivery.

If email fails, the notification still exists.

---

# 84. Realtime vs Notification Table

Realtime event may be dropped during disconnect.

Notification table survives.

On reconnect:

```text
reload canonical notifications
```

---

# 85. Progress vs Analytics

M15 progress answers:

```text
Where am I?
What is next?
What needs attention?
```

It does not answer:

```text
Who is best?
Who is slowest?
Who is most productive?
```

Do not build ranking.

---

# 86. Student Privacy in Progress

A Team-based Student overview may show shared Team workflow state.

It must not expose teammates' Personal Workspace content.

---

# 87. Master Scope in Progress

Master may see assigned Team/Cohort workflow state.

Do not infer organization-wide progress access.

---

# 88. Mentor Progress Access

If Mentor overview is not required by M15 plan, do not invent it.

Mentor may retain existing scoped entity access.

A future Mentor dashboard can be added if product decides.

---

# 89. Admin Progress Access

Admin can have platform administration scope.

M15 does not require large Admin progress analytics.

Keep pilot Admin workflow functional.

---

# 90. Activity Completion

Do not mark Activity complete based solely on:

- Draft creation,
- notification,
- AI output,
- Team Chat.

Use M7 completion rules.

---

# 91. Submission Review State

If Submission workflow has states:

```text
SUBMITTED
UNDER_REVIEW
REVISION_REQUESTED
RESUBMITTED
APPROVED
```

M15 should map those canonically.

Do not create duplicate status flags.

---

# 92. Resubmission

Resubmission should update overview and Master queue.

Prior submission/review history remains visible according to M8.

Do not overwrite old submission history.

---

# 93. Current Approved Output

Use M8 current Version pointer/state.

Do not derive current output from most recently modified Draft.

---

# 94. Team Membership Changes and Overview

When Student is moved/removed:

- Team overview membership updates,
- old historical contributions remain,
- Student current-work view switches according to new authorized scope,
- notifications remain in user's own inbox.

---

# 95. Share Revocation and Notifications

Revoking Share may leave historical "shared with you" notification.

Opening target re-checks access and fails.

Do not delete notification just to hide history unless product policy says so.

---

# 96. Notification Retention

No retention duration is specified.

Do not silently purge notifications in M15.

If retention policy is needed:

```text
STOP → FLAG → ASK
```

---

# 97. Email Preferences

User email preference controls are not defined in M15.

Do not invent a full preference center.

Use a server-side pilot policy for approved high-value event types.

Future settings may add preferences.

---

# 98. Email Deliverability

M15 should support transactional send status/error logging as appropriate.

Do not build marketing newsletter features.

---

# 99. Resend Webhooks

If delivery-status webhooks are implemented:

- verify signature,
- handle idempotently,
- do not treat delivery success as domain-event success.

This is optional for pilot unless current architecture requires it.

---

# 100. Notification Idempotency

Repeated domain retry should not create multiple identical notifications unintentionally.

Use event/entity-based idempotency where practical.

Do not suppress genuinely distinct events.

---

# 101. Unread Count

Unread count should be derived:

```text
recipient_user_id = current user
AND read_at IS NULL
```

Do not maintain a separate mutable counter unless necessary.

---

# 102. Notification Ordering

Default:

```text
created_at DESC
```

Avoid client-side inconsistent ordering as source of truth.

---

# 103. Notification Pagination

Use cursor/keyset pagination if list can grow.

Pilot does not need infinite historical analytics.

---

# 104. Entity Routing

Notification may point to:

- Team,
- Share,
- Submission,
- Artifact,
- Feedback.

Route resolution should map entity type to authorized app route.

Do not store arbitrary unsafe destination URLs in notification rows.

---

# 105. Progress Caching

Pilot scale likely does not require complex cached progress tables.

Use efficient relational queries/indexes.

If performance later requires materialization, add deliberately with invalidation strategy.

---

# 106. Last Meaningful Update

If shown in Master overview, derive from meaningful domain timestamps such as:

- Activity updated/completed,
- Submission created,
- review action,
- Artifact version.

Do not monitor keystrokes or presence to compute activity.

---

# 107. M15 Expected Repository Additions

Conceptually:

```text
features/
├── notifications/
│   ├── service/
│   ├── registry/
│   ├── queries/
│   ├── realtime/
│   ├── email/
│   └── access/
└── progress/
    ├── student/
    ├── master/
    ├── review-queue/
    ├── aggregators/
    └── access/

lib/
├── notifications/
│   ├── create.ts
│   ├── recipients.ts
│   ├── realtime.ts
│   └── email-policy.ts
├── email/
│   ├── provider.ts
│   └── resend-provider.ts
├── progress/
│   ├── student-current-work.ts
│   └── master-cohort-overview.ts
└── permissions/
    ├── notifications.ts
    └── progress.ts

supabase/
├── migrations/
│   ├── ...notifications...
│   └── ...notification_rls...
└── tests/
    └── rls/
        └── notifications...

tests/
├── unit/
│   ├── notifications/
│   └── progress/
├── integration/
│   ├── notifications/
│   ├── email/
│   ├── master-overview/
│   └── student-overview/
└── e2e/
    ├── pilot-notifications.spec.ts
    └── pilot-progress.spec.ts
```

Exact paths may vary.

---

# 108. M15 Completion Gate

M15 is complete only when:

```text
[ ] notifications table exists
[ ] Notification RLS exists
[ ] notification type registry exists
[ ] canonical notification service exists

[ ] listMyNotifications works
[ ] markNotificationRead works
[ ] unread count works
[ ] realtime updates work
[ ] reconnect reloads canonical notifications

[ ] Team membership notification works
[ ] Artifact Share notification works
[ ] Submission received notification works
[ ] Revision requested notification works
[ ] Approval notification works
[ ] feedback notification works if corresponding source event exists

[ ] Resend adapter exists
[ ] email policy hook exists
[ ] only approved high-value email events enabled
[ ] email failure does not corrupt domain state
[ ] email links reauthorize target

[ ] Student current-work query exists
[ ] Student overview exists
[ ] Master cohort overview query exists
[ ] Master cohort overview exists
[ ] pending-review queue works
[ ] revision status visible
[ ] approved output visible
[ ] basic Activity progress visible

[ ] learning progress is not mislabeled as development readiness
[ ] no duplicate canonical workflow state introduced

[ ] Pilot Admin Acceptance PASS
[ ] Pilot Master Acceptance PASS
[ ] Pilot Student Acceptance PASS

[ ] Notification E2E PASS
[ ] Progress E2E PASS
[ ] notification transaction integrity PASS
[ ] notification RLS tests PASS
[ ] realtime recipient-isolation tests PASS
[ ] progress authorization tests PASS
[ ] email security tests PASS

[ ] lint passes
[ ] typecheck passes
[ ] unit tests pass
[ ] integration tests pass
[ ] E2E tests pass
[ ] build passes

[ ] no large analytics dashboard
[ ] no M16 video feature implemented
[ ] Codex reports READY FOR M16
```

Any cross-user notification leak is:

```text
BLOCKER
```

Any progress endpoint exposing unauthorized Team/Personal data is:

```text
BLOCKER
```

Any false approval notification caused by a rolled-back approval is:

```text
HIGH / BLOCKER depending on release impact
```

---

# 109. Recommended Commit Sequence

Example:

```text
feat(notifications): add notification schema and RLS
feat(notifications): add notification registry/service
feat(notifications): add own list/read state
feat(notifications): add realtime delivery
feat(notifications): integrate Team membership events
feat(notifications): integrate Share events
feat(notifications): integrate Submission events
feat(notifications): integrate revision/approval events
feat(email): add provider abstraction and Resend adapter
feat(email): add high-value email policy
feat(progress): add Student current-work aggregation
feat(progress): add Student overview
feat(progress): add Master cohort aggregation
feat(progress): add Master overview
feat(progress): add pending-review/revision status
test(notifications): add recipient isolation/realtime tests
test(email): add email security/failure tests
test(progress): add authorization tests
test(pilot): add Admin/Master/Student acceptance
test(e2e): add pilot notification workflow
test(e2e): add pilot progress workflow
chore(security): complete M15 hardening
```

---

# 110. M15 Non-Goals

Do not accept these as "helpful additions" during M15:

- analytics warehouse,
- BI dashboard,
- Student ranking,
- Team ranking,
- engagement scoring,
- AI scoring,
- automated grading,
- readiness percentage from course completion,
- predictive dropout model,
- marketing emails,
- newsletters,
- SMS,
- push notification infrastructure,
- complex queue system unless clearly required,
- M16 Daily/video integration,
- M17 broad release hardening.

---

# 111. Potential M15 Ambiguities Codex Must Flag

Do not silently decide if approved docs do not resolve:

- exact notification type enum names,
- which Team members receive Team-wide notifications,
- whether removed user gets a removal notification,
- whether all Share destinations trigger notifications,
- whether Share revoke triggers notification,
- whether comment notification goes to all Team members or only owner/submitter,
- exact email event list,
- whether email is enabled by default in pilot,
- whether user email preferences exist,
- whether resubmission gets a distinct notification type,
- whether Master receives email for every submission or only when offline,
- whether course progress percentage should be shown,
- how optional Activities affect percentage,
- how "current Activity" is chosen if multiple Activities are active,
- whether Student sees future locked Activities,
- whether Master sees individual Student Personal progress or Team-only progress,
- whether Mentor receives progress overview,
- notification retention,
- notification deletion,
- mark-unread behavior,
- notification batching,
- email retry count,
- whether Resend webhook tracking is needed in pilot,
- whether Admin needs a pilot dashboard beyond existing tools.

If unresolved:

```text
STOP → FLAG → ASK
```

---

# 112. Recommended Safe Defaults for Purely Technical Decisions

Only where they do not alter approved product policy:

- UUID Notification IDs,
- recipient derived server-side,
- PostgreSQL canonical notifications,
- Supabase Realtime delivery,
- newest-first list,
- `read_at` nullable,
- unread count derived,
- no arbitrary client insert,
- no notification target permission grant,
- Resend behind adapter,
- domain state commits independently of email delivery,
- progress derived from canonical Activity/Submission/Artifact state,
- Master queries constrained to assigned Cohort,
- Student queries constrained to authenticated user,
- no readiness score,
- no M16 code.

---

# 113. Review Checklist for Ahmad/FICI

Before implementation, confirm M15 reflects the intended pilot model:

```text
1. Student sees what they should work on now.

2. Student sees Work in Progress.

3. Student clearly sees Revision Requested.

4. Student clearly sees Approved Output.

5. Master sees all Teams in assigned Cohort.

6. Master sees each Team's current Session/Activity.

7. Master sees pending reviews.

8. Master sees revision-requested work.

9. Master sees approved work.

10. Notifications are in-app and persistent.

11. Realtime only updates connected clients.

12. Email is used only for important async events.

13. Team membership changes generate relevant notifications.

14. Artifact sharing generates relevant notifications.

15. Submission generates Master notification.

16. Revision request generates Team/Student notification.

17. Approval generates Team/Student notification.

18. Notifications do not grant access.

19. Learning progress is not the same as invention readiness.

20. M15 does not become a large analytics dashboard.

21. Admin, Master and Student pilot acceptance flows all pass.

22. M16 remains the next separate live-classroom milestone.
```

---

# 114. Next File After M15

After M15 has actually been:

```text
IMPLEMENTED
→ TESTED
→ SECURITY-REVIEWED
→ COMMITTED
```

create:

# `30_CODEX_M16_PROMPTS.md`

M16 will cover:

```text
Daily Integration
Live Session Room
Master Room Creation
Authorized Student Join
Join Tokens
Cohort Live Session
Current Activity Link
Optional Team Breakout Mapping
Daily Provider Abstraction
Live-Classroom Authorization
```

M16 must keep educational state in FICI and use Daily only as the media provider.

---

# 115. Final Execution Rule

For M15:

```text
NOTIFICATION SCHEMA
→ TYPE REGISTRY
→ NOTIFICATION SERVICE
→ OWN LIST / READ STATE
→ RLS
→ REALTIME
→ MEMBERSHIP NOTIFICATIONS
→ SHARE NOTIFICATIONS
→ SUBMISSION NOTIFICATIONS
→ REVISION NOTIFICATIONS
→ APPROVAL NOTIFICATIONS
→ EMAIL ADAPTER
→ EMAIL POLICY
→ STUDENT CURRENT WORK
→ MASTER COHORT OVERVIEW
→ REVIEW / REVISION / APPROVAL STATUS
→ PILOT ACCEPTANCE
→ NOTIFICATION E2E
→ PROGRESS E2E
→ SECURITY HARDENING
```

Do not skip directly to Daily/live classroom.

---

# End of Document

**Current Status:** Draft v0.1 — Ready for Ahmad/FICI review.  
**Execution Step After M14 Completion:** Start with **M15.1 — Notification Schema**.
