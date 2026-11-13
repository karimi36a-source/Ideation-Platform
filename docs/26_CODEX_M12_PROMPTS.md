# FICI Invention Education & Development Platform
## Codex M12 Execution Prompts — Evidence, Files & Patent Workspace

**Document:** `26_CODEX_M12_PROMPTS.md`  
**Status:** Draft v0.1 — For Review  
**Depends on:** `01_PRODUCT_REQUIREMENTS.md` through `25_CODEX_M11_PROMPTS.md`  
**Purpose:** Provide exact copy/paste prompts for Codex to implement Milestone M12 safely and incrementally after M11 is complete.

---

# 1. Preconditions

Do not begin M12 until M11 is:

```text
IMPLEMENTED
→ TESTED
→ SECURITY-REVIEWED
→ COMMITTED
```

Required M11 state:

- Affinity works,
- Mind Map works,
- React Flow works,
- Liveblocks Team collaboration works,
- PostgreSQL remains canonical,
- Invention Structure V1 exists,
- Gap List exists,
- Invention Mind Map exists,
- Invention Concept V1 exists,
- AT-AFF tests pass,
- AT-MM tests pass,
- AT-CON-001 passes,
- Codex reports READY FOR M12.

If M11 is incomplete:

```text
STOP → FINISH M11 → REVIEW → COMMIT → BEGIN M12
```

Do not build evidence/patent workflows on top of unresolved Project/Artifact security defects.

---

# 2. M12 Goal

M12 adds evidence-backed invention research.

The target flow is:

```text
CURRENT INVENTION STRUCTURE
↓
PATENT LITERACY
↓
SEARCH
↓
SEARCH LOG
↓
RETAIN RELEVANT PATENTS
↓
PATENT RECORDS
↓
EVIDENCE RECORDS
↓
LINK EVIDENCE TO PROJECT ENTITIES
↓
COMPARE / ANALYZE
↓
IDENTIFY GAPS
```

The core rules are:

# SOURCE EVIDENCE ≠ ANALYSIS

# AI OUTPUT ≠ EVIDENCE

# PATENT RELEVANCE ≠ NOVELTY OR PATENTABILITY

# CONFIDENTIAL FILES MUST NEVER BECOME PUBLIC BY DEFAULT

---

# 3. M12 Product Boundary

M12 includes:

- `evidence`,
- `evidence_links`,
- `files`,
- `file_links`,
- private storage,
- signed temporary file access,
- `patent_records`,
- `patent_search_logs`,
- basic Patent Workspace,
- external source links,
- PATENTSCOPE links,
- USPTO links,
- Google Patents links,
- patent-to-evidence linkage,
- source/analysis separation,
- Evidence verification states,
- RLS/security,
- AT-EV acceptance tests,
- AT-PAT acceptance tests,
- AT-FILE acceptance tests,
- Session 8/9 integration.

M12 does **not** yet implement:

- AI Assistant,
- automated patentability conclusions,
- automated novelty conclusions,
- proprietary patent-search engine,
- claim-by-claim legal opinion,
- infringement opinion,
- validity opinion,
- general Sharing,
- external public publishing,
- full patent-comparison engine unless already approved as SHOULD-HAVE.

M14 owns AI assistance.

---

# 4. Evidence Principle

Evidence is a source-backed record.

Examples:

- patent,
- patent claim,
- standard,
- datasheet,
- paper,
- calculation,
- measurement,
- test result,
- customer interview,
- market source,
- secondary source.

Evidence must preserve:

```text
WHAT IS THE SOURCE?
WHAT TYPE OF EVIDENCE IS IT?
WHAT DOES IT SUPPORT / CONTRADICT / VALIDATE?
WHO CAPTURED IT?
WHEN?
HOW VERIFIED IS IT?
```

---

# 5. Evidence Schema

Implement:

```text
evidence
```

Fields:

- `id`
- `project_id`
- `workspace_id`
- `evidence_type`
- `title`
- `description`
- `source_name`
- `source_url`
- `file_id` nullable
- `verification_status`
- `verified_by` nullable
- `verified_at` nullable
- `created_by`
- `captured_at`
- `metadata`

Approved evidence types:

```text
PATENT
PATENT_CLAIM
STANDARD
DATASHEET
PAPER
CALCULATION
MEASUREMENT
TEST_RESULT
CUSTOMER_INTERVIEW
MARKET_SOURCE
SECONDARY_SOURCE
OTHER
```

---

# 6. Evidence Verification States

Approved states:

```text
UNVERIFIED
PARTIALLY_VERIFIED
VERIFIED
CONTRADICTED
NEEDS_REVIEW
```

Default on creation:

```text
UNVERIFIED
```

Never default new Evidence to VERIFIED.

---

# 7. Verification Principle

Verification state describes confidence/review status of the Evidence record.

It does not mean:

- legal validity,
- scientific certainty,
- patentability,
- market truth.

The role allowed to verify is explicitly not finalized in the API contract.

Therefore:

```text
DO NOT INVENT VERIFY AUTHORITY
```

If current approved role policy does not resolve it:

```text
STOP → FLAG → ASK
```

before implementing `verifyEvidence()` authorization.

---

# 8. Evidence Links

Implement:

```text
evidence_links
```

Fields:

- `id`
- `evidence_id`
- `linked_entity_type`
- `linked_entity_id`
- `relationship_type`
- `notes`

Relationship examples:

```text
SUPPORTS
CONTRADICTS
VALIDATES
SOURCE_FOR
RELATED_TO
```

AT-EV-003 requires Evidence to be linkable to:

- Decision,
- Requirement,
- Gap,
- Artifact,
- Patent Record.

Use stable entity IDs.

---

# 9. Source vs Analysis Separation

This distinction is fundamental.

Example:

```text
Patent Record
= source metadata

Evidence Record
= source-backed evidence

Patent Analysis
= human/AI interpretation
```

Do not merge them into one record.

A Patent Record may be linked to an Evidence Record.

A later AI analysis must remain separately labeled as AI analysis.

---

# 10. AI Output Is Not Evidence

AT-EV-002 is BLOCKER.

M12 must establish an explicit boundary:

```text
AI Output
≠
Evidence
```

Even before M14 exists, do not create database triggers or generic promotion behavior that automatically turns AI output into Evidence.

Later workflow may allow a human to:

```text
AI suggests source
↓
human opens real source
↓
human captures source as Evidence
```

That is different from AI output becoming evidence.

---

# 11. File Schema

Implement:

```text
files
```

Fields:

- `id`
- `uploaded_by`
- `workspace_id`
- `project_id` nullable
- `storage_reference`
- `filename`
- `mime_type`
- `size`
- `status`
- `created_at`

M12 now implements the storage behavior that the schema previously deferred.

---

# 12. File Links

Implement:

```text
file_links
```

Fields:

- `id`
- `file_id`
- `entity_type`
- `entity_id`
- `relationship_type`

Examples:

```text
ATTACHMENT
EVIDENCE_SOURCE
ARTIFACT_FILE
CHAT_ATTACHMENT
REFERENCE
```

One File may be connected to multiple authorized entities.

Linking a File does not transfer ownership or Workspace access.

---

# 13. Private Storage Principle

All confidential/user project files are private by default.

Never use a permanent public bucket URL for confidential project content.

Access flow:

```text
AUTHENTICATE
↓
AUTHORIZE FILE METADATA
↓
AUTHORIZE WORKSPACE / PROJECT / ENTITY
↓
ISSUE SHORT-LIVED SIGNED URL
↓
CLIENT DOWNLOAD / VIEW
```

The signed URL is temporary capability access.

---

# 14. Signed Access Principle

Approved contract:

```text
getFileAccess(input)
```

must return an authorized signed URL.

Direct public access must not bypass authorization.

