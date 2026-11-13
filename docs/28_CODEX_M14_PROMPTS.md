# FICI Invention Education & Development Platform
## Codex M14 Execution Prompts — AI Context & AI Assistance

**Document:** `28_CODEX_M14_PROMPTS.md`  
**Status:** Draft v0.1 — For Review  
**Depends on:** `01_PRODUCT_REQUIREMENTS.md` through `27_CODEX_M13_PROMPTS.md`  
**Purpose:** Provide exact copy/paste prompts for Codex to implement Milestone M14 safely and incrementally after M13 is complete.

---

# 1. Preconditions

Do not begin M14 until M13 is:

```text
IMPLEMENTED
→ TESTED
→ SECURITY-REVIEWED
→ COMMITTED
```

Required M13 state:

- object-specific sharing works,
- Personal → Team selected sharing works,
- Team → Master sharing works,
- Team → Team controlled sharing works where enabled,
- revocation works,
- Share RLS works,
- AT-PW-004 passes,
- AT-SHARE-001 to 005 pass,
- relevant AT-E2E-PRIV-001 sharing paths pass,
- Codex reports READY FOR M14.

If M13 is incomplete:

```text
STOP → FINISH M13 → REVIEW → COMMIT → BEGIN M14
```

M14 must consume all existing authorization boundaries rather than create an AI-specific bypass.

---

# 2. M14 Goal

M14 adds permission-aware, activity-aware AI as a native platform capability.

The governing philosophy is:

# AI GENERATES → HUMAN EVALUATES → EVIDENCE VERIFIES → TEAM DECIDES

The target flow is:

```text
AUTHENTICATE USER
↓
RESOLVE PROJECT / WORKSPACE / ACTIVITY
↓
RESOLVE AI ROLE
↓
BUILD MINIMUM AUTHORIZED CONTEXT
↓
CALL AI PROVIDER THROUGH FICI ABSTRACTION
↓
VALIDATE OUTPUT
↓
SAVE AI OUTPUT
↓
SAVE CONTEXT REFERENCES
↓
SAVE USAGE EVENT
↓
HUMAN DISPOSITION
↓
OPTIONAL HUMAN-CONFIRMED CANDIDATE CONVERSION
```

AI is native.

AI is not authoritative.

---

# 3. M14 Product Boundary

M14 includes:

- AI provider abstraction,
- OpenAI Responses API adapter,
- AI Task Service,
- activity-specific AI roles,
- permission-aware Context Builder,
- context minimization,
- `ai_outputs`,
- `ai_context_references`,
- `ai_prompt_templates`,
- `ai_usage_events`,
- structured output validation,
- AI output classification,
- verification status,
- human disposition,
- candidate conversion,
- Project Object conversion with explicit human confirmation,
- AI usage logging,
- prompt-template version tracking,
- provider failure handling,
- privacy/security,
- AI leakage penetration tests,
- AT-AI-001 to AT-AI-009,
- AT-AI-LEAK-001 to 003,
- AT-E2E-AI-001,
- Professional Session 10 integration.

Optional/not required unless explicitly approved:

- `ai_conversations`,
- `ai_messages`,
- multi-provider routing,
- advanced cost dashboard,
- autonomous tools,
- public web research.

---

# 4. AI Product Principle

AI must not be implemented as only:

- generic chatbot,
- disconnected assistant panel,
- isolated content generator,
- hidden automation layer,
- silent project editor.

AI must connect to:

- current Program,
- current Session,
- current Activity,
- current Workspace,
- current Development Project,
- current approved baseline,
- relevant Artifacts,
- relevant Development Objects,
- relevant Evidence,
- Patent Records,
- Team Decisions,
- Instructor Feedback,
- current task.

---

# 5. Initial AI Role Catalog

The approved AI role catalog includes:

## 5.1 Invention Development Facilitator

Used for:

- general ideation,
- early development,
- problem exploration.

## 5.2 Structured Creativity Assistant

Used for:

- SCAMPER,
- structured variation,
- idea expansion.

## 5.3 Brainstorming Facilitator

Used for:

- divergence,
- idea expansion,
- problem storming,
- solution generation.

## 5.4 System Structure Analyst

Used for:

- Affinity,
- Mind Mapping,
- system/subsystem/component analysis,
- missing relationships.

## 5.5 Patent Research Assistant

Used for:

- search terms,
- synonyms,
- patent metadata organization,
- source extraction,
- relevant-result comparison.

## 5.6 Comparative / Critical Analyst

Used for:

- similarity/difference,
- gap analysis,
- option comparison,
- assumption challenge.

## 5.7 Problem-Solving Partner

Used for:

- resolving gaps,
- solution families,
- root cause,
- refinement.

## 5.8 Requirements Analyst

Used for:

- requirements,
- assumptions,
- constraints,
- risk,
- validation questions.

## 5.9 Validation Planning Assistant

Used for:

- PoC,
- prototype,
- MVP,
- experiments,
- evidence criteria,
- validation sequencing.

## 5.10 Market Research Assistant

Used for:

- customer hypotheses,
- research questions,
- competitor mapping,
- market assumptions,
- evidence structuring.

## 5.11 Execution Planning Assistant

Used for:

- backlog,
- dependencies,
- prioritization,
- milestones.

## 5.12 Finance Analysis Assistant

Used for:

- revenue assumptions,
- cost assumptions,
- runway,
- break-even,
- scenarios.

## 5.13 Pitch Review Assistant

Used for:

- story structure,
- evidence consistency,
- claim checking,
- missing proof.

## 5.14 Funding Strategy Assistant

Used for:

- funding logic,
- milestones/capital,
- investor criteria,
- fundraising preparation.

## 5.15 Critical Reviewer

Used for:

- contradiction detection,
- unsupported claims,
- missing evidence,
- unclear reasoning.

M14 MVP implementation may activate only roles needed by current Professional Course Activities, but the role architecture must support the full catalog.

---

# 6. AI Role Resolution

Each Activity Definition may define:

```text
ai_role_code
```

When AI is launched from an Activity:

```text
PROGRAM
+
SESSION
+
ACTIVITY
+
ACTIVITY DEFINITION
→
AI ROLE
```

Do not let the client freely impersonate an arbitrary AI role if Activity Definition specifies one.

AT-AI-001 requires SCAMPER Activity to resolve to:

```text
Structured Creativity Assistant
```

or configured equivalent.

---

# 7. AI Context Layers

The approved context architecture is layered.

## Layer 1 — Platform / FICI Rules

Contains:

- safety rules,
- methodology rules,
- human-control rules,
- project-state restrictions.

## Layer 2 — AI Role

Contains:

- role perspective,
- method,
- allowed behavior,
- prohibited behavior.

## Layer 3 — Project Context

Contains selected:

- current Project,
- approved baseline,
- relevant Development Objects,
- relevant Artifacts.

## Layer 4 — Workspace Context

Contains only authorized content from:

- Personal Workspace,
- Team Workspace,
- Instructor Workspace,
- Shared Workspace.

## Layer 5 — Activity Context

Contains:

- current task,
- Activity inputs,
- working Objects,
- output format,
- Activity state.

## Layer 6 — Evidence Context

Contains relevant:

- Evidence,
- Patent Records,
- tests,
- calculations,
- verified findings.

## Layer 7 — Feedback & Decision Context

Contains:

- instructor feedback,
- Team Decisions,
- revision requests,
- approval state.

The Context Builder should include only what the current task requires.

---

# 8. Context Minimization

Do not include the entire Project by default.

Example SCAMPER task may need:

- selected Problem,
- selected Component,
- current Concept,
- SCAMPER method instructions.

It does not need:

- unrelated finance assumptions,
- unrelated chat,
- future pitch material,
- unrelated Patent Logs.

Reasons:

- privacy,
- focus,
- lower cost,
- lower latency,
- traceability.

---

# 9. Permission-Aware Context — BLOCKER RULE

Before including any entity in AI context:

```text
CHECK USER ACCESS NOW
```

AI must not receive:

- another student's private draft,
- another Team's private Artifact,
- another Team's private Chat,
- instructor-only notes,
- restricted files,
- revoked shared entities,
- former Team content after user removal,
- hidden Brainstorm entries,
- inaccessible Evidence,
- inaccessible Patent notes.

AI service must not become a permission bypass.

---

# 10. Shared Context

M13 Share access may grant AI-readable context only when:

- Share is active,
- recipient currently matches destination,
- permission allows view,
- entity type is safe for context,
- Share has not been revoked.

After revocation:

```text
new AI context must not include source
```

This is AT-AI-LEAK-003.

---

# 11. Team Chat Context

Team Chat must **not** be automatically included.

If chat is used:

- user explicitly selects relevant messages,
- every message is authorized,
- selection is limited,
- Context Reference stored.

Formal decisions must come from Decision Records, not inferred from chat silently.

---

# 12. Private-Before-Reveal Context

For Brainstorming configured as private-before-reveal:

Before reveal:

```text
A1 AI may use A1 unrevealed entries
A1 AI must not use A2 unrevealed entries
```

After authorized reveal:

```text
Team AI may analyze revealed pool
```

This must be enforced by Context Builder.

---

# 13. Independent Thinking Control

Activities may delay AI until participant completes required independent work.

Example:

```text
Step 1 — Student creates 5 ideas
Step 2 — Student confirms independent work
Step 3 — AI assistance becomes available
```

If Activity Definition config includes such a gate, M14 must enforce it server-side.

Do not assume AI is always immediately available.

---

# 14. AI Output Schema

Implement:

```text
ai_outputs
```

Fields:

- `id`
- `project_id`
- `workspace_id`
- `activity_instance_id` nullable
- `requested_by`
- `ai_role`
- `task_type`
- `prompt_text`
- `response_text`
- `output_type`
- `verification_status`
- `disposition`
- `created_at`
- `model_provider_reference` nullable
- `metadata`

