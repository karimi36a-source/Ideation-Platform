# FICI Invention Education & Development Platform
## MVP Scope & Release Definition

**Document:** `07_MVP_SCOPE.md`  
**Status:** Draft v0.1 — For Review  
**Depends on:** `01_PRODUCT_REQUIREMENTS.md`, `02_PLATFORM_ARCHITECTURE.md`, `03_ROLES_PERMISSIONS.md`, `04_WORKSPACE_TEAM_COLLABORATION.md`, `05_DEVELOPMENT_PROJECT_MODEL.md`, `06_COURSE_ACTIVITY_WORKFLOWS.md`  
**Purpose:** Define the first usable product release, separate essential capabilities from later features, and prevent the first build from becoming unnecessarily large.

---

# 1. MVP Goal

The first release must validate one central product idea:

> Can FICI run a real invention-development course in which participants learn, work individually and in teams, use structured invention tools, receive instructor guidance, use AI assistance, preserve evidence and versions, and carry one Development Project from one session to the next?

The MVP is **not** intended to reproduce every future FICI course feature.

The MVP must prove that the platform can support the core workflow:

```text
LEARN
↓
WORK INDIVIDUALLY
↓
SHARE TO TEAM
↓
COLLABORATE
↓
USE STRUCTURED METHOD TOOLS
↓
USE AI ASSISTANCE
↓
MAKE TEAM DECISIONS
↓
SUBMIT TO MASTER
↓
RECEIVE FEEDBACK
↓
REVISE
↓
APPROVE
↓
CARRY OUTPUT FORWARD
```

---

# 2. MVP Principles

The first release must prioritize:

1. Educational usefulness
2. Development Project continuity
3. Team collaboration
4. Instructor control
5. Structured outputs
6. Version history
7. Evidence traceability
8. Practical AI assistance
9. Low enough complexity to build and test quickly
10. Architecture that can expand later

The MVP should not attempt to solve every long-term platform requirement immediately.

---

# 3. Prioritization Categories

Every capability is classified as:

## MUST HAVE — MVP

Required to validate the core platform.

## SHOULD HAVE

High-value capability that should follow soon after MVP if time and budget allow.

## LATER

Important, but not required to validate the first product.

## OPTIONAL / EXPERIMENTAL

Useful ideas that should not influence first-release architecture unless needed.

---

# 4. MVP User Roles

## MUST HAVE

### Admin

Can:

- create/manage users,
- create/manage courses and cohorts,
- assign roles,
- manage teams,
- configure course access,
- manage platform-level settings.

### Master / Instructor

Can:

- manage a cohort,
- create and modify teams,
- add/remove team members,
- launch activities,
- review team and individual work,
- comment,
- request revision,
- approve outputs,
- view team progress,
- access submitted/shared artifacts,
- participate in team communication where permissions allow.

### Student / Team Member

Can:

- access assigned course/session,
- use Personal Workspace,
- join Team Workspace,
- use available tools,
- work individually,
- share work to team,
- collaborate,
- communicate privately with team members,
- share selected work with Master,
- receive feedback,
- revise work,
- view approved/current project outputs.

## LATER

- Guest Mentor
- Technical Expert
- IP Specialist
- Reviewer
- University / Organization Admin
- External Investor / Advisor

---

# 5. Core Platform Structure

## MUST HAVE

The MVP must include these logical areas:

### 1. Course Space

Contains:

- course,
- cohort,
- sessions,
- activities,
- learning materials,
- activity instructions.

### 2. Development Project

The persistent project that carries the invention through the course.

### 3. Personal Workspace

Private working area for each student.

### 4. Team Workspace

Private team environment.

### 5. Master Workspace

Instructor review and control area.

### 6. Activity Workspace

The actual structured tool used for each exercise.

---

# 6. Development Project

## MUST HAVE

Every invention-development workflow must belong to a persistent Development Project.

The project should retain:

- Project Name
- Project Members
- Current Stage
- Current Version
- Problems
- Ideas
- Solutions
- Features
- Functions
- Components
- Systems
- Requirements
- Risks
- Gaps
- Evidence
- Decisions
- AI Outputs
- Instructor Feedback
- Versions
- Activity Outputs
- Files / Links