AT-FILE-003 requires the temporary URL not to become permanent public access.

Signed URL expiration should be short and configurable.

Do not persist signed URLs as long-lived canonical metadata.

Persist only the storage reference.

---

# 15. Upload Flow

Approved contracts:

```text
requestUpload(input)
registerUploadedFile(input)
```

`requestUpload` input:

```text
workspaceId
projectId optional
filename
mimeType
size
```

Rules:

- validate authorization,
- validate file type,
- validate size,
- return upload target/signature.

`registerUploadedFile` creates canonical metadata only after successful upload.

---

# 16. Upload Security

The server must not trust:

- filename,
- MIME type,
- size,
- Workspace ID,
- Project ID,

without validation.

Recommended architecture:

```text
request upload
↓
authorized target generated
↓
client uploads to private storage
↓
server verifies upload exists / metadata is acceptable
↓
register canonical file row
```

Do not allow arbitrary client-selected storage paths that expose another Workspace.

---

# 17. File Privacy

Personal Workspace file:

```text
owner access only by default
```

Team Workspace file:

```text
authorized Team scope only
```

Removed Team member:

```text
future access revoked
```

File metadata itself must not leak sensitive filenames or storage references to unauthorized users.

---

# 18. Archive File

Approved:

```text
archiveFile(fileId)
```

Avoid destructive delete when the File supports:

- formal Evidence,
- Artifact,
- review,
- history.

Archiving must not silently break historical Evidence/Artifact references.

---

# 19. Patent Record Schema

Implement:

```text
patent_records
```

Fields:

- `id`
- `project_id`
- `workspace_id`
- `publication_number`
- `application_number`
- `title`
- `applicant`
- `inventor`
- `priority_date`
- `filing_date`
- `publication_date`
- `ipc_cpc`
- `source_database`
- `source_url`
- `abstract_text`
- `relevance_status`
- `why_retained`
- `created_by`

Patent Record is source metadata.

It is not a legal conclusion.

---

# 20. Patent Search Log Schema

Implement:

```text
patent_search_logs
```

Fields:

- `id`
- `project_id`
- `workspace_id`
- `activity_instance_id`
- `database_name`
- `query_text`
- `search_method`
- `reason`
- `searched_at`
- `searched_by`
- `results_reviewed_count`
- `relevant_results_count`
- `terms_learned`
- `classifications_learned`
- `notes`

This preserves the search process, not only the retained results.

---

# 21. Patent Sources

MVP may link users to:

```text
WIPO PATENTSCOPE
USPTO
Google Patents
```

M12 does not build a proprietary search engine.

The Patent Workspace should support:

- external links,
- saved Search Logs,
- saved Patent Records,
- notes,
- source Evidence,
- project links.

---

# 22. Session 8 Principle

Professional Session 8 teaches users to understand and navigate patent documents.

Input:

```text
Invention Concept V1
existing project structure
```

Learning areas include:

- IP types,
- WIPO/PCT,
- patent front page,
- title,
- abstract,
- description,
- claims,
- drawings,
- bibliographic information.

Platform requirements:

- patent reference materials,
- patent document viewer / links,
- structured Patent Reading framework,
- notes linked to patent sections.

Output:

```text
Patent Reading Framework / Reading Map
```

M12 should support the data/workspace foundation for this.

---

# 23. Session 9 Principle

Professional Session 9 goal:

```text
Build an evidence-based picture of what already exists
and identify potential technical gaps.
```

Approved workflow:

```text
Break Invention into Searchable Elements
↓
Build Keyword Families
↓
Broad Search
↓
Review Results
↓
Learn Terminology / IPC
↓
Refine Search
↓
Screen Results
↓
Retain Relevant Patent Set
↓
Read Relevant Patents
↓
Claim Analysis
↓
Architecture Analysis
↓
Problem–Solution Analysis
↓
Similarity / Difference Matrix
↓
Multi-Patent Comparison
↓
Gap Map
```

M12 implements the core source/evidence/search foundation.

Detailed comparison structures beyond approved M12 scope remain later/SHOULD-HAVE.

---

# 24. Patent Relevance Rule

Patent relevance labels are technical screening aids.

They do not establish:

- novelty,
- patentability,
- claim scope,
- infringement,
- validity.

The platform must not present relevance status as a legal conclusion.

---

# 25. Patent Search Strategy Support

Search Logs should support searching by:

- problem,
- function,
- component,
- mechanism,
- relationship,
- solution,
- classification.

Users may learn:

- new technical terms,
- IPC/CPC classifications,
- better query directions.

These should be recordable in the Search Log.

---

# 26. Patent Record vs Evidence

A Patent Record stores patent metadata.

A linked Evidence record may represent:

```text
this patent/source supports investigation of X
```

or:

```text
this claim is evidence relevant to Y
```

Do not make every Patent Record automatically VERIFIED Evidence.

`linkPatentToEvidence()` may create/link Evidence but should preserve source/verification semantics.

---

# 27. Basic Patent Workspace

M12 Patent Workspace should provide a basic research surface for:

- current Project context,
- external patent source links,
- Search Logs,
- retained Patent Records,
- Evidence linked to patents,
- notes/why retained,
- relevant Project Objects/Gaps.

It must not pretend to be a patent office search engine.

---

# 28. No Automated Patentability Conclusion

M12 must not generate:

```text
PATENTABLE
NOT PATENTABLE
NOVEL
NOT NOVEL
INFRINGEMENT
CLEAR TO OPERATE
VALID / INVALID
```

as system conclusions.

If a future AI tool analyzes patents, it must remain labeled analysis and not legal conclusion.

---

# 29. Source-of-Truth Files

Before each M12 task, Codex must read:

```text
/docs/03_ROLES_PERMISSIONS.md
/docs/04_WORKSPACE_TEAM_COLLABORATION.md
/docs/05_DEVELOPMENT_PROJECT_MODEL.md
/docs/06_COURSE_ACTIVITY_WORKFLOWS.md
/docs/07_MVP_SCOPE.md
/docs/08_DATA_MODEL_SCHEMA.md
/docs/10_TECHNICAL_ARCHITECTURE.md
/docs/11_API_CONTRACTS.md
/docs/12_ACCEPTANCE_TESTS.md
/docs/13_CODEX_IMPLEMENTATION_PLAN.md
/docs/20_CODEX_M6_PROMPTS.md
/docs/21_CODEX_M7_PROMPTS.md
/docs/22_CODEX_M8_PROMPTS.md
/docs/24_CODEX_M10_PROMPTS.md
/docs/25_CODEX_M11_PROMPTS.md
```

Also read approved Professional Course Session 8 and Session 9 materials.

---

# 30. Global Codex Header

Use this block at the beginning of every M12 task if project rules are not automatically retained:

```text
You are implementing the FICI Invention Education & Development Platform.

Before making changes:

1. Read the relevant /docs files and approved Session 8/9 curriculum.
2. Treat them as source of truth.
3. Do not invent missing business rules.
4. Evidence is source-backed data, not AI analysis.
5. New Evidence defaults to UNVERIFIED.
6. Patent Record is source metadata, not a patentability conclusion.
7. Patent relevance is not novelty/patentability.
8. Keep source, human analysis, AI analysis, and decisions separate.
9. All confidential files are private by default.
10. File download/view requires server authorization and short-lived signed access.
11. Never expose raw private storage paths as public URLs.
12. Preserve Workspace/Project/Team isolation.
13. Removed members lose future private Team file/evidence access.
14. Never trust client-provided uploader, creator, verifier, Project, Workspace, or storage path.
15. Use business operations and RLS.
16. Do not build a proprietary patent search engine.
17. Do not implement M13 Sharing or M14 AI early.
18. Use migrations for schema changes.
19. Use strict TypeScript.
20. Validate runtime input.
21. If requirements conflict or are ambiguous, STOP → FLAG → ASK.
22. Run required validation before finishing.
23. Report:
    - files changed,
    - migrations,
    - storage configuration,
    - signed-access behavior,
    - operations,
    - RLS,
    - evidence verification handling,
    - patent source handling,
    - tests,
    - results,
    - assumptions,
    - unresolved issues.
```

