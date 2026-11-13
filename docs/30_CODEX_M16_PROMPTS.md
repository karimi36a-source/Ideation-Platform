# FICI Invention Education & Development Platform
## Codex M16 Execution Prompts — Live Classroom Integration

**Document:** `30_CODEX_M16_PROMPTS.md`  
**Status:** Draft v0.1 — For Review  
**Depends on:** `01_PRODUCT_REQUIREMENTS.md` through `29_CODEX_M15_PROMPTS.md`  
**Purpose:** Provide exact copy/paste prompts for Codex to implement Milestone M16 safely and incrementally after M15 is complete.

---

# 1. Preconditions

Do not begin M16 until M15 is:

```text
IMPLEMENTED
→ TESTED
→ SECURITY-REVIEWED
→ COMMITTED
```

Required M15 state:

- notification records work,
- realtime notifications work,
- selected email notifications work,
- Master cohort overview works,
- Student current-work overview works,
- Pilot Admin/Master/Student acceptance passes,
- Codex reports READY FOR M16.

If M15 is incomplete:

```text
STOP → FINISH M15 → REVIEW → COMMIT → BEGIN M16
```

M16 is an integration milestone.

Do not redesign course, Activity, Project, Team, Chat, Notification, or AI architecture.

---

# 2. M16 Goal

M16 connects the live teaching environment to the FICI platform without rebuilding video infrastructure.

Target experience:

```text
MASTER OPENS COHORT
↓
MASTER STARTS / OPENS LIVE SESSION
↓
FICI RESOLVES DAILY ROOM
↓
AUTHORIZED STUDENT OPENS LIVE CLASS
↓
FICI ISSUES TEMPORARY JOIN TOKEN
↓
STUDENT JOINS DAILY MEDIA ROOM
↓
CURRENT FICI ACTIVITY REMAINS AVAILABLE
↓
TEAM MAY CONTINUE STRUCTURED WORK
```

The core architecture rule is:

# DAILY OWNS MEDIA

# FICI OWNS EDUCATIONAL STATE

---

# 3. M16 Product Boundary

M16 includes:

- Daily integration,
- provider abstraction,
- Daily Prebuilt or lightly customized embedded room for MVP,
- live-session room creation/retrieval,
- server-generated room access,
- temporary join tokens,
- Master room creation,
- authorized Student join,
- assigned Cohort access,
- current Activity link from live classroom,
- optional Team breakout-room mapping,
- Team Workspace linkage,
- room/join security,
- provider failure handling,
- basic live-classroom UI,
- M16 integration/security tests.

M16 does **not** include:

- proprietary WebRTC infrastructure,
- custom media routing,
- advanced video recording management,
- Zoom feature parity,
- custom breakout media engine,
- advanced moderation suite,
- attendance analytics platform,
- full recording library,
- video transcription,
- AI meeting notes,
- public guest rooms,
- webinar infrastructure,
- M17 release hardening unrelated to live-classroom integration.

---

# 4. Technology Decision

The approved live-classroom provider is:

```text
Daily
```

Technical Architecture selects:

```text
Daily Video SDK / Prebuilt
```

Initial MVP strategy:

```text
Daily Prebuilt
or
lightly customized embedded room
```

Later:

```text
Daily Video SDK
```

for deeper FICI-specific controls.

Do not build WebRTC from scratch.

---

# 5. Ownership Boundary

Daily owns:

- media transport,
- WebRTC infrastructure,
- participant media connections,
- video/audio quality.

FICI owns:

- course session,
- Cohort,
- attendance relationship if tracked,
- Team assignment,
- current Activity,
- Development Project,
- Master controls specific to FICI,
- Artifacts,
- Decisions,
- Course state,
- permissions,
- Team/Workspace scope.

Daily must never become the source of truth for educational state.

---

# 6. Canonical State Rule

Do not store canonical FICI educational state only in Daily room metadata.

Examples that must remain in FICI:

```text
current Activity
Activity completion
Team membership
Project state
Artifact state
Submission status
Decision history
AI history
Evidence
Patent Records
```

Daily room data may reference FICI identifiers, but it does not own them.

---

# 7. Provider Abstraction

Daily must remain replaceable.

Create an internal abstraction such as:

```text
LiveClassroomProvider
```

Conceptual methods:

```text
getOrCreateRoom()
createJoinToken()
getRoomStatus()
deleteOrExpireRoom() optional
```

Initial adapter:

```text
DailyLiveClassroomProvider
```

Business logic must not scatter Daily SDK/API calls across UI or domain modules.

---

# 8. Server-Side Provider Secrets

`DAILY_API_KEY` must remain server-only.

Never:

- expose it in browser JavaScript,
- store it in user-visible database fields,
- include it in client logs,
- commit it to repository,
- send it in join URLs.

Client receives only the provider-safe data required to join.

---

# 9. Live Session Identity

The M16 plan does not mandate a new schema table.

Before adding a new live-session table:

1. inspect existing Course Session / Activity / Cohort data,
2. determine whether provider room mapping can be stored using existing extensible metadata/config,
3. add a dedicated minimal table only if required for durable room mapping.

Do not invent a large video-session domain model.

If a new table is needed, it should contain only FICI-owned mapping data such as:

```text
FICI live session identity
Cohort / Course Session reference
provider
provider room reference
status
created_by
created_at
ended_at optional
```

Exact schema requires source/repository confirmation.

---

# 10. Master Room Creation

M16 must support:

```text
get/create live session room
```

Authorized Master should be able to open/create a room only in assigned scope.

Flow:

```text
Master
↓
FICI auth
↓
Cohort scope check
↓
Course Session / live-class context check
↓
resolve existing room
OR
create Daily room
↓
store provider mapping if needed
↓
return FICI live-classroom state
```

