# FICI Invention Education & Development Platform
## Codex M11 Execution Prompts — Affinity & Mind Mapping

**Document:** `25_CODEX_M11_PROMPTS.md`  
**Status:** Draft v0.1 — For Review  
**Depends on:** `01_PRODUCT_REQUIREMENTS.md` through `24_CODEX_M10_PROMPTS.md`  
**Purpose:** Provide exact copy/paste prompts for Codex to implement Milestone M11 safely and incrementally after M10 is complete.

---

# 1. Preconditions

Do not begin M11 until M10 is:

```text
IMPLEMENTED
→ TESTED
→ SECURITY-REVIEWED
→ COMMITTED
```

Required M10 state:

- Dot Voting works,
- vote limits are enforced server-side,
- Team B cannot vote in Team A,
- Voting does not auto-finalize Decisions,
- Decision Records work,
- Decision supersession preserves history,
- Session 5 integration works,
- AT-VOTE suite passes,
- AT-DEC suite passes for M10-owned fields,
- Codex reports READY FOR M11.

If M10 is incomplete:

```text
STOP → FINISH M10 → REVIEW → COMMIT → BEGIN M11
```

M11 must reuse the existing Activity Engine, Development Objects, Artifacts, and Team security model.

---

# 2. M11 Goal

M11 implements two core structural tools:

```text
AFFINITY DIAGRAM
+
MIND MAPPING
```

The curriculum progression is:

```text
SESSION 6 — AFFINITY
What belongs together?
↓
SESSION 7 — MIND MAP
How does everything connect to the whole invention?
```

M11 must turn accumulated Problems, Solutions, Features, Components, Decisions, and gaps into:

```text
INVENTION STRUCTURE V1
+
GAP LIST
+
INVENTION MIND MAP
+
MINIMUM ESSENTIAL INVENTION STRUCTURE
+
INVENTION CONCEPT V1
```

The core architecture principle is:

# VISUAL STRUCTURE MUST REFERENCE CANONICAL PROJECT OBJECTS — NOT DUPLICATE THEM

---

# 3. M11 Product Boundary

M11 includes:

- `affinity_groups`,
- `affinity_group_items`,
- Affinity grouping of existing structured Project Objects,
- collaborative movement,
- group naming/renaming,
- ordering,
- Invention Structure V1 output,
- Gap List output,
- `mind_maps`,
- `mind_map_nodes`,
- `mind_map_edges`,
- typed nodes,
- typed edges,
- links to existing Development Objects,
- React Flow UI,
- Liveblocks collaborative room,
- normalized PostgreSQL save,
- Draft Artifact Version checkpoints,
- create immutable Mind Map checkpoints/versions,
- concurrent-edit protection,
- RLS/security,
- AT-AFF tests,
- AT-MM tests,
- AT-CON-001 collaborative/concurrency test.

M11 does **not** yet implement:

- Evidence Records,
- Files,
- Patent Workspace,
- AI Assistant,
- generic Sharing,
- automated Patent analysis,
- detailed prototype development,
- MVP development,
- full Agile project-management system.

Those belong to later milestones.

---

# 4. Affinity Curriculum Principle

Professional Session 6 goal:

```text
Organize accumulated information into an early invention structure.
```

Approved inputs:

- Problems,
- Solutions,
- Features,
- Decisions,
- Components,
- Search Findings.

Approved workflow:

```text
Collect
↓
Spread Information
↓
Group by Natural Affinity
↓
Name Groups
↓
Identify Relationships
↓
Transform Groups into Systems / Subsystems
↓
Connect Problem → Solution → Function → Component
↓
Identify Gaps
```

Primary mode:

```text
Team collaboration
```

Outputs:

```text
Invention Structure V1
Gap List
```

---

# 5. Affinity Data Principle

Affinity is a visual/organizational layer.

Cards/items should reference existing structured entities where possible.

Therefore:

```text
Affinity Item
→ Development Object
```

or:

```text
Affinity Item
→ Brainstorm Entry
```

Do not duplicate canonical Problems/Solutions into separate Affinity-only records.

---

# 6. Affinity Schema

Implement:

```text
affinity_groups
```

Fields:

- `id`
- `activity_instance_id`
- `name`
- `description`
- `sequence`
- `created_by`

Implement:

```text
affinity_group_items
```

Fields:

- `id`
- `affinity_group_id`
- `development_object_id` nullable
- `brainstorm_entry_id` nullable
- `position`
- `added_by`

At least one valid source reference must exist per item according to approved rules.

---

# 7. Affinity Group Meaning

A Group is a temporary/working organization structure.

Examples may emerge as:

- Control,
- Power,
- Structure,
- User Interface,
- Safety,
- Sensing,
- Mechanical,
- Software,
- unresolved grouping.

The Instructor should guide grouping without imposing categories prematurely.

Therefore:

- do not pre-create rigid mandatory group taxonomies,
- allow teams to discover/name groups,
- preserve later promotion into Systems/Subsystems where appropriate.

---

# 8. Collaborative Movement

The API contract explicitly allows optimistic realtime UI for moving Affinity items, but server persistence must validate access.

Required architecture:

```text
USER DRAG
↓
OPTIMISTIC UI
↓
AUTHORIZED SERVER PERSISTENCE
↓
REALTIME UPDATE
↓
CANONICAL POSTGRESQL POSITION/GROUP
```

The UI may feel realtime.

PostgreSQL remains canonical saved state.

---

# 9. Affinity Concurrency Rule

Two users may move items at nearly the same time.

Silent loss is not acceptable.

The system must either:

- merge non-conflicting movements,
- detect conflicting movement,
- apply deterministic conflict resolution,
- or use collaborative state with authoritative save.

AT-AFF-002 requires collaborative movement without silent loss.

---

# 10. Affinity Output to Project Structure

Session 6 does more than visual grouping.

The team may transform discovered groups into persistent Project structure.

Possible target Development Objects include:

```text
SYSTEM
SUBSYSTEM
COMPONENT
FUNCTION
GAP
```

M11 must preserve existing Problems/Solutions and create new structured objects only when the user intentionally confirms them.

Do not automatically convert every visual group into a System without human action.

---

# 11. Gap Identification

Session 6 explicitly outputs a Gap List.

Gaps should use existing:

```text
Development Object type = GAP
```

and a versioned Artifact:

```text
GAP_LIST
```

Do not create a disconnected gap-text subsystem.

---

# 12. Invention Structure V1

The Session 6 output `Invention Structure V1` should be represented using:

- canonical Development Objects,
- explicit Object Relationships,
- Artifact/Artifact Version,
- optionally Affinity grouping metadata as working context.

Do not make the Affinity Board itself the only permanent invention structure.

---

# 13. Mind Mapping Curriculum Principle

Professional Session 7 goal:

```text
Visualize the entire invention and identify the minimum essential invention structure.
```

Approved inputs:

```text
Invention Structure V1
Gap List
```

Approved workflow:

```text
Central Invention
↓
Main Systems
↓
Subsystems
↓
Components
↓
Functions
↓
Problems / Solutions
↓
Cross-Connections
↓
Unresolved Gaps
↓
Targeted Search / AI
↓
Team Review
↓
Update Map
↓
Classify Core / Supporting / Future
```

M11 implements the Mind Map and structural classification foundation.

Search/AI integration belongs later.

---

# 14. Mind Map Product Principle

Session 7 is not starting again.

It transforms prior work into a visual connected whole:

```text
Invention Structure V1
+
Gap List
↓
Invention Mind Map
```

Every branch/connection/gap should come from real Project work where possible.

---

# 15. Mind Map Schema

Implement:

```text
mind_maps
```

Fields:

- `id`
- `artifact_id`
- `artifact_version_id`
- `root_node_id`

Implement:

```text
mind_map_nodes
```

Fields:

- `id`
- `mind_map_id`
- `node_type`
- `label`
- `development_object_id` nullable
- `parent_node_id` nullable
- `position_data`
- `metadata`
- `created_by`

Implement:

```text
mind_map_edges
```

Fields:

- `id`
- `mind_map_id`
- `source_node_id`
- `target_node_id`
- `edge_type`
- `label`
- `metadata`

---

# 16. Required Mind Map Node Types

AT-MM-001 requires structured node creation for:

```text
System
Subsystem
Component
Function
Problem
Solution
Gap
```

These should map to existing Development Object types where appropriate.

The central invention/root may use an appropriate map/root type if defined by source docs.

Do not invent a large unrelated node taxonomy.

---

# 17. Node vs Development Object

A Mind Map Node is a visual representation.

A Development Object is canonical Project state.

Required distinction:

```text
Mind Map Node
≠
Development Object
```

A node may:

```text
reference Development Object
```

Removing a node must not automatically delete its linked Development Object.

This is a BLOCKER acceptance requirement.

---

# 18. Edge vs Development Object Relationship

Likewise:

```text
Mind Map Edge
```

is a visual relationship in the map.

It may correspond to or help create a canonical:

```text
development_object_relationship
```

but they are not automatically identical.

Do not create/delete canonical Project relationships silently merely because a visual edge is moved/deleted.

Any synchronization must be explicit and source-supported.

---

# 19. React Flow Rule

M11 should use:

```text
React Flow
```

for structured Mind Map UI.

React Flow handles:

- nodes,
- edges,
- position,
- viewport/interactions,
- visual editing.

React Flow state is not the canonical long-term Project source of truth.

---

# 20. Liveblocks Rule

M11 should use:

```text
Liveblocks
```

for high-frequency collaborative state.

Examples:

- live node movement,
- cursor/presence where implemented,
- temporary collaborative edits,
- fast shared board interaction.

Critical rule:

# LIVEBLOCKS = REALTIME COLLABORATION STATE

# POSTGRESQL = CANONICAL SAVED STATE

Do not treat Liveblocks room state as the only persisted invention record.

---

# 21. Normalized PostgreSQL Save

Canonical saved Mind Map data must be normalized into:

```text
mind_maps
mind_map_nodes
mind_map_edges
```

and connected to:

```text
Artifact
Artifact Version
Development Objects
```

Liveblocks state must be converted/validated before canonical save.

---

# 22. Draft Artifact Version Checkpoint

Mind Map is an M8 Artifact.

Approved API:

```text
createMindMap()
```

creates:

- Artifact,
- Draft Artifact Version,
- Mind Map root structure.

Approved:

```text
saveMindMapDraft()
```

normalizes collaborative state and saves a Draft snapshot.

Approved:

```text
createMindMapVersion()
```

creates an immutable checkpoint/version.

---

# 23. Canonical Artifact Type

Use the approved Artifact type:

```text
MIND_MAP
```

for Invention Mind Map.

Other outputs such as Minimum Essential Structure and Invention Concept may use existing/approved Artifact types or Development Objects according to source docs.

Do not invent new Artifact type names unless schema/product docs require them.

---

# 24. Mind Map Classification

Session 7 classifies major elements as:

```text
Core
Supporting
Optional / Future
```

This classification may be stored in node metadata and/or canonical Project object metadata only if consistent with existing schema.

Do not redefine object `status` to mean Core/Supporting/Future.

Keep classification semantically separate.

---

# 25. Minimum Essential Invention Structure

Session 7 asks:

```text
What happens if we remove it?
Does the core function still work?
Does the inventive concept still exist?
Is it needed now, or could it be added later?
```

The output is a Minimum Essential Invention Structure.

M11 should support this as structured classification/output without turning it into detailed MVP/prototype development.

---

# 26. Source-of-Truth Files

Before each M11 task, Codex must read:

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
/docs/24_CODEX_M10_PROMPTS.md
```

Also read approved Professional Course Session 6 and Session 7 curriculum.

---

# 27. Global Codex Header

Use this block at the beginning of every M11 task if project rules are not automatically retained:

```text
You are implementing the FICI Invention Education & Development Platform.

Before making changes:

1. Read the relevant /docs files and approved Session 6/7 curriculum.
2. Treat them as source of truth.
3. Do not invent missing business rules.
4. Affinity and Mind Map are visual/organizational layers over persistent Project data.
5. Reuse canonical Development Objects whenever possible.
6. Do not duplicate Problems/Solutions simply for grouping or mapping.
7. Removing a visual node must not delete its linked Development Object.
8. Liveblocks is realtime collaboration state only.
9. PostgreSQL is canonical saved state.
10. React Flow is the Mind Map interaction layer.
11. Use M8 Artifact Versioning for checkpoints.
12. Preserve Team/Workspace/Project privacy.
13. Preserve stable Project/Object identities.
14. Never trust client-provided actor, Team, Workspace, Project, Object, or room identity.
15. Server persistence must validate all collaborative edits.
16. Protect against silent overwrite.
17. Do not implement M12+ Evidence/Patent/AI features.
18. Use migrations for schema changes.
19. Use strict TypeScript.
20. Validate runtime input.
21. If requirements conflict or are ambiguous, STOP → FLAG → ASK.
22. Run required validation before finishing.
23. Report:
    - files changed,
    - migrations,
    - operations,
    - realtime architecture,
    - canonical persistence,
    - conflict handling,
    - RLS,
    - tests,
    - results,
    - assumptions,
    - unresolved issues.
```

---

# 28. M11.1 — Affinity Schema

## Objective

Create Affinity Groups and item links without duplicating canonical objects.

## Copy/Paste Prompt

```text
TASK ID: M11.1
TASK: Affinity Schema

Read first:

- /docs/08_DATA_MODEL_SCHEMA.md
- /docs/06_COURSE_ACTIVITY_WORKFLOWS.md
- /docs/23_CODEX_M9_PROMPTS.md

OBJECTIVE

Create:
- affinity_groups
- affinity_group_items

AFFINITY_GROUPS

Fields:
- id
- activity_instance_id
- name
- description
- sequence
- created_by

AFFINITY_GROUP_ITEMS

Fields:
- id
- affinity_group_id
- development_object_id nullable
- brainstorm_entry_id nullable
- position
- added_by

RULES

1. Group belongs to one Affinity-compatible Activity.
2. creator server-derived.
3. item must reference an accessible source entity.
4. Development Object remains canonical.
5. Brainstorm Entry remains canonical raw source if used.
6. do not clone source content into a new Problem/Solution.
7. position/order is persisted.
8. add indexes for Activity/group ordering.

TEST

- create group
- add Problem Object
- add Solution Object
- add allowed Brainstorm Entry
- invalid cross-Team source rejected
- item with no valid source rejected if schema requires one

VALIDATION

Run schema and RLS tests.

DEFINITION OF DONE

Affinity Board can organize existing project information without duplication.

FINAL REPORT