---

# 31. M12.1 — Evidence Schema

## Objective

Create source-backed Evidence Records.

## Copy/Paste Prompt

```text
TASK ID: M12.1
TASK: Evidence Schema

Read first:

- /docs/08_DATA_MODEL_SCHEMA.md
- /docs/05_DEVELOPMENT_PROJECT_MODEL.md

OBJECTIVE

Create `evidence`.

FIELDS

- id
- project_id
- workspace_id
- evidence_type
- title
- description
- source_name
- source_url
- file_id nullable
- verification_status
- verified_by nullable
- verified_at nullable
- created_by
- captured_at
- metadata

EVIDENCE TYPES

- PATENT
- PATENT_CLAIM
- STANDARD
- DATASHEET
- PAPER
- CALCULATION
- MEASUREMENT
- TEST_RESULT
- CUSTOMER_INTERVIEW
- MARKET_SOURCE
- SECONDARY_SOURCE
- OTHER

VERIFICATION STATES

- UNVERIFIED
- PARTIALLY_VERIFIED
- VERIFIED
- CONTRADICTED
- NEEDS_REVIEW

RULES

1. default verification_status = UNVERIFIED.
2. Project/Workspace must be compatible.
3. created_by server-derived.
4. verified_by/verified_at cannot be client-set on normal creation.
5. source_url optional when file/source data supports Evidence.
6. file_id must be authorized if present.
7. metadata cannot replace core typed fields.
8. archive rather than destructive delete.

TEST

- create each representative Evidence type.
- default UNVERIFIED.
- creator spoof denied.
- verified_by spoof denied.
- cross-Team Workspace denied.

DEFINITION OF DONE

Evidence has explicit source identity and verification state.
```

---

# 32. M12.2 — Evidence Links

## Objective

Link Evidence to meaningful Project entities.

## Copy/Paste Prompt

```text
TASK ID: M12.2
TASK: Evidence Links

Read first:

- /docs/08_DATA_MODEL_SCHEMA.md
- /docs/11_API_CONTRACTS.md
- /docs/12_ACCEPTANCE_TESTS.md

OBJECTIVE

Create `evidence_links` and implement `linkEvidence(input)`.

INPUT

evidenceId
entityType
entityId
relationshipType
notes optional

RELATIONSHIP TYPES

Use approved vocabulary such as:
- SUPPORTS
- CONTRADICTS
- VALIDATES
- SOURCE_FOR
- RELATED_TO

TARGETS REQUIRED BY AT-EV-003

- Decision
- Requirement
- Gap
- Artifact
- Patent Record

RULES

1. Evidence accessible.
2. target entity exists.
3. target entity accessible.
4. target belongs to compatible Project/scope.
5. link does not transfer ownership.
6. avoid duplicate identical active links where practical.
7. preserve link history.

TEST

AT-EV-003 targets.
Cross-Team target denied.
Unrelated Project target denied.

DEFINITION OF DONE

Evidence can explicitly support/contradict/validate persistent Project entities.
```

---

# 33. M12.3 — Create Evidence

## Objective

Implement `createEvidence(input)`.

## Copy/Paste Prompt

```text
TASK ID: M12.3
TASK: Create Evidence

Read first:

- /docs/11_API_CONTRACTS.md
- /docs/12_ACCEPTANCE_TESTS.md

INPUT

projectId
workspaceId
evidenceType
title
description
sourceName
sourceUrl optional
fileId optional

FLOW

1. authenticate actor.
2. authorize Project.
3. authorize Workspace.
4. validate Evidence type.
5. validate source URL if supplied.
6. validate File if supplied.
7. create Evidence.
8. force verificationStatus = UNVERIFIED.
9. set created_by server-side.
10. set captured_at.

DO NOT

- accept VERIFIED from client creation request.
- auto-create AI Output.
- infer legal/scientific truth.

TEST

AT-EV-001:
Evidence includes:
- source
- type
- title
- verification state
- link/file

Expected:
UNVERIFIED.

DEFINITION OF DONE

AT-EV-001 passes.
```

---

# 34. M12.4 — Verify Evidence

## Objective

Implement verification-state transitions only after role policy is resolved.

## Approved Contract

```text
verifyEvidence(input)
```

Input:

```text
evidenceId
verificationStatus
note optional
```

Must record verifier and timestamp.

## Copy/Paste Prompt

```text
TASK ID: M12.4
TASK: Verify Evidence

Read first:

- /docs/03_ROLES_PERMISSIONS.md
- /docs/11_API_CONTRACTS.md

OBJECTIVE

Implement controlled Evidence verification.

IMPORTANT

The API contract says verification authorization policy is to be finalized.

Before coding:
1. search current approved docs for verifier authority.
2. if unresolved:
   STOP → FLAG → ASK.
3. do NOT default to "any Master" or "creator can verify own Evidence".

IF POLICY IS RESOLVED

Implement:
- authorized state transition,
- verified_by server-derived,
- verified_at server-generated,
- optional verification note/history,
- change/audit record where required.

Do not erase previous verification history if status changes later.

TEST

- authorized verifier works.
- unauthorized user denied.
- client cannot spoof verified_by.
- verification state persists.

DEFINITION OF DONE

Evidence verification authority is explicit, not invented.
```

---

# 35. M12.5 — AI Is Not Evidence Boundary

## Objective

Implement AT-EV-002 structurally before M14 exists.

## Copy/Paste Prompt

```text
TASK ID: M12.5
TASK: AI Output Is Not Evidence Boundary

Read first:

- /docs/12_ACCEPTANCE_TESTS.md
- /docs/08_DATA_MODEL_SCHEMA.md

OBJECTIVE

Guarantee AI-like analysis records cannot automatically become Evidence.

VERIFY ARCHITECTURE

1. `evidence` is a distinct table/domain.
2. no generic trigger auto-creates Evidence from analysis text.
3. no "save AI analysis" operation routes directly to createEvidence().
4. future AI Output must require a separate human action to capture real source Evidence.
5. Evidence requires source_name and source-backed fields according to validation.

TEST

Use fixture representing analysis output.
Attempt to persist through any generic analysis save path.

Expected:
- no Evidence row appears automatically.

Priority:
BLOCKER.

DEFINITION OF DONE

AT-EV-002 passes.
```

---

# 36. M12.6 — File Schema & Private Storage

## Objective

Implement canonical file metadata and private storage.

## Copy/Paste Prompt

```text
TASK ID: M12.6
TASK: File Schema & Private Storage

Read first:

- /docs/08_DATA_MODEL_SCHEMA.md
- /docs/10_TECHNICAL_ARCHITECTURE.md
- /docs/11_API_CONTRACTS.md

OBJECTIVE

Create:
- files
- file_links

FILES

- id
- uploaded_by
- workspace_id
- project_id nullable
- storage_reference
- filename
- mime_type
- size
- status
- created_at

FILE_LINKS

- id
- file_id
- entity_type
- entity_id
- relationship_type

STORAGE

Use the approved private object-storage provider from technical architecture.
Bucket/container must not be publicly readable.

RULES

1. storage_reference is internal.
2. uploaded_by server-derived.
3. Workspace access required.
4. Project optional but validated if present.
5. no permanent public URL stored.
6. hard deletion restricted for formal history/evidence files.

TEST

- Personal File metadata.
- Team File metadata.
- direct public URL unavailable.
- storage path spoof blocked.

DEFINITION OF DONE

Confidential files have canonical metadata and private storage.
```