Do not trust client-provided Cohort ownership.

---

# 11. Room Reuse

For the same live-class context, repeated "open room" requests should not accidentally create duplicate rooms.

Use:

- existing provider mapping,
- idempotency key,
- session identity,
- or repository-standard uniqueness.

If explicit room lifecycle/reuse policy is not defined:

```text
STOP → FLAG → ASK
```

before inventing whether each class occurrence gets a permanent or new room.

---

# 12. Student Authorized Join

Student may join only when:

- authenticated,
- actively enrolled in Cohort,
- authorized for the live Session,
- account active,
- live room currently joinable,
- relevant scope permits access.

Team membership alone should not imply unrelated Cohort live-room access.

Cohort enrollment must be validated server-side.

---

# 13. Join Token Principle

Never expose unrestricted permanent provider access.

Flow:

```text
authenticated FICI user
↓
authorize Cohort/session
↓
create temporary Daily meeting token / authorized join capability
↓
return to client
↓
join room
```

Token lifetime and provider claims should be minimal.

Do not persist join token as canonical user data.

---

# 14. Join Token Identity

Where Daily supports participant identity claims, use server-trusted FICI identity.

Do not accept client-provided:

```text
userId
role
displayName
owner/admin flag
```

without server resolution.

The Master token and Student token must reflect appropriate media permissions.

Exact Daily permission claims should follow current provider API and approved product requirements.

---

# 15. Master vs Student Media Rights

The platform may need different provider-level permissions for:

```text
Master / room owner / moderator
Student / participant
```

Do not invent broad media moderation rules.

At minimum:

- Master can create/open room,
- authorized Student can join.

If recording, mute-others, remove-participant, or screen-share restrictions are not approved:

```text
DEFER
```

---

# 16. Current Activity Link

The live-classroom experience should display/link the current FICI Activity.

Example:

```text
LIVE CLASS
├── Video
├── Current Session
├── Current Activity
└── Open Activity Workspace
```

Clicking "Open Activity" should use normal FICI Activity authorization.

Daily does not control Activity access.

---

# 17. Activity State During Live Class

Starting/joining video must not automatically:

- start Activity,
- complete Activity,
- submit work,
- approve work,
- update Project baseline.

Those are existing explicit FICI business operations.

The live session may link to current Activity, but should not silently mutate educational state.

---

# 18. Continue Structured Work During Class

Definition of Done requires:

```text
A cohort can join a live session
and continue structured Activity work
in the FICI platform.
```

Therefore the UI should support a practical path to:

- live media,
- current Activity,
- Team Workspace/tools.

This can be:

- split layout,
- tabbed layout,
- side panel,
- separate FICI route with embedded Daily.

Exact UI styling is not M16's primary concern.

---

# 19. Team Breakout Rooms

Technical Architecture says for early MVP:

```text
use separate Daily room/session links where needed
```

and:

```text
connect each breakout room to Team Workspace logically
```

Do not build custom media routing.

M16 may implement optional programmatic breakout mapping.

---

# 20. Breakout Room Authorization

A Team breakout room must be accessible only to:

- active Team members,
- assigned Master/authorized instructor scope,
- assigned Mentor only if approved by role policy.

Team B must not join Team A breakout using known room/provider ID.

Provider room name is not authorization.

---

# 21. Breakout Room Mapping

If breakout mapping is implemented, use an explicit server mapping:

```text
Team
↔
FICI live session
↔
Daily room reference
```

Do not store Team membership in Daily as canonical state.

Membership changes in FICI must affect future token issuance.

---

# 22. Member Removal

Scenario:

```text
A1 joins Team A breakout
Master removes A1
A1 requests new breakout join token
```

Expected:

```text
DENIED
```

Previously issued provider token may remain valid until expiration depending on provider capabilities.

Use short token lifetimes and provider revocation controls where practical.

Do not promise instant revocation if provider/token semantics do not support it.

---

# 23. Cohort Room vs Team Room

Keep concepts distinct:

```text
Cohort Live Room
=
whole live class

Team Breakout Room
=
optional Team-scoped media room
```

A user authorized for Cohort room is not automatically authorized for every Team breakout.

---

# 24. FICI Chat vs Daily Chat

FICI already owns Team Chat.

Do not make Daily chat the canonical Team communication history.

If Daily Prebuilt shows its own transient chat feature:

- do not treat it as FICI project record,
- do not replace Team Chat,
- disable it if product design prefers one communication system.

Exact behavior may require product decision.

---

# 25. Recording Boundary

Advanced video recording management is explicitly out of scope.

If Daily Prebuilt exposes recording controls:

- do not enable recording automatically,
- do not build recording library,
- do not persist recording as formal FICI Artifact unless later approved.

Recording may have privacy/consent implications.

If pilot needs recording:

```text
STOP → FLAG → ASK
```

and define policy before implementation.

---

# 26. Attendance Boundary

Technical Architecture says FICI owns attendance relationship.

M16 plan does not explicitly require attendance tracking.

Therefore:

- joining may provide an extension point,
- do not build attendance analytics unless approved,
- do not infer course completion from video attendance.

If attendance is stored, it must remain FICI-owned.

---

# 27. Provider Room Metadata

Provider metadata may contain minimal references such as:

- FICI live-session ID,
- Cohort ID,
- environment.

Do not place:

- confidential Project content,
- Artifact content,
- Evidence,
- AI Outputs,
- private patent notes

inside provider room metadata.

---

# 28. Daily Prebuilt

MVP may use Daily Prebuilt for:

- camera,
- microphone,
- participant tiles,
- screen sharing,
- core call controls.