Return:
1. schema
2. source-link rules
3. constraints/indexes
4. tests/results
5. assumptions
6. unresolved issues
```

---

# 29. M11.2 — Create / Rename Affinity Group

## Objective

Implement group creation and naming operations.

## Approved Contracts

```text
createAffinityGroup(input)
renameAffinityGroup(input)
```

Create input:

```text
activityInstanceId
name
description optional
```

## Copy/Paste Prompt

```text
TASK ID: M11.2
TASK: Affinity Group Operations

Read first:

- /docs/11_API_CONTRACTS.md
- /docs/06_COURSE_ACTIVITY_WORKFLOWS.md

OBJECTIVE

Implement createAffinityGroup() and renameAffinityGroup().

CREATE

1. resolve authenticated actor.
2. validate Activity is Affinity-compatible.
3. validate actor can edit Activity.
4. create group with server-derived created_by.
5. assign sequence safely.

RENAME

1. validate Group belongs to accessible Activity.
2. validate edit authority.
3. update name/description only.
4. do not mutate linked source objects.

CURRICULUM RULE

Do not force predefined categories.
Teams should be able to discover natural Affinity groups.

TEST

- Team A creates group
- Team B denied
- removed member denied
- rename persists
- creator spoof denied

DEFINITION OF DONE

Teams can create and refine natural Affinity group labels safely.
```

---

# 30. M11.3 — Add / Move Affinity Item

## Objective

Implement collaborative grouping and movement.

## Approved Contract

```text
moveItemToAffinityGroup(input)
```

Input:

```text
itemId
targetGroupId
position
```

## Copy/Paste Prompt

```text
TASK ID: M11.3
TASK: Add / Move Affinity Item

Read first:

- /docs/11_API_CONTRACTS.md
- /docs/12_ACCEPTANCE_TESTS.md

OBJECTIVE

Implement:
- add Affinity item
- moveItemToAffinityGroup(input)

RULES

1. source entity accessible.
2. source entity belongs to compatible Project/Activity context.
3. target Group belongs to same Activity.
4. position validated.
5. moving an item changes grouping/position only.
6. moving does not duplicate Development Object.
7. moving does not mutate canonical Object type/content.

COLLABORATION

Optimistic UI may be used.
Server persistence remains authoritative.

TEST

AT-AFF-001:
group existing Problems/Solutions.
Verify same Development Object IDs.

Also test:
- Team B cannot move Team A item.
- cross-Activity move rejected.
- same source Object remains canonical after multiple group moves.

DEFINITION OF DONE

AT-AFF-001 passes.
```

---

# 31. M11.4 — Affinity Collaborative Movement

## Objective

Prevent silent loss when two Team members manipulate the board.

## Copy/Paste Prompt

```text
TASK ID: M11.4
TASK: Affinity Collaborative Movement

Read first:

- /docs/10_TECHNICAL_ARCHITECTURE.md
- /docs/12_ACCEPTANCE_TESTS.md

OBJECTIVE

Implement realtime/optimistic collaborative movement for Affinity.

REQUIREMENTS

1. two authorized Team A users can work concurrently.
2. server validates every persisted move.
3. Team B cannot receive private board events/state.
4. non-conflicting changes merge/persist.
5. conflicting updates must use deterministic conflict handling or explicit conflict detection.
6. silent overwrite is unacceptable.
7. canonical saved group/position lives in PostgreSQL.

TECHNICAL

Use the platform's approved realtime architecture.
Liveblocks may be used if consistent with M11 architecture, but do not make ephemeral state canonical.

TEST

AT-AFF-002:
- A1 moves Item X.
- A2 moves Item Y concurrently.
- both final movements survive.
- refresh shows canonical positions.

Add conflict case:
- A1 and A2 move same Item X nearly simultaneously.
- final state deterministic and no silent hidden data loss.

DEFINITION OF DONE

AT-AFF-002 passes.
```

---

# 32. M11.5 — Affinity to Invention Structure

## Objective

Turn confirmed Session 6 organization into persistent Project structure.

## Copy/Paste Prompt

```text
TASK ID: M11.5
TASK: Affinity → Invention Structure V1

Read first:

- /docs/05_DEVELOPMENT_PROJECT_MODEL.md
- /docs/06_COURSE_ACTIVITY_WORKFLOWS.md
- approved Session 6 curriculum

OBJECTIVE

Implement an explicit human-confirmed conversion path from Affinity organization to Project structure.

SUPPORTED TARGET OBJECT TYPES MAY INCLUDE

- SYSTEM
- SUBSYSTEM
- COMPONENT
- FUNCTION
- GAP

RULES

1. do not automatically convert every Affinity Group.
2. user/team explicitly confirms structural meaning.
3. create or link Development Objects as needed.
4. reuse existing Objects when already present.
5. create Object Relationships explicitly.
6. preserve source Affinity Group/Activity provenance.
7. do not delete Problems/Solutions when reorganizing.

OUTPUT

Compose `INVENTION_STRUCTURE` Artifact / Draft Version using M8 if this Artifact type is approved.
If exact Artifact type naming differs, use source-of-truth enum.

TEST

- group becomes System only after confirmation
- existing Component reused
- Problem/Solution IDs retained
- resulting Artifact references canonical structure
- no automatic category imposition

DEFINITION OF DONE

Session 6 organization becomes durable structured Project state.
```

---

# 33. M11.6 — Gap List Integration

## Objective

Create persistent Gaps discovered during Affinity analysis.

## Copy/Paste Prompt

```text
TASK ID: M11.6
TASK: Gap Identification & Gap List

Read first:

- /docs/05_DEVELOPMENT_PROJECT_MODEL.md
- /docs/22_CODEX_M8_PROMPTS.md
- approved Session 6 curriculum

OBJECTIVE

Implement Gap capture and GAP_LIST Artifact integration.

FLOW

1. identify unresolved/missing element.
2. explicitly create Development Object type GAP.
3. preserve Project/Workspace/creator.
4. link Gap to relevant System/Component/Function/Problem/Solution through existing relationship model where appropriate.
5. create/update GAP_LIST Artifact Draft using Artifact/Object Links.
6. register as Activity Output.

RULES

- no auto-generated Gap without explicit user action unless later AI milestone labels it correctly.
- do not duplicate same Gap merely because it appears in multiple views.

TEST

- create Gap G1
- link to relevant Component
- include G1 in GAP_LIST
- same G1 reused in Mind Map later
- Team B denied

DEFINITION OF DONE

Session 6 Gap List is structured, reusable Project data.
```

---

# 34. M11.7 — Mind Map Schema

## Objective

Create normalized Mind Map entities linked to Artifact Versions.

## Copy/Paste Prompt

```text
TASK ID: M11.7
TASK: Mind Map Schema

Read first:

- /docs/08_DATA_MODEL_SCHEMA.md
- /docs/22_CODEX_M8_PROMPTS.md
- /docs/06_COURSE_ACTIVITY_WORKFLOWS.md

OBJECTIVE

Create:
- mind_maps
- mind_map_nodes
- mind_map_edges

MIND_MAPS

- id
- artifact_id
- artifact_version_id
- root_node_id

NODES

- id
- mind_map_id
- node_type
- label
- development_object_id nullable
- parent_node_id nullable
- position_data
- metadata
- created_by

EDGES

- id
- mind_map_id
- source_node_id
- target_node_id
- edge_type
- label
- metadata

RULES

