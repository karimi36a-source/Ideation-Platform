# FICI Invention Education & Development Platform
## Product Requirements Document (PRD)

**Document:** 01_PRODUCT_REQUIREMENTS.md  
**Status:** Draft v0.1 — For Review  
**Purpose:** Product source-of-truth document to guide architecture, implementation, and Codex development.  
**Scope:** Core platform supporting the FICI Workshop, Professional Course, Advanced Course, and future specialized programs.

---

## 1. Product Vision

The product is not a conventional LMS, video library, or course website.

The objective is to create a **live, collaborative, AI-assisted invention education and development environment** in which a participant can:

1. Learn a structured methodology.
2. Watch an instructor apply that methodology to a continuing case study.
3. Apply the same methodology to an individual or team project.
4. Work privately or collaboratively.
5. Receive instructor/master guidance.
6. Use context-aware AI assistance.
7. Preserve evidence, decisions, versions, and development history.
8. Progress from idea and invention development into product, startup, market, execution, finance, pitch, and funding stages.
9. Continue working on the same Development Project across multiple FICI programs.

The platform must serve the curriculum rather than force the curriculum into generic LMS behavior.

---

## 2. Product Principle

The platform should be organized around a persistent **Development Project**, not around isolated course submissions.

A Development Project may continue through:

**Workshop → Professional Course → Advanced Course → Specialized Programs → Mentoring / Acceleration**

The same project history should remain available across programs.

The platform must preserve:

- what was created,
- who created it,
- why it changed,
- what evidence supported the change,
- what AI suggested,
- what the team decided,
- what the instructor approved,
- and which version is current.

---

## 3. Product Goals

### 3.1 Educational Goals

The platform must support the FICI learning model:

**Learn → Watch Case Study → Practice → Apply to Own Project → Receive Feedback → Correct → Reuse Output in Next Stage**

The platform must support both:

- live instructor-led learning, and
- guided development between sessions.

### 3.2 Product Development Goals

The platform must help users progressively build a structured project from:

**Problem → Idea → Invention → Evidence → Refinement → Product → Validation → Business → Market → Team → Execution → Finance → Pitch → Funding**

### 3.3 Collaboration Goals

The platform must support:

- private individual work,
- private team work,
- team communication,
- structured collaboration,
- controlled sharing,
- instructor/master oversight,
- cross-team sharing when intentionally permitted.

### 3.4 AI Goals

AI must be native to the development workflow, not a generic chatbot.

AI should work with the correct context, role, method, evidence, and current project state.

AI must never silently convert its own suggestions into approved project content.

---

## 4. Target Users

The initial platform should support the following roles:

### 4.1 Admin

Responsible for platform-level administration.

Typical capabilities:

- manage organizations / cohorts / courses,
- manage users,
- assign roles,
- configure permissions,
- access platform-level reporting,
- manage course availability,
- manage system settings.

### 4.2 Master / Instructor

The main educator and project-development supervisor.

Typical capabilities:

- run live sessions,
- create and manage teams,
- add or remove team members,
- observe team work,
- review project artifacts,
- comment and annotate,
- request revisions,
- approve outputs,
- share case-study examples,
- access project progress,
- enter team workspaces according to permissions,
- monitor unresolved issues.

### 4.3 Mentor / Coach

A support role that may be assigned to one or more teams or projects.

Typical capabilities:

- view assigned project information,
- comment,
- coach users,
- participate in selected activities,
- access only the scope granted by Admin or Master.

### 4.4 Student / User

The main learner and project contributor.

Typical capabilities:

- access assigned courses,
- maintain a personal workspace,
- participate in one or more teams as allowed,
- use development tools,
- collaborate,
- submit work,
- share selected personal outputs,
- use AI assistance,
- review feedback,
- revise work,
- view project history.

### 4.5 Team Member

A Student/User acting inside a team workspace.

Team membership does not replace the user's personal workspace.

---

## 5. Program Structure

The platform must support multiple program types without hard-coding the software around one course.

Initial program families:

### 5.1 Innovation & Invention Workshop

A shorter introductory program using selected invention-development methods.

Purpose:

- introduce inventor thinking,
- introduce core methods,
- create an early project direction,
- act as an entry point into deeper FICI programs.

