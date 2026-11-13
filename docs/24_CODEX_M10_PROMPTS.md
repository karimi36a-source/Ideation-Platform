# FICI Invention Education & Development Platform
## Codex M10 Execution Prompts — Voting & Decision Records

**Document:** `24_CODEX_M10_PROMPTS.md`  
**Status:** Draft v0.1 — For Review  
**Depends on:** `01_PRODUCT_REQUIREMENTS.md` through `23_CODEX_M9_PROMPTS.md`  
**Purpose:** Provide exact copy/paste prompts for Codex to implement Milestone M10 safely and incrementally after M9 is complete.

---

# 1. Preconditions

Do not begin M10 until M9 is:

```text
IMPLEMENTED
→ TESTED
→ SECURITY-REVIEWED
→ COMMITTED
```

Required M9 state:

- SCAMPER works,
- Brainstorming works,
- private-before-reveal works,
- Problem Storming works,
- Problem Bank exists,
- Solution Bank exists,
- Problems/Solutions are stable Development Objects,
- Problem/Solution relationships exist,
- M9 RLS/privacy tests pass,
- AT-SCAMPER tests pass or any M13-dependent share sub-case is explicitly deferred,
- AT-BRAIN tests pass,
- Professional Session 4 integration passes,
- Codex reports READY FOR M10.

If M9 is incomplete:

```text
STOP → FINISH M9 → REVIEW → COMMIT → BEGIN M10
```

Do not implement evaluation/decision logic on top of unresolved M9 object identity or privacy defects.

---

# 2. M10 Goal

M10 implements structured convergence and explicit human decisions.

The curriculum flow is:

```text
MULTIPLE OPTIONS
↓
DOT VOTING / OTHER DECISION-SUPPORT METHODS
↓
SEE DIFFERENCES
↓
DISCUSS
↓
UNDERSTAND
↓
HUMAN DECISION
↓
DECISION RECORD
```

The core product rule is:

# VOTING DOES NOT AUTOMATICALLY FINALIZE A DECISION

A vote is decision-support data.

A Decision Record is a separate human-authored/finalized project record.

---

# 3. M10 Product Boundary

M10 includes:

- `voting_sessions`,
- `voting_options`,
- `votes`,
- Dot Voting MVP,
- configurable vote limit,
- open voting,
- close voting,
- anonymous/hidden/reveal configuration support,
- server-side vote validation,
- voting results,
- `decisions`,
- `decision_options`,
- `decision_participants`,
- `decision_links`,
- create Decision,
- finalize Decision,
- supersede Decision,
- linking Decision to Voting Session,
- linking Decision to Artifacts/Development Objects,
- Evidence link extension point,
- Decision history,
- RLS/security,
- AT-VOTE acceptance tests,
- AT-DEC acceptance tests.

M10 does **not** yet fully implement:

- Fist to Five runtime,
- Planning Poker runtime,
- Evidence subsystem,
- AI,
- Affinity,
- Mind Map,
- Patent tools,
- general Sharing.

The architecture must preserve later support for Fist to Five and Planning Poker.

---

# 4. Curriculum Principle

Professional Course Session 5 teaches that voting is not about winning.

The intended learning pattern is:

```text
Vote
→ See the Differences
→ Discuss
→ Understand
→ Decide
```

Different votes are information.

The platform must not implement:

```text
top vote = automatic final decision
```

unless a future workflow explicitly defines such behavior.

---

# 5. Voting Session Schema

Implement:

```text
voting_sessions
```

Fields:

- `id`
- `activity_instance_id`
- `voting_type`
- `status`
- `vote_limit`
- `anonymous`
- `reveal_mode`
- `created_by`
- `opened_at`
- `closed_at`

Voting types in schema:

```text
DOT_VOTE
FIST_TO_FIVE
PLANNING_POKER
```

MVP M10 requirement:

```text
DOT_VOTE
```

FIST_TO_FIVE and PLANNING_POKER should be schema-compatible but may remain unimplemented at runtime.

---

# 6. Voting Option Schema

Implement:

```text
voting_options
```

Fields:

- `id`
- `voting_session_id`
- `development_object_id` nullable
- `label`
- `description`
- `sequence`

Preferred pattern:

```text
Voting Option
→ existing Development Object
```

Examples:

- Problem,
- Solution,
- Feature,
- Design option,
- Technical direction.

Do not duplicate canonical Problems/Solutions just to vote on them.

---

# 7. Vote Schema

Implement:

```text
votes
```

Fields:

- `id`
- `voting_session_id`
- `voting_option_id`
- `user_id`
- `value`
- `created_at`
- `revealed_at` nullable

For Dot Voting:

- `value` should follow the approved MVP semantics,
- vote limit must be enforced server-side,
- direct database insertion must not bypass limit.

---

# 8. Decision Schema

Implement:

```text
decisions
```

Fields:

- `id`
- `project_id`
- `workspace_id`
- `activity_instance_id` nullable
- `title`
- `question`
- `method`
- `outcome`
- `reasoning`
- `status`
- `decision_owner_user_id`
- `decided_at`

Decision is a persistent Project record.

It is not merely a summary of vote counts.

---

# 9. Decision Options

Implement:

```text
decision_options
```

Fields:

- `id`
- `decision_id`
- `label`
- `description`
- `selected`
- `development_object_id` nullable

A Decision may compare:

- Problems,
- Solutions,
- Features,
- directions,
- other project options.

Selected option must be explicit.

---

# 10. Decision Participants

Implement:

```text
decision_participants
```

Fields:

- `id`
- `decision_id`
- `user_id`
- `role`
- `position` nullable
- `comment` nullable

Purpose:

Preserve who participated and, where captured, their position/comment.

Do not infer platform authority from Decision participant role.

---

# 11. Decision Links

Implement:

```text
decision_links
```

Fields:

- `id`
- `decision_id`
- `linked_entity_type`
- `linked_entity_id`
- `relationship_type`

Decision links may point to:

- Voting Session,
- Artifact,
- Development Object,
- Evidence,
- AI Output.

At M10:

Fully support existing entities:
- Voting Session,
- Artifact,
- Development Object.

Evidence and AI links become fully operational in later milestones.

Do not create fake Evidence/AI records.

---

# 12. Dot Voting MVP

M10 must implement Dot Voting completely.

Minimum workflow:

```text
Create Voting Session
↓
Add Options
↓
Open Voting
↓
Eligible Participants Cast Votes
↓
Enforce Vote Limit
↓
Close Voting
↓
View Result
↓
Discuss
↓
Create / Finalize Human Decision
```

---

# 13. Vote Limit Rule

Acceptance requirement:

If:

```text
vote_limit = 3
```

a user cannot cast a fourth valid vote.

