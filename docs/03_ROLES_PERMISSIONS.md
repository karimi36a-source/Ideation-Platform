# FICI Invention Education & Development Platform
## Roles & Permissions Specification

**Document:** 03_ROLES_PERMISSIONS.md  
**Status:** Draft v0.1 — For Review  
**Depends on:** `01_PRODUCT_REQUIREMENTS.md`, `02_PLATFORM_ARCHITECTURE.md`  
**Purpose:** Define the platform authorization model, role boundaries, workspace access, team management authority, sharing permissions, instructor oversight, and protection against cross-team or unauthorized data access.

---

# 1. Purpose

This document defines who can:

- see,
- create,
- edit,
- comment,
- share,
- approve,
- manage,
- review,
- export,
- and administer

content and functionality across the FICI platform.

This document is intentionally product-level.

It does not yet define:

- database row-level security syntax,
- API middleware,
- authentication provider,
- token structure,
- implementation framework,
- technical policy engine.

Those decisions will be addressed later in the Technical Architecture and Database/API documents.

---

# 2. Authorization Principles

The platform must follow the following principles.

## 2.1 Least Privilege

Users receive only the access required for their role and assigned scope.

---

## 2.2 Workspace Isolation

Personal, Team, Instructor, and Shared workspaces are separate permission scopes.

A user must not gain access to another workspace merely because they are enrolled in the same course.

---

## 2.3 Private by Default

Personal content is private by default.

Team content is private to team members by default.

Cross-team sharing requires explicit sharing or authorized instructor/admin action.

---

## 2.4 Role + Scope

Authorization depends on both:

- Role
- Scope

Example:

A Mentor may have permission to comment on artifacts in Team 2, but no access to Team 3.

---

## 2.5 Permission Inheritance Must Be Explicit

Permissions should not silently propagate across unrelated scopes.

Example:

Being Master of Cohort A must not automatically provide access to a private personal workspace unless platform policy explicitly grants it.

---

## 2.6 Historical Attribution Is Permanent

Removing a user from a team must not erase or transfer authorship of their previous contributions.

---

## 2.7 AI Must Follow the Same Permission Boundaries

The AI system must not receive, summarize, retrieve, or expose content the requesting user is not authorized to access.

---

## 2.8 Formal Approval Requires Explicit Authority

Viewing, commenting, voting, and editing do not automatically grant approval authority.

Approval rights must be role- and workflow-specific.

---

# 3. Initial Platform Roles

The initial platform should support the following roles:

1. Admin
2. Master / Instructor
3. Mentor / Coach
4. Student / User

Additional contextual roles may exist inside a team, such as:

- Team Lead

These contextual roles do not replace platform roles.

---

# 4. Admin Role

## 4.1 Purpose

Admin manages the overall platform or organization-level operational structure.

## 4.2 Typical Responsibilities

Admin may:

- manage organizations,
- manage programs,
- manage cohorts,
- manage users,
- assign platform roles,
- assign Masters,
- create or archive cohorts,
- manage course availability,
- manage team settings,
- inspect system-level activity where authorized,
- support access problems,
- manage policy-level settings,
- review platform reports.

## 4.3 Content Access Principle

Admin authority should not automatically mean unrestricted educational-content access in every situation.

There are two different admin needs:

### Operational Admin Access
Needed to manage accounts, memberships, and platform configuration.

### Content Oversight Access
Needed only where FICI policy explicitly permits content inspection.

The technical implementation should support separating these concepts.

## 4.4 Admin Team Management

Admin may:

- create teams,
- rename teams,
- archive teams,
- add members,
- remove members,
- move members,
- assign Team Lead,
- assign Master/Mentor where permitted.

## 4.5 Admin Approval Rights

Admin does not automatically act as the educational approver.

Educational approval should normally remain with Master / Instructor unless the workflow explicitly grants Admin approval authority.

---

# 5. Master / Instructor Role

