# FICI Invention Education & Development Platform
## Workspace & Team Collaboration Specification

**Document:** 04_WORKSPACE_TEAM_COLLABORATION.md  
**Status:** Draft v0.1 — For Review  
**Depends on:** `01_PRODUCT_REQUIREMENTS.md`, `02_PLATFORM_ARCHITECTURE.md`, `03_ROLES_PERMISSIONS.md`  
**Purpose:** Define how Personal, Team, Instructor, and Shared workspaces operate; how teams are created and managed; how private chat works; how users move work between scopes; and how collaboration, ownership, attribution, and cross-team sharing behave.

---

# 1. Purpose

This document defines the collaboration model of the FICI platform.

The platform must support:

- individual work,
- team work,
- instructor-guided work,
- private communication,
- structured sharing,
- cross-team collaboration,
- project continuity,
- contribution attribution,
- workspace-specific tools,
- permission-aware AI.

The goal is not to create separate software for individuals and teams.

The goal is to create one platform where the same tools can operate inside different workspace scopes.

---

# 2. Collaboration Principle

The core collaboration principle is:

# Private by Default → Share Intentionally → Collaborate in Scope → Preserve Ownership and History

Users must be able to think independently before exposing unfinished work to others.

Teams must be able to collaborate without exposing their private work to other teams.

Masters must be able to guide and review without erasing authorship or silently changing team history.

---

# 3. Workspace Types

The platform should support four primary workspace types:

1. Personal Workspace
2. Team Workspace
3. Instructor / Master Workspace
4. Shared Workspace

A Development Project may receive contributions from multiple workspaces.

---

# 4. Personal Workspace

## 4.1 Purpose

The Personal Workspace is the user's private development area.

It supports independent thinking before group influence.

## 4.2 Typical Content

A Personal Workspace may contain:

- private notes,
- ideas,
- personal SCAMPER outputs,
- personal brainstorming,
- research notes,
- private AI conversations,
- draft problem statements,
- draft solutions,
- draft mind maps,
- uploaded files,
- private questions,
- reflections,
- homework drafts,
- individual patent notes.

## 4.3 Default Visibility

Only the owner can view the Personal Workspace by default.

## 4.4 Personal Workspace Actions

The user should be able to:

- create,
- edit,
- organize,
- archive,
- use development tools,
- use AI,
- upload files,
- share selected content,
- submit selected content,
- move or promote selected work into a Team Workspace where permitted.

## 4.5 Important Rule

The user shares **selected artifacts or objects**, not the entire Personal Workspace.

---

# 5. Team Workspace

## 5.1 Purpose

The Team Workspace is the collaborative environment for an official project team.

## 5.2 Core Areas

A Team Workspace should conceptually contain:

- Team Overview
- Team Members
- Private Team Chat
- Shared Files
- Development Tools
- Team Artifacts
- Team Decisions
- Team Evidence
- Team AI
- Instructor Feedback
- Version History
- Activity History

## 5.3 Team Workspace Isolation

Team A must not see Team B's private workspace.

The only exceptions are:

- explicit artifact sharing,
- cohort-wide publication,
- authorized Master/Admin access under platform policy.

---

# 6. Instructor / Master Workspace

## 6.1 Purpose

The Master Workspace supports educational oversight across assigned teams.

## 6.2 Typical Capabilities

The Master should be able to:

- see assigned teams,
- view team progress,
- view submitted work,
- inspect team artifacts,
- review evidence,
- comment,
- annotate,
- request revision,
- approve,
- launch activities,
- open the instructor case study,
- compare team progress,
- enter assigned team discussions according to permissions.

## 6.3 Instructor Workspace Is Not a Team Workspace

Instructor notes, review queues, internal planning, and case-study work should remain separate from student team spaces unless intentionally shared.

---

# 7. Shared Workspace

## 7.1 Purpose

Shared Workspace represents intentionally shared material that crosses the normal Personal or Team boundary.

## 7.2 Possible Audiences

A shared item may be exposed to:

- Master,
- Mentor,
- Admin,
- selected person,
- another team,
- several teams,
- entire cohort.

## 7.3 Sharing Is Object-Specific

Sharing one artifact does not expose:

