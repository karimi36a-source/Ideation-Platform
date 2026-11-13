# FICI Invention Education & Development Platform

FICI is a structured invention-development platform focused on confidentiality,
project continuity, traceability, and evidence integrity. M0.1 through M0.4 establish only
the repository and application foundation. M1.1ط£آ¢أ¢â€ڑآ¬أ¢â‚¬إ“M1.3 add authentication plumbing, secure user profiles, and minimal login/logout.

## Architecture

One Next.js 16.3.5 App Router application forms a modular monolith, using React
19.3.0 and strict TypeScript 6.0.3. `/docs` is the product and architecture source of truth.

- `app/`: routing, root layout, and the minimal foundation page.
- `components/`: reusable UI boundaries for common, workspace, activity, collaboration, and review components.
- `features/`: user-profile services and future domain modules.
- `lib/`: separated Supabase clients, environment validation, and future service boundaries.
- `supabase/`: local configuration, user-profile migration, test boundary, and a comment-only seed.
- `tests/unit/`: Vitest foundation/auth/profile tests; `tests/integration/`: PostgreSQL profile security tests; `tests/e2e/`: Playwright browser smoke test.
- `scripts/`: future development utilities.

Empty boundaries use `.gitkeep`; they contain no implementation.

The pnpm configuration permits only the pinned native resolver post-install script
needed by ESLint. Other dependency build scripts remain subject to pnpm defaults.

Do not modify product requirements or invent missing business rules during implementation. If a requirement is ambiguous, consult `/docs` and flag the issue.

## Prerequisites

- Node.js 24 LTS (24.x; validated with 24.18.0).
- pnpm 11.25.0, matching the `packageManager` field.

If pnpm is not installed, install the pinned tool version:

```sh
npm install --global pnpm@11.25.0
```

Use pnpm for all project dependency operations. Commit `pnpm-lock.yaml` with
changes to dependencies. No environment variables or credentials are needed for M0.1.

## Installation and local development

From the project root:

```sh
pnpm install
pnpm dev
```

Open http://localhost:3000. The root page displays the FICI platform name.

## Quality checks

```sh
pnpm lint
pnpm typecheck
pnpm build
```

Type checking generates Next.js route types before running TypeScript, so it also
works before the first build. Lint fails on warnings. Production TypeScript
checking remains enabled.

After a successful build:

```sh
pnpm start
```

For a reproducible installation of the committed dependencies:

```sh
pnpm install --frozen-lockfile
```

## Automated testing and CI (M0.3)

Install the Chromium browser once after installing dependencies:

```sh
pnpm exec playwright install chromium
```

On Linux CI, install browser system dependencies too:

```sh
pnpm exec playwright install --with-deps chromium
```

Run the foundation checks:

```sh
pnpm lint
pnpm typecheck
pnpm test:unit
pnpm build
pnpm test:e2e
```

`pnpm test` runs all Vitest unit/integration tests once. `pnpm test:watch` starts
Vitest watch mode. Vitest uses Node and a repository-root `@/` alias; it does not
collect Playwright specs. The unit smoke test renders the static root component.
Profile database tests run separately with `pnpm test:db`; future Supabase tests have a
separate boundary in `supabase/tests/`. No product acceptance tests exist yet.

Playwright starts and stops the production Next.js server on **127.0.0.1:3100**,
opens the root page in Chromium, and verifies HTTP 200 and the visible FICI heading.
Run `pnpm build` first. Keep port 3100 free: the test never reuses an existing server,
so it cannot accidentally test another app or an outdated development server.
Reports go to `playwright-report/`; failure screenshots/traces go to `test-results/`.
Both are ignored by Git and ESLint. View the report with:

```sh
pnpm exec playwright show-report
```

`.github/workflows/ci.yml` runs on pushes, pull requests, and manual dispatch.
It uses Node 24.18.0 and pnpm 11.25.0, caches the pnpm store, installs with the frozen
lockfile, and runs lint, typecheck, unit smoke, build, and Chromium E2E in order.
Actions are pinned to release commit SHAs. The workflow has read-only repository
permissions and uploads Playwright reports for seven days. The foundation smoke test needs no credentials. M1.3 Auth E2E requires a
non-production Supabase instance and dedicated credentials (see below).
A hosted Actions run requires pushing the repository to GitHub; local validation
does not imply that the hosted workflow has already run.

Beyond M1 profiles and minimal authentication, business schema, recovery flows, AI, collaboration, and product interfaces
remain unimplemented. Development rules and review questions are documented in
[CONTRIBUTING.md](CONTRIBUTING.md) and the pull request template.

### Windows teardown limitation

In the Codex Windows environment, the E2E assertion has passed while Playwright
stalled during automatic Next.js server teardown. If this occurs, identify the
server PID from that test run's `[WebServer]` output and verify it belongs to the
current test before stopping only that process with `Stop-Process -Id <PID>`.
Wait for Playwright's final result and exit code, and report the manual cleanup.
Do not terminate all Node processes or treat a stalled runner as a completed check.

## Tooling compatibility note

ESLint 9.39.5 is pinned because the plugins included by eslint-config-next 16.3.5
still declare ESLint 9 peer support. npm marks this ESLint release unsupported.
Reassess this tooling pin when the upstream plugin set supports ESLint 10.

## Supabase local development (M0.2)

