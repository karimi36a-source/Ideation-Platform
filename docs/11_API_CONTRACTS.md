# FICI Invention Education & Development Platform
## API Contracts & Business Operations Specification

**Document:** `11_API_CONTRACTS.md`  
**Status:** Draft v0.1 — For Review  
**Depends on:** `01_PRODUCT_REQUIREMENTS.md` through `10_TECHNICAL_ARCHITECTURE.md`  
**Purpose:** Define the business operations, command contracts, authorization expectations, validation rules, side effects, and error behavior that Codex should implement before UI wiring.

---

# 1. API Contract Principle

The API layer represents **business operations**, not generic table access.

The implementation should prefer explicit operations such as:

```text
createTeam()
addTeamMember()
shareArtifact()
submitArtifact()
approveArtifact()
runAiTask()
recordDecision()
```

rather than allowing the client to directly mutate arbitrary database rows.

Critical operations must:

1. authenticate the user,
2. resolve authorization,
3. validate input,
4. enforce business rules,
5. perform transactional changes,
6. create audit records where required,
7. return a predictable typed result.

---

# 2. Contract Categories

The MVP requires contracts for:

1. Authentication & Session
2. User / Role Administration
3. Program / Cohort / Enrollment
4. Team Management
5. Workspace Access
6. Development Project
7. Activity Engine
8. Structured Project Objects
9. Artifacts & Versions
10. Sharing
11. Team Chat
12. Voting
13. Decisions
14. Evidence
15. Patent Records
16. Files
17. Review & Approval
18. AI Tasks
19. Development Gates
20. Notifications
21. Audit & History

---

# 3. Common Request Context

Every authenticated operation should resolve a server-side context similar to:

```ts
type RequestContext = {
  userId: string;
  organizationId?: string;
  activeCohortId?: string;
  activeWorkspaceId?: string;
  activeProjectId?: string;
};
```

The server must derive trusted identity from the authenticated session.

The client must never be trusted to declare:

```text
"I am Admin"
"I am Master"
"I belong to Team X"
```

without server verification.

---

# 4. Standard API Result

Recommended internal contract:

```ts
type ApiSuccess<T> = {
  ok: true;
  data: T;
};

type ApiError = {
  ok: false;
  error: {
    code: string;
    message: string;
    field?: string;
    details?: Record<string, unknown>;
  };
};

type ApiResult<T> = ApiSuccess<T> | ApiError;
```

User-facing messages may be simplified, but error codes should remain stable for application logic and tests.

---

# 5. Common Error Codes

Recommended initial error codes:

```text
AUTH_REQUIRED
FORBIDDEN
NOT_FOUND
VALIDATION_ERROR
CONFLICT
ALREADY_EXISTS
INVALID_STATE
DEPENDENCY_NOT_MET
RESOURCE_ARCHIVED
RATE_LIMITED
AI_UNAVAILABLE
EXTERNAL_PROVIDER_ERROR
FILE_TOO_LARGE
UNSUPPORTED_FILE_TYPE
VERSION_CONFLICT
REVIEW_REQUIRED
APPROVAL_REQUIRED
```

Permission errors should not reveal sensitive inaccessible resource details.

---

# 6. Idempotency

Critical operations that may be retried should support idempotency where practical.

Examples:

- invitations,
- webhook processing,
- artifact approval,
- AI candidate promotion,
- file registration,
- share creation.

For external-facing or retry-prone operations, allow:

```text
idempotencyKey
```

where justified.

---

# 7. Authentication Contracts

## `getCurrentUser()`

### Purpose

Return the authenticated platform profile and authorized role scopes.

### Returns

- user profile,
- organization memberships,
- cohort enrollments,
- role assignments,
- team memberships,
- active project memberships.

### Authorization

Authenticated user only.

---

## `updateOwnProfile(input)`

### Input

- display name,
- profile image reference,
- timezone,
- locale.

### Authorization

User may update only their own profile.

---

# 8. User Administration

## `inviteUser(input)`

### Input

```text
email
displayName optional
role
organizationId
cohortId optional
```

### Authorized Roles