### 5.2 Professional Course

Primary invention-development curriculum.

Core progression includes:

- inventor mindset,
- SCAMPER,
- applied invention development,
- brainstorming,
- problem storming,
- evaluation and voting,
- affinity grouping,
- invention structure,
- mind mapping,
- patent literacy,
- patent search and comparative analysis,
- AI-assisted invention refinement.

Primary result:

**Invention Concept V2 + structured invention-development history and evidence.**

### 5.3 Advanced Course

Continues from the invention into founder and startup development.

Core progression includes:

- invention to product,
- PoC / prototype / MVP / validation,
- TRL and product roadmap,
- business feasibility,
- market research and customer validation,
- startup team and founder structure,
- leadership and conflict,
- Agile execution,
- go-to-market,
- startup finance,
- pitch deck,
- funding strategy.

### 5.4 Future Specialized Programs

The architecture must allow specialized programs such as:

- Patent / IP
- Product Development / MVP
- Agile for Startups
- Startup Finance
- Marketing
- Fundraising
- Pitching

These must reuse the same core platform rather than require separate products.

---

## 6. Core Product Model

The central product entity is:

# Development Project

Each Development Project should persist across sessions and potentially across programs.

A Development Project may contain the following development domains:

1. Invention
2. Evidence & IP
3. Product Development
4. Validation
5. Business & Market
6. Team & Execution
7. Finance
8. Pitch & Funding

The Development Project is the long-term source of truth for the user's project.

---

## 7. Workspace Model

The platform must support multiple workspace scopes.

### 7.1 Personal Workspace

Private by default.

Possible contents:

- notes,
- ideas,
- SCAMPER work,
- brainstorming,
- research,
- AI conversations,
- files,
- drafts,
- private maps,
- private analysis.

A user must be able to deliberately share selected outputs from Personal Workspace into a Team Workspace or with the Master.

### 7.2 Team Workspace

Private to the team unless shared.

Each team must have access to:

- team members,
- private team chat,
- shared files,
- team development tools,
- team project artifacts,
- team decisions,
- team AI activity where applicable,
- team version history,
- instructor/master feedback.

### 7.3 Master / Instructor Workspace

The Master should be able to:

- view assigned cohorts,
- see teams,
- see progress,
- enter relevant team spaces,
- review shared/submitted artifacts,
- comment,
- request revision,
- approve,
- manage team membership,
- publish case-study examples.

### 7.4 Shared / Cross-Team Workspace

Selected content may intentionally be shared with:

- another team,
- multiple teams,
- Master,
- Admin,
- Mentor,
- entire cohort.

Sharing must be permission-controlled.

---

## 8. Team Management Requirements

The platform must allow authorized users to:

- create a team,
- name a team,
- rename a team,
- archive a team,
- add members,
- remove members,
- move a member between teams,
- optionally allow membership in multiple teams,
- assign a team leader if needed,
- assign a mentor or coach,
- view team membership history.

The platform must preserve attribution when a member is removed from a team.

Removing a person must not delete their historical contributions.

---

## 9. Team Communication Requirements

Each team must have a private communication area.

### MVP Communication Requirements

- private team text chat,
- replies / threads,
- file sharing,
- links,
- images,
- mentions,
- pinned messages,
- timestamps,
- author attribution.

### Future Communication

Potential later additions:

- team voice room,
- team video room,
- live whiteboard communication,
- voice notes.

### Permission Principle

Team A must not see Team B's private chat.

Master/Admin access must be controlled by platform policy and role permissions.

---

## 10. Sharing Requirements

The platform must follow:

**Private by Default → Shared Intentionally → Ownership Retained**

A user or team should be able to share an artifact with:

- Team,
- Master,
- Admin,
- Mentor,
- selected user,
- another team,
- entire cohort.

Possible access levels:

- View
- Comment
- Collaborate / Edit

The UI may simplify these permissions, but the underlying permission model must support them.

Example user actions:

- Keep Private
- Share With Team
- Submit to Master
- Share With Another Team
- Share With Cohort

---

## 11. Cross-Team Sharing

Cross-team sharing is required.

For MVP, cross-team sharing should prioritize:

- snapshot sharing,
- view-only sharing,
- comment access.

Full multi-team co-editing may be deferred if it materially increases complexity.

