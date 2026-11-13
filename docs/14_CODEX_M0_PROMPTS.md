# FICI Invention Education & Development Platform
## Codex M0 Execution Prompts

**Document:** `14_CODEX_M0_PROMPTS.md`  
**Status:** Draft v0.1 — For Review  
**Depends on:** `01_PRODUCT_REQUIREMENTS.md` through `13_CODEX_IMPLEMENTATION_PLAN.md`  
**Purpose:** Provide exact copy/paste prompts for Codex to execute Milestone M0 safely and incrementally without jumping ahead into product features.

---

# 1. How to Use This File

Run these prompts in order:

```text
M0.1 Repository Initialization
↓
Review Result
↓
M0.2 Supabase Local Development Setup
↓
Review Result
↓
M0.3 Test & CI Foundation
↓
Review Result
↓
M0.4 Documentation / Rules Validation
↓
Review Result
↓
M0 COMPLETE
```

Do not combine all M0 prompts into one large Codex task.

After each task:

1. review Codex's changes,
2. run the requested checks,
3. confirm there is no scope creep,
4. commit if correct,
5. then move to the next prompt.

---

# 2. Global Codex Header

Use this block at the beginning of every Codex task if your Codex environment does not automatically retain project rules.

```text
You are implementing the FICI Invention Education & Development Platform.

Before making changes:

1. Read the relevant files in /docs.
2. Treat /docs as product and architecture source of truth.
3. Do not invent missing business rules.
4. Do not change product behavior to make implementation easier.
5. If requirements conflict or are ambiguous, stop and report the issue.
6. Do not implement features outside the task scope.
7. Preserve privacy, workspace isolation, version history, evidence separation, and AI governance.
8. Use strict TypeScript.
9. Run the requested validation commands before finishing.
10. Report:
   - files changed,
   - commands run,
   - test results,
   - assumptions,
   - unresolved issues.
```

---

# 3. M0.1 — Repository Initialization

## Objective

Create the initial Next.js/TypeScript application structure and coding foundation only.

No product features.

## Copy/Paste Prompt

```text
TASK ID: M0.1
TASK: Repository Initialization

Read first:

- /docs/10_TECHNICAL_ARCHITECTURE.md
- /docs/12_ACCEPTANCE_TESTS.md
- /docs/13_CODEX_IMPLEMENTATION_PLAN.md

OBJECTIVE

Initialize the FICI platform repository as a production-oriented Next.js 16.3 Active LTS application using:

- TypeScript
- pnpm
- App Router
- strict TypeScript
- ESLint
- modern React

Do not implement any business feature.

IN SCOPE

1. Initialize or normalize the Next.js application.
2. Use pnpm as the package manager.
3. Enable strict TypeScript.
4. Create the approved high-level folder structure:

/
├── app/
├── components/
│   ├── common/
│   ├── workspace/
│   ├── activities/
│   ├── collaboration/
│   └── review/
├── features/
│   ├── auth/
│   ├── courses/
│   ├── teams/
│   ├── projects/
│   ├── activities/
│   ├── evidence/
│   ├── ai/
│   ├── chat/
│   ├── sharing/
│   └── versions/
├── lib/
│   ├── auth/
│   ├── permissions/
│   ├── db/
│   ├── ai/
│   ├── realtime/
│   ├── validation/
│   └── audit/
├── supabase/
├── tests/
│   ├── unit/
│   ├── integration/
│   └── e2e/
├── docs/
└── scripts/

5. Add a minimal root application page that clearly identifies the project as:
   "FICI Invention Education & Development Platform"

6. Add a project README covering:
   - project purpose,
   - prerequisites,
   - pnpm installation,
   - local development command,
   - lint,
   - typecheck,
   - test placeholders,
   - build command,
   - note that /docs is source of truth.

7. Add package scripts for:
   - dev
   - build
   - start
   - lint
   - typecheck

8. Ensure:
   - no "any" is introduced unnecessarily,
   - no business rules are added,
   - no auth,
   - no database,
   - no AI,
   - no Supabase feature implementation yet.

OUT OF SCOPE

Do NOT implement:

- authentication,
- database schema,
- Supabase client setup beyond what the current Next.js template may already include,
- teams,
- workspaces,
- AI,
- chat,
- course UI,
- permissions,
- Liveblocks,
- Daily,
- Resend,
- product dashboards.

FILES EXPECTED TO CHANGE

Typical examples:

- package.json
- pnpm-lock.yaml
- tsconfig.json
- eslint config
- app/*
- README.md
- empty or placeholder folder files only where necessary

VALIDATION

Before finishing, run:

pnpm install
pnpm lint
pnpm typecheck
pnpm build

If any command fails, fix it before completing the task.

DEFINITION OF DONE

- project installs,
- lint passes,
- typecheck passes,
- build passes,
- folder structure exists,
- README is accurate,
- no product features were implemented.

FINAL REPORT

Return:

1. Summary
2. Files changed
3. Commands run
4. Results
5. Any ambiguity or deviation
```

