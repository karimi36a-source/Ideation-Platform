# FICI Invention Education & Development Platform
## Technical Architecture Specification

**Document:** `10_TECHNICAL_ARCHITECTURE.md`  
**Status:** Draft v0.1 — For Review  
**Research Snapshot:** September 17, 2026  
**Depends on:** `01_PRODUCT_REQUIREMENTS.md` through `09_AI_ASSISTANT_SPEC.md`  
**Purpose:** Select the initial technology stack and define the technical architecture that Codex should implement for the FICI platform.

---

# 1. Technical Architecture Decision

The recommended MVP architecture is:

```text
WEB APPLICATION
Next.js 16.3 Active LTS
React
TypeScript
        │
        ├───────────────┐
        │               │
        ▼               ▼
APPLICATION API     REALTIME COLLABORATION
Next.js Server      Supabase Realtime
Routes / Actions    + Liveblocks where needed
        │
        ▼
CORE PLATFORM DATA
Supabase
PostgreSQL
Auth
Storage
Realtime
Row Level Security
        │
        ├───────────────────────────┐
        │                           │
        ▼                           ▼
AI SERVICE                    LIVE CLASSROOM
OpenAI Responses API          Daily Video SDK / Prebuilt
Provider abstraction          initially integrated
        │
        ▼
EXTERNAL RESEARCH
PATENTSCOPE
USPTO
Google Patents links
(initially user-assisted)
```

Deployment:

```text
GitHub
↓
Vercel
↓
Next.js Application
```

Transactional email:

```text
Resend
```

Visual structured tools:

```text
React Flow / custom React components
+
Liveblocks realtime synchronization for selected multiplayer tools
```

---

# 2. Why This Architecture

The platform requires:

- relational structured data,
- complex permissions,
- team isolation,
- persistent Development Projects,
- version history,
- realtime chat,
- collaborative tools,
- file storage,
- AI integration,
- live teaching,
- rapid MVP development,
- strong future portability.

A PostgreSQL-centered architecture is a better fit than a primarily document-database architecture because the platform contains highly relational objects:

```text
Problem
→ Solution
→ Feature
→ Function
→ Component
→ Evidence
→ Decision
→ Version
```

The architecture must preserve these relationships.

---

# 3. Selected Technology Stack

| Area | Selected MVP Technology |
|---|---|
| Language | TypeScript |
| Frontend | Next.js 16.3 Active LTS + React |
| UI | React components + accessible component primitives |
| Backend/Application API | Next.js server routes/actions |
| Primary Database | Supabase PostgreSQL |
| Authentication | Supabase Auth |
| Authorization | PostgreSQL RLS + server-side application checks |
| File Storage | Supabase Storage |
| Basic Realtime | Supabase Realtime |
| Team Chat | Supabase Database + Realtime Broadcast |
| High-frequency Collaboration | Liveblocks |
| Mind Map / Node Editor | React Flow |
| AI | OpenAI Responses API behind provider abstraction |
| AI Default Model Profile | GPT-5.6 Terra |
| AI Deep Analysis Profile | GPT-5.6 Sol |
| AI Low-cost Profile | GPT-5.6 Luna |
| Live Video | Daily Video SDK / Prebuilt |
| Transactional Email | Resend |
| Deployment | Vercel |
| Repository | GitHub |
| E2E Testing | Playwright |
| Unit / Integration Testing | Vitest |
| Runtime Validation | Zod |
| Package Manager | pnpm |
| Database Migrations | Supabase CLI / SQL migrations |

---

# 4. Frontend — Next.js

## Decision

Use:

**Next.js 16.3 Active LTS + App Router + TypeScript**

Do not use canary or experimental releases for production.

## Why

The current Next.js documentation identifies the App Router as the newer routing model supporting modern React features.

Next.js 16.3 is currently Active LTS and the project has an established security support policy.

The platform benefits from:

- server and client React components,
- file-based routing,
- server-side authorization,
- streaming,
- API routes,
- server actions where appropriate,
- mature React ecosystem,
- strong Codex compatibility.

## Rule

Pin the exact production version in `package.json`.

Do not use `"latest"` in production deployment configuration after the initial setup.

---

# 5. TypeScript

All application code should use TypeScript.

Recommended compiler posture:

- strict mode enabled,
- no implicit any,
- strict null checks,
- no unchecked data from APIs,
- shared domain types,
- generated database types.

Business rules should use domain-specific types rather than generic dictionaries wherever practical.

---

# 6. Repository Structure

Recommended initial structure:

```text
/
├── app/
│   ├── (auth)/
│   ├── (platform)/
│   ├── api/
│   └── ...
│
├── components/
│   ├── common/
│   ├── workspace/
│   ├── activities/
│   ├── collaboration/
│   └── review/
│
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
│
├── lib/
│   ├── auth/
│   ├── permissions/
│   ├── db/
│   ├── ai/
│   ├── realtime/
│   ├── validation/
│   └── audit/
│
├── supabase/
│   ├── migrations/
│   ├── seed.sql
│   └── tests/
│
├── tests/
│   ├── unit/
│   ├── integration/
│   └── e2e/
│
├── docs/
│   └── approved project specifications
│
└── scripts/
```

Feature boundaries are preferred over a large generic `utils` directory.

---

# 7. Backend Architecture

The MVP should use a **modular monolith**, not microservices.

## Why

Microservices would add unnecessary:

- deployment complexity,
- distributed tracing,
- network failure modes,
- authentication duplication,
- operational cost.

For the MVP, one Next.js application with clearly separated feature modules is sufficient.

Conceptually:

```text
Next.js Application
├── Identity Module
├── Course Module
├── Team Module
├── Workspace Module
├── Development Project Module
├── Activity Module
├── Evidence Module
├── AI Module
├── Review Module
├── Version Module
└── Sharing Module
```

Modules may later be separated if scale or operational needs justify it.

---

# 8. Database — Supabase PostgreSQL

## Decision

Use Supabase PostgreSQL as the source of truth.

Supabase currently provides:

- PostgreSQL,
- Authentication,
- Storage,
- Realtime,
- backups,
- APIs,
- Row Level Security integration.

## Why PostgreSQL Fits FICI

The platform has strong relational requirements.

Examples:

```text
Team
→ Members
→ Project
→ Artifacts
→ Versions
→ Evidence
→ Decisions
```

and:

```text
Problem
→ Solution
→ Function
→ Component
→ Requirement
→ Risk
→ Test
→ Evidence
```

PostgreSQL supports this naturally.

---

# 9. Supabase Plan

## Development

Supabase Free may be used for early local/prototype work.

## Production MVP

Use **Supabase Pro**.

Research snapshot:

- Pro starts at approximately **USD $25/month**.
- Includes 100,000 monthly active users before overage.
- Includes 8 GB database disk per project before overage.
- Includes 100 GB file storage before overage.
- Includes daily backups with 7-day retention.

Pricing must be checked again before purchase.

Official source:

`https://supabase.com/pricing`

---

# 10. Database Source of Truth

Database schema must be managed through committed migrations.

Use:

```text
/supabase/migrations
```

Rules:

1. No undocumented manual production schema edits.
2. Every schema change receives a migration.
3. Migrations are committed to Git.
4. Database types are regenerated after schema changes.
5. Codex must not change production tables directly without migration files.

---

# 11. ORM Decision

Do **not** introduce a heavy ORM in the first MVP unless a concrete need appears.

Preferred:

- `supabase-js`
- generated TypeScript database types
- SQL migrations
- PostgreSQL functions/RPC where appropriate

Reason:

RLS policies and PostgreSQL security are central to this platform.

Hiding database behavior behind a large ORM can make authorization harder to reason about.

Drizzle may be introduced later if server-side query complexity creates enough benefit.

---

# 12. Authentication — Supabase Auth

Use Supabase Auth.

Initial authentication methods:

## MVP

- email/password
- password reset
- email verification

## SHOULD HAVE

- Google OAuth
- Microsoft OAuth

## LATER

- enterprise SSO / SAML

Application identity remains represented in the platform `users` / profile model.

---

# 13. Authorization — PostgreSQL RLS

Authorization is one of the highest-risk parts of this product.

Supabase/PostgreSQL Row Level Security should enforce data boundaries at the database layer.

Official Supabase guidance recommends enabling RLS for exposed tables.

## Principle

Frontend hiding is not security.

Every protected query must be authorized server-side/database-side.

---

# 14. RLS Scope Model

Policies should evaluate:

- authenticated user ID,
- role assignment,
- organization,
- cohort enrollment,
- team membership,
- project membership,
- workspace ownership,
- explicit shares,
- Master/Mentor assignment.

Examples:

### Personal Workspace

```text
ALLOW SELECT
WHERE workspace.owner_user_id = auth.uid()
OR explicit share exists
OR authorized review submission exists
```

### Team Workspace

```text
ALLOW SELECT
WHERE active team membership exists
OR user is assigned Master
OR explicit share exists
```

### Cross-Team

No default access.

Only explicit `shares` records grant access.

---

# 15. Security Helper Functions

Instead of duplicating complex policy expressions everywhere, create audited database helper functions such as:

```text
can_access_workspace(user_id, workspace_id)
can_edit_workspace(user_id, workspace_id)
can_access_project(user_id, project_id)
can_review_project(user_id, project_id)
can_access_artifact(user_id, artifact_id)
```

These must be security-reviewed.

They should be covered by automated RLS tests.

---

# 16. Realtime Architecture — Split Responsibilities

Do not use one realtime system for every feature blindly.

Use:

## Supabase Realtime

For:

- Team Chat
- notifications,
- activity status,
- simple presence,
- project state updates,
- review updates.

## Liveblocks

For:

- simultaneous visual editing,
- cursor/presence in collaborative canvases,
- conflict-free shared state,
- collaborative Mind Map,
- Affinity Board,
- high-frequency multiplayer interactions.

This separation reduces unnecessary vendor usage.

---

# 17. Supabase Realtime

Supabase currently provides:

- Broadcast,
- Presence,
- Postgres Changes.

Their documentation recommends Broadcast for most scalable realtime database-change use cases and supports RLS-authorized private channels.

Use Broadcast/private channels for team-scoped events.

## Team Chat

Recommended pattern:

```text
User sends message
↓
Server validates team access
↓
Message inserted into PostgreSQL
↓
Realtime Broadcast notifies connected authorized clients
↓
Clients fetch/render canonical stored message
```

The database remains the source of truth.

Do not rely on ephemeral broadcast messages as permanent chat storage.

---

# 18. Liveblocks

## Decision

Use Liveblocks selectively for the collaborative visual tools.

Liveblocks currently provides:

- realtime collaboration,
- presence,
- CRDT-backed storage,
- comments,
- notifications,
- Yjs support,
- user/group/room permissions.

## Initial Use

- Mind Map
- Affinity Board
- potentially shared Brainstorming canvas

Do not use it for all platform data.

---

# 19. Liveblocks Pricing Strategy

Research snapshot:

### Free

Useful for prototype/testing.

### Pro

Approximately:

- USD $30/month monthly
- USD $25/month billed annually
- 10 simultaneous connections per room
- usage-based collaboration charges

Current realtime collaboration usage rate is approximately:

**$0.002 per collaboration minute**

Check pricing before production purchase.

Official sources:

`https://liveblocks.io/pricing`

`https://liveblocks.io/docs/pricing/plans`

---

# 20. Liveblocks Permission Design

Liveblocks must not become an independent authorization source detached from FICI.

FICI database remains the master permission system.

Flow:

```text
User requests collaborative room
↓
FICI server checks Supabase role/workspace permission
↓
Server issues Liveblocks authentication
↓
Liveblocks grants only required room permission
```

Use private rooms by default.

The current Liveblocks documentation supports user/group room permissions and recommends secure server-side authentication for production.

---

# 21. Canonical Data vs Realtime Collaboration State

Avoid dual-source-of-truth ambiguity.

## Supabase PostgreSQL owns:

- project objects,
- artifacts,
- versions,
- final Mind Map structure snapshots,
- decisions,
- evidence,
- permissions,
- approvals.

## Liveblocks owns temporarily:

- live collaborative editing state,
- cursor/presence,
- multiplayer conflict resolution.

At meaningful save/version points:

```text
Live collaborative state
↓
validated
↓
normalized
↓
saved into Supabase artifact version
```

Approved project state always comes from Supabase.

---

# 22. Mind Map Technology

## Decision

Use **React Flow** for structured node-based tools.

React Flow is currently MIT licensed and supports:

- nodes,
- edges,
- dragging,
- zooming,
- panning,
- selection,
- adding/removing elements.

Official source:

`https://reactflow.dev/`

## Why React Flow

FICI does not need a generic infinite whiteboard first.

It needs structured semantic diagrams connected to platform objects.

React Flow fits:

```text
System
→ Subsystem
→ Component
→ Function
→ Gap
```

better than a fully free-form drawing canvas.

---

# 23. tldraw Decision

Do not make tldraw a core MVP dependency initially.

Current tldraw production SDK licensing is commercial/value-priced after trial.

It is powerful, but FICI's first requirement is structured invention mapping rather than a general-purpose whiteboard.

Reconsider later if free-form drawing becomes essential.

Official source:

`https://tldraw.dev/pricing`

---

# 24. Activity Boards

Recommended implementation:

## Brainstorming

Custom card board.

## Problem / Solution Board

Custom structured card/grid/list.

## Dot Voting

Custom native component.

## Affinity

Custom card grouping interface + Liveblocks for simultaneous movement.

## Mind Map

React Flow + Liveblocks.

## Decision Record

Native structured form/view.

This ensures FICI owns the curriculum logic.

---

# 25. Drag-and-Drop

Use a maintained React drag-and-drop library or browser-native techniques for simple boards.

Avoid making a broad whiteboard dependency necessary for card movement.

The specific small library may be chosen during implementation.

---

# 26. AI Provider

## Decision

Use OpenAI API as the initial AI provider behind an internal abstraction layer.

Use the **Responses API** for new development.

Business logic must not directly depend on one model ID.

Internal model profiles:

```text
AI_FAST
AI_STANDARD
AI_DEEP
```

---

# 27. Initial AI Model Mapping

Research snapshot as of September 2026:

## `AI_FAST`

GPT-5.6 Luna

Use for:

- classification,
- simple summarization,
- light extraction,
- low-cost repetitive tasks.

Current listed API pricing:

- $0.20 / 1M input tokens
- $1.20 / 1M output tokens

## `AI_STANDARD`

GPT-5.6 Terra

Default FICI model.

Use for:

- SCAMPER assistance,
- brainstorming,
- requirements analysis,
- standard comparisons,
- structured project assistance.

Current listed pricing:

- $2 / 1M input tokens
- $12 / 1M output tokens

## `AI_DEEP`

GPT-5.6 Sol

Use selectively for:

- difficult patent comparisons,
- complex project critique,
- final cross-artifact analysis.

Current listed pricing:

- $4 / 1M input tokens
- $20 / 1M output tokens

Official model source:

`https://developers.openai.com/api/docs/models`

Pricing is time-sensitive and must not be hard-coded into product logic.

---

# 28. AI Provider Abstraction

Create a server-side interface conceptually like:

```text
AIProvider
├── generate()
├── generateStructured()
├── stream()
└── estimateUsage()
```

Business layer calls:

```text
runAiTask({
  taskType,
  modelProfile,
  user,
  workspace,
  project,
  contextRefs,
  input
})
```

The task service chooses the provider/model.

Do not write curriculum code that calls `gpt-5.6-terra` directly.

---

# 29. AI Context Builder

AI context must be assembled server-side.

Pipeline:

```text
Authenticate
↓
Resolve user scope
↓
Resolve workspace
↓
Resolve project/activity
↓
Retrieve authorized context
↓
Minimize context
↓
Record context references
↓
Call AI provider
↓
Validate response
↓
Store AI output
```

This implementation directly follows `09_AI_ASSISTANT_SPEC.md`.

---

# 30. AI Structured Output

Use structured outputs for project-object generation whenever practical.

Validate results with Zod before persistence.

Example:

```text
AI response
↓
Zod schema validation
↓
Candidate data
↓
Human confirmation
↓
Database write
```

Never write unchecked model JSON directly into canonical project state.

---

# 31. AI Secrets

OpenAI keys must exist only in server-side environment variables.

Never:

- expose keys in browser JavaScript,
- store API keys in user-visible records,
- commit `.env` files.

---

# 32. Live Classroom — Daily

## Decision

Do not build WebRTC infrastructure from scratch.

Use Daily for MVP live-class integration.

Daily currently offers:

- Video SDK
- Daily Prebuilt
- audio/video
- screen sharing
- recording
- live streaming
- programmatic rooms.

## Initial Strategy

### MVP Phase 1

Daily Prebuilt or a lightly customized embedded room.

### Later

Daily Video SDK for deeper FICI-specific controls.

This allows faster launch while preserving the option to create a custom classroom experience later.

---

# 33. Daily Pricing Snapshot

As of September 2026:

- first **10,000 participant-minutes/month** are free,
- 10,001–100,000 participant-minutes: about **$0.004/min**,
- graduated volume discounts follow.

Cloud recording is separately billed.

Official source:

`https://www.daily.co/pricing/video-sdk/`

Prices must be rechecked before production planning.

---

# 34. Live Classroom Scope

Daily owns:

- media transport,
- WebRTC infrastructure,
- participant media connections,
- video/audio quality.

FICI owns:

- session,
- attendance relationship,
- team assignment,
- active activity,
- Development Project,
- instructor controls specific to FICI,
- artifacts,
- decisions,
- course state.

A video provider must never become the source of truth for course/project data.

---

# 35. Breakout Rooms

For early MVP:

- use separate Daily room/session links where needed,
- connect each breakout room to Team Workspace logically.

Later:

- integrate room creation and Master navigation programmatically.

Do not attempt to build custom media routing.

---

# 36. Patent Research Integration

## MVP Decision

Do not build a full patent search engine.

Initial integration:

```text
FICI Patent Workspace
├── PATENTSCOPE external search link
├── USPTO external search link
├── Google Patents external search link
└── Add Patent Record to Project
```

Users can:

- search externally,
- save patent number,
- save URL,
- enter/import relevant metadata,
- attach evidence,
- ask AI to analyze saved material.

---

# 37. Patent Integration — Later

Investigate official APIs/data services individually.

Potential later capabilities:

- patent metadata retrieval,
- automatic abstract retrieval,
- classification lookup,
- document ingestion,
- structured claim extraction,
- semantic project-to-patent search.

Do not scrape services in ways that violate their terms.

---

# 38. File Storage

## Decision

Use Supabase Storage for MVP.

Store:

- evidence attachments,
- activity files,
- project files,
- chat attachments,
- reference images.

Metadata lives in PostgreSQL.

Binary files live in Storage.

---

# 39. Storage Access

Buckets containing confidential invention content must be private.

Use signed/authorized access.

Never rely on publicly accessible file URLs for confidential project data.

