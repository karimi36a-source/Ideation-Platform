# FICI Invention Education & Development Platform
## Platform Architecture Specification

**Document:** 02_PLATFORM_ARCHITECTURE.md  
**Status:** Draft v0.1 — For Review  
**Depends on:** `01_PRODUCT_REQUIREMENTS.md`  
**Purpose:** Define the high-level product architecture and responsibility boundaries of the FICI platform before technical stack selection, database design, API design, or implementation.

---

# 1. Architecture Objective

The FICI platform must be structured as a modular development environment that combines:

- Learning
- Live instruction
- Individual work
- Team collaboration
- Invention development
- Product and startup development
- AI assistance
- Evidence management
- Decision-making
- Versioning
- Instructor review
- Project continuity across programs

The architecture must support the following long-term development path:

**Workshop → Professional Course → Advanced Course → Specialized Programs → Mentoring / Acceleration**

The platform must not be architected as a collection of unrelated course pages.

The central architectural principle is:

# One Persistent Development Project + Multiple Programs + Multiple Workspaces + Multiple Development Tools

---

# 2. Architectural Principles

The platform architecture must follow these principles.

## 2.1 Curriculum First

The curriculum defines the workflows.

The platform must support the approved educational methodology rather than forcing the methodology into generic LMS behavior.

---

## 2.2 Persistent Project Continuity

A participant should be able to continue the same Development Project across multiple courses and stages.

The project should not be recreated for each course.

---

## 2.3 Modular Core + Program Modules

The platform must separate:

### Core Platform
Reusable services required by every program.

### Program Modules
Curriculum-specific activities, tools, and workflows.

This separation is essential for future growth.

---

## 2.4 Workspace-Aware Architecture

Every collaborative tool should operate inside a workspace scope.

Primary scopes:

- Personal Workspace
- Team Workspace
- Instructor / Master Workspace
- Shared / Cross-Team Workspace

A tool should not be rebuilt separately for personal and team use.

---

## 2.5 Structured Data + Files

Important development information must exist as structured platform objects wherever future analysis, versioning, AI context, traceability, or collaboration depends on it.

Files remain important, but the platform must not become only a file repository.

---

## 2.6 Human-Controlled AI

AI is a platform service that assists development activities.

AI must:

- respect permissions,
- receive controlled context,
- label its outputs,
- preserve provenance,
- remain subject to human review.

---

## 2.7 Traceability by Design

Important changes should be traceable through:

**Origin → Analysis → Evidence → Discussion → Decision → Version Change**

Traceability is a platform-level capability, not a feature specific to patent work.

---

## 2.8 Versioning by Design

Important artifacts and project objects must preserve historical state.

New work must not silently overwrite prior approved work.

---

## 2.9 Integrate Commodity Infrastructure

The platform should own its business logic and methodology while allowing external infrastructure for commodity services such as:

- video,
- AI model APIs,
- authentication,
- email delivery,
- file storage,
- search,
- notifications.

Provider selection is deferred to `09_TECHNICAL_ARCHITECTURE.md`.

---

# 3. Top-Level Platform Architecture

The platform is divided into the following major systems:

1. Identity & Access System
2. Organization / Cohort / Enrollment System
3. Learning & Curriculum System
4. Live Learning System
5. Workspace & Team Collaboration System
6. Development Project System
7. Method & Activity Engine
8. Structured Artifact System
9. Evidence & Research System
10. AI Copilot System
11. Review & Feedback System
12. Decision & Voting System
13. Versioning & Traceability System
14. Progress & Development Gate System
15. Communication & Notification System
16. File & Knowledge System
17. Reporting & Administration System
18. Export / Final Package System

These systems must work together through clearly defined boundaries.

---

# 4. Architectural Overview

Conceptually:

