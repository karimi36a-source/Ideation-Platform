# FICI Invention Education & Development Platform
## AI Assistant Specification

**Document:** `09_AI_ASSISTANT_SPEC.md`  
**Status:** Draft v0.1 — For Review  
**Depends on:** `01_PRODUCT_REQUIREMENTS.md`, `02_PLATFORM_ARCHITECTURE.md`, `03_ROLES_PERMISSIONS.md`, `04_WORKSPACE_TEAM_COLLABORATION.md`, `05_DEVELOPMENT_PROJECT_MODEL.md`, `06_COURSE_ACTIVITY_WORKFLOWS.md`, `07_MVP_SCOPE.md`, `08_DATA_MODEL_SCHEMA.md`  
**Purpose:** Define how AI operates inside the FICI platform, what context it may use, which roles it plays, how outputs are classified, how human review works, how privacy boundaries are enforced, and how the implementation remains provider-flexible.

---

# 1. AI Product Principle

AI is a native platform capability.

It must not be implemented as only:

- a generic chatbot,
- an isolated assistant in the corner,
- a content generator disconnected from the project,
- an authority that silently changes project state.

The AI must be connected to:

- current course,
- current session,
- current activity,
- current workspace,
- current Development Project,
- current approved baseline,
- relevant evidence,
- team decisions,
- instructor feedback,
- current task.

The governing philosophy is:

# AI GENERATES → HUMAN EVALUATES → EVIDENCE VERIFIES → TEAM DECIDES

AI may assist.

AI does not own the invention.

AI does not make the final decision.

---

# 2. AI Objectives

The AI system should help users:

- understand methods,
- generate structured ideas,
- analyze problems,
- identify gaps,
- organize information,
- compare options,
- interpret evidence,
- support patent analysis,
- challenge assumptions,
- support product development,
- prepare validation,
- assist market analysis,
- assist planning,
- assist finance analysis,
- review pitch logic,
- identify missing evidence.

The AI must improve the development process without replacing:

- source evidence,
- expert judgment,
- instructor review,
- team decisions,
- formal approval.

---

# 3. AI Role Model

The AI should act through explicit activity-specific roles.

The same underlying AI service may adopt different roles.

Initial role catalog:

## 3.1 Invention Development Facilitator

Used for:

- general ideation,
- early invention development,
- problem exploration.

## 3.2 Structured Creativity Assistant

Used for:

- SCAMPER,
- structured idea expansion,
- variation generation.

## 3.3 Brainstorming Facilitator

Used for:

- divergence,
- idea expansion,
- problem storming,
- solution generation.

## 3.4 System Structure Analyst

Used for:

- Affinity Diagram,
- Mind Mapping,
- system/subsystem/component analysis,
- missing relationships.

## 3.5 Patent Research Assistant

Used for:

- search term generation,
- synonym generation,
- patent metadata organization,
- source extraction,
- relevant-result comparison.

## 3.6 Comparative / Critical Analyst

Used for:

- similarity/difference analysis,
- gap analysis,
- option comparison,
- challenge of assumptions.

## 3.7 Problem-Solving Partner

Used for:

- resolving gaps,
- generating solution families,
- applying root cause,
- structured refinement.

## 3.8 Requirements Analyst

Used for:

- requirements,
- assumptions,
- constraints,
- risk,
- validation questions.

## 3.9 Validation Planning Assistant

Used for:

- PoC,
- prototype,
- MVP,
- experiments,
- evidence criteria,
- validation sequencing.

## 3.10 Market Research Assistant

Used for:

- customer hypotheses,
- research questions,
- competitor mapping,
- market assumptions,
- evidence structuring.

## 3.11 Execution Planning Assistant

Used for:

- backlog,
- task breakdown,
- dependencies,
- prioritization,
- milestones.

## 3.12 Finance Analysis Assistant

Used for:

- revenue assumptions,
- cost assumptions,
- cash/runway logic,
- break-even analysis,
- scenario structure.

## 3.13 Pitch Review Assistant

Used for:

- story structure,
- evidence consistency,
- claim checking against project records,
- missing-proof identification.