File permission must be checked through:

- workspace,
- project,
- share,
- role.

---

# 40. Email

## Decision

Use Resend for transactional application email.

Initial uses:

- invitation,
- email verification support if needed,
- review notification,
- revision requested,
- team membership notification,
- password-related templates where appropriate.

Research snapshot:

- Free: 3,000 emails/month, with daily limit
- Pro: about $20/month for 50,000 emails/month

Official source:

`https://resend.com/pricing`

In-app notifications should remain the primary workflow notification layer later.

---

# 41. Hosting — Vercel

## Decision

Deploy the Next.js web application to Vercel for MVP.

Why:

- first-class Next.js deployment,
- CI/CD from Git,
- preview deployments,
- serverless/edge capabilities,
- custom domains,
- fast startup.

Research snapshot:

- Hobby: free
- Pro: about USD $20/month with included usage credit

Use Pro for production once the pilot begins.

Official source:

`https://vercel.com/pricing`

---

# 42. Hosting Portability

Do not use Vercel-only business logic unnecessarily.

Core application should remain standard Next.js / Node-compatible.

Avoid excessive dependence on proprietary Vercel features when an equivalent portable architecture is reasonable.

The goal is easy deployment now without blocking future migration.

---

# 43. GitHub

GitHub is the source-of-truth code repository.

Recommended branch model:

```text
main
develop (optional)
feature/*
fix/*
```

For a small Codex-driven MVP, a simpler model is acceptable:

```text
main
feature/*
```

Every feature should be implemented through a pull request when practical.

---

# 44. Codex Development Workflow

Codex should receive:

```text
/docs
```

as authoritative product documentation.

Recommended workflow:

```text
Read relevant docs
↓
Create implementation plan
↓
Identify affected files
↓
Implement one bounded feature
↓
Run tests
↓
Run lint/typecheck
↓
Report changes
↓
Human review
↓
Commit / PR
```

Codex should not be prompted to "build the whole platform" in one task.

---

# 45. Package Manager

Use:

**pnpm**

Reasons:

- efficient dependency storage,
- fast installs,
- supported by current Next.js guidance,
- reliable lockfile.

Commit `pnpm-lock.yaml`.

---

# 46. Runtime Validation

Use **Zod** for validating:

- form payloads,
- API payloads,
- AI structured outputs,
- external data,
- environment variables where practical.

TypeScript types alone do not validate runtime input.

---

# 47. Forms

Use server-side validated forms for ordinary business forms.

Collaborative activity interfaces may use client state but must validate persistence operations server-side/database-side.

---

# 48. API Architecture

Use internal typed server operations.

Expose route handlers for:

- realtime auth,
- AI requests,
- provider webhooks,
- external integrations,
- upload signing,
- system callbacks.

Do not unnecessarily expose every database operation as a custom REST endpoint because Supabase already provides controlled database APIs.

Critical writes should go through explicit service functions.

---

# 49. Service Layer

Create business-domain service modules.

Examples:

```text
TeamService
WorkspaceService
ProjectService
ActivityService
ArtifactService
EvidenceService
DecisionService
ReviewService
SharingService
AIService
```

Components must not contain core authorization/business rules.

---

# 50. Command / Mutation Pattern

Important business mutations should be named explicitly.

Examples:

```text
createTeam()
addTeamMember()
removeTeamMember()
shareArtifact()
submitArtifact()
requestRevision()
approveArtifact()
createArtifactVersion()
promoteAiCandidate()
recordDecision()
```

This will later align with `11_API_CONTRACTS.md`.

---

# 51. Transactions

Use PostgreSQL transactions for operations that must be atomic.

Examples:

### Approve Version

```text
mark submitted version APPROVED
+
supersede previous current version
+
set project baseline
+
create audit event
```

must succeed or fail together.

### Move Team Member

```text
close old membership
+
create new membership
+
update access
+
audit
```

should be transactionally consistent.

---

# 52. Audit Architecture

Audit events should be server-generated.

Clients may request actions but must not author trusted audit records directly.

Log:

- role changes,
- membership changes,
- sharing,
- approvals,
- sensitive permission changes,
- archival.

---

# 53. Versioning Implementation

Use immutable `artifact_versions`.

Do not mutate approved version bodies.

Pattern:

```text
Artifact
└── Version 1 — approved
└── Version 2 — draft
└── Version 3 — future
```

`artifacts.current_version_id` references the current approved/current version.

---

# 54. Collaborative Artifact Save Strategy

For Liveblocks-enabled artifacts:

```text
Realtime room state
↓ periodic/local collaborative updates
↓
Explicit Save / Version checkpoint
↓
Server validates
↓
Artifact Version snapshot saved to PostgreSQL
```

Autosave may update a draft snapshot.

Formal approved versions remain explicit.

---

# 55. Team Chat Architecture

Canonical table:

```text
chat_messages
```

Realtime:

```text
Supabase Broadcast
```

Authorization:

```text
team membership / Master scope
```

Message flow:

```text
Client
↓
authorized mutation
↓
Postgres insert
↓
Broadcast event
↓
authorized subscribers
```

---

# 56. Notifications Architecture

## MVP

Persist notifications in PostgreSQL.

Use Supabase Realtime to update connected clients.

Email only for important async events.

Later consider Liveblocks Notifications if it becomes materially useful for collaborative comments.

Avoid duplicating notification systems too early.

---

# 57. Search Architecture

## MVP

Use PostgreSQL search/filtering.

Support searching:

- objects,
- artifacts,
- evidence,
- patent records,
- decisions.

## Later

Add vector/semantic search when AI retrieval requires it.

Supabase/PostgreSQL can support a vector extension later without replacing the database architecture.

---

# 58. AI Retrieval Architecture — MVP

Do not build sophisticated RAG first.

Use structured queries based on:

- current project,
- activity,
- object links,
- current baseline,
- explicit context selections.

This is more reliable for the early structured curriculum.

## Later

Add embeddings/vector retrieval for large evidence collections.

---

# 59. UI Component Strategy

The platform should own the visual identity but does not need to build low-level primitives from scratch.

Use accessible React primitives/component library concepts for:

- dialogs,
- dropdowns,
- tabs,
- tooltips,
- forms,
- tables.

Keep business-specific components custom.

Examples:

- SCAMPER card
- Problem card
- Solution card
- Evidence card
- Decision panel
- Artifact status
- Team workspace
- Development map

---

# 60. Styling

Recommended:

- Tailwind CSS or equivalent utility-first styling,
- centralized design tokens,
- CSS variables,
- responsive layouts,
- WCAG-aware accessibility.

Exact branding will be a later UI specification.

---

# 61. Accessibility

Minimum architecture requirement:

- keyboard navigation,
- semantic HTML,
- labels,
- focus states,
- accessible dialogs,
- sufficient contrast,
- screen-reader-compatible controls where practical.

Collaborative canvas tools should provide alternative structured views when possible.

---

# 62. Testing Strategy

Testing is mandatory because permissions are high-risk.

## Unit Tests

Use Vitest.

Test:

- business rules,
- validators,
- status transitions,
- AI output conversion logic.

## Integration Tests

Test:

- database mutations,
- RLS policies,
- team isolation,
- artifact versioning,
- review transactions.

## End-to-End

Use Playwright.

Critical E2E flows:

1. user sign-in,
2. Personal Workspace privacy,
3. Team Workspace access,
4. add/remove member,
5. team chat,
6. share artifact,
7. submit/revise/approve,
8. cross-team denial,
9. AI context access boundary.

---

# 63. RLS Security Tests

Create database security tests for at least:

```text
Student A cannot read Student B Personal Workspace.
Team A cannot read Team B Team Workspace.
Removed member cannot read future Team A data.
Student cannot approve instructor-gated artifact.
Unshared artifact cannot be accessed through direct ID.
Unshared file cannot be downloaded through direct reference.
AI context query cannot return inaccessible object.
```

No MVP release without these tests.

---

# 64. CI Pipeline

GitHub Actions or Vercel/GitHub checks should run:

```text
pnpm install
pnpm lint
pnpm typecheck
pnpm test
database tests
build
E2E smoke tests
```

A failing check should block production merge once the workflow is established.

---

# 65. Environments

Use separate:

- Local
- Preview / Development
- Production

Never point local development to production database by default.

Separate Supabase projects/environments should be considered for staging and production as pilot maturity increases.

---

# 66. Environment Variables

Examples:

```text
NEXT_PUBLIC_SUPABASE_URL
NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY
SUPABASE_SECRET_KEY
OPENAI_API_KEY
LIVEBLOCKS_SECRET_KEY
DAILY_API_KEY
RESEND_API_KEY
```

Exact current Supabase key naming should follow current documentation; Supabase is transitioning away from older anon/service_role naming during 2026.

Secrets must be server-only.

---

# 67. Logging

Log server-side events with structured fields:

- request ID,
- user ID where appropriate,
- project ID,
- workspace ID,
- operation,
- result,
- error code.

Do not log confidential invention content unnecessarily.

---

# 68. Error Handling

Return user-safe errors.

Internal logs may contain technical diagnostics but must avoid:

- access tokens,
- API secrets,
- entire confidential prompts,
- private files.

Permission errors should not reveal whether inaccessible resources exist.

---

# 69. Observability

## MVP

Use:

- Vercel deployment/runtime logs,
- Supabase logs,
- provider dashboards,
- structured application logs.

## SHOULD HAVE

Add a dedicated error monitoring provider such as Sentry after the foundation is stable.

---

# 70. Backups

Production must use paid database backups.

Supabase Pro currently provides daily backups with retention.