Approved output types:

```text
ANALYSIS
SUGGESTION
HYPOTHESIS
DRAFT
COMPARISON
CLASSIFICATION
SUMMARY
CANDIDATE_SOLUTION
```

---

# 15. AI Output Classification

Every saved AI result must have explicit `output_type`.

AI output must not be mislabeled as:

- Evidence,
- Team Decision,
- Instructor Feedback,
- Verified Fact,
- Approved Content.

This is AT-AI-006.

---

# 16. AI Verification Status

Approved conceptual states include:

```text
UNVERIFIED
UNDER_REVIEW
PARTIALLY_VERIFIED
VERIFIED_AGAINST_SOURCES
CONTRADICTED
REJECTED
```

Default should be:

```text
UNVERIFIED
```

Do not mark AI output verified because model confidence is high.

Verification requires human/evidence process.

---

# 17. AI Human Disposition

Approved disposition values in Data Model:

```text
KEEP_FOR_REVIEW
ACCEPT_AS_CANDIDATE
MODIFIED
REJECTED
INVESTIGATE_FURTHER
CONVERTED_TO_PROJECT_OBJECT
```

The broader workflow may also include:

- Link to Evidence,
- Share With Team,
- Submit to Master.

Those should use existing M12/M13/M8 systems rather than inventing duplicate AI-specific sharing/submission tables.

---

# 18. AI Context Reference Schema

Implement:

```text
ai_context_references
```

Fields:

- `id`
- `ai_output_id`
- `entity_type`
- `entity_id`
- `context_role`
- `included_snapshot_hash` or equivalent
- `permission_scope`

Approved context roles:

```text
CURRENT_PROJECT
CURRENT_ARTIFACT
PRIOR_APPROVED_OUTPUT
TEAM_DECISION
INSTRUCTOR_FEEDBACK
EVIDENCE
PATENT
GAP
COURSE_CONTEXT
```

Context References are required for traceability.

Do not rely only on storing one giant prompt string.

---

# 19. Prompt Template Schema

Implement:

```text
ai_prompt_templates
```

Suggested fields:

- `id`
- `role_code`
- `activity_type`
- `version`
- `system_instruction`
- `task_template`
- `output_schema`
- `status`
- `created_by`
- `created_at`

Prompt templates must be version-controlled.

FICI should own prompt logic.

Do not hide product methodology solely in provider-side configuration.

---

# 20. AI Usage Events

Implement:

```text
ai_usage_events
```

Suggested fields:

- `id`
- `user_id`
- `project_id`
- `workspace_id`
- `activity_instance_id`
- `task_type`
- `model_profile`
- `input_usage`
- `output_usage`
- `estimated_cost`
- `latency`
- `success_failure`
- `timestamp`

Use repository naming conventions for boolean/status fields.

Usage logs must not become a second store of full confidential prompts.

---

# 21. Optional AI Conversation Tables

Optional:

```text
ai_conversations
ai_messages
```

They are not required for task-based MVP.

If not explicitly approved:

```text
DEFER
```

Do not build a large chat system just because AI exists.

---

# 22. Provider Architecture

Technical Architecture selects:

```text
OpenAI Responses API
behind provider abstraction
```

The business layer should depend on an internal interface such as:

```text
AiProvider
```

not directly on vendor SDK calls.

The initial provider adapter may be:

```text
OpenAiResponsesProvider
```

Provider-specific IDs belong in metadata/provider reference, not as platform primary IDs.

---

# 23. Provider Abstraction Principle

Internal task methods may conceptually include:

```text
generateStructuredIdeas
analyzeGap
comparePatent
reviewArtifact
suggestRequirements
prepareValidationPlan
```

These route through task definitions and provider abstraction.

Do not scatter direct provider calls across UI/routes/features.

---

# 24. Model Profiles

Technical Architecture defines AI model profiles.

Use profile abstraction.

Do not hard-code model IDs throughout business logic.

Example profile concepts:

```text
FAST
STANDARD
DEEP_ANALYSIS
EXTRACTION
```

The selected Technical Architecture currently maps profiles to approved provider models/configuration.

Business operations should request profiles by task, not vendor model strings.

---

# 25. AI Task Contract

Every AI task must define:

- Task Name,
- Allowed Role,
- Required Context,
- Optional Context,
- Forbidden Context,
- Output Type,
- Output Schema,
- Verification Requirement,
- Allowed Project Actions,
- Cost Class.

Example:

```text
Task: Analyze Gap
Role: Comparative / Critical Analyst
Required:
- Gap
- Current Concept
Optional:
- Patent Evidence
- Instructor Feedback
Forbidden:
- Other Team Private Data
Output:
- Analysis
- Candidate Directions
Verification:
- Human Review Required
```

---

# 26. RunAiTask Contract

Implement a canonical operation:

```text
runAiTask(input)
```

Conceptual input:

```text
taskType
projectId
workspaceId
activityInstanceId optional
selectedContextRefs optional
userInstruction optional
```

Server checks:

- user authenticated,
- Project access,
- Workspace access,
- Activity access,
- AI enabled for Activity,
- AI role resolved,
- every selected context entity authorized,
- independent-work gate satisfied,
- request usage policy satisfied.

---

# 27. AI Request Lifecycle

Required flow:

```text
AUTHENTICATE
↓
AUTHORIZE PROJECT / WORKSPACE / ACTIVITY
↓
RESOLVE ROLE + TASK TEMPLATE
↓
BUILD MINIMUM AUTHORIZED CONTEXT
↓
REVALIDATE SELECTED CONTEXT
↓
ASSEMBLE FICI PROMPT
↓
CALL PROVIDER
↓
VALIDATE RESPONSE
↓
SAVE AI OUTPUT
↓
SAVE CONTEXT REFERENCES
↓
SAVE USAGE EVENT
↓
RETURN OUTPUT
```

Provider call must happen server-side.

API keys must never reach browser.

---

# 28. Structured Output Validation

When a task requires structured data:

```text
provider output
↓
runtime schema validation
↓
valid → save structured/normalized result
invalid → safe error / repair path
```

Examples:

SCAMPER suggestion:

```text
Technique
Original Element
Proposed Change
Reasoning
Potential Benefit
Risk / Unknown
```

Gap analysis:

```text
Gap
Evidence
Why It Matters
Candidate Direction
Verification Needed
```

Do not trust provider JSON without validation.

---

# 29. Free-Text AI Output

Free text is allowed for:

- explanation,
- coaching,
- brainstorming,
- critique.

But when content becomes Project data:

```text
human confirmation
→ structured Project Object / Draft
```

Do not let free text silently mutate canonical Project state.

---

# 30. AI Output Immutability

Saved AI output should remain immutable as generated.

If user edits it:

- create modified candidate,
- create Project Object,
- create Draft,
- or store separate human-modified representation.

Do not overwrite original AI response while still presenting it as original AI output.

---

# 31. AI-to-Project Promotion

Required flow:

```text
AI Suggestion
↓
Human Reviews
↓
Candidate
↓
Optional Evidence / Test
↓
Team Decision
↓
Approved Project Change
```

AI does not directly alter approved Project state.

---

# 32. Convert AI Output to Candidate

AT-AI-008 requires:

```text
human-confirmed AI output
→ Draft/Candidate Project Object
```

Provenance must retain:

- AI Output ID,
- requester,
- role,
- task type,
- Context References,
- provider reference where appropriate,
- human confirmer.

Do not create accepted/current Project Object without normal human workflow.

---

# 33. AI Project Write Boundaries

## AI Read Actions

May retrieve authorized:

- Project Objects,
- Artifacts,
- Evidence,
- Feedback,
- Patent Records,
- Decisions.

## AI Draft Write Actions

May propose/create after confirmation:

- Draft suggestion,
- Candidate Object,
- temporary structured output.

## AI Committed Write Actions

Must not occur silently for:

- accepted Team Objects,
- current Project baseline,
- formal Decisions,
- submissions,
- approvals,
- permission changes.

---

# 34. Human Confirmation

Recommended pattern:

```text
AI:
"Create 3 Candidate Requirements?"

User:
Confirm

System:
Creates Draft Requirement Objects
```

The provider/model does not directly execute hidden writes.

The server performs the user-confirmed business command.

---

# 35. AI Cannot Approve — BLOCKER RULE

No AI operation may:

- set Artifact Version `APPROVED`,
- set Artifact Version `CURRENT`,
- approve Submission,
- create approval Review Action as human,
- change Project baseline to an unapproved state,
- impersonate Master.

AT-AI-007 must pass.

---

# 36. AI Does Not Vote

AI may:

- analyze options,
- identify tradeoffs,
- summarize concerns.

AI must not:

- cast Dot Vote,
- submit Fist-to-Five support,
- submit Planning Poker estimate,
- count as Decision Participant unless explicitly labeled non-human and product later permits it.

Current product decision:

```text
AI DOES NOT VOTE
```

---

# 37. AI vs Evidence

AI output remains separate from Evidence.

Flow:

```text
SOURCE
↓
EXTRACTED INFORMATION
↓
AI ANALYSIS
↓
HUMAN INTERPRETATION
↓
DECISION
```

AI-generated patent summary is not Patent Evidence.

M12 Evidence must remain source-backed.

---

# 38. AI and Patent Analysis

AI may assist with:

- keywords,
- synonym expansion,
- technical terminology,
- metadata extraction,
- abstract summarization,
- claim-element extraction,
- structured comparison,
- similarity/difference,
- architecture reconstruction,
- gap candidates.

AI must not automatically conclude:

- novel,
- patentable,
- infringement,
- freedom to operate,
- legal protection.