Do not reimplement these controls unless necessary.

Focus FICI engineering on:

- authorization,
- session mapping,
- Activity linkage,
- Team breakout mapping.

---

# 29. Provider Failure

If Daily is unavailable:

- FICI Course/Project state remains intact,
- current Activity remains accessible,
- no false Activity completion,
- safe error displayed,
- retry possible.

Video provider outage must not corrupt Project state.

---

# 30. Provider Replacement

If Daily is replaced later, FICI should retain:

- Cohort/session history,
- current Activity,
- Projects,
- Teams,
- notification history,
- artifacts,
- decisions.

Provider-specific room IDs are integration metadata only.

---

# 31. Source-of-Truth Files

Before every M16 task, Codex must read:

```text
/docs/01_PRODUCT_REQUIREMENTS.md
/docs/03_ROLES_PERMISSIONS.md
/docs/04_WORKSPACE_TEAM_COLLABORATION.md
/docs/06_COURSE_ACTIVITY_WORKFLOWS.md
/docs/07_MVP_SCOPE.md
/docs/10_TECHNICAL_ARCHITECTURE.md
/docs/11_API_CONTRACTS.md
/docs/12_ACCEPTANCE_TESTS.md
/docs/13_CODEX_IMPLEMENTATION_PLAN.md
/docs/17_CODEX_M3_PROMPTS.md
/docs/19_CODEX_M5_PROMPTS.md
/docs/21_CODEX_M7_PROMPTS.md
/docs/29_CODEX_M15_PROMPTS.md
```

Use current Daily provider documentation during implementation only for provider API specifics.

Do not let external provider docs override FICI business rules.

---

# 32. Global Codex Header

Use this block at the beginning of every M16 task if project rules are not automatically retained:

```text
You are implementing the FICI Invention Education & Development Platform.

Before making changes:

1. Read the relevant FICI /docs files listed in this task.
2. Treat FICI docs as product/business/security source of truth.
3. Daily owns media; FICI owns educational state.
4. Do not store canonical Course/Project/Activity state only in Daily.
5. Do not build WebRTC from scratch.
6. Use Daily Prebuilt or approved lightweight integration for MVP.
7. Put Daily behind an internal provider abstraction.
8. DAILY_API_KEY stays server-side.
9. Room IDs/names are not authorization.
10. Every join request rechecks current FICI authorization.
11. Client-provided user/role/Cohort/Team identity is untrusted.
12. Students join only authorized Cohort/session rooms.
13. Team breakout joins require active Team membership.
14. Removed members cannot obtain new Team-room tokens.
15. Provider tokens should be temporary/minimal.
16. Live video must not auto-start/complete/approve Activities.
17. Current Activity links use normal FICI authorization.
18. Do not use Daily chat as canonical FICI Team Chat.
19. Do not implement advanced recording management.
20. Do not implement M17 release-hardening scope early.
21. Use strict TypeScript.
22. Validate runtime input.
23. If room lifecycle, recording, attendance, or breakout policy is unresolved, STOP → FLAG → ASK.
24. Run required security/integration tests.
25. Report:
    - files changed,
    - provider abstraction,
    - room mapping,
    - token issuance,
    - authorization rules,
    - breakout behavior,
    - Activity linking,
    - failure behavior,
    - tests/results,
    - assumptions,
    - unresolved issues.
```

---

# 33. M16.1 — Live Classroom Provider Abstraction

## Objective

Create a replaceable media-provider boundary.

## Copy/Paste Prompt

```text
TASK ID: M16.1
TASK: Live Classroom Provider Abstraction

Read first:

- /docs/10_TECHNICAL_ARCHITECTURE.md
- /docs/13_CODEX_IMPLEMENTATION_PLAN.md

OBJECTIVE

Create internal provider interface.

CONCEPTUAL OPERATIONS

- getOrCreateRoom(context)
- createJoinToken(context)
- getRoomStatus(providerRoomRef)
- optional expireRoom(providerRoomRef)

INITIAL ADAPTER

DailyLiveClassroomProvider

RULES

1. Daily API calls server-side only.
2. provider room ID remains integration metadata.
3. business code depends on interface, not Daily SDK directly.
4. normalized provider errors.
5. no Course/Activity state stored only in provider.

TEST

Use mocked provider:
- room create,
- room reuse,
- token create,
- provider failure.

DEFINITION OF DONE

Daily can be replaced without redesigning Course/Project domains.
```

---

# 34. M16.2 — Live Room Mapping Strategy

## Objective

Define minimal durable mapping between FICI and Daily.

## Copy/Paste Prompt

```text
TASK ID: M16.2
TASK: Live Room Mapping Strategy

Read first:

- current database schema
- /docs/10_TECHNICAL_ARCHITECTURE.md
- /docs/13_CODEX_IMPLEMENTATION_PLAN.md

OBJECTIVE

Determine where provider room mapping belongs.

DO NOT automatically add a new table.

FIRST CHECK

Can existing Course Session / Activity metadata safely store:
- provider = DAILY
- provider room reference
- room lifecycle status?

IF YES

Use existing approved extensibility.

IF NO

Propose the smallest dedicated live-session mapping table and STOP for approval if schema is not already documented.

DO NOT create:
- participant analytics tables,
- recording tables,
- attendance tables,
unless approved.

DEFINITION OF DONE

Room mapping has one clear FICI-owned source of truth with no schema bloat.
```

---

# 35. M16.3 — Master Get/Create Live Room

## Objective

Implement the core Master operation.

## Copy/Paste Prompt

