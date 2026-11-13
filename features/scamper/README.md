# SCAMPER privacy and sharing boundary

`getScamperEntry(entryId)` uses the caller-bound M7 Activity resolver, including
current Project, Workspace, Team and Cohort authority. Personal ownership is
required; platform roles and same-Cohort membership do not bypass privacy.
Team reads follow existing Activity rules, including explicit Project access.
Scoped MASTER identity alone does not replace those rules. Direct SCAMPER table
CRUD remains denied; reads use a narrow authenticated RPC.

`shareScamperEntryToTeam(input)` uses the standard M13 Share input with entityType=SCAMPER_ENTRY and destinationType=TEAM. Source must be the caller's currently accessible Personal Workspace. It delegates to `shareEntity()`: server-owned provenance, SNAPSHOT, VIEW/COMMENT, exact active destination membership, atomic Snapshot/audit and idempotency. Recipients use `resolveSharedEntityAccess({shareId})` only; direct SCAMPER reads and collection privacy remain unchanged. No copy, ownership transfer, source edit or ad hoc ACL is created.

AT-SCAMPER-003 is covered by the M13.6 selected-content acceptance suite. M9.3 promotion remains a separate same-Workspace IDEA operation.

## M9.14 Activity integration
IDEA promotion registers a canonical `development_object` output only when the immutable Activity snapshot contains `configuration.output_registration.promoted_ideas: true`. Missing/false preserves previous behavior. Promotion and output registration are atomic and retry-safe; historical snapshots are not backfilled. SOLUTION, PROBLEM and Bank output behavior is unchanged. Generic `resumeActivity()` remains generic; feature state reloads through existing authorized retrieval/RLS queries using the canonical Activity/output IDs. No methodology payload or new resume operation is introduced.

`listScamperEntries(activityInstanceId)` provides ordered feature reload, including unpromoted sources, through the same canonical Activity authorization as exact-entry retrieval. It performs no writes, grants no table reads, and leaves generic resume unchanged.