## 3.14 Funding Strategy Assistant

Used for:

- funding requirement logic,
- milestone-to-capital mapping,
- investor criteria,
- fundraising preparation.

## 3.15 Critical Reviewer

Used for:

- final review,
- contradiction detection,
- unsupported claim detection,
- missing evidence,
- unclear reasoning.

---

# 4. AI Role Selection

Each `activity_definition` may define an `ai_role_code`.

When a user activates AI inside an activity, the platform should determine:

```text
PROGRAM
+
SESSION
+
ACTIVITY
+
WORKSPACE
+
PROJECT STATE
+
AI ROLE
=
AI TASK CONTEXT
```

The user should not need to manually explain the entire project every time.

---

# 5. AI Context Hierarchy

AI context should be assembled in layers.

Recommended hierarchy:

## Layer 1 — Platform / Method Context

Contains:

- FICI methodology rules,
- AI governance rules,
- activity instructions,
- role behavior.

## Layer 2 — Program Context

Contains:

- course,
- session,
- learning goal,
- output expected,
- current curriculum version.

## Layer 3 — Project Baseline

Contains:

- project name,
- current approved concept,
- current approved artifacts,
- important decisions,
- current project stage.

## Layer 4 — Workspace Context

Contains only information the user is authorized to access in:

- Personal Workspace,
- Team Workspace,
- Instructor Workspace,
- Shared Workspace.

## Layer 5 — Activity Context

Contains:

- current task,
- activity inputs,
- current working objects,
- output format,
- current activity state.

## Layer 6 — Evidence Context

Contains relevant:

- patent records,
- evidence,
- tests,
- calculations,
- verified findings.

## Layer 7 — Feedback & Decision Context

Contains:

- instructor feedback,
- team decisions,
- revision requests,
- current approval state.

The system should include only the context necessary for the current AI task.

---

# 6. Context Minimization

AI context must not include the entire Development Project by default.

The Context Builder should select only relevant information.

Reasons:

- privacy,
- accuracy,
- lower cost,
- lower latency,
- reduced distraction,
- better model focus,
- easier traceability.

Example:

A SCAMPER activity may need:

- selected problem,
- selected component,
- current concept,
- SCAMPER method instructions.

It does not need:

- finance assumptions,
- unrelated team chat,
- future pitch documents.

---

# 7. Permission-Aware Context

This is mandatory.

Before including any object in AI context, the platform must verify the requesting user's access.

AI must not receive:

- another student's private draft,
- another team's private chat,
- another team's private artifact,
- instructor-only notes,
- restricted project information,
- content from a removed team member's former team unless separately authorized.

The AI service must not become a path around platform permissions.

---

# 8. Context Provenance

When a saved AI output is created, the platform should retain references to important context sources.

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

This supports:

- traceability,
- review,
- reproducibility,
- debugging,
- explaining why AI produced a response.

The platform does not need to permanently store every hidden technical prompt token, but it should store the meaningful context references.

---

# 9. AI Output Classification

Every saved AI result should have an explicit type.

Possible types:

- AI ANALYSIS
- AI SUGGESTION
- AI HYPOTHESIS
- AI DRAFT
- AI COMPARISON
- AI CLASSIFICATION
- AI SUMMARY
- AI CANDIDATE SOLUTION

AI output must not be mislabeled as:

- Source Evidence
- Team Decision
- Instructor Feedback
- Verified Fact
- Approved Content

unless a later human workflow explicitly converts or links it.

---

# 10. Verification Status

AI output may have:

- UNVERIFIED
- UNDER REVIEW
- PARTIALLY VERIFIED
- VERIFIED AGAINST SOURCES
- CONTRADICTED
- REJECTED

"Verified" must mean human/evidence verification occurred.

It must not mean "the model sounded confident."

---

# 11. Human Disposition Workflow

After AI generates an output, the user should be able to choose:

- Keep for Review
- Accept as Candidate
- Edit / Modify
- Reject
- Investigate Further
- Link to Evidence
- Convert to Project Object
- Share With Team
- Submit to Master

The action taken must be recorded.