---

# 37. M12.7 — Request Upload / Register Upload

## Objective

Implement secure two-step file upload.

## Copy/Paste Prompt

```text
TASK ID: M12.7
TASK: Secure File Upload

Read first:

- /docs/11_API_CONTRACTS.md
- /docs/12_ACCEPTANCE_TESTS.md

IMPLEMENT

requestUpload(input)
registerUploadedFile(input)

REQUEST INPUT

workspaceId
projectId optional
filename
mimeType
size

REQUEST CHECKS

1. authenticated user.
2. Workspace access.
3. Project access if supplied.
4. filename safe.
5. MIME type allowed.
6. size within configured limit.
7. generate server-controlled storage path.
8. return short-lived upload target/signature.

REGISTER

1. verify expected upload exists.
2. verify path belongs to request/user/scope.
3. validate final metadata.
4. create canonical files row.
5. do not trust client to register arbitrary storage object.

SECURITY TEST

- A1 cannot request Team B target path.
- A1 cannot register B1's uploaded storage object.
- oversized/disallowed type rejected.
- uploader identity server-derived.

DEFINITION OF DONE

Upload flow cannot create cross-Workspace file references.
```

---

# 38. M12.8 — File Linking

## Objective

Connect one File to Evidence/Artifact/Activity/Chat/Project Object.

## Approved Contract

```text
linkFile(input)
```

## Copy/Paste Prompt

```text
TASK ID: M12.8
TASK: File Links

Read first:

- /docs/08_DATA_MODEL_SCHEMA.md
- /docs/11_API_CONTRACTS.md

SUPPORTED TARGETS

- evidence
- artifact
- activity
- chat
- project object

RELATIONSHIPS

- ATTACHMENT
- EVIDENCE_SOURCE
- ARTIFACT_FILE
- CHAT_ATTACHMENT
- REFERENCE

RULES

1. requester can access File.
2. requester can access target.
3. Workspace/Project scopes compatible.
4. linking does not broaden File access.
5. one File may have multiple links.
6. direct link ID must not bypass File security.

IMPORTANT

Existing Chat FILE message type does not mean File becomes public.
Chat attachment access still checks File authorization.

DEFINITION OF DONE

Files are reusable references without weakening privacy.
```

---

# 39. M12.9 — Signed File Access

## Objective

Implement `getFileAccess(input)` and AT-FILE security.

## Copy/Paste Prompt

```text
TASK ID: M12.9
TASK: Signed File Access

Read first:

- /docs/11_API_CONTRACTS.md
- /docs/12_ACCEPTANCE_TESTS.md

OBJECTIVE

Implement authorized temporary file download/view access.

FLOW

1. authenticate requester.
2. resolve File metadata.
3. authorize Workspace/Project/entity scope.
4. generate short-lived signed URL.
5. return URL + expiry metadata if API supports it.

DO NOT

- return raw permanent public URL.
- expose storage_reference to unauthorized users.
- cache signed URLs as permanent application data.

TEST

AT-FILE-001:
A1 Personal File.
A2 exact File ID/direct reference.
Expected DENIED.

AT-FILE-002:
Team A File.
Team B user denied.
Authorized Team A user allowed.

AT-FILE-003:
signed URL expires.
A previously issued URL does not become permanent public access.

Priority:
AT-FILE-001 / 002 = BLOCKER.

DEFINITION OF DONE

All AT-FILE tests pass.
```

---

# 40. M12.10 — Archive File

## Objective

Preserve formal history when archiving Files.

## Copy/Paste Prompt

```text
TASK ID: M12.10
TASK: Archive File

IMPLEMENT

archiveFile(fileId)

RULES

1. authorized actor only.
2. set archived/inactive status.
3. preserve metadata.
4. preserve file_links.
5. preserve Evidence history.
6. avoid physical deletion if File is required for formal Evidence/history.
7. future download may be restricted according to archive policy.

If physical-retention policy is undefined:
do not invent automatic deletion.

TEST

- archived Evidence File links remain.
- unauthorized archive denied.
- direct hard-delete unavailable to normal user.
```

---

# 41. M12.11 — Patent Record Schema

## Objective

Create durable metadata for retained patent documents.

## Copy/Paste Prompt

```text
TASK ID: M12.11
TASK: Patent Record Schema

Read first:

- /docs/08_DATA_MODEL_SCHEMA.md
- approved Session 8/9 curriculum

CREATE

patent_records

FIELDS

- id
- project_id
- workspace_id
- publication_number
- application_number
- title
- applicant
- inventor
- priority_date
- filing_date
- publication_date
- ipc_cpc
- source_database
- source_url
- abstract_text
- relevance_status
- why_retained
- created_by

RULES

1. Project/Workspace compatible.
2. created_by server-derived.
3. publication_number preserved as source metadata.
4. source_database required.
5. source_url validated.
6. relevance_status is technical research label only.
7. no novelty/patentability field is auto-populated as conclusion.

TEST

- PATENTSCOPE record.
- USPTO record.
- Google Patents record.
- creator spoof denied.
- Team B record inaccessible.

DEFINITION OF DONE

Relevant patent sources can be retained as structured Project research records.
```

---

# 42. M12.12 — Create Patent Record

## Objective

Implement `createPatentRecord(input)` and AT-PAT-001.

## Copy/Paste Prompt

```text
TASK ID: M12.12
TASK: Create Patent Record

Read first:

- /docs/11_API_CONTRACTS.md
- /docs/12_ACCEPTANCE_TESTS.md

INPUT

projectId
workspaceId
publicationNumber
applicationNumber optional
title
applicant optional
inventor optional
priorityDate optional
filingDate optional
publicationDate optional
ipcCpc optional
sourceDatabase
sourceUrl
abstractText optional
whyRetained optional

FLOW

1. authorize Project/Workspace.
2. validate source fields.
3. create Patent Record.
4. creator server-derived.
5. capture relevance/why retained only as research metadata.
6. do not generate legal conclusion.

AT-PAT-001

User can save:
- publication number
- title
- database/source
- URL
- notes/why retained
- relevance

Expected PASS.

DEFINITION OF DONE

AT-PAT-001 passes.
```

---

# 43. M12.13 — Patent Search Log

## Objective

Implement search-process history.

## Approved Contract

```text
createPatentSearchLog(input)
```

## Copy/Paste Prompt

```text
TASK ID: M12.13
TASK: Patent Search Log

Read first:

- /docs/11_API_CONTRACTS.md
- approved Session 9 curriculum
- /docs/12_ACCEPTANCE_TESTS.md

INPUT

projectId
workspaceId
activityInstanceId
databaseName
queryText
searchMethod
reason
resultsReviewedCount optional
relevantResultsCount optional
termsLearned optional
classificationsLearned optional
notes optional

FLOW

1. authorize Activity/Project/Workspace.
2. server sets searched_by.
3. server sets searched_at.
4. persist query/method/reason.
5. preserve learned terminology/classifications.
6. allow repeated searches; do not overwrite prior search history.

AT-PAT-003

Store:
- database
- query
- method
- date
- user
- notes

Expected PASS.

DEFINITION OF DONE

AT-PAT-003 passes and search evolution is traceable.
```

---

# 44. M12.14 — Patent → Evidence Link

## Objective

Implement `linkPatentToEvidence(input)` safely.

## Copy/Paste Prompt