## 5.1 Purpose

Master / Instructor is the primary educational leader, reviewer, and development supervisor.

## 5.2 Typical Responsibilities

Master may:

- run live sessions,
- manage assigned cohort teams,
- create teams,
- add/remove team members,
- move members between teams,
- inspect team project progress,
- review submitted artifacts,
- comment,
- annotate,
- request revisions,
- approve artifacts,
- launch structured activities,
- launch voting,
- publish case-study materials,
- monitor development gates,
- review AI-assisted work,
- review evidence,
- assign tasks or homework,
- intervene when teams are blocked.

## 5.3 Master Scope

Master permissions should be limited to:

- assigned programs,
- assigned cohorts,
- assigned teams,
- or explicitly granted projects.

A Master from Cohort A should not automatically access Cohort B.

## 5.4 Master Access to Personal Work

Default rule:

**Personal Workspace remains private unless the student explicitly shares or submits content.**

Master may access:

- submitted personal artifacts,
- content explicitly shared with Master,
- artifacts required by a course workflow,
- content made visible under an approved educational supervision policy.

Master should not automatically browse every private note, draft, or AI conversation in a student's Personal Workspace.

## 5.5 Master Access to Team Work

Master may access team-level educational work for teams under their instructional scope.

This can include:

- team artifacts,
- team decisions,
- team submissions,
- team project status,
- team files shared within the project,
- team AI outputs where relevant to the course.

## 5.6 Master Access to Team Chat

Recommended default:

**Master has read access to team chat for assigned teams only if the educational program policy enables instructor oversight.**

The platform should support configurable modes:

1. Master can always read assigned-team chat.
2. Master can enter team chat only when invited or when the team requests help.
3. Master can read but cannot post unless invited.
4. Master can read and post.

For FICI's instructor-led model, the recommended default is:

**Assigned Master: Read + Post access to team chat, with visible presence and no hidden monitoring.**

This preserves instructor coaching while avoiding invisible surveillance behavior.

## 5.7 Master Approval Rights

Master may approve:

- assignments,
- artifacts,
- revisions,
- development-stage outputs,
- selected gates,

where the curriculum defines instructor approval.

---

# 6. Mentor / Coach Role

## 6.1 Purpose

Mentor / Coach supports selected users, teams, or projects without full cohort authority.

## 6.2 Scope

Mentor access must always be explicitly assigned.

A Mentor may be assigned to:

- one project,
- one team,
- selected artifacts,
- selected course activities.

## 6.3 Default Permissions

Mentor may typically:

- view assigned project content,
- comment,
- provide coaching,
- join selected discussions,
- review evidence,
- suggest revisions.

Mentor should not automatically:

- add/remove team members,
- change team ownership,
- approve final artifacts,
- access unrelated teams,
- access private student work,
- alter permissions,
- delete project content.

## 6.4 Mentor Chat Access

Default:

Mentor may access team chat only if:

- assigned to that team,
- and chat access is explicitly enabled.

---

# 7. Student / User Role

## 7.1 Purpose

Student/User is the primary learner and project contributor.

## 7.2 Default Capabilities

Student may:

- access enrolled courses,
- access personal workspace,
- create private content,
- use personal tools,
- use personal AI,
- participate in assigned teams,
- access team tools,
- contribute to team artifacts,
- use team chat,
- share content,
- submit content,
- comment where allowed,
- vote,
- view feedback,
- revise work,
- inspect version history for content they are authorized to access.

## 7.3 Student Restrictions

Student may not automatically:

- create platform-wide roles,
- access another team's private content,
- access another student's private workspace,
- assign Admin/Master roles,
- approve final instructor-gated work,
- manage unrelated users.

---

# 8. Team Lead Contextual Role

## 8.1 Purpose

Team Lead is optional and applies within a specific team.

## 8.2 Possible Capabilities

Depending on configuration, Team Lead may:

- organize team work,
- create team activities,
- submit team artifacts,
- manage certain team files,
- invite discussion,
- coordinate deadlines.

## 8.3 Restricted Capabilities

By default, Team Lead should not be able to:

- remove members without Master/Admin approval,
- change role assignments,
- expose private teammate content,
- override instructor decisions,
- delete team history.

---

# 9. Role Hierarchy

The platform should not rely only on a simple hierarchy.

However, operationally:

```text
Admin
  └── Master / Instructor
       └── Mentor / Coach
            └── Student / User
```

This hierarchy describes broad authority only.

Actual access must still be controlled by scope.

Example:

A Mentor assigned to Team A may access Team A content.

A Master not assigned to Team A may have less access than that Mentor.

Therefore:

**Role hierarchy does not replace scope authorization.**

---

# 10. Permission Categories

The platform should support permission categories such as:

- View
- Create
- Edit
- Delete
- Comment
- Share
- Submit
- Approve
- Request Revision
- Manage Members
- Manage Permissions
- Export
- Launch Activity
- Manage Team
- Manage Course
- Manage Cohort
- View History
- Restore Version
- Use AI
- Use Evidence
- Access Chat

Not all permissions must be exposed individually in the UI.

---

# 11. Personal Workspace Permissions

## Owner

The workspace owner may:

- view,
- create,
- edit,
- delete own drafts,
- use tools,
- use AI,
- organize files,
- share selected content,
- submit selected content.

## Team Members

Default:

No access.

## Master

Default:

No access unless:

- content is shared,
- content is submitted,
- the course explicitly requires supervised visibility.

## Mentor

Default:

No access unless explicitly shared.

## Admin

Operational access does not automatically grant content access.

---

# 12. Team Workspace Permissions

## Team Members

Members may typically:

- view team artifacts,
- create team content,
- edit collaborative artifacts,
- comment,
- participate in voting,
- access team chat,
- upload files,
- use team tools.

Exact edit rules may vary by artifact.

## Team Lead

May receive additional coordination permissions.

## Master

For assigned teams:

- view,
- comment,
- review,
- request revision,
- approve where applicable,
- participate in chat according to configured policy.

## Mentor

For assigned teams:

- view,
- comment,
- coach,
- access chat if enabled.

## Other Teams

Default:

No access.

## Admin

Access according to organization policy.

---

# 13. Team Creation Permissions

Recommended default:

### Admin
Can create teams.

### Master
Can create teams within assigned cohort/program.

### Mentor
Cannot create teams unless specifically delegated.

### Student
Cannot create official course teams by default.

Future optional capability:

Students may create informal working groups, but these should not be confused with official course teams.

---

# 14. Add / Remove Team Member Permissions

Recommended default:

### Admin
Can add/remove users.

### Master
Can add/remove users within assigned teams/cohorts.

### Mentor
Cannot add/remove by default.

### Team Lead
Cannot remove users by default.

### Student
Cannot add/remove official team members by default.

## Important Historical Rule

Removing a member:

- removes future access,
- does not delete prior authored content,
- does not delete prior votes,
- does not erase attribution,
- does not rewrite history.

---

# 15. Moving Members Between Teams

Admin or assigned Master may move a user.

When moved:

- old team content stays intact,
- prior contributions remain attributed,
- future team access is revoked unless explicitly retained,
- new team access begins,
- sharing history remains visible,
- project ownership is not automatically transferred.

---

# 16. Multiple Team Membership

Product default recommendation:

**A user may belong to multiple teams only when explicitly allowed by the program.**

Examples where this may be useful:

- cross-disciplinary projects,
- mentoring,
- special exercises,
- multiple active projects.

For a standard course cohort, default should be:

**One primary team per project.**

This reduces confusion in permissions and project ownership.

---

# 17. Team Chat Permissions

## Team Members

May:

- read,
- post,
- reply,
- upload,
- mention,
- pin if allowed.