The platform must not treat sessions as disconnected assignments.

---

# 7. Personal Workspace

## MUST HAVE

Each user needs a private Personal Workspace.

Capabilities:

- create private notes,
- create private method outputs,
- use selected tools individually,
- use AI privately,
- save drafts,
- choose what to share,
- share selected item(s) with Team,
- share selected item(s) directly with Master where permitted.

Private work must remain private until the student shares it.

---

# 8. Team Workspace

## MUST HAVE

Every team must have a separate private Team Workspace.

Capabilities:

- team membership,
- private team content,
- private team chat,
- team artifacts,
- team tool access,
- team files,
- team decisions,
- team activity history,
- shared project state.

Each team must be isolated from other teams by default.

---

# 9. Team Management

## MUST HAVE

Admin / Master must be able to:

- create team,
- rename team,
- add participant,
- remove participant,
- move participant between teams,
- assign a team leader if desired,
- view team membership.

Students must see their current team members.

## SHOULD HAVE

- invitation workflow,
- temporary team membership,
- team member role labels,
- member history.

---

# 10. Team Chat

## MUST HAVE

Each team must have private text chat.

Required:

- only current team members can access by default,
- Master/Admin may access according to course policy,
- messages persist,
- sender + timestamp stored,
- basic file/link sharing,
- chat linked to team.

## SHOULD HAVE

- message reply/thread,
- mentions,
- reactions,
- pinned messages,
- search.

## LATER

- internal voice chat,
- internal video call,
- voice messages,
- live transcription.

---

# 11. Cross-Team Sharing

## MUST HAVE

A team must be able to share a selected artifact with:

- Master / Instructor

## SHOULD HAVE

A team may share selected artifacts with another team when enabled by Master.

Required controls:

- Share
- View Only
- Copy as Reference
- Revoke Share

Default rule:

**Team content remains private unless explicitly shared.**

## LATER

- collaborative cross-team editing,
- public showcase gallery.

---

# 12. Structured Activity Engine

## MUST HAVE

The platform needs a reusable Activity model rather than hard-coded pages.

Each activity should define:

- Activity Name
- Session
- Instructions
- Workspace Type
- Required Inputs
- Output Type
- AI Role
- Review Requirement
- Completion Requirement
- Next Dependency

The Activity Engine must create Activity Instances for real users/teams.

This is required because FICI uses many methods but they should share one platform structure.

---

# 13. MVP Method Tools

The MVP should not implement every future tool.

The first release should include enough tools to validate the Professional Course workflow.

## MUST HAVE

### 1. Brainstorming / Idea Board

Supports:

- individual idea creation,
- team idea creation,
- no forced evaluation during generation,
- cards/items,
- author,
- category/tag,
- sharing.

### 2. SCAMPER Workspace

Supports the seven SCAMPER lenses:

- Substitute
- Combine
- Adapt
- Modify
- Put to Another Use
- Eliminate
- Reverse / Rearrange

Each SCAMPER item should save:

- original element,
- selected lens,
- proposed change,
- result,
- notes.

### 3. Problem / Solution Board

Supports:

- Problem Bank
- Solution Bank
- link solution to problem,
- status,
- author,
- source.

### 4. Dot Voting

Supports:

- configurable vote limit,
- individual voting,
- reveal results,
- ranking,
- record final team decision separately.

### 5. Affinity Board

Supports:

- cards,
- drag/group conceptually,
- named groups,
- relationship to existing problem/solution/feature objects.

### 6. Mind Map

Supports:

- node,
- parent-child relationship,
- editable labels,
- node type,
- links to project objects.

Minimum node types:

- System
- Subsystem
- Component
- Function
- Problem
- Solution
- Gap

### 7. Decision Record

Supports:

- decision,
- alternatives,
- reasoning,
- participants,
- date,
- linked evidence,
- linked activity.

### 8. Feedback / Review

Supports:

- comment,
- request revision,
- approve,
- status.

---

# 14. Voting Beyond Dot Voting

## SHOULD HAVE

### Fist to Five

Useful for support / concern checks.

