# FICI Invention Education & Development Platform
## Codex M13 Execution Prompts — Sharing & Cross-Team Access

**Document:** `27_CODEX_M13_PROMPTS.md`  
**Status:** Draft v0.1 — For Review  
**Depends on:** `01_PRODUCT_REQUIREMENTS.md` through `26_CODEX_M12_PROMPTS.md`  
**Purpose:** Provide exact copy/paste prompts for Codex to implement Milestone M13 safely and incrementally after M12 is complete.

---

# 1. Preconditions

Do not begin M13 until M12 is:

```text
IMPLEMENTED
→ TESTED
→ SECURITY-REVIEWED
→ COMMITTED
```

Required M12 state:

- Evidence works,
- File storage is private,
- signed File access works,
- Patent Records work,
- Patent Search Logs work,
- M12 RLS passes,
- AT-EV tests pass,
- AT-PAT tests pass,
- AT-FILE tests pass,
- Codex reports READY FOR M13.

If M12 is incomplete:

```text
STOP → FINISH M12 → REVIEW → COMMIT → BEGIN M13
```

M13 is security-sensitive because it intentionally crosses Workspace boundaries.

---

# 2. M13 Goal

M13 implements deliberate, object-level sharing while preserving privacy.

The core rule is:

# PRIVATE BY DEFAULT → SHARE INTENTIONALLY → OWNERSHIP RETAINED

The target behavior is:

```text
SOURCE WORKSPACE
↓
SELECT ONE ENTITY
↓
CHOOSE DESTINATION
↓
CHOOSE PERMISSION
↓
CHOOSE SHARE MODE
↓
CREATE SHARE RECORD
↓
RECIPIENT GETS ONLY EXPLICIT ACCESS
```

Sharing must never mean:

```text
"recipient now has access to source workspace"
```

---

# 3. M13 Product Boundary

M13 includes:

- `shares`,
- `share_snapshots` if Snapshot mode is used,
- object-specific sharing,
- VIEW,
- COMMENT,
- COLLABORATE foundation,
- SNAPSHOT,
- LIVE_REFERENCE if explicitly approved,
- revoke share,
- share history,
- Personal → Team,
- Team → Master,
- optional Team → Team,
- selected user / Mentor / Cohort / Workspace destinations where allowed,
- share listing,
- share access resolver,
- copy shared snapshot to destination Workspace where policy permits,
- audit/notification hooks,
- RLS/security,
- cross-team leakage tests,
- AT-PW-004,
- AT-SHARE-001 to AT-SHARE-005,
- relevant AT-E2E-PRIV-001 paths.

M13 does **not** yet implement:

- AI context behavior for shared content beyond permission compatibility,
- full Notification Center,
- email notifications,
- collaborative cross-Team live editing unless explicitly approved,
- Workspace-wide sharing,
- Team merge,
- Team split,
- public internet sharing.

M14 will consume the resulting permission model for AI context.

---

# 4. Sharing Principle

Approved collaboration principle:

```text
Private by Default
→ Share Intentionally
→ Collaborate in Scope
→ Preserve Ownership and History
```

The source entity remains owned by its original user/team/workspace.

A Share grants access.

It does not transfer ownership.

---

# 5. Share Schema

Implement:

```text
shares
```

Fields:

- `id`
- `source_workspace_id`
- `shared_entity_type`
- `shared_entity_id`
- `shared_by`
- `destination_type`
- `destination_id`
- `permission_level`
- `share_mode`
- `created_at`
- `revoked_at`
- `revoked_by`

Approved destination types:

```text
USER
TEAM
MASTER
COHORT
WORKSPACE
```

Approved permission levels:

```text
VIEW
COMMENT
COLLABORATE
```

Approved share modes:

```text
LIVE_REFERENCE
SNAPSHOT
```

MVP should prioritize:

```text
VIEW
COMMENT
```

and either:

```text
SNAPSHOT
or
LIVE_REFERENCE
```

according to the approved M13 product decision.

---

# 6. Share Snapshot Schema

If Snapshot mode is enabled, implement:

```text
share_snapshots
```

Fields:

- `id`
- `share_id`
- `source_version_id`
- `snapshot_data`
- `created_at`

Snapshot means:

```text
recipient sees frozen shared state
```

Later source changes do not automatically alter the frozen snapshot.

---

# 7. Live Reference Principle

LIVE_REFERENCE means the recipient sees the current source entity subject to share permission.

It must not imply:

- source Workspace access,
- source Chat access,
- source File browsing,
- source AI history access,
- source sibling entity access.

If LIVE_REFERENCE remains an unresolved MVP decision:

```text
STOP → FLAG → ASK
```

Do not implement it merely because the enum exists.

---

# 8. Snapshot Principle

SNAPSHOT is safer for cross-Team MVP sharing.

A Snapshot must preserve:

- source entity identity/reference,
- source version if versioned,
- source owner,
- source Workspace,
- source Share ID,
- snapshot timestamp.

Snapshot recipient must not gain access to the underlying Workspace.

---

# 9. Share Permission Semantics

Approved model:

| Permission | View | Comment | Edit | Re-share |
|---|---:|---:|---:|---:|
| VIEW | Yes | No | No | No |
| COMMENT | Yes | Yes | No | No |
| COLLABORATE | Yes | Yes | Yes | No by default |

Re-sharing is not allowed by default.

MVP should prioritize VIEW and COMMENT.

Do not silently grant Edit from COMMENT.

---

# 10. Sharing Does Not Transfer Ownership

After sharing:

```text
source owner stays source owner
creator stays creator
Workspace stays source Workspace
Project provenance stays unchanged
```

Recipient permission does not mutate:

- `created_by`,
- Artifact owner,
- Development Object creator,
- Workspace ownership,
- Project ownership.

---

# 11. Only Selected Entity Is Shared

If Team A shares:

```text
Mind Map V2
```

Team B may receive that entity only.

Team B must **not** receive:

- Team A Workspace,
- Team A Chat,
- Team A other Artifacts,
- Team A private Files,
- Team A private Evidence,
- Team A Patent research notes,
- Team A AI history,
- Team A unrelated Development Objects.

This is a BLOCKER rule.

---

# 12. Personal → Team Sharing

Required flow:

```text
Personal Workspace
↓
select entity
↓
share with Team
↓
Team receives only selected entity
↓
Personal Workspace remains private
```

This completes the earlier deferred Personal sharing behavior.

AT-PW-004 must pass.

---

# 13. Team → Master Sharing

A Team may explicitly share selected content with Master.

Important:

Master may already have some educational oversight depending on scope.

The Share record still matters when:

- content is specifically submitted/shared,
- permission level is explicit,
- audit/notification is required,
- source ownership must remain clear.

Do not use a Share to create hidden broader Master access.

---

# 14. Team → Team Sharing

Cross-Team sharing is required by product requirements.

For MVP, prioritize:

```text
VIEW
COMMENT
SNAPSHOT or approved LIVE_REFERENCE
```

Full multi-Team co-editing may be deferred.

If COLLABORATE across teams is not approved:

```text
do not enable it
```

even though the generic enum exists.

---

# 15. Team → Cohort Sharing

Cohort sharing exposes the selected entity to eligible users in that Cohort.

It must still be object-specific.