Before pilot:

- document recovery process,
- test database restore,
- document file-storage recovery limitations.

---

# 71. Data Portability

FICI should be able to export:

- PostgreSQL database,
- storage files,
- project data,
- artifact versions,
- AI outputs,
- evidence metadata.

Avoid business-critical state existing only in external SaaS providers.

---

# 72. Vendor Ownership Boundaries

## FICI Owns

- database schema,
- project data,
- curriculum logic,
- permission model,
- team logic,
- structured tools,
- Development Project logic,
- AI context logic,
- prompts,
- evidence logic,
- artifact versions,
- decision history.

## Supabase Provides

- managed PostgreSQL,
- authentication infrastructure,
- storage infrastructure,
- realtime transport.

## Liveblocks Provides

- multiplayer synchronization infrastructure.

## Daily Provides

- video/audio infrastructure.

## OpenAI Provides

- model inference.

## Vercel Provides

- web deployment/runtime infrastructure.

All provider dependencies should be replaceable without redesigning FICI's core project model.

---

# 73. Build vs Integrate Decisions

## Authentication

**Integrate — Supabase Auth**

Reason: commodity infrastructure with strong database integration.

## Database

**Use Infrastructure — Supabase PostgreSQL**

FICI owns schema/business logic.

## Team Chat

**Build feature using Supabase infrastructure**

FICI owns chat model and permissions.

## Mind Map

**Build FICI feature using React Flow + Liveblocks infrastructure**

FICI owns semantic tool behavior.

## Affinity Board

**Build FICI feature using React + Liveblocks infrastructure**

## Voting

**Build natively**

Simple, curriculum-specific, tightly linked to Decision Records.

## AI

**Integrate OpenAI models through FICI abstraction**

## Video

**Integrate Daily**

Do not build WebRTC media infrastructure.

## Patent Search

**Integrate/link external search sources initially**

Do not build full patent index.

---

# 74. Expected Initial Monthly Infrastructure Cost

Very early production/pilot approximation, before significant usage:

```text
Supabase Pro               ~ $25
Vercel Pro                 ~ $20
Liveblocks Pro             ~ $25–30
Resend                     $0–20
Daily                      $0 until free minute allowance exceeded
OpenAI API                 usage-based
Domain                     separate
---------------------------------------------
Base platform services     roughly $70–95/month
+ AI usage
+ video overage
+ collaboration overage
```

This is only a planning snapshot, not a budget guarantee.

All vendor pricing is usage-sensitive and must be rechecked before purchase.

---

# 75. Scaling Path

Do not prematurely redesign for millions of users.

Architecture can scale progressively:

## Stage 1 — Pilot

- one production app,
- Supabase Pro,
- Vercel Pro,
- Liveblocks Pro,
- Daily usage-based,
- one AI provider.

## Stage 2 — Multiple Cohorts

- higher database compute if needed,
- stronger monitoring,
- background jobs where required,
- collaboration capacity review,
- cost dashboards.

## Stage 3 — Institutional Customers

Consider:

- organization tenancy enhancements,
- SSO,
- compliance controls,
- dedicated environments,
- enterprise plans,
- regional requirements,
- stronger audit/export systems.

---

# 76. Background Jobs

The MVP should avoid requiring a complex queue unless needed.

Potential later tasks:

- large file processing,
- patent document extraction,
- bulk AI analysis,
- scheduled notifications,
- exports,
- email digests.

When these appear, introduce a managed job/queue system deliberately.

Do not implement polling loops in application requests.

---

# 77. Webhooks

Use verified provider webhooks for:

- Daily events if needed,
- Resend delivery status,
- Supabase provider events where applicable,
- future external integrations.

Webhook handlers must:

- verify signatures,
- be idempotent,
- write audit/log records,
- reject malformed events.

---

# 78. Idempotency

Critical mutations should protect against duplicate requests.

Examples:

- invite member,
- approve version,
- process webhook,
- create payment later,
- create AI candidate from saved output.

---

# 79. Security Headers

Production application should configure:

- HTTPS only,
- secure cookies,
- Content Security Policy where practical,
- frame restrictions,
- referrer policy,
- MIME sniffing protection.

Exact policy should be reviewed during implementation because embedded Daily/video content may affect CSP requirements.

---

# 80. CSRF / Session Protection

Use framework/provider-recommended session handling.

Server-side mutations must verify authenticated session and authorization.

Do not rely on client-supplied user IDs.

---

# 81. Rate Limiting

Rate-limit:

- login-sensitive endpoints,
- AI endpoints,
- invitations,
- share endpoints,
- file upload signing,
- realtime authentication endpoints.

AI should additionally have product-level usage limits.

---

# 82. File Security

Validate:

- allowed MIME types,
- file size,
- uploader permission.

Later add malware scanning if external/enterprise usage requires it.

Confidential files must not be public.