---

# 4. M0.1 Review Checklist

After Codex finishes, verify:

```text
[ ] Next.js version is pinned
[ ] pnpm-lock.yaml exists
[ ] strict TypeScript enabled
[ ] lint passes
[ ] typecheck passes
[ ] build passes
[ ] no auth/product/database feature was added
[ ] /docs remains intact
[ ] README says docs are source of truth
```

If Codex started building login/dashboard/features, reject those changes.

---

# 5. M0.2 — Supabase Local Development Setup

## Objective

Add Supabase development infrastructure and environment handling without implementing business tables yet.

## Copy/Paste Prompt

```text
TASK ID: M0.2
TASK: Supabase Local Development Setup

Read first:

- /docs/08_DATA_MODEL_SCHEMA.md
- /docs/10_TECHNICAL_ARCHITECTURE.md
- /docs/13_CODEX_IMPLEMENTATION_PLAN.md

Assume M0.1 is complete.

OBJECTIVE

Set up the technical foundation for Supabase local development, environment validation, and typed database access.

Do NOT implement the platform business schema yet.

IN SCOPE

1. Add Supabase dependencies required for:
   - browser-safe client access,
   - server-side access,
   - auth-compatible future usage.

2. Initialize /supabase for local development if not already initialized.

3. Add configuration for:
   - local Supabase workflow,
   - migration directory,
   - seed file placeholder,
   - future database tests.

4. Add Zod-based environment validation for:

NEXT_PUBLIC_SUPABASE_URL
NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY
SUPABASE_SECRET_KEY
OPENAI_API_KEY
LIVEBLOCKS_SECRET_KEY
DAILY_API_KEY
RESEND_API_KEY

Rules:

- Only variables actually needed at runtime may be mandatory immediately.
- Future-provider keys may be optional in M0 so local development is not blocked.
- Server-only secrets must never be exposed through NEXT_PUBLIC_*.
- Do not commit real secret values.

5. Add:
   - `.env.example`
   - clear comments describing which variables are server-only.

6. Create minimal Supabase client helpers under approved architecture locations, such as:

lib/db/
or
lib/auth/

Separate:

- browser client
- server client

7. Do not create product/business tables yet.

8. Add an initial empty or infrastructure-only migration if the Supabase CLI requires it, but do not implement roles/users/teams/projects.

9. Update README with:
   - Supabase CLI prerequisite,
   - local start command,
   - environment setup,
   - migration command placeholders.

OUT OF SCOPE

Do NOT implement:

- users table,
- roles table,
- RLS business policies,
- teams,
- courses,
- workspaces,
- AI,
- storage buckets,
- chat,
- seed users.

VALIDATION

Run the appropriate commands available in the environment:

pnpm lint
pnpm typecheck
pnpm build

If Supabase CLI is available, also validate configuration with the appropriate non-destructive local/config command.

Do not require Docker services to remain running after the task.

SECURITY

- No real secret values in git.
- No secret key imported into client components.
- No service/secret key in NEXT_PUBLIC variables.

DEFINITION OF DONE

- environment validation exists,
- `.env.example` exists,
- Supabase client helpers are correctly separated,
- local Supabase structure exists,
- no business schema was implemented.

FINAL REPORT

Return:

1. Summary
2. Dependencies added
3. Files changed
4. Environment variables
5. Commands run/results
6. Any issues with Supabase CLI availability
```

---

# 6. M0.2 Review Checklist

Verify:

```text
[ ] no secrets committed
[ ] browser client does not use secret key
[ ] server-only environment module exists
[ ] .env.example exists
[ ] no business schema created prematurely
[ ] Supabase migration directory exists
[ ] README updated
[ ] lint/typecheck/build pass
```

---

# 7. M0.3 — Test & CI Foundation

## Objective

Create the testing and CI framework before implementing product features.

## Copy/Paste Prompt

