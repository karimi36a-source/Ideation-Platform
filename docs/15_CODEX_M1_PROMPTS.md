# FICI Invention Education & Development Platform
## Codex M1 Execution Prompts — Authentication & User Foundation

**Document:** `15_CODEX_M1_PROMPTS.md`  
**Status:** Draft v0.1 — For Review  
**Depends on:** `01_PRODUCT_REQUIREMENTS.md` through `14_CODEX_M0_PROMPTS.md`  
**Purpose:** Provide exact copy/paste prompts for Codex to implement Milestone M1 safely and incrementally after M0 is complete.

---

# 1. Preconditions

Do not begin M1 until M0 is complete and reviewed.

Required M0 state:

- Next.js application builds successfully.
- TypeScript strict mode is enabled.
- pnpm is configured.
- Supabase local development foundation exists.
- environment validation exists.
- Vitest and Playwright work.
- CI exists.
- `/docs` is present and treated as source of truth.
- no business feature was implemented prematurely.

If M0 is incomplete, stop and finish M0 first.

---

# 2. M1 Goal

Milestone M1 establishes the authenticated user foundation.

M1 must deliver:

```text
SUPABASE AUTH
↓
PLATFORM USER PROFILE
↓
LOGIN / LOGOUT
↓
PASSWORD RESET
↓
EMAIL VERIFICATION SUPPORT
↓
PROTECTED ROUTES
↓
SERVER-SIDE CURRENT USER
↓
AUTH ACCEPTANCE TESTS
```

M1 does **not** yet implement:

- scoped roles,
- team permissions,
- cohorts,
- workspaces,
- Development Projects,
- AI,
- chat.

Those belong to later milestones.

---

# 3. Global Codex Header

Use this at the start of every M1 task if project rules are not automatically retained:

```text
You are implementing the FICI Invention Education & Development Platform.

Before making changes:

1. Read the relevant /docs files listed in this task.
2. Treat /docs as source of truth.
3. Do not invent missing business rules.
4. Do not implement features outside this task.
5. Preserve security and privacy from the beginning.
6. Never trust client-provided user identity.
7. Use strict TypeScript.
8. Validate runtime input.
9. Use migrations for schema changes.
10. Run the required tests before finishing.
11. Report files changed, commands run, tests, assumptions, and unresolved issues.
```

---

# 4. M1.1 — Supabase Auth Plumbing

## Objective

Add the reusable Supabase authentication infrastructure needed by later M1 tasks.

## Copy/Paste Prompt

```text
TASK ID: M1.1
TASK: Supabase Auth Plumbing

Read first:

- /docs/08_DATA_MODEL_SCHEMA.md
- /docs/10_TECHNICAL_ARCHITECTURE.md
- /docs/11_API_CONTRACTS.md
- /docs/12_ACCEPTANCE_TESTS.md
- /docs/13_CODEX_IMPLEMENTATION_PLAN.md

Assume M0 is complete.

OBJECTIVE

Implement the core Supabase authentication plumbing only.

IN SCOPE

1. Create/verify browser Supabase client helper.
2. Create/verify server Supabase client helper suitable for Next.js App Router.
3. Add server-side session retrieval.
4. Add a reusable helper for retrieving the authenticated Supabase user.
5. Add auth callback handling if required by the selected Supabase auth flow.
6. Add middleware or server-side route protection foundation only where technically appropriate.
7. Ensure cookies/session handling follows current Supabase SSR guidance.
8. Keep all secret credentials server-side.
9. Add minimal tests for helper behavior where practical.

OUT OF SCOPE

Do NOT implement yet:

- login page,
- password reset UI,
- user profile table,
- roles,
- cohorts,
- dashboard,
- workspaces,
- teams.

SECURITY REQUIREMENTS

- Never trust a user ID passed from the browser.
- Never expose SUPABASE_SECRET_KEY to client code.
- Authenticated identity must come from verified Supabase session/user data.
- Do not store passwords in platform tables.

VALIDATION

Run:

pnpm lint
pnpm typecheck
pnpm test:unit
pnpm build

DEFINITION OF DONE

- browser/server auth clients exist,
- session retrieval works,
- authenticated user helper exists,
- no product UI was added,
- no secret key reaches client bundle,
- validation commands pass.

FINAL REPORT

Return:
1. Summary
2. Files changed
3. Auth/session approach
4. Commands/results
5. Any Supabase SSR assumptions
```

---

# 5. M1.1 Review Checklist

```text
[ ] server and browser clients are separated
[ ] no secret key in client code
[ ] identity comes from authenticated session
[ ] no login/dashboard scope creep
[ ] lint/typecheck/tests/build pass
```