---

# 39. Patent Source Traceability

When AI analyzes Patent material, preferred output should reference source location where practical:

- Patent Number,
- Claim Number,
- Figure,
- Paragraph,
- Section,
- Abstract,
- Description.

Preferred structure:

```text
Observation
Source Reference
Interpretation
Confidence / Uncertainty
```

---

# 40. AI in SCAMPER

AI may:

- propose substitutions,
- propose combinations,
- identify analogies,
- explore modifications,
- suggest alternative use,
- challenge unnecessary elements,
- suggest reverse/rearrange.

AI should increase variation, not collapse immediately to one answer.

If independent examples are required first, AI remains locked until activity rule is satisfied.

---

# 41. AI in Brainstorming

During divergence:

AI may:

- generate options,
- extend ideas,
- create solution families,
- explore perspectives.

AI should not:

- eliminate ideas,
- choose winner,
- force premature ranking,
- see unrevealed peer ideas.

---

# 42. AI in Problem Storming

AI may identify Problems from approved perspectives and challenge assumptions.

AI should keep problem exploration distinct from solution generation where Activity methodology requires it.

---

# 43. AI in Affinity / Mind Map

AI may:

- suggest possible clusters,
- identify missing relationships,
- identify structural gaps,
- critique system structure.

It must not silently:

- regroup canonical data,
- delete Project Objects,
- alter canonical relationships,
- rewrite approved Map Version.

Suggestions remain AI Output until human action.

---

# 44. AI in Voting / Decisions

AI may analyze:

- vote patterns,
- concerns,
- tradeoffs,
- missing information.

It must not:

- cast vote,
- finalize Decision,
- mark option selected,
- replace human reasoning.

---

# 45. AI in Evidence

AI may:

- summarize,
- classify,
- identify contradictions,
- suggest verification questions.

It must not:

- verify Evidence automatically,
- convert itself to Evidence,
- overwrite source fact with interpretation.

---

# 46. AI in Master Workspace

Master AI may support:

- review preparation,
- missing-section detection,
- comparing work to requirements,
- summarizing submissions,
- finding gaps,
- drafting feedback.

Master AI must not silently:

- grade,
- approve,
- reject,
- change student Artifact.

Formal actions remain human.

---

# 47. Prompt Architecture

Approved layered prompt construction:

```text
SYSTEM / PLATFORM RULES
+
AI ROLE
+
ACTIVITY INSTRUCTIONS
+
PROJECT CONTEXT
+
AUTHORIZED EVIDENCE
+
CURRENT TASK
+
REQUIRED OUTPUT FORMAT
```

Prompt logic must be owned/versioned by FICI.

---

# 48. Prompt Version Tracking

Saved AI Output should store or be traceable to:

- Prompt Template ID,
- Prompt Template Version,
- AI Role,
- Task Type,
- Model Profile.

If schema does not have dedicated columns, store safe references in metadata.

Do not rely only on provider logs.

---

# 49. Context Provenance

Saved AI Output must preserve meaningful Context References.

Example:

```text
AI Output A-104
Used Context:
- Invention Concept V1
- Gap G-03
- Patent USXXXX
- Evidence EV-12
- Team Decision D-07
```

AT-AI-005 requires this.

---

# 50. Context Snapshot Hash

`included_snapshot_hash` or equivalent should help record which state of a context entity was used.

For versioned Artifact context, prefer exact Version ID plus hash.

For mutable Development Object, hash relevant serialized context.

Do not store hidden unauthorized content in the hash metadata.

---

# 51. AI Usage Logging

Each provider attempt should record a usage event including:

- user,
- Project,
- Workspace,
- Activity,
- task type,
- model profile,
- input/output usage,
- estimated cost if available,
- latency,
- success/failure,
- timestamp.

Do not store full sensitive prompt in broad analytics tables.

---

# 52. Cost Control

AI system should support deliberate cost control.

Potential controls:

- Context minimization,
- task-specific model profile,
- request limits,
- prompt reuse,
- structured extraction,
- avoiding repeated unnecessary context.

M15 may later expose user/team usage visibility.

M14 implements data foundation and basic enforcement hooks.

---

# 53. AI Rate Limiting

Technical Architecture requires rate limiting for AI endpoints.

Implement:

- per-user/request technical rate limit,
- product-level usage limit extension point.

Exact business quota policy may be unresolved.

Do not invent pricing/plan limits.

---

# 54. Provider Failure

AT-AI-009 requires provider failure to be safe.

If provider fails:

- Project remains intact,
- no false approved output,
- no partial Project mutation,
- usage event records failure,
- safe error shown,
- retry possible.

If output save fails after provider success:

- do not perform candidate conversion,
- handle retry/idempotency.

---

# 55. Provider Replacement

Provider replacement must not lose:

- AI Outputs,
- Context References,
- Prompt Templates,
- Usage history,
- Human disposition,
- Project provenance.

Provider-specific IDs are metadata only.

---

# 56. Personal AI

Personal AI is private by default.

May use:

- user's private Objects,
- personal notes,
- current Project info user may access,
- shared Team info user may view,
- course materials.

Personal AI Output remains private until intentionally shared using M13.

---

# 57. Team AI

Team AI may use:

- Team-owned Artifacts,
- Team Decisions,
- Team Evidence,
- shared/approved Project context,
- Activity inputs.

Output visible only to authorized Team scope.

Requester remains identified.

---

# 58. Shared AI Context

If user can VIEW an entity through active Share, AI may use it if task requires it and policy allows.

If Share is COMMENT, AI still must not edit source.

If Share revoked, future context resolution removes it.

---

# 59. AI Output RLS

AI Output visibility follows:

```text
Workspace
+
Project
+
Share state if shared
+
Activity scope
```

Personal AI output private.

Team AI output Team-private.

Master AI output Instructor-scope unless intentionally shared.

Direct AI Output ID must not bypass security.

---

# 60. Context Reference RLS

Context References are sensitive because they reveal what the model saw.

Only users authorized to view the AI Output and relevant policy should see Context References.

A Context Reference must never become a backdoor to retrieve the underlying entity.

---

# 61. Prompt Template Access

Prompt templates are platform configuration.

Students normally do not need unrestricted editing rights.

Exact Admin/Master editing policy may be deferred.

At minimum:

- runtime can read active templates,
- unauthorized users cannot alter them,
- version history preserved.

---

# 62. AI Usage Event Access

Usage events may contain sensitive metadata.

Normal users should not enumerate organization-wide usage.

Master/Admin visibility policy should follow approved scope.

Exact dashboard policy may be deferred to M15.

---

# 63. Source-of-Truth Files

Before every M14 task, Codex must read:

```text
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
/docs/21_CODEX_M7_PROMPTS.md
/docs/22_CODEX_M8_PROMPTS.md
/docs/23_CODEX_M9_PROMPTS.md
/docs/24_CODEX_M10_PROMPTS.md
/docs/25_CODEX_M11_PROMPTS.md
/docs/26_CODEX_M12_PROMPTS.md
/docs/27_CODEX_M13_PROMPTS.md
```

Also read approved Professional Course Session 10 curriculum.

---

# 64. Global Codex Header

Use this block at the beginning of every M14 task if project rules are not automatically retained:

```text
You are implementing the FICI Invention Education & Development Platform.

Before making changes:

1. Read /docs/09_AI_ASSISTANT_SPEC.md in full.
2. Read all other relevant /docs listed in this task.
3. Treat those docs as product/security source of truth.
4. AI generates; humans evaluate; evidence verifies; team decides.
5. AI is not authoritative.
6. AI context is activity-specific and permission-aware.
7. Context must be minimized.
8. Do not trust client-selected Workspace/Project/entity IDs without reauthorization.
9. No AI request may include content the user cannot access.
10. Revoked Share content must not enter new AI context.
11. Removed Team members must not receive former Team context.
12. Unrevealed Brainstorm entries remain hidden.
13. Chat is excluded unless explicitly selected.
14. AI Output must remain separate from Evidence.
15. AI must not vote.
16. AI must not approve.
17. AI must not change permissions.
18. AI must not silently modify approved/current Project state.
19. Project-changing AI suggestions require explicit human confirmation.
20. Saved AI output preserves provenance/context references.
21. Provider calls are server-side only.
22. OpenAI Responses API stays behind provider abstraction.
23. Validate structured provider outputs.
24. Secrets never reach browser.
25. Use strict TypeScript.
26. Use migrations for schema changes.
27. Use Zod or equivalent runtime validation.
28. If requirements conflict or remain open questions, STOP → FLAG → ASK.
29. Run required validation before finishing.
30. Report:
    - files changed,
    - migrations,
    - provider abstraction,
    - Context Builder rules,
    - prompt templates,
    - model-profile routing,
    - RLS,
    - candidate conversion,
    - leakage tests,
    - usage logging,
    - provider-failure behavior,
    - tests/results,
    - assumptions,
    - unresolved issues.
```

---

# 65. M14.1 — AI Output Schema

## Objective

Create durable AI Output records with explicit provenance and classification.

## Copy/Paste Prompt