The platform must preserve the original owner and source workspace of a shared artifact.

---

## 12. Tool Scope Requirements

Core creation tools should support both:

- Personal use
- Team use

Where appropriate, the same tool should also support controlled sharing.

Examples:

- SCAMPER
- Brainstorming
- Problem Storming
- Problem Bank
- Solution Bank
- Affinity Diagram
- Mind Mapping
- Voting
- Patent Research
- Evidence Collection
- AI Analysis
- Decisions
- Kanban / Backlog in later stages

The platform should not build duplicate software for "personal brainstorming" and "team brainstorming."

Instead, tools should work within a selected workspace scope.

---

## 13. Method & Activity Requirements

The platform should support reusable development behaviors rather than treating every technique as an unrelated feature.

Core activity families:

### Generate

- SCAMPER
- Brainstorming
- Problem Storming

### Organize

- Affinity Diagram
- clustering,
- categorization.

### Connect

- Mind Mapping
- Architecture Mapping
- Problem–Solution Mapping
- relationship mapping.

### Evaluate

- comparison,
- structured assessment,
- criteria review.

### Decide

- Dot Voting,
- Fist to Five,
- Planning Poker,
- team decision records,
- Go / Modify / Stop gates.

### Investigate

- patent research,
- technical research,
- market research.

### Validate

- assumptions,
- experiments,
- testing,
- prototype validation,
- customer validation.

### Plan

- roadmap,
- backlog,
- Kanban,
- milestones,
- development priorities.

---

## 14. Core Development Objects

The platform must eventually represent important project information as structured objects rather than only files.

Examples:

- Problem
- Idea
- Solution
- Feature
- Function
- Component
- System
- Subsystem
- Relationship
- Requirement
- Assumption
- Constraint
- Risk
- Gap
- Open Question
- Patent
- Evidence
- Claim
- Search Record
- Test
- Experiment
- Result
- Customer Insight
- Task
- Decision
- Version
- Feedback Item
- AI Suggestion

These objects should be linkable.

Example traceability:

**Problem → Solution → Function → Component → Requirement → Risk → Validation Question → Test → Evidence → Decision**

---

## 15. Traceability Requirements

Important project changes must be traceable.

The platform should be able to answer questions such as:

- Why was this feature added?
- Who proposed this change?
- Was it AI-generated or human-generated?
- What evidence supported it?
- What team decision approved it?
- Which instructor feedback caused revision?
- Which earlier version did it replace?

Conceptually:

**Conclusion → Analysis → Evidence → Original Source**

The platform must preserve the reasoning behind important project changes.

---

## 16. Versioning Requirements

New work must never silently overwrite development history.

Important artifacts must support states such as:

- Draft
- Candidate
- Under Review
- Revision Requested
- Approved
- Current
- Superseded
- Archived
- Unverified
- Verified

Versioning must be artifact-specific.

The platform must not assume one global version number for the entire invention or project.

Examples:

- Developed Concept V2
- Invention Structure V1
- Invention Mind Map V1
- Invention Concept V1
- Invention Concept V2

Each artifact type maintains its own version history.

---

## 17. Contribution Attribution

Every meaningful artifact or object should retain:

- creator,
- creation timestamp,
- source workspace,
- current owner,
- shared destinations,
- last editor,
- relevant version,
- origin type where applicable.

Origin types may include:

- User
- Team
- Master / Instructor
- Mentor
- AI
- Source Evidence
- Imported Data

When an individual contribution is accepted into a team project, the original creator must remain identifiable.

---

## 18. Instructor Case Study Requirements

The platform should support an Instructor Case Study project that uses the same development system as student projects.

The instructor should be able to demonstrate a method using the Case Study and then allow users to apply the same method to their own project.

The Case Study should be able to continue across multiple sessions and potentially across multiple programs.

---

## 19. Live Learning Requirements

The platform is intended to become a live online learning environment.

Core long-term requirements may include:

- live video,
- live audio,
- instructor camera,
- student cameras,
- microphone controls,
- screen sharing,
- presentation sharing,
- chat,
- raise hand,
- participant management,
- breakout/team rooms,
- polls,
- voting,
- shared whiteboard,
- collaborative exercises,
- attendance,
- session recording where appropriate,
- notifications,
- reactions.