```text
TASK ID: M12.14
TASK: Patent to Evidence Link

Read first:

- /docs/11_API_CONTRACTS.md
- /docs/08_DATA_MODEL_SCHEMA.md

OBJECTIVE

Create/link Evidence referencing a Patent Record.

RULES

1. Patent Record accessible.
2. Project/Workspace compatible.
3. resulting Evidence uses appropriate PATENT or PATENT_CLAIM type.
4. Evidence starts UNVERIFIED unless verification workflow says otherwise.
5. source_name/source_url reference real patent source.
6. create Evidence Link back to Patent Record where appropriate.
7. do not treat Patent Record relevance as verification.
8. do not treat Patent Record existence as proof of novelty.

TEST

- Patent Record → Evidence.
- Patent Claim Evidence.
- Team B Patent cannot become Team A Evidence.
- default UNVERIFIED.

DEFINITION OF DONE

Patent sources can participate in the generic Evidence model without semantic confusion.
```

---

# 45. M12.15 — Basic Patent Workspace

## Objective

Build the basic research workspace for Sessions 8 and 9.

## Copy/Paste Prompt

```text
TASK ID: M12.15
TASK: Basic Patent Workspace

Read first:

- approved Professional Session 8
- approved Professional Session 9
- /docs/06_COURSE_ACTIVITY_WORKFLOWS.md

OBJECTIVE

Create a basic Patent Workspace experience using existing platform primitives.

SURFACE

Show authorized:
- Project context,
- Invention Concept V1 references,
- Mind Map / Essential Structure references,
- external source links,
- Search Logs,
- retained Patent Records,
- Evidence linked to patents,
- why retained,
- relevance status,
- notes.

EXTERNAL SOURCES

Provide outbound links / source actions for:
- PATENTSCOPE
- USPTO
- Google Patents

DO NOT

- scrape/search all patent databases as proprietary engine,
- claim exhaustive search,
- declare novelty/patentability,
- mix AI Analysis into source metadata.

SESSION 8 SUPPORT

Patent-reading links/framework/notes.

SESSION 9 SUPPORT

Search Log + retained relevant Patent set + Evidence linkage.

DEFINITION OF DONE

Users can conduct and document an evidence-backed patent research workflow using external authoritative databases.
```

---

# 46. M12.16 — Patent Analysis Label Boundary

## Objective

Implement AT-PAT-002 structurally.

## Copy/Paste Prompt

```text
TASK ID: M12.16
TASK: Patent Source vs Analysis Boundary

Read first:

- /docs/12_ACCEPTANCE_TESTS.md
- approved Session 9/10 curriculum

OBJECTIVE

Ensure Patent Record stays source metadata.

If analysis exists now or test fixture simulates analysis:

- Patent Record = source
- Evidence = source-backed evidence
- human analysis = explicit analysis record/Artifact if approved
- AI analysis = future AI Output with visible/data label

DO NOT

- write AI-generated comparison into Patent Record as source fact.
- change abstract/source metadata based on AI interpretation.
- present AI interpretation as Evidence automatically.

AT-PAT-002

AI analysis remains labeled AI Analysis while Patent Record remains source/evidence metadata.

M14 will implement real AI Output behavior.
M12 must enforce the data-domain separation now.

Priority:
BLOCKER.

DEFINITION OF DONE

AT-PAT-002 architecture boundary passes.
```

---

# 47. M12.17 — Patent Comparison Boundary

## Objective

Handle `comparePatentWithProject(input)` without scope creep.

## Approved Contract

`comparePatentWithProject(input)` is SHOULD-HAVE.

May produce:

```text
structured comparison draft
or
AI task
```

but not legal conclusion.

## Copy/Paste Prompt

```text
TASK ID: M12.17
TASK: Patent Comparison Boundary

Read first:

- /docs/11_API_CONTRACTS.md
- /docs/08_DATA_MODEL_SCHEMA.md

OBJECTIVE

Implement only if M12 schedule/resources include SHOULD-HAVE patent comparison.

IF IMPLEMENTED

Use `patent_comparisons` as source-supported structured comparison record:
- project_id
- patent_record_id
- comparison_type
- summary
- created_by
- status

RULES

- label as analysis/comparison.
- do not present as legal conclusion.
- no auto-novelty/patentability.
- creator/provenance stored.
- Team/Project scope enforced.

IF NOT IMPLEMENTED

Keep API/service extension point and mark:
`DEFERRED — SHOULD-HAVE`.

Do not substitute an AI implementation before M14.
```

---

# 48. M12.18 — Decision Evidence Integration

## Objective

Complete the Evidence portion deferred from AT-DEC-001.

## Copy/Paste Prompt

```text
TASK ID: M12.18
TASK: Decision Evidence Integration

Read first:

- /docs/24_CODEX_M10_PROMPTS.md
- /docs/12_ACCEPTANCE_TESTS.md

OBJECTIVE

Allow finalized/new Decisions to link real Evidence Records.

RULES

1. Decision accessible.
2. Evidence accessible.
3. same compatible Project.
4. relationship explicit.
5. Evidence verification status visible.
6. unverified Evidence may be linked if policy permits, but must remain visibly UNVERIFIED.
7. linking does not auto-verify Evidence.

TEST

Complete AT-DEC-001 Evidence sub-check:
Decision stores/links:
- issue
- outcome
- reasoning
- participants
- linked Evidence
- timestamp.

DEFINITION OF DONE

AT-DEC-001 is now fully satisfied, including linked Evidence.
```

---

# 49. M12.19 — Evidence / Patent Activity Integration

## Objective

Integrate Sessions 8/9 research into M7 Activity Engine.

## Copy/Paste Prompt

```text
TASK ID: M12.19
TASK: Evidence & Patent Activity Integration

Read first:

- /docs/21_CODEX_M7_PROMPTS.md
- approved Session 8/9 workflow

SESSION 8

Input:
- Invention Concept V1
- Project structure

Output:
- Patent Reading Framework / Reading Map

SESSION 9

Inputs:
- Invention Concept V1
- Mind Map
- Minimum Essential Structure
- Problem/Solution structure
- Patent Reading Framework

M12 OUTPUT LINKS

Register:
- Patent Search Logs,
- Patent Records,
- Evidence Records,
- relevant Patent-set/landscape Artifact references where source model permits

as Activity Outputs/linked research records.

Do not duplicate records into Activity-specific copies.

DEPENDENCY

Session 10 should be able to consume authorized:
- Patent Landscape Snapshot,
- Search Log,
- Evidence,
- Gap-related outputs.

M14 later adds AI.

DEFINITION OF DONE

Patent research persists as Project-linked Activity output rather than browser-only work.
```

---

# 50. M12.20 — Evidence RLS

## Objective

Protect Evidence and Evidence Links directly in PostgreSQL.

## Copy/Paste Prompt

```text
TASK ID: M12.20
TASK: Evidence RLS

OBJECTIVE

Implement RLS for:
- evidence
- evidence_links

RULES

- access follows Project + Workspace.
- Personal Evidence private.
- Team A Evidence only authorized Team A/instructional scope.
- Team B denied.
- removed member denied future Team Evidence.
- linked target does not grant access if target itself inaccessible.
- direct Evidence ID cannot bypass.
- created_by server-controlled.
- verified_by/verified_at protected.
- ordinary user cannot self-verify if policy does not permit it.

ATTACKS

- Team B exact Evidence ID.
- link Team B Evidence to Team A Decision.
- spoof verifier.
- alter source fields of archived/formally used Evidence outside allowed edit policy.

DEFINITION OF DONE

Evidence cannot become a cross-scope information channel.
```

---

# 51. M12.21 — File RLS / Storage Security

## Objective

Protect file metadata and storage access.

## Copy/Paste Prompt

```text
TASK ID: M12.21
TASK: File RLS & Storage Security

OBJECTIVE

Protect:
- files
- file_links
- storage upload paths
- storage download access

RULES

1. File metadata follows Workspace/Project access.
2. Team B cannot SELECT Team A File row.
3. Team B cannot create signed URL for Team A file.
4. Student A2 cannot access A1 Personal File.
5. raw storage bucket/object is not public.
6. file_links cannot be used to escalate access.
7. removed Team member loses future signed access.
8. storage reference cannot be changed by normal client.

TEST

- direct DB metadata query
- guessed File ID
- guessed storage reference
- signed URL request
- File Link enumeration
- removed-member request

DEFINITION OF DONE

AT-FILE privacy is enforced through both metadata RLS and private storage configuration.
```