This must be enforced:

- server-side,
- transactionally/concurrency-safe,
- at database/business-operation level.

Frontend counters are not sufficient.

---

# 14. Vote Limit Concurrency

Two near-simultaneous vote requests must not bypass the limit.

Example:

```text
user already has 2 votes
↓
two concurrent vote requests
↓
only one may succeed if limit = 3
```

Required protection may use:

- transaction,
- row/advisory locking,
- serializable logic,
- constrained aggregation strategy,
- other safe repository-standard approach.

Silent over-voting is unacceptable.

---

# 15. Eligible Voter Rule

A user may vote only if authorized for:

```text
Activity Instance
+
Workspace
+
Project
+
Team where applicable
+
Voting Session
```

Do not allow:

```text
same Cohort
=
eligible to vote in every Team
```

Team B cannot vote in Team A.

---

# 16. Open / Closed State

Votes may be cast only while Voting Session is open.

Conceptual lifecycle:

```text
DRAFT / CREATED
↓
OPEN
↓
CLOSED
```

Exact status vocabulary should follow approved repository conventions.

After close:

```text
new votes = denied
```

unless a future authorized reopen policy is explicitly implemented.

---

# 17. Reveal / Anonymous Foundations

Schema supports:

```text
anonymous
reveal_mode
revealed_at
```

The API includes:

```text
revealVotingSession()
```

especially for Planning Poker or hidden voting modes.

M10 Dot Voting must respect configured visibility.

Do not expose hidden individual vote details before reveal when configuration forbids it.

Do not confuse:

```text
anonymous to participants
```

with:

```text
no auditability in database
```

The system may still need user identity internally for limit enforcement and integrity.

---

# 18. Voting Results

Voting results may include:

- count,
- distribution,
- option order,
- participant summary where policy allows.

But results must not automatically mutate:

- selected Solution,
- accepted Idea,
- Project baseline,
- Decision outcome.

Human finalization remains separate.

---

# 19. Decision Creation Contract

Approved:

```text
createDecision(input)
```

Input:

```text
projectId
workspaceId
activityInstanceId optional
title
question
method
options
```

The Decision should initially be non-final until `finalizeDecision()`.

---

# 20. Decision Finalization Contract

Approved:

```text
finalizeDecision(input)
```

Input:

```text
decisionId
selectedOptionId optional
outcome
reasoning
linkedEvidenceIds optional
linkedArtifactIds optional
linkedObjectIds optional
```

Critical rule:

```text
Voting result alone must not automatically finalize a decision.
Human finalization required.
```

---

# 21. Decision Reasoning Requirement

AT-DEC-001 requires finalized Decision to store:

- issue/question,
- outcome,
- reasoning,
- participants,
- linked evidence,
- timestamp.

Evidence subsystem is M12.

Therefore M10 should:

- support Decision Links structurally,
- fully link existing Artifacts/Objects/Voting,
- preserve Evidence extension point,
- complete Evidence-specific acceptance after M12 if no Evidence table exists yet.

Do not invent Evidence rows.

---

# 22. Supersede Decision

Approved:

```text
supersedeDecision(input)
```

Rule:

A later Decision may supersede an earlier Decision.

Earlier Decision remains in history.

Never:

```text
DELETE old decision
```

or:

```text
overwrite old outcome
```

Use an explicit relationship/history mechanism.

---

# 23. Decision History Principle

Project decision history must answer:

```text
What was decided?
Why?
By whom?
When?
Based on what?
What replaced it later?
```

This supports long-term invention traceability.

---

# 24. Session 5 Output

The Professional Course Session 5 curriculum says to save:

- Selected Problem(s),
- Selected Solution(s),
- Selected Feature(s),
- Decision Reasoning.

The platform should represent this with:

```text
Decision Record
+
Decision Options
+
Development Object links
+
Voting Session link
```

and optionally a `TEAM_DECISION_RECORD` Artifact using M8.

Do not store only a screenshot of vote results.

---

# 25. Team Decision Record Artifact

Where the approved Activity Definition expects an Artifact output:

```text
TEAM_DECISION_RECORD
```

M10 should compose it using:

- Decision Record,
- linked selected Project Objects,
- reasoning,
- linked Voting Session,
- Artifact/Version system from M8.

Decision remains canonical structured data.

Artifact is the versioned higher-level output.

---

# 26. Source-of-Truth Files

Before each M10 task, Codex must read:

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
/docs/19_CODEX_M5_PROMPTS.md
/docs/20_CODEX_M6_PROMPTS.md
/docs/21_CODEX_M7_PROMPTS.md
/docs/22_CODEX_M8_PROMPTS.md
/docs/23_CODEX_M9_PROMPTS.md
```

Also read the approved Professional Course Session 5 material.

---

# 27. Global Codex Header

Use this block at the beginning of every M10 task if project rules are not automatically retained:

```text
You are implementing the FICI Invention Education & Development Platform.

Before making changes:

1. Read the relevant /docs files and approved Session 5 curriculum.
2. Treat them as source of truth.
3. Do not invent missing business rules.
4. M10 MVP fully implements DOT_VOTE.
5. Preserve schema compatibility for FIST_TO_FIVE and PLANNING_POKER without pretending they are implemented.
6. Voting is decision support, not automatic final decision.
7. Human finalization is required for Decision Records.
8. Enforce vote limits server-side and concurrency-safely.
9. Preserve Team/Workspace/Project isolation.
10. Never trust client-provided voter identity, participant role, Decision owner, or vote count.
11. Reuse canonical Development Objects as options.
12. Do not duplicate Problems/Solutions for voting.
13. Preserve Decision history and supersession.
14. Use existing Activity Engine and Artifact/Version system.
15. Do not build M11+ Affinity/Mind Map or M12 Evidence.
16. Use migrations for schema changes.
17. Use strict TypeScript.
18. Validate runtime input.
19. If requirements conflict or are ambiguous, STOP → FLAG → ASK.
20. Run required validation before finishing.
21. Report:
    - files changed,
    - migrations,
    - operations,
    - vote-limit enforcement,
    - concurrency handling,
    - Decision finalization rules,
    - RLS,
    - tests,
    - results,
    - assumptions,
    - deferred later voting types,
    - unresolved issues.
```

---

# 28. M10.1 — Voting Schema

## Objective

Create Voting Session, Options and Votes.

## Copy/Paste Prompt

```text
TASK ID: M10.1
TASK: Voting Schema

Read first:

- /docs/08_DATA_MODEL_SCHEMA.md
- /docs/21_CODEX_M7_PROMPTS.md
- /docs/23_CODEX_M9_PROMPTS.md

OBJECTIVE

Create:
- voting_sessions
- voting_options
- votes

VOTING_SESSIONS FIELDS