### Planning Poker

Useful for complexity / effort estimation.

These are valuable but are not necessary for the first usable release if Dot Voting + Decision Record already validate group decision workflows.

---

# 15. Patent Search Workspace

## MUST HAVE — BASIC VERSION

The MVP must support patent research as part of the Development Project, but it does not need to build a proprietary patent search engine.

Required:

- Patent Record
- patent title
- patent number / publication number
- source
- URL
- abstract / notes
- relevance
- similarity
- difference
- linked problem
- linked solution
- linked feature
- evidence status
- user notes
- AI analysis field

Users may paste or save records from:

- PATENTSCOPE
- USPTO
- Google Patents
- other approved sources.

## SHOULD HAVE

- structured Claim Map
- Architecture Map
- Problem–Solution Map
- Similarity / Difference Matrix
- Patent Landscape Snapshot generator.

## LATER

- direct patent API integrations,
- automated patent retrieval,
- full patent ingestion,
- semantic patent search,
- automated patent clustering,
- continuous patent monitoring.

---

# 16. Evidence System

## MUST HAVE

Evidence must be clearly separated from:

- AI suggestions,
- team decisions,
- instructor feedback.

Each Evidence Record should include:

- title,
- evidence type,
- source,
- URL/file,
- date,
- notes,
- linked project objects,
- verification status.

Statuses:

- Unverified
- Verified

Source categories may include:

- Patent
- Research
- Test
- Calculation
- Customer Evidence
- Instructor Source
- Other

---

# 17. Versioning

## MUST HAVE

The MVP must never overwrite the development history.

Required object/version states:

- Draft
- Submitted
- Approved / Current
- Archived

At minimum, the system must preserve:

- previous version,
- current version,
- author,
- timestamp,
- reason for change.

For the Development Project:

```text
Concept V1
↓
Revision
↓
Concept V1.1
↓
Review
↓
Concept V2
```

must remain traceable.

---

# 18. Change Log

## MUST HAVE

Every major change to an approved project artifact should allow a Change Record.

Store:

- what changed,
- why,
- who changed it,
- source activity,
- related evidence,
- related decision,
- previous version,
- new version.

---

# 19. Instructor Review Workflow

## MUST HAVE

Artifacts can move through:

```text
Draft
↓
Submitted
↓
Under Review
↓
Approved
OR
Revision Requested
↓
Revised
↓
Resubmitted
```

Master must be able to:

- open submission,
- comment,
- approve,
- request revision,
- see prior versions,
- see linked evidence,
- see AI-generated content labels.

---

# 20. AI Assistant — MVP

## MUST HAVE

AI should be available inside relevant activities, not only as a generic global chatbot.

The AI context should be able to include:

- Current Course
- Current Session
- Current Activity
- Current Development Project
- Current Project Version
- selected previous outputs
- Team Decisions
- Instructor Feedback
- Evidence
- Patent Records
- current task.

## MVP AI Roles

At minimum:

### Ideation Assistant
For Brainstorming and SCAMPER.

### Structure Analyst
For Affinity and Mind Mapping.

### Patent Analysis Assistant
For organizing and comparing user-supplied patent information.

### Critical Reviewer
For project refinement.

## Required AI Rule

AI output must be labeled:

- AI Analysis
or
- AI Suggestion

AI output must never automatically become:

- verified evidence,
- team decision,
- approved project content.

Human action is required.

---

# 21. AI Output Actions

## MUST HAVE

Users should be able to:

- Accept as Draft
- Edit
- Save as Candidate
- Reject
- Link to Problem
- Link to Solution
- Link to Gap
- Share to Team

## SHOULD HAVE

- compare AI outputs,
- regenerate with structured prompts,
- ask AI to analyze selected objects,
- AI activity history.

---

# 22. Course & Session Management

## MUST HAVE

Admin / Master must be able to configure:

- Course
- Cohort
- Session
- Activity
- Activity order
- availability
- required inputs
- review requirement.

Students must see:

- current session,
- available activities,
- required work,
- status,
- approved outputs.

The first release does not require a sophisticated LMS.

---

# 23. Learning Content

## MUST HAVE

