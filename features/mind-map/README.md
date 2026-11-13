# Mind Map storage (M11.7)

Normalized visual maps bind to a MIND_MAP Artifact and its exact Version. Roots,
parents and endpoints use same-map composite foreign keys. A nullable root allows
transactional map/node/root creation without disabling constraints. References
use RESTRICT; deleting a leaf or visual edge never deletes canonical Objects or
Project relationships. Repeated Object references are intentionally allowed.

Node/edge types are bounded nonblank extensible text, not a new product enum.
SYSTEM, SUBSYSTEM, COMPONENT, FUNCTION, PROBLEM, SOLUTION and GAP are supported.
Root deletion workflow, self-edge semantics, later coordinate conventions
and Core/Supporting/Future classification remain deferred. Position and metadata
are JSON objects; no configuration vocabulary is invented. Edge label is optional.

All three tables have RLS and no ordinary client grants. M11.7 added no operation,
UI, collaboration room or save/checkpoint path. M11.8 initialization is described
below; later operations must validate current Project/Workspace/Team access and Object scope before writes;
M11.20 owns full read RLS. Artifact/Version identity cannot be reassigned on a map.
Existing M8 immutable Version bodies and privacy are unchanged.

## M11.8 initialization

`createMindMap({ activityInstanceId, idempotencyKey })` is server-only. The root
uses the approved visual type CENTRAL_INVENTION, the canonical Project name at
initialization, null Object/parent, position `{ "x": 0, "y": 0 }`, and metadata
`{ "role": "central_invention" }`. It creates no canonical Object or child node.
Root labels/creators are not resynchronized on retries or Project renames.

Current M7 contribution authority, active Activity, exact Project/Workspace/Team
scope and immutable execution mode/method are required. Existing M7 dependency
evaluation governs configured prerequisites; no global approval requirement is
invented. Registered source inputs and canonical dependency candidates preserve
exact INVENTION_STRUCTURE/GAP_LIST Artifact/Version IDs in the initial snapshot.
artifact_available may carry a null Version; approved_output uses the exact
current approved Version. Content is not copied and inputs are not retargeted.
Production Session 7 definitions/dependencies are not seeded by this task.

One MIND_MAP Artifact per Activity is enforced by a partial unique index. An
Activity advisory lock serializes initialization. Narrow private initialization
and actor/Activity/key receipts bind canonical context; all authorized callers
converge on the same persisted initial map/root. Same-key context mismatch is
CONFLICT. Prerequisites gate initial creation; an authorized active-Activity retry
reuses the existing map even if a source was subsequently archived. It neither
rebuilds the snapshot nor retargets its historical source references.
Existing unbound generic MIND_MAP Artifacts fail closed rather than
being adopted as trusted initialization. Archived maps are not restored.

The controlled SECURITY DEFINER RPC has an empty fixed search_path and only
authenticated EXECUTE. Private helpers/receipts and raw map writes remain denied.
The M8 initial-Draft initializer and initial snapshot pattern preserve V1 revision
0 and null current pointer. Optional MIND_MAP output comes only from the immutable
snapshot; no auto-completion, submission, approval or baseline change.

Run `node scripts/test-db.mjs --mind-map-creation` for isolated real PostgreSQL
scope, dependency, formal approval, peer/same-key concurrency and rollback tests.
No M11.9 node/edge operation, UI, provider room, save/checkpoint or hosted push.

## M11.9 node operations

`addMindMapNode()` accepts the seven structural types and returns the persisted
node with `edit_revision = 0`. `updateMindMapNode()` requires `expectedRevision`;
changed visual fields increment the token, exact no-ops preserve it, stale
requests return CONFLICT before any write. Types, creator and map binding cannot
be changed. JSON position data follows the existing object storage contract.

Current M7 edit authority, active Activity, ACTIVE Artifact and its bound DRAFT
Version are required. Map-scoped transaction serialization protects parent
validation against concurrent hierarchy cycles. Same-map parents are optional;
explicit null clears a parent or Object link without touching canonical data.
Object references must be unarchived, exact Project/Workspace and matching type.
The same Object may appear in multiple nodes; unlinking affects one visual node.

CENTRAL_INVENTION remains initialization-only. Its label, position and safe
metadata may be edited with CAS; the server preserves metadata role
`central_invention`. Parent/Object remain null and its visual label never renames
the Project. Metadata cannot supply canonical identities/authority; arbitrary
presentation keys have no classification semantics.

