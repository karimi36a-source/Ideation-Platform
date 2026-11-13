# M12.19 Activity research integration

`addActivityInput` and `addActivityOutput` accept a strict `{ activityInstanceId, evidenceId }` variant (inputs additionally require `required`). Evidence stays canonical and retains its verification state. Resume returns the independently authorized Evidence ID alongside existing Object/Artifact links.

`addActivityResearchReference({ activityInstanceId, entityType, entityId })` accepts only `PATENT_RECORD` and `PATENT_SEARCH_LOG`. Relationship is server-fixed `OUTPUT_REFERENCE`; creator is authenticated server identity. The single `activity_research_links` table contains no source metadata. Registration is active-Activity-only and idempotent under concurrent retries. Direct client writes and historical link edits/deletion are denied.

`listActivityResearchReferences(activityInstanceId)` reads authorized prior references for later contexts. Source rows are resolved through their canonical, independently authorized Patent/Search Log services/queries. Reference IDs never grant access. Search Log reads also require access to their original Activity. Evidence uses existing inputs, and Artifacts/Gaps continue using accepted M7/M8 handoff. No new input table, copied source, automatic approval, verification, legal inference, AI or sharing is introduced.

The focused PostgreSQL fixture represents isolated Session 8/9/10 contexts on one canonical Project/Workspace; it is not the later full curriculum Session E2E scenario. Completed/archived contexts retain readable historical references while refusing new registrations. Existing approved-output dependency rules remain unchanged: a Draft Landscape reference is available research, not approved output.

Run `node scripts/test-db.mjs --activity-research` for clean migrations, handoff/privacy/history/atomicity and real-session concurrency/service checks. Default cumulative integration includes these checks.