```text
TASK ID: M14.1
TASK: AI Output Schema

Read first:

- /docs/08_DATA_MODEL_SCHEMA.md
- /docs/09_AI_ASSISTANT_SPEC.md

CREATE

ai_outputs

FIELDS

- id
- project_id
- workspace_id
- activity_instance_id nullable
- requested_by
- ai_role
- task_type
- prompt_text
- response_text
- output_type
- verification_status
- disposition
- created_at
- model_provider_reference nullable
- metadata

OUTPUT TYPES

- ANALYSIS
- SUGGESTION
- HYPOTHESIS
- DRAFT
- COMPARISON
- CLASSIFICATION
- SUMMARY
- CANDIDATE_SOLUTION

DISPOSITIONS

- KEEP_FOR_REVIEW
- ACCEPT_AS_CANDIDATE
- MODIFIED
- REJECTED
- INVESTIGATE_FURTHER
- CONVERTED_TO_PROJECT_OBJECT

RULES

1. requested_by server-derived.
2. Project/Workspace compatible.
3. Activity, if present, scope-compatible.
4. AI role/task type controlled by Task Service.
5. default verification state = UNVERIFIED.
6. output_type required.
7. saved generated output immutable under normal user edit.
8. provider reference not platform primary identity.
9. metadata may contain prompt-template/model-profile references.

TEST

- create Personal AI Output.
- create Team AI Output.
- output type required.
- requested_by spoof denied.
- cross-Team Workspace mismatch rejected.

DEFINITION OF DONE

Saved AI results are explicit, immutable, provenance-aware records.
```

---

# 66. M14.2 — AI Context References

## Objective

Persist meaningful context provenance.

## Copy/Paste Prompt

```text
TASK ID: M14.2
TASK: AI Context Reference Schema

CREATE

ai_context_references

FIELDS

- id
- ai_output_id
- entity_type
- entity_id
- context_role
- included_snapshot_hash or equivalent
- permission_scope

CONTEXT ROLES

- CURRENT_PROJECT
- CURRENT_ARTIFACT
- PRIOR_APPROVED_OUTPUT
- TEAM_DECISION
- INSTRUCTOR_FEEDBACK
- EVIDENCE
- PATENT
- GAP
- COURSE_CONTEXT

RULES

1. referenced entity must have been authorized at request time.
2. Context Reference does not grant future access to underlying entity.
3. AI Output may keep provenance even if later Share is revoked.
4. recipient viewing AI Output must not automatically retrieve now-inaccessible source entity.
5. versioned source should store Version ID/hash where practical.

TEST

- AT-AI-005 fixture.
- revoked source remains historical reference but cannot be reopened without access.
- Team B cannot use Context Reference ID to fetch Team A source.

DEFINITION OF DONE

AI provenance is traceable without turning references into permission bypasses.
```

---

# 67. M14.3 — Prompt Templates

## Objective

Create FICI-owned, versioned AI prompt configuration.

## Copy/Paste Prompt

```text
TASK ID: M14.3
TASK: AI Prompt Templates

CREATE

ai_prompt_templates

FIELDS

- id
- role_code
- activity_type
- version
- system_instruction
- task_template
- output_schema
- status
- created_by
- created_at

RULES

1. templates version-controlled.
2. active template resolved server-side.
3. prior template versions retained.
4. runtime stores template/version reference in AI Output metadata where practical.
5. students cannot modify templates.
6. exact Admin/Master authoring policy follows approved permissions.
7. no provider-specific hidden prompt should replace FICI template source of truth.

SEED

Seed approved MVP templates only for current required tasks/roles.

DEFINITION OF DONE

AI methodology can evolve through versioned FICI configuration.
```

---

# 68. M14.4 — AI Usage Events

## Objective

Record basic AI usage/cost/performance data without leaking confidential content.

## Copy/Paste Prompt

```text
TASK ID: M14.4
TASK: AI Usage Events

CREATE

ai_usage_events

FIELDS CONCEPTUALLY

- id
- user_id
- project_id
- workspace_id
- activity_instance_id
- task_type
- model_profile
- input_usage
- output_usage
- estimated_cost
- latency
- success_failure
- timestamp

RULES

1. user_id server-derived.
2. one event per provider attempt/operation as appropriate.
3. record failures.
4. do not store full confidential context in usage record.
5. estimated cost nullable if provider data unavailable.
6. use current Technical Architecture naming conventions.

TEST

- success event.
- provider failure event.
- unauthorized user cannot enumerate Team B/organization-wide usage.

DEFINITION OF DONE

MVP has basic cost/performance observability without content duplication.
```

---

# 69. M14.5 — Provider Abstraction

## Objective

Keep FICI business logic provider-independent.

## Copy/Paste Prompt

```text
TASK ID: M14.5
TASK: AI Provider Abstraction

Read first:

- /docs/09_AI_ASSISTANT_SPEC.md
- /docs/10_TECHNICAL_ARCHITECTURE.md

OBJECTIVE

Create internal AI provider abstraction.

CONCEPTUAL INTERFACE

AiProvider.generate({
  modelProfile,
  instructions,
  input,
  outputSchema?,
  metadata?
})

RETURN

- text / structured output
- provider request/reference metadata
- usage
- latency
- status/error

INITIAL ADAPTER

OpenAI Responses API behind:
OpenAiResponsesProvider

RULES

1. no provider SDK calls in UI/components.
2. API key server-only.
3. provider IDs metadata only.
4. business tasks use internal Task Service.
5. provider failure normalized into platform error type.
6. future provider replacement possible.

VALIDATION

Run unit tests with mocked provider adapter.

DEFINITION OF DONE

FICI AI behavior is not tightly coupled to one vendor SDK.
```

---

# 70. M14.6 — Model Profile Resolver

## Objective

Route AI tasks through platform model profiles.

## Copy/Paste Prompt

```text
TASK ID: M14.6
TASK: AI Model Profile Resolver

Read first:

- /docs/10_TECHNICAL_ARCHITECTURE.md
- /docs/09_AI_ASSISTANT_SPEC.md

OBJECTIVE

Implement model-profile resolution by task.

PROFILE CONCEPTS

- FAST
- STANDARD
- DEEP_ANALYSIS
- EXTRACTION

Use the current Technical Architecture mappings.
Do not hard-code provider model strings throughout business logic.

TASK EXAMPLES

- simple classification → lightweight profile
- brainstorming → general profile
- patent comparison → deeper reasoning
- extraction → extraction profile

RULES

1. Task Contract selects allowed/default profile.
2. client cannot arbitrarily escalate to expensive profile unless policy permits.
3. usage event stores profile.
4. provider adapter receives resolved provider configuration.

DEFINITION OF DONE

Model selection is task-driven and replaceable.
```

---

# 71. M14.7 — AI Task Registry

## Objective

Define explicit FICI AI tasks rather than arbitrary unrestricted prompts.

## Copy/Paste Prompt

```text
TASK ID: M14.7
TASK: AI Task Registry

Read first:

- /docs/09_AI_ASSISTANT_SPEC.md
- /docs/06_COURSE_ACTIVITY_WORKFLOWS.md

OBJECTIVE

Implement typed AI task definitions.

EACH TASK DEFINES

- Task Name
- Allowed AI Role
- Required Context
- Optional Context
- Forbidden Context
- Output Type
- Output Schema
- Verification Requirement
- Allowed Project Actions
- Cost Class / Model Profile

INITIAL MVP TASKS SHOULD SUPPORT PROFESSIONAL COURSE NEEDS, SUCH AS

- SCAMPER assistance
- Brainstorming assistance
- System/Gap analysis
- Patent research assistance
- Comparative analysis
- Critical review
- Session 10 gap analysis / refinement

Do not invent unrelated autonomous tasks.

DEFINITION OF DONE

Every provider request originates from an explicit FICI task definition.
```

---

# 72. M14.8 — Permission-Aware Context Builder

## Objective

Build the highest-security M14 component.

## Copy/Paste Prompt

```text
TASK ID: M14.8
TASK: Permission-Aware AI Context Builder

Read first:

- /docs/03_ROLES_PERMISSIONS.md
- /docs/04_WORKSPACE_TEAM_COLLABORATION.md
- /docs/09_AI_ASSISTANT_SPEC.md
- /docs/27_CODEX_M13_PROMPTS.md

OBJECTIVE

Implement Context Builder that selects only relevant authorized context.

INPUT

- authenticated actor
- projectId
- workspaceId
- activityInstanceId optional
- taskType
- selectedContextRefs optional

ALGORITHM

1. resolve current user from session.
2. verify Project access.
3. verify Workspace access.
4. verify Activity access.
5. load Task Contract.
6. resolve required context types.
7. validate each selected entity independently.
8. include only entities actor can access now.
9. apply Share resolver for shared entities.
10. exclude revoked Shares.
11. exclude former-Team private content.
12. exclude unrevealed peer Brainstorm entries.
13. exclude chat unless explicitly selected.
14. minimize to task-relevant fields.
15. return context payload + Context Reference candidates.

DO NOT

- trust client saying entity is accessible.
- search all organization content.
- infer Team access from Cohort alone.
- expand all relationships recursively.

TEST

AT-AI-002, 003, 004, LEAK-001, LEAK-002, LEAK-003 foundations.

DEFINITION OF DONE

No AI call can receive content outside normal user authorization.
```

---

# 73. M14.9 — Activity AI Availability

## Objective

Respect Activity-specific AI role and educational gates.

## Copy/Paste Prompt

```text
TASK ID: M14.9
TASK: Activity AI Availability

OBJECTIVE

Implement AI availability resolver for an Activity.

CHECK

- Activity exists.
- actor authorized.
- Activity Definition permits AI.
- configured ai_role_code resolved.
- independent-work requirement satisfied.
- private-before-reveal rules satisfied.
- current Activity state allows AI.
- usage/rate limit permits request.

RETURN

- available true/false
- aiRole
- allowedTasks
- reason code if unavailable

AT-AI-001

SCAMPER Activity resolves Structured Creativity Assistant or configured equivalent.

DEFINITION OF DONE

AI availability follows curriculum, not a global always-on chatbot rule.
```

---

# 74. M14.10 — Prompt Assembly

## Objective

Build deterministic layered prompts from FICI-owned sources.

## Copy/Paste Prompt