Do not convert Cohort sharing into source Workspace membership.

---

# 16. Master → Team Sharing

Master may share:

- case-study artifacts,
- references,
- examples,
- templates,
- instructions,
- external resources,
- feedback.

The shared entity should indicate its purpose where product model supports it:

```text
Reference
Example
Required Input
Feedback
Assignment
```

Do not invent a new purpose table unless approved.

---

# 17. ShareEntity Contract

Approved:

```text
shareEntity(input)
```

Input:

```text
entityType
entityId
destinationType
destinationId
permissionLevel
shareMode
```

Authorization:

```text
caller must have Share permission
```

Output:

```text
Share record
```

---

# 18. RevokeShare Contract

Approved:

```text
revokeShare(shareId)
```

Rules:

- future access removed,
- audit/history preserved.

Revocation must not erase the Share record.

---

# 19. ListEntityShares Contract

Approved:

```text
listEntityShares(input)
```

Owner/authorized roles can inspect where an entity is shared.

This is essential for confidentiality awareness.

---

# 20. CopySharedSnapshotToWorkspace Contract

Approved:

```text
copySharedSnapshotToWorkspace(input)
```

If policy allows, recipient may create a referenced/copied artifact in own Workspace.

Provenance to source Share must remain.

Copying is not the same as modifying the source.

---

# 21. Share Access Resolver

M13 should create one authoritative server-side resolver such as:

```text
resolveSharedEntityAccess(userId, entityType, entityId)
```

or repository-equivalent.

It should determine:

- active Share?
- correct destination?
- destination membership active?
- permission level?
- Share revoked?
- Snapshot vs Live Reference?
- source entity still valid?
- recipient capability: view/comment/collaborate?

Do not duplicate share logic independently across every feature.

---

# 22. Destination Resolution

Destination authorization must be resolved server-side.

Examples:

## USER

Only the intended user receives access.

## TEAM

Only active authorized Team members receive access.

## MASTER

Only the intended/authorized Master context receives access.

## COHORT

Only active authorized members of that Cohort receive access.

## WORKSPACE

Only users who currently have access to destination Workspace receive access.

A client-provided destination ID is never sufficient by itself.

---

# 23. Membership Changes Affect Share Access

For a TEAM destination:

```text
share remains active
+
user leaves Team
=
user loses future shared access
```

The Share belongs to Team destination, not permanently to each former member.

Historical authorship remains.

---

# 24. Revocation

After revocation:

```text
revoked_at != null
```

and future recipient access must fail.

Preserve:

- Share record,
- shared_by,
- created_at,
- revoked_by,
- revoked_at,
- audit event,
- historical references.

---

# 25. Revocation and Snapshot

Important distinction:

If recipient has only been viewing a shared Snapshot through the Share, revocation removes future platform access to that shared Snapshot.

If policy allows recipient to **copy** a shared Snapshot into their own Workspace before revocation, that copied derivative may remain subject to provenance and policy.

The source docs do not fully define whether such copies survive revocation.

If this behavior is needed:

```text
STOP → FLAG → ASK
```

Do not silently choose.

---

# 26. Revocation and Live Reference

LIVE_REFERENCE must stop resolving after revocation.

No cached application shortcut should continue returning source entity content.

M14 AI context must later respect the same revocation.

---

# 27. Comments on Shared Entity

COMMENT permission allows comments without source editing.

Preferred architecture:

- use existing Feedback/comment model if target supports it,
- preserve commenter identity,
- preserve Share context,
- do not grant source edit permission.

Do not create comments by directly changing Artifact content.

---

# 28. Collaborate Permission

COLLABORATE means edit access only if:

- entity type supports it,
- cross-boundary collaboration is approved,
- Workspace/security model can safely support it.

MVP may defer broad cross-Team COLLABORATE.

Do not enable generic edit merely because permission enum exists.

---

# 29. Sharing Versioned Artifacts

For Artifact sharing, the product must distinguish:

- Artifact identity,
- specific Artifact Version,
- current/live Artifact.

SNAPSHOT should freeze a specific Version where possible.

LIVE_REFERENCE may resolve current authorized source state.

Do not silently switch a recipient from shared V2 to future V3 if Snapshot mode was selected.

---

# 30. Sharing Development Objects

If Development Object sharing is supported:

- share the selected Object only,
- do not expose all related Objects automatically,
- do not expose all relationships automatically if they reveal private context.

Relationship expansion must be explicit and authorized.

---

# 31. Sharing Mind Maps

Sharing a Mind Map must not automatically expose:

- all Project Objects referenced by nodes beyond what is needed for rendering and permitted by Share,
- source Workspace,
- unrelated Artifacts.

For Snapshot, snapshot enough display data to avoid unauthorized source traversal.

For Live Reference, every referenced entity access must be resolved safely.

---

# 32. Sharing Files

M13 must not accidentally make source Files public.

If a shared Artifact has a File:

- recipient File access must be explicitly allowed,
- signed File access still applies,
- source Workspace remains private.

Do not treat Artifact share as automatic permission to every File unless policy explicitly includes those files.

---

# 33. Sharing Evidence

Evidence can be sensitive.

If shared explicitly, the recipient may receive that selected Evidence according to Share permission.

Do not automatically share:

- linked private File,
- unrelated Evidence,
- source Workspace,
- private research notes not included in the shared entity.

---

# 34. Sharing Patent Records

Patent source URLs may be public, but Team research metadata can be private.

Sharing a Patent Record intentionally may expose:

- selected Patent Record metadata,
- allowed notes.

It must not expose unrelated Search Logs or research strategy.

---

# 35. Share History

Share history should answer:

```text
WHAT was shared?
WHO shared it?
FROM WHICH Workspace?
WITH WHOM?
WHAT permission?
WHAT mode?
WHEN?
IS IT active?
IF revoked, WHO revoked and WHEN?
```

Do not delete historical Share records.

---

# 36. Audit Requirements

Sensitive sharing events must create audit events:

```text
SHARE_CREATED
SHARE_REVOKED
SHARE_PERMISSION_CHANGED if supported
SNAPSHOT_COPIED if supported
```

Audit event names may follow repository convention.

Audit must not include full confidential content.

---

# 37. Notification Hooks

M13 sharing flows should create notification records/hooks for:

- new Share,
- Share revoked where relevant.

Full notification UX is M15.

Do not build a large notification center in M13.

---

# 38. Sharing UI Safety

Before sharing confidential project content outside source scope, UI should make destination and permission clear.

Example:

```text
Share "Mind Map V2"
with Team 4
as View Only?
```

The implementation should require explicit confirmation of:

- destination,
- permission,
- mode.

Do not silently default to broad Cohort sharing.

---

# 39. Confidentiality Indicator

Underlying state should support displaying labels such as:

```text
Private
Team
Shared with Master
Shared with Team 4
Cohort
```

Exact UI is deferred.

M13 provides the data needed to derive such labels.

---

# 40. Source-of-Truth Files

Before each M13 task, Codex must read:

```text
/docs/01_PRODUCT_REQUIREMENTS.md
/docs/03_ROLES_PERMISSIONS.md
/docs/04_WORKSPACE_TEAM_COLLABORATION.md
/docs/05_DEVELOPMENT_PROJECT_MODEL.md
/docs/07_MVP_SCOPE.md
/docs/08_DATA_MODEL_SCHEMA.md
/docs/10_TECHNICAL_ARCHITECTURE.md
/docs/11_API_CONTRACTS.md
/docs/12_ACCEPTANCE_TESTS.md
/docs/13_CODEX_IMPLEMENTATION_PLAN.md
/docs/18_CODEX_M4_PROMPTS.md
/docs/19_CODEX_M5_PROMPTS.md
/docs/20_CODEX_M6_PROMPTS.md
/docs/22_CODEX_M8_PROMPTS.md
/docs/23_CODEX_M9_PROMPTS.md
/docs/26_CODEX_M12_PROMPTS.md
```

---

# 41. Global Codex Header

Use this block at the beginning of every M13 task if project rules are not automatically retained:

```text
You are implementing the FICI Invention Education & Development Platform.

Before making changes:

1. Read the relevant /docs files listed in this task.
2. Treat them as product/security source of truth.
3. Do not invent missing sharing rules.
4. Private by default.
5. Sharing is explicit and object-specific.
6. Sharing does not transfer ownership.
7. Source Workspace remains private.
8. One shared entity must not expose sibling entities.
9. VIEW cannot edit.
10. COMMENT cannot edit.
11. Re-sharing is denied by default.
12. Revocation removes future access.
13. Share history remains.
14. Team membership changes affect destination access.
15. Never trust client-provided sharer, source Workspace, destination membership, or permission.
16. Enforce authorization server-side and through RLS.
17. File access still requires signed authorization.
18. Do not implement M14 AI early.
19. If LIVE_REFERENCE/COLLABORATE policy is unresolved, STOP → FLAG → ASK.
20. Use migrations for schema changes.
21. Use strict TypeScript.
22. Validate runtime input.
23. Run required validation before finishing.
24. Report:
    - files changed,
    - migrations,
    - share modes,
    - permission rules,
    - destination resolution,
    - revocation behavior,
    - RLS,
    - audit/notifications,
    - tests,
    - assumptions,
    - unresolved issues.
```

---

# 42. M13.1 — Share Schema

## Objective

Create explicit, auditable Share records.

## Copy/Paste Prompt

```text
TASK ID: M13.1
TASK: Share Schema

Read first:

- /docs/08_DATA_MODEL_SCHEMA.md
- /docs/03_ROLES_PERMISSIONS.md

OBJECTIVE

Create `shares`.

FIELDS

- id
- source_workspace_id
- shared_entity_type
- shared_entity_id
- shared_by
- destination_type
- destination_id
- permission_level
- share_mode
- created_at
- revoked_at
- revoked_by

DESTINATION TYPES

- USER
- TEAM
- MASTER
- COHORT
- WORKSPACE

PERMISSION LEVELS

- VIEW
- COMMENT
- COLLABORATE

SHARE MODES

- LIVE_REFERENCE
- SNAPSHOT

RULES

1. shared_by is server-derived.
2. source Workspace must be resolvable from entity and accessible.
3. entity must exist and be shareable.
4. destination must exist.
5. revoked Share remains stored.
6. direct client cannot set revoked_by.
7. re-sharing is denied by default.
8. add indexes for entity, destination, active/revoked lookup.

TEST

- valid Personal → Team Share.
- valid Team → Master Share.
- valid Team → Team Share if enabled.
- invalid source Workspace rejected.
- non-owner/non-sharer denied.

DEFINITION OF DONE

All cross-Workspace access is represented by explicit Share records.
```

---

# 43. M13.2 — Snapshot Schema

## Objective

Implement frozen Share representation if Snapshot mode is part of MVP.

## Copy/Paste Prompt

```text
TASK ID: M13.2
TASK: Share Snapshot Schema

Read first:

- /docs/08_DATA_MODEL_SCHEMA.md
- /docs/13_CODEX_IMPLEMENTATION_PLAN.md

OBJECTIVE

If SNAPSHOT is enabled, create `share_snapshots`.

FIELDS

- id
- share_id
- source_version_id
- snapshot_data
- created_at

RULES

1. one Snapshot belongs to one Share.
2. source_version_id required for versioned entities where applicable.
3. snapshot_data freezes only information intended for recipient.
4. do not serialize entire source Workspace.
5. exclude unrelated private fields.
6. source owner/provenance retained.

If Snapshot behavior is not required:
document why table is deferred.

TEST

- Artifact V2 snapshot remains V2 after source V3.
- snapshot does not contain sibling Artifact metadata.
- Team B cannot access source Workspace via snapshot references.

DEFINITION OF DONE

Frozen sharing does not depend on broad source access.
```

---

# 44. M13.3 — Shareability Resolver

## Objective

Determine whether a caller may share a selected entity.

## Copy/Paste Prompt

```text
TASK ID: M13.3
TASK: Shareability Resolver

Read first:

- /docs/03_ROLES_PERMISSIONS.md
- /docs/04_WORKSPACE_TEAM_COLLABORATION.md
- /docs/11_API_CONTRACTS.md

OBJECTIVE

Implement one authoritative server-side shareability resolver.

CHECK

1. caller authenticated.
2. source entity exists.
3. caller can access source entity.
4. caller has SHARE capability for source.
5. source entity is not archived/restricted against sharing.
6. source Workspace known.
7. destination exists.
8. destination type supported.
9. cross-Team sharing enabled if destination Team differs.
10. requested permission allowed.
11. requested share mode allowed.

IMPORTANT

Do not infer SHARE permission merely from VIEW or COMMENT.

Team Lead share authority is an explicit open question.
If not approved:
do not grant automatically.

RETURN

Typed:
- allowed,
- denied reason,
- allowed permission levels,
- allowed modes.

DEFINITION OF DONE

Share authorization is centralized and explicit.
```

---

# 45. M13.4 — ShareEntity Transaction

## Objective

Implement the core `shareEntity(input)` operation.

## Copy/Paste Prompt

```text
TASK ID: M13.4
TASK: shareEntity()

Read first:

- /docs/11_API_CONTRACTS.md
- /docs/12_ACCEPTANCE_TESTS.md

INPUT

entityType
entityId
destinationType
destinationId
permissionLevel
shareMode

FLOW

1. authenticate caller.
2. resolve source entity.
3. resolve source Workspace.
4. evaluate Share capability.
5. validate destination.
6. validate requested permission.
7. validate requested mode.
8. create Share record.
9. if SNAPSHOT:
   create Share Snapshot transactionally.
10. create audit event.
11. create notification hook/record.
12. return Share.

RULES

- ownership unchanged.
- creator unchanged.
- source Workspace unchanged.
- duplicate identical active Share handled idempotently or rejected cleanly.
- broad Workspace access not granted.

TRANSACTION

Share + Snapshot + audit + minimal notification should be transactionally consistent where repository architecture permits.

TEST

- Personal → Team.
- Team → Master.
- Team → Team if enabled.
- unauthorized source denied.
- invalid destination denied.
- duplicate safe.

DEFINITION OF DONE

Explicit Share can be created without exposing source scope.
```

---

# 46. M13.5 — Shared Access Resolver

## Objective

Resolve recipient capabilities on a shared entity.

## Copy/Paste Prompt

