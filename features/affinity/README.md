# Affinity schema foundation (M11.1)

Groups belong to canonical Activity Instances; items reference exactly one existing Development Object or Brainstorm Entry without copying content. Positive ordering is unique within each parent, and a source may appear once per group but in different groups. Foreign keys restrict deletion of referenced records. Deleting an organizational item never deletes its source.

Both tables have RLS enabled, no client grants, and restrictive denial policies. Provenance fields confer no authority. Exact-scope source placement and source-visibility validation remain deferred to the item operation/security tasks; schema fixtures do not establish product authorization. No item operations, UI, realtime, or Artifact outputs are implemented.

Run `node scripts/test-db.mjs --affinity-schema` for clean local migration and schema checks; the cumulative runner includes the same suite.

## Group operations (M11.2)

`createAffinityGroup({ activityInstanceId, name, description? })` and `renameAffinityGroup({ affinityGroupId, name, description? })` use narrow authenticated RPCs. The immutable snapshot and Definition must both identify `affinity`. Existing M7 contribution authorization governs current Personal owner/Team edit rights; creator provenance grants no authority. Only active/editable Activities accept mutations.

Names use the existing 200-character label limit; descriptions have a defensive 10,000-character bound. Unicode edge whitespace is trimmed. Omitted rename descriptions preserve existing values; null explicitly clears them. Creation serializes sequence allocation with a per-Activity transaction advisory lock and rechecks authority after waiting. Identical names intentionally create distinct groups. Rename locks the group row, updates only name/description, and leaves timestamps/provenance/items/sources unchanged. Concurrent rename conflict resolution remains deferred to M11.4.

Default-deny table grants/policies remain intact. Private validators are not client-executable; public RPCs use a fixed empty search path and server-derived identity. No new audit event vocabulary is introduced. Run `node scripts/test-db.mjs --affinity-operations` for operation, privacy, lifecycle, and independent-session create races. No item operations or hosted migrations are added.

## Item operations (M11.3)

`addAffinityItem({ affinityGroupId, developmentObjectId?, brainstormEntryId?, position? })` requires exactly one canonical source. `moveItemToAffinityGroup({ itemId, targetGroupId, position })` preserves item identity, source IDs, provenance and creation time. Current M11.2 edit authority and exact source Project/Workspace/Team compatibility are checked on every request, including retries. Moves remain inside one Affinity Activity.

Team Brainstorm sources must already be visible under M9's immutable source configuration. The only current M9 runtime is private-before-reveal, requiring authorized reveal; its creator cannot bypass this restriction. No directly-visible configuration vocabulary is invented. Personal owners may use their own unrevealed entries. Historical completed source Activities remain usable when M9 still authorizes reading them; grouping never reveals or mutates source rows.

Adds append or insert within `1..count+1`; moves use `1..target count` within one group or `1..target count+1` across groups. Position uniqueness is DEFERRABLE INITIALLY IMMEDIATE so complete reorder statements retain uniqueness without row-order collisions. Per-Activity transaction locks serialize ordering, and stable item rows are shifted deterministically. Same-group duplicate sources conflict; different groups remain allowed. Identical moves are authorized no-ops. Failure rolls back all shifts and grouping changes.

Run `node scripts/test-db.mjs --affinity-items` for schema, privacy, ordering, rollback, AT-AFF-001 and independent add/different-item move tests. AT-AFF-002, same-item collaborative conflict policy, realtime and UI remain M11.4-owned. No client CRUD grant, Artifact output or hosted migration is added.

## M11.4 collaborative persistence

Every durable move now requires `expectedRevision` from the canonical item's `move_revision`. Explicit successful moves advance that token; sibling position shifts do not. Stale moves conflict without mutation, including return-to-original-position cases. Authorized no-op retries with the current token remain no-ops. Clients must reload on conflict and seek a fresh user intent, never silently retry stale intent.

`getAffinityCollaborationBoard({ activityInstanceId })` loads minimal canonical group/item/source IDs through the existing exact Affinity edit authority. The deterministic room is `affinity:<activity UUID>`; client room/user/team claims are rejected. No raw source content is placed in provider state. PostgreSQL advisory serialization preserves transaction-safe M11.3 ordering.

The provider-independent acknowledgement utility distinguishes optimistic, persisted, conflict and failed states. Reconnect reloads PostgreSQL; ephemeral provider layout is never a durable acknowledgement. The server authorizer rechecks access before and after provider I/O. The production auth endpoint uses the server-only Liveblocks adapter described below and fails closed with DEPENDENCY_NOT_READY if configuration/provider issuance is unavailable. Future FICI authorization, fresh-client reconnect and durable writes are denied after removal. Already-issued token sessions are not forcibly revoked. No second Supabase movement protocol is added.