- id
- activity_instance_id
- voting_type
- status
- vote_limit
- anonymous
- reveal_mode
- created_by
- opened_at
- closed_at

VOTING TYPES

- DOT_VOTE
- FIST_TO_FIVE
- PLANNING_POKER

M10 RUNTIME REQUIREMENT

Implement DOT_VOTE only unless another type is already explicitly approved for this milestone.

VOTING_OPTIONS FIELDS

- id
- voting_session_id
- development_object_id nullable
- label
- description
- sequence

VOTES FIELDS

- id
- voting_session_id
- voting_option_id
- user_id
- value
- created_at
- revealed_at nullable

RULES

1. Voting Session belongs to an Activity Instance.
2. Activity must be voting-compatible.
3. Option Development Object must be accessible and in compatible Project scope.
4. Vote belongs to valid Session and Option.
5. user_id server-derived.
6. vote_limit non-negative/valid.
7. add indexes for session/result/user counting.
8. preserve hidden/reveal fields.

TEST

- create DOT_VOTE session
- valid option linked to Problem/Solution
- invalid cross-Team Object rejected
- vote user spoof denied
- unsupported runtime type handled safely

VALIDATION

Run standard schema/tests.

DEFINITION OF DONE

Voting storage supports secure Dot Voting and future extension.

FINAL REPORT

Return schema, constraints, indexes, tests and deferred runtime types.
```

---

# 29. M10.2 — Create Voting Session

## Objective

Implement `createVotingSession(input)`.

## Copy/Paste Prompt

```text
TASK ID: M10.2
TASK: Create Voting Session

Read first:

- /docs/11_API_CONTRACTS.md
- /docs/03_ROLES_PERMISSIONS.md
- /docs/06_COURSE_ACTIVITY_WORKFLOWS.md

INPUT

activityInstanceId
votingType
voteLimit
anonymous
revealMode
options

AUTHORIZED ROLES

- Master
- permitted Team Lead / Activity host
according to approved Activity configuration.

Do not automatically grant Team Lead permission unless current Activity policy allows it.

FLOW

1. resolve authenticated actor.
2. verify Activity access and voting method.
3. validate votingType.
4. for M10, DOT_VOTE must work.
5. validate voteLimit.
6. validate options.
7. create Voting Session in non-open state.
8. create Voting Options transactionally.
9. preserve option order.
10. create audit/change event if required.

OPTIONS

If option references Development Object:
- object must be accessible,
- object must match Activity/Project scope.

If label-only option is allowed:
- preserve label/description without creating fake Project Object.

TEST

- authorized Master creates
- permitted host creates where configured
- unauthorized Student denied
- Team B object rejected
- invalid vote limit rejected

VALIDATION

Run tests.

DEFINITION OF DONE

Secure voting configuration can be created without starting voting prematurely.
```

---

# 30. M10.3 — Open Voting

## Objective

Implement `openVotingSession(votingSessionId)`.

## Copy/Paste Prompt

```text
TASK ID: M10.3
TASK: Open Voting Session

Read first:

- /docs/11_API_CONTRACTS.md
- /docs/12_ACCEPTANCE_TESTS.md

OBJECTIVE

Implement openVotingSession().

AUTHORIZATION

Only authorized Activity host / Master / configured role.

CHECK

- Session exists.
- Session belongs to accessible Activity.
- options are valid/non-empty according to policy.
- Session is in an openable state.
- voteLimit valid.

ON OPEN

- status → OPEN
- opened_at set
- voting becomes eligible for authorized participants.

DO NOT

- create votes,
- auto-select option,
- auto-finalize decision.

TEST

- valid open
- unauthorized open denied
- second open idempotent/conflict-safe
- archived/completed Activity behavior respected

DEFINITION OF DONE

Voting accepts votes only after authorized opening.
```

---

# 31. M10.4 — Cast Dot Vote

## Objective

Implement `castVote(input)` with server-enforced eligibility and vote limits.

## Copy/Paste Prompt

```text
TASK ID: M10.4
TASK: Cast Dot Vote

Read first:

- /docs/11_API_CONTRACTS.md
- /docs/12_ACCEPTANCE_TESTS.md

INPUT

votingSessionId
votingOptionId
value

OBJECTIVE

Implement secure DOT_VOTE casting.

CHECK

1. authenticated user.
2. Voting Session exists.
3. voting_type = DOT_VOTE for M10.
4. status = OPEN.
5. voter is eligible participant.
6. option belongs to Session.
7. Team/Workspace/Project access valid.
8. vote value valid for Dot Voting.
9. user's resulting vote total/count does not exceed vote_limit.
10. hidden/reveal behavior preserved.

IDENTITY

user_id must come from server auth.

CONCURRENCY

Enforce vote limit atomically.
Two concurrent requests must not exceed limit.

TEST

AT-VOTE-001:
voteLimit = 3
first 3 valid votes allowed
4th denied.

AT-VOTE-002:
Team B user cannot vote Team A.

Also test:
- closed Session denied
- fake userId ignored/denied
- invalid option denied
- direct DB limit bypass denied if relevant policy permits direct insert tests

DEFINITION OF DONE

Dot Voting is valid, bounded, scoped and concurrency-safe.
```

---

# 32. M10.5 — Voting Visibility / Reveal

## Objective

Implement hidden/reveal behavior generically enough for future voting methods.

## Copy/Paste Prompt

```text
TASK ID: M10.5
TASK: Voting Visibility & Reveal

Read first:

- /docs/08_DATA_MODEL_SCHEMA.md
- /docs/11_API_CONTRACTS.md

OBJECTIVE

Implement configured result visibility and `revealVotingSession()` foundation.

RULES

1. respect `anonymous`.
2. respect `reveal_mode`.
3. hide unrevealed individual values when configuration requires.
4. reveal only through authorized operation.
5. reveal only votes belonging to Session.
6. preserve user identity internally if required for integrity while hiding it from participant-facing result.

DOT VOTING

If Dot Voting is configured live-visible:
- aggregate may be visible according to Activity definition.

If hidden-until-close/reveal:
- enforce server-side.

FUTURE TYPES

Planning Poker can reuse the same reveal foundation later.

TEST

- hidden votes not visible before reveal
- authorized reveal exposes permitted result
- unauthorized participant cannot reveal
- Team B cannot query hidden votes
- anonymous mode does not leak voter identity to participants

DEFINITION OF DONE

Voting visibility is policy-driven and cannot be bypassed by direct query.
```

---

# 33. M10.6 — Close Voting

## Objective

Implement `closeVotingSession(votingSessionId)`.

## Copy/Paste Prompt

```text
TASK ID: M10.6
TASK: Close Voting Session

Read first:

- /docs/11_API_CONTRACTS.md
- /docs/12_ACCEPTANCE_TESTS.md

OBJECTIVE

Close voting safely.

AUTHORIZATION

Authorized Activity host / Master / permitted role.

ON CLOSE

- status → CLOSED
- closed_at set
- further votes rejected
- results become available according to reveal policy.

CRITICAL RULE

DO NOT:
- create final Decision automatically,
- set top option as selected Project direction,
- mutate Problem/Solution acceptance state,
- update Project baseline.

TEST

AT-VOTE-003:
close Session with clear highest-vote option.
Verify:
- no final Decision automatically created/finalized,
- no selected solution automatically marked final.

DEFINITION OF DONE

Voting ends cleanly while human Decision remains separate.
```

---

# 34. M10.7 — Voting Result Query

## Objective

Return authorized results without violating anonymity/reveal rules.

## Copy/Paste Prompt

```text
TASK ID: M10.7
TASK: Voting Results

OBJECTIVE

Implement an authorized result query/service.

RETURN AS POLICY ALLOWS

- option
- linked Development Object metadata where accessible
- vote total/distribution
- status
- whether results are revealed
- voter identities only if policy explicitly permits

RULES

- Team B cannot see Team A results.
- removed member cannot gain future access.
- hidden/unrevealed data stays hidden.
- result ordering must not be interpreted as a Decision.

TEST

- closed Dot Vote result correct
- vote count accurate
- unauthorized user denied
- anonymity respected
- no Decision side effect

DEFINITION OF DONE

Voting data is available for discussion without becoming automatic project truth.
```

---

# 35. M10.8 — Decision Schema

## Objective

Create formal Decision entities.

## Copy/Paste Prompt

```text
TASK ID: M10.8
TASK: Decision Schema

Read first:

- /docs/08_DATA_MODEL_SCHEMA.md
- /docs/05_DEVELOPMENT_PROJECT_MODEL.md

OBJECTIVE

Create:
- decisions
- decision_options
- decision_participants
- decision_links

DECISIONS FIELDS

- id
- project_id
- workspace_id
- activity_instance_id nullable
- title
- question
- method
- outcome
- reasoning
- status
- decision_owner_user_id
- decided_at

DECISION_OPTIONS

- id
- decision_id
- label
- description
- selected
- development_object_id nullable

DECISION_PARTICIPANTS

- id
- decision_id
- user_id
- role
- position nullable
- comment nullable

DECISION_LINKS

- id
- decision_id
- linked_entity_type
- linked_entity_id
- relationship_type

RULES

1. Decision belongs to Project + Workspace.
2. Activity link must be scope-compatible.
3. Object options must belong to authorized Project.
4. Decision owner server-validated.
5. finalized Decision remains historical.
6. future Evidence/AI links structurally supported without fake records.

TEST

- valid Team Decision
- valid Personal Decision where policy allows
- cross-Team object option denied
- owner spoof denied

DEFINITION OF DONE

Formal human decisions have durable structured storage.
```

---

# 36. M10.9 — Create Decision

## Objective

Implement `createDecision(input)`.

## Copy/Paste Prompt

```text
TASK ID: M10.9
TASK: Create Decision

Read first:

- /docs/11_API_CONTRACTS.md
- /docs/03_ROLES_PERMISSIONS.md

INPUT

projectId
workspaceId
activityInstanceId optional
title
question
method
options

FLOW

1. authenticate actor.
2. verify Project and Workspace access.
3. verify optional Activity scope.
4. create Decision in draft/open state.
5. create Decision Options.
6. link existing Development Objects where provided.
7. add initial Decision Participants if explicitly supplied/authorized.

METHOD

May record:
- DOT_VOTE,
- DISCUSSION,
- CONSENSUS,
- OTHER approved method
if source docs permit.

Do not invent broad method vocabulary if not defined.

VOTING LINK

If Decision follows Voting Session:
link through Decision Link rather than copying vote data.

TEST

- create Decision after Dot Vote
- options reference same Solution Objects from M9
- no automatic selected winner
- Team B denied
- removed member denied

DEFINITION OF DONE

Human decision process can begin without auto-finalization.
```

---

# 37. M10.10 — Finalize Decision

## Objective

Implement explicit human finalization.

## Copy/Paste Prompt

```text
TASK ID: M10.10
TASK: Finalize Decision

Read first:

- /docs/11_API_CONTRACTS.md
- /docs/12_ACCEPTANCE_TESTS.md
- approved Session 5 curriculum

INPUT

decisionId
selectedOptionId optional
outcome
reasoning
linkedEvidenceIds optional
linkedArtifactIds optional
linkedObjectIds optional

AUTHORIZATION

Use approved Decision owner/Team workflow role.

Do not infer that every voter can finalize.
Do not infer that top vote may finalize automatically.

CHECK

1. Decision exists and is finalizable.
2. actor authorized.
3. selectedOptionId belongs to Decision if used.
4. linked Artifact/Object accessible.
5. Evidence IDs only allowed if Evidence subsystem exists.
6. outcome non-empty as required.
7. reasoning captured.

ON FINALIZE

- set selected Decision Option explicitly.
- store outcome.
- store reasoning.
- set status finalized/current according to approved vocabulary.
- set decided_at.
- ensure Decision Participants are preserved.
- add Decision Links.
- write Project Change Log/audit where required.

TEST

AT-DEC-001 core:
- issue/question stored
- outcome stored
- reasoning stored
- participants stored
- timestamp stored
- existing Artifact/Object links stored
- Evidence link portion deferred only if M12 not yet exists.

Also verify:
- Student without authority cannot finalize
- top vote does not self-finalize

DEFINITION OF DONE

Decision finalization is explicit, human-controlled and traceable.
```

---

# 38. M10.11 — Link Decision to Voting / Artifact / Objects

## Objective

Preserve the basis for a human decision.

## Copy/Paste Prompt

```text
TASK ID: M10.11
TASK: Decision Link Integration

OBJECTIVE

Implement secure Decision Links for currently available entity types.

SUPPORTED NOW

- VOTING_SESSION
- ARTIFACT
- DEVELOPMENT_OBJECT

FUTURE

- EVIDENCE
- AI_OUTPUT

RULES

1. target exists.
2. target belongs to compatible authorized Project/scope.
3. Decision access and target access both required.
4. link history preserved.
5. linking does not transfer ownership.
6. linking a Voting Session does not make vote result authoritative automatically.

TEST

- Decision links Dot Voting Session
- Decision links selected Solution Object
- Decision links Problem/Solution Bank Artifact
- Team B target denied
- unrelated Project target denied

DEFINITION OF DONE