- Admin
- Master only within permitted cohort if policy allows student invitations.

### Side Effects

- create/invite user,
- create role/enrollment where requested,
- send invitation email,
- create audit event.

---

## `assignRole(input)`

### Input

```text
userId
roleCode
scopeType
scopeId
```

### Authorized Roles

Admin by default.

### Rules

- role must be valid,
- scope must exist,
- assignment must not create unauthorized escalation.

### Audit

Required.

---

## `removeRoleAssignment(roleAssignmentId)`

Admin only unless a narrower delegated rule is approved.

Audit required.

---

# 9. Program & Cohort Contracts

## `createCohort(input)`

### Input

```text
programId
curriculumVersionId
name
startDate
endDate optional
primaryMasterId
```

### Authorization

Admin.

### Output

Created cohort.

---

## `updateCohort(input)`

Admin or appropriately scoped Master for limited fields.

---

## `enrollUser(input)`

### Input

```text
cohortId
userId
enrollmentRole
```

### Authorization

Admin / assigned Master according to policy.

### Rules

Must not duplicate active enrollment.

---

## `removeEnrollment(input)`

Must preserve historic work.

Removal affects future access, not authored history.

Audit required.

---

# 10. Team Contracts

## `createTeam(input)`

### Input

```text
cohortId
name
description optional
projectId optional
teamLeadUserId optional
```

### Authorized Roles

- Admin
- Master assigned to cohort

### Transaction

1. create Team,
2. create Team Workspace,
3. create Team Chat Channel,
4. assign Master scope,
5. optionally link Development Project,
6. create audit event.

### Output

Team + Workspace + Chat identifiers.

---

## `renameTeam(input)`

### Input

```text
teamId
name
```

### Authorization

Admin / assigned Master.

---

## `addTeamMember(input)`

### Input

```text
teamId
userId
membershipRole = member | team_lead | mentor
```

### Authorization

Admin / assigned Master.

### Rules

- user must be eligible for team/cohort,
- duplicate active membership forbidden,
- program rule may prevent multiple primary teams.

### Side Effects

- membership record,
- chat membership,
- notification,
- audit event.

---

## `removeTeamMember(input)`

### Input

```text
teamId
userId
reason optional
```

### Authorization

Admin / assigned Master.

### Required Behavior

- close membership,
- revoke future Team Workspace access,
- revoke future Team Chat access,
- preserve authored artifacts/messages/votes,
- preserve historical attribution,
- create notification,
- create audit event.

---

## `moveTeamMember(input)`

### Input

```text
userId
fromTeamId
toTeamId
reason optional
```

### Authorization

Admin / assigned Master.

### Transaction

1. close old membership,
2. create new membership,
3. update chat memberships,
4. preserve old contribution history,
5. notify user,
6. audit.

---

## `assignTeamLead(input)`

Must not automatically grant member-management rights unless permission policy explicitly says so.

---

## `archiveTeam(teamId)`

### Authorization

Admin / assigned Master.

### Rules

Archiving must:

- preserve all history,
- make workspace read-only where appropriate,
- prevent new ordinary activity unless restored.

---

# 11. Workspace Contracts

## `getWorkspace(workspaceId)`

Returns workspace metadata only if user has access.

---

## `listMyWorkspaces()`

Returns accessible:

- Personal Workspace,
- Team Workspaces,
- Shared Workspaces,
- Master Workspace where relevant.

---

## `createPersonalWorkspace()`

Usually system-created automatically.

Should be idempotent per user.

---

## `getWorkspaceAccess(workspaceId)`

Returns resolved capabilities such as:

```text
canView
canCreate
canEdit
canComment
canShare
canReview
canApprove
canManageMembers
canAccessChat
```

Useful for UI rendering, but backend enforcement remains authoritative.

---

# 12. Development Project Contracts

## `createDevelopmentProject(input)`

### Input

```text
name
description optional
projectType = individual | team | instructor_case_study
ownerUserId optional
ownerTeamId optional
primaryWorkspaceId
```

### Authorization

Authorized user in relevant scope.

### Output

Development Project.

---