---

# 12. AI-to-Project Promotion

AI output must not directly alter approved project state.

Required pattern:

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

If AI suggests a new Component:

1. AI creates suggestion.
2. User accepts as candidate.
3. Candidate Component object is created.
4. Team evaluates.
5. Evidence/test may be linked.
6. Team decides.
7. Master may approve if required.
8. New artifact version is created.

---

# 13. AI in Personal Workspace

Personal AI is private by default.

It may use:

- user's private objects,
- user's personal notes,
- current project information the user can access,
- shared team information the user may view,
- current course materials.

Personal AI output remains private until intentionally shared.

---

# 14. AI in Team Workspace

Team AI may use:

- team-owned artifacts,
- team decisions,
- team evidence,
- approved/shared project context,
- activity inputs.

Team AI output should be visible to authorized team members.

The requesting user should remain identified.

Example:

```text
Requested by: User A
Workspace: Team 3
Role: Critical Reviewer
```

---

# 15. AI in Master / Instructor Workspace

Master AI may support:

- review preparation,
- identifying missing sections,
- comparing team output to activity requirements,
- summarizing submissions,
- finding unresolved gaps,
- preparing feedback.

Master AI must not silently grade, approve, or reject a student artifact.

The instructor remains responsible for formal review actions.

---

# 16. AI and Team Chat

Team chat should not automatically be included in AI context.

Reasons:

- chat contains noise,
- private discussion,
- incomplete thinking,
- unrelated content.

If chat is used, it should be:

- explicitly selected,
- limited to relevant messages,
- authorized,
- traceable.

Formal decisions should still come from Decision Records, not inferred automatically from chat.

---

# 17. AI and Source Evidence

The system must clearly distinguish:

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

An AI-generated summary of a patent is not itself patent evidence.

The patent document remains the evidence source.

---

# 18. AI and Patent Analysis

AI may assist with:

- search keywords,
- synonym expansion,
- technical terminology,
- patent metadata extraction,
- abstract summarization,
- claim element extraction,
- structured comparison,
- similarity/difference analysis,
- architecture reconstruction assistance,
- gap candidate identification.

AI must not automatically conclude:

- novel,
- patentable,
- infringes,
- freedom to operate,
- legally protected.

These require professional legal/IP analysis where applicable.

---

# 19. Patent Evidence Traceability

When AI analyzes a patent, it should reference source location where practical.

Examples:

- Patent Number
- Claim Number
- Figure
- Paragraph
- Section
- Abstract
- Description

Preferred AI output structure:

```text
Observation
Source Reference
Interpretation
Confidence / Uncertainty
```

---

# 20. AI in SCAMPER

AI may:

- propose alternative substitutions,
- suggest combinations,
- identify analogies,
- explore modifications,
- suggest alternative uses,
- challenge unnecessary elements,
- suggest reversals/rearrangements.

AI should encourage variation rather than collapse quickly to one answer.

AI should not replace the participant's required independent examples where the educational activity requires student work.

---

# 21. AI in Brainstorming

During divergence, AI should:

- generate options,
- avoid ranking unless requested,
- extend existing ideas,
- create different solution families,
- explore different perspectives.

During the divergence phase, AI should not:

- eliminate ideas,
- choose winners,
- force premature feasibility analysis.

---

# 22. AI in Problem Storming

AI may help identify problems from perspectives such as:

- User
- Function
- Technical
- Cost
- Safety
- Environment
- Accessibility
- Maintenance
- Manufacturing
- Market

Outputs remain candidate Problems.

---

# 23. AI in Affinity

AI may:

- suggest clusters,
- propose group labels,
- identify duplicated concepts,
- highlight ungrouped items,
- identify possible relationships.

Human/team users must be able to:

- accept,
- modify,
- reject AI clustering.

---

# 24. AI in Mind Mapping

AI may:

- suggest missing nodes,
- suggest systems/subsystems,
- identify weak connections,
- identify functions without components,
- identify components without clear functions,
- identify unresolved gaps.

AI must not silently restructure the team map.

Changes should be proposed first.

---