1. Mind Map belongs to MIND_MAP Artifact/Version.
2. node belongs to same Mind Map.
3. parent node belongs to same Mind Map.
4. edge endpoints belong to same Mind Map.
5. Development Object reference must be authorized and Project-compatible.
6. creator server-derived.
7. root_node_id must belong to Mind Map.
8. indexes support node/edge loading.

TEST

- valid root
- valid child hierarchy
- valid cross-edge
- invalid cross-map edge rejected
- Team B Object link rejected

DEFINITION OF DONE

Canonical normalized Mind Map storage exists.
```

---

# 35. M11.8 — Create Mind Map

## Objective

Implement `createMindMap(input)` using M8 Artifact Versioning.

## Approved Contract

Creates:

- Artifact,
- Draft Artifact Version,
- Mind Map root structure.

## Copy/Paste Prompt

```text
TASK ID: M11.8
TASK: Create Mind Map

Read first:

- /docs/11_API_CONTRACTS.md
- /docs/22_CODEX_M8_PROMPTS.md
- approved Session 7 curriculum

OBJECTIVE

Implement createMindMap() transactionally.

FLOW

1. authenticate actor.
2. validate Activity/Project/Workspace.
3. create MIND_MAP Artifact.
4. create Draft Artifact Version.
5. create mind_maps row linked to Artifact/Version.
6. create root node representing central invention according to approved model.
7. set root_node_id.
8. register Mind Map as Activity output where configured.

INPUT CONTEXT

Use Invention Structure V1 + Gap List as approved Activity inputs.
Do not copy them into disconnected records.

TRANSACTION

If any core creation step fails:
rollback all.

TEST

- Team A creates map
- Artifact exists
- Draft Version exists
- root exists
- same Project/Workspace
- Team B denied

DEFINITION OF DONE

Mind Map begins as an M8-versioned structured Artifact.
```

---

# 36. M11.9 — Add / Update Mind Map Node

## Objective

Implement typed structured nodes.

## Approved Contract

```text
addMindMapNode(input)
updateMindMapNode(input)
```

Add input:

```text
mindMapId
nodeType
label
parentNodeId optional
developmentObjectId optional
positionData
```

## Copy/Paste Prompt

```text
TASK ID: M11.9
TASK: Mind Map Node Operations

Read first:

- /docs/11_API_CONTRACTS.md
- /docs/12_ACCEPTANCE_TESTS.md
- approved Session 7 curriculum

REQUIRED NODE TYPES

- SYSTEM
- SUBSYSTEM
- COMPONENT
- FUNCTION
- PROBLEM
- SOLUTION
- GAP

OBJECTIVE

Implement add/update operations.

ADD

1. validate Mind Map access.
2. validate node type.
3. validate parent.
4. validate optional Development Object.
5. persist position_data.
6. creator server-derived.

UPDATE

Allow controlled changes such as:
- label,
- parent,
- position,
- approved metadata/classification.

Do not allow:
- moving node to another inaccessible Mind Map,
- changing linked canonical Object to unrelated Team data,
- spoofing creator.

TEST

AT-MM-001:
create all required node types.

AT-MM-002:
link node to existing Development Object.

Verify same Object ID.

DEFINITION OF DONE

AT-MM-001 and AT-MM-002 pass.
```

---

# 37. M11.10 — Connect Mind Map Nodes

## Objective

Create typed visual edges without corrupting canonical Project relationships.

## Approved Contract

```text
connectMindMapNodes(input)
```

## Copy/Paste Prompt

```text
TASK ID: M11.10
TASK: Mind Map Edge Operations

OBJECTIVE

Implement typed edge creation/update/removal.

RULES

1. source and target nodes exist.
2. source and target belong to same Mind Map.
3. actor can edit Map.
4. edge_type validated.
5. label optional according to schema.
6. no unauthorized cross-Team nodes.
7. deleting visual edge does not automatically delete canonical Development Object Relationship.

CANONICAL RELATIONSHIP

If user explicitly chooses to synchronize edge into Development Object Relationship:
- use separate explicit operation,
- validate both linked Development Objects,
- preserve Project semantics.

Do not auto-sync every visual edge.

TEST

- connect Component → Function visual edge
- cross-map edge rejected
- edge deletion leaves Development Objects untouched
- canonical relation untouched unless explicit action

DEFINITION OF DONE

Visual map relationships remain safe and distinct from canonical Project relationships.
```

---

# 38. M11.11 — Remove Mind Map Node

## Objective

Enforce AT-MM-003.

## Approved Contract

```text
removeMindMapNode(input)
```

Rule:

```text
Must not delete underlying Development Object unless explicitly requested through separate operation.
```

## Copy/Paste Prompt

```text
TASK ID: M11.11
TASK: Remove Mind Map Node

Read first:

- /docs/11_API_CONTRACTS.md
- /docs/12_ACCEPTANCE_TESTS.md

OBJECTIVE

Remove a visual node safely.

FLOW

1. validate actor edit authority.
2. validate node belongs to Mind Map.
3. handle child nodes/edges according to approved map behavior.
4. remove/archive visual node record as appropriate.
5. DO NOT delete linked Development Object.
6. DO NOT archive linked Development Object.
7. DO NOT delete unrelated canonical Object Relationships.

TEST

AT-MM-003:
- create Development Object C1.
- create map node N1 linked to C1.
- remove N1.
- verify C1 still exists and is unchanged.

Priority: BLOCKER.

Also test:
- Team B cannot remove Team A node.
- root-node deletion behavior follows approved policy.

DEFINITION OF DONE

AT-MM-003 passes.
```

---

# 39. M11.12 — React Flow Integration

## Objective

Implement the structured Mind Map interaction layer.

## Copy/Paste Prompt

```text
TASK ID: M11.12
TASK: React Flow Mind Map UI

Read first:

- /docs/10_TECHNICAL_ARCHITECTURE.md
- approved Session 7 curriculum

OBJECTIVE

Implement the Mind Map editor using React Flow.

REQUIREMENTS

1. render normalized nodes/edges.
2. node type visually distinguishable.
3. central invention/root clear.
4. support parent/branch structure.
5. support cross-connections.
6. drag/move nodes.
7. connect nodes.
8. edit labels where authorized.
9. classification display for:
   - Core
   - Supporting
   - Optional/Future
10. preserve Development Object reference indication.

IMPORTANT

React Flow UI state is not canonical saved Project state.
All durable changes must be normalized/validated before PostgreSQL save.

SECURITY

Do not load inaccessible nodes/Objects into the client.

OUT OF SCOPE

- patent-specific claim map,
- detailed architecture CAD,
- prototype design.

DEFINITION OF DONE

Team can visually build the Session 7 invention map using structured project data.
```

---

# 40. M11.13 — Liveblocks Collaborative Room

## Objective

Enable high-frequency Team collaboration without replacing canonical persistence.

## Copy/Paste Prompt

```text
TASK ID: M11.13
TASK: Mind Map Liveblocks Collaboration

Read first:

- /docs/10_TECHNICAL_ARCHITECTURE.md
- /docs/13_CODEX_IMPLEMENTATION_PLAN.md
- /docs/12_ACCEPTANCE_TESTS.md

OBJECTIVE

Use Liveblocks for high-frequency collaborative Mind Map state.

ROOM AUTHORIZATION

Room access must derive from:
- authenticated user,
- Mind Map,
- Workspace,
- Project,
- Team membership/scope.

Never trust client-provided room authorization.

LIVE STATE MAY INCLUDE

- node positions,
- in-progress node/edge edits,
- presence/cursors if implemented.