Decision reasoning can be traced to the information/method used.
```

---

# 39. M10.12 — Supersede Decision

## Objective

Implement later Decision replacement without erasing history.

## Copy/Paste Prompt

```text
TASK ID: M10.12
TASK: Supersede Decision

Read first:

- /docs/11_API_CONTRACTS.md
- /docs/12_ACCEPTANCE_TESTS.md
- /docs/05_DEVELOPMENT_PROJECT_MODEL.md

OBJECTIVE

Implement `supersedeDecision(input)`.

RULES

1. old Decision remains stored.
2. create/use a newer Decision record.
3. create explicit relationship:
   NEW DECISION → SUPERSEDES → OLD DECISION
or repository-approved equivalent.
4. old Decision status may become superseded/historical.
5. old outcome/reasoning/participants remain unchanged.
6. Project history remains queryable.

DO NOT

- overwrite old Decision text,
- delete old Decision,
- retarget old Decision ID.

TEST

AT-DEC-002:
- Decision D1 finalized
- later D2 finalized
- D2 supersedes D1
- D1 remains queryable
- relationship/history visible

DEFINITION OF DONE

Decision changes preserve the evolution of project reasoning.
```

---

# 40. M10.13 — Team Decision Record Artifact

## Objective

Produce the Session 5 durable Artifact output when configured.

## Copy/Paste Prompt

```text
TASK ID: M10.13
TASK: Team Decision Record Artifact

Read first:

- /docs/22_CODEX_M8_PROMPTS.md
- /docs/06_COURSE_ACTIVITY_WORKFLOWS.md
- approved Professional Course Session 5 curriculum

OBJECTIVE

Create TEAM_DECISION_RECORD Artifact from the structured Decision.

CONTENT SHOULD REPRESENT

- issue/question
- options considered
- selected Problem(s)/Solution(s)/Feature(s)
- voting/reference method
- final outcome
- reasoning
- participants
- decision timestamp

ARCHITECTURE

Decision = canonical decision data.
Artifact = versioned higher-level output.

Use Artifact/Object Links for selected Development Objects.

Use Decision Link/metadata to preserve Decision reference.

Do not duplicate Project Objects.

REGISTER

Team Decision Record as Activity Output.

If review/approval required:
use M8 workflow.

TEST

- artifact created from finalized Decision
- selected Solution IDs reused
- reasoning preserved
- versioning works
- downstream Activity can consume approved artifact if configured

DEFINITION OF DONE

Session 5 produces a durable structured Team Decision output.
```

---

# 41. M10.14 — Voting RLS

## Objective

Protect Voting Sessions, Options and Votes at the database boundary.

## Copy/Paste Prompt

```text
TASK ID: M10.14
TASK: Voting RLS

Read first:

- /docs/03_ROLES_PERMISSIONS.md
- /docs/04_WORKSPACE_TEAM_COLLABORATION.md
- /docs/12_ACCEPTANCE_TESTS.md

OBJECTIVE

Implement RLS for:
- voting_sessions
- voting_options
- votes

RULES

TEAM A
- eligible authorized participants may access according to voting state.
- Team B denied.

VOTE INSERT
- current auth user only.
- Session must be OPEN through business operation.
- Option must belong to Session.
- user eligible.

HIDDEN VOTES
- peer SELECT restricted until reveal according to policy.

MUTATION
Normal client cannot:
- create vote as another user,
- update vote user_id,
- change vote to another Session/Option,
- alter Session vote_limit,
- open/close Session directly,
- set reveal state directly.

LIMIT

RLS alone may not efficiently enforce aggregate vote limit.
Business operation + transaction is authoritative.
RLS prevents identity/scope bypass.

DIRECT TESTS

- Team B vote insert denied.
- exact Team A Voting Session ID denied to B.
- hidden A2 vote denied to A1 before reveal.
- closed session direct insert denied where policy can enforce.

DEFINITION OF DONE

Voting privacy/scope cannot be bypassed by direct database access.
```

---

# 42. M10.15 — Decision RLS

## Objective

Protect Decisions and prevent unauthorized finalization.

## Copy/Paste Prompt

```text
TASK ID: M10.15
TASK: Decision RLS

OBJECTIVE

Implement RLS for:
- decisions
- decision_options
- decision_participants
- decision_links

RULES

- Decision follows Project + Workspace scope.
- Team B cannot access Team A Decision.
- Personal Decision follows Personal Workspace privacy.
- removed member denied future private Team Decision access.
- normal Student cannot directly set finalized state unless authorized business rule permits.
- decision_owner_user_id cannot be spoofed.
- selected flag cannot be forged outside controlled Decision operation if finalization-sensitive.
- Decision Links cannot reference inaccessible entities.

DIRECT ATTACKS

- Team B exact Decision ID
- Student direct finalize UPDATE
- Student set selected option manually
- spoof decided_at
- spoof owner
- link Team A Decision to Team B Object

EXPECTED

Denied.

DEFINITION OF DONE

Human Decision integrity is preserved at database boundary.
```

---

# 43. M10.16 — AT-VOTE-001 to 003

## Objective

Implement complete Voting acceptance tests.

## Copy/Paste Prompt

```text
TASK ID: M10.16
TASK: Voting Acceptance Tests

Read first:

- /docs/12_ACCEPTANCE_TESTS.md
- /docs/24_CODEX_M10_PROMPTS.md

AT-VOTE-001 — Dot Vote Limit

Given vote limit = 3:
- first 3 valid votes succeed,
- fourth valid vote fails.

Also test concurrent requests cannot exceed 3.

Expected: PASS.

AT-VOTE-002 — Unauthorized User Cannot Vote

Team B user attempts Team A vote:
- API/service
- direct DB insert
- exact Session/Option IDs.

Expected: DENIED.
Priority: BLOCKER.

AT-VOTE-003 — Voting Does Not Auto-Finalize Decision

Close vote with a clear top option.

Verify:
- no finalized Decision auto-created,
- no option automatically becomes Team's final Decision,
- Project Object not auto-accepted,
- baseline unchanged.

Expected: PASS.

FINAL REPORT

Return test matrix, concurrency result and PASS/FAIL.
```

---

# 44. M10.17 — AT-DEC-001 to 002

## Objective

Implement Decision acceptance tests.

## Copy/Paste Prompt

```text
TASK ID: M10.17
TASK: Decision Acceptance Tests

Read first:

- /docs/12_ACCEPTANCE_TESTS.md
- /docs/24_CODEX_M10_PROMPTS.md

AT-DEC-001 — Decision Records Reasoning

Finalize Decision.

Verify:
- issue/question
- outcome
- reasoning
- participants
- linked Artifact/Object/Voting Session
- timestamp

If Evidence subsystem is not yet present:
record Evidence-link sub-check as M12-dependent,
without inventing Evidence.