```text
TASK ID: M13.5
TASK: Shared Entity Access Resolver

OBJECTIVE

Implement reusable recipient access resolution.

INPUT

authenticated user
entity type
entity ID or Share ID

EVALUATE

- active Share exists?
- Share revoked?
- destination matches current user/scope?
- destination Team/Cohort/Workspace membership active?
- permission = VIEW / COMMENT / COLLABORATE?
- share mode = SNAPSHOT / LIVE_REFERENCE?
- source entity still valid?
- source version relevant?

RETURN CAPABILITIES

- canView
- canComment
- canEdit
- canReshare = false by default
- isSnapshot
- isLiveReference

RULES

No Share may grant:
- source Workspace browse,
- source Chat,
- unrelated File,
- unrelated Artifact,
- unrelated Project Object.

TEST

- VIEW → view only.
- COMMENT → view/comment only.
- revoked → no access.
- former Team destination member → no access.

DEFINITION OF DONE

Shared access has one authoritative capability resolver.
```

---

# 47. M13.6 — Personal → Team Sharing

## Objective

Complete Personal Workspace selected-content sharing.

## Copy/Paste Prompt

```text
TASK ID: M13.6
TASK: Personal → Team Sharing

Read first:

- /docs/04_WORKSPACE_TEAM_COLLABORATION.md
- /docs/12_ACCEPTANCE_TESTS.md
- /docs/23_CODEX_M9_PROMPTS.md

OBJECTIVE

Allow a Personal Workspace owner to share selected entities with their authorized Team.

CRITICAL RULE

Only selected entities become accessible.

Example:
A1 has 10 private Ideas.
A1 shares 3.
Team A sees exactly 3.

The other 7 remain private.

SOURCE WORKSPACE

Must remain inaccessible to Team.

PROVENANCE

Preserve:
- original creator,
- source Workspace,
- original entity ID,
- Share record.

SCAMPER INTEGRATION

Complete the M9-deferred selected SCAMPER sharing path using the standard Share model.

TEST

AT-PW-004.
AT-SCAMPER-003 if previously deferred.

Priority:
MUST PASS.

DEFINITION OF DONE

Selected Personal work can reach Team without exposing the rest of Personal Workspace.
```

---

# 48. M13.7 — Team → Master Sharing

## Objective

Implement explicit Team-to-Master sharing.

## Copy/Paste Prompt

```text
TASK ID: M13.7
TASK: Team → Master Sharing

OBJECTIVE

Allow Team A to share selected Artifact/entity with authorized Master.

RULES

1. sharer has Team Share authority.
2. destination Master valid and in appropriate scope.
3. exact permission stored.
4. ownership remains Team A.
5. Share record exists.
6. audit created.
7. notification created/hooked.

TEST

AT-SHARE-001:
Team A shares Artifact with Master.

Verify:
- Master gains specified access.
- Team A ownership unchanged.
- Share exists.
- audit/notification exists.

DEFINITION OF DONE

AT-SHARE-001 passes.
```

---

# 49. M13.8 — Team → Team Sharing

## Objective

Implement safe cross-Team object-specific sharing.

## Copy/Paste Prompt

```text
TASK ID: M13.8
TASK: Team → Team Sharing

Read first:

- /docs/01_PRODUCT_REQUIREMENTS.md
- /docs/03_ROLES_PERMISSIONS.md
- /docs/04_WORKSPACE_TEAM_COLLABORATION.md

OBJECTIVE

Allow authorized Team A sharer to share one selected entity with Team B.

MVP PRIORITY

- VIEW
- COMMENT
- SNAPSHOT or approved LIVE_REFERENCE

FULL CROSS-TEAM EDIT

Do not enable unless explicitly approved.

RULES

1. Team A sharer currently authorized.
2. Team B exists.
3. same Cohort requirement only if product policy requires it.
4. selected entity only.
5. Team B does not gain Team A Workspace membership.
6. Team B does not gain Team A Chat.
7. Team B does not gain unrelated Files/Artifacts/AI history.
8. re-sharing denied.

TEST

Share Team A Mind Map with Team B.

Verify:
- shared entity accessible.
- Team A Workspace route denied.
- other Artifact denied.
- Chat denied.
- unrelated File denied.

DEFINITION OF DONE

Cross-Team sharing works without cross-Team Workspace exposure.
```

---

# 50. M13.9 — VIEW Permission Enforcement

## Objective

Implement strict read-only shared access.

## Copy/Paste Prompt

```text
TASK ID: M13.9
TASK: VIEW Permission Enforcement

OBJECTIVE

For permissionLevel = VIEW:

ALLOW
- fetch/render shared entity.
- view permitted shared metadata/version/snapshot.

DENY
- edit source.
- edit snapshot source.
- comment.
- approve.
- archive source.
- share again.
- change source relationships.
- access source Workspace.

TEST

AT-SHARE-003:
Team B receives VIEW.
Attempts edit via:
- UI/API,
- direct mutation,
- direct DB under auth.

Expected:
FORBIDDEN.

Priority:
BLOCKER.

DEFINITION OF DONE

VIEW can never become edit through a secondary route.
```

---

# 51. M13.10 — COMMENT Permission Enforcement

## Objective

Implement COMMENT without source editing.

## Copy/Paste Prompt

```text
TASK ID: M13.10
TASK: COMMENT Permission

OBJECTIVE

For permissionLevel = COMMENT:

ALLOW
- view shared entity,
- add permitted comment/feedback.

DENY
- edit source content,
- change source Version,
- archive source,
- approve source unless separate authority exists,
- re-share.

COMMENT STORAGE

Use existing comment/Feedback mechanism where appropriate.
Preserve:
- commenter identity,
- target entity,
- target version if versioned,
- Share context where useful.

TEST

AT-SHARE-004:
Team B can comment.
Team B cannot edit source.

Expected PASS.

DEFINITION OF DONE

Comment collaboration does not mutate source ownership/content.
```

---

# 52. M13.11 — COLLABORATE Permission Boundary

## Objective

Support or safely defer edit-level cross-boundary collaboration.

## Copy/Paste Prompt

```text
TASK ID: M13.11
TASK: COLLABORATE Permission Boundary

Read first:

- /docs/03_ROLES_PERMISSIONS.md
- /docs/13_CODEX_IMPLEMENTATION_PLAN.md

OBJECTIVE

Determine whether COLLABORATE is enabled for M13 MVP.

IF NOT APPROVED

- retain enum/schema capability,
- do not expose it in normal share creation,
- return unsupported/policy-denied,
- document deferred behavior.

IF APPROVED

Implement entity-specific edit capability.
Do not grant source Workspace membership.
All edits must preserve:
- source owner,
- versioning,
- attribution,
- audit.

Never enable generic edit across all entity types.

DEFINITION OF DONE

No accidental broad edit rights arise from the generic permission enum.
```

---

# 53. M13.12 — Revoke Share

## Objective

Implement `revokeShare(shareId)`.

## Copy/Paste Prompt