CANONICAL STATE

PostgreSQL remains source of truth for saved:
- nodes,
- edges,
- Artifact Version checkpoints.

SECURITY

- Team B cannot join Team A room.
- removed Team A member loses future room access.
- room ID alone must not authorize.

TEST

- A1/A2 collaborate.
- B1 denied.
- removed A1 denied after membership removal.
- reconnect restores canonical saved state plus permitted live state.

DEFINITION OF DONE

Realtime collaboration exists without weakening Team isolation or canonical persistence.
```

---

# 41. M11.14 — Save Mind Map Draft

## Objective

Normalize collaborative state into PostgreSQL and save Draft Artifact state.

## Approved Contract

```text
saveMindMapDraft(input)
```

## Copy/Paste Prompt

```text
TASK ID: M11.14
TASK: Save Mind Map Draft

Read first:

- /docs/11_API_CONTRACTS.md
- /docs/22_CODEX_M8_PROMPTS.md

OBJECTIVE

Implement saveMindMapDraft().

FLOW

1. authenticate actor.
2. authorize Mind Map edit.
3. read/receive collaborative state through validated server boundary.
4. normalize nodes/edges.
5. validate every linked Development Object.
6. persist canonical mind_map_nodes/mind_map_edges.
7. update Draft Artifact Version snapshot/checkpoint state according to M8 Draft rules.
8. protect against stale writes.
9. return saved canonical revision/version token.

CONFLICT

Silent overwrite prohibited.

Use:
- optimistic revision/version token,
- or repository-approved conflict strategy.

TEST

- A1 saves Draft.
- A2 stale save receives conflict or safe merge.
- refresh loads canonical saved map.
- Team B save denied.

DEFINITION OF DONE

Live collaborative state can be safely checkpointed into canonical PostgreSQL state.
```

---

# 42. M11.15 — Create Mind Map Version

## Objective

Create immutable Artifact Version checkpoint from the normalized map.

## Approved Contract

```text
createMindMapVersion(input)
```

## Copy/Paste Prompt

```text
TASK ID: M11.15
TASK: Create Mind Map Version

Read first:

- /docs/11_API_CONTRACTS.md
- /docs/22_CODEX_M8_PROMPTS.md

OBJECTIVE

Create immutable Mind Map checkpoint/version.

FLOW

1. ensure latest collaborative state is normalized/saved.
2. validate actor.
3. create new Artifact Version using M8.
4. create/associate canonical Mind Map snapshot representation.
5. preserve previous Version unchanged.
6. server assigns Version number.
7. record change summary/provenance.

RULES

- approved Version immutable.
- new revision creates new Version.
- do not overwrite prior Version's map data.
- Development Object identities remain stable across map Versions.

TEST

- V1 saved
- create V2
- V1 unchanged
- same Component Object linked in V1/V2
- Team B denied

DEFINITION OF DONE

Mind Map history uses the existing Artifact Version model correctly.
```

---

# 43. M11.16 — Core / Supporting / Future Classification

## Objective

Implement Session 7 essential-structure classification.

## Copy/Paste Prompt

```text
TASK ID: M11.16
TASK: Essential Structure Classification

Read first:

- approved Professional Course Session 7 curriculum
- /docs/05_DEVELOPMENT_PROJECT_MODEL.md

OBJECTIVE

Support broad classification of major mapped elements:

- Core
- Supporting
- Optional/Future

RULES

1. classification is human-assigned.
2. classification belongs to the mapped element/context.
3. do not confuse with Development Object lifecycle status.
4. do not automatically delete/exclude Optional/Future Objects.
5. preserve classification in map/Artifact snapshot.
6. where approved, also persist structured metadata on relevant Project representation.

CURRICULUM

Core:
must exist for core function/inventive concept.

Supporting:
supports operation/control/usability/safety/reliability.

Optional/Future:
can be developed later.

IMPORTANT

This is minimum essential invention structure, not detailed MVP/prototype planning.

TEST

- classify System S1 as Core
- Component C2 as Supporting
- Feature/Object F3 as Optional/Future
- classifications persist after reload/version
- canonical Object status remains unchanged

DEFINITION OF DONE

The Team can identify essential invention structure without corrupting object lifecycle semantics.
```

---

# 44. M11.17 — Session 6 Artifact Outputs

## Objective

Produce durable outputs from Affinity session.

## Copy/Paste Prompt

```text
TASK ID: M11.17
TASK: Session 6 Artifact Outputs

Read first:

- /docs/06_COURSE_ACTIVITY_WORKFLOWS.md
- /docs/22_CODEX_M8_PROMPTS.md
- approved Session 6 curriculum

OBJECTIVE

Produce:

1. Invention Structure V1
2. Gap List

ARCHITECTURE

Use:
- Development Objects
- Object Relationships
- Artifact / Artifact Versions
- Artifact/Object Links

REGISTER

Both outputs as Session 6 Activity Outputs.

REVIEW

If Activity Definition requires review/approval:
use M8 workflow.

DEPENDENCY

Session 7 should consume approved/current:
- Invention Structure V1
- Gap List

TEST

- same Problems/Solutions referenced
- Gap IDs stable
- outputs survive logout
- approved outputs satisfy Session 7 dependency

DEFINITION OF DONE

Session 6 outputs are durable, versioned and reusable.
```

---

# 45. M11.18 — Session 7 Artifact Outputs

## Objective

Produce the approved Session 7 outputs.

## Copy/Paste Prompt

```text
TASK ID: M11.18
TASK: Session 7 Artifact Outputs

Read first:

- /docs/06_COURSE_ACTIVITY_WORKFLOWS.md
- approved Session 7 curriculum
- /docs/22_CODEX_M8_PROMPTS.md

OBJECTIVE

Produce:

- Invention Mind Map
- Minimum Essential Invention Structure
- Invention Concept V1

REQUIREMENTS

MIND MAP
- MIND_MAP Artifact
- normalized nodes/edges
- versioned snapshot

MINIMUM ESSENTIAL STRUCTURE
- use approved Artifact/Object structure if source docs define a specific Artifact type.
- otherwise use structured Project output compatible with existing schema and flag missing enum rather than invent one.

INVENTION CONCEPT V1
- use existing approved Artifact/Project model.
- preserve links to Systems/Subsystems/Components/Functions and relevant Problems/Solutions/Gaps.

REGISTER

Outputs as Activity Outputs.

DEPENDENCY

Invention Concept V1 becomes baseline input entering patent-literacy/patent-analysis stages according to curriculum.

Do not implement Patent Workspace yet.

DEFINITION OF DONE

Session 7 creates durable structured outputs ready for Session 8.
```

---

# 46. M11.19 — Affinity RLS

## Objective

Protect Affinity data at database boundary.

## Copy/Paste Prompt

```text
TASK ID: M11.19
TASK: Affinity RLS

OBJECTIVE

Implement RLS for:
- affinity_groups
- affinity_group_items

RULES

- Activity/Workspace/Project/Team scope required.
- Team B cannot read Team A groups/items.
- removed member cannot mutate Team A Board.
- item source references do not bypass source-entity privacy.
- normal client cannot spoof created_by/added_by.
- direct group ID cannot bypass authorization.

TEST

- Team B SELECT denied.
- Team B INSERT/MOVE denied.
- removed member denied.
- cross-Team Object item insert denied.

DEFINITION OF DONE