```text
TASK ID: M14.10
TASK: AI Prompt Assembly

OBJECTIVE

Assemble prompt/instructions in this order:

SYSTEM / PLATFORM RULES
+
AI ROLE
+
ACTIVITY INSTRUCTIONS
+
PROJECT CONTEXT
+
AUTHORIZED EVIDENCE
+
CURRENT TASK
+
OUTPUT FORMAT

RULES

1. use versioned Prompt Template.
2. include only Context Builder result.
3. separate source Evidence from AI interpretation.
4. include verification warnings where task requires.
5. include methodology constraints.
6. record prompt-template version.
7. avoid unnecessary Team Chat/raw private data.
8. do not embed secrets.

For patent tasks:
include instruction:
- no novelty/patentability conclusion,
- preserve source references,
- identify uncertainty.

DEFINITION OF DONE

AI behavior is FICI-controlled, reproducible, and traceable.
```

---

# 75. M14.11 — Run AI Task

## Objective

Implement the canonical `runAiTask(input)` command.

## Copy/Paste Prompt

```text
TASK ID: M14.11
TASK: runAiTask()

Read first:

- /docs/11_API_CONTRACTS.md
- /docs/09_AI_ASSISTANT_SPEC.md

INPUT

taskType
projectId
workspaceId
activityInstanceId optional
selectedContextRefs optional
userInstruction optional

FLOW

1. authenticate.
2. authorize Project/Workspace/Activity.
3. resolve Activity AI availability.
4. resolve Task Contract.
5. resolve AI Role.
6. resolve Prompt Template.
7. build minimal authorized context.
8. select model profile.
9. assemble prompt.
10. call provider.
11. validate output.
12. create AI Output.
13. create AI Context References.
14. create AI Usage Event.
15. return saved output.

ATOMICITY / FAILURE

Provider call is external.
Database writes after successful provider response should be transactionally consistent.

If database save fails:
- do not mutate Project.
- safe retry/idempotency strategy.

DEFINITION OF DONE

One secure command owns the complete AI task lifecycle.
```

---

# 76. M14.12 — Structured Output Validation

## Objective

Prevent malformed AI structured responses from entering Project workflow.

## Copy/Paste Prompt

```text
TASK ID: M14.12
TASK: Structured AI Output Validation

OBJECTIVE

For tasks with output schema:

1. provider produces structured response.
2. validate with Zod/equivalent.
3. reject malformed structure.
4. do not create Project Object from invalid output.
5. optionally preserve provider raw response only according to approved error/retention policy.
6. usage event records failure/validation failure.

TEST

- valid structured SCAMPER response.
- valid Gap Analysis response.
- malformed response.
- missing required fields.
- unexpected extra fields according to schema policy.

DEFINITION OF DONE

Only validated AI structured results enter saved AI Output/project-conversion workflows.
```

---

# 77. M14.13 — AI Output Classification & Verification

## Objective

Enforce labels and default verification state.

## Copy/Paste Prompt

```text
TASK ID: M14.13
TASK: AI Output Classification

OBJECTIVE

Ensure every saved AI Output has:
- output_type,
- verification_status,
- ai_role,
- task_type,
- requested_by.

DEFAULT

verification_status = UNVERIFIED

AT-AI-006

Output visibly/data-wise classified as AI_ANALYSIS / AI_SUGGESTION / approved equivalent.

Never classify as:
- Evidence,
- Verified Fact,
- Team Decision,
- Approved Content.

TEST

- Analysis labeled.
- Suggestion labeled.
- Patent Summary remains AI Summary.
- no auto-verified output.

DEFINITION OF DONE

AI origin is unambiguous everywhere.
```

---

# 78. M14.14 — Human Disposition

## Objective

Record what humans do with AI output.

## Copy/Paste Prompt

```text
TASK ID: M14.14
TASK: AI Human Disposition

OBJECTIVE

Implement explicit disposition commands.

SUPPORTED CORE DISPOSITIONS

- KEEP_FOR_REVIEW
- ACCEPT_AS_CANDIDATE
- MODIFIED
- REJECTED
- INVESTIGATE_FURTHER
- CONVERTED_TO_PROJECT_OBJECT

RULES

1. only authorized user can disposition accessible output.
2. AI cannot set its own human disposition.
3. disposition change recorded/auditable where important.
4. original AI response remains immutable.
5. REJECTED output does not disappear if historically linked.
6. ACCEPT_AS_CANDIDATE does not mean approved/current.

If full disposition history is required but no schema exists:
use Change Log/audit rather than inventing duplicate workflow table unless approved.

DEFINITION OF DONE

Human response to AI is explicit and traceable.
```

---

# 79. M14.15 — Convert AI Output to Candidate Object

## Objective

Implement AT-AI-008.

## Copy/Paste Prompt

```text
TASK ID: M14.15
TASK: Human-Confirmed AI Candidate Conversion

Read first:

- /docs/05_DEVELOPMENT_PROJECT_MODEL.md
- /docs/12_ACCEPTANCE_TESTS.md

OBJECTIVE

Convert accepted AI output into a Draft/Candidate Development Object only after human confirmation.

FLOW

1. authenticated human selects AI Output.
2. verify AI Output access.
3. verify disposition/action allowed.
4. user confirms target Object type.
5. create Development Object in authorized Project/Workspace.
6. mark origin/provenance = AI-derived / source AI Output.
7. preserve human confirmer.
8. link original AI Output to new Object using approved relationship/provenance.
9. update AI disposition = CONVERTED_TO_PROJECT_OBJECT.
10. no approval/current baseline change.

IMPORTANT

API docs contain open question:
one confirmation vs two-stage Team acceptance.

If unresolved for Team-owned committed Candidate:
STOP → FLAG → ASK.

A safe M14 baseline is Draft/Candidate only, never approved.

TEST

AT-AI-008:
AI Output → Draft/Candidate Object with provenance.

DEFINITION OF DONE

Human-confirmed conversion works without bypassing Project governance.
```

---

# 80. M14.16 — AI + Artifact Revision

## Objective

Ensure AI-assisted changes preserve M8 versioning.

## Copy/Paste Prompt

```text
TASK ID: M14.16
TASK: AI-Assisted Artifact Revision

OBJECTIVE

If AI suggests changes to approved Artifact:

1. current approved Version remains immutable.
2. user accepts suggestion as Draft change.
3. create/reuse new Draft Artifact Version.
4. link AI Output provenance.
5. human edits/reviews.
6. normal Submission/Review/Approval required.
7. new Version becomes current only after human approval.

DO NOT

- modify approved Version body.
- auto-submit.
- auto-approve.
- auto-change baseline.

TEST

- approved V1.
- AI suggests change.
- create V2 Draft.
- V1 unchanged.
- AI source linked.
- approval still human.

DEFINITION OF DONE

AI integrates with M8 without weakening version history.
```

---

# 81. M14.17 — AI + Evidence Boundary

## Objective

Preserve M12 Evidence separation.

## Copy/Paste Prompt

```text
TASK ID: M14.17
TASK: AI / Evidence Separation

OBJECTIVE

Enforce:
AI Output ≠ Evidence.

AI may:
- summarize Evidence,
- compare Evidence,
- suggest Evidence needed,
- propose source references.

AI may not:
- create VERIFIED Evidence automatically,
- promote its response into Evidence automatically,
- mark source Evidence verified.

To create Evidence:
human must invoke M12 createEvidence() with a real source.

TEST

Re-run AT-EV-002 with real AI Output entity present.

Expected:
No automatic Evidence row.

DEFINITION OF DONE

M14 preserves M12 evidence integrity.
```

---

# 82. M14.18 — AI + Sharing Boundary

## Objective

Use M13 Shares correctly in Context Builder.

## Copy/Paste Prompt

```text
TASK ID: M14.18
TASK: AI Shared-Context Integration

OBJECTIVE

Allow AI to use an entity shared to the requester only while Share is active and task-relevant.

TEST CASES

1. Team A shares Artifact X VIEW with Team B.
2. B1 AI may use X if selected/relevant.
3. B1 AI must not use Team A sibling Artifact Y.
4. Team A revokes X.
5. B1 asks AI again about X.
6. Context Builder rejects/excludes X.

AT-AI-LEAK-003:
must PASS.

COMMENT permission:
may still permit AI read context if VIEW is implied, but no source write.

DEFINITION OF DONE

AI follows M13 dynamic Share authorization.
```

---

# 83. M14.19 — AI + Private Brainstorm Boundary

## Objective

Prevent AI from bypassing M9 hidden-before-reveal rules.

## Copy/Paste Prompt

```text
TASK ID: M14.19
TASK: AI Brainstorm Privacy

OBJECTIVE

Test private-before-reveal Brainstorming.

BEFORE REVEAL

A1:
- own AI may access A1 hidden entries if activity permits.
- AI must not retrieve A2 hidden entries.

AFTER REVEAL

Team AI may analyze revealed pool.

ATTACK

A1 manually supplies A2 hidden Brainstorm Entry ID.

Expected:
Context Builder rejects.

DEFINITION OF DONE

AI cannot become a hidden peer-idea disclosure channel.
```

---

# 84. M14.20 — AI + Team Removal Boundary

## Objective

Implement AT-AI-004.

## Copy/Paste Prompt

```text
TASK ID: M14.20
TASK: Removed Member AI Access

SCENARIO

1. A1 is Team A member.
2. A1 runs Team AI successfully.
3. Master removes A1.
4. A1 runs AI request referencing Team A.
5. A1 manually supplies known Team A Artifact/Object IDs.

EXPECTED

- Workspace/Team access denied.
- Context Builder excludes Team A private data.
- no provider request containing Team A data is sent.

Priority:
BLOCKER.

DEFINITION OF DONE

AT-AI-004 passes.
```

---

# 85. M14.21 — AI Provider Failure Handling

## Objective

Implement AT-AI-009.