The platform should support attaching learning resources to a session/activity:

- text
- PDF
- video link
- external link
- downloadable reference

## LATER

- full content-authoring studio,
- SCORM,
- quizzes,
- certificates,
- adaptive learning.

---

# 24. Live Classroom

The long-term platform requires live learning, but rebuilding Zoom-like infrastructure is not required for MVP.

## MUST HAVE — MVP

- Session Join Link
- external live-class link or integrated provider entry
- session status
- attendance marker if practical
- chat/activity work remains inside FICI platform.

## SHOULD HAVE

- embedded video room using external infrastructure / SDK,
- screen sharing,
- participant controls,
- breakout-room linkage to Team Workspace.

## LATER

- proprietary full live-video system,
- recording management,
- reactions,
- raise hand,
- in-platform presentation broadcast,
- advanced moderation.

The MVP should validate FICI's invention workflow before investing heavily in live-video infrastructure.

---

# 25. Notifications

## SHOULD HAVE

Basic notifications for:

- assignment/activity opened,
- shared artifact,
- Master comment,
- revision requested,
- approval,
- team membership change.

## LATER

- notification preferences,
- email digest,
- push notifications,
- scheduled reminders.

---

# 26. File Management

## MUST HAVE

Users need to attach files to:

- Development Project
- Activity
- Evidence
- Patent Record
- Team Workspace
- Feedback

Required metadata:

- uploader,
- date,
- related object,
- filename,
- type.

## SHOULD HAVE

- folders,
- file versioning,
- preview.

---

# 27. Search

## SHOULD HAVE

Basic project search across:

- problems,
- ideas,
- solutions,
- features,
- evidence,
- patent records,
- decisions.

## LATER

- semantic search,
- AI knowledge retrieval across entire organization.

---

# 28. Progress Tracking

## MUST HAVE — SIMPLE VERSION

Master should see:

- teams,
- current session,
- current activity,
- submission status,
- approval status.

Student should see:

- completed,
- in progress,
- revision requested,
- approved.

## LATER

- analytics dashboards,
- learning analytics,
- team performance analytics,
- engagement analytics,
- predictive alerts.

---

# 29. Advanced Course Features in MVP

The architecture must allow the Advanced Course later, but the first MVP does not need every Advanced Course tool.

## MUST HAVE

The Development Project Model must already support:

- Requirement
- Risk
- Gap
- Evidence
- Test
- Decision
- Version

This prevents redesign later.

## SHOULD HAVE

Simple generic structured tables that can support:

- Requirement Map
- Risk Map
- Validation Plan
- TRL Development Map

## LATER

Advanced specialized tools for:

- Business Case
- Market Validation
- Startup Team Map
- Leadership Map
- Agile System
- GTM
- Finance
- Pitch
- Funding CRM.

---

# 30. Kanban / Agile

## SHOULD HAVE

A simple project board:

- To Do
- Doing
- Done

with:

- task,
- assignee,
- due date,
- priority,
- blocker.

This becomes more important for the Advanced Course.

## LATER

- Scrum sprint planning,
- velocity,
- burndown,
- WIP limits,
- advanced dependencies,
- recurring sprint analytics.

---

# 31. Security & Privacy — MVP Minimum

## MUST HAVE

- authenticated access,
- role-based permissions,
- private Personal Workspace,
- private Team Workspace,
- explicit sharing,
- access checks on every artifact,
- audit-friendly timestamps,
- no cross-team accidental access,
- secure file access.

The platform must treat invention content as confidential project information.

---

# 32. Audit Trail

## MUST HAVE

For major objects, retain:

- created by,
- created at,
- modified by,
- modified at,
- status,
- version.

For high-value actions:

- sharing,
- approval,
- team membership changes,
- decision changes.

---

# 33. Export

## SHOULD HAVE

Users should be able to export a structured project summary.

Initial export may include:

- Project Summary
- Problem
- Solution
- Features
- Functions
- Mind Map summary
- Evidence
- Patent Records
- Decisions
- Current Version
- Instructor Feedback.

## LATER

- polished invention report,
- patent-analysis report,
- Advanced Course startup package,
- pitch deck generation.