---

# 6. M1.2 — Platform User Profile Schema

## Objective

Create the platform-side user profile linked to Supabase Auth.

## Copy/Paste Prompt

```text
TASK ID: M1.2
TASK: User Profile Schema

Read first:

- /docs/08_DATA_MODEL_SCHEMA.md — User Entity
- /docs/10_TECHNICAL_ARCHITECTURE.md
- /docs/11_API_CONTRACTS.md — Authentication Contracts
- /docs/12_ACCEPTANCE_TESTS.md

OBJECTIVE

Implement the FICI platform user profile model linked 1:1 with the authenticated Supabase user.

IN SCOPE

1. Add migration for `users` or the approved profile table.

Required conceptual fields:

- id
- email
- display_name
- first_name
- last_name
- profile_image
- account_status
- timezone
- locale
- created_at
- updated_at

2. Use the Supabase auth user ID as the stable platform user identity unless there is a strong technical reason not to.
If deviating, report it before implementation.

3. Add account status enum/constraint supporting:

- invited
- active
- suspended
- archived

4. Create safe server-side profile creation/provisioning behavior.

5. Implement:

- getCurrentUser()
- updateOwnProfile()

6. Add RLS for the profile table sufficient for M1:

- user can read own profile,
- user can update allowed own profile fields,
- user cannot update another user's profile,
- sensitive/admin-only fields must not be user-writable.

7. Add database/integration tests.

OUT OF SCOPE

- role assignments,
- organization membership,
- team membership,
- cohort enrollment.

IMPORTANT

Email identity comes from authenticated auth identity.
Do not allow arbitrary profile update to change trusted auth identity fields unless handled through an approved auth flow.

VALIDATION

Run:

pnpm lint
pnpm typecheck
pnpm test:unit
relevant integration/database tests
pnpm build

DEFINITION OF DONE

- profile migration exists,
- profile can be provisioned,
- current user returns auth + platform profile data as appropriate,
- user may update own allowed profile fields only,
- another user's profile cannot be modified.

FINAL REPORT

Include:
1. Migration
2. RLS policies
3. Provisioning strategy
4. API/service functions
5. Tests/results
```

---

# 7. M1.2 Review Checklist

```text
[ ] migration committed
[ ] profile uses authenticated identity
[ ] own-profile RLS tested
[ ] cannot edit another profile
[ ] account_status not arbitrarily writable by student
[ ] no roles implemented prematurely
```

---

# 8. M1.3 — Login & Logout

## Objective

Implement usable authentication entry and exit.

## Copy/Paste Prompt

```text
TASK ID: M1.3
TASK: Login and Logout

Read first:

- /docs/10_TECHNICAL_ARCHITECTURE.md
- /docs/11_API_CONTRACTS.md
- /docs/12_ACCEPTANCE_TESTS.md — AT-AUTH-001 through AT-AUTH-004

OBJECTIVE

Implement email/password login and logout using the M1.1 auth foundation.

IN SCOPE

1. Create login route/page.
2. Create accessible login form.
3. Validate fields server-side/runtime.
4. Authenticate through Supabase Auth.
5. Redirect authenticated user to a minimal authenticated landing page.
6. Add logout action.
7. Handle invalid credentials safely.
8. Do not reveal whether a particular email/account exists beyond normal provider-safe behavior.
9. Preserve return/redirect target only if safely validated.

UI

Keep UI minimal.
Do not build final dashboard/navigation.

OUT OF SCOPE

- social login,
- roles,
- onboarding wizard,
- course dashboard,
- workspace UI.

ACCEPTANCE TESTS

Implement E2E coverage for:

- AT-AUTH-001 Valid Login
- AT-AUTH-002 Invalid Login
- logout/session end behavior

Also verify authenticated users do not unnecessarily remain on login screen.

VALIDATION

pnpm lint
pnpm typecheck
pnpm test:unit
pnpm build
pnpm test:e2e

DEFINITION OF DONE

- valid login works,
- invalid login fails safely,
- logout works,
- session cookie behavior is correct,
- E2E tests pass.

FINAL REPORT

Return changed files, auth flow, tests, and any environment/test-account requirements.
```

---

# 9. M1.3 Review Checklist

```text
[ ] login actually uses Supabase Auth
[ ] no fake/local password logic
[ ] logout invalidates session correctly
[ ] errors are safe
[ ] no dashboard scope creep
[ ] E2E passes
```

---

# 10. M1.4 — Email Verification & Password Reset

## Objective

Complete basic account recovery lifecycle.

## Copy/Paste Prompt