## Master

Recommended:

- read + post for assigned team chats,
- clearly identified as Master,
- no invisible or hidden presence.

## Mentor

Access only if assigned and enabled.

## Other Teams

No access.

## Removed Members

Lose future access to the chat.

Historical messages remain part of the record.

---

# 18. Chat Privacy Rule

Private team chat must never be visible to:

- unrelated teams,
- unrelated students,
- unrelated mentors,
- unrelated Masters.

Cross-team sharing must use explicit sharing mechanisms rather than exposing chat history.

---

# 19. Artifact Ownership

Every artifact should have:

- creator,
- current workspace,
- project,
- owner or owning team,
- contributors,
- visibility,
- permissions,
- status,
- version.

Ownership must not be inferred only from who last edited it.

---

# 20. Individual Contribution to Team

A user may create content privately and then share it with a team.

Recommended model:

```text
Personal Artifact
↓
Share to Team
↓
Team receives shared instance/reference
↓
Original creator remains recorded
```

The platform must preserve:

- original creator,
- share date,
- destination,
- resulting team use.

---

# 21. Team Artifact Sharing

A team may share an artifact with:

- Master,
- Mentor,
- Admin,
- specific person,
- another team,
- entire cohort.

Sharing permission levels:

- View
- Comment
- Edit / Collaborate

MVP recommendation:

Cross-team default should support:

- View
- Comment

Full cross-team co-editing may be deferred.

---

# 22. Share vs Transfer

Sharing does not change ownership.

Example:

Team A shares its Mind Map with Team B.

Team B can view/comment.

Team A remains owner.

Transfer of ownership should be a separate explicit administrative action.

---

# 23. Cross-Team Sharing Rules

When Team A shares with Team B:

Team B must not automatically receive:

- Team A chat,
- Team A private files,
- Team A unrelated artifacts,
- Team A internal AI history.

Only the selected shared object(s) become visible.

---

# 24. Cohort-Wide Sharing

Master may publish selected content to the whole cohort.

Examples:

- sample answer,
- instructor case study,
- approved team example,
- reference material.

A team's artifact should not become cohort-visible without:

- team authorization,
- Master policy authority,
- or explicit course rule.

---

# 25. Master Review Permissions

Master may review submitted work from assigned scope.

Master review capabilities may include:

- view,
- comment,
- annotate,
- request revision,
- approve,
- reopen.

Master should not silently edit a student/team artifact without leaving change history.

Preferred rule:

If Master edits directly, the change must show:

- editor = Master,
- timestamp,
- reason,
- version/change log.

---

# 26. Approval Permissions

Approval is a distinct permission.

Recommended defaults:

### Master
May approve instructional artifacts and project-stage outputs.

### Mentor
May recommend approval but cannot finalize unless explicitly delegated.

### Admin
May administratively override if necessary, but educational approval should remain with Master by policy.

### Student
Cannot approve instructor-gated outputs.

### Team
May make internal team decisions, but internal decision does not replace formal Master approval where required.

---

# 27. Revision Permissions

Master may request revision.

When revision is requested:

- current approved version remains preserved,
- new draft is created or reopened,
- feedback remains linked,
- resubmission creates updated review state.

---

# 28. Voting Permissions

Voting tools may define:

- who can participate,
- whether votes are private before reveal,
- whether results are visible immediately,
- whether voting is anonymous or attributed,
- who can launch,
- who can close,
- who can reopen.

Recommended defaults:

### Master
Can launch formal course voting.

### Team Lead
May launch internal team voting if enabled.

### Team Member
Can vote when invited.

### Other Teams
No access unless activity is cross-team.

---

# 29. Planning Poker Privacy

Planning Poker must support independent estimates before reveal.

Before reveal:

- participants cannot see other estimates.

At reveal:

- all authorized participants see results simultaneously.

This behavior is part of the educational workflow and must not be bypassed by broader team permissions.