AT-DEC-002 — Supersede Without Erasing

Create D1, finalize.
Create D2 later, finalize.
Supersede D1 with D2.

Verify:
- D1 remains,
- D1 reasoning remains,
- D2 remains,
- explicit supersession relation/history exists.

Expected: PASS for all M10-owned fields.

FINAL REPORT

Return test matrix, Evidence dependency note if applicable, PASS/FAIL.
```

---

# 45. M10.18 — Professional Session 5 Integration Scenario

## Objective

Validate the curriculum flow from M9 output to human Decision.

## Copy/Paste Prompt

```text
TASK ID: M10.18
TASK: Professional Session 5 Integration Scenario

Read first:

- approved Professional Course Session 5 curriculum
- /docs/23_CODEX_M9_PROMPTS.md
- /docs/24_CODEX_M10_PROMPTS.md

SCENARIO

1. Team A enters Session 5 with approved/current Problem Bank and Solution Bank.
2. Activity references existing Problem/Solution Development Objects.
3. Host creates Dot Voting Session.
4. Voting Options reference canonical Problems/Solutions.
5. voteLimit configured.
6. Team members cast votes.
7. close Voting.
8. inspect result.
9. no automatic Decision occurs.
10. Team discussion happens outside/around voting process.
11. authorized human creates Decision.
12. selected option explicitly recorded.
13. reasoning recorded.
14. participants recorded.
15. Voting Session linked.
16. selected Development Objects linked.
17. Team Decision Record Artifact created if configured.
18. output becomes available for next Session dependency when approved/configured.

VERIFY

- no Problem/Solution duplication,
- vote limit enforced,
- Team B denied,
- top vote not automatically final,
- human reasoning stored,
- same object IDs carry forward.

DEFINITION OF DONE

Session 5 changes many alternatives into an explicit human Decision while preserving structured history.
```

---

# 46. M10.19 — Voting/Decision Concurrency Tests

## Objective

Prevent race conditions affecting voting integrity or Decision finalization.

## Copy/Paste Prompt

```text
TASK ID: M10.19
TASK: Voting & Decision Concurrency

OBJECTIVE

Test concurrency-sensitive cases.

CASE 1 — VOTE LIMIT

User has 2/3 votes.
Two simultaneous vote requests.
Expected:
- one succeeds,
- one fails,
- total <= 3.

CASE 2 — CLOSE VS VOTE

Vote request races with Session close.
Expected:
- deterministic transaction outcome,
- no vote accepted after committed close.

CASE 3 — DOUBLE FINALIZE

Two finalizeDecision() requests.
Expected:
- one canonical finalization,
- no contradictory outcomes.

CASE 4 — SUPERSEDE RACE

Two newer Decisions attempt to supersede same current Decision if system has a current-decision concept.
Expected:
- no silent contradictory history.

Use transaction/state preconditions/locking consistent with repository architecture.

DEFINITION OF DONE

No last-write-wins corruption in voting or Decision finalization.
```

---

# 47. M10.20 — Cross-Team Leakage Security Tests

## Objective

Attack Voting and Decision boundaries.

## Copy/Paste Prompt

```text
TASK ID: M10.20
TASK: M10 Leakage Security Tests

FIXTURES

Team A:
- Voting Session VA
- Decision DA

Team B:
- Student B1

ATTEMPT AS B1

- fetch VA
- fetch VA options
- cast vote using exact IDs
- query votes
- query hidden votes
- reveal VA
- close VA
- fetch DA
- list Decision options
- finalize DA
- supersede DA
- create Decision Link to Team A Object
- direct DB queries

REMOVED TEAM A MEMBER

Attempt:
- vote in new Team A Session
- read new Team A Decision
- finalize Team A Decision.

EXPECTED

All unauthorized routes denied.

DEFINITION OF DONE

No cross-Team or removed-member Voting/Decision leakage remains.
```

---

# 48. M10.21 — M10 Security & Integrity Hardening

## Objective

Review M10 before collaborative mapping tools are introduced.

## Copy/Paste Prompt

```text
TASK ID: M10.21
TASK: M10 Security & Integrity Hardening

Read first:

- /docs/03_ROLES_PERMISSIONS.md
- /docs/04_WORKSPACE_TEAM_COLLABORATION.md
- /docs/05_DEVELOPMENT_PROJECT_MODEL.md
- /docs/06_COURSE_ACTIVITY_WORKFLOWS.md
- /docs/08_DATA_MODEL_SCHEMA.md
- /docs/10_TECHNICAL_ARCHITECTURE.md
- /docs/11_API_CONTRACTS.md
- /docs/12_ACCEPTANCE_TESTS.md
- /docs/21_CODEX_M7_PROMPTS.md
- /docs/22_CODEX_M8_PROMPTS.md
- /docs/23_CODEX_M9_PROMPTS.md
- /docs/24_CODEX_M10_PROMPTS.md

OBJECTIVE

Perform M10 security/integrity hardening.

VERIFY

1. DOT_VOTE fully implemented.
2. FIST_TO_FIVE/PLANNING_POKER not falsely represented as complete.
3. vote limits enforced server-side.
4. concurrency cannot exceed vote limit.
5. Team B cannot vote Team A.
6. hidden votes cannot leak before reveal.
7. closed voting blocks new votes.
8. closing voting does not auto-finalize Decision.
9. Decision finalization is explicit.
10. outcome/reasoning/participants stored.
11. Decision Links preserve basis.
12. old Decision survives supersession.
13. direct DB update cannot forge final Decision.
14. removed member cannot access future Team voting/decisions.
15. Team Decision Record uses M8 Artifact system.
16. no M11+ feature implemented.

RUN

pnpm lint
pnpm typecheck
pnpm test:unit
pnpm test:integration
pnpm test:e2e
pnpm build
plus all configured RLS/concurrency tests.

DEFINITION OF DONE

- AT-VOTE-001 PASS
- AT-VOTE-002 PASS
- AT-VOTE-003 PASS
- AT-DEC-001 PASS for M10-owned fields
- AT-DEC-002 PASS
- Session 5 integration PASS
- zero vote-limit bypass
- zero cross-Team leak
- zero automatic Decision finalization
- no M11+ scope creep

FINAL REPORT