```text
TASK ID: M0.3
TASK: Test & CI Foundation

Read first:

- /docs/10_TECHNICAL_ARCHITECTURE.md
- /docs/12_ACCEPTANCE_TESTS.md
- /docs/13_CODEX_IMPLEMENTATION_PLAN.md

Assume M0.1 and M0.2 are complete.

OBJECTIVE

Set up the automated quality foundation for the project using:

- Vitest
- Playwright
- CI checks

Do not implement product acceptance tests yet because product features do not exist.

IN SCOPE

1. Install/configure Vitest.

2. Add:
   - unit test directory,
   - integration test directory.

3. Add at least one minimal unit smoke test proving the test runner works.

4. Install/configure Playwright.

5. Add one minimal E2E smoke test that:
   - starts the app using the project's supported Playwright webServer configuration,
   - opens the root page,
   - verifies the FICI platform title/text is visible.

6. Add package scripts such as:

test
test:unit
test:e2e
test:watch
typecheck

Use naming appropriate to the actual configuration.

7. Add CI workflow using GitHub Actions.

The CI should run, in a sensible order:

pnpm install --frozen-lockfile
pnpm lint
pnpm typecheck
pnpm test:unit
pnpm build

Run Playwright in CI if the environment/configuration is stable enough now.
If not, prepare the workflow and clearly explain what is deferred.

8. Add caching where straightforward, but do not over-engineer CI.

9. Ensure future Supabase/RLS tests have a clear place in the repository.

OUT OF SCOPE

Do NOT implement:

- product-specific tests,
- auth tests,
- RLS tests,
- team tests,
- AI tests,
- database fixtures,
- complex test factories.

VALIDATION

Run locally:

pnpm lint
pnpm typecheck
pnpm test:unit
pnpm build
pnpm test:e2e

If Playwright browser installation is needed, document the required command.

DEFINITION OF DONE

- Vitest works,
- Playwright works,
- smoke tests pass,
- CI configuration exists,
- CI does not contain fake passing placeholders.

FINAL REPORT

Return:

1. Summary
2. Packages added
3. Test files added
4. CI workflow
5. Commands/results
6. Any CI/E2E limitations
```

---

# 8. M0.3 Review Checklist

Verify:

```text
[ ] unit test actually runs
[ ] E2E test actually runs
[ ] CI uses frozen lockfile
[ ] CI runs lint
[ ] CI runs typecheck
[ ] CI runs tests
[ ] CI runs build
[ ] no fake skipped core check
[ ] no product tests invented yet
```

---

# 9. M0.4 — Documentation & Development Rules Validation

## Objective

Make the repository clearly governable by the approved documentation before product implementation begins.

## Copy/Paste Prompt

```text
TASK ID: M0.4
TASK: Documentation and Development Rules Validation

Read all files in /docs.

OBJECTIVE

Prepare the repository so that future Codex tasks clearly follow the approved FICI documentation.

Do not implement any product feature.

IN SCOPE

1. Verify that the approved documentation files exist in `/docs`.

Expected set:

01_PRODUCT_REQUIREMENTS.md
02_PLATFORM_ARCHITECTURE.md
03_ROLES_PERMISSIONS.md
04_WORKSPACE_TEAM_COLLABORATION.md
05_DEVELOPMENT_PROJECT_MODEL.md
06_COURSE_ACTIVITY_WORKFLOWS.md
07_MVP_SCOPE.md
08_DATA_MODEL_SCHEMA.md
09_AI_ASSISTANT_SPEC.md
10_TECHNICAL_ARCHITECTURE.md
11_API_CONTRACTS.md
12_ACCEPTANCE_TESTS.md
13_CODEX_IMPLEMENTATION_PLAN.md
14_CODEX_M0_PROMPTS.md

2. Do not rewrite those documents.

3. Add a developer guidance file if one does not already exist, such as:

`CONTRIBUTING.md`

It must state:

- `/docs` is source of truth.
- Product requirements cannot be silently changed during implementation.
- Ambiguities must be flagged.
- Protected data requires server/database authorization.
- RLS is mandatory for protected Supabase tables.
- Approved artifact versions must not be destructively overwritten.
- AI must not bypass permissions.
- AI output is not evidence.
- Team and Personal workspace isolation is mandatory.
- migrations are required for schema changes.
- tests and acceptance criteria are part of Definition of Done.

4. Add a concise architectural decision/development checklist to the PR template if a PR template is appropriate.

Suggested PR questions:

- Which docs govern this change?
- Does this change affect permissions/RLS?
- Does this change affect project history/versioning?
- Does this change affect AI context?
- What tests were added?
- Are there unresolved requirements?

5. Add CODEOWNERS only if the repository already has a clear ownership model.
Do not invent people/emails.

6. Verify package scripts and README commands remain accurate.

7. Run the full M0 validation suite.

OUT OF SCOPE

Do NOT implement:

- login,
- roles,
- database business tables,
- UI dashboard,
- team features,
- AI.

VALIDATION

Run:

pnpm lint
pnpm typecheck
pnpm test:unit
pnpm build
pnpm test:e2e

DEFINITION OF DONE

M0 is ready only when:

- project foundation is stable,
- docs are clearly authoritative,
- development rules are documented,
- test/CI foundation works,
- no product scope has leaked into M0.

FINAL REPORT

Return:

1. M0 completion summary
2. Documentation files found
3. Files added/changed
4. Validation results
5. Any documentation contradiction discovered
6. Recommendation: READY FOR M1 or NOT READY FOR M1
```