```text
TASK ID: M16.3
TASK: Master Get/Create Live Session Room

OBJECTIVE

Implement:

getOrCreateLiveSessionRoom(input)

INPUT CONCEPTUALLY

- cohortId
- courseSessionId or approved live-session context
- activityInstanceId optional

AUTHORIZATION

- authenticated Master/Admin according to approved scope.
- Master must be assigned to Cohort.

FLOW

1. authenticate actor.
2. authorize Cohort.
3. validate Course Session/context.
4. resolve existing FICI room mapping.
5. if active room exists, return it.
6. otherwise call LiveClassroomProvider.
7. save provider mapping.
8. return safe room metadata.
9. audit if required.

DO NOT RETURN

- DAILY_API_KEY
- unrestricted admin credentials

TEST

- assigned Master succeeds.
- unrelated Master denied.
- Student cannot create room.
- retry does not create accidental duplicate room.

DEFINITION OF DONE

Master can securely open the Cohort live classroom.
```

---

# 36. M16.4 — Student Join Authorization

## Objective

Authorize Student before issuing provider access.

## Copy/Paste Prompt

```text
TASK ID: M16.4
TASK: Student Live Session Authorization

OBJECTIVE

Implement a reusable authorization function:

canJoinLiveSession(userId, liveSessionContext)

CHECK

1. authenticated user.
2. account active.
3. enrollment active.
4. Cohort matches.
5. live session belongs to Cohort.
6. room is joinable.
7. user not removed/suspended from required scope.

DO NOT TRUST

- client role,
- client cohortId ownership claim,
- provider room name.

TEST

- enrolled A1 allowed.
- Team B in same authorized Cohort may join Cohort room if Cohort-wide room.
- unrelated Cohort user denied.
- suspended/removed enrollment denied.

DEFINITION OF DONE

Join eligibility is based on canonical FICI scope.
```

---

# 37. M16.5 — Join Token Issuance

## Objective

Issue temporary Daily join capability after FICI authorization.

## Copy/Paste Prompt

```text
TASK ID: M16.5
TASK: Live Session Join Token

OBJECTIVE

Implement:

getLiveSessionJoinToken(input)

FLOW

1. authenticate current user.
2. resolve FICI live session.
3. run join authorization.
4. resolve trusted display identity.
5. determine participant role.
6. call provider adapter.
7. create short-lived join token/capability.
8. return only safe client data.

SECURITY

- token created server-side.
- user identity server-derived.
- Student cannot request Master token.
- room reference cannot override authorized room.
- token expiry should be limited.
- token not stored permanently.

TEST

- Student token.
- Master token.
- client attempts role=MASTER → ignored/denied.
- guessed Team A room by B1 → denied where not authorized.

DEFINITION OF DONE

Provider access is temporary and permission-gated.
```

---

# 38. M16.6 — Live Classroom UI

## Objective

Embed Daily media while keeping FICI Activity/workflow visible.

## Copy/Paste Prompt

```text
TASK ID: M16.6
TASK: Live Classroom UI

OBJECTIVE

Build an MVP live-classroom route/component.

SHOW

- Cohort / Course Session
- live media area using Daily Prebuilt/light integration
- current Activity
- button/link: Open Current Activity
- Team/Project context summary where authorized
- safe provider error state

RULES

1. provider token retrieved from secure FICI operation.
2. no secret keys client-side.
3. Activity button uses normal FICI route authorization.
4. joining call does not auto-start/complete Activity.
5. leave/rejoin does not mutate Project state.

ACCESSIBILITY

- meaningful call controls.
- keyboard reachable surrounding controls.
- clear errors.
- do not rely only on color.

DEFINITION OF DONE

Student can attend live class and continue FICI Activity work.
```

---

# 39. M16.7 — Current Activity Integration

## Objective

Link live class to the Activity Engine.

## Copy/Paste Prompt

```text
TASK ID: M16.7
TASK: Live Session → Current Activity Integration

Read first:

- /docs/21_CODEX_M7_PROMPTS.md
- /docs/29_CODEX_M15_PROMPTS.md

OBJECTIVE

Resolve current Activity for the live Course Session/Cohort.

RETURN

- activityInstanceId
- Activity title/type
- status
- authorized route
- current Team/Project context as needed

RULES

1. reuse existing M7 Activity state.
2. do not create duplicate Activity state.
3. Master may launch/start Activity only through approved M7 operation.
4. Student may open/resume only when authorized.
5. Daily join/leave has no implicit Activity completion effect.

TEST

- Master opens room linked to current Activity.
- A1 opens Activity.
- Team A work persists independently of Daily.
- provider outage does not block direct FICI Activity access.

DEFINITION OF DONE

Live media and structured course work are connected but decoupled.
```

---

# 40. M16.8 — Cohort Live Room Security

## Objective

Prevent unauthorized room access.

## Copy/Paste Prompt

```text
TASK ID: M16.8
TASK: Cohort Live Room Security

ATTACKS

- unauthenticated join-token request.
- Student from unrelated Cohort.
- direct provider room ID/name.
- client spoofs cohortId.
- client spoofs userId.
- client requests Master privileges.
- expired token reuse.
- inactive account.

EXPECTED

Denied before/at token issuance.

IMPORTANT

Do not rely on room obscurity.

If provider supports private rooms/token-only access:
configure it accordingly.

DEFINITION OF DONE

Cohort room cannot be joined through guessed provider identifiers.
```

---

# 41. M16.9 — Optional Team Breakout Mapping

## Objective

Implement early-MVP breakout rooms only if enabled.

## Copy/Paste Prompt