---

# 34. Features Explicitly Excluded from First MVP

The following should **not** delay MVP:

- proprietary video conferencing,
- native voice rooms,
- advanced breakout-room video,
- full social network,
- marketplace,
- investor marketplace,
- VC matching,
- full CRM,
- startup accounting,
- native pitch deck designer,
- complex certification engine,
- mobile native apps,
- advanced gamification,
- public community feed,
- automated patentability opinion,
- autonomous AI invention approval,
- automated legal conclusions,
- full enterprise multi-tenant university administration.

---

# 35. MVP Feature Matrix

| Capability | Priority |
|---|---|
| Authentication | MUST HAVE |
| Admin / Master / Student roles | MUST HAVE |
| Course / Cohort / Session structure | MUST HAVE |
| Development Project | MUST HAVE |
| Personal Workspace | MUST HAVE |
| Team Workspace | MUST HAVE |
| Create / add / remove / move team members | MUST HAVE |
| Private Team Chat | MUST HAVE |
| Share to Master | MUST HAVE |
| Cross-team selected sharing | SHOULD HAVE |
| Brainstorming Board | MUST HAVE |
| SCAMPER | MUST HAVE |
| Problem / Solution Board | MUST HAVE |
| Dot Voting | MUST HAVE |
| Affinity Board | MUST HAVE |
| Mind Map | MUST HAVE |
| Decision Record | MUST HAVE |
| Evidence Record | MUST HAVE |
| Patent Record / Search Log | MUST HAVE |
| Claim Map | SHOULD HAVE |
| Patent Comparison Matrix | SHOULD HAVE |
| AI Assistant by activity | MUST HAVE |
| AI output labels | MUST HAVE |
| Instructor Review | MUST HAVE |
| Revision workflow | MUST HAVE |
| Version history | MUST HAVE |
| Change Log | MUST HAVE |
| File attachments | MUST HAVE |
| Basic progress tracking | MUST HAVE |
| Live-class external/integrated join | MUST HAVE |
| Native live video | SHOULD HAVE / LATER |
| Notifications | SHOULD HAVE |
| Basic search | SHOULD HAVE |
| Export project summary | SHOULD HAVE |
| Kanban | SHOULD HAVE |
| Planning Poker | SHOULD HAVE |
| Fist to Five | SHOULD HAVE |
| Advanced Course specialized tools | LATER |
| Full patent API integration | LATER |
| Semantic patent search | LATER |
| Investor CRM | LATER |
| Native Pitch Deck Designer | LATER |

---

# 36. First Usable MVP Scenario

The MVP is successful if FICI can run this scenario:

```text
1. Admin creates Professional Course cohort.
2. Master adds 20 students.
3. Master creates 4 teams.
4. Students enter Personal Workspace.
5. Students perform SCAMPER individually.
6. Students share selected ideas to Team Workspace.
7. Team discusses in private chat.
8. Team uses Brainstorming / Problem–Solution tools.
9. Team uses Dot Voting.
10. Team records a final decision.
11. Team organizes content with Affinity Board.
12. Team creates a Mind Map.
13. Team saves Patent Records and Evidence.
14. Team uses AI to compare / analyze.
15. AI outputs remain clearly labeled.
16. Team submits output to Master.
17. Master comments and requests revision.
18. Team revises without losing previous version.
19. Master approves.
20. Approved output becomes input to next activity.
```

If this complete workflow works reliably, the core product has been validated.

---

# 37. MVP Release Boundary

## Release 1 — Core Collaboration & Project Foundation

Build:

- Auth
- Roles
- Course/Cohort
- Development Project
- Personal Workspace
- Team Workspace
- Team Management
- Team Chat
- Sharing
- Basic Files
- Basic Review
- Versioning foundation

## Release 2 — Invention Method Tools

Add:

- SCAMPER
- Brainstorming
- Problem/Solution
- Dot Voting
- Affinity
- Mind Mapping
- Decision Log

## Release 3 — Evidence, Patent & AI

Add:

- Evidence
- Patent Records
- Search Log
- AI contextual assistance
- AI labels
- linked analysis
- structured review