```text
USERS
│
├── Personal Identity
├── Role(s)
├── Course Enrollment(s)
└── Team Membership(s)

        ↓

PROGRAM / COHORT
│
├── Course
├── Sessions
├── Activities
└── Instructor Case Study

        ↓

WORKSPACE LAYER
│
├── Personal Workspace
├── Team Workspace
├── Instructor Workspace
└── Shared Workspace

        ↓

DEVELOPMENT PROJECT
│
├── Invention
├── Evidence & IP
├── Product Development
├── Validation
├── Business & Market
├── Team & Execution
├── Finance
└── Pitch & Funding

        ↓

ACTIVITY / METHOD ENGINE
│
├── Generate
├── Organize
├── Connect
├── Evaluate
├── Decide
├── Investigate
├── Validate
└── Plan

        ↓

STRUCTURED ARTIFACTS + FILES + AI + EVIDENCE
        ↓

REVIEW / DECISION / VERSION / APPROVAL
        ↓

NEXT ACTIVITY / NEXT SESSION / NEXT DEVELOPMENT STAGE
```

---

# 5. System 1 — Identity & Access System

## Purpose

Manage authenticated users and their platform identity.

## Responsibilities

- user account,
- profile,
- authentication state,
- role assignment,
- authorization checks,
- organization membership,
- cohort membership,
- team membership,
- access permissions.

## Core Entities

- User
- Role
- Permission
- Organization
- Membership
- TeamMembership
- Enrollment

## Important Rule

Authorization must be evaluated separately from authentication.

Being logged in does not imply access to every project, team, chat, artifact, or AI context.

Detailed rules will be defined in:

`03_ROLES_PERMISSIONS.md`

---

# 6. System 2 — Organization / Cohort / Enrollment System

## Purpose

Provide the operational structure around programs and learners.

## Responsibilities

- organizations,
- programs,
- cohorts,
- class groups,
- instructors,
- mentors,
- enrollment,
- course access,
- cohort dates,
- team assignment.

## Example Structure

```text
Organization: FICI
└── Program: Professional Course
    └── Cohort: Fall 2026
        ├── Master: Instructor A
        ├── Team 1
        ├── Team 2
        └── Team 3
```

The same Development Project may survive beyond one cohort.

---

# 7. System 3 — Learning & Curriculum System

## Purpose

Deliver the educational structure.

## Responsibilities

- programs,
- courses,
- sessions,
- lessons,
- reference material,
- activities,
- assignments,
- prerequisites,
- activity sequencing,
- learning completion,
- educational instructions.

## Important Principle

Course completion and project readiness are separate.

The Learning System should answer:

**What should the learner study or do next?**

The Development Project System should answer:

**What state is the project currently in?**

---

# 8. System 4 — Live Learning System

## Purpose

Support synchronous instructor-led learning.

## Responsibilities

Long-term capabilities may include:

- video,
- audio,
- screen sharing,
- presentation sharing,
- live chat,
- raise hand,
- participant controls,
- attendance,
- breakout rooms,
- reactions,
- polls,
- recordings,
- live activity launching.

## Important Architectural Principle

The live classroom should be aware of the current learning activity.

Example:

```text
Session 5
↓
Activity: Dot Voting
↓
Team Workspace
↓
Voting Activity Instance
↓
Result saved to Development Project
```

The Live Learning System should not own invention data.

It launches and displays activities managed by the Method / Activity Engine.

---

# 9. System 5 — Workspace & Team Collaboration System

## Purpose

Control where users work and who can access their work.

This is a core platform system.

## Workspace Types

### 9.1 Personal Workspace

Private default work area.

Used for:

- personal notes,
- individual brainstorming,
- private AI use,
- private research,
- draft artifacts,
- individual SCAMPER,
- private maps.

---

### 9.2 Team Workspace

Private shared environment for team members.

Used for:

- team chat,
- shared files,
- team brainstorming,
- team decisions,
- collaborative artifacts,
- team AI work,
- team invention development.

---

### 9.3 Instructor / Master Workspace

Used for:

- cohort oversight,
- reviews,
- case study,
- team monitoring,
- submitted work,
- intervention,
- feedback.