The live classroom should be connected to the current educational activity.

The platform should know whether users are currently:

- brainstorming,
- voting,
- building an affinity diagram,
- working on a mind map,
- reviewing patents,
- running a validation exercise,
- or completing another structured activity.

Not every generic conferencing capability must be custom-built.

Build vs Integrate decisions will be made in the Technical Architecture document.

---

## 20. Guided Weekly Development

The platform must support work between live sessions.

Students may submit or update:

- exercises,
- maps,
- diagrams,
- research,
- questions,
- evidence,
- project versions,
- patent analyses,
- validation results,
- team decisions.

The instructor must be able to:

- review,
- comment,
- annotate,
- correct,
- request revision,
- approve.

Corrected outputs may become required inputs to later activities.

---

## 21. AI Requirements

AI must be context-aware and activity-aware.

The AI should potentially understand:

- current program,
- current session,
- current activity,
- current workspace,
- current project,
- current approved baseline,
- relevant prior artifacts,
- instructor feedback,
- team decisions,
- evidence,
- patents,
- gaps,
- current task.

AI roles may change by activity.

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
- Project Planning Assistant
- Startup Finance Analyst
- Pitch Review Assistant
- Funding Strategy Assistant

---

## 22. AI Governance

The governing philosophy is:

**AI Generates → Human Evaluates → Evidence Verifies → Team Decides**

AI output must be distinguishable from evidence.

Required labels should include concepts such as:

- Source Evidence
- Team Decision
- Instructor Feedback
- AI Analysis
- AI Suggestion
- Unverified
- Verified

AI-generated features or conclusions must not automatically become approved project content.

AI should not silently approve:

- novelty,
- patentability,
- market validity,
- technical feasibility,
- financial assumptions,
- or business decisions.

---

## 23. Evidence Requirements

The platform must support structured evidence management.

Evidence may include:

- patent documents,
- patent claims,
- drawings,
- official standards,
- datasheets,
- scientific papers,
- calculations,
- measurements,
- test results,
- customer interviews,
- market research,
- verified secondary sources.

Evidence should be linkable to:

- decisions,
- risks,
- requirements,
- gaps,
- claims,
- tests,
- project changes.

---

## 24. Patent / IP Requirements

The platform should support patent-related workflows including:

- searchable invention elements,
- keyword families,
- search logs,
- relevant patent sets,
- evidence sheets,
- claim mapping,
- architecture mapping,
- problem–solution analysis,
- similarity / difference analysis,
- gap mapping,
- re-search after invention changes.

External patent sources may include:

- WIPO PATENTSCOPE,
- USPTO,
- Google Patents,
- other sources added later.

External patent results must remain evidence sources, not AI-generated conclusions.

---

## 25. Decision Requirements

Important project decisions should be explicit records.

A decision record should eventually be able to include:

- issue being decided,
- options considered,
- voting method if used,
- votes,
- concerns,
- reasoning,
- evidence,
- participants,
- final decision,
- date,
- related artifacts,
- related versions.

Voting must not automatically equal approval unless the workflow explicitly defines it that way.

---

## 26. Development Gates

The platform should support reusable stage gates.

Examples:

- Invention Readiness Gate
- Technical Development Gate
- Business Feasibility Gate
- Market Validation Gate
- Investment Readiness Gate

A gate evaluates project readiness rather than only lesson completion.

Possible gate outcomes:

- Go
- Modify
- Hold
- Stop
- Needs More Evidence

Exact gate behavior will be defined in later workflow specifications.

---

## 27. Progress Model

The platform must distinguish:

### Learning Progress

Examples:

- session completed,
- exercise submitted,
- course percentage.

### Development Progress / Readiness

Examples:

- invention structure ready,
- patent analysis incomplete,
- product validation pending,
- market evidence insufficient,
- team structure partially ready,
- finance not started.

Course completion must not automatically imply project readiness.

---

## 28. Feedback & Review Requirements

Instructor / mentor feedback should be attachable to:

- entire artifact,
- specific object,
- specific version,
- specific section / node where supported.

Possible review lifecycle:

**Submitted → Under Review → Feedback Added → Revision Requested → Resubmitted → Approved**

Feedback history must remain available.

---