## Copy/Paste Prompt

```text
TASK ID: M14.21
TASK: AI Provider Failure

OBJECTIVE

Handle provider errors safely.

SIMULATE

- timeout,
- provider 5xx,
- invalid structured response,
- rate limit,
- network error.

EXPECTED

- Project unchanged.
- no candidate object.
- no Artifact approval.
- no partial Context Reference orphan state.
- usage event records failure.
- user gets safe error.
- retry possible.
- secrets/provider details not exposed.

If output record for failed attempt is stored:
it must be clearly ERROR/FAILED according to approved schema.
Do not invent fake generated content.

DEFINITION OF DONE

AT-AI-009 passes.
```

---

# 86. M14.22 — AI Output RLS

## Objective

Protect AI Outputs directly in PostgreSQL.

## Copy/Paste Prompt

```text
TASK ID: M14.22
TASK: AI Output RLS

OBJECTIVE

Implement RLS for:
- ai_outputs
- ai_context_references

RULES

PERSONAL
- only owner/source authorized scope.
- A2 cannot read A1 Personal AI Output.

TEAM
- active Team scope only.
- Team B denied.
- removed member denied future Team AI Outputs.

MASTER
- Instructor Workspace policy only.

SHARED
- M13 Share required if shared.

MUTATION

Normal client cannot:
- spoof requested_by,
- change Workspace/Project,
- relabel AI output as Evidence,
- set verification verified without policy,
- alter original generated response,
- set disposition to converted without business command,
- alter Context References to inaccessible entities.

DIRECT ID ATTACKS

- AI Output ID.
- Context Reference ID.

Expected:
FORBIDDEN / safe NOT_FOUND.

DEFINITION OF DONE

Saved AI data cannot bypass Workspace/Project boundaries.
```

---

# 87. M14.23 — Prompt Template / Usage RLS

## Objective

Protect platform AI configuration and usage telemetry.

## Copy/Paste Prompt

```text
TASK ID: M14.23
TASK: AI Configuration & Usage RLS

OBJECTIVE

Protect:
- ai_prompt_templates
- ai_usage_events

PROMPT TEMPLATES

- runtime read through server.
- unauthorized Student cannot edit.
- version history preserved.
- active/inactive status controlled.

USAGE EVENTS

- ordinary user may access own usage if product exposes it.
- Team/organization-wide usage only if approved scope.
- no cross-Team analytics leakage.
- sensitive metadata minimized.

TEST

- Student attempts prompt-template update → denied.
- Team B user attempts Team A usage query → denied.

DEFINITION OF DONE

AI configuration/analytics are not a privacy or prompt-tampering vector.
```

---

# 88. M14.24 — AT-AI-001 to 009

## Objective

Implement complete AI acceptance suite.

## Copy/Paste Prompt

```text
TASK ID: M14.24
TASK: AI Acceptance Tests

AT-AI-001 — Activity-Specific Role
SCAMPER resolves Structured Creativity Assistant/configured equivalent.
PASS.

AT-AI-002 — Team Context Authorization
Team A AI uses Team A authorized context.
No Team B private data.
BLOCKER.

AT-AI-003 — Private AI Context
A1 Personal AI may use A1 private content.
A2 AI may not.
BLOCKER.

AT-AI-004 — Removed Member AI Access
Removed A1 gets no Team A private AI context.
BLOCKER.

AT-AI-005 — Context References Stored
Saved AI Output stores meaningful Context References.
PASS.

AT-AI-006 — AI Output Label
Saved output clearly classified AI_ANALYSIS / AI_SUGGESTION / equivalent.
BLOCKER.

AT-AI-007 — AI Cannot Auto-Approve
No AI operation can mark Artifact Version APPROVED/CURRENT.
BLOCKER.

AT-AI-008 — Convert to Candidate
Human-confirmed AI Output creates Draft/Candidate Object with provenance.
PASS.

AT-AI-009 — Provider Failure
No project corruption; safe error; retry possible.
PASS.

FINAL REPORT

Return full test matrix and PASS/FAIL.
```

---

# 89. M14.25 — AI Leakage Penetration Tests

## Objective

Implement AT-AI-LEAK-001 to 003.

## Copy/Paste Prompt

```text
TASK ID: M14.25
TASK: AI Leakage Penetration Tests

AT-AI-LEAK-001

A1 prompt:
"Summarize the best solution from other teams."

Expected:
Context retrieval contains no Team B private content.
Provider never receives Team B private data.

BLOCKER.

AT-AI-LEAK-002

B1 manually supplies Team A Artifact ID.

Expected:
Context resolver rejects it before provider call.

BLOCKER.

AT-AI-LEAK-003

Team A Artifact was shared with B1/Team B, then revoked.

B1 requests AI analysis afterward.

Expected:
revoked source excluded/rejected.

BLOCKER.

ALSO ATTACK

- guessed Evidence ID
- guessed Patent Record ID
- guessed Personal Artifact ID
- guessed Chat Message ID
- guessed File ID
- guessed Mind Map Node ID
- hidden Brainstorm Entry ID

No unauthorized context may enter provider payload.

DEFINITION OF DONE

All AI leakage penetration tests pass.
```

---

# 90. M14.26 — AI Provider Payload Inspection Tests

## Objective

Prove unauthorized content is absent before provider invocation.

## Copy/Paste Prompt

```text
TASK ID: M14.26
TASK: AI Provider Payload Security Tests

OBJECTIVE

Mock provider and inspect exact request payload.

TEST

Authorized Team A request:
- contains only approved Team A/context entities.

Unauthorized selected Team B ID:
- operation rejected before provider call.

Revoked Share:
- source absent.

Personal A1:
- A2 content absent.

Private Brainstorm:
- peer hidden entries absent.

Chat:
- not included unless explicitly selected.

IMPORTANT

Do not assert only response behavior.
Verify provider request itself contains no unauthorized content.

DEFINITION OF DONE

Security is enforced before data leaves FICI boundary.
```

---

# 91. M14.27 — Session 10 AI Integration

## Objective

Implement Professional Course Session 10 workflow using prior structured Project data.

## Curriculum Principle

Session 10 connects and reuses Sessions 1–9.

It does not replace earlier methodology.

Core sequence:

```text
LOAD CURRENT BASELINE
+
LOAD PATENT LANDSCAPE / EVIDENCE
↓
AI RECONSTRUCTS CURRENT INVENTION
↓
HUMAN CHECKPOINT
↓
ANALYZE GAPS
↓
ONE GAP AT A TIME
↓
ROOT CAUSE / PROBLEM STORMING / SCAMPER / BRAINSTORMING
↓
CANDIDATE DIRECTIONS
↓
CRITICAL REVIEW
↓
HUMAN SELECTION
↓
VERIFY / SEARCH / TEST AS NEEDED
↓
DRAFT REFINEMENT
```

## Copy/Paste Prompt

```text
TASK ID: M14.27
TASK: Professional Session 10 AI Integration

Read first:

- approved Professional Course Session 10
- /docs/09_AI_ASSISTANT_SPEC.md
- /docs/26_CODEX_M12_PROMPTS.md

SCENARIO

1. Project has:
   - Invention Concept V1
   - Mind Map
   - Minimum Essential Structure
   - Problem/Solution structure
   - Patent Landscape Snapshot / retained Patents
   - Search Logs
   - Evidence
   - Gap Map / Gap Objects
   - Decisions

2. Start Session 10 Activity.

3. Context Builder loads only authorized current/relevant context.

4. AI Critical/Comparative role reconstructs:
   - Main Problem
   - Current Solution
   - Components
   - Functions
   - Relationships
   - Architecture
   - Technical Results
   - Constraints
   - Open Questions

5. Human reviews reconstruction.

6. Select one Gap.

7. AI analyzes Gap using:
   - Current Concept
   - selected Evidence
   - Patent context
   - relevant Decision

8. AI produces:
   - Analysis
   - Candidate Directions
   - Verification Needed.

9. Human accepts one output as Candidate.

10. Candidate Project Object created with provenance.

11. Candidate remains unverified/draft.

12. Team may return to:
    - SCAMPER,
    - Brainstorming,
    - Problem Storming,
    - Mind Map,
    - Patent Search,
    according to identified need.

13. No auto-approval.

VERIFY

- source/evidence/AI layers visibly separate.
- no novelty/patentability declaration.
- Context References saved.
- Team B excluded.
- same Project Objects reused.
- candidate conversion requires human action.

DEFINITION OF DONE

Session 10 uses AI as a controlled development assistant over the structured Project memory.
```

---

# 92. M14.28 — Patent AI Traceability Test

## Objective

Ensure patent AI analysis remains source-referenced and non-authoritative.

## Copy/Paste Prompt

```text
TASK ID: M14.28
TASK: Patent AI Traceability

SCENARIO

Use saved Patent Record + Evidence.

AI task performs structured comparison.

VERIFY OUTPUT DISTINGUISHES

- Observation
- Source Reference
- Interpretation
- Confidence / Uncertainty

VERIFY

- Patent Record unchanged.
- Evidence unchanged.
- AI Output labeled COMPARISON/ANALYSIS.
- no novelty conclusion.
- no patentability conclusion.
- no FTO/infringement conclusion.
- Context Reference points to Patent/Evidence source.

DEFINITION OF DONE

AI can support patent research without becoming source evidence or legal conclusion.
```

---

# 93. M14.29 — Human-Governance End-to-End AI Scenario

## Objective

Implement AT-E2E-AI-001.

## Copy/Paste Prompt