---

### 9.4 Shared Workspace

Used for intentionally shared materials.

Possible audiences:

- Master,
- Mentor,
- Admin,
- selected user,
- another team,
- whole cohort.

---

## Core Capabilities

- create team,
- add member,
- remove member,
- move member,
- assign team lead,
- assign mentor,
- archive team,
- workspace-specific permissions,
- share artifact,
- revoke share,
- track share history.

Detailed behavior will be defined in:

`04_WORKSPACE_TEAM_COLLABORATION.md`

---

# 10. System 6 — Development Project System

## Purpose

Act as the permanent project container and long-term source of truth.

This is the heart of the platform.

## Development Project Domains

### 10.1 Invention

May contain:

- problems,
- ideas,
- SCAMPER outputs,
- solutions,
- functions,
- features,
- components,
- systems,
- subsystems,
- invention structure,
- mind maps,
- gap maps,
- invention concepts.

---

### 10.2 Evidence & IP

May contain:

- patent searches,
- search logs,
- patent documents,
- evidence sheets,
- claims,
- drawings,
- architecture maps,
- comparisons,
- gap findings,
- technical references.

---

### 10.3 Product Development

May contain:

- requirements,
- assumptions,
- constraints,
- risks,
- PoC,
- prototype plans,
- MVP plans,
- validation plans,
- TRL,
- roadmap.

---

### 10.4 Validation

May contain:

- validation questions,
- experiments,
- tests,
- metrics,
- results,
- learnings,
- decisions.

---

### 10.5 Business & Market

May contain:

- business feasibility,
- market assumptions,
- customer segments,
- interviews,
- market evidence,
- value propositions,
- business model,
- go-to-market inputs.

---

### 10.6 Team & Execution

May contain:

- team capability map,
- role ownership,
- founder structure,
- decision rights,
- backlog,
- tasks,
- Kanban,
- sprint / execution records,
- conflict / decision records.

---

### 10.7 Finance

May contain:

- cost assumptions,
- revenue assumptions,
- pricing,
- unit economics,
- financial forecasts,
- funding requirements.

---

### 10.8 Pitch & Funding

May contain:

- pitch narrative,
- pitch claims,
- evidence references,
- pitch deck,
- investor readiness,
- funding strategy,
- investor targets,
- funding activity.

---

## Important Rule

The Development Project System owns project state.

Courses create and update project state through activities.

---

# 11. System 7 — Method & Activity Engine

## Purpose

Provide reusable interaction patterns for the FICI methodology.

Instead of coding every course technique as unrelated software, the platform should reuse shared activity mechanics.

## Activity Families

### Generate

Used for:

- SCAMPER
- Brainstorming
- Problem Storming

Mechanics may include:

- prompt,
- timed generation,
- cards/items,
- private generation,
- team submission,
- combining,
- expansion.

---

### Organize

Used for:

- Affinity Diagram
- clustering
- categorization
- grouping evidence.

Mechanics may include:

- cards,
- drag / move,
- grouping,
- headers,
- relationships.

---

### Connect

Used for:

- Mind Mapping
- Architecture Mapping
- Problem–Solution Mapping
- Claim Mapping

Mechanics may include:

- nodes,
- edges,
- hierarchy,
- cross-links,
- labels,
- references.

---

### Evaluate

Used for:

- comparisons,
- matrices,
- criteria-based review,
- technical review,
- option assessment.

---

### Decide

Used for:

- Dot Voting,
- Fist to Five,
- Planning Poker,
- decision gates,
- team decisions.

---

### Investigate

Used for:

- patent research,
- technical research,
- market research,
- customer research.

---

### Validate

Used for:

- experiment planning,
- testing,
- customer validation,
- verification.

---

### Plan

Used for:

- roadmap,
- backlog,
- milestones,
- Kanban,
- development planning.

---

## Activity Instance

Every actual use of a method should create an Activity Instance.

Example:

```text
Activity Definition:
Dot Voting

Activity Instance:
Cohort 2026 / Team 3 / Session 5 / Problem Prioritization
```

The instance should store:

- participants,
- workspace,
- input objects,
- output objects,
- timestamps,
- status,
- results.

---

# 12. System 8 — Structured Artifact System

## Purpose

Represent important learning and development outputs as durable, versioned artifacts.

## Artifact Examples

- Developed Concept
- Problem Bank
- Solution Bank
- Team Decision Record
- Invention Structure
- Gap List
- Mind Map
- Minimum Essential Structure
- Invention Concept
- Patent Landscape Snapshot
- Search Log
- Claim Map
- Architecture Map
- Gap Map
- Product Requirements
- Risk Map
- Validation Plan
- Product Roadmap
- Business Feasibility Assessment
- Market Validation Record
- Team Development Map
- Pitch Deck Record

## Artifact Responsibilities

- ownership,
- workspace scope,
- status,
- version,
- linked project objects,
- linked evidence,
- linked feedback,
- linked decisions,
- linked AI outputs.

---

# 13. System 9 — Evidence & Research System

## Purpose

Store, organize, and connect evidence to project conclusions and decisions.

## Evidence Types

- patent document,
- patent claim,
- standard,
- datasheet,
- technical paper,
- calculation,
- measurement,
- test result,
- market source,
- customer interview,
- verified secondary source.

## Evidence Responsibilities

- source,
- citation / reference,
- uploader / creator,
- evidence type,
- verification status,
- related project objects,
- related decisions,
- related AI analysis.

## Important Rule

Evidence must remain distinguishable from:

- AI analysis,
- AI suggestion,
- team interpretation,
- instructor feedback.

---

# 14. System 10 — AI Copilot System

## Purpose

Provide context-aware AI assistance across development stages.

## AI Architecture Components

### 14.1 Context Builder

Constructs the exact context for the current task.

Potential context layers:

1. Program context
2. Project baseline
3. Relevant development domain
4. Current artifact
5. Current activity
6. Relevant evidence
7. Instructor feedback
8. Current task

---

### 14.2 AI Role Selector

Examples:

- Structured Creativity Assistant
- Ideation Facilitator
- Systems Analyst
- Patent Research Assistant
- Comparative Analyst
- Critical Reviewer
- Product Requirements Analyst
- Validation Planning Assistant
- Market Research Assistant
- Finance Analyst
- Pitch Review Assistant

---

### 14.3 AI Output Classifier

AI output should be classified as:

- AI Analysis
- AI Suggestion
- Hypothesis
- Draft
- Candidate

AI output must not automatically become approved content.

---

### 14.4 AI History

Store where appropriate:

- role,
- task,
- context scope,
- input references,
- response,
- user action,
- acceptance / rejection,
- verification status.

---

### 14.5 Permission Boundary

AI must never receive information outside the requesting user's authorized scope.

This requirement is mandatory.

Detailed AI behavior will be defined in:

`08_AI_ASSISTANT_SPEC.md`

---

# 15. System 11 — Review & Feedback System

## Purpose

Support instructor, mentor, and team review cycles.

## Responsibilities

- submit artifact,
- request review,
- comment,
- annotate,
- request revision,
- resolve comment,
- approve,
- reject,
- reopen.

## Example Lifecycle

```text
Draft
↓
Submitted
↓
Under Review
↓
Revision Requested
↓
Revised
↓
Resubmitted
↓
Approved
```

Feedback must remain tied to the relevant artifact version.

---

# 16. System 12 — Decision & Voting System

## Purpose

Capture structured human decisions.

## Supported Decision Mechanics

- Dot Voting
- Fist to Five
- Planning Poker
- option comparison
- Go / Modify / Stop
- instructor approval
- team approval

## Decision Record

Should be able to capture:

- question,
- options,
- participants,
- votes,
- concerns,
- discussion summary,
- evidence,
- final decision,
- reasoning,
- related artifacts,
- affected versions.

Voting results are not automatically equal to approval.