---

# 83. Data Retention

Before broader deployment, define policies for:

- archived projects,
- chat,
- AI outputs,
- audit logs,
- course records,
- deleted accounts.

Initial MVP may preserve most development history because traceability is a product requirement.

---

# 84. Canadian / International Deployment

The technical architecture must later review privacy/compliance requirements based on:

- participant location,
- institutional customers,
- invention confidentiality,
- selected provider data regions.

Do not make legal/compliance claims solely from infrastructure selection.

---

# 85. Technical Decisions Captured

## TECH-001 — Modular Monolith

Use one structured Next.js application rather than microservices for MVP.

**Status:** Recommended.

## TECH-002 — Next.js + TypeScript

Use Next.js Active LTS App Router with TypeScript.

**Status:** Recommended.

## TECH-003 — Supabase as Core Infrastructure

Use Supabase PostgreSQL/Auth/Storage/Realtime.

**Status:** Recommended.

## TECH-004 — PostgreSQL Is Canonical Source

Canonical Development Project data lives in PostgreSQL.

**Status:** Required.

## TECH-005 — RLS Is Mandatory

Database-level permission enforcement is required.

**Status:** Required.

## TECH-006 — Realtime Split

Supabase handles chat/basic realtime; Liveblocks handles selected high-frequency collaborative canvases.

**Status:** Recommended.

## TECH-007 — React Flow for Structured Maps

Use React Flow for Mind Map/system node interfaces.

**Status:** Recommended.

## TECH-008 — OpenAI Behind Abstraction

Use OpenAI initially but never bind curriculum/business logic directly to model IDs.

**Status:** Required.

## TECH-009 — Daily for Video

Integrate live video rather than building WebRTC infrastructure.

**Status:** Recommended.

## TECH-010 — Vercel for MVP Deployment

Deploy Next.js to Vercel while preserving portability.

**Status:** Recommended.

## TECH-011 — Patent Search External First

Use external patent sources in MVP; build deeper integrations later.

**Status:** Required MVP approach.

## TECH-012 — No Heavy ORM Initially

Use SQL migrations + Supabase generated types and APIs initially.

**Status:** Recommended.

---

# 86. Current Official Research References

Research reviewed September 17, 2026:

### Next.js

`https://nextjs.org/docs`

`https://nextjs.org/support-policy`

`https://nextjs.org/blog`

Current Active LTS security release referenced during research: Next.js 16.3.3.

### Supabase

`https://supabase.com/pricing`

`https://supabase.com/docs/guides/database/postgres/row-level-security`

`https://supabase.com/docs/guides/realtime`

### Liveblocks

`https://liveblocks.io/pricing`

`https://liveblocks.io/docs/pricing/plans`

`https://liveblocks.io/docs/authentication/permissions`

### Daily

`https://www.daily.co/pricing/video-sdk/`

### React Flow

`https://reactflow.dev/`

### tldraw

`https://tldraw.dev/pricing`

### OpenAI API

`https://developers.openai.com/api/docs/models`

### Vercel

`https://vercel.com/pricing`

### Resend

`https://resend.com/pricing`

Because pricing, model names, limits, and product capabilities can change, these references must be checked again at implementation milestones.

---

# 87. Codex Technical Rules

Codex must:

1. Read `/docs` before implementing a feature.
2. Use TypeScript strict mode.
3. Preserve feature/module boundaries.
4. Use migrations for schema changes.
5. Implement RLS for protected tables.
6. Write permission tests.
7. Keep server secrets server-side.
8. Validate untrusted input.
9. Treat PostgreSQL as canonical project state.
10. Preserve immutable approved versions.
11. Keep AI provider logic behind abstraction.
12. Never let AI bypass permissions.
13. Use external infrastructure only behind FICI-owned business logic.
14. Add tests with each major feature.
15. Flag a documentation conflict before choosing a new business behavior.

Codex must not:

- create microservices prematurely,
- store canonical project state only in Liveblocks,
- put business-critical data only in Daily/OpenAI/Vercel,
- use public storage for confidential invention files,
- implement permission checks only in React components,
- use AI model output without runtime validation for structured writes,
- silently modify approved product requirements.

---

# 88. Next Document

The next document is:

# `11_API_CONTRACTS.md`

It should define the business operations Codex will implement, including:

- Authentication/session operations
- Team operations
- Workspace operations
- Development Project operations
- Activity operations
- Sharing
- Chat
- Artifact/version operations
- Evidence
- Patent Records
- Voting
- Decisions
- Review/approval
- AI task requests
- File operations
- audit behavior
- error contracts

After API Contracts, the final pre-coding document should be:

# `12_ACCEPTANCE_TESTS.md`

---

# End of Document

**Current Status:** Draft v0.1 — Ready for Ahmad/FICI review.  
**Next Document After Approval:** `11_API_CONTRACTS.md`