The two narrow SECURITY DEFINER RPCs use empty fixed search paths, verified
identity and existing authorization locks. Private helpers and raw table CRUD
remain inaccessible. No Artifact snapshot, Version, pointer, Object, relationship,
baseline or approval is written by node operations. M11.10 edges, deletion,
collaboration UI/provider rooms, save/checkpoints and classification remain deferred.

Run `node scripts/test-db.mjs --mind-map-nodes` for PostgreSQL node-operation,
hierarchy, exact Object reuse, root, CAS, rollback and privacy regressions.

## M11.10 visual edges

`connectMindMapNodes()`, `updateMindMapEdge()` and `removeMindMapEdge()` return
canonical persisted edge rows. Only HIERARCHY and CROSS_CONNECTION are accepted.
HIERARCHY requires target.parent_node_id to already equal source.id; connect and
edge type changes never set parents. A node parent cannot change incompatibly
while a HIERARCHY edge exists: remove that visual edge first. Removing it leaves
the parent untouched. Root and unlinked visual nodes are valid endpoints.

Distinct endpoints must belong to the exact map. A directional unique constraint
covers map/source/target/type, ignoring label and metadata. Reverse connections
are distinct; one of each type can coexist if hierarchy semantics are satisfied.
Multi-node CROSS_CONNECTION cycles are permitted, self-edges are not.

Edges start at edit_revision 0. Update/removal require expectedRevision; stale
state conflicts, material updates increment, exact no-ops preserve revision.
Endpoints/map are immutable in the public update contract. Labels can be cleared
with explicit null; omission preserves the existing label. Removal physically
deletes only the visual edge and returns its final row. Missing/removed IDs fail
with the same opaque NOT_FOUND behavior as inaccessible IDs.

The existing M11.9 current-scope/active Activity/DRAFT Version guard and map lock
serialize all node/edge mutations. Three narrow SECURITY DEFINER wrappers have
empty fixed search paths and authenticated EXECUTE only. Private helpers and
raw tables remain inaccessible. No creator field, audit subsystem, canonical
relationship sync, Artifact snapshot/Version/pointer or baseline write is added.

`node scripts/test-db.mjs --mind-map-edges` covers hierarchy, endpoint/duplicate
constraints, real-session CAS/removal races, failure injection, scope revocation,
Personal privacy and exact-ID/direct-client attacks. M11.11 deletion, UI,
Liveblocks, save/checkpoints and classification remain deferred.

## M11.13 transient collaboration

The React Flow editor uses the pinned M11.4 Liveblocks SDKs and shared private-room
issuer. A room is `mind-map:<canonical mind_maps.id>`, extending the accepted
`affinity:<canonical Activity UUID>` namespace convention. FICI's existing
`get_mind_map_editor` boundary determines both access and editability before and
after provider issuance. Clients submit only the Activity ID; room, actor, role,
Team, Project, Workspace, and permission claims are rejected. Read-only state gets
a read grant; editable state gets write with Comments/Feeds disabled. No provider
ACL memberships or profile details are introduced.

Liveblocks carries only finite node coordinates with canonical node IDs and base
revisions, plus content-free reload hints. No Liveblocks Storage is created.
Movement is explicitly unsaved, expires after a short interruption, and never
writes PostgreSQL from a provider callback. Labels, edges and removals become
visible through a newly authorized canonical reload after the ordinary server
mutation. Drag-start revisions remain the CAS tokens even if a peer saves during
the drag. Reconnect reloads PostgreSQL and never replays a stale local snapshot.
Initial provider authorization completes before the SDK connection deadline;
subsequent authorization still uses the FICI endpoint.

No visible cursors/avatars, shared text engine, checkpoint save, immutable Version
creation, or classification is included. Missing provider access degrades to the
existing canonical editor. Already-issued/open access-token sessions are not
immediately invalidated; fresh FICI auth and canonical persistence are denied
after revocation, as in M11.4. A cached unexpired provider token is part of that
same limitation, not a fresh FICI grant.

`node scripts/test-db.mjs --mind-map-collaboration` runs clean migrations and the
real provider auth/WebSocket/CAS/revocation/failure test using isolated test rooms
and a disposable local database. `node scripts/run-mind-map-browser.mjs` runs the
real Auth/PostgREST browser fixtures and both M11.12/M11.13 suites; its local test
runtime/database must first be prepared. The provider suite deletes only its
isolated cloud room and never pushes hosted migrations. Bundle scans must follow
a fresh production build.

## M11.14 explicit Draft checkpoint