# 25. AI in Decision Support

AI may:

- summarize options,
- identify trade-offs,
- identify missing evidence,
- challenge assumptions,
- surface conflicting criteria.

AI must not cast a team vote.

AI must not appear as a human participant.

AI recommendations must remain advisory.

---

# 26. AI in Requirements & Risk

AI may assist with:

- requirement categories,
- conflicting requirements,
- missing constraints,
- risk identification,
- mitigation options,
- validation questions.

The system should encourage traceability:

```text
Requirement
↓
Risk
↓
Validation Question
↓
Test
↓
Evidence
↓
Decision
```

---

# 27. AI in Validation Planning

AI may propose:

- minimum experiment,
- metric,
- success criterion,
- failure criterion,
- test conditions,
- alternative validation method.

Human users must confirm:

- feasibility,
- safety,
- appropriateness,
- resources,
- final criteria.

---

# 28. AI in Market Work

AI may help:

- structure customer hypotheses,
- prepare research questions,
- classify interview findings,
- compare competitors,
- summarize market evidence,
- challenge price assumptions.

AI-generated market claims must not be treated as verified market evidence unless supported by actual sources.

---

# 29. AI in Finance

AI may assist with:

- formulas,
- scenario analysis,
- assumption structure,
- break-even logic,
- unit economics,
- runway logic.

Financial model inputs must preserve:

- source,
- assumption status,
- confidence,
- evidence.

AI should never silently invent numbers to fill missing financial assumptions.

If a number is missing, AI should identify the gap.

---

# 30. AI in Pitch

AI may:

- review story sequence,
- identify unsupported claims,
- check consistency across project data,
- suggest clearer phrasing,
- identify missing investor questions,
- compare claims to evidence.

The platform should prefer:

```text
Pitch Claim
↓
Linked Evidence
```

AI should flag unsupported claims rather than strengthen them rhetorically without proof.

---

# 31. AI in Funding Strategy

AI may support:

- milestone-to-funding mapping,
- funding source comparison,
- due diligence preparation,
- investor-fit criteria,
- outreach preparation.

Final investor selection and fundraising decisions remain human.

---

# 32. Prompt Architecture

The platform should use layered prompt construction.

Conceptual structure:

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

Prompt logic should be owned by FICI.

It should not be embedded only inside vendor-specific configuration.

---

# 33. Prompt Templates

AI prompts should be versioned.

## `ai_prompt_templates`

Conceptually:

- template ID
- role
- activity type
- version
- system instructions
- task structure
- output schema
- status

This allows FICI to improve AI behavior without rewriting application code.

---

# 34. Prompt Version Tracking

Saved AI outputs should record which prompt-template version was used where practical.

This helps:

- debugging,
- comparing quality,
- curriculum updates,
- reproducibility.

---

# 35. Structured AI Output

When the product needs structured data, AI should return validated structured output rather than free text only.

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

The implementation should validate AI output before saving structured fields.

---

# 36. Free-Text AI Output

Free text remains useful for:

- explanation,
- coaching,
- brainstorming,
- critical discussion.

But when AI output becomes project data, it should be converted into structured objects.

---

# 37. AI Conversation Model

The platform may support conversations, but conversations are not the main project model.

A conversation should belong to:

- User
- Workspace
- Project
- Activity
- AI Role

Important outputs should be explicitly saved as project objects.

---

# 38. Conversation Persistence

Recommended default:

## Personal AI

Conversation may be temporary until the user intentionally saves important outputs.

## Team AI

Relevant conversation history may persist for team collaboration.

## Master AI

Review-related saved outputs may persist.

Exact retention policy will be defined later.

---

# 39. AI Memory Principle

The platform should not rely on opaque vendor-side memory as the source of project continuity.

FICI should own the durable project memory through its own data model.

AI receives selected project context on each task.

This ensures:

- portability,
- provider replacement,
- permission control,
- predictable context,
- auditable project state.

---

# 40. Retrieval / Context Search

For larger projects, the AI Context Builder may retrieve relevant:

- objects,
- artifacts,
- evidence,
- feedback,
- decisions,
- patent records.