---

# 17. System 13 — Versioning & Traceability System

## Purpose

Preserve development history.

## Responsibilities

- artifact versioning,
- object change history,
- current vs previous states,
- origin tracking,
- change reason,
- linked decisions,
- linked evidence,
- linked AI suggestion,
- linked feedback.

## Traceability Example

```text
Patent Gap G12
↓
Problem P08
↓
Candidate Solution S14
↓
AI Suggestion A23
↓
Team Discussion
↓
Technical Test T03
↓
Evidence EV19
↓
Decision D08
↓
Component C07 added
↓
Invention Concept V2
```

The platform should preserve this chain.

---

# 18. System 14 — Progress & Development Gate System

## Purpose

Track both education progress and project readiness.

## Learning Progress

Examples:

- session completion,
- assignment submission,
- participation.

## Development Readiness

Examples:

- invention structure ready,
- patent landscape incomplete,
- validation evidence weak,
- market validation ready,
- finance not started.

## Development Gates

Possible reusable gates:

- Invention Readiness
- Technical Development
- Business Feasibility
- Market Validation
- Investment Readiness

A gate may produce:

- Go
- Modify
- Hold
- Stop
- More Evidence Required

---

# 19. System 15 — Communication & Notification System

## Purpose

Support communication outside the structured artifact flow.

## Communication Types

### Team Chat

Private team communication.

### Instructor / Team Communication

Possible channel for:

- coaching,
- questions,
- feedback discussions.

### Announcements

Instructor or Admin messages to:

- cohort,
- team,
- program.

## Notifications

Events may include:

- mention,
- new comment,
- share received,
- team membership change,
- review requested,
- revision requested,
- approval,
- assignment due,
- decision pending.

---

# 20. System 16 — File & Knowledge System

## Purpose

Store supporting files while maintaining their relationship to structured platform content.

## File Contexts

Files may belong to:

- user,
- team,
- project,
- activity,
- artifact,
- evidence item,
- session,
- assignment.

## Important Rule

Uploading a file should not automatically make its contents available to everyone.

File access must follow workspace and project permissions.

---

# 21. System 17 — Reporting & Administration System

## Purpose

Provide operational visibility.

## Potential Master / Admin Reporting

- user activity,
- course progress,
- project progress,
- team progress,
- pending reviews,
- unresolved gaps,
- missing assignments,
- approval status,
- development gate status.

Advanced analytics may be deferred.

---

# 22. System 18 — Export / Final Package System

## Purpose

Allow projects to produce structured outputs.

Potential exports:

- final invention development package,
- evidence package,
- project summary,
- validation package,
- pitch package,
- instructor report,
- course completion package.

Export should assemble approved project state rather than only download random files.

---

# 23. Architecture Relationship Between Programs and Projects

The architecture must support:

```text
Development Project
├── Workshop Participation
│   └── Early Project Outputs
│
├── Professional Course
│   └── Invention Concept V2
│
├── Advanced Course
│   └── Product / Business / Startup Development
│
└── Specialized Program(s)
    └── Additional Domain-Specific Development
```

Programs contribute to the same project.

---

# 24. Architecture Relationship Between Workspaces and Projects

A project is not the same as a workspace.

A project can contain contributions from multiple workspaces.

Example:

```text
Development Project A

Personal Workspace — Ahmad
  └── Private Brainstorming

Personal Workspace — Sara
  └── Private Research

Team Workspace — Team 2
  ├── Shared Problem Bank
  ├── Shared Solution Bank
  └── Team Mind Map

Instructor Workspace
  └── Feedback / Approval
```

When private content is shared into a team project:

- the original owner remains recorded,
- the team receives the approved share,
- the share action is logged.

---

# 25. Architecture Relationship Between Tools and Workspaces

Tools must be workspace-aware.

Example:

```text
Brainstorming Tool
├── Personal Mode
├── Team Mode
└── Shared / Review Mode
```

The core tool behavior remains reusable.