---

# 52. M12.22 — Patent RLS

## Objective

Protect Patent Records/Search Logs.

## Copy/Paste Prompt

```text
TASK ID: M12.22
TASK: Patent RLS

OBJECTIVE

Implement RLS for:
- patent_records
- patent_search_logs
- patent_comparisons if implemented

RULES

- Project + Workspace access required.
- Team B cannot read Team A retained patent research notes.
- Search Logs private to authorized scope.
- source URL itself may be public externally, but private notes/why_retained/search strategy remain protected.
- creator/searched_by identity server-derived.
- direct IDs do not bypass.

TEST

- Team B exact Patent Record ID denied.
- Team B Search Log query denied.
- removed member denied future Team research records.

DEFINITION OF DONE

Public patent sources do not make private Team research metadata public.
```

---

# 53. M12.23 — AT-EV-001 to 003

## Objective

Implement Evidence acceptance tests.

## Copy/Paste Prompt

```text
TASK ID: M12.23
TASK: Evidence Acceptance Tests

AT-EV-001 — Create Evidence

Create Evidence with:
- source
- type
- title
- verification state
- link/file

Expected:
UNVERIFIED by default.
PASS.

AT-EV-002 — AI Output Is Not Evidence

Use analysis fixture / future-domain boundary.
Verify no automatic Evidence creation.

Priority:
BLOCKER.

AT-EV-003 — Link Evidence

Link Evidence to:
- Decision
- Requirement
- Gap
- Artifact
- Patent Record

Expected:
PASS.

Also test Team/Workspace isolation.

FINAL REPORT

Return full test matrix.
```

---

# 54. M12.24 — AT-PAT-001 to 003

## Objective

Implement Patent acceptance tests.

## Copy/Paste Prompt

```text
TASK ID: M12.24
TASK: Patent Acceptance Tests

AT-PAT-001 — Save Patent Record

Save:
- publication number
- title
- database/source
- URL
- notes/why retained
- relevance

Expected PASS.

AT-PAT-002 — Patent Analysis Label

Source Patent Record remains source metadata.
Analysis remains separately labeled.

Priority:
BLOCKER.

AT-PAT-003 — Search Log

Store:
- database
- query
- method
- date
- user
- notes

Expected PASS.

Also verify:
- Team B denied.
- no automatic patentability/novelty conclusion.

FINAL REPORT

Return test matrix and boundary checks.
```

---

# 55. M12.25 — AT-FILE-001 to 003

## Objective

Implement secure-file acceptance tests.

## Copy/Paste Prompt

```text
TASK ID: M12.25
TASK: File Acceptance Tests

AT-FILE-001 — Private File

A1 uploads to Personal Workspace.
A2 attempts:
- metadata lookup
- File ID access
- signed URL request
- storage path access

Expected DENIED.
Priority BLOCKER.

AT-FILE-002 — Team File

Team A File accessible only to authorized Team A / authorized instructional roles.
Team B denied.

Priority BLOCKER.

AT-FILE-003 — Signed Access Expires

Issue temporary signed URL.
Verify:
- works during allowed lifetime,
- expires,
- raw object remains private,
- old signed URL not treated as permanent application link.

Expected PASS.

FINAL REPORT

Return attack matrix and PASS/FAIL.
```

---

# 56. M12.26 — Professional Session 8 Integration

## Objective

Validate the approved Patent Reading workflow.

## Copy/Paste Prompt

```text
TASK ID: M12.26
TASK: Professional Session 8 Integration

Read first:
- approved Professional Course Session 8
- /docs/06_COURSE_ACTIVITY_WORKFLOWS.md

SCENARIO

1. Session 8 receives Invention Concept V1.
2. learner opens structured Patent Reading Activity.
3. platform provides source/reference links.
4. learner opens a patent external/source link.
5. learner records notes on:
   - title
   - abstract
   - description
   - claims
   - drawings
   - bibliographic data
6. save Patent Reading Framework / Reading Map output.
7. preserve patent/source references.

VERIFY

- source material remains distinguishable from learner notes.
- no AI dependence required.
- no patentability conclusion generated.
- output can feed Session 9.

DEFINITION OF DONE

Session 8 patent literacy is supported without pretending to be automated patent analysis.
```

---

# 57. M12.27 — Professional Session 9 Integration

## Objective

Validate evidence-backed patent research workflow.

## Copy/Paste Prompt

```text
TASK ID: M12.27
TASK: Professional Session 9 Integration

Read first:
- approved Professional Course Session 9
- /docs/06_COURSE_ACTIVITY_WORKFLOWS.md

SCENARIO

1. consume:
   - Invention Concept V1
   - Mind Map
   - Minimum Essential Structure
   - Problem/Solution structure
   - Patent Reading Framework
2. define searchable invention elements.
3. open external patent source.
4. save Search Log.
5. review results.
6. save learned terms/classifications.
7. refine search.
8. retain relevant Patent Records.
9. record why retained / relevance.
10. create/link Evidence.
11. link Evidence to:
    - Gap
    - Requirement
    - Decision
    - Artifact
    as appropriate.
12. create/maintain Patent Landscape research outputs where approved.
13. prepare Session 10 inputs.

VERIFY

- search history preserved.
- Patent Record != analysis.
- Evidence default UNVERIFIED.
- no novelty/patentability conclusion.
- Team B denied private Team research notes.

DEFINITION OF DONE

Session 9 creates a traceable, evidence-backed patent research history.
```

---

# 58. M12.28 — Cross-Team Evidence/File/Patent Leakage Tests

## Objective

Attack M12 privacy boundaries.

## Copy/Paste Prompt

```text
TASK ID: M12.28
TASK: M12 Leakage Tests

FIXTURES

Team A:
- Evidence EA
- File FA
- Patent Record PA
- Search Log SLA

Team B:
- Student B1

ATTEMPTS AS B1

- exact Evidence ID
- Evidence Link list
- exact File ID
- getFileAccess(FA)
- raw storage reference
- file_links enumeration
- exact Patent Record ID
- Search Log ID/query
- link PA to Team B entity
- link Team A Evidence to Team B Decision
- direct DB SELECT

REMOVED TEAM A MEMBER

Attempt same future-access routes.

EXPECTED

All unauthorized access denied.

IMPORTANT

External patent source URL may itself be public.
Private Team metadata/notes/search strategy must remain private.

DEFINITION OF DONE

No M12 cross-Team private-data leakage remains.
```

---

# 59. M12.29 — M12 Security & Integrity Hardening

## Objective

Review M12 before Sharing and AI are added.

## Copy/Paste Prompt