Retrieval must be:

- permission-aware,
- project-scoped,
- activity-aware,
- relevance-limited.

Technical retrieval implementation is deferred to Technical Architecture.

---

# 41. Provider Abstraction

The application should not tightly couple core business logic to one AI vendor.

The AI layer should conceptually expose internal platform functions such as:

- `generateStructuredIdeas`
- `analyzeGap`
- `comparePatent`
- `reviewArtifact`
- `suggestRequirements`
- `prepareValidationPlan`

The implementation may route those tasks to a selected provider/model.

Provider-specific code should remain behind an abstraction layer.

---

# 42. Multi-Provider Capability

The architecture should allow future use of:

- one primary model provider,
- alternative provider,
- specialized model,
- local/private model where appropriate.

The MVP may use one provider initially.

The product architecture should not assume that provider is permanent.

---

# 43. Model Selection by Task

Different tasks may require different model capabilities.

Examples:

- simple classification → lightweight model
- brainstorming → general model
- patent comparative analysis → stronger reasoning model
- document extraction → model optimized for structured extraction

The AI orchestration layer should be able to select a model profile by task.

Exact provider/model names are intentionally deferred.

---

# 44. Cost Control

The AI system must be designed with cost awareness.

Controls may include:

- context minimization,
- smaller model for simple tasks,
- limits per activity,
- max output size,
- caching reusable summaries,
- avoiding repeated full-project context,
- per-user / per-cohort usage tracking,
- Master/Admin usage controls.

---

# 45. AI Usage Records

The platform should track:

- user,
- project,
- workspace,
- activity,
- task type,
- model profile,
- approximate usage/cost where available,
- timestamp,
- saved output status.

This supports product analytics and cost management.

---

# 46. AI Rate Limits

MVP should support configurable safeguards such as:

- per-user request limit,
- per-minute limit,
- per-day allowance,
- course allowance,
- admin override.

These limits should be configurable rather than hard-coded.

---

# 47. Failure Handling

If AI is unavailable:

- user work must remain accessible,
- users must still be able to complete manual workflows,
- platform must not corrupt project state,
- failed AI request must not create an approved output,
- retry should be possible.

The educational platform must not depend on AI uptime for basic data integrity.

---

# 48. AI Confidence

The platform should not display fake precision.

For analytical outputs, AI may express uncertainty using:

- High confidence
- Medium confidence
- Low confidence
- Needs verification

These labels should describe model uncertainty only.

They do not replace evidence verification.

---

# 49. Hallucination Mitigation

The platform should reduce unsupported AI claims through:

- evidence-first prompting where appropriate,
- requiring source references for factual analysis,
- separating suggestions from evidence,
- encouraging "not enough information" responses,
- structured verification steps,
- instructor/team review,
- source-aware patent analysis.

AI should never be instructed to fabricate missing evidence.

---

# 50. Contradiction Detection

AI may be used to flag:

- conflicting project versions,
- inconsistent requirements,
- pitch claims inconsistent with evidence,
- decisions that contradict later project state,
- patent analysis inconsistent with stored source notes.

Flags remain review items, not automatic corrections.

---

# 51. Cross-Team Leakage Prevention

Mandatory rules:

1. AI retrieval is scoped before model invocation.
2. Another team's private data must never be placed in prompt context.
3. Cached AI summaries must retain source scope.
4. Shared artifacts may be used only according to share permissions.
5. Revoked access must remove the object from future AI context.
6. Removed team members lose access to team AI context.
7. AI logs must not reveal restricted prompt content to unauthorized users.

---

# 52. Personal-to-Team AI Sharing

A user may generate AI output privately and later:

- keep private,
- share with team,
- save as candidate,
- convert to project object.

When shared, provenance remains:

- requested by user,
- generated by AI,
- original Personal Workspace,
- share timestamp.

---

# 53. Team AI Attribution

Team AI outputs should display:

- AI role,
- requesting team member,
- generation time,
- linked context,
- disposition.

This prevents AI contributions from appearing anonymously as team-authored facts.

---

# 54. Instructor Review of AI Use