## `updateProjectMetadata(input)`

Editable fields may include:

- name,
- description,
- status,
- current stage.

Sensitive ownership changes require separate operations.

---

## `linkProjectToProgram(input)`

### Input

```text
projectId
programId
cohortId
entryArtifactVersionId optional
```

Allows project continuity across programs.

---

## `archiveProject(projectId)`

Must preserve:

- versions,
- evidence,
- decisions,
- memberships,
- audit history.

---

# 13. Project Object Contracts

## `createDevelopmentObject(input)`

### Input

```text
projectId
workspaceId
objectType
title
content
originType
metadata optional
```

### Authorization

User must be able to create in workspace/project.

### Output

New Draft object.

---

## `updateDevelopmentObject(input)`

### Rules

- user must have edit rights,
- approved history must not be silently destroyed,
- if change affects approved content, create version/change record where required.

---

## `archiveDevelopmentObject(objectId)`

Preferred over destructive delete for important project content.

---

## `relateDevelopmentObjects(input)`

### Input

```text
sourceObjectId
targetObjectId
relationshipType
description optional
```

### Rules

Both objects must belong to accessible project scope.

---

## `unlinkDevelopmentObjects(relationshipId)`

Must preserve history if relationship was part of an approved artifact/version.

---

# 14. Activity Contracts

## `startActivity(input)`

### Input

```text
activityDefinitionId
projectId
workspaceId
teamId optional
```

### Rules

- activity must be available,
- required dependencies must be satisfied,
- user must have access,
- do not create duplicate active instance unless activity allows it.

### Output

Activity Instance.

---

## `resumeActivity(activityInstanceId)`

Returns:

- definition,
- instructions,
- required inputs,
- current outputs,
- participants,
- status,
- AI role.

---

## `completeActivity(activityInstanceId)`

### Rules

Completion requirements must be satisfied.

May trigger:

- submission availability,
- progress update,
- dependent activity unlock.

---

## `addActivityInput(input)`

Links an approved/allowed artifact, object, evidence item, or version as an activity input.

---

## `addActivityOutput(input)`

Registers structured output produced by the activity.

---

# 15. SCAMPER Contracts

## `createScamperEntry(input)`

### Input

```text
activityInstanceId
scamperType
originalElement
proposedChange
resultText
```

### Output

SCAMPER Entry + optional linked Idea object.

---

## `updateScamperEntry(input)`

Allowed while editable.

---

## `shareScamperEntryToTeam(input)`

Uses standard sharing/promote logic.

---

# 16. Brainstorming Contracts

## `createBrainstormEntry(input)`

### Input

```text
activityInstanceId
content
visibilityState
parentEntryId optional
```

Supports independent private generation.

---

## `revealBrainstormEntries(input)`

### Authorization

Activity host/Master/team workflow according to definition.

### Rules

Only entries in the activity may be revealed.

---

## `promoteBrainstormEntryToIdea(input)`

Creates an Idea Development Object with provenance back to brainstorm entry.

---

# 17. Affinity Contracts

## `createAffinityGroup(input)`

### Input

```text
activityInstanceId
name
description optional
```

---

## `moveItemToAffinityGroup(input)`

### Input

```text
itemId
targetGroupId
position
```

For collaborative interfaces, optimistic realtime UI may be used, but server persistence must validate access.

---

## `renameAffinityGroup(input)`

---

# 18. Mind Map Contracts

## `createMindMap(input)`

Creates:

- Artifact,
- Draft Artifact Version,
- mind map root structure.

---

## `addMindMapNode(input)`

### Input

```text
mindMapId
nodeType
label
parentNodeId optional
developmentObjectId optional
positionData
```

---

## `updateMindMapNode(input)`

---

## `connectMindMapNodes(input)`

Creates typed edge.

---

## `removeMindMapNode(input)`

Must not delete underlying Development Object unless explicitly requested through separate operation.

---

## `saveMindMapDraft(input)`

Normalizes collaborative state and saves draft snapshot.

---

## `createMindMapVersion(input)`

Creates immutable checkpoint/version.

---