Run `node scripts/test-db.mjs --affinity-collaboration` for local canonical concurrency/security tests and AT-AFF-001 regression. No M11.5 behavior or hosted push.

## M11.4 actual Liveblocks provider

Official `@liveblocks/node` and `@liveblocks/client` are pinned to 3.24.3. The server-only adapter reads `LIVEBLOCKS_SECRET_KEY`, gets/creates the exact private room, rejects broad pre-existing ACLs, and issues an access token for only the server-derived room. FICI authorization is checked before and after provider I/O. The client callback accepts only its canonical room and sends only Activity ID to the FICI endpoint. Provider errors remain generic.

Run `node scripts/test-db.mjs --affinity-collaboration --liveblocks` for opt-in actual provider tests with disposable local PostgreSQL fixtures. The provider test substitutes only the verified fixture identity/database transport; it exercises the production service/HTTP handler, official SDK, real private room and WebSockets. It covers authorized event delivery, foreign-room token denial, canonical CAS persistence, new-auth/fresh reconnect denial after removal, and provider failure safety. It creates/deletes only its isolated test room; no hosted migrations. Ordinary cumulative tests remain network-independent.

Access-token limitation: an already issued token/open or cached session is not forcibly revoked on membership removal. Fresh FICI authorization and fresh-client reconnect are denied; no immediate socket revocation or old-token invalidation is claimed. PostgreSQL authorization and CAS always remain current. Provider events are ephemeral hints; reload canonical state after conflict/disconnect. Run `node scripts/scan-client-secrets.mjs` after a fresh build to explicitly scan for the configured server secret without displaying it.


M11.5: `confirmAffinityStructure({ activityInstanceId, affinityGroupId, mode, targetObjectId?, newObject?, relationships?, idempotencyKey })` is explicit human confirmation. LINK_EXISTING reuses a structural Object without changing it; CREATE_NEW accepts SYSTEM/SUBSYSTEM/COMPONENT/FUNCTION/GAP and records AFFINITY origin to the Group. Relationships use sourceObjectId/targetObjectId (UUID or request-local CONFIRMED_OBJECT) and the existing relationshipType vocabulary. Every included source must remain in the authorized exact scope; grouping never infers a semantic edge.

One INVENTION_STRUCTURE Artifact per Activity receives a new M8 Draft for each new intentional confirmation. Version snapshots and Object-link metadata preserve references, actor and timestamp without copying canonical source content. Output registration is opt-in through immutable `configuration.outputs.artifact_types`; flags come from that same execution snapshot. No Activity completion, approval, baseline, restore, or M11.6 behavior.

The narrow private receipt table scopes keys to verified actor + Activity. Normalized identical payloads replay the original IDs with `replayed: true`; changed intent conflicts. New keys preserve prior Versions. Replays require current active/editable Affinity authority. Composition, Object/relationship creation, links, optional output and receipt commit atomically. No authenticated CRUD grants are broadened. The existing M11.4 Liveblocks/CAS path remains independent; PostgreSQL stays canonical.


M11.6: `captureGap({ activityInstanceId, mode, gapObjectId?, newGap?, relationships?, idempotencyKey })` is explicit human capture. CREATE_NEW accepts newGap.title/content and creates one canonical GAP through the existing Object model with GAP_CAPTURE origin to the Activity; ADD_EXISTING accepts an accessible unarchived GAP from the same Project/Workspace, including earlier work, without modifying its provenance or content. Unknown identity, scope, lifecycle and output fields are rejected. Relationships use the M11.5 sourceObjectId/targetObjectId/relationshipType shape and request-local CONFIRMED_OBJECT token; no edges or Gaps are inferred.

One GAP_LIST Artifact per Activity receives cumulative M8 Draft checkpoints only when membership changes. Latest membership ordering is preserved and a new Gap appended once; each Version owns its complete Object links and reference-only provenance snapshot. Prior rows/links and current pointers remain unchanged. Re-adding an included Gap returns the latest Version with membershipChanged=false; explicit new relationships can be saved independently and recorded in the private receipt without rewriting that Version, even when it is CURRENT. No-op output registration remains idempotent and opt-in through the immutable configuration.outputs.artifact_types array. Review/approval flags come from that same snapshot; no auto-submit, auto-approve, Activity completion or baseline mutation.

The narrow private.gap_captures receipt scopes normalized intent to verified actor + Activity + key. Identical retries return original IDs with replayed=true; changed intent conflicts. Activity serialization plus the M8 Artifact lock prevents lost concurrent additions. Prior members are revalidated; only a capture-created checkpoint with matching canonical links may supply cumulative membership. Generic Drafts cannot forge that identity merely by using plausible snapshot fields. Unbound/mismatched history fails closed instead of silently discarding membership. This is an integrity check after current authorization, not an access grant from provenance. Atomicity covers Object/relationships, Artifact/Version, complete links, optional output and receipt; ordinary client CRUD remains denied. Mind Map reuse is tested only through isolated references to the same Object ID; M11.7 is not implemented.