- the source chat,
- unrelated files,
- unrelated AI history,
- the rest of the source workspace.

---

# 8. Workspace Scope on Every Tool

Every major development tool should run inside a workspace scope.

Conceptually:

```text
Tool
↓
Workspace Scope
↓
Activity Instance
↓
Output
```

Example:

```text
Brainstorming
├── Personal Workspace
├── Team Workspace
└── Shared Activity
```

The same underlying tool is reused.

---

# 9. Workspace Selector

When relevant, a user should know where they are working.

Possible conceptual states:

- My Workspace
- Team 1 Workspace
- Team 2 Workspace
- Instructor Case Study
- Shared Activity

The product should make workspace context obvious enough to reduce accidental sharing.

---

# 10. Team Lifecycle

An official team should support the following lifecycle:

```text
Created
↓
Members Assigned
↓
Active
↓
Optional Membership Changes
↓
Course / Project Continues
↓
Completed
↓
Archived
```

Archiving must not erase project history.

---

# 11. Team Creation

## 11.1 Authorized Creators

Default:

- Admin
- Master within assigned scope

## 11.2 Required Team Fields

At minimum:

- Team Name
- Cohort
- Program / Course
- Project association
- Members
- Master / Instructor
- Status

Optional:

- Team Lead
- Mentor / Coach
- Description
- Team image/icon

---

# 12. Team Member Addition

When a user is added to a team:

1. Team membership is created.
2. User receives notification.
3. Team Workspace becomes available.
4. Team Chat becomes available.
5. Team tools become available.
6. Team project artifacts become visible according to permissions.
7. New member does not automatically gain access to restricted historical personal content.

---

# 13. Team Member Removal

When a user is removed:

1. Future team access is revoked.
2. Team chat access is revoked.
3. Team files are no longer accessible unless separately shared.
4. Team AI context is no longer available.
5. Historical contributions remain.
6. Votes remain.
7. Comments remain.
8. Authorship remains.
9. Audit history records removal.

Removing a member must never delete team history.

---

# 14. Moving a Member Between Teams

When a user moves from Team A to Team B:

## Team A

User loses future private access.

Prior contributions remain attributed.

## Team B

User receives access from the effective membership time onward.

## Important Rule

Moving teams must not silently copy Team A's private information into Team B.

---

# 15. Team Lead

Team Lead is optional.

Possible responsibilities:

- coordinate internal work,
- organize meetings,
- launch permitted team activities,
- submit team work,
- coordinate decisions,
- manage task assignments.

Team Lead should not automatically receive administrative power to:

- remove members,
- change platform roles,
- expose private teammate content,
- override Master decisions.

---

# 16. Mentor / Coach Assignment

A Mentor may be assigned to:

- a team,
- a project,
- selected activities.

Mentor access should be scoped.

The Team Workspace should visibly show assigned Mentors.

---

# 17. Team Private Chat

## 17.1 Purpose

Each team must have a dedicated private communication channel.

## 17.2 MVP Chat Capabilities

- text messages,
- replies / threads,
- mentions,
- links,
- image sharing,
- file sharing,
- timestamps,
- author identity,
- pinned messages,
- message search if practical.

## 17.3 Visibility

Default:

- team members,
- assigned Master according to approved policy,
- assigned Mentor if enabled.

Other teams cannot access the chat.

---

# 18. Master Presence in Team Chat

Recommended FICI model:

The assigned Master can read and post in assigned team chat.

Master identity must be visible.

The platform should not simulate hidden instructor surveillance.

The team should know when a Master is participating.

This policy remains subject to final approval in `03_ROLES_PERMISSIONS.md`.

---

# 19. Chat Is Communication, Not Project Source of Truth

Important decisions must not exist only inside chat.

If a discussion results in:

- selected solution,
- approved feature,
- project risk,
- change to invention,
- formal decision,

the result should be saved as a structured project object or Decision Record.

---

# 20. Personal-to-Team Sharing

A user should be able to share selected personal work to a Team Workspace.

Example:

```text
Private Idea
↓
Share With Team
↓
Team Idea Pool
```

The original must retain:

- creator,
- creation time,
- original workspace,
- share time,
- destination team.

---

# 21. Personal-to-Team Promotion Modes