Affinity organization cannot leak Project data across Team boundaries.
```

---

# 47. M11.20 — Mind Map RLS

## Objective

Protect normalized Mind Map data and collaborative room authorization.

## Copy/Paste Prompt

```text
TASK ID: M11.20
TASK: Mind Map RLS

OBJECTIVE

Implement RLS for:
- mind_maps
- mind_map_nodes
- mind_map_edges

RULES

1. access follows underlying Artifact + Workspace + Project.
2. Team B denied Team A map.
3. removed Team member denied future map access.
4. Personal map remains private where applicable.
5. Development Object links must not expose inaccessible Objects.
6. direct node/edge IDs cannot bypass authorization.
7. creator spoof blocked.
8. normal client cannot reassign map to another Artifact/Version.
9. room authorization must reuse same scope.

ATTACKS

- B1 exact Map ID
- B1 exact Node ID
- B1 exact Edge ID
- B1 joins Liveblocks room
- removed A1 joins room
- client changes development_object_id to Team B/A inaccessible resource

EXPECTED

Denied.

DEFINITION OF DONE

Visual/realtime layers do not create a privacy bypass.
```

---

# 48. M11.21 — AT-AFF-001 and AT-AFF-002

## Objective

Implement Affinity acceptance tests.

## Copy/Paste Prompt

```text
TASK ID: M11.21
TASK: Affinity Acceptance Tests

Read first:

- /docs/12_ACCEPTANCE_TESTS.md
- /docs/25_CODEX_M11_PROMPTS.md

AT-AFF-001 — Group Existing Objects

Team groups existing Problems/Solutions.

Verify:
- Affinity items link canonical Objects.
- no duplicate Problem/Solution rows.
- moving between Groups preserves Object IDs.

Expected: PASS.

AT-AFF-002 — Collaborative Movement

A1 and A2 update Board concurrently.

Verify:
- both non-conflicting changes survive.
- refresh shows canonical state.
- conflict case does not silently overwrite.

Expected: PASS.

FINAL REPORT

Return test matrix and results.
```

---

# 49. M11.22 — AT-MM-001 to AT-MM-004

## Objective

Implement full Mind Map acceptance suite.

## Copy/Paste Prompt

```text
TASK ID: M11.22
TASK: Mind Map Acceptance Tests

Read first:

- /docs/12_ACCEPTANCE_TESTS.md
- /docs/25_CODEX_M11_PROMPTS.md

AT-MM-001

Create structured nodes:
- System
- Subsystem
- Component
- Function
- Problem
- Solution
- Gap

Expected: PASS.

AT-MM-002

Node references existing Development Object.

Expected:
same Object ID.

AT-MM-003

Delete visual Node linked to canonical Object.

Expected:
canonical Object remains unchanged.

Priority:
BLOCKER.

AT-MM-004

Live collaborative state saved as Draft Artifact Version.

Expected:
- canonical PostgreSQL state saved,
- Draft Version/checkpoint exists,
- reload works.

FINAL REPORT

Return test matrix and PASS/FAIL.
```

---

# 50. M11.23 — AT-CON-001 Collaborative Edit

## Objective

Prove simultaneous Mind Map/Affinity edits cannot silently overwrite.

## Acceptance Rule

Two users edit same Draft.

System must:

```text
merge safely through collaboration layer
OR
detect version conflict
```

Silent overwrite is unacceptable.

## Copy/Paste Prompt

```text
TASK ID: M11.23
TASK: AT-CON-001 Collaborative Edit

Read first:

- /docs/12_ACCEPTANCE_TESTS.md
- /docs/10_TECHNICAL_ARCHITECTURE.md

SCENARIO A — DIFFERENT NODES

A1 moves Node N1.
A2 edits Node N2 concurrently.

Expected:
both changes survive.

SCENARIO B — SAME NODE

A1 and A2 edit/move same Node from same starting revision.

Expected:
- collaborative merge if supported,
OR
- explicit conflict/deterministic resolution.

No silent hidden overwrite.

SCENARIO C — SAVE RACE

A1 and A2 checkpoint nearly simultaneously.

Expected:
- version/revision protection,
- no loss of canonical changes,
- clear resulting checkpoint order.

PRIORITY

HIGH

DEFINITION OF DONE

AT-CON-001 passes for M11 collaborative editing.
```

---

# 51. M11.24 — Professional Session 6 Integration Scenario

## Objective

Validate approved Affinity curriculum flow.

## Copy/Paste Prompt

```text
TASK ID: M11.24
TASK: Professional Session 6 Integration

Read first:

- approved Professional Course Session 6
- /docs/06_COURSE_ACTIVITY_WORKFLOWS.md

SCENARIO

1. Team A starts with Problems, Solutions, Features, Decisions, Components.
2. Start Affinity Activity.
3. collect existing canonical objects.
4. spread as Affinity items.
5. group by natural affinity.
6. rename groups.
7. move items collaboratively.
8. identify relationships.
9. explicitly confirm selected groups as Systems/Subsystems.
10. connect Problem → Solution → Function → Component using canonical relationships.
11. identify Gap Objects.
12. create Invention Structure V1.
13. create Gap List.
14. register both as Activity Outputs.
15. review/approve if configured.

VERIFY

- no source Object duplication,
- group movement persists,
- same IDs carry into outputs,
- Team B denied.

DEFINITION OF DONE

Session 6 workflow is represented natively and structurally.
```

---

# 52. M11.25 — Professional Session 7 Integration Scenario

## Objective

Validate approved Mind Mapping curriculum flow.

## Copy/Paste Prompt

```text
TASK ID: M11.25
TASK: Professional Session 7 Integration

Read first:

- approved Professional Course Session 7
- /docs/06_COURSE_ACTIVITY_WORKFLOWS.md

SCENARIO

1. Session 7 consumes approved Invention Structure V1 + Gap List.
2. create Mind Map.
3. central invention root.
4. add Main Systems.
5. add Subsystems.
6. add Components.
7. add Functions.
8. bring in Problems/Solutions.
9. create cross-connections.
10. place existing Gap Objects.
11. collaborate with two Team members.
12. classify major elements:
    Core / Supporting / Optional-Future.
13. save Draft checkpoint.
14. create new immutable Version.
15. produce Invention Mind Map output.
16. produce Minimum Essential Invention Structure.
17. produce Invention Concept V1 according to approved model.
18. register outputs.
19. prepare dependency for Session 8.

VERIFY

- existing Objects reused.
- visual node removal never deletes canonical Object.
- collaboration survives reload.
- Team B denied.
- no Patent Workspace implemented.

DEFINITION OF DONE

Session 7 converts Session 6 structure into a connected whole-invention map.
```

---

# 53. M11.26 — Cross-Team / Realtime Leakage Tests

## Objective

Attack M11's database and collaboration boundaries.

## Copy/Paste Prompt

```text
TASK ID: M11.26
TASK: M11 Leakage Tests

FIXTURES

Team A:
- Affinity Board A
- Mind Map A
- Liveblocks room A

Team B:
- Student B1

ATTEMPTS AS B1

- fetch Affinity Group A
- move Affinity Item A
- fetch Mind Map A
- fetch exact Node A
- fetch exact Edge A
- update Node A
- save Map A Draft
- create Map A Version
- join Liveblocks room A
- subscribe to Team A collaborative updates
- link Team A Map to Team B Object
- direct DB query

REMOVED TEAM A MEMBER

Attempt same future-access paths.

EXPECTED

