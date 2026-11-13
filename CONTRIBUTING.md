# Contributing to FICI

## Source of truth and scope

Read the relevant numbered files in `/docs` before making changes. Documents
01–31 are the product, architecture, security, and implementation source of truth.
This guide summarizes their rules; it does not replace them.

- Do not invent business rules or silently change approved requirements to simplify implementation.
- Flag ambiguities or contradictions with the document names, sections, and affected behavior. Stop the affected implementation and request a decision; do not invent precedence.
- Keep each change within its authorized milestone and task. Do not begin the next milestone without authorization.
- Product or architecture changes require documented approval before implementation. Do not rewrite `/docs` as an incidental code change.

## Security and data integrity

- Schema changes require versioned migrations under `supabase/migrations/`.
- RLS is mandatory for protected Supabase tables. Enforce permissions server-side and at the database; hidden UI controls are not authorization.
- Apply Role + Scope + Resource authorization. Never trust client-provided identity, role, ownership, or membership; deny access unless explicitly allowed.
- Personal and Team workspace isolation is mandatory. Sharing must be explicit and scoped to authorized content; it does not expose the source workspace or transfer ownership.
- Approved artifact history must not be overwritten. Revisions create new versions; preserve authorship, provenance, evidence links, and historical contributions after membership changes.
- AI must respect the user's current permissions when selecting context. It cannot bypass revoked access, approve content, or silently change approved project state.
- AI output is not evidence. Keep AI suggestions, source evidence, human decisions, and instructor feedback distinct; project-changing suggestions require explicit human confirmation.
- Keep secrets server-only and out of source control, browser bundles, logs, and test reports. Never put secret keys in `NEXT_PUBLIC_*`; `.env.example` contains placeholders only.
- Preserve strict TypeScript, module boundaries, and runtime validation of untrusted input.

These rules follow docs 03–05, 08–12, and the applicable milestone prompts.

## Validation and Definition of Done

Use the Node and pnpm versions documented in README and `package.json`. Include
`pnpm-lock.yaml` with dependency changes and preserve the documented compatibility
pins/patches unless a verified defect or supported replacement justifies a change.

Run from the repository root after installing dependencies and Playwright Chromium
as described in README:

```sh
pnpm lint
pnpm typecheck
pnpm test:unit
pnpm build
pnpm test:e2e
```

Run `pnpm test` for all Vitest unit/integration tests and add relevant tests as
features are authorized. Tests and acceptance criteria in
`docs/12_ACCEPTANCE_TESTS.md` are part of Definition of Done; compiling alone is
insufficient. Permission changes require direct authorization/RLS tests, including
denied access. Report actual commands, results, limitations, and unresolved
requirements in the PR. Do not weaken checks or invent passing placeholders.

M0 contains foundation smoke tests only. Product acceptance tests belong to their
approved milestones. See README for the Windows Playwright cleanup limitation.