```text
TASK ID: M12.29
TASK: M12 Security & Integrity Hardening

Read first:

- /docs/03_ROLES_PERMISSIONS.md
- /docs/04_WORKSPACE_TEAM_COLLABORATION.md
- /docs/05_DEVELOPMENT_PROJECT_MODEL.md
- /docs/06_COURSE_ACTIVITY_WORKFLOWS.md
- /docs/08_DATA_MODEL_SCHEMA.md
- /docs/10_TECHNICAL_ARCHITECTURE.md
- /docs/11_API_CONTRACTS.md
- /docs/12_ACCEPTANCE_TESTS.md
- /docs/13_CODEX_IMPLEMENTATION_PLAN.md
- /docs/24_CODEX_M10_PROMPTS.md
- /docs/25_CODEX_M11_PROMPTS.md
- /docs/26_CODEX_M12_PROMPTS.md

VERIFY

1. Evidence defaults UNVERIFIED.
2. Evidence type controlled.
3. Evidence links enforce scope.
4. AI output cannot become Evidence automatically.
5. Patent Record remains source metadata.
6. Patent relevance not presented as novelty/patentability.
7. Patent Search Logs preserve query history.
8. Files stored privately.
9. no permanent public file URL.
10. signed access short-lived and authorized.
11. Personal File privacy works.
12. Team File isolation works.
13. removed member loses future Team file/evidence access.
14. source URL/public patent source does not expose private research metadata.
15. no M13 Sharing implemented early.
16. no M14 AI implemented early.
17. no automated legal conclusion.

RUN

pnpm lint
pnpm typecheck
pnpm test:unit
pnpm test:integration
pnpm test:e2e
pnpm build
plus RLS/storage-security tests.

DEFINITION OF DONE

- AT-EV-001 PASS
- AT-EV-002 PASS
- AT-EV-003 PASS
- AT-PAT-001 PASS
- AT-PAT-002 PASS
- AT-PAT-003 PASS
- AT-FILE-001 PASS
- AT-FILE-002 PASS
- AT-FILE-003 PASS
- Session 8 integration PASS
- Session 9 integration PASS
- AT-DEC-001 Evidence sub-check PASS
- zero known private file leak
- zero known source/analysis confusion
- no M13/M14 scope creep

FINAL REPORT

Return:
1. security review
2. data-integrity review
3. storage review
4. patent-source boundary review
5. issues found
6. issues fixed
7. remaining issues
8. BLOCKER status
9. tests/results
10. recommendation: READY FOR M13 or NOT READY FOR M13
```

---

# 60. Evidence vs Project Object

Evidence and Development Objects are distinct.

Example:

```text
Requirement R1
← SUPPORTED BY ←
Evidence E1
```

Do not embed all evidence inside Requirement metadata.

Use explicit Evidence Link.

---

# 61. Evidence vs Artifact

An Artifact may summarize or present Evidence.

Evidence remains its own source-backed entity.

Artifact approval does not automatically verify Evidence.

---

# 62. Evidence vs Decision

A Decision may link Evidence.

A Decision being finalized does not change Evidence verification state.

---

# 63. Evidence vs Patent Record

Patent Record:

```text
bibliographic/source metadata
```

Evidence:

```text
source-backed record used in project reasoning
```

One Patent Record may support multiple Evidence Records/links where appropriate.

---

# 64. Source URL vs File

An Evidence record may use:

- external URL,
- uploaded File,
- or both.

Do not require File upload when authoritative external source link is sufficient.

---

# 65. External Link Safety

External Patent URLs may be opened in browser.

Validate schemes and avoid unsafe URL handling.

Do not proxy external content into private storage automatically unless explicitly requested/approved.

---

# 66. Search Log Is Historical

Do not update old Search Log query to represent a new search.

Create a new Search Log entry.

This preserves:

```text
Broad Search
→ Learned Terms
→ Refined Search
→ Classification Search
```

---

# 67. Relevant Patent Set

Relevant Patent Set may be represented by:

- Patent Records with relevance metadata,
- Artifact/structured output if defined,
- Activity outputs.

Do not create a legal-status implication from retention.

---

# 68. Patent Screening Labels

Course materials use labels such as:

- Not Relevant,
- Possibly Relevant,
- Relevant,
- Highly Relevant.

These describe technical relevance for further analysis.

They do not establish legal conclusions.

If exact enum is not approved in schema:

```text
STOP → FLAG → ASK
```

before hard-coding permanent values.

---

# 69. IPC/CPC

Patent Record supports:

```text
ipc_cpc
```

Search Log supports:

```text
classifications_learned
```

Do not assign meanings to classification codes without verified source.

The platform records what users found/used.

---

# 70. Patent Notes

`why_retained` and Search Log notes are team research metadata.

Even though the external patent is public, these notes can be confidential Project information.

Protect them with Workspace/Project security.

---

# 71. File Link Does Not Share Workspace

A File linked to an entity does not automatically grant access to the entity's audience unless File authorization resolves that link safely.

M13 Sharing later must explicitly define cross-Workspace File behavior.

Do not pre-implement it.

---

# 72. Signed URL Revocation Limitation

A signed URL may remain usable until expiration after it is issued.

Therefore:

- use short expiration,
- do not issue unnecessarily long URLs,
- check authorization before each new URL,
- revocation prevents future URL issuance.

Do not promise instant invalidation of already-issued signed URLs unless storage provider supports it and implementation uses it.

---

# 73. File MIME / Size Policy

Exact allowed types and size limits may be product/config decisions.

Do not silently hard-code arbitrary restrictive limits if not documented.

Create configurable validation.

Unsafe executable/content types may be restricted based on technical/security policy.

If product-facing limits are needed:

```text
FLAG → ASK
```

---

# 74. Virus/Malware Scanning

If file scanning is not included in approved architecture, do not claim it exists.

Leave an extension point if appropriate.

Do not block M12 completion on invented scanning infrastructure unless security requirements require it.

---

# 75. Patent Comparison

`patent_comparisons` is marked future/SHOULD-HAVE.

M12 core Definition of Done does not require a full comparison engine.

Prioritize:

```text
Search Log
Patent Record
Evidence
Links
Files
Security
```

---

# 76. Patent Landscape Snapshot

Session 9 outputs Patent Landscape Snapshot composed from multiple research artifacts.

M12 should support the underlying records and Artifact integration.

Do not reduce the entire landscape to one AI-generated paragraph.

---

# 77. Session 10 Boundary

Session 10 uses:

- Patent Landscape Snapshot,
- Search Log,
- Evidence Sheets,
- Claim Maps,
- Architecture Maps,
- Similarity/Difference Matrix,
- Gap Map.

M12 prepares source/evidence data.

M14 later adds AI-assisted synthesis/refinement.

---

# 78. Audit / Change Log

Recommended events:

```text
EVIDENCE_CREATED
EVIDENCE_VERIFIED
EVIDENCE_ARCHIVED
FILE_UPLOADED
FILE_LINKED
FILE_ARCHIVED
PATENT_RECORD_CREATED
PATENT_SEARCH_LOG_CREATED
```

Do not put confidential File URLs or full Evidence contents in broad audit metadata.

---

# 79. M12 Expected Repository Additions

Conceptually:

```text
features/
├── evidence/
│   ├── operations/
│   ├── verification/
│   ├── links/
│   └── access/
├── files/
│   ├── upload/
│   ├── access/
│   ├── links/
│   └── validation/
└── patents/
    ├── records/
    ├── search-log/
    ├── workspace/
    ├── evidence/
    └── access/

lib/
├── permissions/
│   ├── evidence.ts
│   ├── file.ts
│   └── patent.ts
├── storage/
│   ├── upload.ts
│   └── signed-access.ts
└── source-integrity/

supabase/
├── migrations/
│   ├── ...evidence...
│   ├── ...evidence_links...
│   ├── ...files...
│   ├── ...file_links...
│   ├── ...patent_records...
│   ├── ...patent_search_logs...
│   └── ...m12_rls...
└── tests/
    └── rls/
        ├── evidence...
        ├── files...
        └── patents...

tests/
├── unit/
│   ├── evidence/
│   ├── files/
│   └── patents/
├── integration/
│   ├── evidence/
│   ├── file-storage/
│   ├── session8/
│   └── session9/
└── e2e/
    └── patent-research.spec.ts
```

Exact paths may vary.

---

# 80. M12 Completion Gate

M12 is complete only when:

