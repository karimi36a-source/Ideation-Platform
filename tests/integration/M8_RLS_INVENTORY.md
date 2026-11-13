# M8.15 database security inventory

All seven tables have RLS enabled and FORCE RLS disabled. This preserves the
repository's deliberate owner-executed, narrowly authorized RPC design.
Authenticated clients have SELECT only; anonymous clients have no table grants.
INSERT, UPDATE and DELETE are denied directly on every table. No permissive
mutation policy exists. Controlled business RPCs alone perform approved writes.

| Table | Authenticated SELECT boundary | Writes |
| --- | --- | --- |
| artifacts | Current canonical Project/Workspace access, including authorized archived history | Create/archive/approval RPCs |
| artifact_versions | Authorized Artifact or exact submitted-Version reviewer entitlement | Version/revision/reopen and review RPCs |
| artifact_object_links | Both exact Version and canonical Object must be visible | No ordinary composition CRUD |
| submissions | Authorized Artifact scope or current exact assigned reviewer | Submission/review RPCs |
| feedback_items | Exact Submission, submitted Version and target Object where applicable | Feedback/revision RPCs |
| review_actions | Exact Submission visibility | Append-only review RPC writes |
| project_baseline_items | Current Project read authorization | Explicit baseline setter only |

Reviewer Artifact metadata is intentionally exposed through
`get_submitted_artifact_metadata`, not general table SELECT. This avoids exposing
the Artifact's unrelated current pointer or sibling Version history. Reviewer
entitlement ends when the existing canonical status/scope predicates no longer
permit review. Historical attribution is preserved.

Baseline setter authority grants only the approved exact-target command. It
does not confer Personal Project browsing or direct baseline DML privileges.

## Function audit

The fixture inventories every function created/replaced by M8 migrations. The
database suite checks actual catalog privileges, owner and fixed empty
`search_path`, denies PUBLIC/anonymous/service-role execution, and checks an
explicit authenticated API allowlist. Anonymous typed calls exercise the execute
boundary. Trigger functions and internal lock/context helpers remain private.

The three caller-bound `can_review_*` predicates remain executable because RLS
uses them. They answer only whether the current verified caller has the exact
entitlement; inaccessible and nonexistent IDs both yield false. They accept no
actor override. Internal status-independent reviewer and baseline predicates
remain inaccessible.

Authorization call paths inspected:

- Artifact creation/version/archive/revision/reopen use the locked canonical
  Project/Workspace write validator and verified current profile.
- Submit checks current ownership/Team Lead, Activity scope, participation and
  current assigned reviewer; identities are derived internally.
- Review/feedback/revision/approval use the private lock-and-recheck reviewer
  boundary; they cannot substitute general role names for exact assignment.
- Baseline uses the private current Primary Master/exact approval predicate.
- Activity candidate/input/output operations use canonical Activity context and
  contribution checks; linkage is explicit and revalidated under locks.

Definers use schema-qualified relations and no dynamic client SQL. SQL built-ins
resolve through PostgreSQL's implicit `pg_catalog` with the empty search path.
Private definers prevent recursive RLS in reviewer predicates; child policies
compose indexed parent identities rather than broad role-based OR grants.

## Coverage

`artifact-review-rls.sql` proves AT-RLS-002, AT-RLS-003, AT-RLS-004 and the M8
Artifact-scope portion of AT-RLS-007 using actual authenticated SQL roles and
canonical business operations. It includes independent child reads, known-ID
attacks, reviewer revocation, an independently denied Object target, archived
history, baseline escalation, every-column DML attempts, approval/audit forgery,
and anonymous execution. Test-only grants verify UPDATE/DELETE RLS separately
from table privileges. These changes roll back with the disposable fixture.

The cumulative suite also runs M8.1–M8.14 workflows, races and rollback checks,
formal AT-ACT-004 handoff, and prior Workspace/Team/Project privacy regressions.
Full platform-wide AT-RLS-007 and M8.16 acceptance consolidation are not claimed.