```text
TASK ID: M16.9
TASK: Team Breakout Room Mapping

Read first:

- /docs/04_WORKSPACE_TEAM_COLLABORATION.md
- /docs/10_TECHNICAL_ARCHITECTURE.md

OBJECTIVE

If M16 pilot enables breakouts:

Map:
- live Cohort session
- Team
- separate Daily room reference

FLOW

Master:
1. requests breakout preparation.
2. server enumerates Teams in authorized Cohort.
3. creates/reuses one room per Team as approved.
4. stores minimal provider mapping.
5. exposes navigation to Master.

Student:
1. requests Team breakout token.
2. current Team membership validated.
3. receives token only for own Team room.

DO NOT

- build custom media routing.
- copy Team membership into Daily as source of truth.
- allow room name alone to authorize.

If breakouts are not required for pilot:
mark task DEFERRED OPTIONAL.

DEFINITION OF DONE

Optional Team breakouts use separate provider rooms with FICI authorization.
```

---

# 42. M16.10 — Breakout Join Authorization

## Objective

Protect Team-specific live rooms.

## Copy/Paste Prompt

```text
TASK ID: M16.10
TASK: Breakout Join Authorization

SCENARIO

Team A:
- A1
- A2

Team B:
- B1
- B2

VERIFY

- A1/A2 may obtain Team A room token.
- B1/B2 cannot.
- assigned Master may join according to instructor policy.
- removed A1 cannot obtain a new Team A breakout token.
- exact provider room ID does not bypass.

MENTOR

Only allow assigned Mentor if current role policy explicitly permits live breakout participation.
Do not assume.

DEFINITION OF DONE

Breakout room authorization mirrors canonical Team scope.
```

---

# 43. M16.11 — Master Breakout Navigation

## Objective

Let Master move between breakout rooms without changing Team/project permissions.

## Copy/Paste Prompt

```text
TASK ID: M16.11
TASK: Master Breakout Navigation

Implement only if breakout rooms are enabled.

OBJECTIVE

Provide Master an authorized list of Cohort Team breakout rooms.

SHOW

- Team name
- room join action
- linked Team Workspace action
- current Activity status if useful

SECURITY

- only Teams in Master's assigned Cohort.
- provider room credentials generated per join.
- no broad permanent room admin secret in client.

DO NOT

- expose Team private Workspace content merely from the breakout list.
- change Team membership.

DEFINITION OF DONE

Master can navigate pilot breakouts safely.
```

---

# 44. M16.12 — Team Workspace Link from Breakout

## Objective

Keep structured work adjacent to media.

## Copy/Paste Prompt

```text
TASK ID: M16.12
TASK: Breakout → Team Workspace Link

Implement only if breakouts enabled.

OBJECTIVE

Inside Team breakout view, provide:
- Open Team Workspace
- Open Current Activity
- Open Team Project

Each link uses existing FICI authorization.

RULES

1. provider room does not grant Workspace access.
2. removed user may not open Team Workspace even if old room UI remains open.
3. link must reauthorize on navigation.

DEFINITION OF DONE

Breakout media is logically connected to the correct Team work area.
```

---

# 45. M16.13 — Provider Failure Handling

## Objective

Ensure Daily outage/failure cannot corrupt FICI state.

## Copy/Paste Prompt

```text
TASK ID: M16.13
TASK: Daily Provider Failure Handling

SIMULATE

- room-create timeout
- token-create failure
- provider 5xx
- invalid provider response
- embedded room load failure

EXPECTED

- no Project state corruption.
- no Activity completion/change.
- existing Artifacts/Team/Chat remain available.
- safe user error.
- retry possible.
- provider error details logged safely.
- DAILY_API_KEY never exposed.

ROOM CREATION

If provider room succeeds but local mapping save fails:
define safe reconciliation/idempotency approach.

DEFINITION OF DONE

Live provider failures remain isolated to live media functionality.
```

---

# 46. M16.14 — Room Creation Idempotency

## Objective

Avoid orphan/duplicate Daily rooms during retries.

## Copy/Paste Prompt

```text
TASK ID: M16.14
TASK: Live Room Idempotency

OBJECTIVE

Test repeated get/create operations.

CASE 1

Master double-clicks Start Live Session.

Expected:
one canonical room mapping.

CASE 2

Client retries after timeout.

Expected:
same logical live session resolves existing provider room where possible.

CASE 3

Provider room created but response lost.

Expected:
reconciliation strategy prevents unbounded duplicate rooms.

Use:
- deterministic FICI live-session key,
- provider naming/idempotency where supported,
- canonical mapping transaction/reconciliation.

Do not invent a complex cleanup service unless needed.

DEFINITION OF DONE

Normal retries do not fragment one class into multiple rooms.
```

---

# 47. M16.15 — Token Expiration / Removed Member Test

## Objective

Verify future-access revocation.

## Copy/Paste Prompt

```text
TASK ID: M16.15
TASK: Join Token Expiration & Membership Revocation

SCENARIO

1. A1 authorized for Team A breakout.
2. A1 receives token.
3. Master removes A1.
4. A1 requests another token.

Expected:
DENIED.

5. old token handling:
document provider semantics.
6. after expiration, old token unusable.

RULE

Use short-lived tokens so membership changes take effect promptly.

Do not claim instant invalidation unless Daily integration actually supports it.

DEFINITION OF DONE

New live-room access always reflects current FICI membership.
```

---

# 48. M16.16 — Provider Secret Security

## Objective

Prove Daily secrets never reach client.

## Copy/Paste Prompt

```text
TASK ID: M16.16
TASK: Daily Secret Security

SEARCH CODEBASE FOR

- DAILY_API_KEY
- provider admin token
- room-owner secrets
- raw authorization headers

VERIFY

- server-only modules.
- not in NEXT_PUBLIC env.
- not serialized into React props.
- not returned by API.
- not logged.
- not included in browser bundle.

E2E

Inspect live classroom network responses.
Only safe join token/client room info may appear.

DEFINITION OF DONE

No Daily management credential is client-exposed.
```