Return:
1. security review
2. integrity review
3. issues found
4. issues fixed
5. remaining issues
6. BLOCKER status
7. tests/results
8. recommendation: READY FOR M11 or NOT READY FOR M11
```

---

# 49. Voting Type vs Decision Method

Do not conflate:

```text
voting_type
```

with:

```text
decision.method
```

Voting type describes the structured voting mechanic.

Decision method describes how the Team actually finalized its Decision.

Example:

```text
Voting Type = DOT_VOTE
Decision Method = discussion_after_dot_vote
```

if such method value is approved.

---

# 50. Dot Voting Semantics

Dot Voting is for prioritization.

It is not proof of:

- correctness,
- technical feasibility,
- patentability,
- safety,
- business viability.

Do not label highest votes as "best solution" automatically.

---

# 51. Fist to Five

Schema supports:

```text
FIST_TO_FIVE
```

Curriculum uses it to measure support and reveal concerns.

M10 architecture should allow it later.

Do not implement incomplete Fist-to-Five behavior and mark it production-ready unless explicitly required.

---

# 52. Planning Poker

Schema supports:

```text
PLANNING_POKER
```

Curriculum uses it for team estimation, not popularity voting.

Future implementation must preserve:

```text
estimate independently
→ reveal together
→ discuss differences
→ estimate again
```

M10 should preserve reveal architecture but need not implement full Planning Poker runtime.

---

# 53. Vote Value

`votes.value` exists because different voting methods need different values.

For Dot Voting, if the approved business rule is one dot per cast:

```text
value = 1
```

or equivalent.

Do not invent weighted Dot Voting unless source docs approve it.

---

# 54. Duplicate Vote on Same Option

The schema does not by itself state whether one user may place multiple dots on one option.

Do not silently choose.

If Session 5 or Activity config does not resolve it:

```text
STOP → FLAG → ASK
```

Possible future configurations may include:

- one vote per option,
- multiple dots allowed per option.

This affects uniqueness constraints.

---

# 55. Anonymous Voting

Anonymous participant display does not mean anonymous database identity.

The system still needs user identity for:

- eligibility,
- vote-limit enforcement,
- abuse prevention,
- audit where authorized.

Participant-facing queries may hide identity.

---

# 56. Reveal Mode

Exact `reveal_mode` vocabulary is not fully defined in the schema.

Do not invent permanent values without source support.

A safe typed model may be introduced only if consistent with Activity configuration and documented.

If unclear:

```text
FLAG → ASK
```

---

# 57. Reopen Voting

API says close locks votes unless reopened by authorized role, but a dedicated reopen contract is not specified.

Do not invent reopen behavior unless required.

M10 may safely omit reopen and treat close as final for MVP.

---

# 58. Decision Owner

`decision_owner_user_id` is the accountable owner/finalizer context.

Do not allow client spoofing.

Ownership does not necessarily mean sole participant.

---

# 59. Decision Participants

Decision Participants preserve involvement.

They do not automatically grant:

- Project access,
- Workspace access,
- approval authority.

Canonical permissions remain authoritative.

---

# 60. Decision Selected Option

Voting winner and Decision selected option are separate.

Example:

```text
Option A = highest votes
Human Decision selects Option B
Reasoning = technical risk discovered during discussion
```

The data model must support this.

---

# 61. Decision Links to Evidence — Deferred Integration

M10 supports the link shape.

M12 implements Evidence Records.

Do not mark full linked-evidence behavior complete until Evidence exists.

When M12 arrives, it should extend AT-DEC-001's Evidence link sub-check.

---

# 62. Decision Links to Artifacts

M10 can fully link:

- Problem Bank,
- Solution Bank,
- Team Decision Record,
- other authorized M8 Artifacts.

This helps show which structured outputs informed the Decision.

---

# 63. Decision Links to Voting

A Decision should be able to say:

```text
informed by Voting Session V123
```

This retains method traceability.

Do not copy all votes into Decision JSON unnecessarily.

---

# 64. Supersession

A later Decision can replace an earlier one.

Preferred history:

```text
D1 — finalized
D2 — finalized
D2 SUPERSEDES D1
```

D1 remains queryable.

---

# 65. Decision vs Artifact Approval

A Team Decision is not the same as Master Artifact Approval.

Example:

```text
Team decides Solution S3
```

then:

```text
Team Decision Record Artifact submitted
Master approves Artifact
```

These are separate events with separate authority.

---

# 66. Decision vs Project Baseline

Finalizing a Decision does not automatically update Project baseline unless a later explicit workflow says so.

Do not silently change baseline from a Decision.

---

# 67. Voting and Activity Engine

Voting Session must belong to an Activity Instance.

Use M7 for:

- participants,
- Project/Workspace/Team context,
- status/dependencies.

Do not build a standalone voting product detached from Activity scope.

---

# 68. Decision and Activity Output

A finalized Decision may become:

- Activity Output via Decision link/ID,
- Team Decision Record Artifact,
- input to later Activities.

Use the existing Activity Output extension point when Decision entity support is available.

---

# 69. Audit / Change Log

Recommended M10 events include:

```text
VOTING_SESSION_CREATED
VOTING_OPENED
VOTING_CLOSED
DECISION_CREATED
DECISION_FINALIZED
DECISION_SUPERSEDED
```

Do not log individual hidden vote values into broad audit metadata if that would violate anonymous/reveal policy.

Project Change Log may record meaningful finalized Decision changes.

---

# 70. M10 Expected Repository Additions

Conceptually:

```text
features/
├── voting/
│   ├── sessions/
│   ├── options/
│   ├── votes/
│   ├── results/
│   ├── access/
│   └── validation/
└── decisions/
    ├── operations/
    ├── options/
    ├── participants/
    ├── links/
    ├── supersession/
    └── access/

lib/
├── permissions/
│   ├── voting.ts
│   └── decision.ts
├── concurrency/
│   └── vote-limit.ts
└── traceability/

supabase/
├── migrations/
│   ├── ...voting_sessions...
│   ├── ...voting_options...
│   ├── ...votes...
│   ├── ...decisions...
│   ├── ...decision_options...
│   ├── ...decision_participants...
│   ├── ...decision_links...
│   └── ...m10_rls...
└── tests/
    └── rls/
        ├── voting...
        └── decisions...

tests/
├── unit/
│   ├── voting/
│   └── decisions/
├── integration/
│   ├── voting/
│   ├── decisions/
│   └── session5/
└── e2e/
    └── professional-session5.spec.ts
```

Exact paths may vary.

---

# 71. M10 Completion Gate

M10 is complete only when:

```text
[ ] voting_sessions exists
[ ] voting_options exists
[ ] votes exists

[ ] DOT_VOTE fully implemented
[ ] createVotingSession() implemented
[ ] openVotingSession() implemented
[ ] castVote() implemented
[ ] closeVotingSession() implemented
[ ] reveal foundation implemented where configured
[ ] result query implemented

[ ] vote limit enforced server-side
[ ] concurrent requests cannot exceed limit
[ ] unauthorized Team cannot vote
[ ] hidden vote rules enforced
[ ] closed Session rejects votes

[ ] voting does not auto-finalize Decision