All unauthorized paths denied.

DEFINITION OF DONE

No cross-Team or removed-member M11 leakage remains.
```

---

# 54. M11.27 — M11 Security & Integrity Hardening

## Objective

Review M11 before Evidence/Patent/File systems are introduced.

## Copy/Paste Prompt

```text
TASK ID: M11.27
TASK: M11 Security & Integrity Hardening

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
- /docs/25_CODEX_M11_PROMPTS.md

OBJECTIVE

Perform final M11 security/integrity hardening.

VERIFY

1. Affinity items reference canonical Objects.
2. no duplicate Problems/Solutions from grouping.
3. collaborative movements persist without silent loss.
4. Mind Map uses normalized PostgreSQL data.
5. React Flow is not canonical persistence.
6. Liveblocks is not canonical persistence.
7. Team B cannot access Team A collaboration room/data.
8. removed member loses future collaborative access.
9. nodes can link canonical Objects.
10. deleting visual node never deletes canonical Object.
11. edges do not silently mutate canonical Project relationships.
12. Draft save detects conflicts.
13. immutable checkpoint Version works.
14. Core/Supporting/Future classification does not overwrite Object lifecycle state.
15. Session 6 outputs feed Session 7.
16. Session 7 outputs are ready for Session 8.
17. no M12+ Evidence/Patent/File feature implemented.

RUN

pnpm lint
pnpm typecheck
pnpm test:unit
pnpm test:integration
pnpm test:e2e
pnpm build
plus RLS, collaboration, and concurrency tests.

DEFINITION OF DONE

- AT-AFF-001 PASS
- AT-AFF-002 PASS
- AT-MM-001 PASS
- AT-MM-002 PASS
- AT-MM-003 PASS
- AT-MM-004 PASS
- AT-CON-001 PASS
- Session 6 integration PASS
- Session 7 integration PASS
- zero known cross-Team realtime leak
- zero canonical Object deletion through visual action
- no M12+ scope creep

FINAL REPORT

Return:
1. security review
2. integrity review
3. collaboration review
4. issues found
5. issues fixed
6. remaining issues
7. BLOCKER status
8. tests/results
9. recommendation: READY FOR M12 or NOT READY FOR M12
```

---

# 55. Affinity Group vs System

An Affinity Group is not automatically a System.

Affinity is exploratory organization.

A System is a persistent Development Object.

Required distinction:

```text
Affinity Group
→ human interpretation
→ optional explicit SYSTEM Object
```

Do not auto-promote every group.

---

# 56. Affinity Item vs Project Object

An Affinity item should be a reference.

Example:

```text
Affinity Item A
→ Problem P12
```

Moving Item A between groups must not:

- clone P12,
- change P12 ID,
- change P12 content.

---

# 57. Mind Map Node vs Canonical Object

A single Development Object could potentially appear in more than one map/version/context.

Therefore:

```text
Node ID
≠
Object ID
```

The link is explicit.

---

# 58. Mind Map Node Deletion

Node deletion is visual.

Canonical object deletion is a separate high-risk business operation.

Do not combine them.

---

# 59. Mind Map Versioning

A Mind Map version is a snapshot/checkpoint.

New Version:

```text
V1
→ V2
```

does not recreate canonical Development Objects.

The same Component C5 may be referenced from both versions.

---

# 60. Position Data

`position_data` stores visual layout.

Do not treat position as semantic Project structure.

Moving a Component visually should not change:

- System ownership,
- canonical relationship,
- classification,

unless user explicitly performs those separate semantic edits.

---

# 61. Cross-Connections

Mind Map supports:

- branch hierarchy,
- cross-connections.

A cross-connection is visually useful.

Do not assume every cross-connection should become a canonical `development_object_relationship`.

Explicit confirmation is safer unless source docs say otherwise.

---

# 62. Core / Supporting / Future

Classification is conceptual importance within the current invention structure.

It must not automatically mean:

```text
Core = approved
Supporting = less verified
Future = rejected
```

Those are different dimensions.

---

# 63. Search + AI Placeholder

Session 7 curriculum includes targeted Search + AI for:

- missing component,
- unclear function,
- weak connection,
- unresolved gap.

M11 should preserve UI/data extension points only.

M12/M14 own research/evidence/AI.

Do not call AI from M11.

---

# 64. Instructor Role in Affinity

Course workflow says Instructor should guide grouping without imposing categories prematurely.

The platform should permit Master to observe/comment according to approved collaboration permissions.

Do not automatically allow Master to rewrite Team structure without explicit edit authority.

---

# 65. Liveblocks Presence

If presence/cursors are implemented:

- they should be visible,
- they should respect room authorization,
- they are ephemeral,
- they must not be treated as Project history.

---

# 66. Realtime Disconnect

A lost Liveblocks connection must not corrupt canonical saved data.

On reconnect:

- load authorized canonical state,
- reconcile permitted live state,
- avoid overwriting newer saved revision.

---

# 67. Artifact Version Snapshot

Mind Map Artifact Version should contain enough normalized snapshot information to reconstruct the historical visual/structural state.

Do not rely on external Liveblocks room history as the only reconstruction source.

---

# 68. M11 Expected Repository Additions

Conceptually:

```text
features/
├── affinity/
│   ├── groups/
│   ├── items/
│   ├── collaboration/
│   ├── promotion/
│   └── access/
└── mind-map/
    ├── editor/
    ├── nodes/
    ├── edges/
    ├── collaboration/
    ├── persistence/
    ├── versions/
    └── access/

lib/
├── permissions/
│   ├── affinity.ts
│   └── mind-map.ts
├── collaboration/
│   ├── liveblocks-auth.ts
│   └── conflict.ts
└── normalization/
    └── mind-map.ts

supabase/
├── migrations/
│   ├── ...affinity_groups...
│   ├── ...affinity_group_items...
│   ├── ...mind_maps...
│   ├── ...mind_map_nodes...
│   ├── ...mind_map_edges...
│   └── ...m11_rls...
└── tests/
    └── rls/
        ├── affinity...
        └── mind-map...

tests/
├── unit/
│   ├── affinity/
│   └── mind-map/
├── integration/
│   ├── session6/
│   ├── session7/
│   └── collaboration/
└── e2e/
    └── mind-map-collaboration.spec.ts
```

Exact paths may vary.

---

# 69. M11 Completion Gate

M11 is complete only when:

```text
[ ] affinity_groups exists
[ ] affinity_group_items exists
[ ] createAffinityGroup() implemented
[ ] renameAffinityGroup() implemented
[ ] moveItemToAffinityGroup() implemented

[ ] Affinity items reference canonical Objects
[ ] grouping does not duplicate Problems/Solutions
[ ] collaborative movement works
[ ] silent loss prevented

[ ] Invention Structure V1 output supported
[ ] GAP Objects supported
[ ] GAP_LIST Artifact supported

[ ] mind_maps exists
[ ] mind_map_nodes exists
[ ] mind_map_edges exists

[ ] createMindMap() implemented
[ ] addMindMapNode() implemented
[ ] updateMindMapNode() implemented
[ ] connectMindMapNodes() implemented
[ ] removeMindMapNode() implemented
[ ] saveMindMapDraft() implemented
[ ] createMindMapVersion() implemented

[ ] node types System/SubSystem/Component/Function/Problem/Solution/Gap supported
[ ] node links existing Development Object
[ ] deleting node does not delete Object