# 19. Voting Contracts

## `createVotingSession(input)`

### Input

```text
activityInstanceId
votingType
voteLimit
anonymous
revealMode
options
```

### Authorized Roles

Master or permitted Team Lead / activity host.

---

## `openVotingSession(votingSessionId)`

---

## `castVote(input)`

### Input

```text
votingSessionId
votingOptionId
value
```

### Rules

- user must be eligible participant,
- vote rules must be satisfied,
- hidden/reveal behavior enforced server-side.

---

## `revealVotingSession(votingSessionId)`

For Planning Poker or hidden voting modes.

---

## `closeVotingSession(votingSessionId)`

Locks further votes unless reopened by authorized role.

---

# 20. Decision Contracts

## `createDecision(input)`

### Input

```text
projectId
workspaceId
activityInstanceId optional
title
question
method
options
```

---

## `finalizeDecision(input)`

### Input

```text
decisionId
selectedOptionId optional
outcome
reasoning
linkedEvidenceIds optional
linkedArtifactIds optional
linkedObjectIds optional
```

### Rules

A voting result alone must not automatically finalize a decision.

Human finalization required.

---

## `supersedeDecision(input)`

Creates relationship to later decision instead of erasing history.

---

# 21. Artifact Contracts

## `createArtifact(input)`

### Input

```text
projectId
workspaceId
artifactType
title
activityInstanceId optional
reviewRequired
approvalRequired
```

Creates initial Draft Version.

---

## `createArtifactVersion(input)`

### Input

```text
artifactId
contentSnapshot
changeSummary
sourceDecisionIds optional
sourceEvidenceIds optional
sourceAiOutputIds optional
```

### Rules

Version number assigned server-side.

---

## `getArtifact(artifactId)`

Returns current authorized artifact metadata.

---

## `getArtifactVersion(versionId)`

Must respect original artifact permissions/share scope.

---

## `listArtifactVersions(artifactId)`

Authorized users may inspect version history.

---

## `archiveArtifact(artifactId)`

Preserves all versions.

---

# 22. Submission Contracts

## `submitArtifact(input)`

### Input

```text
artifactId
artifactVersionId
activityInstanceId
```

### Rules

- version must be Draft/editable state,
- user/team must own or be authorized to submit,
- required fields must be complete.

### Transaction

1. set version status SUBMITTED,
2. create Submission,
3. set activity state if appropriate,
4. notify reviewer,
5. audit.

---

## `withdrawSubmission(submissionId)`

Only if review has not passed a policy-defined point.

---

# 23. Review Contracts

## `startReview(submissionId)`

Assigned reviewer only.

---

## `addFeedback(input)`

### Input

```text
targetEntityType
targetEntityId
targetVersionId optional
feedbackType
content
```

---

## `requestRevision(input)`

### Input

```text
submissionId
note
```

### Transaction

- Submission → REVISION_REQUESTED
- Artifact Version → REVISION_REQUESTED
- notify submitter
- audit

---

## `approveArtifact(input)`

### Input

```text
submissionId
approvalNote optional
```

### Authorization

Master / authorized approver.

### Transaction

1. validate reviewer authority,
2. mark submitted version APPROVED,
3. mark previous CURRENT version SUPERSEDED where applicable,
4. set approved version CURRENT,
5. update `artifact.current_version_id`,
6. optionally update Project Baseline,
7. complete submission,
8. create audit event,
9. notify team/user.

This operation must be atomic.

---

## `reopenApprovedArtifact(input)`

Does not mutate approved version.

Creates a new Draft Version based on current approved version.

---

# 24. Sharing Contracts

## `shareEntity(input)`

### Input

```text
entityType
entityId
destinationType
destinationId
permissionLevel
shareMode
```

### Authorization

Caller must have Share permission.

### Rules

Sharing does not transfer ownership.

### Output

Share record.

---

## `revokeShare(shareId)`

### Rules

- future access removed,
- audit/history preserved.

---

## `listEntityShares(input)`

Owner/authorized roles can inspect where an entity is shared.

---

## `copySharedSnapshotToWorkspace(input)`