```text
TASK ID: M14.29
TASK: E2E AI Governance

SCENARIO

1. Team A runs AI on Gap G1.
2. AI suggests Solution S-AI.
3. Output stored as AI_SUGGESTION / UNVERIFIED.
4. Team reviews it.
5. Team saves it as Candidate.
6. Evidence is added.
7. Team records Decision.
8. New Draft Artifact Version created.
9. Master reviews.
10. Only after Master approval does new Version become CURRENT.

VERIFY AT EVERY STEP

- AI never becomes Evidence automatically.
- AI never decides.
- AI never approves.
- source provenance retained.
- human actions recorded.
- approved Version history preserved.
- Team B cannot access.

PRIORITY

RELEASE GATE.

DEFINITION OF DONE

AT-E2E-AI-001 passes.
```

---

# 94. M14.30 — Provider Failure / Retry Integrity

## Objective

Protect against duplicate AI Output/candidate creation under retries.

## Copy/Paste Prompt

```text
TASK ID: M14.30
TASK: AI Retry & Idempotency

OBJECTIVE

Test:

1. provider timeout then retry.
2. client retries same command.
3. provider succeeds but response delivery to browser fails.
4. user retries Candidate conversion.

EXPECTED

- no duplicate committed Candidate on idempotent confirmation.
- no duplicate usage corruption.
- AI Output duplicates prevented or clearly distinct according to idempotency design.
- provider request IDs metadata-only.
- no Project mutation during failed attempt.

DEFINITION OF DONE

AI retries cannot corrupt Project history.
```

---

# 95. M14.31 — M14 Security & Integrity Hardening

## Objective

Perform final AI security review before pilot notifications/progress work.

## Copy/Paste Prompt

```text
TASK ID: M14.31
TASK: M14 Security & Integrity Hardening

Read first:

- /docs/03_ROLES_PERMISSIONS.md
- /docs/04_WORKSPACE_TEAM_COLLABORATION.md
- /docs/05_DEVELOPMENT_PROJECT_MODEL.md
- /docs/08_DATA_MODEL_SCHEMA.md
- /docs/09_AI_ASSISTANT_SPEC.md
- /docs/10_TECHNICAL_ARCHITECTURE.md
- /docs/11_API_CONTRACTS.md
- /docs/12_ACCEPTANCE_TESTS.md
- /docs/13_CODEX_IMPLEMENTATION_PLAN.md
- /docs/21_CODEX_M7_PROMPTS.md
- /docs/22_CODEX_M8_PROMPTS.md
- /docs/23_CODEX_M9_PROMPTS.md
- /docs/24_CODEX_M10_PROMPTS.md
- /docs/25_CODEX_M11_PROMPTS.md
- /docs/26_CODEX_M12_PROMPTS.md
- /docs/27_CODEX_M13_PROMPTS.md
- /docs/28_CODEX_M14_PROMPTS.md

VERIFY

1. provider behind abstraction.
2. API keys server-side.
3. Context Builder permission-aware.
4. context minimized.
5. Team B data never enters Team A provider payload.
6. Personal A1 data never enters A2 payload.
7. removed member receives no former Team context.
8. revoked Share excluded.
9. hidden Brainstorm entries excluded.
10. Team Chat excluded unless explicitly selected.
11. Context References saved.
12. AI Output classified.
13. AI Output defaults unverified.
14. AI Output is not Evidence.
15. AI cannot vote.
16. AI cannot approve.
17. AI cannot change permissions.
18. AI cannot silently change current baseline.
19. Candidate conversion requires human confirmation.
20. approved Artifact remains immutable.
21. Patent AI avoids legal conclusions.
22. usage logging avoids broad confidential content.
23. provider failure safe.
24. retries/idempotency safe.
25. no M15+ scope creep.

RUN

pnpm lint
pnpm typecheck
pnpm test:unit
pnpm test:integration
pnpm test:e2e
pnpm build
plus all RLS, provider-payload, leakage, failure, and idempotency tests.

DEFINITION OF DONE

- AT-AI-001 PASS
- AT-AI-002 PASS
- AT-AI-003 PASS
- AT-AI-004 PASS
- AT-AI-005 PASS
- AT-AI-006 PASS
- AT-AI-007 PASS
- AT-AI-008 PASS
- AT-AI-009 PASS
- AT-AI-LEAK-001 PASS
- AT-AI-LEAK-002 PASS
- AT-AI-LEAK-003 PASS
- AT-E2E-AI-001 PASS
- AT-EV-002 still PASS
- Session 10 integration PASS
- zero known AI context leak
- zero AI auto-approval path
- no M15+ scope creep

FINAL REPORT

Return:
1. AI security review
2. Context Builder review
3. provider boundary review
4. governance review
5. issues found
6. issues fixed
7. remaining issues
8. BLOCKER status
9. test results
10. recommendation: READY FOR M15 or NOT READY FOR M15
```

---

# 96. AI Output vs Project Object

Do not conflate:

```text
AI Output
```

with:

```text
Development Object
```

AI Output is generated assistance.

Development Object is persistent Project content.

Conversion requires human action.

---

# 97. AI Output vs Evidence

Do not conflate:

```text
AI Analysis
```

with:

```text
Evidence
```

Evidence is source-backed.

AI Analysis is interpretation.

---

# 98. AI Output vs Decision

Do not conflate:

```text
AI Recommendation
```

with:

```text
Team Decision
```

AI may inform Decision.

Humans finalize Decision.

---

# 99. AI Output vs Approved Artifact

Do not conflate:

```text
AI Draft
```

with:

```text
Approved Artifact Version
```

AI-assisted changes use normal Draft → Review → Approval flow.

---

# 100. Context Reference vs Permission

A saved Context Reference records historical provenance.

It does not grant current permission.

Example:

```text
AI Output used Shared Artifact X yesterday
Share revoked today
```

The AI Output may retain:

```text
Context Reference → X
```

but recipient cannot open X today unless separately authorized.

---

# 101. Provider Memory

Do not rely on opaque provider-side memory for Project continuity.

FICI owns durable Project memory.

Every task receives selected FICI context.

---

# 102. Raw Prompt Retention

`ai_outputs.prompt_text` exists in Data Model, but privacy requirements warn against unnecessary confidential retention.

Codex must inspect current product retention policy before storing full assembled system/context prompt.

A safe distinction may be:

- user task/prompt text,
- Prompt Template reference,
- Context References,
- provider metadata.

If full raw prompt retention policy is unresolved:

```text
STOP → FLAG → ASK
```

Do not silently retain all confidential serialized context.

---

# 103. Conversation Persistence

Personal AI conversation retention is an open question.

Team AI conversation visibility to Master is an open question.

Therefore M14 MVP should prefer task-based AI Outputs unless conversation behavior has been explicitly approved.

Do not invent retention policy.

---

# 104. User Context Selection

The user may select context references.

Selected IDs are requests, not authorization.

Every selected entity must be reauthorized server-side.

---

# 105. Manual Context Removal

Whether users can remove context items before generation is an open question.

Do not build complex context editor unless approved.

The Context Builder may expose a safe summary of selected context if current design needs it.

---

# 106. Public Web Research

Whether AI may research the public web in MVP is explicitly open.

M14 must not assume unrestricted web research.

Default source-grounded MVP may operate on:

- Project data,
- saved Evidence,
- Patent Records,
- user-supplied sources.

If web research is later enabled:

- external source result remains separate,
- user intentionally saves relevant source as Evidence,
- AI interpretation remains AI Output.

---

# 107. Free vs Paid AI Mode

The AI spec lists whether FICI should support Free AI and Paid/Advanced AI as an open question.

Do not implement subscription product logic in M14 unless approved.

Model-profile architecture should remain compatible with future tiers.

---

# 108. AI Usage Visibility

Master visibility into per-student/team AI usage is an open question.

M14 stores usage events.

M15 may expose selected progress/notification views.

Do not create broad monitoring dashboard without policy.

---

# 109. AI Request Limits

Per-user/team/cohort/organization limits are an open question.

Implement technical rate-limit hooks and usage data.

Do not invent commercial quotas.

---

# 110. AI Candidate Confirmation Policy

Whether Team Candidate conversion requires one confirmation or two-stage Team acceptance is unresolved.

M14 must not silently grant a single Student authority to create Team-accepted canonical state.

Safe baseline:

```text
human-confirmed Draft/Candidate
```

not approved/current.

Flag Team acceptance semantics.

---

# 111. Verification Requirement

Some AI Outputs may require Evidence before becoming Candidate.

Exact task-by-task policy may remain open.

Task Registry should support:

```text
verification requirement
```

Do not hard-code one global rule if source docs do not.

---

# 112. Prompt Injection / Source Content

User-generated Evidence/Files may contain malicious instructions.

M14 should treat source content as data, not platform instruction.

Context assembly should clearly delimit:

- system rules,
- role,
- task,
- source material.

Do not allow source text to overwrite platform rules.

---

# 113. AI Tool Calls

MVP should be conservative with AI tool calls.

If provider can request platform actions:

- tool request is a proposal,
- server authorizes operation,
- high-impact writes require human confirmation,
- normal business commands execute changes.

Do not give model unrestricted database/API tools.

---

# 114. Audit / Change Log

Important events may include:

```text
AI_TASK_RUN
AI_OUTPUT_SAVED
AI_DISPOSITION_CHANGED
AI_CANDIDATE_CREATED
```

Exact audit names follow repository convention.

Do not put full confidential prompt/context in broad audit metadata.

---

# 115. M14 Expected Repository Additions

Conceptually:

```text
features/
└── ai/
    ├── tasks/
    ├── roles/
    ├── context/
    ├── prompts/
    ├── outputs/
    ├── disposition/
    ├── candidate-conversion/
    ├── usage/
    └── access/

lib/
├── ai/
│   ├── provider.ts
│   ├── openai-responses-provider.ts
│   ├── task-registry.ts
│   ├── model-profiles.ts
│   ├── prompt-builder.ts
│   ├── context-builder.ts
│   └── output-validation.ts
├── permissions/
│   └── ai.ts
└── security/
    └── ai-context.ts

supabase/
├── migrations/
│   ├── ...ai_outputs...
│   ├── ...ai_context_references...
│   ├── ...ai_prompt_templates...
│   ├── ...ai_usage_events...
│   └── ...ai_rls...
└── tests/
    └── rls/
        └── ai...

tests/
├── unit/
│   ├── ai-context/
│   ├── ai-tasks/
│   ├── prompt-builder/
│   └── output-validation/
├── integration/
│   ├── ai/
│   ├── candidate-conversion/
│   └── session10/
└── e2e/
    ├── ai-governance.spec.ts
    └── ai-leakage.spec.ts
```

Exact paths may vary.

---

# 116. M14 Completion Gate

M14 is complete only when:

```text
[ ] AI provider abstraction exists
[ ] OpenAI Responses API adapter exists
[ ] provider secrets server-only

[ ] ai_outputs exists
[ ] ai_context_references exists
[ ] ai_prompt_templates exists
[ ] ai_usage_events exists

[ ] Task Registry exists
[ ] model profile resolver exists
[ ] activity AI role resolver exists
[ ] Context Builder exists
[ ] context minimization enforced
[ ] Share-aware context works
[ ] removed-member exclusion works
[ ] hidden Brainstorm exclusion works
[ ] Chat excluded by default

[ ] runAiTask() implemented
[ ] structured output validation implemented
[ ] Prompt Template version tracked
[ ] Context References saved
[ ] AI usage logged
[ ] AI Output classified
[ ] default verification = UNVERIFIED

[ ] Human disposition implemented
[ ] Candidate conversion implemented
[ ] Candidate provenance retained

[ ] AI cannot auto-create Evidence
[ ] AI cannot vote
[ ] AI cannot approve
[ ] AI cannot change permissions
[ ] AI cannot silently change current baseline
[ ] AI-assisted Artifact revision uses new Draft Version

[ ] provider failure safe
[ ] retry/idempotency safe

[ ] AT-AI-001 PASS
[ ] AT-AI-002 PASS
[ ] AT-AI-003 PASS
[ ] AT-AI-004 PASS
[ ] AT-AI-005 PASS
[ ] AT-AI-006 PASS
[ ] AT-AI-007 PASS
[ ] AT-AI-008 PASS
[ ] AT-AI-009 PASS

[ ] AT-AI-LEAK-001 PASS
[ ] AT-AI-LEAK-002 PASS
[ ] AT-AI-LEAK-003 PASS

[ ] AT-E2E-AI-001 PASS
[ ] AT-EV-002 remains PASS
[ ] Professional Session 10 integration PASS

[ ] lint passes
[ ] typecheck passes
[ ] unit tests pass
[ ] integration tests pass
[ ] E2E tests pass
[ ] RLS tests pass
[ ] provider-payload leakage tests pass
[ ] failure/retry tests pass
[ ] build passes

[ ] no M15+ feature implemented prematurely
[ ] Codex reports READY FOR M15
```

Any unauthorized content entering provider payload is:

```text
BLOCKER
```

Any AI auto-approval path is:

```text
BLOCKER
```

Any AI Output automatically becoming Evidence is:

```text
BLOCKER
```

Any AI participation in human Team voting is:

```text
PRODUCT GOVERNANCE DEFECT
```

---

# 117. Recommended Commit Sequence

Example:

```text
feat(ai): add AI Output schema
feat(ai): add Context Reference schema
feat(ai): add Prompt Template schema
feat(ai): add Usage Event schema
feat(ai): add provider abstraction
feat(ai): add OpenAI Responses adapter
feat(ai): add model profiles
feat(ai): add task registry
feat(ai): add permission-aware Context Builder
feat(ai): add Activity AI availability
feat(ai): add layered prompt assembly
feat(ai): add runAiTask service
feat(ai): add structured output validation
feat(ai): add classification/verification handling
feat(ai): add human disposition
feat(ai): add Candidate conversion
feat(artifacts): add AI-assisted Draft revision flow
feat(evidence): enforce AI/Evidence boundary
feat(sharing): integrate shared AI context
feat(security): add AI RLS
test(ai): add AT-AI suite
test(ai): add AI leakage suite
test(ai): add provider payload inspection
test(session10): add Professional Session 10 AI flow
test(e2e): add AI governance scenario
test(ai): add provider failure/idempotency coverage
chore(security): complete M14 hardening
```

---

# 118. M14 Non-Goals

Do not accept these as "helpful additions" during M14:

- autonomous multi-step agents,
- background research agents,
- continuous patent monitoring,
- automated investor research agents,
- AI Team voting,
- autonomous decisions,
- autonomous approvals,
- autonomous Evidence verification,
- automatic baseline changes,
- unrestricted browser/web research,
- multi-model swarm orchestration,
- large AI analytics dashboard,
- AI billing/subscription system,
- organization-wide hidden memory,
- direct client-side provider calls.

---

# 119. Potential M14 Ambiguities Codex Must Flag

Do not silently decide if approved docs do not resolve:

- Personal AI conversation retention,
- Team AI conversation visibility to Master,
- whether Master can disable AI per Activity,
- whether independent-work-first is mandatory for SCAMPER/Brainstorming,
- one-confirmation vs Team-acceptance for Candidate conversion,
- which outputs require Evidence before Candidate,
- whether users see full Context References,
- whether users can remove context before generation,
- claim/paragraph reference requirement for Patent AI output,
- whether public-web research is enabled in MVP,
- AI usage visibility to Master,
- usage limit scope,
- Free vs Paid AI mode,
- which AI tool actions are enabled in MVP,
- raw prompt retention,
- raw provider response retention,
- whether failed provider responses create AI Output rows,
- whether AI Output can be deleted vs archived,
- exact verification authority for AI Output,
- exact prompt-template editing authority,
- whether Team Lead can initiate all Team AI tasks,
- whether shared VIEW content may always be included in AI context,
- whether AI may use COMMENT-shared content automatically or only on explicit selection.

If unresolved:

```text
STOP → FLAG → ASK
```

---

# 120. Recommended Safe Defaults for Purely Technical Decisions

Only where they do not alter approved product policy:

- UUID AI Output IDs,
- server-derived requester,
- task-based AI instead of persistent chat,
- provider abstraction,
- OpenAI Responses adapter,
- task-specific model profiles,
- Context Builder fail-closed,
- minimal context,
- Chat excluded by default,
- UNVERIFIED default,
- original AI response immutable,
- Context References persisted,
- candidate conversion human-confirmed,
- no approval/Decision/vote tool access,
- provider failures isolated,
- usage events content-minimized,
- cross-Team context fails closed,
- revoked Share excluded immediately from future requests.

---

# 121. Review Checklist for Ahmad/FICI

Before implementation, confirm M14 reflects the intended AI model:

```text
1. AI is built into Activities, not just a generic chatbot.

2. Activity determines the AI role.

3. AI only sees context the current user is authorized to access.

4. AI receives only relevant context, not the entire Project.

5. Personal AI stays private.

6. Team AI stays Team-scoped.

7. Removed members cannot use AI to retrieve old Team data.

8. Revoked shares disappear from future AI context.

9. Unrevealed Brainstorm ideas remain hidden from peer/team AI.

10. Chat is not included automatically.

11. Every saved AI Output has an AI label/type.

12. AI Output starts unverified.

13. AI Output is not Evidence.

14. AI does not vote.

15. AI does not approve.

16. AI does not change permissions.

17. AI does not silently change the approved baseline.

18. Human confirmation is required before AI suggestion becomes Candidate Project data.

19. AI-assisted Artifact changes create a new Draft Version.

20. Context References are saved.

21. Provider usage is logged.

22. OpenAI is behind a replaceable provider abstraction.

23. Session 10 uses the Project/Evidence/Patent history built in Sessions 1–9.

24. AI Patent analysis never declares novelty/patentability automatically.
```

---

# 122. Next File After M14

After M14 has actually been:

```text
IMPLEMENTED
→ TESTED
→ SECURITY-REVIEWED
→ COMMITTED
```

create:

# `29_CODEX_M15_PROMPTS.md`

M15 will cover:

```text
Progress
Activity Status Overview
Submission / Review Status
Notifications
Realtime Notifications
Selected Email Notifications
Master Cohort Overview
Student Current-Work Overview
Pilot Workflow
```

M15 will make the already-built platform operational for a real pilot cohort.

---

# 123. Final Execution Rule

For M14:

```text
AI SCHEMA
→ CONTEXT REFERENCES
→ PROMPT TEMPLATES
→ USAGE EVENTS
→ PROVIDER ABSTRACTION
→ MODEL PROFILES
→ TASK REGISTRY
→ CONTEXT BUILDER
→ ACTIVITY AI AVAILABILITY
→ PROMPT ASSEMBLY
→ RUN AI TASK
→ OUTPUT VALIDATION
→ CLASSIFICATION
→ HUMAN DISPOSITION
→ CANDIDATE CONVERSION
→ ARTIFACT REVISION
→ EVIDENCE BOUNDARY
→ SHARING BOUNDARY
→ BRAINSTORM PRIVACY
→ MEMBER REMOVAL
→ PROVIDER FAILURE
→ RLS
→ AI ACCEPTANCE TESTS
→ LEAKAGE TESTS
→ SESSION 10 E2E
→ AI GOVERNANCE E2E
→ SECURITY HARDENING
```

Do not skip directly to notifications/pilot dashboards.

---

# End of Document

**Current Status:** Draft v0.1 — Ready for Ahmad/FICI review.  
**Execution Step After M13 Completion:** Start with **M14.1 — AI Output Schema**.