## 29. File & Knowledge Management

The platform must support files associated with:

- users,
- teams,
- projects,
- artifacts,
- evidence,
- sessions,
- assignments.

Files must retain:

- uploader,
- timestamp,
- source context,
- permissions,
- relationship to relevant project objects.

Important structured information should not exist only inside uploaded files if the platform needs to reason over it later.

---

## 30. Notification Requirements

The platform should support notifications for events such as:

- added to team,
- removed from team,
- artifact shared,
- comment received,
- revision requested,
- approval granted,
- mention in chat,
- assignment due,
- instructor announcement,
- team decision pending.

Initial MVP may prioritize in-app notifications, with email notifications added selectively.

---

## 31. Privacy & Permission Principles

The platform must follow least-privilege and intentional-sharing principles.

Core rules:

1. Personal work is private by default.
2. Team work is private to the team by default.
3. Cross-team access requires deliberate sharing or authorized instructor action.
4. Historical attribution must remain intact.
5. Removing a member must not erase their contribution history.
6. AI context must respect workspace and permission boundaries.
7. A user should not receive AI context containing information they are not authorized to access.
8. Evidence and confidential invention information must be handled with strong privacy controls.

Detailed RBAC rules will be defined in `03_ROLES_PERMISSIONS.md`.

---

## 32. Ownership Principle

The long-term product must be owned by FICI.

The platform may use external infrastructure and APIs, but FICI should own:

- curriculum logic,
- Development Project model,
- activity workflows,
- project data model,
- team/workspace logic,
- permission rules,
- traceability,
- versioning,
- evidence relationships,
- AI context logic,
- decision workflows.

External infrastructure may be used for:

- video,
- storage,
- authentication,
- AI model APIs,
- notifications,
- other commodity infrastructure.

Provider selection will be addressed later.

---

## 33. Core Platform vs Program Modules

### Core Platform

Program-independent capabilities:

- users,
- roles,
- organizations,
- cohorts,
- teams,
- workspaces,
- permissions,
- live learning,
- chat,
- files,
- collaboration,
- Development Projects,
- structured artifacts,
- versioning,
- traceability,
- AI context,
- feedback,
- decisions,
- notifications,
- progress,
- development gates.

### Professional Course Module

Includes course-specific methods such as:

- SCAMPER,
- Brainstorming,
- Problem Storming,
- Problem Bank,
- Solution Bank,
- Dot Voting,
- Fist to Five,
- Planning Poker,
- Affinity Diagram,
- Invention Structure,
- Mind Map,
- Patent Reading Framework,
- Patent Search Map,
- Patent Evidence,
- Claim Mapping,
- Architecture Mapping,
- Gap Mapping,
- AI-Assisted Refinement.

### Advanced Course Module

Includes course-specific development workflows such as:

- Product Development Questions,
- Requirements,
- Assumptions,
- Constraints,
- Risk Mapping,
- PoC / Prototype / MVP planning,
- Validation,
- TRL,
- Product Roadmap,
- Business Feasibility,
- Market Research,
- Customer Validation,
- Team Development,
- Leadership / Conflict,
- Agile,
- Go-to-Market,
- Finance,
- Pitch,
- Funding Strategy.

### Future Specialized Modules

Must be addable without rebuilding the core platform.

---

## 34. MVP Product Philosophy

The MVP must validate the differentiating value of the platform.

It should not attempt to rebuild every feature of:

- Zoom,
- Miro,
- Jira,
- Slack,
- Google Drive,
- or full patent databases.

When practical, commodity capabilities may be integrated initially.

The MVP should prioritize the unique FICI value:

- persistent Development Project,
- personal/team workspace,
- team management,
- private team chat,
- curriculum-linked tools,
- structured project objects,
- instructor review,
- sharing,
- decisions,
- version history,
- context-aware AI,
- evidence separation.

Exact MVP scope will be defined in `07_MVP_SCOPE.md`.

---

## 35. Non-Goals for the First Release

Unless specifically approved later, the initial release should not attempt to provide:

- a full custom video-conferencing infrastructure built from scratch,
- a general-purpose project-management product competitive with Jira,
- a full Miro replacement,
- a complete patent-search database,
- automatic legal patentability opinions,
- autonomous AI project approval,
- complex enterprise organization administration,
- every future Advanced / Specialized workflow at launch.