`saveMindMapDraft({mindMapId, expectedDraftRevision})` saves the existing bound
DRAFT Version through M8.20 `draft_revision` CAS. Every successful explicit save,
including identical content, increments that counter; stale tokens conflict.
There is no autosave or new Version. Scope and Version identity are server-derived.

M11.13 uses transient events, not persistent provider Storage. Only coordinates
already accepted by canonical node CAS can enter this checkpoint. PostgreSQL is
validated under the existing map lock; provider outages do not prevent saving
valid canonical state and do not imply that unsaved live previews were saved.
Nodes/edges retain their IDs/revisions. Canonical Object references are revalidated
without copying Object bodies. Existing Artifact/Object Link rows remain untouched;
no membership/link replacement workflow is introduced. No Activity, pointer,
approval, baseline, immutable Version, or provider-room mutation occurs.

`node scripts/test-db.mjs --mind-map-draft` checks clean migrations, canonical
save/determinism, M8 no-op/CAS compatibility, competing sessions, node CAS, exact
Object reuse, scope attacks, frozen Versions and trigger-induced rollback through
commit. The actual-provider regression also checkpoints the canonical move winner
and denies a removed member's save despite their already-open provider session.


## M11.15 — canonical Version checkpoints

`createMindMapVersion({ mindMapId, expectedDraftRevision, changeSummary })` is server-only. It validates current exact edit authority and the active Activity, locks the canonical map, requires the source Draft to match the latest canonical save, and snapshots PostgreSQL nodes and edges rather than browser/provider state. M8 assigns the new DRAFT Version number and predecessor. The current pointer, approval state, predecessor snapshot, predecessor nodes/edges, and predecessor Object Links remain unchanged.

Each new Version has its own map and visual node/edge IDs. Labels, hierarchy, positions, cross-connections, metadata, authorship, and linked canonical Development Object IDs are preserved; canonical Objects are never cloned. Visual CAS counters begin at zero for the new representation. The editor resolves the latest representation. Older maps cannot be edited through normal map operations, and the historical Version body cannot be overwritten through generic M8 Draft CAS.

Team access requires current canonical Team membership and Project/Workspace/Activity authorization. Master role alone supplies no map access. Explicit sharing, grant/revoke operations and cross-Team access remain deferred to M13. No fixed branch count, hierarchy depth, AI naming, classification, automatic approval, or automatic current-pointer transition is introduced.

Validation: `node scripts/test-db.mjs --mind-map-version` applies clean local migrations and checks lineage, exact graph preservation, stable Objects, predecessor isolation, concurrent creation, safe denials and rollback. No hosted migration push is required.

Existing M8 authorization for an exact submitted Version is retained. Such review access is not a whole working-map grant and does not authorize createMindMapVersion(). No new review or sharing permission is introduced here.


## M11.16 canonical product classification

`classifyMindMapNode({nodeId, expectedRevision, expectedObjectRevision, classification})`
accepts only `CORE`, `SUPPORTING`, `OPTIONAL_FUTURE`, or null (unclassified).
`expectedObjectRevision` is required: the canonical Object revision for linked
nodes, null for visual-only nodes. Both the node CAS and independent Object CAS
must match. Current exact edit authorization, active Activity, newest DRAFT,
Project/Workspace and Team boundaries are revalidated in one PostgreSQL transaction.
A real semantic change updates the canonical Object, selected representation,
and existing OBJECT_UPDATED history atomically. No platform authority is created.

Linked current editor views resolve the same Object classification, including
multiple nodes pointing to C1. An unlinked node stores its own classification.
Linking propagates a classified node to an unclassified Object, adopts an already
classified Object when the node is unclassified, and rejects contradictory
non-null choices with CONFLICT. Existing metadata/lifecycle fields are not
repurposed. Canonical Object identity, authorship, scope and lifecycle are retained.

Classification changes never rewrite Artifact bodies. An explicit
`saveMindMapDraft()` captures canonical classification in the newest Draft body
and its normalized nodes; checkpoint creation requires that latest saved state.
A successor Version freezes its predecessor even when M8 still calls it DRAFT.
V1/V2 historical snapshots never resolve classification dynamically from C1.
Current C1 may continue changing while V3's saved body waits for an explicit save.
No new Artifact lifecycle status, background snapshot propagation, Object clone,
sharing/grants, AI structuring, or M11.17 output behavior is introduced.

The editor displays and edits classification with both concurrency tokens.
Existing authorized Liveblocks reload hints and tab-focus reload reconcile current
views from PostgreSQL. Provider state is never a canonical classification write.