Master should be able to see AI outputs that have been:

- submitted,
- converted to team artifacts,
- used in an artifact under review,
- explicitly shared.

Master should not automatically see all private Personal AI interactions.

---

# 55. AI-Supported Instructor Feedback

AI may help Master:

- summarize artifact history,
- identify missing required fields,
- compare output against activity rubric,
- find unresolved feedback,
- identify unsupported claims.

AI-generated feedback should remain a draft until the Master confirms it.

---

# 56. AI and Rubrics

If course rubrics are added later, AI may:

- compare submission against criteria,
- identify missing elements,
- prepare instructor review notes.

AI must not automatically issue final grades or approvals unless explicitly designed and approved later.

---

# 57. AI Output Versioning

Saved AI output should remain immutable as generated.

If a user edits it, the edited content should become:

- modified candidate,
- project object,
- or new draft.

Do not rewrite the original AI output while claiming it is unchanged.

---

# 58. AI Output Deletion

Personal temporary AI output may be deletable.

However, if AI output has been:

- linked to a Decision,
- used in approved project content,
- submitted,
- cited in a Change Log,

it should normally be archived rather than destructively deleted.

---

# 59. Safety / High-Stakes Boundaries

AI must not present itself as a substitute for:

- patent attorney,
- legal counsel,
- licensed engineer,
- financial advisor,
- regulatory authority,
- safety certifier.

Where appropriate, AI should identify when expert review or formal verification is needed.

---

# 60. External Research

Some AI tasks may require current external research.

When external search is enabled, the platform must distinguish:

- project evidence,
- external research result,
- AI interpretation.

An external webpage does not automatically become verified evidence.

The user/team should intentionally save relevant source material into Evidence.

---

# 61. AI Tool Access

Long-term AI may call platform tools.

Examples:

- retrieve approved artifacts,
- create candidate idea,
- add draft gap,
- summarize evidence,
- prepare comparison,
- create draft validation plan.

Important rule:

AI actions that change project state must obey action permissions.

High-impact state changes should require user confirmation.

---

# 62. Read Actions vs Write Actions

## AI Read Actions

May retrieve authorized:

- project objects,
- evidence,
- feedback,
- artifacts.

## AI Draft Write Actions

May create:

- draft suggestion,
- candidate,
- temporary structured output.

## AI Committed Write Actions

Should require explicit user confirmation before:

- creating accepted team objects,
- modifying current baseline,
- creating formal decisions,
- submitting work,
- approving work,
- changing permissions.

---

# 63. AI Action Confirmation

Recommended pattern:

```text
AI proposes:
"Create 3 candidate Requirements?"

User:
Confirm

System:
Creates Draft Requirement objects
```

The model should not directly perform hidden changes.

---

# 64. AI and Version Changes

If AI-assisted work changes an approved artifact:

1. Current approved version remains unchanged.
2. New draft version is created.
3. AI contribution is linked.
4. Human edits/reviews.
5. Decision/approval occurs.
6. New version becomes current only after approval where required.

---

# 65. AI Analytics

The platform may later measure:

- which AI roles are used,
- which suggestions are accepted,
- which suggestions are rejected,
- AI cost by course,
- AI cost by activity,
- user engagement,
- time saved.

These analytics should not expose confidential project content unnecessarily.

---

# 66. AI Configuration

Admin/Master should eventually be able to configure:

- AI enabled/disabled by course,
- AI enabled/disabled by activity,
- allowed AI role,
- request limits,
- model profile,
- evidence requirement,
- whether student may use AI before completing personal work.

This is especially useful educationally.

---

# 67. Independent Thinking Control

For activities that require independent thinking, AI access may be delayed.

Example:

```text
Step 1: Student creates 5 ideas independently
Step 2: Student confirms completion
Step 3: AI assistance becomes available
```

This prevents AI from replacing the learning objective.

---

# 68. Team Reveal Control

In private-before-team activities:

- personal ideas remain hidden,
- AI cannot summarize other members' unrevealed ideas,
- reveal occurs according to activity rules,
- after reveal, team AI may analyze the shared pool.