---

## 36. Success Criteria

The product should be considered directionally successful when a user can:

1. Join a course.
2. Maintain a personal workspace.
3. Join or be assigned to a team.
4. Communicate privately with that team.
5. Use FICI development tools privately and collaboratively.
6. Intentionally share work with the team, Master, or another team.
7. Develop one project over multiple sessions.
8. Receive instructor feedback.
9. Revise work without losing history.
10. Use AI with relevant project context.
11. Distinguish AI suggestions from evidence and approved content.
12. Continue the same project into later FICI development stages.

---

## 37. Product Decisions Captured So Far

### Decision 001 — Persistent Project Model

**Decision:** The platform is centered on a persistent Development Project rather than isolated course assignments.

**Status:** Accepted direction.

### Decision 002 — Multi-Program Project Continuity

**Decision:** The same Development Project can continue from Workshop to Professional Course to Advanced Course and future specialized programs.

**Status:** Accepted direction.

### Decision 003 — Personal + Team Workspaces

**Decision:** Core tools should support both Personal and Team workspace scopes.

**Status:** Accepted requirement.

### Decision 004 — Private by Default

**Decision:** Personal content remains private until intentionally shared; team content remains private to the team unless intentionally shared or accessed by authorized instructional roles.

**Status:** Accepted requirement.

### Decision 005 — Team Administration

**Decision:** Authorized Master/Admin users can create teams, add/remove members, move members, and assign access.

**Status:** Accepted requirement.

### Decision 006 — Team Private Chat

**Decision:** Each team requires private communication separate from other teams.

**Status:** Accepted requirement.

### Decision 007 — Controlled Cross-Team Sharing

**Decision:** Users/teams can intentionally share selected content with other teams, Master, Admin, or Mentor while preserving ownership and permissions.

**Status:** Accepted requirement.

### Decision 008 — Human-Controlled AI

**Decision:** AI suggestions never become approved project content automatically.

**Status:** Accepted requirement.

---

## 38. Open Questions for Later Documents

The following are intentionally not finalized in this PRD:

- exact role-permission matrix,
- exact Master access to private team chat,
- whether students may belong to multiple teams simultaneously,
- exact cross-team editing behavior,
- detailed artifact schemas,
- exact Development Project object model,
- exact activity workflows,
- MVP cut line,
- AI provider / model selection,
- realtime collaboration provider,
- live video provider,
- database,
- authentication provider,
- hosting,
- technical stack,
- API design,
- database schema.

These will be addressed in later documents in the approved documentation sequence.

---

## 39. Documentation Sequence

This PRD is the first implementation document.

Subsequent source-of-truth documents:

1. `01_PRODUCT_REQUIREMENTS.md`
2. `02_PLATFORM_ARCHITECTURE.md`
3. `03_ROLES_PERMISSIONS.md`
4. `04_WORKSPACE_TEAM_COLLABORATION.md`
5. `05_DEVELOPMENT_PROJECT_MODEL.md`
6. `06_COURSE_ACTIVITY_WORKFLOWS.md`
7. `07_MVP_SCOPE.md`
8. `08_AI_ASSISTANT_SPEC.md`
9. `09_TECHNICAL_ARCHITECTURE.md`
10. `10_DATABASE_SCHEMA.md`
11. `11_API_CONTRACTS.md`
12. `12_ACCEPTANCE_TESTS.md`

---

## 40. Codex Implementation Rule

Codex must treat the approved documents in `/docs` as product source of truth.

Implementation rules:

1. Do not invent business rules that contradict approved documents.
2. Do not silently modify product behavior to make implementation easier.
3. If a requirement is ambiguous, flag it for clarification.
4. Preserve privacy and permission boundaries.
5. Do not merge AI output with verified evidence.
6. Do not overwrite project history.
7. Do not hard-code the product to a single course.
8. Prefer modular implementations that support future FICI programs.
9. Follow the MVP scope once it is approved.
10. Technical implementation must conform to the approved product architecture and permission model.

---

# End of Document

**Current Status:** Draft v0.1 — Ready for Ahmad/FICI review.  
**Next Document After Approval:** `02_PLATFORM_ARCHITECTURE.md`