If policy allows, recipient may create a referenced/copy artifact in own workspace.

Provenance to source share must remain.

---

# 25. Chat Contracts

## `listTeamMessages(input)`

### Input

```text
teamId
cursor optional
limit
```

### Authorization

Active authorized team/chat membership or authorized Master/Mentor.

---

## `sendTeamMessage(input)`

### Input

```text
teamId
content
parentMessageId optional
attachmentIds optional
```

### Rules

- sender must currently have chat access,
- messages persist in database,
- broadcast only after canonical write succeeds.

---

## `editTeamMessage(input)`

Policy-dependent.

If enabled:

- only author within allowed window,
- preserve edited timestamp.

---

## `deleteTeamMessage(input)`

Recommended MVP behavior:

soft delete only.

Do not erase formal project records linked from chat.

---

## `pinTeamMessage(input)`

SHOULD-HAVE.

---

# 26. Evidence Contracts

## `createEvidence(input)`

### Input

```text
projectId
workspaceId
evidenceType
title
description
sourceName
sourceUrl optional
fileId optional
```

### Default

verificationStatus = UNVERIFIED

---

## `linkEvidence(input)`

### Input

```text
evidenceId
entityType
entityId
relationshipType
notes optional
```

---

## `verifyEvidence(input)`

### Input

```text
evidenceId
verificationStatus
note optional
```

### Authorization

Role policy to be finalized.

Must record verifier and timestamp.

---

## `archiveEvidence(evidenceId)`

Should not destroy links/history.

---

# 27. Patent Contracts

## `createPatentRecord(input)`

### Input

```text
projectId
workspaceId
publicationNumber
applicationNumber optional
title
applicant optional
inventor optional
priorityDate optional
filingDate optional
publicationDate optional
ipcCpc optional
sourceDatabase
sourceUrl
abstractText optional
whyRetained optional
```

---

## `createPatentSearchLog(input)`

### Input

```text
projectId
workspaceId
activityInstanceId
databaseName
queryText
searchMethod
reason
resultsReviewedCount optional
relevantResultsCount optional
termsLearned optional
classificationsLearned optional
notes optional
```

---

## `linkPatentToEvidence(input)`

Creates/links Evidence Record referencing patent.

---

## `comparePatentWithProject(input)`

SHOULD-HAVE.

May produce structured comparison draft or AI task, but not legal conclusion.

---

# 28. File Contracts

## `requestUpload(input)`

### Input

```text
workspaceId
projectId optional
filename
mimeType
size
```

### Rules

- validate authorization,
- validate file type,
- validate size,
- return upload target/signature.

---

## `registerUploadedFile(input)`

Creates canonical file metadata after successful storage upload.

---

## `linkFile(input)`

Links file to:

- evidence,
- artifact,
- activity,
- chat,
- project object.

---

## `getFileAccess(input)`

Returns authorized signed download/view URL.

Direct public access must not bypass authorization.

---

## `archiveFile(fileId)`

Avoid destructive delete when file supports formal evidence/history.

---

# 29. AI Task Contracts

## `runAiTask(input)`

### Input

```text
taskType
activityInstanceId optional
projectId
workspaceId
selectedContextRefs optional
userInput
modelProfile optional
```

### Server Flow

```text
Authenticate
↓
Check workspace/project access
↓
Resolve AI role from task/activity
↓
Retrieve permitted context
↓
Apply context minimization
↓
Call provider abstraction
↓
Validate output
↓
Create AI Output
↓
Create AI Context References
↓
Return output
```

### Output

Must include:

- AI Output ID
- output type
- verification state
- response
- context reference summary
- available human dispositions.

---

## `saveAiCandidate(input)`

### Input

```text
aiOutputId
candidateType
targetProjectId
targetWorkspaceId
```

### Rules

Creates Draft/Candidate project object.

Does not approve it.

---

## `rejectAiOutput(aiOutputId)`

Stores disposition = REJECTED.

---

## `convertAiOutputToProjectObject(input)`

### Rules

- human confirmation required,
- target object type validated,
- origin = AI,
- requestedBy user preserved,
- provenance link retained.