```text
TASK ID: M1.4
TASK: Email Verification and Password Reset

Read first:

- /docs/10_TECHNICAL_ARCHITECTURE.md
- /docs/11_API_CONTRACTS.md
- current Supabase auth implementation from M1.1–M1.3

OBJECTIVE

Implement the minimum production-appropriate email verification and password reset flows supported by Supabase Auth.

IN SCOPE

1. Add forgot-password flow.
2. Add reset-password page/action.
3. Validate reset tokens/session safely.
4. Add email verification/callback handling where required.
5. Add clear states for:
   - reset email requested,
   - invalid/expired reset state,
   - password updated,
   - verification pending if applicable.
6. Add tests for local application behavior around these flows.

IMPORTANT

Do not create custom password-reset tokens in the application database.
Use the authentication provider's secure flow.

OUT OF SCOPE

- Resend transactional product notifications,
- social login,
- MFA,
- enterprise SSO.

SECURITY

- do not reveal account existence unnecessarily,
- do not log reset tokens,
- do not put secrets in URLs beyond provider-required secure tokens,
- never store raw passwords.

VALIDATION

pnpm lint
pnpm typecheck
pnpm test:unit
pnpm build
relevant E2E tests where feasible

DEFINITION OF DONE

Password recovery can be initiated and completed using the approved Supabase flow.

FINAL REPORT

Include:
- routes/actions added,
- Supabase configuration assumptions,
- test coverage,
- manual configuration still required, if any.
```

---

# 11. M1.4 Review Checklist

```text
[ ] provider flow used
[ ] no custom raw token storage
[ ] no account enumeration
[ ] no password logging
[ ] reset route handles invalid state
```

---

# 12. M1.5 — Protected Routes & Current User

## Objective

Ensure protected application areas cannot be accessed without valid authentication.

## Copy/Paste Prompt

```text
TASK ID: M1.5
TASK: Protected Routes and Current User

Read first:

- /docs/11_API_CONTRACTS.md — Common Request Context + Authentication Contracts
- /docs/12_ACCEPTANCE_TESTS.md — AT-AUTH-003 and AT-AUTH-004
- existing M1 implementation

OBJECTIVE

Complete authentication enforcement for protected application routes and server business operations.

IN SCOPE

1. Define the initial authenticated route group.
2. Ensure unauthenticated requests are redirected/denied appropriately.
3. Add reusable server helpers:

- requireAuthenticatedUser()
- getOptionalAuthenticatedUser()

Naming may vary if project conventions differ.

4. Ensure future server commands can obtain trusted user ID from server auth state.
5. Create a minimal authenticated landing page showing only:
   - user's display name/email,
   - logout action,
   - "FICI Platform" placeholder.

Do not build course/workspace dashboard.

6. Ensure an authenticated Student A cannot spoof Student B identity in service calls.

ACCEPTANCE TESTS

Implement/complete:

- AT-AUTH-003 Unauthenticated Protected Route
- AT-AUTH-004 Client User ID Spoofing

VALIDATION

pnpm lint
pnpm typecheck
pnpm test:unit
pnpm build
pnpm test:e2e

DEFINITION OF DONE

- protected routes cannot be viewed anonymously,
- server operations derive identity from session,
- user-ID spoofing test passes.

FINAL REPORT

Return route strategy, helpers, changed files, test results.
```

---

# 13. M1.5 Review Checklist

```text
[ ] anonymous protected access denied
[ ] trusted identity resolved server-side
[ ] spoofing test passes
[ ] minimal authenticated landing page only
[ ] no roles/workspace implementation
```

---

# 14. M1.6 — Authentication Acceptance & Hardening

## Objective

Run M1 as a complete security-focused acceptance milestone.

## Copy/Paste Prompt

```text
TASK ID: M1.6
TASK: Authentication Acceptance and Hardening

Read first:

- /docs/12_ACCEPTANCE_TESTS.md — Authentication Acceptance Tests
- /docs/13_CODEX_IMPLEMENTATION_PLAN.md — M1
- all M1 implementation code

OBJECTIVE

Audit and harden the complete M1 Authentication & User Foundation.

Do not add unrelated product features.

REQUIRED ACCEPTANCE TESTS

Run and ensure coverage for:

AT-AUTH-001 — Valid Login
AT-AUTH-002 — Invalid Login
AT-AUTH-003 — Unauthenticated Protected Route
AT-AUTH-004 — Client User ID Spoofing

Also verify:

1. logout invalidates effective authenticated access,
2. own profile update cannot modify another profile,
3. server-only Supabase secret is not exposed to client bundle/source,
4. password reset flow does not expose account details,
5. profile provisioning is idempotent or otherwise safe,
6. suspended/archived account behavior is documented if not enforced yet.

SECURITY REVIEW

Search the codebase for:

- SUPABASE_SECRET_KEY usage,
- direct client-provided userId trust,
- auth state read only from browser state,
- accidental secret logging,
- passwords written to logs/database.

Fix any defects within M1 scope.

FULL VALIDATION

Run:

pnpm lint
pnpm typecheck
pnpm test:unit
relevant integration/database tests
pnpm build
pnpm test:e2e

FINAL REPORT

Provide:

1. M1 summary
2. Acceptance test matrix with PASS/FAIL
3. Security findings
4. Files changed during hardening
5. Commands/results
6. Remaining HIGH/MEDIUM/LOW issues
7. Recommendation:
   READY FOR M2
   or
   NOT READY FOR M2

Do not mark READY if any authentication BLOCKER is unresolved.
```