---

# 49. M16.17 — Live-Class Authorization Regression

## Objective

Verify M16 does not weaken existing role/scope rules.

## Copy/Paste Prompt

```text
TASK ID: M16.17
TASK: Live-Class Authorization Regression

TEST

- unrelated Master cannot create Cohort room.
- Student cannot create Master room.
- Team B cannot join Team A breakout.
- removed A1 cannot get Team A breakout token.
- live room does not grant Team Workspace access.
- room does not grant Artifact access.
- room does not grant AI context.
- room does not grant file access.
- room does not grant Chat access beyond normal permissions.

EXPECTED

All existing authorization remains authoritative.

DEFINITION OF DONE

Live media is not a new privilege-escalation path.
```

---

# 50. M16.18 — Reconnect / Refresh

## Objective

Ensure live-class UI can recover without losing FICI state.

## Copy/Paste Prompt

```text
TASK ID: M16.18
TASK: Live Classroom Reconnect

SCENARIO

1. A1 joins Cohort room.
2. opens current Activity.
3. temporary network loss.
4. media disconnects.
5. FICI Activity/Project data remains saved.
6. A1 refreshes.
7. server rechecks authorization.
8. new token issued if required.
9. A1 rejoins.
10. current Activity still correct.

DEFINITION OF DONE

Media reconnect does not reset or corrupt educational work.
```

---

# 51. M16.19 — Pilot Live Classroom E2E

## Objective

Validate the full M16 Definition of Done.

## Copy/Paste Prompt

```text
TASK ID: M16.19
TASK: Pilot Live Classroom E2E

SCENARIO

1. Admin has configured Test Cohort.
2. Master opens Cohort.
3. Master opens/creates live classroom.
4. A1 and A2 request authorized join tokens.
5. B1 joins only if B1 belongs to same Cohort and Cohort room policy permits.
6. unrelated Cohort user denied.
7. users join embedded Daily room.
8. current FICI Activity shown.
9. Master launches/links Activity through FICI.
10. Students open Activity.
11. Students continue structured Team work.
12. work persists in PostgreSQL.
13. students leave/rejoin video.
14. Project/Activity state unchanged except explicit user actions.

OPTIONAL BREAKOUT

15. Master opens Team A/Team B separate rooms.
16. A1 joins Team A only.
17. B1 joins Team B only.
18. Master can navigate if authorized.

VERIFY

- Daily owns media only.
- FICI owns state.
- no cross-Team access.
- no secret exposure.

DEFINITION OF DONE

A Cohort can attend live class and continue structured work inside FICI.
```

---

# 52. M16.20 — M16 Security & Integration Hardening

## Objective

Review M16 before M17 final release hardening.

## Copy/Paste Prompt

```text
TASK ID: M16.20
TASK: M16 Security & Integration Hardening

Read first:

- /docs/03_ROLES_PERMISSIONS.md
- /docs/04_WORKSPACE_TEAM_COLLABORATION.md
- /docs/10_TECHNICAL_ARCHITECTURE.md
- /docs/12_ACCEPTANCE_TESTS.md
- /docs/13_CODEX_IMPLEMENTATION_PLAN.md
- /docs/21_CODEX_M7_PROMPTS.md
- /docs/29_CODEX_M15_PROMPTS.md
- /docs/30_CODEX_M16_PROMPTS.md

VERIFY

1. Daily behind provider abstraction.
2. DAILY_API_KEY server-only.
3. Cohort-room join reauthorizes current enrollment.
4. Team breakout join reauthorizes current membership.
5. room ID is not authorization.
6. Master limited to assigned Cohort.
7. Student cannot obtain Master token.
8. removed member cannot get new breakout token.
9. provider metadata contains no confidential Project data.
10. FICI remains source of truth.
11. video join/leave does not mutate Activity completion.
12. Activity links use normal authorization.
13. Daily chat does not replace canonical Team Chat.
14. recording management not added.
15. provider failure does not corrupt FICI state.
16. retry does not produce uncontrolled duplicate rooms.
17. no M17 hardening scope creep.

RUN

pnpm lint
pnpm typecheck
pnpm test:unit
pnpm test:integration
pnpm test:e2e
pnpm build
plus provider-adapter/security tests.

DEFINITION OF DONE

- Master room creation PASS
- authorized Student join PASS
- unauthorized Cohort join DENIED
- Team breakout isolation PASS if enabled
- member-removal token test PASS
- provider failure PASS
- room idempotency PASS
- secret-security PASS
- Activity integration PASS
- Pilot Live Classroom E2E PASS
- zero known live-room privilege escalation
- no M17 scope creep

FINAL REPORT

Return:
1. M16 summary
2. provider architecture
3. room lifecycle/mapping
4. token authorization
5. breakout status
6. security findings
7. provider-failure behavior
8. tests/results
9. remaining issues
10. recommendation: READY FOR M17 or NOT READY FOR M17
```

---

# 53. Daily vs FICI Session

Do not conflate:

```text
Daily Room
```

with:

```text
FICI Course Session / Activity
```

Daily Room is media infrastructure.

FICI Session/Activity is educational workflow.

---

# 54. Join Token vs FICI Session

A join token is temporary media access.

It is not:

- enrollment,
- Team membership,
- Activity participation record,
- course completion,
- Workspace permission.

---

# 55. Provider Room ID vs Permission

Knowing:

```text
room name
room URL
provider room ID
```

must not be enough to join a private class.

FICI authorization + provider join capability is required.

---

# 56. Room Creation vs Activity Launch

Creating live room does not necessarily launch Activity.