The workspace determines:

- visibility,
- participants,
- permissions,
- ownership,
- sharing.

---

# 26. Architecture Relationship Between AI and Workspaces

AI context must follow the same permission system.

Example:

A student working privately may provide AI with:

- their personal draft,
- shared team artifacts they are allowed to access,
- approved project evidence.

The AI must not receive:

- another user's private notes,
- another team's private chat,
- restricted instructor notes,
- unshared artifacts.

Permission-aware AI context is a core architecture requirement.

---

# 27. Architecture Relationship Between Chat and Project Content

Team chat is not itself the source of truth for project decisions.

Chat may contain discussion.

Formal project changes should be captured as:

- artifact update,
- decision record,
- task,
- feedback item,
- approved version.

This prevents important project logic from being buried in chat history.

---

# 28. Architecture Relationship Between Files and Evidence

Not every file is evidence.

A file may be:

- supporting attachment,
- draft,
- image,
- reference,
- evidence source.

Evidence must be intentionally classified and linked.

This distinction is required for reliable AI and traceability.

---

# 29. Program Module Architecture

Program-specific modules should register:

- sessions,
- activity definitions,
- required inputs,
- outputs,
- dependencies,
- method configuration,
- completion criteria,
- gate relationships.

The core platform should not need code changes for every minor curriculum revision.

Where practical, course structure should be configurable.

---

# 30. Professional Course Module — Architectural Responsibilities

The Professional Course module should use core systems to implement workflows such as:

- SCAMPER
- Brainstorming
- Problem Storming
- Problem Bank
- Solution Bank
- Dot Voting
- Fist to Five
- Planning Poker
- Affinity Diagram
- Invention Structure
- Gap List
- Mind Map
- Minimum Essential Structure
- Patent Reading
- Patent Search Log
- Patent Evidence
- Claim Mapping
- Architecture Mapping
- Similarity / Difference Matrix
- Gap Map
- AI-Assisted Refinement
- Invention Concept V2

These should use reusable core engines rather than custom isolated code where possible.

---

# 31. Advanced Course Module — Architectural Responsibilities

The Advanced Course module should use the same core platform to implement:

- Product Development Question Map
- Requirements
- Assumptions
- Constraints
- Risk Map
- Validation Questions
- PoC / Prototype / MVP planning
- Experiment planning
- TRL
- Product Roadmap
- Business Feasibility
- Market Research
- Customer Validation
- Team Development
- Founder Structure
- Leadership / Conflict
- Backlog
- Kanban
- Agile execution
- Go-to-Market
- Finance
- Pitch Deck
- Funding Strategy

The Advanced Course must not require a separate platform architecture.

---

# 32. Architecture for Future Specialized Programs

Future modules should reuse:

- Identity
- Workspaces
- Projects
- Activity Engine
- AI
- Evidence
- Versioning
- Review
- Decisions
- Progress
- Export

Only specialized activity definitions and domain artifacts should be added.

---

# 33. Architectural Ownership Boundaries

FICI should own:

- Development Project model,
- workspace logic,
- team logic,
- sharing model,
- curriculum logic,
- activity definitions,
- method workflows,
- structured artifacts,
- project object relationships,
- evidence relationships,
- traceability,
- decision logic,
- AI context rules,
- versioning rules.

External providers may supply infrastructure.

Provider-specific decisions are intentionally excluded from this document.

---

# 34. MVP Architectural Priority

The MVP architecture should prioritize:

1. Authentication / identity
2. Roles and permission enforcement
3. Personal workspace
4. Team workspace
5. Team management
6. Private team chat
7. Development Project
8. Core structured artifacts
9. Sharing
10. Instructor review
11. Version history
12. Initial activity tools
13. Initial AI context
14. Basic evidence handling
15. Notifications
16. Learning / course progression

The exact MVP cut line will be defined in:

`07_MVP_SCOPE.md`

---

# 35. Architectural Non-Goals at This Stage

This document does not define:

- programming language,
- frontend framework,
- backend framework,
- database engine,
- cloud provider,
- authentication vendor,
- realtime vendor,
- AI provider,
- video provider,
- storage provider,
- deployment model,
- API protocol,
- database tables,
- UI screens.

Those decisions are intentionally deferred.

---

# 36. Architecture Decisions Captured

## Decision A-001 — Persistent Development Project

**Decision:** Development Project is the primary long-lived project container.

**Status:** Recommended / derived from approved product requirements.

---

## Decision A-002 — Modular Core + Program Modules

**Decision:** Shared platform capabilities belong to Core Platform; course-specific techniques belong to modules.

**Status:** Recommended.

---

## Decision A-003 — Workspace-Aware Tools

**Decision:** Core tools must operate in Personal, Team, and Shared scopes rather than be duplicated.

**Status:** Recommended.

---

## Decision A-004 — Team Collaboration as Core Architecture

**Decision:** Team management, private chat, sharing, and team-scoped tools are first-class core systems.

**Status:** Required.

---

## Decision A-005 — AI as Shared Platform Service

**Decision:** AI is one context-aware platform service with multiple roles, not a collection of disconnected bots.

**Status:** Recommended.

---

## Decision A-006 — Structured Artifacts

**Decision:** Important outputs should be stored as structured, versioned artifacts rather than only uploaded files.

**Status:** Recommended.

---

## Decision A-007 — Evidence Separation

**Decision:** Source evidence remains a distinct system from AI analysis, team interpretation, and feedback.

**Status:** Required.

---

## Decision A-008 — Versioning & Traceability as Core

**Decision:** Versioning and traceability are shared platform capabilities used across all development stages.

**Status:** Required.

---

## Decision A-009 — Chat Is Not Source of Truth

**Decision:** Important decisions and project changes must be recorded structurally, not only inside chat.

**Status:** Recommended.

---

## Decision A-010 — Configurable Curriculum

**Decision:** Course/session/activity definitions should be configurable where practical and not hard-coded to one fixed sequence.

**Status:** Recommended.

---

# 37. Open Architecture Questions

The following questions remain open and should be resolved in later documents:

1. Exact permission inheritance rules.
2. Exact Master/Admin access to private team chat.
3. Whether users may belong to multiple teams simultaneously.
4. Whether team artifacts can have multiple owners.
5. Exact cross-team collaboration behavior.
6. Artifact locking and concurrent editing rules.
7. Whether team chat is retained permanently after course completion.
8. Which tools require realtime multi-user editing in MVP.
9. Which tools may initially use integrated external services.
10. Exact AI context retention rules.
11. Exact evidence verification roles.
12. Exact gate approval authority.
13. Exact export formats.
14. Exact organization hierarchy.
15. Exact technical implementation stack.

These must not be silently invented during implementation.

---

# 38. Required Next Document

The next document should define the exact user authorization model:

# `03_ROLES_PERMISSIONS.md`

It must define:

- roles,
- role hierarchy,
- personal workspace access,
- team workspace access,
- team chat access,
- add/remove member permissions,
- Master access,
- Admin access,
- Mentor access,
- cross-team sharing permissions,
- artifact edit rights,
- AI context access,
- review rights,
- approval rights,
- permission inheritance,
- exceptional cases.

---

# 39. Codex Architecture Rule

Codex must treat this architecture as a constraint.

Codex must not:

- collapse Personal and Team workspaces into one global data space,
- allow cross-team data leakage,
- make AI context permission-blind,
- replace versioned artifacts with destructive updates,
- store formal project decisions only in chat,
- hard-code the platform around the Professional Course,
- introduce technical dependencies that contradict approved ownership requirements,
- add major new architectural systems without documenting the change.

If implementation requires an architectural change, the change must first be documented and approved.

---

# End of Document

**Current Status:** Draft v0.1 — Ready for Ahmad/FICI review.  
**Next Document After Approval:** `03_ROLES_PERMISSIONS.md`