---

# 30. AI Usage Contracts

## `getMyAiUsage()`

Returns current usage allowance/cost visibility if product exposes it.

---

## `getCohortAiUsage(cohortId)`

Master/Admin only if enabled.

Must avoid exposing confidential AI content; usage metrics only by default.

---

# 31. Development Gate Contracts

## `createDevelopmentGate(input)`

Typically created from workflow definition or program stage.

---

## `evaluateDevelopmentGate(input)`

### Input

```text
gateId
outcome
reasoning
evidenceIds
requiredNextActions optional
```

### Authorized Roles

Master / designated reviewer.

### Outcomes

- GO
- MODIFY
- HOLD
- STOP
- MORE_EVIDENCE_REQUIRED

---

# 32. Notification Contracts

## `listNotifications(input)`

Cursor-based.

---

## `markNotificationRead(notificationId)`

Only recipient.

---

## `markAllNotificationsRead()`

---

# 33. Audit Contracts

Audit records should primarily be generated internally.

Normal clients should not call:

```text
createAuditEvent()
```

directly.

Admin may have read-only access to appropriate audit views.

---

# 34. History Contracts

## `getProjectChangeLog(projectId)`

Authorized project members/reviewers.

---

## `getProjectDecisionLog(projectId)`

---

## `getProjectVersionHistory(projectId)`

Returns artifact/version timeline.

---

# 35. Pagination Contract

Lists with potentially large results should use cursor pagination.

Recommended request:

```text
limit
cursor
```

Recommended response:

```ts
{
  items: [...],
  nextCursor: string | null
}
```

Avoid page-number pagination for high-growth chat/activity histories.

---

# 36. Concurrency Contract

Editable versioned resources should support optimistic concurrency.

Recommended:

```text
expectedUpdatedAt
```

or version token.

If the resource changed:

```text
VERSION_CONFLICT
```

The client should refresh/merge rather than silently overwrite.

---

# 37. Realtime Event Contracts

Realtime events are notifications of canonical state changes.

Example event names:

```text
team.message.created
team.member.added
team.member.removed
artifact.updated
artifact.submitted
artifact.approved
artifact.revision_requested
share.created
share.revoked
activity.started
activity.completed
vote.cast
vote.revealed
notification.created
```

Events should contain identifiers and limited necessary metadata.

Do not broadcast confidential full records unnecessarily.

---

# 38. Transaction Boundaries

The following must be transactional:

## Team Creation

- Team
- Workspace
- Chat Channel
- Master assignment
- audit

## Member Move

- old membership close
- new membership create
- chat access
- audit

## Artifact Approval

- submission status
- version status
- previous current status
- current version pointer
- baseline update
- audit

## Share Promotion

Where ownership/copy creation happens.

## AI Candidate Conversion

When AI output creates linked structured object + provenance.

---

# 39. Authorization Contract

Every business operation must document:

```text
WHO may call it
IN WHICH SCOPE
ON WHICH RESOURCE
UNDER WHICH STATE
```

Example:

```text
approveArtifact:
Role: Master
Scope: assigned Cohort/Project
Resource: submitted Artifact Version
State: SUBMITTED or UNDER_REVIEW
```

Never rely on role alone without scope.

---

# 40. State-Machine Validation

Important entities must reject illegal transitions.

Example Artifact Version:

```text
DRAFT
→ SUBMITTED
→ UNDER_REVIEW
→ APPROVED

OR

UNDER_REVIEW
→ REVISION_REQUESTED
→ DRAFT/REVISED
→ SUBMITTED
```

Invalid example:

```text
ARCHIVED → APPROVED
```

without explicit restore workflow.

---

# 41. Destructive Operations

Avoid generic `deleteEntity()` APIs.

Use explicit commands:

- archiveTeam
- archiveArtifact
- archiveEvidence
- softDeleteChatMessage

Permanent deletion should be rare and admin-controlled.

---

# 42. Frontend Query vs Command Separation

Recommended conceptual separation:

## Queries

Read data:

```text
getProject()
listArtifacts()
listTeamMessages()
getActivity()
```