[ ] decisions exists
[ ] decision_options exists
[ ] decision_participants exists
[ ] decision_links exists

[ ] createDecision() implemented
[ ] finalizeDecision() implemented
[ ] supersedeDecision() implemented

[ ] outcome/reasoning persisted
[ ] participants persisted
[ ] voting link supported
[ ] Artifact/Object links supported
[ ] Evidence link extension point preserved

[ ] Team Decision Record Artifact integration works where configured

[ ] Decision history survives supersession
[ ] direct client cannot forge final Decision
[ ] Team B cannot access Team A Decision
[ ] removed member denied future Team scope

[ ] AT-VOTE-001 PASS
[ ] AT-VOTE-002 PASS
[ ] AT-VOTE-003 PASS

[ ] AT-DEC-001 PASS for M10-owned fields
[ ] AT-DEC-002 PASS

[ ] Professional Session 5 integration PASS

[ ] lint passes
[ ] typecheck passes
[ ] unit tests pass
[ ] integration tests pass
[ ] E2E tests pass
[ ] RLS tests pass
[ ] concurrency tests pass
[ ] build passes

[ ] no M11+ feature implemented prematurely
[ ] Codex reports READY FOR M11
```

Any vote-limit bypass is:

```text
BLOCKER
```

Any cross-Team voting access is:

```text
BLOCKER
```

Any automatic vote→Decision finalization is:

```text
ARCHITECTURE DEFECT
```

---

# 72. Recommended Commit Sequence

Example:

```text
feat(voting): add Voting schema
feat(voting): add create/open operations
feat(voting): add secure Dot Vote casting
feat(voting): add reveal/result/close behavior
feat(decisions): add Decision schema
feat(decisions): add Decision creation
feat(decisions): add human finalization
feat(decisions): add Decision links
feat(decisions): add supersession history
feat(artifacts): add Team Decision Record integration
feat(security): add Voting/Decision RLS
test(voting): add AT-VOTE suite
test(decisions): add AT-DEC suite
test(session5): add Professional Session 5 flow
test(concurrency): add vote-limit races
test(security): add cross-Team Voting/Decision leakage tests
chore(security): complete M10 hardening
```

---

# 73. M10 Non-Goals

Do not accept these as "helpful additions" during M10:

- full Fist to Five runtime,
- full Planning Poker runtime,
- Affinity groups,
- Mind Map,
- React Flow,
- Liveblocks,
- Evidence records,
- Patent Workspace,
- AI Assistant,
- Sharing,
- automatic winner selection,
- automatic Project baseline update from voting,
- automatic Decision finalization,
- autonomous team decision-making.

---

# 74. Potential M10 Ambiguities Codex Must Flag

Do not silently decide if approved docs do not resolve:

- exact Voting Session status vocabulary,
- exact reveal_mode values,
- whether Dot Voting is live-result or hidden by default,
- whether Dot Voting is anonymous by default,
- whether a user may place multiple dots on one option,
- whether vote_limit counts total dots or number of distinct options,
- whether votes may be changed/retracted while open,
- whether closed Voting may be reopened,
- who may create Voting Session besides Master,
- whether Team Lead may open/close/reveal,
- whether Master may vote,
- whether Mentor may vote,
- whether Activity host is a distinct participant role,
- exact Decision status vocabulary,
- exact Decision method vocabulary,
- who may finalize Team Decision,
- whether Team Lead alone may finalize,
- whether final Decision requires all participants,
- whether Decision requires a selectedOptionId,
- whether multiple options may be selected,
- whether participant positions are mandatory,
- whether superseded Decision remains "finalized" plus superseded or changes status,
- whether final Decision automatically creates TEAM_DECISION_RECORD Artifact,
- whether Team Decision Record requires Master approval,
- whether Decision Evidence links wait until M12,
- whether Decision changes Project baseline automatically.

If unresolved:

```text
STOP → FLAG → ASK
```

---

# 75. Recommended Safe Defaults for Purely Technical Decisions

Only where they do not alter approved product policy:

- UUID IDs,
- server-derived voter identity,
- server-derived Decision owner identity,
- DOT_VOTE runtime only,
- future voting types preserved in enum/schema,
- vote limit checked transactionally,
- closed Session rejects new votes,
- no auto-finalization,
- canonical Project Objects referenced rather than copied,
- Decision history preserved,
- supersession uses explicit relationship/history,
- Team/Workspace/Project RLS enforced,
- direct DB identity spoof blocked,
- no Evidence records until M12.

---

# 76. Review Checklist for Ahmad/FICI

Before implementation, confirm M10 reflects the intended Session 5 model:

```text
1. M10 fully implements Dot Voting.

2. Fist to Five and Planning Poker remain future-compatible.

3. Team votes on existing Problems/Solutions/Options.

4. Vote limit is enforced by the server.

5. Team B cannot vote in Team A.

6. Voting can be opened and closed.

7. Hidden/reveal behavior is respected where configured.

8. Highest vote does not automatically become the final answer.

9. Team discusses the result.

10. Human creates/finalizes the Decision.

11. Decision stores outcome and reasoning.

12. Decision stores participants.

13. Decision can link to Voting Session and Project Objects.

14. Old Decision remains when superseded.

15. Session 5 can produce a Team Decision Record Artifact.

16. M10 does not yet build Affinity, Mind Map, Evidence, Patent, AI, or Sharing.
```

---

# 77. Next File After M10

After M10 has actually been:

```text
IMPLEMENTED
→ TESTED
→ SECURITY-REVIEWED
→ COMMITTED
```

create:

# `25_CODEX_M11_PROMPTS.md`

M11 will cover:

```text
Affinity Groups
Affinity Group Items
Collaborative Movement
Mind Maps
Mind Map Nodes
Mind Map Edges
Typed Nodes
React Flow
Liveblocks
Canonical PostgreSQL Save
Draft Artifact Version Checkpoints
Concurrency / Collaborative Save
```

---

# 78. Final Execution Rule

For M10:

```text
VOTING SCHEMA
→ CREATE SESSION
→ OPEN
→ CAST DOT VOTE
→ ENFORCE LIMIT
→ REVEAL / RESULTS
→ CLOSE
→ DECISION SCHEMA
→ CREATE DECISION
→ FINALIZE HUMAN DECISION
→ LINK BASIS
→ SUPERSEDE
→ TEAM DECISION RECORD
→ RLS
→ ACCEPTANCE TESTS
→ SESSION 5 E2E
→ CONCURRENCY TESTS
→ SECURITY HARDENING
```

Do not skip directly to Affinity or Mind Mapping.

---

# End of Document

**Current Status:** Draft v0.1 — Ready for Ahmad/FICI review.  
**Execution Step After M9 Completion:** Start with **M10.1 — Voting Schema**.