## M11.17 Session 6 output acceptance

`node scripts/test-db.mjs --session6-outputs` runs an isolated PostgreSQL integration scenario using the existing M11.5/M11.6 composition RPCs and M7/M8 output, review, input, and dependency operations. The full database suite also runs this scenario.

The fixture explicitly configures `configuration.outputs.artifact_types` with `INVENTION_STRUCTURE` and `GAP_LIST` before starting the Activity. Both register as `activity_outputs.output_type = artifact` with stable Artifact IDs. Version-specific Object links retain existing canonical Objects; Gap List Versions are cumulative. Grouping alone creates no canonical relationships.

Review-required outputs remain DRAFT until the existing M8 submit/review/approve flow makes their Versions CURRENT. Session 7 `approved_output` dependencies require both exact approved Versions. The separate no-review fixture uses existing `artifact_available` semantics without inventing approval or a current pointer. No Session 7 final output is created.

Coverage includes concurrent same-intent retries, exact output deduplication, composition rollback on output-insert failure, cumulative Version/link history, fresh authenticated connection reload after anonymous denial, Team B and removed-member exact-ID/join denial, and preservation of Objects, classifications, Activity state, baselines, and existing Mind Map state. This is database re-authentication coverage, not a claim of browser logout/login or a shared-cluster restart. The cumulative suite separately retains M11.16 Mind Map snapshot/classification regressions.

M11.17 also closes a reproduced direct-RPC configuration bypass: Affinity Artifact output registration now requires the exact type in the immutable execution snapshot, including direct registration retries. The shared RPC retains its existing scope/lifecycle checks, narrow grants, and other-method contracts. No historical snapshot or output row is rewritten; no sharing model or dependency vocabulary is added.


## M11.19 Affinity RLS

Authenticated SELECT on groups requires current canonical Activity/Project/Workspace access and exact Team membership or Personal ownership. Items additionally require same-scope accessible Object or Brainstorm source. Team Brainstorm references require the accepted reveal configuration and revealed_at; a mere stored source ID never grants source visibility. Master/Admin/Mentor role alone grants no Team invention-data access.

Direct client INSERT/UPDATE/DELETE remain revoked. Restrictive read guards and operation-specific write-denial policies protect both tables even if a future permissive policy is added. Existing create/rename/add/CAS-move RPCs remain unchanged. Reads reuse existing Activity history visibility; mutations continue requiring active/editable Activity state. RLS enablement follows repository conventions; trusted owner/definer operations remain privileged, ordinary authenticated credentials are the tested boundary. No new sharing or deletion workflow.

Run `node scripts/test-db.mjs --affinity-rls` for disposable PostgreSQL exact-ID/CRUD/spoof/source/reveal/Personal/lifecycle/removal tests. The cumulative runner includes this test plus existing M11.1–M11.6 and Session 6/7 regressions.

## M11.21 Affinity acceptance

Run `node scripts/test-db.mjs --affinity-acceptance` for AT-AFF-001/002 against clean disposable PostgreSQL. Four distinct canonical sources (P1/P2/S1/S2) retain their complete rows, counts, and relationships through grouping and CAS movement. Separate authenticated processes prove non-conflicting writes survive, one same-item contender conflicts, fresh connections reload saved state, and Team B/removed users cannot read or mutate the board. Existing Personal/unrevealed Brainstorm boundaries remain in the item/RLS regressions.

The cumulative integration command checks both acceptance markers. `node scripts/test-db.mjs --affinity-collaboration --liveblocks` separately verifies the real private provider room, event isolation, and fresh authorization revocation. Existing open provider sessions are not immediately revoked; PostgreSQL mutations still require current canonical authorization. No new product or sharing behavior.


## M11.24 Professional Session 6 integration

`node scripts/test-db.mjs --session6-integration` runs one disposable PostgreSQL workflow from the existing Activity start and canonical Project fixtures through grouping, Team-authored names, two-user independent moves and explicit same-item CAS conflict, human-confirmed System/Subsystem structure, cumulative Gap capture, durable Artifact checkpoints, configured Activity Outputs, real M8 approval, and exact Session 7 dependency input registration. The cumulative runner requires both M11.24 acceptance markers.

The scenario preserves full source rows, prior finalized Decision history, historical Versions and Object links; grouping creates no semantic relationships. Explicit confirmations create only selected Objects/relationships. Retries, output-insert rollback, Team B exact-ID/join denial, removal revocation, and surviving-member access are verified. Fresh authenticated PostgreSQL sessions and an intervening anonymous denial prove durable re-authenticated reload; this is not a claim of browser logout/login. No Session 7 composition, sharing, production migration, or hosted push is added.