```text
[ ] evidence exists
[ ] evidence_links exists
[ ] Evidence defaults UNVERIFIED
[ ] approved Evidence types supported
[ ] Evidence verification states supported
[ ] createEvidence() implemented
[ ] linkEvidence() implemented
[ ] archiveEvidence() implemented
[ ] verifyEvidence() implemented only if authority policy resolved

[ ] AI Output cannot auto-create Evidence

[ ] files exists
[ ] file_links exists
[ ] private storage configured
[ ] requestUpload() implemented
[ ] registerUploadedFile() implemented
[ ] linkFile() implemented
[ ] getFileAccess() implemented
[ ] archiveFile() implemented
[ ] no permanent public confidential URL
[ ] signed access expires

[ ] patent_records exists
[ ] patent_search_logs exists
[ ] createPatentRecord() implemented
[ ] createPatentSearchLog() implemented
[ ] linkPatentToEvidence() implemented
[ ] basic Patent Workspace exists
[ ] PATENTSCOPE external link supported
[ ] USPTO external link supported
[ ] Google Patents external link supported

[ ] Patent Record remains source metadata
[ ] Patent Analysis remains separate
[ ] no automated novelty/patentability conclusion

[ ] Decision → Evidence integration works

[ ] Session 8 integration PASS
[ ] Session 9 integration PASS

[ ] AT-EV-001 PASS
[ ] AT-EV-002 PASS
[ ] AT-EV-003 PASS

[ ] AT-PAT-001 PASS
[ ] AT-PAT-002 PASS
[ ] AT-PAT-003 PASS

[ ] AT-FILE-001 PASS
[ ] AT-FILE-002 PASS
[ ] AT-FILE-003 PASS

[ ] lint passes
[ ] typecheck passes
[ ] unit tests pass
[ ] integration tests pass
[ ] E2E tests pass
[ ] RLS tests pass
[ ] storage-security tests pass
[ ] build passes

[ ] no M13 Sharing implemented prematurely
[ ] no M14 AI implemented prematurely
[ ] Codex reports READY FOR M13
```

Any private File exposure is:

```text
BLOCKER
```

Any automatic AI → Evidence conversion is:

```text
BLOCKER
```

Any system-generated patentability/novelty conclusion in M12 is:

```text
PRODUCT / LEGAL-SAFETY DEFECT
```

---

# 81. Recommended Commit Sequence

Example:

```text
feat(evidence): add Evidence schema and links
feat(evidence): add create/link/archive operations
feat(files): add private File metadata and links
feat(storage): add secure upload registration
feat(storage): add signed File access
feat(files): add archive behavior
feat(patents): add Patent Record schema
feat(patents): add Patent Search Log
feat(patents): add patent-to-evidence linking
feat(patents): add basic Patent Workspace
feat(decisions): add Evidence link integration
feat(activities): integrate Session 8/9 research outputs
feat(security): add Evidence/File/Patent RLS
test(evidence): add AT-EV suite
test(patents): add AT-PAT suite
test(files): add AT-FILE suite
test(session8): add Patent Reading integration
test(session9): add Patent Search integration
test(security): add M12 leakage tests
chore(security): complete M12 hardening
```

---

# 82. M12 Non-Goals

Do not accept these as "helpful additions" during M12:

- AI Assistant,
- automated patent search bot,
- proprietary patent database,
- patentability scoring,
- novelty scoring,
- infringement scoring,
- legal opinion generator,
- generic Sharing,
- cross-Team evidence sharing,
- automatic patent comparison by AI,
- automatic source verification,
- public file bucket,
- permanent signed download links,
- email/file-distribution system.

---

# 83. Potential M12 Ambiguities Codex Must Flag

Do not silently decide if approved docs do not resolve:

- who may verify Evidence,
- whether creator may verify own Evidence,
- whether verification requires Master/Mentor/expert,
- exact verification transition rules,
- whether verification history needs separate table,
- exact Evidence editability after verification,
- exact Evidence archive/restore policy,
- allowed upload MIME types,
- maximum file size,
- signed URL lifetime,
- whether archived File remains downloadable,
- physical file retention policy,
- whether malware scanning is required,
- exact patent relevance status values,
- whether Patent Records should deduplicate by publication number per Project,
- whether same patent can be saved in multiple Workspaces,
- whether Search Log may be edited after capture,
- whether retained Patent Record automatically creates Evidence,
- whether Claim-level Evidence requires a dedicated claim locator field,
- exact Patent Reading Framework storage model,
- exact Artifact type for Patent Landscape Snapshot if enum differs,
- whether `patent_comparisons` should be implemented in M12 pilot,
- whether Session 9 requires a minimum retained patent count,
- whether external source URL validation uses allowlist or generic HTTPS,
- whether File link to shared future entity should grant File access after M13.

If unresolved:

```text
STOP → FLAG → ASK
```

---

# 84. Recommended Safe Defaults for Purely Technical Decisions

Only where they do not alter approved product policy:

- UUID IDs,
- Evidence defaults UNVERIFIED,
- server-derived creators/verifiers,
- private storage bucket,
- short-lived signed URLs,
- storage path generated server-side,
- no public raw storage reference,
- archive over hard delete,
- search logs append-only/history-oriented,
- source Patent Record separated from analysis,
- source URL validated as HTTPS where appropriate,
- cross-Team access fails closed,
- no automatic patentability/novelty conclusion,
- M13/M14 extension points preserved.

---

# 85. Review Checklist for Ahmad/FICI

Before implementation, confirm M12 reflects the intended research model:

```text
1. Evidence is separate from analysis.

2. New Evidence starts UNVERIFIED.

3. Evidence can support/contradict/validate Project entities.

4. Evidence can link to Decisions, Requirements, Gaps, Artifacts and Patents.

5. AI output never automatically becomes Evidence.

6. Files are private.

7. Personal File cannot be downloaded by another student.

8. Team File cannot be downloaded by another Team.

9. File access uses temporary signed URLs.

10. Patent Record stores source metadata.

11. Patent Search Log records how the team searched.

12. PATENTSCOPE, USPTO and Google Patents are external sources, not replaced by our own search engine.

13. Patent relevance is not a novelty/patentability conclusion.

14. Session 8 teaches patent reading.

15. Session 9 records search, retained patents and evidence.

16. Session 10 can later consume this evidence/research.

17. AI remains M14.

18. General Sharing remains M13.
```

---

# 86. Next File After M12

After M12 has actually been:

```text
IMPLEMENTED
→ TESTED
→ SECURITY-REVIEWED
→ COMMITTED
```

create:

# `27_CODEX_M13_PROMPTS.md`

M13 will cover:

```text
Shares
Share Snapshots
Personal → Team
Team → Master
Optional Team → Team
VIEW
COMMENT
SNAPSHOT
LIVE_REFERENCE if approved
Revoke
Share History
Object-Level Access
Cross-Team Leakage Protection
```

M13 will finally implement the intentional cross-Workspace sharing model that earlier milestones deliberately deferred.

---

# 87. Final Execution Rule

For M12:

```text
EVIDENCE SCHEMA
→ EVIDENCE LINKS
→ CREATE EVIDENCE
→ VERIFY BOUNDARY
→ AI/EVIDENCE SEPARATION
→ FILE SCHEMA
→ PRIVATE UPLOAD
→ FILE LINKS
→ SIGNED ACCESS
→ ARCHIVE
→ PATENT RECORDS
→ SEARCH LOG
→ PATENT/EVIDENCE LINK
→ BASIC PATENT WORKSPACE
→ SOURCE/ANALYSIS BOUNDARY
→ DECISION EVIDENCE
→ ACTIVITY INTEGRATION
→ RLS
→ ACCEPTANCE TESTS
→ SESSION 8/9 E2E
→ SECURITY HARDENING
```

Do not skip directly to Sharing or AI.

---

# End of Document

**Current Status:** Draft v0.1 — Ready for Ahmad/FICI review.  
**Execution Step After M11 Completion:** Start with **M12.1 — Evidence Schema**.