```text
TASK ID: M13.12
TASK: Revoke Share

Read first:

- /docs/11_API_CONTRACTS.md
- /docs/12_ACCEPTANCE_TESTS.md

OBJECTIVE

Revoke active Share.

AUTHORIZATION

Source owner / authorized sharer / authorized management policy.

FLOW

1. authenticate actor.
2. load Share.
3. verify revoke authority.
4. set revoked_at.
5. set revoked_by server-side.
6. preserve Share row.
7. create audit event.
8. create notification hook if relevant.
9. invalidate future shared access.

RULES

- source unchanged.
- history retained.
- no destructive Share delete.
- future signed File/shared reference access must fail where based on Share.

TEST

AT-SHARE-005:
After revoke:
- Team B loses future access.
- Share history remains.
- audit remains.

DEFINITION OF DONE

AT-SHARE-005 passes.
```

---

# 54. M13.13 — Share History Query

## Objective

Implement `listEntityShares(input)`.

## Copy/Paste Prompt

```text
TASK ID: M13.13
TASK: Share History

OBJECTIVE

Implement authorized inspection of where an entity is/was shared.

RETURN

- destination type/id display-safe info,
- permission,
- mode,
- created_at,
- shared_by,
- active/revoked state,
- revoked_at,
- revoked_by where authorized.

SECURITY

Only owner/authorized roles may inspect Share history.

Do not leak private destination membership details beyond need.

TEST

- source owner sees active/revoked shares.
- recipient cannot enumerate all source entity Shares unless policy permits.
- Team B cannot inspect Team A unrelated Share history.

DEFINITION OF DONE

Confidentiality history is inspectable by authorized source actors.
```

---

# 55. M13.14 — Copy Shared Snapshot

## Objective

Implement `copySharedSnapshotToWorkspace(input)` only if policy permits.

## Copy/Paste Prompt

```text
TASK ID: M13.14
TASK: Copy Shared Snapshot to Workspace

Read first:

- /docs/11_API_CONTRACTS.md
- /docs/04_WORKSPACE_TEAM_COLLABORATION.md

OBJECTIVE

Allow authorized recipient to create a derivative/reference in own Workspace from an allowed Snapshot.

CHECK

1. active Share.
2. Share mode = SNAPSHOT.
3. recipient can view Snapshot.
4. copy policy allows.
5. destination Workspace accessible.

CREATE

- new entity/artifact only according to target entity's normal creation rules,
- preserve provenance to:
  - source Share,
  - source entity,
  - source Version,
  - original creator.

DO NOT

- change source ownership.
- silently copy entire Workspace context.
- copy unrelated private relationships/files.

REVOCATION

If copied derivatives surviving revocation is not explicitly defined:
STOP → FLAG → ASK.

DEFINITION OF DONE

Snapshot copying, if enabled, is provenance-preserving and scope-limited.
```

---

# 56. M13.15 — Shared File Access Integration

## Objective

Ensure entity sharing does not bypass M12 File security.

## Copy/Paste Prompt

```text
TASK ID: M13.15
TASK: Shared File Access Integration

Read first:

- /docs/26_CODEX_M12_PROMPTS.md
- /docs/12_ACCEPTANCE_TESTS.md

OBJECTIVE

Integrate Shares with file-access checks safely.

RULES

1. sharing Artifact does not automatically share every linked File unless policy says included.
2. shared File access must resolve an explicit File Share or an approved entity-to-file access rule.
3. getFileAccess() still performs authorization.
4. signed URL remains short-lived.
5. revocation prevents future signed URL issuance through Share.
6. source storage reference stays private.

TEST

- shared Artifact without File permission → File denied.
- explicitly shared File → signed URL allowed.
- revoked Share → new URL denied.
- Team B cannot use source storage reference.

DEFINITION OF DONE

M13 cannot become a bypass around M12 signed File security.
```

---

# 57. M13.16 — Sharing Artifact Versions

## Objective

Make Snapshot and Live Reference semantics explicit for versioned Artifacts.

## Copy/Paste Prompt

```text
TASK ID: M13.16
TASK: Artifact Version Sharing

OBJECTIVE

Implement safe Artifact sharing behavior.

SNAPSHOT

- bind to explicit source Artifact Version.
- recipient sees frozen state.
- later source Version does not change Snapshot.

LIVE_REFERENCE

If approved:
- recipient sees current allowed source state.
- each access re-checks Share and entity authorization.
- revocation immediately blocks future resolution.

VIEW/COMMENT

Operate against the shared representation, not unrestricted Artifact history.

VERSION HISTORY

Do not automatically expose all source Artifact Versions unless explicitly included.

TEST

- Snapshot V2 remains V2 after V3 created.
- recipient cannot browse V1/V3 by guessing IDs.
- Live Reference revoked → access denied.

DEFINITION OF DONE

Sharing versioned Artifacts does not leak source history.
```

---

# 58. M13.17 — Mind Map Share Safety

## Objective

Safely share a complex Artifact with referenced Project Objects.

## Copy/Paste Prompt

```text
TASK ID: M13.17
TASK: Mind Map Sharing Safety

Read first:

- /docs/25_CODEX_M11_PROMPTS.md

OBJECTIVE

Share Team A Mind Map with Team B without exposing Team A Workspace.

SNAPSHOT MODE

Snapshot must include only rendering/display data necessary for the shared map.

Do not include:
- unrelated Team A Object metadata,
- private Workspace IDs beyond internal provenance,
- source Chat,
- source File references unless explicitly included,
- source AI history.

LIVE REFERENCE MODE

If approved:
- every referenced Object/Version needed for render must be authorized through Share projection,
- recipient cannot traverse arbitrary Project relations.

TEST

This is the primary AT-SHARE-002 scenario.

DEFINITION OF DONE

Mind Map can be shared safely as one object-specific resource.
```

---

# 59. M13.18 — SCAMPER Share Integration

## Objective

Complete the previously deferred M9 SCAMPER share requirement.

## Copy/Paste Prompt

```text
TASK ID: M13.18
TASK: SCAMPER Standard Sharing Integration

Read first:

- /docs/23_CODEX_M9_PROMPTS.md
- /docs/12_ACCEPTANCE_TESTS.md

OBJECTIVE

Implement selected Personal SCAMPER Entry → Team sharing using standard M13 Share model.

RULES

1. original Personal entry stays in Personal Workspace.
2. creator remains recorded.
3. Team receives selected Entry only.
4. other Personal entries remain private.
5. source Workspace inaccessible.
6. Share can be revoked.
7. general Share audit exists.

TEST

AT-SCAMPER-003:
selected Entry available to Team A.
original creator retained.

Also verify AT-PW-004 behavior.

DEFINITION OF DONE

M9's deferred sharing path is completed without ad hoc permissions.
```

---

# 60. M13.19 — Share RLS

## Objective

Protect Share records and shared entity resolution directly.

## Copy/Paste Prompt

```text
TASK ID: M13.19
TASK: Share RLS

OBJECTIVE

Implement RLS for:
- shares
- share_snapshots if used

RULES

SOURCE SIDE
- only authorized source actors can create/manage Share.
- client cannot spoof shared_by/source_workspace_id.

RECIPIENT SIDE
- active destination membership required.
- revoked Share denied.
- recipient sees only Share records necessary for access/UI.

MUTATION
Normal recipient cannot:
- elevate VIEW → COMMENT,
- elevate COMMENT → COLLABORATE,
- change destination,
- un-revoke,
- re-share,
- alter source entity ID,
- alter source Workspace.

SNAPSHOT
- only active recipient/source authorized users may read.
- snapshot cannot reveal entire source Workspace.

TEST

- Team B cannot forge Share from Team A entity.
- recipient cannot elevate permission.
- revoked row cannot be used for access.
- guessed Share ID denied.

DEFINITION OF DONE

Direct database access cannot bypass sharing policy.
```