`node scripts/test-db.mjs --mind-map-classification` runs clean disposable local
migrations and tests C1/N1/N2 consistency, independent stale/CAS races, explicit
save boundaries, V2 freeze/V3 editability, rollback, nullable clear, link conflict,
lifecycle preservation and Team/Master/removed-member/direct-client denials.

## M11.18 Session 7 output composition

`finalizeSession7Outputs({ activityInstanceId, mindMapId, expectedDraftRevision, changeSummary?, idempotencyKey })` is a strict server-only service backed by one PostgreSQL transaction. Identity, Project/Workspace/Team scope, current edit access, and active Activity state are server-derived and rechecked. Master/Admin/Mentor role alone supplies no access; sharing remains M13 work.

The Activity execution snapshot must configure `MIND_MAP`, `MINIMUM_ESSENTIAL_STRUCTURE`, and `INVENTION_CONCEPT` in `configuration.outputs.artifact_types`. The existing MIND_MAP Artifact is reused. The other two stable identities are recorded in a private operation registry; saved compositions append ordinary M8 DRAFT Versions with canonical Object links and existing `artifact` Activity Outputs. No Object, classification, relationship, current pointer, baseline, or Activity completion is created or rewritten by composition.

The newest editable map must match its explicit saved Draft body, including current canonical classifications. Stale revisions and persisted-but-unsaved changes conflict. Transient browser/provider data is never accepted. Concept snapshots retain the complete saved graph, Team-authored labels/positions/metadata, linked Object IDs/types/titles/classifications, and existing active canonical relationships between those Objects. No narrative, invention claims, labels, or relationships are generated.

Essential membership consists only of human-classified CORE Objects represented in that saved map. Existing CORE-bound canonical connections, their mapped endpoints, and parent paths supply context; non-CORE context is explicitly marked `essential: false` and linked with role `context`. Context does not expand transitively across the supporting/optional graph, infer essential membership, or reclassify/delete/archive excluded Objects. The saved visual root remains context. Historical snapshots capture classifications rather than resolving them dynamically later.

A successful composition reuses M11.15 `createMindMapVersion()` to freeze the captured source map and leave a successor DRAFT for further editing. `mindMapId` identifies the captured source; `successorMindMapId` identifies that operation's successor, which may itself become historical later. No automatic save, approval, superseding of an effective Version, or current-pointer transition occurs. Generated output predecessors also reject body rewrites after a successor exists, without inventing a lifecycle status.

Same actor/Activity/key with different normalized input conflicts. Same source Version/revision and intent converge across callers/keys; failed transactions retain no receipt. An intentional new composition requires a newly saved revision/current map. Authorized retries return canonical persisted Artifact/Version rows, not cached approval states. All retries still require current edit authority and active Activity state.

Session 8 uses existing `approved_output` or configured `artifact_available` dependencies. Composing Drafts does not satisfy approval prematurely. Source Session 6 Artifacts/Versions and their canonical Objects remain intact. No Session 8 tools, AI, sharing, or M11.19 implementation is included.

`node scripts/test-db.mjs --session7-outputs` runs clean disposable migrations and the integrated composition, save/checkpoint, history/classification, relationship/context, concurrency, rollback, review/dependency, auth-context reload, exact-ID and removal tests. The full database suite runs it too. Browser logout/refresh coverage is reported separately from database re-authentication; PostgreSQL is the durable source, never client/provider memory.


## M11.20 normalized RLS and room boundary

Authenticated SELECT on maps/nodes/edges resolves canonical Artifact/Version, Project, Workspace and Activity scope using existing private Mind Map and Team authorization. Historical map rows inherit the same current scope. Node source references must remain in the exact Project/Workspace; edges require both endpoints visible. The elevated editor applies these same node/edge predicates, including malformed persisted-reference protection. Exact submitted-Version review access does not grant the normalized whole map or room.

Direct INSERT/UPDATE/DELETE remain revoked, with restrictive read guards and write-denial policies. Existing CAS, lifecycle, immutable lineage, classification and output operations are unchanged. RLS follows repository owner/definer conventions; normal authenticated roles are the direct-client boundary under test. No new sharing path.

The existing collaboration authorizer brackets provider issuance with canonical editor authorization and preserves the existing read/edit distinction. Rooms remain private and server-derived (`mind-map:<canonical-map-UUID>`); no wildcard grants or content metadata. Removal denies fresh authorization/reconnect and canonical writes; already issued/open provider sessions are not immediately revoked.