Install the Supabase CLI using the [official installation guide](https://supabase.com/docs/guides/local-development/cli/getting-started).
This configuration was initialized with CLI **2.118.0**. The CLI is a separate
developer prerequisite, not an application dependency. Docker Desktop (running
with Linux containers) or another CLI-supported container runtime is required
for the local stack. Verify `supabase --version` and `docker version` first.

Run all commands from the repository root. `supabase/config.toml` is already
initialized; do not rerun `supabase init` or link to a production project.

```sh
supabase start
supabase status
```

The configuration uses local PostgreSQL 17, API port 54321, database port 54322,
Studio port 54323, and the local mail capture UI on port 54324. Realtime, storage,
edge functions, and analytics are disabled until their milestones need them.
M1.2 defines only the `public.users` profile table and its policies. No storage buckets or product seeds are defined.
Provider-owned infrastructure schemas are managed by Supabase itself.

### Environment setup

In PowerShell, copy the template only if you do not already have `.env.local`:

```powershell
Copy-Item .env.example .env.local
```

Set `NEXT_PUBLIC_SUPABASE_URL` to the local API URL and set
`NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` to the local `sb_publishable_...` key from
`supabase status`. The template contains no key. Never substitute a secret or
service-role key into a public variable. The validator accepts publishable keys,
not legacy JWT keys. Restart the Next.js development server after changing them;
public values are embedded at build time, so rebuild for a new deployment.

Both public variables are mandatory **when a client factory is called**. Validation
is lazy, so the static root page, lint, typecheck, and build work without any keys.
Missing or invalid values produce errors naming variables without echoing values.

These server-only variables are optional in M0.2; empty values mean unset:

- `SUPABASE_SECRET_KEY`
- `OPENAI_API_KEY`
- `LIVEBLOCKS_SECRET_KEY`
- `DAILY_API_KEY`
- `RESEND_API_KEY`

They are validated only in `lib/validation/env-server.ts`, protected by
`server-only`. Do not send its return value to Client Components. Neither client
uses the Supabase secret key, and no privileged/admin client is provided.
Only `.env.example` is eligible for source control; real `.env` files remain ignored.

### Client boundaries

- `lib/db/browser.ts`: cookie-compatible browser client using public configuration.
- `lib/db/server.ts`: a fresh request-scoped server client using `next/headers`
  cookies and the same publishable key. Server Actions and Route Handlers can write
  cookies; the helper tolerates only the framework's read-only Server Component
  cookie error and rethrows other failures.

The helpers follow the [Supabase SSR approach](https://supabase.com/docs/guides/auth/server-side/creating-a-client).
M1.1 adds session-refresh Proxy handling and verified identity helpers. M1.3
adds login/logout and a protected landing page; recovery remains a later task.
The foundation page does not instantiate either client or contact Supabase.
Database types should be generated from approved migrations in later milestones.

### Migration workflow

The M1.2 migration defines user profiles, grants, RLS, provisioning, and Auth email synchronization.
When a later task authorizes a schema change:

```sh
supabase migration new descriptive_change_name
# Edit the generated SQL under supabase/migrations and review it against /docs.
supabase migration up --local
```

To rebuild a disposable local database from migrations and the seed placeholder:

```sh
supabase db reset --local
```

Reset deletes the local database contents. Use it only with disposable local data.
No remote migration or deployment is part of this milestone. The seed file contains
comments only; database security tests will later live in `supabase/tests/`.

Stop the local stack when finished:

```sh
supabase stop
```

### Dependency compatibility

`patches/supabase-auth-js-2.117.2.patch` fixes a declaration-only incompatibility in
Supabase's `PublicKeyCredentialFuture` with TypeScript 6's DOM `toJSON` definition.
It preserves Supabase's own generic `toJSON` declaration while omitting the conflicting
inherited member, in both CommonJS and ESM declarations. pnpm applies the patch
reproducibly through `pnpm-workspace.yaml` and the lockfile. No JavaScript runtime
code is changed; `strict` and full dependency declaration checking remain enabled.
Reassess and remove this patch when Supabase publishes compatible declarations.

### Validation environment

CLI initialization succeeded. CLI status reached the container-inspection step,
but Docker and Podman were unavailable on the implementation machine. A live local
stack/migration run was therefore not verified. No containers were started.

## Authentication plumbing (M1.1)

`lib/auth/session.ts` is server-only. `getVerifiedSession()` returns `{ user }`
from Supabase Auth's `getUser()` or `null` for a missing/invalid session. This is a
verified identity context, not the SDK's raw token-bearing Session. Access and
refresh tokens are not returned. `getOptionalAuthenticatedUser()` returns the
verified Auth user or `null`; `requireAuthenticatedUser()` throws `AUTH_REQUIRED`
when signed out. Provider/network failures fail closed with a sanitized
`EXTERNAL_PROVIDER_ERROR`. Configuration errors remain explicit.

These helpers accept no client user ID, create a fresh request-scoped client,
and do not cache identities between requests. They do not read profiles or assign
roles. User-editable metadata must never be used as authorization. Call the
required-user helper inside every future protected server operation; authentication
alone does not grant resource access or replace RLS.

`proxy.ts` delegates session refresh to `lib/auth/proxy.ts` for application paths,
excluding Next.js static/image resources and favicon. The existing `/` foundation
page is explicitly exempt because it reads no auth state and requires no keys.
Remove that exemption if the root ever becomes auth-aware. Other matched requests
require the two validated public Supabase variables. No secret key is used.

The Proxy verifies with `getUser()`, propagates refreshed cookies to both the
server request and browser response, and preserves Supabase cache-prevention
headers, including across repeated cookie writes. Server Components use the
refreshed request cookies; Server Actions/Route Handlers can also persist cookies
through the server client. Keep auth routes dynamic (`dynamic = 'force-dynamic'`),
never use ISR for auth responses, and preserve cookies/cache headers if replacing
or redirecting a Proxy response. The Proxy refreshes sessions; it is not a route
access gate. M1.3 uses these helpers for the protected `/account` page and login redirects.

This follows the [Supabase SSR client guidance](https://supabase.com/docs/guides/auth/server-side/creating-a-client?framework=nextjs)
and [advanced session/caching guidance](https://supabase.com/docs/guides/auth/server-side/advanced-guide).
`getUser()` provides a server-confirmed user record; cookie-only `getSession()` is
not used as identity evidence. No callback is required for the current plumbing;
M1.3 uses password login without a callback; verification/recovery callbacks remain later tasks.

Unit tests cover verified identity, signed-out/invalid sessions, sanitized failures,
request isolation, refreshed cookie chunks, cache headers, and Proxy routing.
They mock the provider boundary and do not prove a live Supabase login/refresh
round trip. That requires a running local Supabase stack, configured public keys,
and test accounts when the later authentication flows are implemented. Account
status, registration, and verification policy remain governed by the relevant M1
docs; no policy is invented here.

## Platform user profiles (M1.2)

Apply `supabase/migrations/20260929000000_create_user_profiles.sql` to the local
stack with `supabase migration up --local`. `public.users.id` references
`auth.users.id` one-to-one. All twelve required fields exist. Nullable profile
fields can remain unset; email mirrors the Auth identity and may be null where
the provider has no email. No passwords are stored in the profile.

Provisioning is explicit and trusted, not automatic signup activation. From a
trusted database operator or service-role backend, call:

```sql
-- Use an existing Auth user's actual ID and an explicitly approved status.
select public.provision_user_profile('<auth-user-uuid>'::uuid, 'invited');
```

The four supported statuses are `invited`, `active`, `suspended`, and `archived`.
There is no default or inferred status because the docs do not define an initial
activation policy. Both arguments are mandatory. The function reads email from
Auth, ignores user metadata, locks the Auth row against concurrent email changes,
and inserts only if no profile exists. Repeating it preserves profile edits and
status. It is executable only by the trusted `service_role`/database owner, never
by `anon` or `authenticated`. No service key is added to the application clients.
Provision existing Auth users through the same function; there is no automatic
backfill that assigns a business status.

Auth email updates synchronize to an existing profile through a hardened trigger.
There is no profile API for email changes. Auth deletion is restricted when a
profile exists, preserving history until an approved archive/deletion workflow is
implemented. No account activation, suspension enforcement, registration policy,
profile deletion, or administrator UI is introduced.

`features/users/service.ts` provides server-only `getCurrentUser()` and
`updateOwnProfile(input)`. Both derive identity from `requireAuthenticatedUser()`.
The first returns the platform profile only; later role/membership scopes are not
invented. Missing profiles return `NOT_FOUND`; reads never silently provision.
The update accepts only `display_name`, `profile_image`, `timezone`, and `locale`
from the API contract. Unknown fields (including `userId`, `email`, and
`account_status`) are rejected. First/last names exist but are not self-editable
under the current contract. Profile image is an opaque reference; no image fetch,
rendering, or upload is implemented. Null clears an editable field.

RLS restricts SELECT/UPDATE to `auth.uid() = id`. Column grants additionally deny
updates to identity, status, names, and timestamps. No user INSERT/DELETE grants
or policies exist. Database-managed `updated_at` records updates.
`lib/db/database.types.ts` is a manually maintained schema contract for this
migration, used by both Supabase clients; it is not claimed as CLI-generated.

### Database integration tests

Install PostgreSQL 17 tools (`initdb`, `postgres`, `pg_isready`, `pg_ctl`, `psql`)
and expose them on PATH, or set `POSTGRES_BIN` to their directory. On Windows:

```powershell
$env:POSTGRES_BIN = 'C:\Program Files\PostgreSQL\17\bin'
pnpm test:db
```

Run as an ordinary user (PostgreSQL does not support running as root on Unix).
The runner creates a new temporary cluster, listens only on loopback on an
available port, applies a minimal test-only Supabase Auth contract plus the actual
migration, runs SQL assertions, stops its server, and removes its temporary data.
It never accepts a remote database URL or uses the installed database's data.
Local trust authentication is confined to that disposable test cluster.

Tests exercise real PostgreSQL grants and RLS as `anon`/`authenticated`, explicit
trusted provisioning and retries, protected columns, cross-user read/write denial,
email synchronization, and preservation on Auth deletion. The Auth fixture is not
a replacement for testing the full Supabase Auth/PostgREST stack; that live-provider
round trip remains separate. `pnpm test:unit` covers the services and input rules.
The existing GitHub workflow does not yet run `test:db`; run it before review of
profile/database changes. No production or hosted migration is applied by tests.

## Login and logout (M1.3)

Configure the public Supabase URL and publishable key in ignored `.env.local` for
local development. `/login` provides labelled email/password inputs, browser and
server validation, a pending state, and generic provider errors. Credentials go
to a Next.js Server Action and then Supabase `signInWithPassword`; the application
never stores or logs passwords. Next.js supplies Server Action origin protection.

Successful login always redirects to `/account`, which verifies server-side Auth
identity and shows only the signed-in email and sign-out button. Already signed-in
users visiting `/login` go to `/account`. Return URLs are not accepted. Logout uses
`signOut({ scope: 'local' })` for the current session, invalidates route cache, and
redirects to `/login` only on success. Auth pages are dynamic; the Proxy preserves
cookies and no-store headers. The public foundation page remains unchanged.

M1.2 provisioning is still explicit; login does not create profiles or assign an
account status. This minimal Auth landing does not expose profile or business data.
Platform status enforcement is implemented in M1.5 as described below;
Supabase controls password/verification acceptance.
No signup, OAuth, roles, or dashboard is included. Recovery is described below.

### Live authentication acceptance tests

Use a non-production Supabase instance and a dedicated existing, confirmed test
account with an active platform profile. Provision it through the M1.2 trusted
workflow; tests do not create users or alter profiles. Set these variables in an
ignored `.env.test.local` file or the test process environment:

```dotenv
NEXT_PUBLIC_SUPABASE_URL=<non-production-supabase-url>
NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=<publishable-key>
FICI_E2E_EMAIL=<dedicated-test-account-email>
FICI_E2E_PASSWORD=<dedicated-test-account-password>
```

Then run `pnpm build` and `pnpm test:e2e`. Playwright loads `.env.test.local` and
passes the public configuration to its production app server. The tests exercise
real Supabase login, invalid-password rejection, persisted cookies across reload,
already-authenticated redirects, fixed redirect targets, and denial after logout.
Live Auth runs disable failure-page snapshots and HTML reports; auth tests also
disable traces, screenshots, video, and retries to limit credential
capture and repeated login attempts. No saved browser session is committed.

Missing configuration fails Auth E2E explicitly. Do not interpret a passing
foundation smoke test or mocked unit tests as live Auth acceptance. In GitHub
Actions, configure the same four variables as repository secrets; the workflow maps public configuration to the build and all
four variables to E2E. Secrets are unavailable to fork PRs, so those runs cannot
complete live Auth acceptance without a trusted follow-up run. Never use production accounts. See the Windows teardown note
above if the test server requires manual cleanup.

## M1.4 ط£آ¢أ¢â€ڑآ¬أ¢â‚¬â€Œ Recovery and email verification

Set server-only `AUTH_SITE_URL` to the trusted deployment origin (HTTPS, or HTTP
loopback for development). Requests cannot choose their own email redirect.
In Supabase Auth URL Configuration, set Site URL and allow the exact
`AUTH_SITE_URL/reset-password` redirect for each approved environment.
Playwright sets the local app origin for its own server.

Configure Supabase Auth **Reset Password** email template to link to:

```html
<a href="{{ .RedirectTo }}?token_hash={{ .TokenHash }}&amp;type=recovery">Reset password</a>
```

Configure **Confirm signup** email template to link to:

```html
<a href="{{ .SiteURL }}/auth/confirm?token_hash={{ .TokenHash }}&amp;type=signup">Verify email</a>
```

If email changes are enabled, their confirmation template must use the same
confirmation endpoint with `type=email_change`; preserve Supabase's secure email
change setting. Signup UI and email-editing APIs are not implemented here.
Enable Confirm email if the deployment requires email verification; the app does
not change registration or verification policy. Use Supabase's configured email
delivery and password policy; configure production SMTP through Supabase Auth
before release. Resend product notifications are not involved.

`/forgot-password` calls `resetPasswordForEmail` and returns the same request state
for eligible, missing, rate-limited and provider-rejected accounts. This state
acknowledges a request, not confirmed mail delivery. `/reset-password` receives only
the provider-issued token hash. GET does not consume it. Submission first checks
password confirmation, then calls `verifyOtp(type: recovery)`, verifies the user
remotely, and calls `updateUser({ password })` in that same action. A normal login
session alone cannot authorize this action. Supabase enforces expiry, one-time use
and password requirements. Token hashes/passwords are never stored in platform
tables or logged. After an update the recovery session is signed out locally;
other-session revocation follows Supabase Auth's provider policy.

A failed password update consumes the link: request a new email after correcting
the password. Missing, expired and reused links have explicit error states.
`/auth/confirm` accepts only signup/email-change token hashes, ends its temporary
session, and redirects to a fixed clean verification state. Auth link pages use
no-store and no-referrer headers. Configure hosting/proxy access logs to redact
auth query strings; never record provider links, credentials or cookies.

Unit tests cover successful provider verification/update, invalid/expired/replayed
tokens, identity mismatch, password policy failure, and sanitized callback states.
E2E covers the request UI and live provider rejection of invalid links without
changing test-account passwords. Successful mail delivery and full link completion
require a controlled mailbox and the above hosted email-template configuration;
perform that final manual check in a non-production environment. No custom token
storage, registration, social login, MFA or later-scope features were added.

## M1.5 ط£آ¢أ¢â€ڑآ¬أ¢â‚¬â€Œ Platform account state

The approved task clarification allows protected platform access only for an
`active` profile. `invited` waits for trusted activation; `suspended` and
`archived` are blocked. An authenticated identity with no profile is blocked
pending trusted provisioning. Login, logout, verification and recovery remain
available independently of platform access; successful password recovery never
changes platform status or restores suspended/archived access.

The `(platform)` layout and account page enforce fresh server-side profile state
through `requireProtectedAccount`. Protected server operations must independently
call `requireActivePlatformUser`; layout/Proxy checks alone do not secure actions.
`getCurrentUser` can still read the caller's own profile to explain blocked state.
`/account-state` shows only account lifecycle guidance and logout, and derives its
state from verified identity and the database. Provider/database failures deny
access rather than granting an active status. No client status or Auth metadata
is authoritative.

`updateOwnProfile` checks active state server-side. Migration
`20260930000000_enforce_profile_account_state.sql` also restricts own-profile
UPDATE RLS to active accounts, so a concurrent suspension or direct browser SDK
call cannot bypass the check. Protected field grants and own-profile SELECT RLS
are preserved. No role, membership, scope or product tables were added.

Apply both migrations in timestamp order to each approved Supabase environment
before using protected platform routes. The live E2E project requires the M1.2
schema, this M1.5 policy, and an existing active dedicated test profile. A trusted
operator may provision a missing profile through the existing function:

```sql
select public.provision_user_profile(id, 'active'::public.account_status)
from auth.users where email = '<dedicated-test-account-email>';
```

Use the intended initial status for real accounts. The function requires explicit
status, reads provider-owned identity/email, and is idempotent: retrying it never
overwrites or reactivates an existing profile. Existing invited, suspended or
archived profiles require a separate deliberate trusted status change; application
users cannot provision themselves or change status. No automatic provisioning or
activation was introduced. Run `pnpm test:db` to validate migrations, grants,
provisioning and lifecycle RLS in a disposable PostgreSQL cluster.

## M2.1 ط£آ¢أ¢â€ڑآ¬أ¢â‚¬â€Œ System role catalog

Migration `20260930010000_create_system_roles.sql` creates `roles` and inserts
exactly ADMIN, MASTER, MENTOR and STUDENT. Fixed UUIDs and unique, immutable codes
identify configuration; they never authorize a user. Role + Scope + Resource
checks and assignments belong to later M2 tasks.

`seed_system_roles()` is the single canonical seed, invoked by the migration and
`supabase/seed.sql`. It runs with the database owner's ordinary privileges, has no
parameters and grants no execution to application/browser roles. Repeating it
uses `ON CONFLICT (code) DO NOTHING`, preserving IDs, metadata and timestamps.
System role identity/code cannot be updated. Owner-controlled descriptive updates
maintain `updated_at`; this is migration/configuration maintenance, not an Admin
UI or API. New role definitions require an approved migration.

RLS is enabled on `roles`. No catalog read policy, table privileges or seed RPC
execution is granted to anon, authenticated or service_role. Browser role claims
are not authority. Role-label visibility and role-management APIs are deferred;
there is no bootstrap Admin assignment or Team Lead platform role.

`lib/auth/role-codes.ts` contains server-only typed catalog identifiers. Integration
tests compare them against the actual PostgreSQL seed and exercise duplicate
seeding, immutable identity, and direct table/RPC denial. Existing M1 profile/RLS
tests run against all migrations as part of the same disposable database suite.

```powershell
# Windows: use the PostgreSQL installation already used for M1 database tests.
$env:POSTGRES_BIN = 'C:\Program Files\PostgreSQL\17\bin'
pnpm test:integration
```

On other platforms set `POSTGRES_BIN` to the directory containing `initdb`,
`postgres`, `psql`, `pg_ctl` and `pg_isready`, or leave it unset when all are on PATH.
No database URL, production connection, Docker service or live credentials are
used by the integration suite. `pnpm test:db` runs the SQL assertions directly;
`pnpm test:integration` also checks the TypeScript/database contract.

## M2.2 ط£آ¢أ¢â€ڑآ¬أ¢â‚¬â€Œ Scoped role assignment reads

Migration `20260930020000_create_scoped_role_assignments.sql` adds UUID bindings
between platform users and system roles, with an explicit `assigned_by` profile,
active/inactive status, validity timestamps and created/updated timestamps. User,
assigner and role FKs preserve identity/history with restrictive deletion.

Each binding requires at least one of the five nullable scope UUIDs. Per the
approved task clarification, multiple scope columns are allowed and preserved
without defining cumulative/alternative permissions, inheritance or resource
access. These meanings belong to a later approved authorization policy.

Deferred foreign keys (no substitute resource tables were created):

| Assignment field | Future referenced table |
| --- | --- |
| organization_id | organizations |
| program_id | programs |
| cohort_id | cohorts |
| team_id | teams |
| project_id | development_projects |

Add each FK when its owning milestone creates the table, validating existing UUIDs
before applying the constraint. M2.2 does not prove those future resources exist
or implement an `assignRole` administration API.

`getActiveRoleAssignments()` is server-only, accepts no identity/scope/time input,
and first requires an active, verified platform profile. Its parameter-free
`get_active_role_assignments()` RPC uses invoker security and RLS, returning only
the authenticated caller's active bindings at database statement time:
`starts_at <= now` and `ends_at IS NULL OR ends_at > now`. An end must be strictly
after its start; null end means no scheduled expiry. Inactive, future, expired,
other-user and blocked-profile bindings are excluded. Every scope UUID, role ID,
validity field and assigner is returned intact; this read is not authorization.

Authenticated clients have only SELECT on eligible own rows and execution of that
read RPC. No client insert/update/delete, role request or assignment mutation RPC
exists. The role catalog's M2.1 privileges remain unchanged. Expired/inactive
history remains stored for trusted inspection, not exposed by these reads.

An active-row unique index with `NULLS NOT DISTINCT` rejects exact retries of the
same user, role, five scope fields and validity window. ID/assigner/audit timestamp
differences cannot evade this constraint. Distinct validity windows are preserved;
overlap/conflict policy is not invented. Trusted provisioning must handle a unique
conflict or use an explicit conflict-safe insert; no retry may silently grant a
different scope. Deactivation uses inactive status and preserves history.

Run `pnpm test:integration` with the PostgreSQL setup above. The real database
suite covers own/cross-user reads, active/inactive/future/expired bindings, all five
scope fields, exact retries with nulls, distinct windows, existing-domain FKs,
unscoped/invalid-window denial and denied client mutations. Server unit tests
cover verified identity, spoofed input, scope preservation and safe failures.



## M2.3 ط£آ¢أ¢â€ڑآ¬أ¢â‚¬â€Œ Server authorization foundation

`lib/auth/authorization.ts` provides `getAuthorizationContext`, `hasScopedRole`,
`requireScopedRole`, `requireAdminScope` and a safe API-result adapter. Trusted
server operations register a static role/scope/access policy with
`defineScopedRolePolicy` and a database/RLS-backed resource-metadata resolver.
Never construct a policy or resource descriptor from browser claims. The resolver
must explicitly confirm the approved resource rules through `resourcePolicyAllows`;
it must not perform mutations or return protected content before authorization.

Identity comes from verified Auth data and an active platform profile. Bindings
must belong to that identity, be active, have started and not have expired.
Authorization requires exactly one populated scope, an exact scope kind and UUID
match, and the requested role. Per the approved M2.3 clarification, multi-scope
bindings are denied until a later policy is approved. No scope inheritance exists.
Role IDs use the immutable M2.1 seed identities; integration tests verify the
TypeScript mapping against the actual database seed.

Operational ADMIN authority never implicitly grants educational access. A separate
eligible educational role binding is required. Resource resolution is followed by
a fresh identity/profile/binding check to reject revocation or session changes
during asynchronous lookup. Exported contexts are immutable inspection snapshots;
the authorization gates never accept a caller-supplied context as authority.

Errors use the documented `{ ok, data/error }` envelope and stable AUTH_REQUIRED,
FORBIDDEN, NOT_FOUND and VALIDATION_ERROR codes. Missing and inaccessible resources
produce the same generic FORBIDDEN response. NOT_FOUND is reserved for operations
that have already established access. Provider diagnostics are not serialized.
Future operations must still enforce database/RLS rules and appropriate transaction
boundaries. This foundation adds no resource APIs, role mutations or product UI.
## M2.4 ط£آ¢أ¢â€ڑآ¬أ¢â‚¬â€Œ Database authorization primitives

Migration `20260930030000_add_rls_security_helpers.sql` adds
`current_platform_user_id()`, diagnostic `has_active_role(role_code)`, and exact
role/scope checks `has_active_role_in_organization`, `has_active_role_in_program`,
`has_active_role_in_cohort`, `has_active_role_in_team`, and
`has_active_role_in_project` (each accepts `role_code`, `scope_id`).

These STABLE SQL SECURITY DEFINER functions read owner-controlled security data
without granting clients access to the role catalog. Their owner is the trusted
migration/table owner; preserve that ownership. An empty fixed search_path and
qualified objects prevent search-path substitution. They use no dynamic SQL.
EXECUTE is revoked from PUBLIC, anon and service_role and granted only to
 authenticated. Auth identity always comes from auth.uid(), never an argument or
user metadata. Active profile, active status, database statement time and exactly
one populated scope are mandatory. Future/expired/multi-scope assignments deny.

The helpers deliberately bypass source-table RLS, explicitly restrict every read
to the authenticated subject and return only a UUID or boolean. They do not call
other helpers or RLS-protected reads through invoker security, so future policies
can compose them without recursive role/profile policy dependencies. Keep these
predicates explicit when evolving the schema. Auth context is supplied by the
trusted Supabase gateway; clients must never receive direct SQL access capable of
setting trusted JWT context.

Role presence is diagnostic only: no global role authorization is approved.
Exact-scope predicates are necessary building blocks, not complete resource
permissions. ADMIN does not bypass educational rules. Scope UUIDs still have
deferred FKs, so these checks do not prove that a future resource exists.
Workspace, membership, sharing, artifact, review and resource authorization remain
deferred. No M2.5 policies or existing RLS grants/policies were changed.

`pnpm test:db` and `pnpm test:integration` run direct helper assertions alongside
all existing migration/RLS tests in disposable PostgreSQL. Tests cover all five
scope checks, spoofed metadata, null/unknown roles, injection-shaped input,
non-active profiles, validity windows, multi-scope denial, and definer grants,
ownership and fixed search path. No live project credentials are required.
## M2.5 ط£آ¢أ¢â€ڑآ¬أ¢â‚¬â€Œ Base RLS protections

Migration `20260930040000_harden_base_rls_policies.sql` explicitly enables RLS
on the three M1/M2 sensitive tables: users, roles and role_assignments. Existing
own-profile reads and active-profile updates remain limited to the M1 fields
(display_name, profile_image, timezone, locale). Restrictive ownership guards keep
later permissive policies from widening those boundaries accidentally.

Role catalog access remains denied to browsers. Restrictive role denial and
assignment INSERT/UPDATE/DELETE denial complement revoked client grants. Own
effective-assignment reads remain unchanged. A product ADMIN claim never becomes
owner or service authority. No generic assignment administration endpoint exists.

Trusted table/migration ownership and the existing narrow service_role profile
provisioning RPC remain the administrative paths. Direct service-role privileges
on these tables are revoked; BYPASSRLS never substitutes for missing privileges.
Keep service keys server-only and authorize callers before invoking provisioning.
No FORCE RLS is added: the audited owner/definer helpers depend on intentional
owner bypass. Future resource policies and role-administration commands are deferred.

Direct `base-rls.sql` tests use an actual STUDENT assignment and exercise anonymous
reads, self-escalation, cross-user profile/assignment writes, scope/assigner changes,
protected profile columns, deletion, valid own updates and trusted provisioning.
Transaction-only accidental grants/permissive policies additionally prove the
restrictive guards at the RLS boundary. Tests run with both pnpm test:db and
pnpm test:integration; no live project or credentials are used.
## M2.6 ط£آ¢أ¢â€ڑآ¬أ¢â‚¬â€Œ RBAC/scope acceptance tests

`tests/fixtures/m2-authorization.json` supplies deterministic Admin, Master,
Mentor, Student A/B identities and Cohort A/B, Team A/B and Project A/B UUIDs.
Server acceptance tests exercise the real authorization service with mocked
verified identity/assignment providers. They assert stable FORBIDDEN results for
AT-RBAC-001/002/003, positive controls, invalid assignments, spoofed browser claims,
and indistinguishable restricted/missing-resource errors.

The database runner expands only validated UUID placeholders in
`tests/integration/rbac-acceptance.sql`. It creates all identities locally and a
transaction-only restricted-resource fixture schema, then tests real PostgreSQL
RLS composed with M2 helpers. The fixture schema and all rows are rolled back;
no resource tables, production policies or role-administration endpoints ship.
Direct tests cover the same acceptance IDs, cross-scope confidential-field denial,
self-escalation, spoofing, validity, and inaccessible privileged RPCs. All existing
M1/M2 RLS attack tests also run. Test-only resource policies illustrate helper
composition and are not permissions for future product domains.

Run pnpm test:unit, pnpm test:integration and pnpm test:db with the PostgreSQL
prerequisites above. Existing Playwright authentication/public/recovery smoke
coverage remains the browser regression suite; M2 operations have no product UI
or HTTP endpoints yet, so their acceptance coverage is at server/SQL boundaries.
## M2.7 ط£آ¢أ¢â€ڑآ¬أ¢â‚¬â€Œ Security completion review

Authorization errors are rebuilt from approved codes and canonical messages,
including when an Error instance has been mutated. Regression tests prevent
private diagnostic text or unknown codes from entering the API envelope.
The direct database audit verifies the exact base-policy inventory, RLS flags,
client/service grants, protected profile column permissions, and privileged RPC
isolation. Negative acceptance tests explicitly include assigning another user,
changing one's own scope, and passing a user ID to a scope helper.

The M2 boundary uses verified server Auth identity, active profiles, exact single
scopes and trusted resource policies. Multi-scope denial and no inheritance remain
in force. ADMIN operational authority does not grant private educational access.
Database helpers have fixed empty search paths and explicit subject predicates;
trusted owner/definer bypass is intentional, with no browser generic CRUD path.
No M3 resources or administrative product endpoints were added. Database validation
uses disposable PostgreSQL and does not apply M2 migrations to a hosted project.
## M3.1 ط£آ¢أ¢â€ڑآ¬أ¢â‚¬â€Œ Organization foundation

Migration `20260930050000_create_organizations.sql` seeds FICI with slug `fici`
and stable UUID `00000000-0000-4000-8000-000000000501`. Owner-only seed retries
preserve identity, metadata, rename and lifecycle state. Unique lowercase slugs,
immutable identity/slug, timestamps and JSON-object settings are enforced.
Approved statuses are active, inactive and archived. Lifecycle changes retain the
row and scoped history; exact-scope Admins can reactivate inactive/archived rows.
No settings interpretation or settings mutation API is introduced.

`updateOrganization(id, { name, status })` is server-only and uses the existing
M2 operational Admin gate with a database/RLS-backed resource resolver. The narrow
`update_organization` RPC independently checks verified auth context, active profile,
currently valid exact single-organization ADMIN scope, and validated inputs. It
uses SECURITY DEFINER only because generic table mutation grants are absent, with
an empty search_path, qualified objects and authenticated-only EXECUTE. Its scalar
JSON result is runtime-validated. Browser Student/ordinary-user access is denied;
service_role gets no generic organization privileges. Scoped Admin SELECT and
UPDATE policies are present; no client INSERT/DELETE or direct UPDATE grants exist.
This operational permission never grants educational content access.

The deferred role_assignments.organization_id FK now references organizations
with ON DELETE RESTRICT. Migration validation intentionally fails for dangling
legacy organization UUIDs; a trusted operator must reconcile those before deployment,
without fabricated resources or dropped history. Other scope FKs remain deferred.
Existing M2 SQL fixtures now create real organization fixture rows in rolled-back
transactions. Tests cover seed retries, unique slug, Admin lifecycle, Student and
out-of-scope denial, privileged boundaries and FK protection. No programs/cohorts,
organization UI or other M3.2 features were added.
## M3.2 ط£آ¢أ¢â€ڑآ¬أ¢â‚¬â€Œ Program and curriculum versions

Migration `20260930060000_create_program_curriculum.sql` adds Programs under
organizations and immutable approved curriculum versions under Programs. Supported
Program types are workshop, professional_course and advanced_course; only
Professional Course is seeded. Program status is active/inactive/archived;
curriculum status is draft/approved/retired. Effective timestamps are nullable;
a populated end must be after a populated start. No effective dates are invented
for the initial seed.

The owner-only idempotent seed creates PROFESSIONAL_COURSE in FICI, stable UUID
`00000000-0000-4000-8000-000000000601`, and approved `2026 v1`, UUID
`00000000-0000-4000-8000-000000000602`. The initial current pointer is established
only when creating the Program; retries do not reset later pointer/lifecycle edits.
Codes are unique within an organization and version labels within a Program.

The current pointer uses a composite FK to version identity, Program identity and
approved status. A generated internal constant, current_curriculum_required_status,
ensures these rules remain declarative and race-safe. Draft/retired/cross-Program
versions cannot become current. Repoint or clear the pointer before retiring the
current version. Identity/parent fields are immutable; approved definition fields
cannot change. Retirement preserves those fields, and retired rows cannot change.
Destructive deletion is denied; future cohort references must point to the explicit
version ID, independently of the Program current pointer.

Server-only manageProgram, manageCurriculum, transitionCurriculum and
setCurrentCurriculum use the M2 operational Admin gate. Policies resolve the actual
parent organization from RLS-backed rows. The four narrow SECURITY DEFINER RPCs
independently derive identity and check exact organization-scope ADMIN, active
profile and current single-scope assignments. No caller user ID/role is accepted.
Fixed empty search paths and authenticated-only EXECUTE isolate those commands;
there are no generic client/service table writes. Reads are also scoped to that
Admin; learner curriculum visibility remains deferred to enrollment/release rules.
This explicit parent-organization rule does not grant educational-content access.

The deferred role_assignments.program_id FK is now validated with restrictive
deletion. Dangling legacy UUIDs fail migration and need trusted reconciliation,
not fabricated resources. Other scope FKs remain deferred. Unit/SQL tests cover
seed retries, uniqueness, draft edits, approval/immutability, current-pointer
integrity, historical references and unauthorized operations. Historical-reference
fixtures are transaction-only and are not cohort tables. No session definitions,
Workshop/Advanced seed, editor UI or M3.3 implementation is added.
## M3.3 ط£آ¢أ¢â€ڑآ¬أ¢â‚¬â€Œ Professional Course sessions

Migration `20260930070000_create_session_definitions.sql` seeds exactly the ten
approved titles and their order under Professional Course 2026 v1. All are active;
status vocabulary is active/inactive/archived. Stable session IDs end in 701ط£آ¢أ¢â€ڑآ¬أ¢â‚¬إ“710.
Number and sequence are unique within each curriculum version. Description is the
verbatim Primary Output section where present, otherwise Goal; learning_goal is
verbatim Goal from docs/06. The fixture catalog and SQL result are checked against
those source sections without modifying documentation or inventing content.

The explicitly approved one-time trusted seed runs before installation of history
guards. Later owner-only seed retries validate the ten rows and do no writes;
partial/conflicting data raises an integrity error instead of rewriting history.
There is no caller-controlled bypass flag or bootstrap RPC grant. Approved and
retired versions reject session INSERT/UPDATE/DELETE. Draft session identity and
parent cannot change; timestamps follow existing conventions.

Server-only manageSession resolves the actual curriculum/Program organization
and uses the existing exact-scope operational Admin gate. The narrow manage_session
RPC derives authenticated identity, checks current exact organization ADMIN scope,
locks the parent curriculum, and permits mutation only in draft. Fixed empty
search_path and authenticated-only EXECUTE isolate its intentional SECURITY DEFINER
writes; generic client/service mutation grants are absent. Parent locks serialize
edits with approval, preserving historical definitions. RLS reads are exact-scope
Admin only; learner release/enrollment rules remain deferred.

Unit/SQL tests cover exact titles/count/order and source provenance, seed retries,
duplicate number/sequence, draft Admin editing, approved/retired denial, Student
and unrelated organization denial. No attendance, live classes, activity instances,
video, release UI or M3.4 activity definitions were added.

M3.4 adds activity definitions only, with one trusted SCAMPER Example Set seed under Session 2 of 2026 v1. Metadata is curriculum-derived; unspecified AI/completion values stay null, configuration is an uninterpreted object, and approval defaults false. Instructor review is recorded as definition metadata only. Exact organization-scope Admin commands manage drafts; approved/retired definitions are immutable, including additions and deletion. Future changes require a new curriculum version. No execution, AI invocation, activity instances or dependency behavior is implemented. Migrations are validated in a disposable database; hosted deployment is separate.

M3.5 adds definition-level activity prerequisites with completion, approved_output,
artifact_available and gate_passed types. Both activities must belong to the same
curriculum version. The duplicate key is the activity pair, dependency type and
nullable artifact type (nulls compare equal); changing mandatory does not create
a distinct prerequisite. Mandatory must be supplied explicitly. Artifact type is
uninterpreted definition metadata, with no artifact lookup or runtime enforcement.
Exact organization-scope Admin commands manage drafts only. Both references use
restricting foreign keys; approved/retired prerequisites cannot be appended,
rewritten or deleted through normal paths. The narrow SECURITY DEFINER command
has a fixed empty search_path and derives identity from the verified database
auth context. Clients have no direct mutation grants or mutation RLS policies.

No dependency rows are seeded: M3.4 contains only Session 2's SCAMPER Example Set.
The following approved relationships remain deferred until the corresponding
activity definitions are approved and exist in a new draft curriculum version:

| Prior session | Dependent session | Documented relationship |
| --- | --- | --- |
| 4 | 5 | Problem Bank / Solution Bank feed evaluation and voting |
| 6 | 7 | Invention Structure V1 / Gap List feed mind mapping |
| 8 | 9 | Patent Reading Framework prepares patent search and comparison |
| 9 | 10 | Patent Landscape Snapshot feeds structured invention refinement |

These relationships come from docs/06 and docs/17 and are also recorded in
tests/fixtures/deferred-professional-dependencies.json. No activity records are
fabricated to satisfy them. Session 2 ط£آ¢أ¢â‚¬آ أ¢â‚¬â„¢ 3 likewise awaits its missing target
definition. M7 owns runtime gating, artifact resolution and Development Gate
execution; AT-ACT-002 is not claimed by this definition-only task. No graph-cycle
or sequencing execution behavior is implemented. Database tests create temporary
definition fixtures within rolled-back transactions only; deployment remains
separate from disposable-database validation.

M3.6 provides createCohort, getCohort, listAuthorizedCohorts and updateCohort in
features/cohorts/service.ts. Mutations require an ADMIN assignment in the exact
parent organization. MASTER reads require a valid exact cohort assignment; the
primary_master_id field alone never grants access. No Student administration or
implicit program-to-cohort Master permission is added.

Cohort statuses are planned, active, completed and archived. startDate is required;
endDate is optional and cannot precede it. settings is an uninterpreted JSON
object. Creation defaults to planned and empty settings. Update is a replacement
of editable metadata and explicitly requires status and settings. Program and
curriculum IDs cannot be updated. New cohorts require an approved curriculum;
existing references survive retirement and later current-version changes.

Creation validates an active platform profile and atomically creates its exact
cohort-only MASTER assignment, using the authenticated Admin as assigned_by.
The internal primary_master_assignment_id tracks the grant owned by that
relationship; a deferred constraint verifies its user, role and scope at commit.
Admin reassignment locks the cohort, validates the new profile, creates its grant,
updates the primary reference, and deactivates only the old tracked grant in one
transaction. Other assignments are preserved, including independent grants in
the same cohort. An unchanged primary Master does not create another assignment.
Profile suspension and assignment expiry/deactivation still deny access through
the existing M1/M2 authorization rules. Lifecycle status does not itself grant
permissions. Destructive deletion is blocked; archival preserves history.

RLS and revoked table write grants protect the database boundary. Narrow
SECURITY DEFINER commands have fixed empty search_path values and no caller
identity argument. Audit events remain deferred because no audit foundation
exists. No enrollment, team, workspace or classroom behavior is implemented.
The role_assignments cohort foreign key is now validated; deployments with
legacy dangling cohort UUIDs must resolve those references through trusted
approved data work rather than bypass the constraint. Database tests use only
disposable PostgreSQL fixtures; hosted migration deployment is separate.

M3.7 adds enrollments and enrollUser, removeEnrollment, listCohortEnrollments,
listMyEnrollments, plus the explicit Admin-only transitionEnrollment operation.
Enrollment roles are participant and instructor, and never assign platform roles.
Instructor enrollment may be created only for the current Primary Master with a
valid exact cohort MASTER assignment. Exact parent-organization Admins may manage
enrollments. The current Primary Master, with a valid M2 cohort assignment, may
enroll/remove participants only. Other scoped Masters have roster read access
only; Students cannot mutate enrollment records. No enrollment grants MASTER,
ADMIN or other privileged role assignments.

Enrollment state determines learner access:

| Status | Learner access | Timestamps/history |
| --- | --- | --- |
| invited | None | joined_at and completed_at null; activation is explicit |
| active | Normal cohort access foundation | joined_at set by the database |
| completed | Completed cohort history read only | completed_at set on completion |
| withdrawn | No current course access | Voluntary-exit history retained |
| removed | No current course access | Administrative-removal history retained |

enrollUser creates a new active row by default, or an invited row when explicitly
requested. Active enrollment/activation requires an active platform profile;
invitation records may also reference invited profiles. Admin transitions
explicitly activate invitations, mark completion or record voluntary withdrawal.
No email invitation, certificate or self-service withdrawal workflow is added.
Completed/withdrawn/removed rows cannot be reactivated; re-enrollment creates a
new row and a partial unique index enforces one active row per user/cohort.
Removal is idempotent, keeps joined_at and any existing completed_at, and never
deletes enrollment, profile or account history. Enrollment identity/role and
historical timestamps cannot be arbitrarily rewritten, and hard deletion is
blocked. Removal/withdrawal never invent a completion timestamp.

has_active_enrollment provides the authenticated user's active-course predicate;
has_enrollment_read_access separately includes completed-history read access.
The latter is not a privileged mutation/ongoing execution grant. A surviving
completed row may still grant history reads when another enrollment is removed,
but cannot make that removed enrollment active. Cohort metadata reads use this
read-only authorization foundation; future released materials/execution must
compose the appropriate active/history predicate with their own resource rules.
Existing curriculum definition visibility is not broadened to unreleased content.
Own history remains readable to the verified active account only, with database
RLS enforcing user isolation. Helpers use fixed search_path, derive identity
from authenticated context and avoid recursive cohort/enrollment RLS checks.
Direct client mutations remain denied even if table grants are accidentally added.

Enrollment/removal/transition audit events are required but deferred to the audit
milestone because no audit foundation exists. No team, workspace, project
membership, certificate logic or M3.8 operation is added. Tests use disposable
database fixtures; hosted migration deployment remains separate.

### M3.8 Primary Master integration

`assignMasterToCohort({cohortId, primaryMasterId})` requires verified active
identity and exact organization ADMIN authority, rechecked by its database RPC.
An active platform profile is required for the target, as in M3.6. Assignment and
reassignment lock the cohort and update its tracked exact-cohort MASTER grant
atomically. Valid same-Master retries are no-ops; revoked, future or expired
relationship grants remain as inactive history and are replaced by a fresh grant.
Unrelated role grants are untouched. `updateCohort` uses the same operation.
The primary-Master reference alone grants nothing: scope/time/profile checks and
RLS still apply. Participant administration additionally requires the current
primary relationship. No workspace, team or approval rights are implied.

### M4.1 Workspace schema

Five types: PERSONAL, TEAM, MASTER, SHARED, CASE_STUDY. Approved status values:
active (default), inactive, archived. Visibility is private only. Metadata tracks
creator/updater platform identities, timestamps and optional archived_at.
Personal owner is required; a partial unique index permits one active Personal
Workspace per owner. Archived history does not prevent a new active row; restoring
a row cannot conflict with an existing active row. No restore operation is added.
Owner/cohort and creator/updater foreign keys restrict deletion. Team/project UUID
columns are retained; their foreign keys are deferred to M5/M6 respectively.
RLS is enabled with no client grants/policies. No provisioning or access service,
workspace seeds, Team/Project resources, sharing or execution behavior is added.

### M4.2 Personal provisioning

`createPersonalWorkspace()` is an explicit server-only authenticated provisioning
hook. Call it from an authorized server operation when Personal scope is needed;
it does not create a second login/profile lifecycle or require a browser owner ID.
Only existing active platform profiles qualify. The Auth-bound database command
locks that profile, reuses the active private Personal row, or creates My Workspace.
The partial unique index and conflict handling protect retries/concurrency.
Inactive/archived historical rows are retained; no restore operation is added.
Owner-only active Personal SELECT is allowed by RLS; direct client writes, foreign
owners, anonymous callers and privileged type provisioning remain denied.

### M4.3 Workspace capabilities

`getWorkspaceAccess(workspaceId)` is server-only and returns capabilities without
resource metadata. It refreshes verified identity/M2 bindings and re-reads through
RLS before returning. Active/private PERSONAL permits only its owner. MASTER and
CASE_STUDY require ownership plus exact cohort-scoped MASTER authorization;
unscoped, inactive and archived rows deny. Enrollment and Admin authority do not
grant private content access. TEAM and SHARED deny pending their approved models.
View/create/edit are true only in an allowed scope; comment/share/review/approve/
member-management/chat remain false. Capabilities describe authority, not new
content APIs. Missing and inaccessible rows share a generic FORBIDDEN failure.

### M4.4 Workspace metadata retrieval

`getWorkspace(id)` gates metadata through the central capability resolver before
and after the RLS-backed read. `listMyWorkspaces()` queries only RLS-visible IDs,
orders by created_at then id, and returns fresh resolver-authorized rows. Revoked
candidates are omitted, while authentication/provider failures fail closed. Missing
and inaccessible IDs use the same generic denial. No contents, additional RLS
policies, sharing, or future Workspace resources are implemented.

### M4.5 Personal database privacy

Owner-only active Personal SELECT remains unchanged. Owner metadata edits and
client INSERT/UPDATE/DELETE remain unavailable. Restrictive mutation-denial policies
protect ownership, type, scope and lifecycle even if permissive write policies are
accidentally added. The narrow Auth-bound provisioning RPC remains the only Personal
creation path. Direct RLS tests exercise Student, Master, Mentor, Admin and anonymous
contexts, including temporary write grants/permissive policies inside rollback-only
attack fixtures. No sharing, submission or membership exceptions are granted.

### M4.6 Master provisioning

`createMasterWorkspace(cohortId)` provisions only the current verified active user,
using exact cohort-scoped MASTER authorization and the actual cohort resource.
Its narrow Auth-bound RPC locks the cohort and revalidates authority. One active
MASTER row per owner/cohort is enforced by a partial unique index; retries reuse
it, and different authorized cohorts have distinct Workspaces. The metadata label
is Master Workspace. No global scope, third-party owner, copied student content,
review/oversight UI or later capabilities are added. Existing RLS and capability
resolution still require ownership plus currently valid cohort MASTER authority.

### M4.7 Deferred Workspace foundations

TEAM/SHARED/CASE_STUDY are schema-valid types, not later milestone features.
TEAM provisioning requires real Teams and Membership in M5 and remains unavailable.
SHARED access/recipient permissions remain unavailable until explicit M13 sharing.
CASE_STUDY access requires the active owner's exact cohort MASTER scope; students
have no publication access and no Case Study Development Project is created.
Team/project UUID columns remain nullable. M5.1 now supplies the Team FK;
the Project FK remains deferred to M6.

### M5.1 Team schema foundation

Official Teams reference one Cohort, a valid cohort-scoped Master, and a unique
TEAM Workspace in that same Cohort. Composite foreign keys prevent subsequent
Workspace type/cohort drift. Master binding validation uses active profiles and
current single-scope MASTER assignments; it does not grant authorization from
the stored Master field or invalidate history after a grant expires.

Teams use created/active/completed/archived status, creation/update timestamps,
nullable description/Team Lead, and archive metadata. Client access is denied by
grants and RLS until approved operations/membership policies exist. No creation
transaction, membership, chat, UI, or Project linkage is implemented here.

Team-name uniqueness remains deferred: lifecycle states covered by uniqueness,
case sensitivity, and reuse rules require an approved policy. Archive preserves
the Team row; ordinary clients have no DELETE privilege or policy.

### M5.2 Team Membership schema foundation

Membership roles are member/team_lead/mentor; statuses are active/removed.
Active rows require a join timestamp and no removal metadata. Removed rows
require left_at >= joined_at and a removing actor. Join/identity timestamps are
immutable; removed records cannot be rewritten, reactivated, or deleted.
Rejoining creates a new row while a partial unique index permits only one
active membership per user/Team. No cross-Team exclusivity is enforced.

Team, user, adding actor, and removing actor use restrictive foreign keys.
Team/user-active indexes support later authorization queries. RLS and grants
deny client access. This schema does not yet grant Workspace/Chat access,
provide add/remove/move operations, or define Program/Cohort eligibility.

### M5.3 Team Chat storage foundation

PostgreSQL stores chat_channels, chat_memberships, and chat_messages. TEAM
channels require the exact Team/Workspace/Cohort combination; composite foreign
keys also require replies to reference a parent in the same channel. Channel
statuses are active/archived, and read/read_write membership levels are metadata
only. No client access is granted: all three tables have RLS and revoked grants.

TEXT content, sender identity, timestamps, and replies persist canonically and
are tested across a database reconnect. TEXT/FILE/LINK/SYSTEM are the exact
message types; FILE attachment handling remains deferred to the File milestone.
Other channel products, send/read operations, authorization, membership sync,
realtime, and message edit/delete policy are not implemented. Ordered loading
uses (chat_channel_id, created_at, id); membership and reply indexes support
later operations. Test records exist only in the disposable database runner.

### M5.4 atomic Team creation

The server-only createTeam service uses the existing scoped authorization layer
and one create_team RPC. Verified identity must have exact organization ADMIN
scope or exact cohort MASTER scope. The transaction locks/rechecks the Cohort,
parent Program scope, actor, and the existing Primary Master's active binding.
It creates an active private TEAM Workspace, a created Team, the Workspace's
team_id back-reference, and an active TEAM Chat Channel, returning their IDs.
Required-step failures roll back all resources; direct table CRUD remains denied.

Project linkage is rejected before M6 with DEPENDENCY_NOT_MET. TEAM_CREATED
audit and notification foundations are deferred to M5.12. Automatic Master Chat
membership awaits the approved Chat authorization policy. An optional Team Lead
requires an active profile and active participant enrollment in this Cohort.
The same transaction creates the active contextual team_lead membership and
Team reference; it grants no management or Chat authority. No add/remove/move operations
or Team Membership-based Workspace/Chat access are introduced here.
Personal provisioning takes no client owner, type or scope argument and cannot
create privileged Workspace types. Catalog/RLS tests guard these boundaries.

### M5.5 add Team member

The server-only `addTeamMember` service validates strict target input and M2
Role + Scope + Resource authorization before one identity-bound `add_team_member`
RPC. Exact organization ADMIN or exact cohort/Team MASTER scope permits mutation;
Student, contextual Team Lead, and Mentor roles never confer member management.
Teams must be created/active. Every target requires an active profile and active
participant enrollment in the Team cohort, including contextual mentor targets.

The transaction locks the cohort, Team, applicable role bindings, profile,
enrollment, Workspace and channel, creates a new active Team membership and
creates/reuses an open Chat membership. Closed historical membership rows are
preserved. Same-Team active duplicates are rejected; cross-Team exclusivity
remains deferred. Adding a different Team Lead when one is already set is
rejected; replacement belongs to M5.8.

The existing Workspace resolver and PostgreSQL RLS now allow eligible active
Team members into their active private Team Workspace. Member/Team Lead have
view/create/edit capabilities; contextual Mentor has view only. Chat additionally
requires a current open membership and active channel: member/Lead receive
read_write, Mentor receives read. All later capabilities remain false. No
platform Admin/Master shortcut grants Team content or Chat access. There are no
message operations, realtime, removal/move operations or Personal privacy changes.
`MEMBER_ADDED` audit and notifications remain deferred to M5.12.

### M5.6 remove Team member

The server-only `removeTeamMember` service reuses the M5.5 scoped mutation gate
and calls one identity-bound `remove_team_member` transaction. Created/active
Teams permit removal by an exact organization Admin or cohort/Team Master.
The target must have an active membership; an inactive profile or enrollment
never prevents an authorized actor from revoking a remaining Team relationship.

Removal preserves the membership row and joined_at, sets removed/left_at and
verified removed_by, closes corresponding open TEAM Chat memberships, and clears
an affected Team Lead without replacement. Closed historical Chat memberships,
messages, authorship, other Teams, and Personal Workspaces are untouched. The
existing Workspace/Chat resolver and RLS immediately deny removed members,
even if a stale Chat membership is later present. Required-step failures roll
back membership, Chat and Lead changes. MEMBER_REMOVED, optional reason
persistence, and notifications remain deferred to M5.12; no temporary audit
storage or reason logging is introduced.

### M5.7 move Team member

`moveTeamMember` authorizes both resources through scoped Master authority or
both through organization Admin authority. Its single `move_team_member` RPC
rejects same-Team/cross-Cohort moves, locks the shared cohort and both Teams in
UUID order, and composes the existing remove/add functions in one transaction.
All existing eligibility, duplicate and lifecycle rules remain enforced.
Member stays member; Mentor stays contextual mentor; a Team Lead moves as member
and the source Lead field is cleared. Target Lead assignment remains explicit.
A new target membership and synchronized Chat access replace the source access;
source membership, messages, attribution and private records remain in place.
No source content is copied. Personal and unrelated Team records are untouched.
Any source/target failure rolls back the entire move. Audit, reason persistence
and notifications remain deferred to M5.12.

### M5.8 Team Lead assignment

`assignTeamLead({teamId,userId})` uses a verified session and scoped Admin/Master authorization, then a single identity-bound `assign_team_lead` transaction. Cohort/Team locks serialize membership operations. Only created/active Teams and eligible active members qualify. The existing membership is promoted without changing lifecycle/history; a different current Lead conflicts (SQL `23505`, normalized to the approved `VALIDATION_ERROR` API code). Consistent retries preserve the same membership and do not rewrite timestamps. Existing open Chat access is synchronized to `read_write`; missing Chat membership is rejected rather than provisioned by this operation. Lead confers no platform or member-management authority. TEAM_LEAD_ASSIGNED audit remains deferred to M5.12. No replacement workflow or Chat message operations are introduced.

### M5.9 canonical Team Chat operations

Server-only `getTeamChatChannel(teamId)`, `sendTeamChatMessage({teamId,content,parentMessageId?})` and `listTeamChatMessages({teamId,limit?,cursor?})` reuse the centralized Chat access resolver and PostgreSQL RLS. TEXT writes use a narrow identity-bound RPC, database timestamps and same-channel parent validation; no sender/type/timestamp claims are accepted. Membership/Chat/lifecycle locks serialize writes with removal and moves. Direct client INSERT/UPDATE/DELETE stays denied. Members/Leads may read/write; contextual Mentors read only. No automatic platform Admin/Master content access exists.

Pagination returns `{items,nextCursor}` in ascending `created_at,id` order with a precise timestamp/UUID cursor, default limit 50 and maximum 100. Blank messages are rejected; no product-specific content-size limit is invented. Realtime acceptance portions remain deferred to M5.10. FILE/LINK/SYSTEM send, editing/deletion, attachments and advanced Chat features remain unimplemented.

### M5.10 private Team Chat Broadcast

PostgreSQL remains canonical. An AFTER INSERT trigger publishes identifier-only `team.message.created` notifications with `realtime.send(...,true)` in the message transaction. Failed writes/publication produce neither a committed message nor an event. Publication fans out to private `team-chat:<chat-channel-id>:<verified-recipient-id>` topics for currently eligible readers only, including contextual read-only Mentors. Recipient/profile/enrollment/Workspace/Chat rows are locked during publication. No routine Admin/Master visibility is introduced.

Recipient-specific delivery is required because [Supabase caches private channel access while connected](https://supabase.com/docs/guides/realtime/authorization). Removed users' old topics receive no future publications even while an old socket remains open. New joins are guarded by `realtime.messages` RLS, exact recipient identity and the existing Chat resolver. Normal clients cannot publish through SQL or Broadcast policies. The internal explicit-recipient predicate is not an executable client RPC. No Presence policy exists.

The server subscription descriptor and read-only server actions bridge the existing M5.9 canonical loader to `createTeamChatRealtime()` in `features/chat/realtime-browser.ts`. Connect/reconnect reauthorize and load PostgreSQL; SUBSCRIBED rechecks access and reloads to close join races. Events never create database rows or render message content. Canonical message IDs deduplicate loaded pages/events, and access failure clears the local view and closes transport. Call `disconnect()` on disposal and `reconnect()` after transport failure. No Chat UI is added.

Apply the migration to a Supabase project with `realtime.messages`, `realtime.topic()` and `realtime.send(jsonb,text,text,boolean)` available. Enable private-only Realtime channels in the project settings. This repository has no other Realtime policies; do not add broad SELECT/INSERT or Presence policies. Hosted websocket transport is not represented by the disposable native PostgreSQL runner: its test-only Realtime fixture captures publication and exercises actual PostgreSQL policies/triggers, while unit tests exercise the subscription adapter and reconciliation. These deterministic tests must not be described as hosted network delivery PASS. Fan-out costs one event per eligible reader and should be monitored at pilot scale. Presence, edit/delete, attachments and M5.11 hardening remain deferred.

### M5.11 Team/Chat RLS hardening

Active eligible members/Leads and contextual Mentors may SELECT their own Team metadata through the existing Team Workspace access predicate. Scoped Admin/Master operational metadata access remains separate from private Workspace/Chat content access. Team membership rows remain server-only: no roster/history client read policy is introduced. Chat memberships expose only the caller's currently open authorized record. Restrictive read guards protect Team resources against accidental permissive policies, with anonymous denial and restrictive client mutation guards on all Team/Chat tables. Personal/Master Workspace policies and M5.10 recipient-topic authorization remain unchanged.

Direct client INSERT/UPDATE/DELETE stays denied, including message INSERT: approved writes use the existing verified-identity transaction RPCs. `send_team_chat_message` is the only ordinary-user canonical write path and enforces current read/write access, caller-derived sender identity, database timestamp and same-channel replies. Contextual Mentors cannot write; Team Leads cannot manage membership/platform roles. SECURITY DEFINER helpers remain fixed-search-path, narrowly granted and protected against caller-selected identity; internal recipient/publisher functions are not client executable. Audit tables remain deferred to M5.12.

`tests/integration/team-chat-rls-security.sql` uses deterministic authenticated fixtures and exact resource IDs to exercise baseline grants, accidental broad-grant/policy resistance, stale removed membership, Mentor/Lead boundaries, operational/content separation, and helper ownership/grants. The full database runner also reruns M5.4–M5.10 transaction, Chat persistence and deterministic Realtime regressions. Hosted websocket delivery remains outside the native PostgreSQL harness.

### M5.12 audit and minimal notifications
Team lifecycle RPCs persist immutable, identifier-only audit history atomically. Audit access is server-only. Add/remove/move persist one recipient-only notification for the affected user; moves emit one canonical event. Consistent Team Lead retries emit no duplicate event. Private transaction components are not client-callable. Raw reasons/content are not stored. Earlier M5.12 persistence deferrals are now resolved. TEAM_ARCHIVED remains reserved for M5.13; notification UI, delivery, preferences and full lifecycle remain M15 work.

### M5.13 Team archive
`archiveTeam(teamId)` uses verified exact organization Admin or cohort/Team Master authorization and one database transaction. Archive preserves Team Lead, memberships, Workspace, Chat, messages, attribution, audit and notification history unchanged. TEAM_ARCHIVED persists atomically; audit failure rolls back. Existing lifecycle gates deny ordinary Workspace/Chat activity and member operations, including moves out of archived Teams. No archive notifications, restoration, or new historical browsing rights are introduced. Authorized operational Team metadata scope remains unchanged. Authorized archive retries preserve the timestamp and do not duplicate the event.

### M5.14 Team management acceptance coverage
`team-management-acceptance.sql` exercises AT-TEAM-001–005 together using canonical creation/lifecycle RPCs, named Team A/B/C and Professional Course cohort fixtures, and deterministic Admin/Master/Student identities. PostgreSQL tests verify audit/affected-user notification effects, RLS/direct-ID denials, realtime authorization, removal/move history preservation, isolation and archive regression. Unit acceptance tests exercise the actual Workspace HTTP handler, retrieval/resolvers and Chat services with provider I/O substituted; database enforcement is tested separately. Existing lifecycle, rollback and escalation suites remain required.

| Acceptance | Current coverage | Deferred sub-check only |
| --- | --- | --- |
| AT-TEAM-001 | Team/Workspace/Chat consistency, assigned Master, audit, denials | None |
| AT-TEAM-002 | Member/Chat activation, audit/notification, duplicates, Personal privacy | None |
| AT-TEAM-003 | Removal/revocation, messages/sender/time/history, audit/notification | Voting history — requires Voting entities/runtime |
| AT-TEAM-004 | Team/Workspace/Channel/Message exact IDs, route/service, SQL/RLS, realtime authorization | Artifact direct-ID — requires Artifacts |
| AT-TEAM-005 | Atomic move, source revocation, target activation, preserved history, no content transfer, Lead boundaries, audit/notification | None |

No later entities or new authorization model are introduced. Hosted websocket delivery is outside the deterministic PostgreSQL realtime authorization fixture; it is not claimed as tested by this suite.

### M5.15 Team Chat acceptance coverage
`team-chat-acceptance.sql` runs AT-CHAT-001–004 with deterministic A1/A2/B1/B2 identities and canonical Team A/B fixtures. It verifies TEXT persistence, authenticated sender/timestamps, private canonical-ID publication, duplicate event replay without duplicate rows, ordered pagination/fresh history loads, Team B/direct-ID/RLS denials, removed-member denials even with a stale open Chat membership, and Mentor/Team Lead/archive boundaries. Service/controller acceptance tests exercise send, list, recipient authorization, duplicate reconciliation and refresh/reconnect using the actual application code with provider I/O and transport substituted. Existing database publication/RLS and controller regressions remain required.

| Sub-check | Test boundary |
| --- | --- |
| AT-CHAT-001 send/persistence/sender/time | Service + PostgreSQL |
| Realtime authorization/private publication/canonical-ID reconciliation | PostgreSQL fixture + service/controller |
| AT-CHAT-002 cross-Team list/IDs/DB/subscription denial | Service + PostgreSQL RLS |
| AT-CHAT-003 removed send/read/subscribe denial | Service/controller + PostgreSQL, including stale Chat membership |
| AT-CHAT-004 refresh/reconnect/order/pagination | Canonical SQL history + actual service/controller |
| Hosted websocket transport | NOT EXERCISED — local deterministic realtime fixture; no live delivery claim |

PostgreSQL remains the source of truth. The hosted transport limitation does not defer any tested authorization/persistence blocker. No edit/delete, attachments, reactions, mentions, search, or other Chat products are added.

### M5.16 Cross-Team leakage security matrix
`cross-team-leakage.sql` attacks Team A using B1/B2, an unrelated Master/Mentor, a removed former member (including stale Chat membership), and anonymous database contexts. It verifies exact-ID/list denials and structural INSERT/UPDATE/DELETE denial across teams, team_memberships, workspaces, chat_channels, chat_memberships and chat_messages, including Lead/Master changes, relationship rebinding, membership reactivation and access-level escalation. Snapshots verify history/private rows remain unchanged. Positive controls retain Team A/B read/write, exact-scope Master operational access and contextual Mentor read-only access.

`cross-team-leakage.test.ts` exercises the actual Workspace HTTP handler, retrieval/resolvers, Chat and membership services. Known inaccessible and nonexistent IDs have the same safe responses; forged identity/role/scope/ownership/channel/sender claims do not authorize. Provider I/O is substituted in unit tests; direct enforcement is independently tested on PostgreSQL. Realtime authorization/RLS is deterministic; hosted websocket delivery remains NOT EXERCISED. No new M6+ entities or privacy rules are introduced.

### M5.17 integrated member-removal scenario
`member-removal-scenario.sql` executes the M5-owned AT-E2E-MEMBER-001 chain: active A1 accesses Team A and sends canonical TEXT; verified assigned Master removes A1; exact Team/Workspace/Channel/Message/membership identifiers, direct mutations and realtime authorization cannot restore access. Original closed Chat membership history is retained while a separate injected stale membership proves it cannot authorize. Historical join/attribution/timestamps, removal audit and affected-user notification persist. A1 still reads the unchanged private Personal Workspace; Master/teammates cannot. Remaining A2 reads A1 history, posts and subscribes; unrelated Team B remains isolated.

The companion unit scenario calls the actual services, authorization/resolvers and Workspace HTTP handler sequentially with provider I/O substituted. SQL tests separately enforce real PostgreSQL transactions/RLS/history/side effects. Hosted websocket delivery remains NOT EXERCISED; realtime authorization/publication boundaries are covered.

Later sub-checks remain explicitly DEFERRED: Idea contribution preservation → M6 Development Objects/M9 Ideas; Vote preservation → M10 Voting; Artifact edit/history → M8 Artifacts; AI access/revocation → M14 AI. No later schemas or removal behavior are invented.

### M6.1 Development Project schema

Development Projects have typed ownership and a compatible primary Workspace. Composite foreign keys and binding validation protect Individual, Team, and Instructor Case Study relationships. Active Project reads require current account and Workspace authorization; Team reads reuse current Team membership, and Case Study reads require owner plus exact cohort MASTER scope. Direct client mutation is denied. No Project Membership or creation business operation exists yet.

Stage and confidentiality are nullable nonblank text metadata without defaults, permanent enums, or authorization effects. Vocabulary remains deferred. Multiple Projects per owner are supported. Referenced Workspace scope cannot be rebound; lifecycle changes revoke access without deleting Project history. The optional Workspace project_id FK remains deferred to Project/Workspace linking integration.

Project SQL/RLS regression tests run through pnpm test:db and pnpm test:integration.

### M6.2 Project participation

Project Membership uses participant only, with active/inactive status. Authorization checks starts_at and ends_at on every read. Team Projects require both current Project Membership and existing Team authorization; Individual and authorized Case Study owners retain their M6.1 access without membership. No non-owner Individual/Case Study access or management/synchronization API is introduced.

Overlapping active time intervals for a user/Project are rejected by a concurrency-safe GiST exclusion constraint (btree_gist). Non-overlapping re-entry creates a new row; expired/inactive rows and join identity are immutable, and hard deletion is rejected. Inactive rows require ends_at. Membership rows are client-inaccessible; the narrow caller-bound helper returns a boolean only. Team removal denies access immediately without changing Project history.

### M6.3 Project creation

The server-only createDevelopmentProject service delegates to one identity-bound database transaction. Individual creators must own the active Personal Workspace; Case Study creators must be its owner and exact cohort-scoped Master. Team creation requires current Team/Cohort Master or organization-scoped Admin operational authorization and the exact compatible Team Workspace. Required eligibility rows remain locked through insert. No Workspace or participant Membership is automatically created; Team creation authority does not itself grant private Project content access. Project creation audit/change history is deferred to M6.10, with no reuse of Team audit events. Direct table mutation remains denied. SQL tests include post-insert failure rollback and ownership/scope attacks.

### M6.4 Program/Project participation

linkProjectToProgram is a server-only service backed by an atomic identity-bound RPC. Linking requires current Project access and approved target eligibility: Individual owner with active participant enrollment; Team participant with Master/Admin authority over both the owning Team and target Cohort; or authorized Case Study owner with exact target-cohort Master authority. Programs must be active and Cohorts planned/active. Reads require Project access plus active/completed target enrollment or exact target Master/Admin authority. Direct client writes are denied.

Links preserve Project identity, ownership, Workspace and memberships. Active duplicates and unapproved completed same-context re-entry are rejected. Link identity and completed history are immutable; no deletion workflow exists. Artifact Version UUIDs remain nullable with FKs/ownership validation deferred to M8; supplied entry IDs produce DEPENDENCY_NOT_MET. Object continuity is deferred to M6.5/M6.13. Multi-Program tests reuse the isolated Other professional fixture pattern; no Advanced curriculum is seeded.


M6.5 Development Objects: twelve typed object kinds; generic text content; nullable nonblank descriptive status/verification/origin fields have no authorization meaning. Metadata is supplemental JSON object only. Version counter starts at 1; formal version history is deferred. Objects currently bind to the Project primary Workspace; related Workspace support needs explicit later policy. Reads compose Project and Workspace RLS; direct client mutations are denied. Stable identity/creator and historical rows are protected. Archive does not delete records; visibility follows current Project/Workspace authorization. Origin-reference UUID validation/FKs remain deferred to their owning M7+ entities. No business object operations or product seed objects are introduced.

M6.6: server-only createDevelopmentObject, updateDevelopmentObject (objectId plus title/content/metadata), and archiveDevelopmentObject compose current Project and Workspace capabilities with identity-bound locked database transactions. Mentor writes are denied. Create derives creator from verified identity. Updates preserve scope/type/creator/version; archived objects are read-only. Archive preserves row, content, metadata, original timestamps, and is idempotent for currently authorized actors. Historical reads remain subject to Project AND Workspace RLS; active queries must filter archived_at IS NULL. Version increments/history are deferred; create/update/archive change logging is deferred to M6.10. No restore or destructive-delete operation exists.

M6.7: one-to-one Problem/Idea extensions use the canonical Object ID and parent Object RLS. Problem category/priority/perspective and Idea technique are nullable nonblank descriptive text. Six Idea acceptance states are classification only, with no sharing/Decision/archive permission effects. Narrow server-only create/update wrappers use locked M6.6 authorization; archived parents are read-only but extension history remains queryable under current parent access. Setting Personal provenance requires an active private Workspace owned by the verified caller AND original Idea creator. Unchanged provenance may be retained by authorized editors; it never grants private Workspace access. Parent/type/source-owner rebinding and destructive extension deletion are blocked. No M6.8 behavior introduced.

M6.8: directional Development Object relationships use exactly fifteen approved types and active/inactive history. Same-Project composite FKs, self-link checks, and unique active edges enforce integrity. Both endpoint Object RLS plus Project access govern reads; identity-bound locked RPCs and server-only services govern relate/unlink. Archived endpoints reject new links; authorized unlink cleanup and historical reads remain available under current Project/Workspace authority. Current-edge queries require active status and non-archived endpoints. Unlink preserves identity/description/creator, is idempotent, and cannot reactivate historical rows. Re-link creates a new row. No inverse edges, cloning, graph UI, or restore behavior. Relationship create/unlink change logging is deferred to M6.10.

M6.9: updateProjectMetadata accepts only projectId plus name/description/status/currentStage. Name trims to 1-200 characters; stage is nullable trimmed nonblank development-stage text, not curriculum progression or authorization. Status allows active/paused interchange and completion from either; completed/archived Projects and any archived_at flag deny normal edits. No-op patches for editable Projects preserve timestamps. A narrow authorized metadata RPC supports paused Project editing without widening ordinary Project/Object/Relationship RLS. Shared private write validation retains current ownership, Workspace edit, and Team AND Project participation checks; Mentor writes remain denied. Objects/Relationships/Memberships/Program links remain untouched. PROJECT_METADATA_UPDATED and PROJECT_STAGE_CHANGED persistence is DEFERRED - M6.10; any status-event naming remains for that owning milestone. No archive, restore, ownership/type/Workspace/confidentiality mutation is introduced.

M6.10 supersedes earlier Change Log deferrals: append-only change_log is now integrated atomically into Project create/metadata/stage/status, Object create/update/archive, and Relationship create/unlink RPCs. Three independent metadata categories produce distinct events only when changed; no-op updates and archive/unlink retries produce none. Fixed summaries exclude private content and metadata. Actor comes from verified context. Reads inherit current Project RLS; direct writes and the private writer are denied to clients. Nullable reason is reserved for trusted controlled use; no general user-authored log API. Version FKs remain deferred to M8; Decision/Evidence/AI FKs to their owning milestones. PROJECT_ARCHIVED is reserved for M6.11, with no archive operation here.

M6.11: archiveProject uses a narrow identity-bound database transaction. Individual owner and scoped Case Study Master owner may archive; Team archival uses existing exact organization Admin / cohort or Team Master management authority, never ordinary membership or Team Lead. Retry reauthorizes and preserves archived_at with one PROJECT_ARCHIVED event. All memberships, Program links, Objects, typed details, relationships, Team/Workspace and prior logs remain intact. Current RLS denies archived Project reads; ordinary writes stop. No restore, deletion, cascading archive or cleanup exists.

M6.12: consolidated direct-auth RLS tests cover all eight M6 tables, known IDs, removed/stale memberships, private ownership, explicit contextual Mentor read-only participation, default-deny RPC/grants, and archived-at lifecycle enforcement. Project reads require active status AND no archive timestamp; dependent Object/detail/link/relationship/log privacy follows that predicate. No automatic Master/Admin private Team content access or new participant management API is introduced.


M7.1 Activity Instance foundation: schema only; seven approved statuses, canonical Project/Workspace/Team binding and exact Cohort curriculum matching. New instances require an open exact Project/Program/Cohort link. Normal reads compose current Project/Workspace/Team authorization with active enrollment or existing exact Master scope; completed participation and non-active Student enrollment grant no Activity history access. Direct client mutations are denied. started_by/started_at/completed_at follow the approved lifecycle constraints. Started identity, scope and configuration snapshot remain immutable; historical rows survive participation/enrollment changes. Snapshot population, start/submit/complete/archive operations and participant/input/output tables remain deferred. The caller-bound read helper uses a fixed empty search_path and exposes no private row.


M7.2 Activity participants: explicit historical periods with only the participant role.
Only one open period per Activity/user; ended periods remain immutable.
Reads reuse current parent Activity authorization; participation never grants access.
Direct client mutations and automatic participant population remain unavailable.
M7.6 owns trusted participant creation and target eligibility validation.


M7.3 Activity input/output links reference canonical Development Objects only.
The same Project and current primary Workspace are required; reads compose Activity and Object RLS.
Inputs require an explicit required flag; links imply no approval, verification or copying.
Artifact/Version FKs await M8, Evidence FKs await M12, and Decision FK awaits its owning milestone.
Reserved UUID fields remain nullable but must be null until those targets are supported.
Client mutations remain denied; M7.8/M7.9 own registration operations.

M7.4: getActivityAvailability(input) is a read-only server service backed by the identity-bound, stable resolve_activity_availability SQL evaluator.
The caller supplies only Definition, Project, Workspace and optional Team IDs. A future start transaction must revalidate eligibility atomically; this result is advisory and creates no state.

Only exact Personal Workspace -> PERSONAL and Team Workspace -> TEAM mappings are supported. Null, aliases, Case Study and other modes fail closed. Production curriculum seeds remain unchanged; Team tests use an isolated curriculum fixture.

Personal starts require the authenticated owner and active enrollment. Team starts require the current exact Team Lead or scoped Master, plus existing canonical Project/Workspace authorization. Ordinary members, contextual Mentors, and operational Admin authority alone cannot launch. No Master access to private Personal content is added.

One matching open Project/Program/Cohort link and usable approved curriculum are required. Ambiguous contexts fail closed. Team must be active; created or archived Teams cannot launch normal execution.

M7.5 now evaluates dependencies centrally: required completion must match authorized runtime context; optional dependencies never block. Approval, Artifact and gate dependencies remain unsatisfied pending their canonical systems.
Exact-context not_started/active/submitted/under_review/revision_requested instances block duplicates; completed/archived history alone does not. Instance IDs are returned only when current Activity privacy permits.

Foreign/missing contexts return safe INVALID_CONTEXT without private names, ownership, dependencies or execution IDs. No participants, snapshots, mutations or Change Log entries are created.
Validation covers server input spoofing, deterministic PostgreSQL scope/eligibility/dependency/duplicate/privacy tests, and public-table fingerprints proving zero writes per resolver call.


### M7.5 Activity dependency evaluator

`evaluateActivityDependencies()` is server-only and shares identity/context validation with availability. Completion requires an accessible completed instance in the same definition, Project, Workspace, Team and Cohort. Every mandatory requirement must pass; optional requirements never block. Approval, Artifact and gate requirements remain unsatisfied pending canonical owning milestones. Responses include only curriculum requirement IDs after context authorization, never runtime IDs or private timestamps. All evaluation is read-only; eventual start must re-evaluate atomically. No M7.6 behavior is added.


### M7.6 Atomic Activity start

startActivity() accepts only Definition, Project, Workspace and optional Team IDs. One identity-bound RPC revalidates M7.4 availability and M7.5 dependencies, snapshots the eight approved execution fields, and inserts an active Activity plus exactly one initiating participant. No other users are auto-added. Current parent authorization still governs access after role/membership revocation.

Exact-context transaction advisory locks serialize competing starts. Supabase/PostgREST default READ COMMITTED is required so eligibility observes a preceding committed start; other isolation levels fail closed. Authorized duplicates return ACTIVE_INSTANCE_EXISTS rather than resuming. Canonical parent/authorization facts are locked against concurrent mutation; any snapshot/instance/participant failure rolls back the entire operation. Direct table writes remain denied. No resume, completion, bulk participation or M7.7 behavior is added.

### M7.7 read-only Activity resume

`resumeActivity(id)` reads canonical PostgreSQL state with current parent and link RLS. Definition display identity is narrowly gated; instructions and AI role come only from the immutable snapshot. Missing snapshot keys return null; no live-definition fallback occurs. Required input expectations are empty until an approved configuration contract defines them; existing input links retain their required flags. Resume neither starts nor repairs an Activity. AT-ACT-003 persistence coverage is foundation only; M7.14 remains deferred.

### M7.8 canonical Activity input registration

`addActivityInput({activityInstanceId, developmentObjectId, required})` requires current contribution authority and an active Activity. The source must be authorized in the exact same Project and Workspace. A unique Activity/Object/type key and READ COMMITTED transaction lock serialize retries. Matching required flags return the existing row; differing flags return CONFLICT. No Object content, participants, lifecycle, snapshot, or Change Log is modified. Direct table mutations remain denied.


M7.9: `addActivityOutput({activityInstanceId, developmentObjectId})` registers an existing canonical Object reference only in an active, currently writable exact Project/Workspace context. Identity and output type are server-derived; provenance and all other tables remain unchanged. Identical retries reuse one database-unique link. The narrow fixed-search-path RPC rechecks timed authority after locking; ordinary direct writes remain denied. Resume returns the persisted reference. Artifact/Evidence/Decision outputs and completion remain deferred. Disposable database tests include concurrent registrations and authority expiry during lock waits.

M7.10: `completeActivity(activityInstanceId)` completes an active Personal Activity for its current owner or a Team Activity for its current Lead/exact scoped Master with existing Project/Workspace access. Snapshot completion_rule accepts null/empty or V1 JSON (min_required_inputs, min_outputs non-negative integers); unsupported legacy text fails closed. Completion uses database time, canonical same-context Object link counts, locked current authority and idempotent retries. It never completes participant rows or approves outputs, changes baseline/stage, logs new event types or creates downstream execution.

M7.11 retains existing Activity RLS and business operations after dedicated audit. `tests/integration/activity-rls-security.sql` directly checks all four Activity tables, exact-ID privacy, stale/removed membership, independent Object RLS, anonymous/direct-write denial, protected snapshots/completion and the 15-function privilege/search-path inventory. No production policy or helper change is required; no hosted migration is pushed. Full operation/concurrency regressions remain part of `test:db` and `test:integration`.

M7.12 formal AT-ACT-001 runs in `test:db` and `test:integration`: canonical Personal/Team start, one initiating participant, database timestamps, immutable execution snapshots, duplicate and dependency denial, removal/privacy and transactional rollback. Existing independent-session start concurrency and server-wrapper tests remain required. No Activity business behavior or production seeds changed.

M7.13 formal AT-ACT-002 runs through `test:db` / `test:integration`: required completion blocks downstream start until canonical `complete_activity`, optional/future and multiple requirements, lifecycle states, independently isolated execution scopes, sanitized denial and direct bypass regressions. No dependency business semantics or production seeds changed.

M7.14 formal AT-ACT-003 uses committed PostgreSQL state and separate request processes: approved start/input/output operations, exact Personal/Team reconnect payloads, all eight snapshot fields after trusted fixture revisions, actual completion, removal/current scope denial and whole-database read-only fingerprints. Runs in `test:db` and `test:integration`; no production resume behavior changed.

M7.15 AT-ACT-004 generic foundation uses actual output/complete/start/input RPCs in one exact context: A output and B required input reference the same canonical Object, all Object rows/provenance stay unchanged, resume retains both links, foreign/stale access is denied. Formal approval handoff is DEFERRED TO M8; completion does not satisfy approved_output. Runs in `test:db` / `test:integration`.

M7.16 dedicated Activity leakage suite reuses four-table RLS/CRUD/helper/Object privacy attacks with canonical Team B positive controls, foreign RPC/error parity, spoofed claims, same-Workspace cross-Project references, removed-participant history and inaccessible upstream completion. Runs in `test:db` / `test:integration`; no new product permissions or production behavior.

M7.17 snapshot integrity creates distinct approved V1/V2 curriculum versions through existing Admin RPCs, without disabling immutability. Exact eight-field snapshots remain bound to original definitions; V1 zero-output completion and V2 required-output completion use their stored rules. Active/completed direct mutation and foreign snapshot reads are denied. Workspace mode remains Team Workspace for valid exact scopes. Runs in `test:db` / `test:integration`; no product behavior changes.

M7.18 database hardening adds an exact-context partial unique index for nonterminal Activity executions, treating null Team scope as equal. Trusted duplicate writes fail instead of silently creating parallel executions; completed and archived history remains preserved. The Activity schema suite checks this database boundary alongside the existing start concurrency tests.

M8.1 adds Artifact stable identity with the approved 16 types and ACTIVE/ARCHIVED lifecycle. Composite FKs bind its canonical Project/Workspace and optional Activity provenance. Reads reuse current Project/Workspace/Team authorization; ordinary mutations are denied. Archived reads/restore are not enabled. Version content and the nullable current-version FK/lifecycle remain deferred to M8.2+. Schema, direct-ID privacy, revocation and preservation checks run in test:db/test:integration; M7 handoff still uses Development Objects only.

M8.2 adds JSONB Artifact Version snapshots, exact eight statuses, positive unique per-Artifact numbering, same-Artifact lineage and nullable current-pointer FK. Version visibility inherits Artifact RLS; direct client writes are denied. Approved/current metadata requires actor/time, and historical content/identity is protected. No creation/edit/approval/reopen RPC, number allocation, automatic pointer transition or Object-link workflow exists yet. Draft editing/checkpoint and simultaneous-Draft policies remain deferred. Schema/privacy/history tests run through test:db/test:integration; AT-VER-001 formal acceptance remains M8.17.

M8.3 adds Artifact/Object links as canonical references with exact Artifact Version, Project and Workspace checks. Reads require both Version and Object RLS access; direct client mutations remain denied. Roles, sequence and structured JSON metadata are contextual only. No Object copying, status/pointer changes or public membership workflow is implemented. Version membership editing semantics remain deferred. Tests run in disposable PostgreSQL; no hosted migration push is required.

M8.4 `createArtifact()` uses one caller-bound database transaction to create an ACTIVE Artifact and empty V1 DRAFT, with the current pointer null. Optional active/completed Activity provenance requires current exact scope authorization and is never mutated. No Object links, Activity outputs, approval or subsequent-Version operations are added. Artifact creation audit remains deferred because the current Project change-log vocabulary has no suitable event. Local database tests include forced Version-insert rollback and independent-session creation; no hosted migration push is performed.

M8.5 `createArtifactVersion()` appends a caller-authorized Draft under an Artifact row lock, assigning the latest number plus one and latest Version as predecessor. Existing Version snapshots, Artifact metadata/current pointer, Object links and Activities remain unchanged. `changeSummary` is required and nullable; snapshots follow existing JSON validation. Future source arrays may be absent/empty; non-empty Decision/Evidence/AI references fail with a deferred-integration validation error. No one-Draft restriction, link inheritance, deduplication or subsequent review workflow is introduced. Disposable database tests exercise sequential/concurrent numbering, rollback and revocation/archive races.

M8.6 provides server-only Artifact/Version reads, ascending Version history and idempotent Artifact archive. Services expose canonical camelCase metadata and opaque NOT_FOUND failures for unknown/inaccessible IDs. Active and archived Artifacts share the same current Project/Workspace authorization; historical authorship and removed membership grant no access. Archive changes lifecycle metadata only, preserves current pointers/Versions/Object links, blocks new Versions, and offers no restore. AT-VER-003 retrieval foundation is covered; formal M8.17 remains deferred.

M8.7 adds caller-bound `submitArtifact()` with exact Draft/Activity validation, primary-Master resolution, atomic Version submission and active-cycle uniqueness. Reviewer access is limited to committed active submissions and current primary/cohort MASTER authority. Minimal Artifact metadata is read through a narrow RPC; exact submitted Versions and linked canonical Objects use RLS. Other Versions, Workspace/Project browsing and unrelated Objects remain private. Audit integration is deferred; notifications await M15. No M8.8 review mutations are implemented.

M8.8 adds `startReview()` and `addFeedback()` as caller-bound, current assigned-reviewer RPCs. Review start atomically transitions the exact Submission/Version and records one append-only STARTED_REVIEW action; retries reuse it. Each Feedback has immutable server-derived Submission/Project/author context, optional exact Version targeting, OPEN state, and one COMMENTED action with no copied confidential note. Ambiguous nullable targets fail validation. Reads inherit exact Submission RLS; no reviewer Project/Workspace browsing is added. Revision, approval, rejection, feedback resolution and notifications remain deferred.

M8.9 `requestRevision({submissionId,note})` is current-reviewer-only and atomic: exact Submission/Version transition, immutable revision action, exact revision feedback, and minimal Submission audit. Identical retries reuse history; changed or inconsistent retries fail closed. Notification delivery remains deferred to M15. No Version creation or Activity/current-pointer mutation.

M8.10 `createRevisionDraft({submissionId,contentSnapshot,changeSummary})` validates an exact latest revision-requested source and reuses Version creation under the canonical Artifact lock. Repeated/conflicting requests fail safely. Existing `submitArtifact()` creates a separate review cycle, requires the same Activity for revision lineage, and resolves the current reviewer again. No Draft editor, implicit Object-link copy, or new audit vocabulary; notifications remain deferred to M15.

M8.11 `approveArtifact({submissionId,approvalNote?})` atomically commits CURRENT status, approval metadata, exact prior-current supersession, Artifact pointer, Submission APPROVED, Review Action and minimal ARTIFACT_APPROVED audit. The existing current Primary Master + exact assigned reviewer policy remains required, including retries. Public review read entitlements remain status-limited. Baseline mutation is deferred to M8.13 and notifications to M15; no Activity/Feedback/Object-link mutation.

M8.13: setProjectBaselineItem explicitly selects an already CURRENT, formally approved Version through the current exact-cohort Primary Master. This narrow command grants no general Personal/Team Project read/edit authority or membership. Baseline reads retain Project RLS. Composite foreign keys, one-effective-row uniqueness and scope/Artifact/slot transaction locks protect replacement history, retries and concurrency. Approval/reopen never update baselines. BASELINE_UPDATED audit is atomic and content-free; change-log integration awaits approved vocabulary. Local tests cover three generations, rollback, privacy, Master reassignment and independent-session races. No hosted migration push or M8.14 integration.

M8.14 activates exact-context approved_output and artifact_available dependencies through the existing M7 evaluator. Draft-backed ACTIVE Artifacts may satisfy availability; approval requires the exact CURRENT pointer and approval metadata. Candidate lists contain authorized references only and never select or insert inputs automatically. addActivityInput supports Artifact identity and exact CURRENT approved Version references; addActivityOutput supports stable Artifact identity with exact originating Activity. Canonical FKs, append-only Artifact links, source-aware Activity I/O RLS and locked write-time validation preserve historical Version IDs and prevent cross-Team/Personal access or stale-current linking. Completion and gate semantics remain unchanged; approval does not update Activity state or Project baselines. AT-ACT-004 generic and formal approved handoffs and AT-CUR-001 Problem Bank reuse are tested with isolated fixtures. No hosted migrations or M8.15 behavior.

## M8.15 Artifact, Version and Review RLS

The dedicated disposable PostgreSQL suite checks all seven M8 tables, direct
field/known-ID attacks, anonymous execution, current reviewer scope, canonical
member removal, archived history, baseline command isolation, audit forgery and
child-table leakage. The only policy change adds a restrictive Feedback target
guard: visible Submission context cannot bypass independently denied Version or
linked Object RLS. Existing controlled workflows and execute grants are retained.
See `tests/integration/M8_RLS_INVENTORY.md` for the table/function inventory.
`pnpm test:integration` includes this suite and the prior M8.1–M8.14 regressions.
All runs use disposable local PostgreSQL; no hosted migration push is performed.
## M8.16 consolidated review acceptance

`node scripts/test-db.mjs --review-acceptance` runs the dedicated disposable
PostgreSQL AT-REV-001–005 lifecycle suite. The normal integration/database run
also includes it, M8.15 security checks, approval races/rollback and M8.14 formal
approved-output handoff. The Team fixture proves Draft → Submitted → Under
Review → Revision Requested → new Draft → Resubmitted → Approved/CURRENT,
immutable prior context, exact reviewer authority, safe retries, Student denial,
Team B isolation, removed-member revocation and manual-only baselines.
Submission retries retain their existing safe conflict behavior.

Core/security/history are asserted separately from notification effects.
Submission, revision and approval notifications are **DEFERRED TO M15**: the
existing minimal notification table supports Team membership events only.
Implemented M8 audit coverage is REVISION_REQUESTED and ARTIFACT_APPROVED;
ARTIFACT_SUBMITTED and REVIEW_STARTED audit events are not added by this task.
The browser E2E suite validates existing application/auth flows; the formal
review acceptance uses real authenticated PostgreSQL contexts without adding UI.
## M8.17 — Versioning acceptance

`node scripts/test-db.mjs --version-acceptance` runs AT-VER-001/002/003 against a fresh disposable PostgreSQL cluster. It reuses the canonical reviewed M8.16 lifecycle, then verifies approved reopening, actual supersession, protected-field mutation/deletion denial, lineage, numbering, current-pointer separation, preserved references, and Personal/Team/reviewer/removed-user history privacy. The normal integration suite includes this acceptance suite plus existing Version constraint, rollback, M8.15 RLS, and concurrency regressions. Application tests verify strict input rejection and exact authorized history mapping, including null summaries and ascending version numbers. No hosted migration or application behavior is added.
## M8.18 — AT-TX-001 approval rollback

`node scripts/test-db.mjs --approval-rollback` runs real PostgreSQL fault injection in a fresh disposable cluster. Transaction-local AFTER triggers verify earlier writes before raising a controlled error at prior-current supersession, new CURRENT/approval metadata, Artifact pointer, Submission approval, Review Action insertion, and final audit insertion. First approval also tests Version and pointer boundaries. Complete row snapshots include Feedback, Activities, baseline, notifications, links, and canonical Objects. The M8.14 evaluator must return unchanged dependency/candidate results after rollback and never select the rolled-back Version; replacement may legitimately retain the prior committed CURRENT candidate. Normal approval and exact retries are then verified. Hooks have runtime EXECUTE revoked, are removed after each case, and are discarded with the test transaction. No production fault parameter, migration, or hosted push is introduced. Notification rollback is DEFERRED TO M15. Browser E2E is optional and is not run by this transaction-only suite.
## M8.19 — AT-CON-002 terminal reviewer concurrency

`node scripts/test-db.mjs --terminal-concurrency` uses independent READ COMMITTED psql connections in a disposable database. It observes actual PostgreSQL lock waits via pg_stat_activity/pg_blocking_pids before releasing client-controlled test barriers; observer connections verify uncommitted writes remain invisible. Approval-first, revision-first, and natural races each run three times. Same-note retries, changed-note conflicts, competing Versions, stale opposite actions, final-audit failure/rollback recovery, reviewer revocation while waiting, and archive while waiting are covered. Each race checks canonical state, exact terminal history/Feedback/audit counts, preserved earlier comments, immutable Version fields, baseline/Activity preservation, and post-commit M8.14 candidates. The one-CURRENT index is attacked directly. No deadlock is suppressed or retried. Coordination is test-only client input/row locks; the disposable AFTER-audit fault hook has runtime EXECUTE revoked and is dropped. Production review permissions and transactions are unchanged. Browser E2E is optional and skipped for this database-only milestone.
### M8.20 Draft conflict protection

Server-only updateArtifactDraft requires artifactVersionId, expectedDraftRevision and contentSnapshot; optional changeSummary preserves the existing value when omitted. Retrieval exposes draftRevision. Successful DRAFT saves on ACTIVE Artifacts increment the independent counter once, including identical saves. Stale saves return CONFLICT: reload before explicit retry. No merging, automatic retries or new Versions are created. Existing canonical scope locks serialize saves with submission/archive. Normal direct table UPDATE remains denied. No audit, baseline, Activity or pointer side effects. Liveblocks/full collaborative AT-CON-001 remains deferred to M11.

Dedicated local PostgreSQL checks: node scripts/test-db.mjs --draft-conflicts. Migration 20261007150000_artifact_draft_cas.sql is not pushed to hosted projects by this task.

Future M11 collaborative checkpoints into an existing canonical Draft must honor this token or an explicitly approved later checkpoint/version strategy; realtime merging does not bypass PostgreSQL conflict protection.

### M8.21 integrated Artifact revision-cycle acceptance

Run node scripts/test-db.mjs --revision-cycle against a disposable local PostgreSQL cluster. One Team scenario exercises Activity provenance, trusted M8.3 Object-link composition, V1 Draft save/submission/review/feedback/revision request, V2 revision/CAS conflict/resubmission/approval, and exact approved-output handoff. Captured historical rows, Object identity, baseline and upstream Activity remain unchanged; direct body/pointer/history attacks and Team B/removed-member reads are denied. Review notifications remain DEFERRED TO M15. The full integration runner also feeds the actual PostgreSQL history rows through listArtifactVersions via a test transport adapter and reruns existing M8 acceptance/security/concurrency suites. Browser E2E remains a regression of implemented routes, not a fabricated Artifact review UI. No production migration or hosted push is required.

### M8.22 security and integrity hardening

The current-Version pointer now has a private deferred PostgreSQL constraint: a non-null pointer must reference the same Artifact's CURRENT Version. This closes a reproduced trusted-write integrity gap while allowing the approval transaction's intermediate states. Existing invalid data causes migration failure rather than historical-data repair. Ordinary client grants remain unchanged. Regression coverage is in `tests/integration/artifact-current-pointer-integrity.sql`, included in `pnpm test:integration` / `pnpm test:db`; the existing M8 RLS inventory also checks the new trigger function's grants and fixed search path. Artifact notifications remain deferred to M15. No M9 behavior is introduced.
M11.11: removeMindMapNode({ nodeId, expectedRevision }) removes only authorized DRAFT-map non-root leaves and incident visual edges atomically. Canonical Objects/history are preserved. Mandatory CAS and the shared map lock prevent stale removal. Focused validation: node scripts/test-db.mjs --mind-map-node-removal. No recursive deletion, archive or restore.

### M12.1 Evidence schema foundation

`20261011000000_create_evidence.sql` adds typed source-backed Evidence with exact
Project/Workspace foreign-key binding, server-context creator defaults, immutable
capture provenance, and archive history. New rows must be UNVERIFIED with no
verifier/time. Only UNVERIFIED implies null verification fields; the reverse and
verification authority/workflow remain deferred. Named offline sources require
no fake URL or file. Metadata is supplemental; source identity stays typed.

SELECT reuses canonical Project authorization, including Personal ownership,
current Team and Project participation, and exact Case Study ownership/scope.
Role-only Master/Admin/Mentor authority grants no private Team Evidence access.
Authenticated/anonymous clients cannot mutate Evidence. Schema fixtures use
trusted caller-bound writes; no createEvidence/verifyEvidence API was added.

`file_id` is a nullable deferred reference: the canonical Files FK and authorized
file validation await the Files milestone. No file storage or sharing is implemented. Five indexes cover Project, Workspace, creator, type,
and verification filtering; no speculative file/JSON/archive index is added.

`node scripts/test-db.mjs --evidence-schema` runs the focused storage/RLS suite;
the complete integration command includes the same assertions and row/type parity.

### M12.2 Evidence Links

`linkEvidence({ evidenceId, entityType, entityId, relationshipType, notes? })` returns the canonical persisted link. Targets are stable `DECISION`, `REQUIREMENT`/`GAP` Development Object, and `ARTIFACT` identities. `PATENT_RECORD` is recognized but returns `DEPENDENCY_REQUIRED` until its owning M12 milestone; no placeholder storage is created.

Creation reuses current canonical Project write authority and requires both endpoints in the same Project/Workspace. Read-only contextual mentors cannot create links. New links reject archived endpoints; authorized retries return the original active link and notes. Links grant no access and do not verify Evidence, finalize Decisions, change GAPs, or alter Artifact Versions. RLS reads compose both endpoint policies; ordinary direct client writes and role-only private access are denied.

Creator and timestamps are server-derived. An Evidence-row lock and partial unique index serialize identical active links, including independent actors; different relationship types remain distinct. Links retain immutable identity/notes and nullable archive metadata, with no unlink/restore API. Polymorphic targets are checked against canonical tables; existing target identity/history guards preserve referenced entities. The Evidence and creator FKs restrict deletion. Full source-history and target indexes support justified lookups; no speculative relationship/JSON index is added.

`node scripts/test-db.mjs --evidence-links` runs canonical Decision/Requirement/GAP/Artifact controls, privacy/exact-ID/join/direct-client/rollback attacks and duplicate races on disposable PostgreSQL. The complete integration gate includes this suite plus the M12.1 regression. No createEvidence, verification, Files, Patent Record, sharing, or AI operation is introduced.


### M12.3 Create Evidence

`createEvidence({ projectId, workspaceId, evidenceType, title, description, sourceName, sourceUrl?, fileId? })` uses the user-scoped authenticated client and narrow `create_evidence` RPC. The approved function-only migration changes no Evidence table, constraints, RLS or direct-write grants. Only authenticated EXECUTE is granted; PUBLIC, anonymous and service-role execution remain revoked.

The RPC reuses canonical current Project/Workspace write authorization and its locking of account, enrollment, Team and Project participation. Personal and Case Study ownership remains exact; role-only Master/Admin/Mentor does not gain Team-private write access. All twelve Evidence types remain controlled. Title, description and source name use accepted whitespace trimming and must be nonblank. Optional HTTP(S) source references use the accepted M12.1 format and are trimmed but never fetched or scraped. Offline named sources need no fake URL or file. Supplied non-null File IDs return DEPENDENCY_REQUIRED until the Files milestone.

Identity, UNVERIFIED status, null verifier/time, current capture time, empty metadata and non-archived state are server-derived. No verification, Evidence Link, AI, storage, ownership transfer, update/archive workflow or idempotency policy is introduced. Intentional repeated creations produce distinct rows. Insert failures roll back without links or partial state.

`node scripts/test-db.mjs --evidence-create` runs the RPC/security/rollback suite, M12.1/M12.2 regressions and AT-EV-001 through the actual exported createEvidence service with a disposable PostgreSQL transport adapter. The adapter substitutes only the authenticated fixture context and database transport; it does not mock canonical persistence or RPC authorization. Its dedicated Vitest configuration is invoked by the database runner, avoiding recursive cumulative execution. Full cumulative integration includes the same acceptance and regression gates.


### M12.4 Verify Evidence

`verifyEvidence({ evidenceId, verificationStatus, note? })` uses a narrow authenticated `verify_evidence` RPC. Only the exact current active Team Lead with canonical Project/Workspace access may verify Team Evidence; creator, ordinary member, and platform role alone grant no authority. Current Personal owners may verify their own scope. Other Workspace types, including Case Study, default deny in this milestone. No sharing or broader review role is inferred.

All five accepted confidence states are explicit targets. New transitions set server-derived verifier/time and append immutable `evidence_verification_history` (Evidence ID, previous/new status, actor, time, optional trimmed nonblank note). Returning to UNVERIFIED clears only the current-row verifier/time; history retains the actor/time/note. Current source identity/content/metadata, links and downstream workflow remain unchanged; existing update-audit metadata is stamped normally.

Same-status requests recheck current authority and return the exact existing row without changing verifier/time or appending/replacing notes. To record a note, a real status transition must occur; this operation does not provide a separate comment workflow. Overlapping requests fail explicitly with CONFLICT rather than silently overwrite. An initial row/history-count observation, canonical authority locks and a NOWAIT Evidence-row lock protect against stale/ABA observations without expanding the approved three-field input contract. Committed state and history are atomic.

History has Evidence/user RESTRICT FKs, one source/time index and immutable UPDATE/DELETE guards. SELECT inherits current Evidence RLS; ordinary client history mutations and generic Evidence UPDATE remain denied. RPC PUBLIC/anonymous/service-role execution is revoked.

`node scripts/test-db.mjs --evidence-verify` runs current/former/new Lead, Personal owner, creator/non-lead, Team B, role-only, archive, exact-ID/join/history mutation, all-state, same-status, atomic-failure and independent-session conflict/rollback controls, plus M12.1–M12.3 regressions. Full cumulative integration includes these same gates. No M12.5, Files, Patent schema, sharing, AI or general reviewer engine is added.

### M12.5 AI-like analysis is not Evidence

AT-EV-002 saves an isolated analysis-like JSON fixture through the existing Artifact Draft service/RPC. It creates no AI entity. Full PostgreSQL Evidence rows/IDs, verification fields/history, Evidence Links and Decision Links remain unchanged. Transaction-local RPC tripwires and live function/trigger catalog checks guard against automatic creation or verification. Team B, removed members and role-only Master/Admin/Mentor cannot use the generic path to write private Team content or Evidence. The real public service test also proves that a missing/blank source name is rejected without any Evidence RPC call.

Evidence remains a separate source-backed domain. A human must perform a separate explicit `createEvidence()` capture with valid source identity; factual-sounding analysis, an Artifact title, or a model label never supplies that identity automatically. Verification and linking remain separate explicit operations. No conversion feature, provider, AI schema, source extraction, migration or production behavior is added.

`node scripts/scan-evidence-creation-paths.mjs` classifies repository creation references and asserts one explicit production creation transport and SQL insert. `node scripts/test-db.mjs --evidence-boundary` runs AT-EV-002 plus all M12.1–M12.4 regressions on disposable PostgreSQL; the same checks run in cumulative integration.

### M12.6 File metadata and private Storage foundation

`files` stores uploader, Workspace, optional compatible Project, filename, MIME metadata, exact nonnegative byte count, approved `active`/`archived` lifecycle, and update/archive history. Its provider key is generated as `workspaces/<workspace UUID>/files/<File UUID>` in the fixed `fici-private-files` bucket. Filenames never select paths; URLs and caller-supplied keys cannot be stored in the generated column. Object keys are globally unique across active and archived rows. Byte counts are bounded by exact JavaScript integer representation, not a product upload-size limit; M12.7 owns the latter and MIME validation.

Current active metadata reads reuse canonical Workspace access and, when present, exact Project authorization. Personal ownership remains private; Team access requires current membership/context, with no role-only Master/Admin/Mentor grant. An existing contextual Team Mentor may retain the current read-only Team capability; the platform Mentor role alone grants none. Inactive scopes and archived File rows are denied normal reads. Uploader and timestamps are caller-bound/server-stamped; direct client writes are denied. Identity/content metadata and archived history are immutable; no upload, rename, archive/restore, registration or download business operation is added.

`file_links` uses approved targets `EVIDENCE`, `ARTIFACT`, `ACTIVITY_INSTANCE`, `CHAT_MESSAGE`, `DEVELOPMENT_OBJECT` and relationships `ATTACHMENT`, `EVIDENCE_SOURCE`, `ARTIFACT_FILE`, `CHAT_ATTACHMENT`, `REFERENCE`. Identical active links are unique, while archived history and distinct relationships remain separate. Both ordinary link reads and writes are denied in M12.6. Target resolution and authorized linking remain M12.8 work; a link cannot expose either File or target metadata now.

The deferred `evidence.file_id` FK now references canonical Files with RESTRICT, plus current readable/active compatible Workspace and optional Project validation for a new binding. Workspace-only Files may support Evidence in that same Workspace. Existing historical bindings remain preserved if a File later archives. `createEvidence()` still rejects non-null File input with DEPENDENCY_REQUIRED until secure upload/registration and explicit linking are implemented; null-File behavior is unchanged.

Local Supabase config enables Storage. The RLS migration adds bucket-scoped restrictive denials for anonymous/authenticated object and bucket operations, leaving unrelated buckets untouched. No upload/download policy is granted. Bucket creation uses the provider API, following the [Supabase Storage schema guidance](https://supabase.com/docs/guides/storage/schema/design); no production migration invents provider tables or inserts object metadata.

`node scripts/file-storage-foundation.mjs --setup-only` creates/checks the private bucket against a LOCAL service only. Configure `FICI_STORAGE_TEST_URL` and server-only `FICI_STORAGE_TEST_SERVICE_ROLE_KEY` privately. Without `--setup-only`, also provide `FICI_STORAGE_TEST_ANON_KEY`: the script uploads a disposable fixture via the trusted provider client, proves it exists, tests anonymous public-URL/listing denial, and removes it. It never prints credentials or allows a hosted endpoint. This is a provider infrastructure test, not the M12.7 upload API or a signed-access workflow.

`node scripts/test-db.mjs --files-schema` runs File metadata, constraints, privacy/direct-ID/CRUD/joins/removal/history, Evidence FK, and M12.1–M12.5 regressions on disposable PostgreSQL. `tests/integration/fixtures/storage.sql` is explicitly a test-only provider metadata subset, not a Storage HTTP server. Its policy tests do NOT establish real public-URL denial. The actual provider gate remains BLOCKED when no local Storage service/credentials are available; schema/RLS results must never be reported as a provider PASS.

### M12.7 secure upload

`requestUpload({ workspaceId, projectId?, filename, mimeType, size })` creates a private identity-bound two-hour upload intent, then signs its exact generated `workspaces/<workspace>/files/<file>` path with `upsert: false`. The server-only provider signer uses `SUPABASE_SECRET_KEY` and the same configured Supabase project as the user-scoped database client. It never stores signed capabilities. MIME is restricted to the nine approved PDF/JPEG/PNG/WebP/TXT/CSV/DOCX/XLSX/PPTX values; size is 1 through 26,214,400 bytes.

`registerUploadedFile({ uploadRequestId })` rechecks current write authority and reads exact-path provider-owned `storage.objects.metadata` (read-only) before atomically creating one File and consuming the intent. Retries return the same File after current authorization; concurrent calls serialize. Provider MIME metadata is not content sniffing or malware scanning. No ordinary Storage/table grants were broadened; no hosted migrations are pushed.

Run `node scripts/test-db.mjs --file-upload` for focused SQL/RLS/rollback tests. `node scripts/test-db.mjs --file-provider` additionally runs the actual public services against real signed uploads in the explicitly pinned non-production test project. This test bridges real provider metadata into disposable local PostgreSQL fixtures because hosted migration pushes are prohibited; it does not claim hosted application-RPC deployment. Private FICI_STORAGE_TEST_* configuration is required; no capability or credential is logged. Test teardown deletes only generated objects.

Failed signing may leave an unconsumed private intent. Failed registration creates no File; uploaded orphans are retained pending an approved cleanup policy. Automated orphan cleanup, linkFile, signed download, and createEvidence non-null File input remain deferred to their owning tasks.

### M12.8 File links

`linkFile({ fileId, entityType, entityId, relationshipType })` accepts only the four canonical fields and returns the immutable File Link row. Entity vocabulary reuses `EVIDENCE`, `ARTIFACT`, `ACTIVITY_INSTANCE`, `CHAT_MESSAGE`, `DEVELOPMENT_OBJECT`. Matrix: Evidence permits EVIDENCE_SOURCE/ATTACHMENT/REFERENCE; Artifact permits ARTIFACT_FILE/ATTACHMENT/REFERENCE; Activity and Development Object permit ATTACHMENT/REFERENCE; Chat Message permits CHAT_ATTACHMENT only.

New links require active readable Files and independent current canonical target write authority, the same Workspace, and matching Projects when both endpoints are Project-bound. Activities must remain active and mutable; completed/archived executions receive no new links. Chat targets are messages: only the current authorized author can append an attachment, and deleted messages or archived channels are rejected. No message body, sender, timestamp, type, Artifact Version, Evidence verification, Object body or ownership changes occur.

File Links SELECT composes both endpoint RLS and exact scope compatibility, including historical Activity references where current access still permits reading. Links never grant File access. Files archived later and removed members retain their historical link rows without gaining authorization. Direct client link writes remain denied. Identical active links serialize on the File and return the canonical row; rollback/concurrent duplicate tests preserve exactly one effective link. No unlink, replacement, sharing, signed download or File archive API is introduced.

Run `node scripts/test-db.mjs --file-links` for the full matrix, privacy/lifecycle, public-service and database-barrier duplicate/rollback tests plus M12.1–M12.7 database regressions. Full `pnpm test:integration` includes these tests in a fresh disposable cluster.

### M12.9 temporary File access

`getFileAccess({ fileId })` is server-only and accepts no other fields. It returns `{ signedUrl, expiresAt, expiresIn }` after an authenticated File SELECT under existing RLS, private-bucket validation, exact canonical-path signing, and a final current-authorization check. Existing active-File, Personal, Team and Project privacy remains authoritative; File Links never grant access.

The server-only `FICI_FILE_ACCESS_TTL_SECONDS` setting defaults to 60 seconds and accepts integer seconds from 1 through 300. Invalid configuration fails closed. This download/view lifetime is separate from upload expiry. The result is a temporary bearer capability: callers must not log, persist, cache or treat it as canonical metadata. Only `storage_reference` remains canonical. Membership removal blocks new signing requests; an already-issued provider URL can remain valid until its own expiry. No token revocation or File archive operation is added.

`node scripts/test-db.mjs --file-links --file-provider` runs real non-production Storage download/expiry/revocation tests through the public services and disposable PostgreSQL authorization transport, alongside File/link/upload regressions. It requires the existing private test-provider configuration, creates only disposable objects, cleans them afterward, and pushes no hosted migrations. The expiry test uses a server-configured two-second lifetime and verifies successful access before expiry and denial afterward.

### M12.10 logical File archive

`archiveFile(fileId)` accepts a UUID and returns the canonical archived File. Its narrow database transaction requires current File access plus the existing Workspace/Project mutation authority, locks the File, and changes only archive state and server update attribution. Repeated authorized calls return the same row without new timestamps. Concurrent calls serialize; retries always recheck current authority.

M12.10 supersedes the earlier active-only File read restriction: archived Files remain readable/downloadable through `getFileAccess` only while canonical current scope authorization permits it. New File links still require an active File. Archive preserves all original metadata, internal storage reference, Evidence references, all historical links, and the physical private provider object. There is no provider deletion, replacement, restore, retention duration or cleanup job. Physical retention is indefinite pending an approved future policy.

The `--file-links` database group and full integration run include archive authorization, rollback, idempotency, direct-delete denial and history-preservation tests. `--file-provider` additionally verifies Personal/Team public-service archives, concurrent retry, retained provider objects and signed access after archive.

### M12.11 Patent Record schema

`patent_records` stores retained source metadata within one compatible Project/Workspace. The controlled sources are PATENTSCOPE, USPTO and GOOGLE_PATENTS. Human research relevance is NOT_REVIEWED (default), RELEVANT, POSSIBLY_RELEVANT or NOT_RELEVANT; none expresses novelty, patentability, infringement, validity, freedom-to-operate or legal opinion.

Publication numbers retain their exact source value and formatting and are not unique, including within one scope. No merge or duplicate-resolution operation exists. Optional applicant, inventor and IPC/CPC details remain nullable source text; patent dates use nullable PostgreSQL `date` columns. A source URL is required HTTPS metadata, syntax-validated without fetching, normalization or a domain allowlist.

Reads inherit current canonical Project/Workspace privacy, including Team membership and Project participation. Direct client writes remain denied. A private invoker guard binds creator/timestamp and preserves identity/history; it grants no creation authority. No public create operation, search log, Evidence link, Patent UI, comparison, AI inference or sharing is introduced.

Run `node scripts/test-db.mjs --patent-schema` for clean migrations, patent schema/RLS/type-parity fixtures and affected M12 File/Evidence regressions. Full integration includes the same patent assertions from a fresh disposable PostgreSQL cluster.

### M12.12 create Patent Record

`createPatentRecord(input)` adds the narrow creation path to the accepted M12.11 schema. Input is the approved strict camel-case source contract, including optional human `relevanceStatus`; omission saves NOT_REVIEWED. Nullable optional text/date fields remain null when omitted. Publication numbers, titles, source URLs, notes and other supplied source metadata are preserved without normalization, fetching or analysis.

The authenticated-only `create_patent_record(jsonb)` RPC uses an empty search path and qualified relations. It rejects unknown/type-invalid inputs, validates real ISO dates and existing HTTPS/source/relevance rules, then reuses canonical current Project/Workspace mutation authority and locks before one insert. Creator/timestamps are server-derived. Direct table writes remain denied, and the existing read RLS is unchanged.

Repeated submissions may create separate authorized records; no publication-number deduplication, merge, Evidence creation/link, source fetching, search log, AI comparison or legal inference occurs. Run `node scripts/test-db.mjs --patent-create` for AT-PAT-001 through the actual server service and disposable PostgreSQL transport, direct RPC attacks, rollback, schema/RLS and affected M12 regressions. Full cumulative integration includes the same creation tests.

### M12.13 Patent Search Log

`createPatentSearchLog(input)` appends human research history in the exact current Activity/Project/Workspace scope. It uses canonical active Activity contribution authority, server-derived actor/time, the existing three patent sources, nonnegative counts, and string arrays for learned terms/classifications. Repeated/refined searches create distinct immutable rows. Current Activity and Project authorization governs reads; direct client writes/deletes are denied. No provider search, Evidence links, AI or legal inference is added. Run `node scripts/test-db.mjs --patent-search` for focused schema/RLS/AT-PAT-003 and public-service PostgreSQL coverage; the default integration suite includes it.

### M12.14 Patent → Evidence

`linkPatentToEvidence({ patentRecordId, evidenceType, title, description, claimLocator? })` atomically creates new UNVERIFIED Evidence and one RELATED_TO/PATENT_RECORD source link. Canonical Patent metadata supplies scope, source URL, and source name (`database: publication number`). PATENT forbids claimLocator; PATENT_CLAIM requires an exact nonblank locator in the dedicated claim_locator column. Relevance never verifies Evidence. Generic createEvidence keeps its existing contract and cannot create PATENT_CLAIM without a locator; use this explicit operation. Existing generic linkEvidence permissions remain unchanged. Migration fails rather than fabricates locators for incompatible historical claim records. Run `node scripts/test-db.mjs --patent-evidence`; full integration includes the same schema/RLS, service, atomicity, and privacy tests. No provider fetching, legal analysis, sharing, or M12.15 UI is added.

### M12.15 Basic Patent Workspace

The authenticated route `/projects/[projectId]/patents` combines canonical Project references, authorized Artifact Version references, external patent-source navigation, append-only Search Logs, retained Patent metadata/human notes, and linked PATENT/PATENT_CLAIM Evidence. The loader gates current Project and Workspace access before research queries and uses the request-scoped RLS client throughout. Forms orchestrate only the existing createPatentSearchLog, createPatentRecord, and linkPatentToEvidence operations; no new schema, grants, search provider, analysis model, or sharing behavior is added. A Search Log requires an accessible active Activity; absent references and empty research lists are supported.

Focused clean database acceptance: `node scripts/test-db.mjs --patent-workspace` (includes affected M12.11–M12.14 regressions and the actual Workspace loader against authenticated PostgreSQL roles). UI/action unit tests cover canonical rendering, empty states, service delegation, and input/scope rejection. Configured Playwright includes anonymous exact-ID/role-spoof denial; live authenticated browser fixtures are separate from this loader's PostgreSQL acceptance.

### M12.16 Patent source versus analysis boundary

AT-PAT-002 uses a temporary, explicitly labeled AI_ANALYSIS fixture and the accepted Artifact Draft operation for separate human notes. Exact persisted Patent, Evidence, claim locator, verification/history, Decision and link rows must remain unchanged. Transaction-local RPC tripwires reject automatic source creation, Evidence conversion or verification. Tests also deny direct source overwrite, cross-Team/Personal reads, role-only access and removed-member analysis access. The existing Patent Workspace labels remain unchanged; simulated AI output has no production renderer or persistence. No AI domain or schema is introduced.

Focused clean database gate: `node scripts/test-db.mjs --patent-boundary`. The gate includes accepted Patent Workspace and affected M12 regressions.

### M12.17 Patent Comparison boundary

`comparePatentWithProject(input)`: **DEFERRED — SHOULD-HAVE** for M12 MVP. The approved API/schema documents retain the future extension point; no executable placeholder, comparison table, UI, scoring, provider path, or AI persistence is added. Future comparison is analysis, not source metadata, automatic Evidence/verification/relevance/Decision mutation, or a legal conclusion. M14 owns real AI behavior. Current Project/Workspace/Team authorization remains authoritative for any later implementation.

Regression coverage checks the production AST/routes/transports, rejects unsupported comparison actions, verifies the existing Workspace does not claim automated comparison, and checks the live fully migrated PostgreSQL catalog. Focused catalog gate: `node scripts/test-db.mjs --patent-comparison-boundary`. Accepted M12.16 source-preservation/privacy and M12.15 Workspace regressions remain applicable.

### M12.18 Decision / Evidence integration

Decision finalization now atomically creates canonical Evidence-to-Decision SUPPORTS links. Evidence confidence/source data remains unchanged; every verification state remains independently queryable through the existing RLS-protected Evidence join. No second link model, automatic selection/verification, or voting inference is introduced. Existing linkEvidence supports later attachments without editing finalized outcomes. Migration 20261011130000_decision_evidence.sql retains authenticated-only RPCs, empty search paths and existing RLS; the shared link operation changes Decision/Evidence lock order only. Focused acceptance/concurrency/public-service gate: `node scripts/test-db.mjs --decision-evidence`.

M12.19 canonical Activity research references: see features/activities/RESEARCH.md. Focused clean database validation: node scripts/test-db.mjs --activity-research.

M12.20 Evidence RLS regression: node scripts/test-db.mjs --evidence-rls. Verifies existing canonical Project/Workspace privacy, independent link endpoints, verifier policy, direct-client/RPC attacks, archive protection, and preserved history; no new authorization model.

M12.21 File RLS/Storage regression: node scripts/test-db.mjs --file-rls. Covers exact IDs and paths, independent link endpoints, Project participation loss, direct DML with temporary grants, restrictive Storage policies, and immutable internal references. Real signed access/expiry/revocation regression: node scripts/test-db.mjs --file-provider (approved non-production configuration required).

M12.22 Patent RLS regression: node scripts/test-db.mjs --patent-rls. Verifies canonical Project/Workspace privacy, immutable Search history, exact/public-source filters, independent Evidence/Activity reference reads, raw RPC/DML attacks, removal, and preserved attribution; no comparison or sharing model added.

M12.26 Session 8 uses the canonical PATENT_READING_FRAMEWORK Artifact and M8 Draft Versions. The Patent Workspace records six learner-note sections separately from canonical Patent source IDs. Saving atomically registers the source reference and Activity output; edits require exact Version identity and Draft CAS. Session 9 resolves the same Artifact through artifact_available without cloning or implying approval. Focused clean database gate: `node scripts/test-db.mjs --session8`. Isolated curriculum fixtures cover real start/complete/resume, source preservation, Version lineage, rollback, Personal/Team isolation and current-access revocation. No Session 9 workflow, AI, automatic Evidence or legal conclusions are introduced.

M12.27: `node scripts/test-db.mjs --session9` validates Session 8/9 canonical inputs, refined immutable Search Logs, source-backed Evidence links, generic PATENT_LANDSCAPE Draft content, same-ID Session 10 handoff, and revoked/role-only/Team B isolation. No AI, legal analysis, specialized comparison schemas, or production behavior added.

M12.28: `node scripts/test-db.mjs --m12-leakage` attacks combined Evidence/File/Patent/Search/Activity-reference boundaries with accessible foreign targets, known identifiers/paths/public sources, removed-member and role-only actors, and complete historical-row preservation. Existing File provider, Evidence/Patent RLS, Activity research, and Decision suites supply complementary service/provider regressions. No production security behavior changed.

M13.1: shares is an inert, default-denied schema foundation. Six canonical entity types, five destination types, current exact Team/Cohort MASTER assignment IDs, preserved revocation history and exact active-row uniqueness are enforced in PostgreSQL. No recipient resolver, client writer, snapshot payload or access grant is enabled. Focused clean-database validation: node scripts/test-db.mjs --shares-schema.

M13.2: MVP Share runtime mode is SNAPSHOT-only; LIVE_REFERENCE remains vocabulary-only and new rows are rejected as policy-deferred. share_snapshots freezes a server-derived canonical source projection and internal provenance. Artifacts bind exact Artifact Versions; other current source types have no canonical Version-row store (Object counters are retained only as data). No related-row hydration, storage capabilities, recipient resolver, copying, live updates or source ACL grants. Focused clean-database gate: node scripts/test-db.mjs --share-snapshots.
# M13.3 Shareability foundation

`resolveShareability(input)` is a read-only, caller-bound eligibility check backed by `resolve_shareability(jsonb)`. It grants no access and creates no Share. Personal owners may target their currently authorized Team; exact current active Team Leads may target enabled Team/scoped-Master destinations. Both use VIEW/COMMENT SNAPSHOT eligibility. USER, WORKSPACE, COHORT, COLLABORATE, and LIVE_REFERENCE remain deferred. Current source scope is checked independently; Share/Snapshot provenance never supplies authority. Future creation must revalidate within its transaction.

Run `node scripts/test-db.mjs --shareability` for clean-migration resolver, Share, and Snapshot regressions. The default cumulative runner includes these checks.

M13.4: `shareEntity(input)` calls one authenticated transaction for Share, immutable Snapshot, and identifier-only SHARE_CREATED audit event (durable M15 hook; no new notification delivery policy). Artifact callers explicitly select sourceVersionId; non-versioned sources accept only null/omitted Version. Exact retries return the canonical active Share; a different Version under the same seven-column active identity returns ACTIVE_SHARE_DIFFERENT_VERSION. Existing revoked Share/Snapshot history is retained. No recipient resolver, source ACL grant, revoke API or M13.5 behavior. Clean focused validation: `node scripts/test-db.mjs --share-entity`, including duplicate/concurrent commit/rollback and version-conflict checks.

M13.5: `resolveSharedEntityAccess({shareId})` is the sole Share-derived recipient capability resolver. Current destination Team membership or the exact active scoped MASTER assignment permits only the frozen projection: VIEW or COMMENT, never edit/re-share. Revocation and membership/assignment loss are checked afresh. Source RLS remains unchanged; no source Workspace, sibling/history, File signing or internal provenance access is added. USER/WORKSPACE/COHORT, COLLABORATE and LIVE_REFERENCE remain deferred. Clean focused gate: `node scripts/test-db.mjs --shared-access`, including M13.1-M13.4 regressions. No M13.6 UI/flow or revoke API.

M13.6: Personal owners use the standard `shareEntity()` and `resolveSharedEntityAccess()` path for selected supported entities. The formerly deferred `shareScamperEntryToTeam()` adapter now accepts the standard Share input narrowed to SCAMPER_ENTRY -> TEAM, checks canonical Personal ownership, and delegates to the same transaction. No copy, new ACL, source browsing, linked File grant, edit right or recipient re-share is introduced. `node scripts/test-db.mjs --personal-sharing` runs AT-PW-004 (three of ten private IDEA objects), AT-SCAMPER-003, actual-service/Workspace-route attacks, removal/history checks, and M9/M13 regressions against disposable PostgreSQL.

M13.10: `addSharedComment({shareId, content})` and `listSharedComments({shareId})` use an exact immutable Share thread. COMMENT recipients may discuss the frozen target without source editing or formal review. The append-only `share_comments` context is separate from Submission-bound M8 feedback; targets, Version, author and timestamp are server-derived. Current source readers retain historical comments after revocation; former recipients lose Share-derived thread access. `node scripts/test-db.mjs --share-comments` runs AT-SHARE-004 and M13.1-M13.9 regressions.

M14.19: `node scripts/test-db.mjs --ai-brainstorm` verifies exact Brainstorm-entry AI context and immutable provenance. BRAINSTORM is optional only for BRAINSTORMING_ASSISTANCE. The Context Builder reuses M14.9 availability; M9 read authority remains mandatory. Self-only execution may include permitted own hidden entries, while pool-dependent execution includes only canonically revealed entries in the exact Activity/Project/Workspace. No Brainstorm sharing, reveal mutation, provider calls, or new visibility mode is added.

M14.19 saved-output protection adds a restrictive AI Output read policy. A Team result referencing any unrevealed Brainstorm entry stays requester-only under normal current Project/Workspace authorization. Context References inherit parent RLS. Only canonical reveal of every referenced Brainstorm entry restores ordinary Team reads; no output/provenance rewrite, Share, publication flag, or non-Brainstorm visibility change occurs. The `--ai-brainstorm` gate covers requester/peer/Lead/role-only IDs, mixed reveal, unchanged history, normal Team results and Personal isolation.
The same narrow predicate also gates security-definer disposition, conversion and Artifact-revision RPCs, so direct RPC calls cannot reopen a hidden-derived result or return it through an idempotent retry. Other RPC behavior and grants remain unchanged.