---

# 61. M13.20 — Shared Entity Query Isolation

## Objective

Ensure normal entity queries honor explicit Shares without broadening source queries.

## Copy/Paste Prompt

```text
TASK ID: M13.20
TASK: Shared Entity Query Isolation

OBJECTIVE

Extend entity retrieval carefully.

When recipient has Share:
- get exact shared entity may succeed according to permission.

But recipient must not automatically gain:
- list all source Workspace Artifacts,
- list Project Objects,
- list source Files,
- list source Evidence,
- list source Activity history,
- list source Versions unless shared.

TEST

Team B has Share to Mind Map M1.

Attempt:
- get M1 → allowed.
- list Team A artifacts → denied.
- get M2 exact ID → denied.
- list Team A files → denied.
- get Team A chat → denied.

DEFINITION OF DONE

Object-level access stays object-level in every query path.
```

---

# 62. M13.21 — AT-PW-004

## Objective

Complete the Personal Workspace selected-share acceptance test.

## Copy/Paste Prompt

```text
TASK ID: M13.21
TASK: AT-PW-004

SCENARIO

A1 has 10 private Ideas.

A1 shares exactly 3 with Team A.

VERIFY

- Team A can access exactly those 3.
- remaining 7 inaccessible.
- A2 cannot browse A1 Personal Workspace.
- Team A cannot list all A1 Personal entities.
- creator/owner stays A1/source.
- Share records exist.

PRIORITY

MUST PASS.

FINAL REPORT

Return:
- shared IDs,
- denied IDs,
- Workspace access result,
- PASS/FAIL.
```

---

# 63. M13.22 — AT-SHARE-001 to 005

## Objective

Implement the complete Sharing acceptance suite.

## Copy/Paste Prompt

```text
TASK ID: M13.22
TASK: Sharing Acceptance Tests

AT-SHARE-001 — Share Artifact to Master

Verify:
- specified Master access,
- Team A ownership remains,
- Share record,
- audit/notification.

AT-SHARE-002 — Sharing Does Not Expose Workspace

Share Team A Mind Map with Team B.

Team B must not access:
- Team A Chat,
- Team A other Artifacts,
- Team A Files,
- Team A AI history.

Priority:
BLOCKER.

AT-SHARE-003 — View-Only Enforcement

VIEW recipient edit attempt fails.

Priority:
BLOCKER.

AT-SHARE-004 — Comment Permission

COMMENT recipient can comment but cannot edit source.

AT-SHARE-005 — Revoke Share

After revoke:
- future access denied,
- Share history retained,
- audit retained.

RUN

API/service,
direct IDs,
database under user auth,
realtime where relevant.

FINAL REPORT

Return full test matrix.
```

---

# 64. M13.23 — End-to-End Privacy Sharing Paths

## Objective

Run the sharing-relevant portion of AT-E2E-PRIV-001.

## Copy/Paste Prompt

```text
TASK ID: M13.23
TASK: E2E Privacy — Sharing Paths

Read first:

- /docs/12_ACCEPTANCE_TESTS.md

SETUP

Team A shares exactly one selected entity with Team B.

ATTACK ROUTES

Team B attempts source Team A access through:

- UI navigation,
- direct URL,
- API request,
- database query under user auth,
- realtime channel,
- File URL,
- shared-object relationship traversal,
- guessed Version IDs,
- guessed linked Object IDs.

AI context path belongs to M14 but M13 must expose a clean authorization API for it.

EXPECTED

Only explicitly shared content returns.

No unauthorized source Team content returned.

Priority:
BLOCKER / RELEASE GATE.

DEFINITION OF DONE

Sharing cannot be used as a pivot into source Workspace.
```

---

# 65. M13.24 — Revocation & Membership Change Tests

## Objective

Prove dynamic permission changes invalidate future shared access.

## Copy/Paste Prompt

```text
TASK ID: M13.24
TASK: Share Revocation & Membership Changes

CASE 1 — REVOKE

Team A shares with Team B.
Team A revokes.
B loses future access.

CASE 2 — DESTINATION MEMBER REMOVED

Share destination = Team B.
B1 leaves/is removed from Team B.
Share stays active for Team B.
B1 loses future access.

CASE 3 — SOURCE SHARER REMOVED

Team A sharer who created Share is later removed.
Define behavior according to Share ownership policy.
Do not silently revoke Team-owned Share unless source docs say so.

CASE 4 — SOURCE ENTITY ARCHIVED

Shared source entity archived.
Recipient access follows entity/share archive policy.
Do not invent restore behavior.

DEFINITION OF DONE

Share access is evaluated dynamically against current destination scope.
```

---

# 66. M13.25 — Share Audit & Notification Hooks

## Objective

Preserve security history and pilot notification integration points.

## Copy/Paste Prompt

```text
TASK ID: M13.25
TASK: Sharing Audit & Notification Hooks

OBJECTIVE

For:
- Share created,
- Share revoked,
- Snapshot copied if supported,

record auditable events.

SHARE CREATED AUDIT

Include safe metadata:
- Share ID,
- entity type/id,
- source Workspace ID,
- destination type/id,
- permission,
- mode,
- actor,
- timestamp.

Do not copy full confidential content.

NOTIFICATIONS

Create/use notification foundation for:
- new Share,
- Share revoked where relevant.

Full notification UI/email = M15.

TEST

- AT-AUD-003:
Share/revoke produces audit event.

DEFINITION OF DONE

Sensitive sharing changes are traceable.
```

---

# 67. M13.26 — M13 Security & Integrity Hardening

## Objective

Review Sharing before AI context is introduced.

## Copy/Paste Prompt

```text
TASK ID: M13.26
TASK: M13 Security & Integrity Hardening

Read first:

- /docs/01_PRODUCT_REQUIREMENTS.md
- /docs/03_ROLES_PERMISSIONS.md
- /docs/04_WORKSPACE_TEAM_COLLABORATION.md
- /docs/08_DATA_MODEL_SCHEMA.md
- /docs/10_TECHNICAL_ARCHITECTURE.md
- /docs/11_API_CONTRACTS.md
- /docs/12_ACCEPTANCE_TESTS.md
- /docs/13_CODEX_IMPLEMENTATION_PLAN.md
- /docs/18_CODEX_M4_PROMPTS.md
- /docs/19_CODEX_M5_PROMPTS.md
- /docs/22_CODEX_M8_PROMPTS.md
- /docs/23_CODEX_M9_PROMPTS.md
- /docs/26_CODEX_M12_PROMPTS.md
- /docs/27_CODEX_M13_PROMPTS.md

VERIFY

1. sharing is object-specific.
2. ownership never transfers.
3. source Workspace remains private.
4. VIEW cannot edit.
5. COMMENT cannot edit.
6. re-sharing denied by default.
7. revoked Share loses future access.
8. Share history remains.
9. destination membership is evaluated dynamically.
10. Personal → Team exposes only selected entities.
11. Team → Team does not expose Workspace/Chat/Files/AI history.
12. Snapshot does not expose source history.
13. Live Reference, if enabled, checks access on every resolution.
14. signed File access remains protected.
15. recipient cannot enumerate source entity siblings.
16. Share RLS blocks permission escalation.
17. audit records Share/revoke.
18. no M14 AI implemented early.

RUN

pnpm lint
pnpm typecheck
pnpm test:unit
pnpm test:integration
pnpm test:e2e
pnpm build
plus all RLS/security tests.

DEFINITION OF DONE

- AT-PW-004 PASS
- AT-SHARE-001 PASS
- AT-SHARE-002 PASS
- AT-SHARE-003 PASS
- AT-SHARE-004 PASS
- AT-SHARE-005 PASS
- AT-SCAMPER-003 PASS if previously deferred
- AT-AUD-003 PASS
- AT-E2E-PRIV-001 relevant sharing paths PASS
- zero known source Workspace leak
- zero permission elevation path
- no M14 scope creep

FINAL REPORT

Return:
1. security review
2. permission review
3. revocation review
4. leakage review
5. issues found
6. issues fixed
7. remaining issues
8. BLOCKER status
9. test results
10. recommendation: READY FOR M14 or NOT READY FOR M14
```