[ ] React Flow UI works
[ ] Liveblocks Team collaboration works
[ ] Team B cannot join Team A room
[ ] PostgreSQL remains canonical
[ ] Draft save conflict protection works
[ ] immutable Artifact Version checkpoints work

[ ] Core / Supporting / Optional-Future classification supported

[ ] Session 6 integration PASS
[ ] Session 7 integration PASS

[ ] AT-AFF-001 PASS
[ ] AT-AFF-002 PASS
[ ] AT-MM-001 PASS
[ ] AT-MM-002 PASS
[ ] AT-MM-003 PASS
[ ] AT-MM-004 PASS
[ ] AT-CON-001 PASS

[ ] lint passes
[ ] typecheck passes
[ ] unit tests pass
[ ] integration tests pass
[ ] E2E tests pass
[ ] RLS tests pass
[ ] collaboration tests pass
[ ] concurrency tests pass
[ ] build passes

[ ] no M12+ feature implemented prematurely
[ ] Codex reports READY FOR M12
```

Any visual-node deletion that deletes a canonical Development Object is:

```text
BLOCKER
```

Any cross-Team Liveblocks/board access is:

```text
BLOCKER
```

Any silent collaborative overwrite is:

```text
HIGH / BLOCKER if data loss affects canonical state
```

---

# 70. Recommended Commit Sequence

Example:

```text
feat(affinity): add Affinity schema
feat(affinity): add group/item operations
feat(collaboration): add Affinity realtime movement
feat(structure): add Affinity-to-Project structure promotion
feat(gaps): add Gap List integration
feat(mind-map): add normalized Mind Map schema
feat(mind-map): add create/node/edge operations
feat(mind-map): add safe node removal
feat(ui): add React Flow Mind Map editor
feat(collaboration): add Liveblocks Mind Map room
feat(mind-map): add canonical Draft save
feat(mind-map): add immutable checkpoint versions
feat(structure): add essential-structure classification
feat(artifacts): add Session 6/7 outputs
feat(security): add Affinity/Mind Map RLS
test(affinity): add AT-AFF suite
test(mind-map): add AT-MM suite
test(concurrency): add AT-CON-001
test(session6): add Affinity integration
test(session7): add Mind Map integration
test(security): add collaboration leakage tests
chore(security): complete M11 hardening
```

---

# 71. M11 Non-Goals

Do not accept these as "helpful additions" during M11:

- Evidence records,
- patent records,
- Patent Search Log,
- private file system,
- signed file access,
- AI Assistant,
- automated gap generation by AI,
- automated patent search,
- generic Sharing,
- detailed prototype design,
- MVP backlog,
- Kanban,
- Scrum execution,
- architecture CAD tool,
- automatic canonical relationship creation from every visual edge.

---

# 72. Potential M11 Ambiguities Codex Must Flag

Do not silently decide if approved docs do not resolve:

- whether Affinity item may reference both Development Object and Brainstorm Entry simultaneously,
- whether one source item may appear in multiple groups,
- whether groups can be nested,
- exact `position` representation,
- whether Group rename/history needs versioning,
- whether Group → System promotion creates new Object or links existing one,
- exact Artifact type for Invention Structure V1 if enum naming differs,
- exact Artifact type for Minimum Essential Invention Structure,
- whether Mind Map root is a special node type,
- exact Mind Map node-type enum storage names,
- exact edge_type vocabulary,
- whether visual edges auto-create canonical Object Relationships,
- whether node hierarchy auto-creates BELONGS_TO relationships,
- whether deleting parent deletes child visual nodes or reparents them,
- whether root node may be deleted,
- whether same Development Object can appear more than once in one map,
- exact mapping of Core/Supporting/Optional-Future classification,
- whether classification applies to node, Object, or both,
- exact Liveblocks presence features,
- checkpoint frequency,
- autosave frequency,
- who may create immutable Mind Map Version,
- whether Master may edit Team Mind Map directly,
- whether Mentor may edit,
- how Liveblocks room IDs are generated,
- how stale offline edits are reconciled.

If unresolved:

```text
STOP → FLAG → ASK
```

---

# 73. Recommended Safe Defaults for Purely Technical Decisions

Only where they do not alter approved product policy:

- UUID IDs,
- canonical source references instead of copies,
- PostgreSQL canonical state,
- Liveblocks ephemeral/realtime state,
- React Flow visual layer,
- server-validated room auth,
- optimistic UI with authoritative persistence,
- explicit conflict tokens for Draft save,
- immutable M8 Artifact checkpoints,
- visual deletion does not cascade to canonical Project Objects,
- cross-Team access fails closed,
- same Development Object may remain stable across multiple Artifact Versions,
- no M12 data tables created early.

---

# 74. Review Checklist for Ahmad/FICI

Before implementation, confirm M11 reflects the intended Sessions 6 and 7:

```text
1. Session 6 groups existing information instead of recreating it.

2. Affinity cards reference existing Problems/Solutions/Objects.

3. Teams create natural groups rather than using mandatory predefined categories.

4. Affinity organization can be converted into Systems/Subsystems explicitly.

5. Session 6 produces Invention Structure V1 + Gap List.

6. Session 7 starts from those outputs.

7. Mind Map centers the invention and branches into Systems → Subsystems → Components → Functions.

8. Problems, Solutions and Gaps can appear on the Map using existing Object IDs.

9. Cross-connections are supported.

10. React Flow is used for Mind Map interaction.

11. Liveblocks handles realtime collaboration.

12. PostgreSQL remains canonical.

13. Deleting a visual node never deletes the underlying Project Object.

14. Mind Map can be saved as Draft and versioned through M8.

15. Major elements can be classified Core / Supporting / Optional-Future.

16. Session 7 outputs Invention Mind Map + Minimum Essential Structure + Invention Concept V1.

17. Evidence, Patents and AI remain for later milestones.
```

---

# 75. Next File After M11

After M11 has actually been:

```text
IMPLEMENTED
→ TESTED
→ SECURITY-REVIEWED
→ COMMITTED
```

create:

# `26_CODEX_M12_PROMPTS.md`

M12 will cover:

```text
Evidence Records
Evidence Links
Files
File Links
Private Storage
Signed Access
Patent Records
Patent Search Logs
PATENTSCOPE / USPTO / Google Patents Links
Patent Workspace
Source vs Analysis Separation
Evidence Verification States
```

M12 will add evidence-backed research to the structured invention model created in M6–M11.

---

# 76. Final Execution Rule

For M11:

```text
AFFINITY SCHEMA
→ GROUP OPERATIONS
→ ITEM MOVEMENT
→ COLLABORATION
→ INVENTION STRUCTURE
→ GAP LIST
→ MIND MAP SCHEMA
→ CREATE MAP
→ NODES
→ EDGES
→ SAFE NODE REMOVAL
→ REACT FLOW
→ LIVEBLOCKS
→ CANONICAL DRAFT SAVE
→ VERSION CHECKPOINT
→ ESSENTIAL STRUCTURE CLASSIFICATION
→ SESSION 6 OUTPUTS
→ SESSION 7 OUTPUTS
→ RLS
→ ACCEPTANCE TESTS
→ CONCURRENCY
→ SECURITY HARDENING
```

Do not skip directly to Evidence, Patent or AI systems.

---

# End of Document

**Current Status:** Draft v0.1 — Ready for Ahmad/FICI review.  
**Execution Step After M10 Completion:** Start with **M11.1 — Affinity Schema**.