## Commands

Change state:

```text
createTeam()
submitArtifact()
approveArtifact()
shareEntity()
```

This makes business side effects easier to audit/test.

---

# 43. Server-Only Operations

These operations must execute server-side:

- role assignment,
- team membership mutation,
- share authorization,
- review/approval,
- signed file access,
- AI provider calls,
- Liveblocks authorization,
- Daily room management,
- audit creation.

---

# 44. External Provider Contracts

External provider adapters should expose FICI-owned interfaces.

Examples:

```text
AiProvider
VideoProvider
EmailProvider
CollaborationProvider
StorageProvider
```

Business code should not call vendor SDKs from unrelated feature modules.

---

# 45. Liveblocks Authorization Contract

## `authorizeCollaborationRoom(input)`

### Input

```text
roomType
entityId
```

### Server Rules

1. authenticate user,
2. resolve FICI workspace/artifact permission,
3. map to provider room ID,
4. issue minimum required Liveblocks permission.

The client must not construct unrestricted permissions.

---

# 46. Daily Room Contracts

## `getOrCreateLiveSessionRoom(input)`

### Input

```text
cohortId
sessionDefinitionId
teamId optional
roomPurpose
```

### Authorization

Master/Admin for creation.

Students receive join details only for rooms they are authorized to enter.

---

## `getLiveRoomJoinToken(input)`

Server verifies:

- enrollment,
- team if breakout,
- session availability.

---

# 47. Email Contracts

Email should be triggered by business events, not arbitrary client requests.

Examples:

- user invited,
- revision requested,
- artifact approved,
- team assignment changed.

A generic "send any email" client API should not exist.

---

# 48. Validation Rules

Every mutation requires runtime validation.

Use Zod schemas or equivalent.

Validation categories:

- shape/type validation,
- length limits,
- allowed enum values,
- resource existence,
- ownership/scope,
- current state,
- curriculum constraints.

---

# 49. Example Contract — Share Artifact

```text
COMMAND:
shareEntity

INPUT:
entityType = ARTIFACT
entityId = A123
destinationType = TEAM
destinationId = T4
permissionLevel = COMMENT
shareMode = LIVE_REFERENCE

SERVER CHECKS:
- caller authenticated
- caller can share A123
- Team T4 exists
- cross-team sharing enabled
- entity not archived/restricted

TRANSACTION:
- create Share
- create audit event
- create notification(s)

OUTPUT:
shareId
effectivePermission
createdAt
```

---

# 50. Example Contract — Approve Artifact

```text
COMMAND:
approveArtifact

INPUT:
submissionId = SUB55
approvalNote = "Approved for Session 7"

SERVER CHECKS:
- caller is assigned Master
- submission belongs to assigned project/cohort
- submission state allows approval
- artifact version exists
- required fields complete

TRANSACTION:
- submitted version → APPROVED/CURRENT
- old current → SUPERSEDED
- artifact.current_version_id updated
- project baseline updated if configured
- submission → APPROVED
- audit event
- notification

OUTPUT:
artifactId
approvedVersionId
previousVersionId
baselineUpdated
```

---

# 51. Example Contract — AI Gap Analysis

```text
COMMAND:
runAiTask

INPUT:
taskType = ANALYZE_GAP
projectId = P1
workspaceId = W_TEAM_3
selectedContextRefs = [G12, IC_V1, EV19]

SERVER CHECKS:
- user can access W_TEAM_3
- user can access P1
- user can access G12, IC_V1, EV19
- activity permits AI

CONTEXT:
- FICI AI rules
- Comparative Analyst role
- current project baseline
- Gap G12
- selected evidence
- relevant decisions

OUTPUT:
AI Analysis
Candidate Directions
Verification Needed

SAVE:
ai_output
ai_context_references
usage event

NO AUTOMATIC PROJECT CHANGE
```

---

# 52. API Versioning

For MVP, internal APIs may begin without public version prefixes.

If external/public API access is introduced later:

```text
/api/v1/
```

should be used.

Internal service contracts should still be treated as version-sensitive to avoid accidental breaking changes.