## Release 4 — Full Professional Course Pilot

Connect:

- sessions,
- activity dependencies,
- Master review,
- current/approved outputs,
- progress,
- pilot cohort.

This is still one MVP program, but development should be staged internally rather than attempted in one code drop.

---

# 38. MVP Acceptance Criteria

The MVP should not be considered ready until all of the following are true.

## Access & Permissions

- A student cannot see another team's private workspace.
- A user cannot see another student's private workspace.
- Master can manage assigned course teams.
- Sharing permissions work correctly.

## Project Continuity

- Output from one activity can be referenced by another.
- Current approved project version is clear.
- Earlier versions remain available.

## Collaboration

- Team members can communicate.
- Team artifacts are shared inside the team.
- Master can review submitted team work.

## Structured Tools

- Core tools save structured data.
- Outputs are linked to Development Project.

## AI

- AI receives relevant project/activity context.
- AI output is visibly identified.
- AI output cannot silently become approved content.

## Review

- Master can comment.
- Master can request revision.
- Student/team can revise.
- Master can approve.
- revision history remains.

## Evidence

- Evidence source can be recorded.
- Evidence verification status can be recorded.
- Decisions can link to evidence.

---

# 39. What We Are Intentionally Not Validating Yet

The MVP does not need to prove:

- large-scale video conferencing,
- university enterprise administration,
- hundreds of simultaneous cohorts,
- automated patent search quality,
- investor marketplace demand,
- complete Advanced Course automation,
- native mobile app demand.

Those belong to later validation phases.

---

# 40. MVP Product Decision

## Decision MVP-001

The MVP will validate the invention-development workflow, not attempt to reproduce a full LMS + Zoom + Miro + Slack + patent platform + startup platform simultaneously.

**Status:** Required.

## Decision MVP-002

Private Personal and Team Workspaces are core, not optional.

**Status:** Required.

## Decision MVP-003

Private Team Chat is part of MVP because team collaboration is central to the educational method.

**Status:** Required.

## Decision MVP-004

Team management — add/remove/move members — is part of MVP.

**Status:** Required.

## Decision MVP-005

Structured method tools are part of MVP because generic text boxes would not validate the FICI methodology.

**Status:** Required.

## Decision MVP-006

The MVP includes basic patent records and evidence management, but not a proprietary patent-search engine.

**Status:** Required.

## Decision MVP-007

AI is embedded inside workflows, but humans remain responsible for evidence, decisions, and approval.

**Status:** Required.

## Decision MVP-008

Live video is initially integrated rather than rebuilt from scratch.

**Status:** Recommended MVP approach.

## Decision MVP-009

Advanced Course data requirements influence the core model, but most Advanced Course specialized tools are deferred until the Professional Course workflow is validated.

**Status:** Required.

---

# 41. Development Priority Order for Codex

When implementation begins, Codex should follow this dependency order:

```text
1. Core Data Model
2. Authentication
3. Roles & Permissions
4. Course / Cohort Structure
5. Development Project
6. Personal Workspace
7. Team Workspace
8. Team Membership
9. Sharing
10. Team Chat
11. Activity Engine
12. Review / Approval
13. Versioning
14. Core Method Tools
15. Evidence
16. Patent Records
17. AI Context Layer
18. AI Actions
19. Progress Tracking
20. Export / Pilot Improvements
```

Do not begin with visual polish.

Do not begin with AI.

Do not begin with video.

The platform foundation must exist first.

---

# 42. Required Next Document

The next document should be:

# `08_DATA_MODEL_SCHEMA.md`

It will convert the approved Development Project, course, workspace, team, activity, evidence, versioning, sharing, and AI requirements into a concrete implementation-oriented data model.

It should define:

- entities,
- fields,
- relationships,
- ownership,
- access scope,
- status enums,
- version relationships,
- activity relationships,
- evidence relationships,
- project relationships,
- team relationships,
- sharing relationships.

This still does **not** require UI design or application code.

---

# End of Document

**Current Status:** Draft v0.1 — Ready for Ahmad/FICI review.  
**Next Document After Approval:** `08_DATA_MODEL_SCHEMA.md`