---

# 10. M0.4 Review Checklist

Verify:

```text
[ ] docs were not rewritten
[ ] CONTRIBUTING.md reflects approved rules
[ ] no invented CODEOWNERS identities
[ ] PR template is useful and not excessive
[ ] all M0 validation commands pass
[ ] Codex explicitly says READY / NOT READY FOR M1
```

---

# 11. M0 Completion Gate

Do not begin M1 until:

```text
[ ] repository initializes cleanly
[ ] pnpm install works
[ ] lint passes
[ ] typecheck passes
[ ] unit tests pass
[ ] E2E smoke test passes
[ ] production build passes
[ ] Supabase development structure exists
[ ] environment validation exists
[ ] no secrets are committed
[ ] /docs is present
[ ] CONTRIBUTING/development rules exist
[ ] CI exists
[ ] no product features were implemented prematurely
```

---

# 12. Recommended Commit Sequence

Use small commits.

Example:

```text
chore: initialize nextjs platform foundation
chore: add supabase development setup
test: add vitest and playwright foundation
chore: add ci and contributor rules
```

Avoid one giant:

```text
"initial platform"
```

commit containing unrelated changes.

---

# 13. What to Do If Codex Goes Out of Scope

If Codex unexpectedly creates:

- login UI,
- dashboards,
- database business schema,
- teams,
- AI,
- chat,
- product pages,

during M0:

1. identify the out-of-scope changes,
2. ask Codex to revert only those changes,
3. preserve valid M0 infrastructure,
4. rerun tests.

Do not accept unnecessary feature code just because it works.

---

# 14. What to Do If Codex Finds a Documentation Conflict

Codex should report:

```text
CONFLICT
Document A:
Document B:
Why they conflict:
Affected implementation:
Suggested options:
```

Do not ask Codex to choose the product rule.

Resolve the rule first, update docs if needed, then continue.

---

# 15. M0 Output Expected Before M1

At the end of M0, the repository should approximately contain:

```text
/
├── app/
├── components/
├── features/
├── lib/
├── supabase/
│   ├── migrations/
│   └── seed.sql
├── tests/
│   ├── unit/
│   ├── integration/
│   └── e2e/
├── docs/
│   ├── 01_...
│   ├── ...
│   └── 14_CODEX_M0_PROMPTS.md
├── .github/
│   └── workflows/
├── .env.example
├── CONTRIBUTING.md
├── README.md
├── package.json
├── pnpm-lock.yaml
└── tsconfig.json
```

No actual FICI business feature should be required yet.

---

# 16. Next File After M0

Once M0 has actually been completed and reviewed in Codex, create:

# `15_CODEX_M1_PROMPTS.md`

That file should break Authentication into bounded tasks such as:

```text
M1.1 Supabase Auth Plumbing
M1.2 User Profile Schema
M1.3 Login / Logout
M1.4 Password Reset
M1.5 Protected Routes
M1.6 Auth Acceptance Tests
```

Do not create the M1 implementation prompts based on assumptions about M0 results if M0 revealed technical issues that should first be incorporated.

---

# 17. Final Execution Rule

For every prompt in this file:

```text
ONE TASK
→ REVIEW
→ TEST
→ COMMIT
→ NEXT TASK
```

Do not run all prompts blindly without reviewing Codex's output between steps.

---

# End of Document

**Current Status:** Draft v0.1 — Ready for Ahmad/FICI review.  
**Execution Step After Approval:** Start with **M0.1 — Repository Initialization** in Codex.