---

# 69. AI UX State Requirements

Even before UI design, the product should support states such as:

- AI Ready
- Generating
- Generated
- Needs Review
- Candidate
- Verified
- Rejected
- Linked to Project
- Error

These states must exist in the underlying data/workflow.

---

# 70. MVP AI Capabilities

## MUST HAVE

1. Context-aware AI request inside an activity.
2. AI role determined by activity.
3. Permission-aware context.
4. Save AI output.
5. Label AI output type.
6. Link AI output to relevant project objects.
7. Human disposition.
8. Convert accepted AI output into draft project object.
9. Evidence separation.
10. AI context references.
11. Basic usage logging.
12. Provider abstraction.

## SHOULD HAVE

- AI conversation threads,
- structured output validation,
- model routing,
- AI cost dashboard,
- project-aware retrieval,
- instructor AI review assistant.

## LATER

- autonomous multi-step agents,
- background research agents,
- continuous patent monitoring,
- automated investor research agents,
- automatic project health scoring,
- advanced multi-model orchestration.

---

# 71. AI Non-Goals for MVP

The MVP should not include:

- autonomous invention approval,
- autonomous patentability conclusion,
- autonomous legal advice,
- AI joining team votes,
- AI changing permissions,
- AI modifying current approved baseline without confirmation,
- AI reading all organization data,
- hidden cross-team learning,
- unrestricted web research on every prompt,
- complex autonomous agent swarms.

---

# 72. AI Data Entities

The Data Model should support:

- `ai_outputs`
- `ai_context_references`
- `ai_prompt_templates`
- `ai_usage_events`
- `ai_conversations` optional
- `ai_messages` optional

Suggested conceptual fields for `ai_usage_events`:

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
- success/failure
- timestamp

---

# 73. AI Conversation Entities — Optional MVP Extension

## `ai_conversations`

- id
- project_id
- workspace_id
- activity_instance_id
- owner_user_id
- ai_role
- title
- status
- created_at

## `ai_messages`

- id
- conversation_id
- sender_type
- content
- created_at
- linked_ai_output_id nullable

These are not required if the MVP uses task-based AI interactions instead of chat.

---

# 74. AI Prompt Template Entities

## `ai_prompt_templates`

Suggested fields:

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

Prompt templates should be version-controlled.

---

# 75. AI Model Profiles

## `ai_model_profiles`

Conceptual fields:

- id
- profile_code
- purpose
- capability_level
- cost_class
- latency_class
- provider_configuration_reference
- status

Example profiles:

- FAST
- STANDARD
- DEEP_ANALYSIS
- EXTRACTION

Specific provider models are selected later.

---

# 76. AI Task Contract

Each AI task should define:

- Task Name
- Allowed Role
- Required Context
- Optional Context
- Forbidden Context
- Output Type
- Output Schema
- Verification Requirement
- Allowed Project Actions
- Cost Class

Example:

```text
Task: Analyze Gap
Role: Comparative Analyst
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

# 77. AI Decision Log

Important AI-assisted decisions should preserve:

```text
AI Suggestion
↓
Human Response
↓
Evidence Used
↓
Team Decision
↓
Project Change
```

This can be represented through existing:

- AI Output
- Evidence
- Decision
- Change Log
- Artifact Version

No separate duplicate system is required.

---

# 78. Provider Failure / Migration

The platform must support provider replacement without losing:

- project data,
- AI history,
- saved AI output,
- prompt templates,
- context references,
- human decisions.

Provider-specific IDs may be stored as metadata but must not be the primary identity of platform records.

---

# 79. AI Security Requirements

Mandatory:

1. Server-side permission checks before context retrieval.
2. No client-trusted workspace scope.
3. No cross-team retrieval.
4. Secrets/API keys never exposed to browser clients.
5. User-generated evidence sanitized/validated before tool use where required.
6. AI tool calls must enforce the same authorization rules as normal user actions.
7. Logged AI prompts must avoid exposing unnecessary confidential data to broad admin analytics.
8. Provider data-retention options must be reviewed during Technical Architecture selection.

---

# 80. AI Privacy Requirements

The technical architecture must later evaluate:

- provider data usage terms,
- retention,
- training use,
- regional data processing,
- enterprise/API privacy controls,
- deletion behavior,
- compliance requirements.

No provider should be selected until these are reviewed.

---

# 81. AI Product Decisions Captured

## AI-001 — AI Is Native but Not Authoritative

AI is embedded in workflows but cannot silently approve content.

**Status:** Required.

## AI-002 — Context Is Activity-Specific

AI receives only relevant authorized context.

**Status:** Required.

## AI-003 — AI Output Is Separate from Evidence

AI output must remain distinct until verified.

**Status:** Required.

## AI-004 — FICI Owns Project Memory

Project continuity lives in FICI data, not opaque provider memory.

**Status:** Required.

## AI-005 — Provider Abstraction

The platform should be able to replace AI providers later.

**Status:** Required.

## AI-006 — Human Confirmation for Project Changes

AI may create drafts/candidates, but committed state changes require authorized human action.

**Status:** Required.

## AI-007 — Preserve AI Provenance

Saved AI output retains role, requester, context references, and disposition.

**Status:** Required.

## AI-008 — Independent Thinking Can Precede AI

Activities may delay AI access until the educational objective is met.

**Status:** Recommended.

## AI-009 — AI Does Not Vote

AI can analyze but does not participate in human team voting.

**Status:** Required.

## AI-010 — AI Usage Must Be Cost-Controlled

Context, task type, model profile, and usage should be managed deliberately.

**Status:** Required.

---

# 82. Open Questions Before Technical Implementation

1. Should Personal AI conversations be saved automatically or only when the user chooses Save?
2. Should Team AI conversation history be visible to Master by default?
3. Should Master be able to disable AI for selected activities?
4. Should the platform enforce "independent work first" for SCAMPER and Brainstorming?
5. Should AI be allowed to create draft project objects directly after one user confirmation?
6. Which AI outputs require evidence before being accepted as Candidate?
7. Should students see the full list of context items used by AI?
8. Should users be able to manually remove a context item before generation?
9. Should AI-generated patent comparisons require claim/paragraph references before saving?
10. Should AI research the public web in MVP, or initially operate only on project data and user-supplied sources?
11. Should the Master receive AI usage visibility by student/team?
12. Should usage limits be per user, team, cohort, or organization?
13. Should FICI support a Free AI mode and Paid/Advanced AI mode?
14. Which project actions should AI be able to propose through tools in MVP?
15. What retention policy should apply to AI prompts and raw conversations?

These should be resolved before the AI implementation is locked.

---

# 83. Required Next Document

The next document is:

# `10_TECHNICAL_ARCHITECTURE.md`

It should finally select and justify the implementation approach, including:

- application architecture,
- frontend,
- backend,
- database,
- authentication,
- realtime collaboration,
- team chat,
- file storage,
- AI provider layer,
- patent integrations,
- live-classroom integration,
- hosting,
- security,
- deployment,
- observability,
- provider abstraction,
- Build vs Integrate decisions.

Because these technologies and services change over time, current official product information and pricing should be researched before the final technical choices are approved.

---

# 84. Codex AI Rule

Codex must not implement AI as a generic endpoint that receives unrestricted project data.

Every AI request must follow:

```text
AUTHENTICATE USER
↓
RESOLVE ROLE / SCOPE
↓
RESOLVE CURRENT WORKSPACE
↓
RESOLVE CURRENT PROJECT / ACTIVITY
↓
SELECT AUTHORIZED CONTEXT
↓
SELECT AI ROLE / TASK
↓
CALL MODEL THROUGH PROVIDER ABSTRACTION
↓
CLASSIFY OUTPUT
↓
SAVE PROVENANCE
↓
WAIT FOR HUMAN DISPOSITION
```

If a feature bypasses this flow, it must be treated as an architecture defect.

---

# End of Document

**Current Status:** Draft v0.1 — Ready for Ahmad/FICI review.  
**Next Document After Approval:** `10_TECHNICAL_ARCHITECTURE.md`