---

# 53. API Documentation

Each implemented command should have:

- name,
- purpose,
- input schema,
- output schema,
- authorization,
- states,
- errors,
- side effects,
- audit requirements.

Codex should update technical API documentation when contracts change.

---

# 54. Contract Testing

Each high-value operation must have tests for:

1. success path,
2. unauthorized user,
3. invalid scope,
4. invalid state,
5. malformed input,
6. duplicate/retry behavior where relevant,
7. transaction rollback behavior.

---

# 55. Permission Test Examples

Required:

```text
Student cannot add Team Member.
Master cannot manage unrelated Cohort.
Team A cannot share Team B artifact.
Removed member cannot send Team A chat message.
Student cannot approve Artifact requiring Master approval.
User cannot retrieve inaccessible Artifact by direct ID.
User cannot include inaccessible object in AI context.
```

---

# 56. API Decisions Captured

## API-001 — Business Commands Over Generic CRUD

Important mutations use explicit domain commands.

**Status:** Required.

## API-002 — Server Derives Identity

Client-provided identity/role is never trusted.

**Status:** Required.

## API-003 — Scope-Aware Authorization

Every command evaluates role + resource scope.

**Status:** Required.

## API-004 — Critical Operations Are Transactional

Team membership, approvals, and other multi-record business changes use transactions.

**Status:** Required.

## API-005 — AI Uses Same Authorization Layer

AI context retrieval cannot bypass normal project/workspace access.

**Status:** Required.

## API-006 — Realtime Is Not Canonical Storage

Realtime events notify about canonical state.

**Status:** Required.

## API-007 — External Providers Stay Behind Adapters

Vendor SDK calls do not become business contracts.

**Status:** Required.

## API-008 — Archive Over Delete

Important project history is preserved.

**Status:** Required.

---

# 57. Open Questions Before Coding

1. Should Master be able to directly edit team artifacts, or only review/comment?
2. Should students be able to withdraw a submission after Master opens it?
3. Should students be able to leave a team without Master action?
4. Should Team Lead be able to launch Dot Voting?
5. Should Team Lead be able to share team artifacts cross-team?
6. Who can mark Evidence as VERIFIED?
7. Should AI candidate conversion require one confirmation or two-stage team acceptance?
8. Should artifacts autosave continuously or only save explicit draft checkpoints?
9. Should cross-team Live Reference sharing exist in MVP or only Snapshot?
10. Should chat message editing/deletion be enabled?
11. Should Student-created projects require Master approval before being attached to an official team?
12. Should project baseline automatically update whenever an artifact is approved?
13. Which operations require email in addition to in-app notifications?
14. Should team membership invitations require student acceptance?
15. Should all curriculum Activity Definitions be editable through Admin UI in MVP, or seeded/configured by developers first?

These do not block the conceptual API model, but they must be resolved before affected features are considered complete.

---

# 58. Required Next Document

The final pre-coding specification is:

# `12_ACCEPTANCE_TESTS.md`

It will define end-to-end product acceptance scenarios for:

- Authentication
- Roles
- Personal Workspace privacy
- Team isolation
- Team management
- Chat
- Sharing
- Development Project continuity
- Activities
- Structured tools
- Voting
- Evidence
- Patent Records
- AI permissions
- AI provenance
- Submission / Revision / Approval
- Version history
- RLS security
- Cross-team data leakage prevention
- MVP pilot readiness

After `12_ACCEPTANCE_TESTS.md` is approved, the documentation package is sufficiently complete to prepare the first Codex implementation plan.

---

# 59. Codex API Rule

Codex must not create a new business mutation without determining:

```text
INPUT
AUTHORIZATION
VALIDATION
CURRENT STATE
TRANSACTION
OUTPUT
AUDIT
ERRORS
```

If an implementation requires behavior that is not defined in the approved documentation, Codex must flag it instead of silently creating a new product rule.

---

# End of Document

**Current Status:** Draft v0.1 — Ready for Ahmad/FICI review.  
**Next Document After Approval:** `12_ACCEPTANCE_TESTS.md`