The platform should support at least two conceptual modes:

## 21.1 Share Reference

The team receives access to the selected item while original ownership remains personal.

## 21.2 Promote to Team

A personal draft becomes an accepted team artifact while preserving original authorship.

The exact technical behavior will be defined later.

---

# 22. Team Acceptance of Personal Contribution

A team should not be forced to treat every shared idea as accepted project content.

Possible states:

- Shared
- Under Discussion
- Candidate
- Accepted
- Rejected
- Archived

This is particularly useful for:

- brainstorming,
- solution selection,
- features,
- invention changes.

---

# 23. Team-to-Master Sharing

A team should be able to:

- share for visibility,
- submit for review,
- request feedback,
- request approval.

These are not the same action.

Example:

```text
Share With Master
= visibility

Submit for Review
= formal review workflow
```

---

# 24. Team-to-Team Sharing

A team may intentionally share an artifact with another team.

Supported MVP modes should include:

### Snapshot

Recipient sees a frozen copy/version.

### View

Recipient sees the current source artifact but cannot modify.

### Comment

Recipient can view and add comments.

Full cross-team edit can be deferred.

---

# 25. Cross-Team Sharing Example

```text
Team A
└── Mind Map V2
    ↓ Share: Comment
Team B
└── Can view + comment
```

Team B cannot see:

- Team A chat,
- Team A files unrelated to the map,
- Team A private notes,
- Team A internal AI history.

---

# 26. Cohort Sharing

The Master may publish selected artifacts or examples to the whole cohort.

Examples:

- instructor sample,
- approved student example,
- reference map,
- case-study output.

The platform should preserve source attribution where appropriate.

---

# 27. Sharing Permission Levels

Recommended core levels:

## View

Recipient may read/view only.

## Comment

Recipient may view and comment.

## Collaborate

Recipient may edit the shared artifact.

## Owner

Full control inside the allowed scope.

For MVP cross-team sharing, prioritize:

- View
- Comment

---

# 28. Share Revocation

The owner or authorized role should be able to revoke a share.

Revocation should:

- remove future access,
- preserve audit history,
- preserve existing source history,
- not erase source content.

---

# 29. Share History

Important sharing events should be logged:

- who shared,
- what was shared,
- source workspace,
- destination,
- permission level,
- date/time,
- whether revoked.

This supports traceability and security.

---

# 30. Workspace Ownership

## Personal Workspace

Owned by the individual.

## Team Workspace

Owned operationally by the team/project scope.

## Instructor Workspace

Owned by the instructor role / organization context.

## Shared Workspace

Does not replace source ownership.

---

# 31. Artifact Ownership

An artifact should track:

- creator,
- owning workspace,
- project,
- contributors,
- current status,
- permissions,
- shares.

Example:

```text
Artifact: Problem Bank V1
Created by: Team 3
Workspace: Team 3
Project: Project A
Contributors: User A, User B, User C
Status: Approved
```

---

# 32. Contribution Attribution

Contribution history should remain visible where appropriate.

Examples:

- Idea created by User A
- Expanded by User B
- Combined by User C
- Accepted by Team
- Approved by Master

This is especially important for invention-development history.

---

# 33. Collaborative Editing

Some tools require realtime or near-realtime team editing.

Examples:

- brainstorming board,
- affinity diagram,
- mind map,
- shared problem/solution bank,
- Kanban.

The platform should support concurrent collaboration where educational value justifies it.

Exact technology is deferred.

---

# 34. Collaboration Presence

Future or MVP-ready collaboration may show:

- active users,
- cursor/presence,
- current editor,
- last activity.

Presence is useful but should not be treated as a requirement for every tool.

---

# 35. Conflict Handling in Collaborative Editing

The platform must avoid silent data loss when two users edit simultaneously.

The technical strategy will be defined later.

Product requirement:

Users should not overwrite each other's work without detection.

---

# 36. Tool Access by Workspace

Every tool may define which workspace types it supports.

Example:

| Tool | Personal | Team | Shared/Cross-Team |
|---|---:|---:|---:|
| SCAMPER | Yes | Yes | View/Comment |
| Brainstorming | Yes | Yes | Optional |
| Problem Storming | Yes | Yes | Optional |
| Problem Bank | Yes | Yes | Yes |
| Solution Bank | Yes | Yes | Yes |
| Dot Voting | No/Optional | Yes | Possible |
| Fist to Five | No | Yes | Possible |
| Planning Poker | No | Yes | Possible |
| Affinity Diagram | Yes | Yes | Yes |
| Mind Map | Yes | Yes | Yes |
| Patent Notes | Yes | Yes | Yes |
| Evidence | Yes | Yes | Yes |
| AI | Yes | Yes | Context-dependent |
| Kanban | Personal optional | Yes | View |

This matrix may be refined in later workflow documents.

---

# 37. Personal Brainstorming Workflow

Example:

```text
Student
↓
Personal Brainstorming
↓
Creates 12 Ideas
↓
Selects 5
↓
Shares 5 With Team
↓
Team Sees 5
```

The other 7 remain private.

---

# 38. Team Brainstorming Workflow

Example:

```text
Master Launches Activity
↓
Team Members Join
↓
Independent Idea Generation
↓
Reveal / Share
↓
Team Idea Pool
↓
Build / Combine
↓
Solution Candidates
```

This flow preserves independent thinking before group influence.

---

# 39. Brainwriting / Passing Group Workflow

The platform should eventually support:

```text
User A writes
↓
Pass to User B
↓
User B adds/modifies
↓
Pass to User C
↓
Developed direction
```

Each contribution should retain attribution.

---

# 40. Voting Collaboration

Voting activities should run within a defined group.

Possible groups:

- team,
- several teams,
- whole cohort.

The activity must define:

- eligible participants,
- number of votes,
- reveal behavior,
- result visibility,
- whether revoting is allowed.

---

# 41. Fist to Five Collaboration

All invited participants should submit support level independently.

Results should become visible according to activity configuration.

Low scores should be associated with optional concerns/comments.

---

# 42. Planning Poker Collaboration

Planning Poker must support:

- hidden individual estimates,
- simultaneous reveal,
- discussion,
- re-estimation,
- final record.

The platform should not average estimates automatically as the decision.

---

# 43. Affinity Collaboration

Team members should be able to:

- create cards,
- move cards,
- group cards,
- rename group headers,
- regroup,
- identify relationships.

The activity history should preserve major changes where practical.

---

# 44. Mind Map Collaboration

Team members should be able to:

- create nodes,
- create branches,
- create cross-links,
- edit labels,
- classify nodes,
- identify gaps,
- attach relevant project objects.

The Mind Map should eventually connect to structured project objects rather than remain only an image.

---

# 45. Evidence Collaboration

Team members may:

- add evidence,
- link evidence,
- comment on evidence,
- classify relevance,
- mark verification status where authorized.

Evidence should not be deleted simply because a team changes direction.

---

# 46. AI Collaboration

## Personal AI

Private to the user unless shared.

## Team AI

Visible to the team.

Possible use:

- analyze team artifact,
- compare options,
- identify gaps,
- summarize evidence,
- propose candidates.

## Important Rule

Team AI should use team-authorized context only.

---

# 47. Sharing AI Outputs

An AI output may be:

- kept private,
- shared with team,
- submitted to Master,
- linked to an artifact.

The platform must preserve:

- AI origin,
- user who requested it,
- context references,
- verification status.

---

# 48. Instructor Intervention

Master should be able to intervene through:

- comment,
- annotation,
- question,
- revision request,
- approval,
- activity launch,
- coaching message.

Direct instructor edits should always be traceable.

---

# 49. Submission Workflow

A user or team may submit an artifact.

Example:

```text
Draft
↓
Submit to Master
↓
Under Review
↓
Feedback
↓
Revision Requested
↓
Resubmit
↓
Approved
```

The source workspace remains the same unless workflow explicitly promotes the artifact.

---

# 50. Team Decision Workflow

Example:

```text
Options
↓
Discussion
↓
Voting / Evaluation
↓
Concerns
↓
Decision
↓
Decision Record
↓
Update Project
```

The Decision Record should link to the artifact or object that changed.

---

# 51. Master-to-Team Sharing

The Master may share:

- case-study artifacts,
- reference examples,
- feedback,
- templates,
- instructions,
- selected external resources.

A Master-shared resource should indicate whether it is:

- Reference
- Example
- Required Input
- Feedback
- Assignment

---

# 52. Workspace Notifications

Users should receive relevant notifications for:

- team membership,
- new share,
- comment,
- mention,
- review request,
- revision request,
- approval,
- activity start,
- vote request,
- team announcement.

Notifications should deep-link to the relevant workspace/item when implemented.

---

# 53. Workspace Activity History

Each workspace should maintain an activity history for meaningful events.

Examples:

- artifact created,
- artifact shared,
- member added,
- member removed,
- decision created,
- review completed,
- approval granted,
- share revoked.

This is not the same as chat.

---

# 54. Team Project vs Team Workspace

These concepts must remain distinct.

## Team Workspace

The collaboration environment.

## Development Project

The persistent project record.

A Team Workspace may contribute to one Development Project.

Future architecture may allow a team to work on multiple projects.

---

# 55. Personal Project vs Team Project

A Development Project may be:

- individual,
- team-owned,
- transitioned from individual to team.

The project should not require team collaboration if the educational program allows individual participation.

---

# 56. Transition from Individual to Team

A user may begin a project individually and later form a team.

The platform should support:

```text
Individual Project
↓
Team Created
↓
Selected Project Artifacts Shared/Promoted
↓
Team Project Continues
```

The original history must remain intact.

---

# 57. Transition from Team to Individual

If a user leaves a team:

- team-owned project data remains with the team,
- personal original content remains with the user,
- shared contributions remain historically attributed,
- access to team-private content ends.

Detailed IP/legal ownership policies may require separate organizational policy and are outside this product document.

---

# 58. Team Merge — Future

Future capability may allow two teams to merge.

If implemented, merge must preserve:

- source team histories,
- authorship,
- artifacts,
- decisions,
- version lineage.

Not required for initial MVP.

---

# 59. Team Split — Future

Future capability may allow one team to split.

This is complex and should be deferred unless required.

If implemented, source ownership and artifact duplication rules must be explicit.

---

# 60. Offline / Async Collaboration

The platform must support asynchronous collaboration.

Users should not need to be simultaneously online to:

- comment,
- edit where allowed,
- upload,
- review,
- share,
- submit,
- use AI,
- add evidence.

---

# 61. Live / Synchronous Collaboration

During live sessions, the same workspace tools should support synchronous group use.

The platform should avoid creating separate "live" and "homework" versions of the same artifact.

The artifact should continue across both contexts.

---

# 62. Breakout Team Rooms

In future live-class integration:

Each team should be able to enter a private breakout area tied to its Team Workspace.

The room may expose:

- chat,
- active activity,
- team artifact,
- files,
- Master help request.

The breakout room should not create a separate disconnected project space.

---

# 63. Ask Master for Help

Recommended collaboration feature:

A team should be able to request instructor attention.

Possible status:

- Help Requested
- Master Joined
- Resolved

This is particularly useful during live workshops.

---

# 64. Sharing Safety

Before sharing confidential project content outside the team, the platform should make destination and permission clear.

Example:

> Share "Mind Map V2" with Team 4 as View Only?

This reduces accidental disclosure.

---

# 65. Confidentiality Indicator

Future or MVP-friendly visual concept:

Artifacts may display scope labels such as:

- Private
- Team
- Shared with Master
- Shared with Team 4
- Cohort

Exact UI is deferred, but the underlying state is required.

---

# 66. Collaboration Audit Requirements

The system should preserve records for:

- share actions,
- permission changes,
- membership changes,
- formal submissions,
- approvals,
- revocations,
- ownership changes.

These logs are not intended as a surveillance feed but as system integrity records.

---

# 67. Collaboration MVP Requirements

The first release should strongly prioritize:

1. Personal Workspace
2. Team Workspace
3. Team creation
4. Add/remove team members
5. Team private chat
6. Shared team files
7. Personal tool use
8. Team tool use
9. Personal-to-team sharing
10. Team-to-Master sharing
11. Master review/comment
12. Cross-team View/Comment sharing
13. Contribution attribution
14. Workspace notifications
15. Activity / share history
16. Permission-aware AI context