---

# 30. AI Access Permissions

AI may operate only on content the requesting user is allowed to access.

## Personal AI

May use:

- user's personal artifacts,
- team artifacts visible to user,
- approved project evidence,
- course materials user can access.

Must not use:

- another student's private content,
- another team's private content,
- restricted instructor notes.

## Team AI

May use:

- team artifacts,
- team-approved context,
- team evidence,
- shared project data,
- course context.

Team AI output should normally be visible to authorized team members.

## Master AI

May use:

- instructional content,
- assigned team artifacts,
- shared/submitted work,
- authorized evidence.

---

# 31. AI Output Visibility

AI outputs inherit the workspace where they are created unless explicitly shared.

Examples:

Personal AI output → private.

Team AI output → visible to team.

Master AI output → instructor workspace unless shared.

---

# 32. AI Context Leakage Prevention

The system must prevent situations such as:

- Team A asks AI a question and receives Team B's private solution.
- Student A's private notes influence Student B's AI.
- A removed team member continues receiving team context through AI.

This is a mandatory security requirement.

---

# 33. Evidence Permissions

Evidence items should have:

- owner,
- source,
- workspace,
- linked project,
- visibility.

A patent document may be shared broadly.

A confidential test result may remain team-only.

Evidence visibility must not be assumed from evidence type.

---

# 34. File Permissions

File access follows its associated workspace and explicit shares.

Files may be:

- private,
- team-only,
- submitted to Master,
- shared with Mentor,
- shared across teams,
- cohort-visible.

A direct file URL must not bypass authorization rules.

---

# 35. Version History Permissions

Authorized users should be able to see version history for artifacts they can access.

Recommended defaults:

### Owner
Can view own version history.

### Team Member
Can view team artifact history.

### Master
Can view history of submitted/assigned team artifacts.

### Mentor
Can view history if assigned and allowed.

### Other Teams
Only shared version/snapshot unless broader access is explicitly granted.

---

# 36. Delete Permissions

Delete should be limited.

Important content should preferably use:

- archive,
- supersede,
- restore.

Permanent deletion should be restricted for:

- approved artifacts,
- evidence,
- decisions,
- instructor feedback,
- formal submissions,
- version history.

This reduces accidental loss of development history.

---

# 37. Archive Permissions

Recommended:

### Admin
May archive organization-level structures.

### Master
May archive teams/artifacts within assigned scope where allowed.

### Student
May archive own personal drafts.

Archive should not erase history.

---

# 38. Export Permissions

Export may be allowed for:

### Student
Own personal work and authorized team/project outputs.

### Team
Team-owned artifacts.

### Master
Assigned cohort/team outputs.

### Admin
Authorized administrative exports.

Export must respect confidentiality.

A user must not export content they cannot otherwise access.

---

# 39. Course Material Permissions

Course materials may be available according to:

- enrollment,
- program,
- session release,
- instructor publication,
- cohort schedule.

Access to course materials does not imply access to project content from other users.

---

# 40. Instructor Case Study Permissions

Instructor Case Study is normally:

- editable by Master,
- viewable by enrolled students when published,
- potentially commentable if activity allows,
- not editable by students unless explicitly used as a collaborative exercise.

---

# 41. Shared Content Snapshot Behavior

Recommended MVP behavior for cross-team sharing:

When an artifact is shared as Snapshot:

- recipient sees frozen version,
- source team may continue editing original,
- recipient does not automatically see later updates.

When shared as Live View:

- recipient sees current state,
- recipient cannot edit.

These are separate share types.

---

# 42. Permission Revocation

A share may be revoked.

Revocation should:

- block future access,
- not erase audit history,
- not erase comments already authored where retention is required,
- preserve record that access previously existed.

---

# 43. Temporary Access

The architecture should support temporary access for:

- guest mentor,
- expert reviewer,
- temporary instructor support.

Temporary access should have:

- start date,
- optional expiry,
- limited scope,
- explicit permissions.

---

# 44. Guest / Expert Role — Future

Not required for the initial role model, but architecture should support future roles such as:

- Technical Expert
- IP Specialist
- Reviewer
- University Administrator
- Guest Mentor

These should be implemented using scoped permissions rather than unrestricted new global roles wherever possible.

---

# 45. Permission Matrix — High-Level

| Capability | Admin | Master | Mentor | Student |
|---|---|---|---|---|
| Manage platform users | Yes | No | No | No |
| Manage assigned cohort | Yes | Yes | No | No |
| Create official team | Yes | Yes | No* | No |
| Add/remove team member | Yes | Yes | No* | No |
| Personal workspace | Own/admin policy | Own | Own | Own |
| View another user's private work | Policy only | Shared/submitted only | Shared only | No |
| Team workspace | Policy/assigned | Assigned teams | Assigned teams | Own teams |
| Team chat | Policy/assigned | Assigned teams | If enabled | Own teams |
| Cross-team private content | No by default | Only if shared/authorized | Only if shared | Only if shared |
| Comment on assigned artifact | Yes | Yes | Yes | If allowed |
| Request revision | Policy | Yes | Recommend/if delegated | No |
| Approve course artifact | Policy | Yes | If delegated | No |
| Use AI | Yes | Yes | Yes | Yes |
| View version history | Authorized scope | Assigned scope | Assigned scope | Own/authorized |
| Share content | Authorized scope | Authorized scope | Assigned scope | Own/authorized |
| Export | Authorized scope | Assigned scope | Assigned scope | Own/authorized |

\* Can be delegated later if required.

---

# 46. Permission Matrix — Personal Workspace

| Action | Owner | Team Member | Master | Mentor | Admin |
|---|---|---|---|---|---|
| View | Yes | No | No by default | No | Policy only |
| Edit | Yes | No | No | No | No by default |
| Comment | N/A/Yes | No | If shared | If shared | Policy |
| Share | Yes | No | No | No | Policy |
| Submit | Yes | No | Receives | Receives if assigned | Policy |
| Use in AI | Yes | No | Only if shared/authorized | If shared | Policy |

---

# 47. Permission Matrix — Team Workspace

| Action | Team Member | Team Lead | Master | Mentor | Other Team |
|---|---|---|---|---|---|
| View | Yes | Yes | Yes if assigned | If assigned | No |
| Create | Yes | Yes | Yes | If allowed | No |
| Edit collaborative artifact | Yes | Yes | Yes with trace | If allowed | No |
| Comment | Yes | Yes | Yes | Yes | If shared |
| Team chat | Yes | Yes | Yes per policy | If enabled | No |
| Launch internal activity | If allowed | Yes | Yes | If allowed | No |
| Submit to Master | If allowed | Yes | N/A | No | No |
| Manage members | No | No by default | Yes | No | No |
| Share externally | If allowed | Yes | Yes | If allowed | No |

---

# 48. Permission Matrix — Shared Artifact

| Share Level | Recipient Can View | Comment | Edit | Re-share |
|---|---:|---:|---:|---:|
| View | Yes | No | No | No |
| Comment | Yes | Yes | No | No |
| Collaborate | Yes | Yes | Yes | No by default |
| Owner/Admin | Yes | Yes | Yes | Yes |

Re-sharing should not be allowed by default.

---

# 49. Audit Requirements

The system should log sensitive permission events, including:

- team created,
- member added,
- member removed,
- member moved,
- role changed,
- share created,
- share revoked,
- approval granted,
- approval revoked,
- artifact deleted/archived,
- permission changed,
- temporary access granted.

Audit logs are especially important for:

- project ownership,
- educational disputes,
- confidential invention content,
- security review.

---

# 50. Notification Requirements for Permission Events

Users should be notified when:

- added to team,
- removed from team,
- moved to team,
- assigned Mentor,
- content shared with them,
- share revoked where relevant,
- revision requested,
- artifact approved,
- role changed.

---

# 51. Security-Critical Rules

The following rules are mandatory:

1. A student must not access another student's Personal Workspace without explicit sharing.
2. Team A must not access Team B's private workspace without explicit sharing.
3. Team A must not access Team B's private chat.
4. AI must not bypass workspace permissions.
5. Direct file access must not bypass permissions.
6. Removed team members must lose future team access.
7. Historical authorship must remain intact.
8. Approval must require explicit authority.
9. Cross-team sharing must expose only selected objects.
10. Permission changes must be auditable.

---

# 52. Product Decisions Captured

## Decision P-001 — Private Personal Workspace

Personal Workspace is private by default.

**Status:** Required.

---

## Decision P-002 — Team Workspace Isolation

Team work is visible only to team members and authorized instructional roles.

**Status:** Required.

---

## Decision P-003 — Instructor Oversight

Assigned Master may access educational work in assigned Team Workspaces.

**Status:** Required.

---

## Decision P-004 — Master Chat Access

Recommended default: Assigned Master may read and post in assigned team chats, with visible presence.

**Status:** Proposed for approval.

---

## Decision P-005 — No Hidden Instructor Chat Monitoring

Master access should not be hidden from the team.

**Status:** Recommended.

---

## Decision P-006 — Cross-Team Sharing Is Object-Specific

Sharing one artifact does not reveal the source team's entire workspace.

**Status:** Required.

---

## Decision P-007 — Cross-Team MVP Permissions

MVP should prioritize View and Comment sharing; full cross-team editing may be later.

**Status:** Recommended.

---

## Decision P-008 — Member Removal Preserves History

Removing a team member never deletes or reassigns their historical contribution.

**Status:** Required.

---

## Decision P-009 — Scope-Aware AI

AI context follows user permissions.

**Status:** Required.

---

## Decision P-010 — One Primary Team per Project by Default

Standard course configuration should use one primary team per project, while architecture can support multiple memberships later.

**Status:** Recommended.

---

# 53. Open Questions for Review

The following questions need Ahmad/FICI confirmation before final approval:

1. Should Master always have access to assigned-team chat, or only when invited?
2. Should Admin be able to read all team chats, or only for support/security reasons?
3. Can Team Lead share artifacts externally without Master approval?
4. Should students be allowed to create informal teams?
5. Can a student belong to more than one official team in the same course?
6. Can Master directly edit a team artifact, or only comment/request revision?
7. Should Mentors ever have approval authority?
8. Should team members be able to remove their own contributions after those contributions are accepted into the team project?
9. Should cross-team sharing allow live view in MVP, or snapshot only?
10. How long should team chats remain accessible after a course ends?

These should be resolved before the final permission model is locked.

---

# 54. Required Next Document

The next document is:

# `04_WORKSPACE_TEAM_COLLABORATION.md`

It should define in detail:

- Personal Workspace lifecycle,
- Team Workspace lifecycle,
- team creation,
- membership changes,
- private chat behavior,
- personal-to-team sharing,
- team-to-Master sharing,
- team-to-team sharing,
- collaboration states,
- activity participation,
- team tools,
- ownership and attribution,
- sharing history,
- workspace notifications,
- edge cases.

---

# 55. Codex Authorization Rule

Codex must never implement a feature that assumes:

- "logged in = authorized,"
- "same course = can see content,"
- "same cohort = can see team content,"
- "Admin = unrestricted content access,"
- "Master = can see all private student work,"
- "shared artifact = shared workspace,"
- "AI can read all project data."

If a permission is not explicitly allowed by the approved permission model, access must default to denied.

---

# End of Document

**Current Status:** Draft v0.1 — Ready for Ahmad/FICI review.  
**Next Document After Approval:** `04_WORKSPACE_TEAM_COLLABORATION.md`