Master uses normal M7 operation for Activity lifecycle.

---

# 57. Video Presence vs Attendance

Being connected to video does not automatically mean:

- present for entire class,
- completed Session,
- completed Activity.

Do not infer educational completion from media connection.

---

# 58. Breakout vs Team Membership

Provider breakout assignment must follow current FICI Team membership.

Do not maintain an independent permanent breakout-member list in Daily.

---

# 59. Live Session vs Team Chat

FICI Team Chat remains persistent communication.

Daily media/chat is ephemeral/provider-controlled unless later product policy explicitly captures it.

---

# 60. Recording

Recording is out of scope.

Do not enable automatic recording.

Do not create recording storage/retention assumptions.

---

# 61. Screen Sharing

Daily may provide screen sharing as a media feature.

Using screen share must not grant access to FICI private resources.

It is the presenter's visual media action only.

---

# 62. Master Moderation

Do not assume full Zoom-like moderation is required.

Implement only provider controls required for secure pilot operation.

Advanced moderation is later scope.

---

# 63. Guest Access

Public/anonymous guest access is not part of M16.

All pilot users must authenticate through FICI unless later policy explicitly adds guests.

---

# 64. External Invite Links

Do not email/share raw unrestricted Daily room URLs as authentication.

Notifications may link to FICI live-classroom route.

The route authenticates/authorizes and then issues join capability.

---

# 65. Notifications Integration

M15 may optionally notify Cohort users that live class is available only if an approved event exists.

M16 does not require building new reminder scheduling.

Do not create calendar/reminder system.

---

# 66. Provider Webhooks

Daily webhooks are optional in M16.

If used:

- verify signatures,
- handle idempotently,
- store only needed provider events,
- do not let provider event directly mutate canonical Activity completion.

Do not add webhooks without a concrete M16 need.

---

# 67. Room End State

Exact meaning of "end live room" is not defined.

Do not silently decide:

- whether Master destroys room,
- expires room,
- reuses room next class,
- simply leaves.

If explicit end-room behavior is required:

```text
STOP → FLAG → ASK
```

---

# 68. Room Scheduling

M16 does not require a calendar scheduler.

Room may be created on demand for current Course Session.

Do not build Calendar integration.

---

# 69. Live Session Notifications

M16 does not require push/email reminders.

If the pilot later requires "class starts in 10 minutes", this is separate scheduling/notification functionality.

Do not invent it.

---

# 70. Provider Usage / Cost

M16 does not require detailed cost analytics.

If Daily returns usage metadata, it may be logged technically.

Do not build billing dashboard.

---

# 71. Browser Permissions

Live classroom UI must handle:

- camera permission denied,
- microphone permission denied,
- device unavailable,
- browser unsupported/limited.

Provide clear user-facing states.

Do not treat device-denial as FICI authorization failure.

---

# 72. Browser Acceptance

M17 performs broad browser release testing.

M16 should at least test the supported pilot browsers where feasible for embedded Daily experience.

Do not claim universal browser support without testing.

---

# 73. Mobile / Responsive

Complex structured work is primarily desktop/tablet.

M16 live room should remain usable on reasonable mobile view, but do not redesign the full platform for mobile during M16.

---

# 74. Accessibility

M16 surrounding FICI controls must support:

- keyboard access,
- meaningful labels,
- visible focus,
- clear join/leave/error controls.

Provider accessibility depends on Daily component capabilities.

Document provider limitations rather than hiding them.

---

# 75. Privacy / Consent

Video/audio introduces privacy considerations.

M16 product docs do not define recording/consent policy.

Therefore:

- no automatic recording,
- no hidden recording,
- no attendance surveillance,
- no background transcript capture.

Flag any requested recording feature for policy review.

---

# 76. M16 Expected Repository Additions

Conceptually:

```text
features/
└── live-classroom/
    ├── provider/
    ├── rooms/
    ├── tokens/
    ├── authorization/
    ├── breakout/
    ├── activity-link/
    └── ui/

lib/
├── live-classroom/
│   ├── provider.ts
│   ├── daily-provider.ts
│   ├── room-mapping.ts
│   └── join-authorization.ts
└── permissions/
    └── live-classroom.ts

tests/
├── unit/
│   └── live-classroom/
├── integration/
│   ├── live-room/
│   └── breakout/
└── e2e/
    └── live-classroom.spec.ts
```

Database migration is required only if a dedicated FICI live-room mapping table is approved/necessary.

Do not add schema solely for convenience.

---

# 77. M16 Completion Gate

M16 is complete only when:

```text
[ ] Daily integration exists
[ ] Daily is behind provider abstraction
[ ] DAILY_API_KEY is server-only

[ ] Master can get/create Cohort live room
[ ] unrelated Master denied
[ ] Student cannot create room

[ ] authorized Student can obtain join token
[ ] unauthorized Cohort user denied
[ ] client cannot spoof Master role
[ ] room ID alone does not grant access
[ ] token is temporary/minimal

[ ] live classroom UI works
[ ] current Activity is linked
[ ] FICI Activity remains canonical
[ ] joining/leaving does not auto-complete Activity
[ ] Project/Artifact state remains in FICI

[ ] optional breakout mapping works OR explicitly deferred
[ ] Team breakout authorization works if enabled
[ ] removed member cannot obtain new breakout token
[ ] Master breakout navigation works if enabled

[ ] Daily chat does not replace Team Chat
[ ] no advanced recording management
[ ] no custom WebRTC stack

[ ] provider failure does not corrupt FICI state
[ ] room creation is retry/idempotency safe
[ ] provider secret exposure test passes
[ ] Live Classroom E2E passes

[ ] lint passes
[ ] typecheck passes
[ ] unit tests pass
[ ] integration tests pass
[ ] E2E tests pass
[ ] build passes

[ ] no M17 scope implemented prematurely
[ ] Codex reports READY FOR M17
```