---

# 68. Collaboration Features That Can Be Later

Potential later features:

- cross-team co-editing,
- voice rooms,
- video rooms,
- advanced presence,
- cursor tracking,
- informal student-created groups,
- team merge,
- team split,
- temporary external expert rooms,
- advanced chat moderation,
- advanced chat search,
- federated organization collaboration.

---

# 69. Product Decisions Captured

## Decision C-001 — Workspaces Are First-Class

Personal and Team Workspaces are core architectural entities.

**Status:** Required.

---

## Decision C-002 — Same Tools, Different Scope

The same development tools should work in Personal and Team contexts.

**Status:** Required.

---

## Decision C-003 — Private Team Chat

Each team receives a private chat inaccessible to other teams.

**Status:** Required.

---

## Decision C-004 — Selected Sharing

Users share selected artifacts, not entire workspaces.

**Status:** Required.

---

## Decision C-005 — Ownership Retained

Sharing never silently changes original ownership or authorship.

**Status:** Required.

---

## Decision C-006 — Cross-Team MVP

Cross-team sharing should initially support Snapshot/View/Comment rather than full shared editing.

**Status:** Recommended.

---

## Decision C-007 — Personal Thinking Before Group Influence

The platform should support private ideation before team reveal where the curriculum requires it.

**Status:** Required by methodology.

---

## Decision C-008 — Chat Is Not Formal Decision Storage

Formal project decisions must be saved structurally.

**Status:** Required.

---

## Decision C-009 — Individual and Team Projects Supported

The Development Project architecture should support both individual and team development.

**Status:** Recommended.

---

## Decision C-010 — Live and Async Use Same Artifacts

Live sessions and between-session work should continue in the same artifacts rather than duplicate them.

**Status:** Required.

---

# 70. Open Questions for Review

The following remain intentionally open:

1. Should the Master always have read/post access to team chat?
2. Should Admin ever have routine team-chat visibility?
3. Should students be allowed to create unofficial teams?
4. Should Team Lead be able to invite members with Master approval?
5. Should Team Lead be allowed to share team artifacts with other teams?
6. Should personal artifacts shared to a team remain editable from the personal copy?
7. When promoting a personal artifact to team ownership, should a copy remain in Personal Workspace?
8. Should cross-team sharing in MVP include Live View or only Snapshot?
9. Should team members be able to delete their own chat messages?
10. Should team members be able to delete an idea after the team has accepted it?
11. Should team chat remain accessible after the course finishes?
12. Should archived team spaces remain read-only indefinitely?
13. Should Team AI conversations be visible to Master by default?
14. Should Master be able to launch an activity inside a Team Workspace without entering team chat?

These should be resolved before final implementation rules are locked.

---

# 71. Required Next Document

The next document is:

# `05_DEVELOPMENT_PROJECT_MODEL.md`

It must define the structured project model in detail, including:

- Development Project,
- development domains,
- Problem,
- Idea,
- Solution,
- Feature,
- Function,
- Component,
- System,
- Subsystem,
- Requirement,
- Assumption,
- Constraint,
- Risk,
- Gap,
- Open Question,
- Evidence,
- Patent,
- Search Record,
- Test,
- Experiment,
- Customer Insight,
- Task,
- Decision,
- Artifact,
- Version,
- Feedback,
- AI Suggestion,
- relationships and traceability.

---

# 72. Codex Collaboration Rule

Codex must implement collaboration with explicit workspace boundaries.

Codex must not:

- use one global shared content space for all students,
- expose team chat across teams,
- automatically publish personal drafts,
- assume sharing means ownership transfer,
- erase authorship after team promotion,
- copy entire source workspaces during sharing,
- allow AI to read outside the active user's authorized workspace scope,
- store formal decisions only in chat,
- destroy historical contributions when removing a member,
- create duplicate live/homework artifacts when the same artifact should continue across contexts.

If a collaboration behavior is ambiguous, implementation must stop and request clarification rather than inventing a permission rule.

---

# End of Document

**Current Status:** Draft v0.1 — Ready for Ahmad/FICI review.  
**Next Document After Approval:** `05_DEVELOPMENT_PROJECT_MODEL.md`