Run `node scripts/test-db.mjs --mind-map-rls` for disposable direct-client attacks and `node scripts/test-db.mjs --mind-map-collaboration` for the opt-in real-provider regression. No hosted migrations or M13 sharing.

## M11.22 acceptance coverage

M11.23 adds `node scripts/test-db.mjs --collaborative-edit-acceptance`. Its test-only PostgreSQL advisory-lock barrier verifies all contenders are waiting before releasing them together. Three rounds of different-node edits preserve both independent revisions; same-node and whole-Draft races require one winner and an explicit conflict. Canonical state is reloaded through fresh authenticated connections, and stale graph payloads are rejected. A checkpoint race produces one successor with unchanged predecessors; classification races protect canonical Object state. Team B races, removed-member stale tokens and direct DML remain denied. The cumulative integration wrapper requires these markers. No production lock, timeout, lifecycle, sharing or provider behavior changes.

AT-MM-001/002 run in `--mind-map-nodes`: all seven exact structural types, Team labels/positions, authenticated reload, compatible canonical Object references, full-row preservation and duplicate prevention. AT-MM-003 runs in `--mind-map-node-removal`: visual leaf and incident-edge removal preserve the classified Component, canonical relationships and historical rows; a fresh authenticated connection reloads the surviving Object and its classification.

AT-MM-004 runs in `--mind-map-draft`: two actors persist movement, a Team-authored label/metadata and a cross-connection before competing Draft saves. Exactly one CAS winner advances revision 3 to 4, and fresh authenticated reload recovers PostgreSQL state independently of provider memory. Existing version/classification suites verify historical predecessor freezing. The cumulative integration wrapper requires all four acceptance markers. Real provider and authenticated React Flow regressions remain separate existing harnesses; an already-issued provider session is not immediately revoked, while fresh authorization and canonical mutation are denied after removal.


## M11.25 Professional Session 7 integration

`node scripts/test-db.mjs --session7-integration` validates a disposable PostgreSQL Session 6 → Session 7 → Session 8 dependency flow. Both Session 6 source outputs go through real M8 submission/review/approval before Session 7 starts; Draft-only sources remain blocked. Seven canonical source Objects enter the map unchanged, with no reconstruction or session-specific copies. Team-authored hierarchy, visual cross-connections, independent two-user edits, same-node CAS, whole-Draft CAS, explicit classification, checkpoint freezing, and visual-only deletion are covered in the same workflow.

The accepted M11.18 transaction reuses MIND_MAP and creates stable MINIMUM_ESSENTIAL_STRUCTURE/INVENTION_CONCEPT identities, CORE-only essential membership with explicitly non-essential context, Version-specific Object links, three Activity Outputs, and editable successor Drafts. Nine injected failure boundaries verify full rollback. Retries, classification history, exact approved Session 8 input identities, Session 6 Artifact/Version/link immutability, fresh authenticated Project/Activity/map/output reload, Team B direct-ID/join denial, and removed-member read/write denial remain asserted. Database re-authentication is reported separately from browser login/logout; provider state never supplies durable state.

Add `--session7-provider` to run the existing real Liveblocks production-authorizer/event/CAS/removal regression on an isolated clone of this same Session 7 fixture, preserving canonical IDs. Provider errors are sanitized; the test room and clone are cleaned afterward. Existing issued/open provider sessions are not immediately revoked; fresh authorization/reconnect and canonical writes are denied after removal. No new sharing, Patent/Evidence/AI functionality, production migration, or M11.26 work is introduced.


## M11.26 cross-Team and realtime leakage acceptance

The Session 7 integration fixture now executes an adversarial matrix as Team B, role-only Master/Admin/Mentor, and a removed contributor using normal authenticated PostgreSQL credentials. Exact IDs, direct CRUD, indirect joins, Affinity operations, node/edge operations, known Draft/Object revisions, checkpoint creation, classification, Session 6/7 outputs, and historical Versions must remain private. Full canonical/history row snapshots prove rejected attacks leave no partial writes. Authorized remaining-member controls stay operational. The Mind Map RLS fixture additionally tests genuine Team B map endpoints and bidirectional private Object references.

Both existing real Liveblocks harnesses test removal committed during server grant delivery: the post-provider canonical recheck must withhold the grant. Stale canonical writes fail after removal. Team B receives no private events; fresh removed-user authorization/reconnect is denied. Existing unexpired issued tokens/open sessions are not immediately revoked. No sharing model or product permissions are added.