Any unauthorized room/token access is:

```text
BLOCKER
```

Any provider secret exposed to client is:

```text
BLOCKER
```

Any video-provider event mutating canonical educational state incorrectly is:

```text
ARCHITECTURE DEFECT
```

---

# 78. Recommended Commit Sequence

Example:

```text
feat(live): add live-classroom provider abstraction
feat(live): add Daily provider adapter
feat(live): add room mapping strategy
feat(live): add Master get/create room
feat(live): add Student join authorization
feat(live): add temporary join tokens
feat(live): add embedded classroom UI
feat(live): link current Activity
feat(live): add optional Team breakout mapping
feat(live): add breakout authorization
feat(live): add Master breakout navigation
test(live): add Cohort room security tests
test(live): add member-removal token tests
test(live): add provider failure/idempotency tests
test(security): add Daily secret exposure tests
test(e2e): add live-classroom pilot flow
chore(security): complete M16 hardening
```

---

# 79. M16 Non-Goals

Do not accept these as "helpful additions" during M16:

- custom WebRTC stack,
- custom SFU/media servers,
- Zoom parity,
- video recording library,
- transcription,
- AI meeting assistant,
- automatic notes,
- attendance scoring,
- student behavior analytics,
- public guest rooms,
- webinar mode,
- calendar scheduling,
- email reminders,
- custom media routing,
- M17 full release hardening.

---

# 80. Potential M16 Ambiguities Codex Must Flag

Do not silently decide if approved docs do not resolve:

- whether one Daily room is reused across Course Sessions,
- whether each class occurrence gets a new room,
- exact FICI schema for provider room mapping,
- whether Master can explicitly end/destroy a room,
- join-token lifetime,
- Master Daily permission claims,
- Student Daily permission claims,
- screen-share rights,
- whether Daily chat is enabled,
- whether recording is enabled,
- whether attendance is tracked,
- whether join/leave events are stored,
- whether Team breakout rooms are required for pilot,
- whether breakouts are created automatically or on demand,
- whether Mentor may join Team breakouts,
- whether Admin may join live Cohort room,
- whether users outside Cohort can be invited as guests,
- whether live room availability sends notification,
- whether Course Session has scheduled start/end time,
- whether provider webhooks are required,
- how to reconcile provider-created room if local mapping write fails.

If unresolved:

```text
STOP → FLAG → ASK
```

---

# 81. Recommended Safe Defaults for Purely Technical Decisions

Only where they do not alter approved product policy:

- Daily behind provider abstraction,
- server-only API key,
- Daily Prebuilt for MVP,
- private/token-gated rooms,
- server-derived participant identity,
- temporary join tokens,
- provider room IDs treated as integration metadata,
- no automatic recording,
- no guest access,
- no attendance inference,
- no Activity mutation on join/leave,
- explicit FICI authorization before every token issuance,
- Team breakout access from current Team membership,
- provider failure isolated from FICI state,
- no M17 scope.

---

# 82. Review Checklist for Ahmad/FICI

Before implementation, confirm M16 reflects the intended classroom model:

```text
1. Daily provides video/audio infrastructure.

2. FICI remains the owner of Course/Project/Activity state.

3. Master can open the live room.

4. Students must log into FICI before joining.

5. FICI checks Cohort authorization before issuing a join token.

6. Students cannot become Master by changing client data.

7. Current Activity is visible from the live classroom.

8. Students can continue structured Activity work while in class.

9. Video join/leave does not automatically change Activity status.

10. Team breakouts, if used, are separate Daily rooms mapped to Teams.

11. Team B cannot join Team A breakout.

12. Removed Team member cannot obtain a new Team-room token.

13. Daily room ID alone is never sufficient authorization.

14. Daily chat does not replace FICI Team Chat.

15. We are not building WebRTC ourselves.

16. We are not building advanced recording management.

17. Daily stays replaceable behind a provider abstraction.

18. M17 remains the final pilot-hardening/release milestone.
```

---

# 83. Next File After M16

After M16 has actually been:

```text
IMPLEMENTED
→ TESTED
→ SECURITY-REVIEWED
→ COMMITTED
```

create:

# `31_CODEX_M17_PROMPTS.md`

M17 will cover:

```text
Full RLS Review
Direct-ID Attack Tests
AI Leakage Tests
Transaction Rollback Tests
Browser Testing
Accessibility Review
Backup / Restore Test
Logging
Rate Limiting
File Limits
Error Handling
Full Professional Course E2E
MVP Release Checklist
Pilot Readiness Report
```

M17 is hardening/release preparation, not another feature-development milestone.

---

# 84. Final Execution Rule

For M16:

```text
PROVIDER ABSTRACTION
→ ROOM MAPPING
→ MASTER ROOM CREATION
→ STUDENT AUTHORIZATION
→ JOIN TOKEN
→ EMBEDDED CLASSROOM
→ ACTIVITY LINK
→ COHORT ROOM SECURITY
→ OPTIONAL BREAKOUTS
→ BREAKOUT AUTHORIZATION
→ MEMBER-REMOVAL CHECK
→ PROVIDER FAILURE
→ IDEMPOTENCY
→ SECRET SECURITY
→ LIVE CLASSROOM E2E
→ M16 HARDENING
```

Do not skip directly into M17 release work.

---

# End of Document

**Current Status:** Draft v0.1 — Ready for Ahmad/FICI review.  
**Execution Step After M15 Completion:** Start with **M16.1 — Live Classroom Provider Abstraction**.