---

# 68. Sharing vs Submission

Do not conflate:

```text
Share with Master
```

with:

```text
Submit Artifact for formal review
```

Submission uses M8 workflow.

Sharing grants access.

A shared Artifact is not automatically under review.

---

# 69. Sharing vs Team Membership

Do not add recipient as source Team member merely to make sharing easier.

Share access is narrower than Team membership.

---

# 70. Sharing vs Workspace Membership

Likewise:

```text
share one Artifact
≠
add user to Workspace
```

Do not implement Share by silently adding destination user to source Workspace.

---

# 71. Sharing vs Ownership Transfer

A Shared entity does not become destination-owned.

If later product supports "promote/copy into destination Project," use a separate operation with provenance.

---

# 72. Sharing vs Copying

Share:

```text
recipient gains controlled access
```

Copy:

```text
new destination entity may be created
```

These are different.

`copySharedSnapshotToWorkspace()` is explicit.

---

# 73. Snapshot vs Live Reference

Snapshot:

```text
frozen
```

Live Reference:

```text
source changes may be visible
```

The user must understand which is selected.

Do not silently convert between modes.

---

# 74. Permission Downgrade / Upgrade

If changing Share permission is needed:

- use explicit operation,
- audit it,
- do not let recipient self-upgrade.

If no approved API exists:

do not implement generic client update.

Use revoke + new Share or flag missing command.

---

# 75. Source Entity Archive

If source entity becomes archived:

- Share should not silently make archived content editable,
- access behavior should follow archive policy.

Do not delete Share history.

---

# 76. Source Entity Delete

Important entities use archive over delete.

M13 should assume source history persists.

If source hard-deletion exists for non-critical entities, dangling Share must be safely handled.

---

# 77. Share Discovery

Recipient needs a way to list shared items available to them.

If API contract does not specify a dedicated list operation, implement a minimal authorized query/service based on active Shares.

Do not expose all source metadata.

---

# 78. Shared Workspace Concept

The product concept includes Shared Workspace.

M13 may expose shared items through a logical Shared area.

Do not duplicate source entities into a broad shared database unless Snapshot mode requires a snapshot record.

Shared Workspace is a permission/view layer, not ownership transfer.

---

# 79. Team-to-Master Review Boundary

If Team shares a Draft with Master via COMMENT permission:

Master can comment through Share.

Formal review/approval still uses M8 Submission/Review.

Do not grant approval authority through Share permission.

---

# 80. COMMENT and Feedback

Where comments use `feedback_items`:

- Feedback target should be exact shared entity/version,
- author identity preserved,
- COMMENT Share required,
- Feedback visibility should match source/recipient policy.

Do not expose unrelated feedback threads automatically.

---

# 81. Share to Mentor

Destination model supports USER/WORKSPACE and product requirements include Mentor.

If Mentor destination is represented by USER or scoped Workspace in current schema, follow source architecture.

Do not invent a new `MENTOR` destination enum unless approved.

---

# 82. Share to Admin

Product requirements mention Admin as a possible audience.

Current destination enum does not list ADMIN.

Do not invent it.

Use USER/WORKSPACE or existing role-aware destination pattern if docs define it.

Otherwise flag the mismatch.

---

# 83. Share to Multiple Teams

The product may allow several teams.

Implement as multiple Share records unless source docs specify group destination object.

This keeps each destination independently revocable.

---

# 84. Cohort-Wide Publication

Cohort destination is controlled sharing, not public publication.

Users outside the Cohort remain denied.

---

# 85. Cross-Team Comment Safety

Team B COMMENT access should permit only the comment surface.

It must not grant:
- editing Artifact Version,
- changing Mind Map canonical nodes,
- editing linked Development Objects,
- access to Team A Activity history.

---

# 86. Shared Entity Relationships

A shared entity may reference private source entities.

Do not recursively authorize all relationships.

Default:

```text
only include relationships/data required to safely render the shared entity
```

Any deeper navigation requires independent Share/access.

---

# 87. M14 AI Compatibility

M14 Context Builder must later treat an active Share as an access source.

M13 should expose a reusable permission resolver so AI does not duplicate sharing logic.

After revoke:

```text
new AI context resolution must no longer include source
```

M13 should make that possible.

---

# 88. Realtime Compatibility

If a Live Reference or shared comment uses realtime:

- recipient may subscribe only to the shared resource channel,
- not source Workspace broad channel,
- revocation must prevent future subscriptions.

Do not create wildcard source-Team subscriptions.

---

# 89. File Compatibility

M12 signed access remains authoritative.

A Share record alone must never be translated into a permanent File URL.

---

# 90. Audit Compatibility

Share audit should preserve:

- actor,
- source entity,
- destination,
- permission,
- mode,
- revocation.

This supports confidentiality disputes and security reviews.

---

# 91. M13 Expected Repository Additions

Conceptually:

```text
features/
└── sharing/
    ├── operations/
    ├── access/
    ├── snapshots/
    ├── comments/
    ├── destinations/
    ├── history/
    └── validation/

lib/
├── permissions/
│   └── sharing.ts
├── provenance/
│   └── shared-copy.ts
└── security/
    └── shared-access.ts

supabase/
├── migrations/
│   ├── ...shares...
│   ├── ...share_snapshots...
│   └── ...share_rls...
└── tests/
    └── rls/
        └── sharing...

tests/
├── unit/
│   └── sharing/
├── integration/
│   ├── personal-to-team/
│   ├── team-to-master/
│   └── team-to-team/
└── e2e/
    └── sharing-privacy.spec.ts
```

Exact paths may vary.

---

# 92. M13 Completion Gate

M13 is complete only when:

```text
[ ] shares exists
[ ] share_snapshots exists if Snapshot enabled

[ ] shareEntity() implemented
[ ] revokeShare() implemented
[ ] listEntityShares() implemented
[ ] copySharedSnapshotToWorkspace() implemented only if policy allows

[ ] destination resolution implemented
[ ] active membership considered
[ ] share access resolver implemented

[ ] VIEW works
[ ] COMMENT works
[ ] COLLABORATE safely supported or explicitly deferred

[ ] SNAPSHOT works if selected
[ ] LIVE_REFERENCE works only if explicitly approved

[ ] sharing does not transfer ownership
[ ] source Workspace remains private
[ ] selected entity only is exposed
[ ] re-sharing denied by default

[ ] Personal → Team works
[ ] Team → Master works
[ ] Team → Team works if enabled

[ ] shared Files remain protected by signed access
[ ] Artifact Version sharing does not leak history
[ ] Mind Map sharing does not leak source Project
[ ] SCAMPER standard sharing completed

[ ] revocation removes future access
[ ] share history preserved
[ ] audit events created
[ ] notification hooks created

[ ] AT-PW-004 PASS
[ ] AT-SHARE-001 PASS
[ ] AT-SHARE-002 PASS
[ ] AT-SHARE-003 PASS
[ ] AT-SHARE-004 PASS
[ ] AT-SHARE-005 PASS
[ ] AT-SCAMPER-003 PASS if previously deferred
[ ] AT-AUD-003 PASS
[ ] AT-E2E-PRIV-001 sharing paths PASS

[ ] lint passes
[ ] typecheck passes
[ ] unit tests pass
[ ] integration tests pass
[ ] E2E tests pass
[ ] RLS tests pass
[ ] build passes

[ ] no M14 AI implemented prematurely
[ ] Codex reports READY FOR M14
```

Any source Workspace exposure from one Share is:

```text
BLOCKER
```

Any VIEW → edit privilege escalation is:

```text
BLOCKER
```

Any revoked Share still granting future platform access is:

```text
BLOCKER
```

---

# 93. Recommended Commit Sequence

Example:

```text
feat(sharing): add Share schema
feat(sharing): add Snapshot schema
feat(sharing): add shareability resolver
feat(sharing): add shareEntity transaction
feat(sharing): add recipient access resolver
feat(sharing): add Personal-to-Team flow
feat(sharing): add Team-to-Master flow
feat(sharing): add Team-to-Team flow
feat(sharing): enforce VIEW permission
feat(sharing): enforce COMMENT permission
feat(sharing): add revoke/history
feat(sharing): add Snapshot copy if approved
feat(files): integrate shared File access
feat(artifacts): add safe versioned Artifact sharing
feat(mind-map): add safe shared rendering
feat(scamper): complete standard sharing
feat(security): add Share RLS
feat(audit): add Share audit hooks
test(sharing): add AT-PW-004
test(sharing): add AT-SHARE suite
test(security): add E2E sharing privacy tests
chore(security): complete M13 hardening
```

---

# 94. M13 Non-Goals

Do not accept these as "helpful additions" during M13:

- AI Assistant,
- AI Context Builder,
- public anonymous links,
- public internet sharing,
- unrestricted cross-Team editing,
- source Workspace membership via Share,
- Team merge,
- Team split,
- permanent File URLs,
- automatic ownership transfer,
- recursive sharing of all linked objects,
- recipient re-sharing by default,
- large Notification Center,
- email notification workflows.

---

# 95. Potential M13 Ambiguities Codex Must Flag

Do not silently decide if approved docs do not resolve:

- whether LIVE_REFERENCE is enabled in MVP,
- whether MVP is Snapshot-only,
- whether COLLABORATE is enabled cross-Team,
- who may share Team-owned content,
- whether Team Lead may share cross-Team,
- whether Master can share Team-owned content on team's behalf,
- whether Mentor can share,
- whether Student can share directly with Master,
- whether Cohort Share is enabled in MVP,
- whether source/destination must be in same Cohort,
- whether copied Snapshot survives Share revocation,
- whether Shared Snapshot can be copied more than once,
- whether copied derivative may be edited,
- exact behavior for sharing linked Files,
- whether Artifact Share exposes current Version only or selected Version,
- whether Live Reference follows new approved Version automatically,
- whether recipient can see Share source owner identity,
- whether recipient can see source Workspace name,
- whether recipient can list Share history,
- whether source can downgrade permission without revoke/re-share,
- whether revoked Share notification is required,
- whether comments survive Share revocation and remain visible to source,
- whether a shared entity can be archived by recipient,
- whether Admin needs a special destination type,
- whether Mentor needs a special destination type.

If unresolved:

```text
STOP → FLAG → ASK
```

---

# 96. Recommended Safe Defaults for Purely Technical Decisions

Only where they do not alter approved product policy:

- UUID Share IDs,
- server-derived sharer/revoker,
- explicit Share record per destination,
- re-sharing false,
- source ownership retained,
- recipient access resolved dynamically,
- revoked Shares retained,
- Snapshot freezes specific Version,
- no broad source Workspace query,
- VIEW and COMMENT prioritized,
- cross-Team COLLABORATE disabled unless approved,
- File signed access retained,
- RLS enabled,
- audit required,
- no M14 AI code.

---

# 97. Review Checklist for Ahmad/FICI

Before implementation, confirm M13 reflects the intended collaboration model:

```text
1. Everything is private by default.

2. A user/team chooses exactly what to share.

3. Sharing never exposes the whole source Workspace.

4. Ownership stays with the source.

5. Creator attribution stays unchanged.

6. Personal → Team selected sharing works.

7. Team → Master selected sharing works.

8. Team → Team sharing works in controlled form.

9. VIEW means no edit.

10. COMMENT means comment but no edit.

11. Re-sharing is disabled by default.

12. Snapshot can freeze the shared state.

13. Live Reference is enabled only if explicitly approved.

14. Revocation removes future access.

15. Share history remains after revocation.

16. Team membership changes dynamically affect shared access.

17. Shared Files still require signed authorization.

18. Sharing one Mind Map does not expose Team chat, other Artifacts, Files, Evidence, Patent notes, or AI history.

19. M13 completes the earlier SCAMPER selected-share requirement.

20. M14 AI will use this same sharing permission resolver.
```

---

# 98. Next File After M13

After M13 has actually been:

```text
IMPLEMENTED
→ TESTED
→ SECURITY-REVIEWED
→ COMMITTED
```

create:

# `28_CODEX_M14_PROMPTS.md`

M14 will cover:

```text
AI Provider Abstraction
OpenAI Responses API
AI Task Service
AI Roles
Permission-Aware Context Builder
AI Outputs
AI Context References
AI Prompt Templates
AI Usage Events
Human Disposition
Candidate Conversion
AI Leakage Tests
AI Cannot Auto-Approve
```

---

# 99. Final Execution Rule

For M13:

```text
SHARE SCHEMA
→ SNAPSHOT MODEL
→ SHAREABILITY
→ SHARE TRANSACTION
→ ACCESS RESOLVER
→ PERSONAL → TEAM
→ TEAM → MASTER
→ TEAM → TEAM
→ VIEW
→ COMMENT
→ COLLABORATE BOUNDARY
→ REVOKE
→ HISTORY
→ SNAPSHOT COPY
→ FILE INTEGRATION
→ VERSIONED ARTIFACT SHARING
→ MIND MAP SHARING
→ SCAMPER INTEGRATION
→ RLS
→ ACCEPTANCE TESTS
→ E2E PRIVACY
→ SECURITY HARDENING
```

Do not skip directly to AI.

---

# End of Document

**Current Status:** Draft v0.1 — Ready for Ahmad/FICI review.  
**Execution Step After M12 Completion:** Start with **M13.1 — Share Schema**.