---

# 15. M1 Completion Gate

M1 is complete only when:

```text
[ ] valid login works
[ ] invalid login fails safely
[ ] logout works
[ ] password reset works
[ ] verification/callback handling is correct
[ ] platform profile exists
[ ] current user helper exists
[ ] own-profile update works
[ ] another user's profile cannot be modified
[ ] protected routes reject anonymous access
[ ] client cannot spoof user identity
[ ] no server secrets exposed
[ ] AT-AUTH-001 PASS
[ ] AT-AUTH-002 PASS
[ ] AT-AUTH-003 PASS
[ ] AT-AUTH-004 PASS
[ ] lint passes
[ ] typecheck passes
[ ] tests pass
[ ] build passes
[ ] Codex reports READY FOR M2
```

---

# 16. Recommended Commit Sequence

Example:

```text
feat(auth): add supabase auth server and browser clients
feat(users): add platform user profiles
feat(auth): add login and logout
feat(auth): add password reset flow
feat(auth): protect authenticated routes
test(auth): add authentication acceptance coverage
```

Keep migrations and their tests in the same logical commit or PR where practical.

---

# 17. M1 Technical Non-Goals

Do not accept these as "helpful additions" during M1:

- Admin dashboard
- Student dashboard
- Google OAuth
- Microsoft OAuth
- team creation
- role-management UI
- organization administration
- course enrollment
- workspace selector
- AI assistant
- chat
- file uploads
- final design system

M1 is authentication infrastructure, not product breadth.

---

# 18. Potential M1 Ambiguities Codex Must Flag

Codex should flag instead of inventing behavior if it encounters questions such as:

- Should unverified users be allowed into the authenticated app?
- Should suspended account enforcement happen in Auth middleware or profile/service layer?
- Is account self-registration allowed, or are accounts invitation-only?
- Should email changes be supported now?
- Should deleting an auth user archive or delete platform profile?

If these rules are not already resolved in approved docs, report them.

Do not silently decide.

---

# 19. Recommended Default Until Product Decision

Where a temporary technical choice is required but does not change business behavior:

- keep self-registration UI **out** of M1 unless explicitly approved,
- support Admin/invite-driven provisioning later,
- keep authenticated landing minimal,
- preserve profile records rather than destructive deletion,
- treat email verification behavior according to Supabase environment configuration.

Any user-facing policy decision should still be flagged.

---

# 20. M1 Expected Repository Additions

After M1, the repository may include:

```text
features/auth/
features/users/

lib/auth/
lib/db/

app/(auth)/login/
app/(auth)/forgot-password/
app/(auth)/reset-password/
app/(platform)/

supabase/migrations/
tests/unit/auth/
tests/integration/auth/
tests/e2e/auth.spec.ts
```

Exact names may vary.

Architecture boundaries should remain clean.

---

# 21. Next File After M1

After M1 has actually been implemented, tested, reviewed, and committed, create:

# `16_CODEX_M2_PROMPTS.md`

M2 should be broken into tasks such as:

```text
M2.1 Role Schema & Seed
M2.2 Scoped Role Assignments
M2.3 Authorization Service
M2.4 RLS Helper Functions
M2.5 Base RLS Policies
M2.6 RBAC / Scope Acceptance Tests
M2.7 M2 Security Hardening
```

M2 is the security foundation for everything that follows.

---

# 22. Final Execution Rule

For M1:

```text
AUTH FOUNDATION
→ PROFILE
→ LOGIN/LOGOUT
→ RECOVERY
→ PROTECTED ROUTES
→ SECURITY ACCEPTANCE
```

Do not skip directly to product features.

---

# End of Document

**Current Status:** Draft v0.1 — Ready for Ahmad/FICI review.  
**Execution Step After M0 Completion:** Start with **M1.1 — Supabase Auth Plumbing**.
