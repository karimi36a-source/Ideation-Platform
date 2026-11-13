# FICI Invention Education & Development Platform
## Development Project Model

**Document:** 05_DEVELOPMENT_PROJECT_MODEL.md  
**Status:** Draft v0.1 — For Review  
**Depends on:** `01_PRODUCT_REQUIREMENTS.md`, `02_PLATFORM_ARCHITECTURE.md`, `03_ROLES_PERMISSIONS.md`, `04_WORKSPACE_TEAM_COLLABORATION.md`  
**Purpose:** Define the structured project model that represents how a project evolves from problem and invention development through product, validation, business, market, team, finance, pitch, and funding stages.

---

# 1. Purpose

The Development Project is the persistent core of the FICI platform.

It must survive across:

- Workshop,
- Professional Course,
- Advanced Course,
- future Specialized Programs,
- mentoring,
- acceleration,
- and later project development.

This document defines the conceptual project objects and relationships that Codex and later technical architecture must implement.

It does **not** define database tables yet.

---

# 2. Core Principle

The project must not be represented as:

```text
Project
└── Files
```

Instead, it should be represented as a connected development model:

```text
Project
├── Problems
├── Ideas
├── Solutions
├── Features
├── Functions
├── Components
├── Requirements
├── Risks
├── Evidence
├── Patents
├── Gaps
├── Tests
├── Decisions
├── Versions
└── Development History
```

Files may support these objects, but files are not the project model.

---

# 3. Top-Level Development Project

Each Development Project should have at least:

- Project ID
- Project Name
- Project Description
- Project Type
- Owner
- Owning Workspace
- Team, if applicable
- Created Date
- Current Stage
- Current Status
- Current Approved Baseline
- Associated Programs
- Associated Cohorts
- Project Members
- Visibility
- Archived State
- Development Domains
- Activity History
- Version History
- Decision History
- Evidence Links

---

# 4. Development Project Types

The platform should support:

## 4.1 Individual Project

Owned by one user.

May later become a team project.

## 4.2 Team Project

Owned operationally by a team.

Contains contributions from multiple members.

## 4.3 Instructor Case Study Project

Owned by Master / Instructor.

Used for teaching demonstrations.

## 4.4 Future Organization Project

Potential future project type for university, company, accelerator, or R&D use.

Not required in MVP.

---

# 5. Development Domains

Each Development Project may contain multiple domains.

Recommended domains:

1. Invention
2. Evidence & IP
3. Product Development
4. Validation
5. Business & Market
6. Team & Execution
7. Finance
8. Pitch & Funding

These domains organize the project but do not create hard silos.

Objects may connect across domains.

---

# 6. Object Model Philosophy

Important project information should be stored as structured objects whenever the platform needs to:

- search it,
- compare it,
- version it,
- connect it,
- use it in AI context,
- trace decisions,
- review it,
- reuse it in later sessions.

Each object should have:

- stable ID,
- type,
- title/label,
- description/content,
- creator,
- owning workspace,
- project,
- created time,
- updated time,
- status,
- verification state where relevant,
- links to related objects,
- version reference where relevant,
- source/origin,
- permissions.

---

# 7. Core Invention Objects

## 7.1 Problem

Represents a problem, unmet need, limitation, weakness, or challenge.

Fields may include:

- Problem ID
- Statement
- Description
- Category
- Perspective
- Source
- Priority
- Status
- Related Solution(s)
- Related Evidence
- Related Gap
- Related Decision
- Related Version

Possible categories:

- User
- Function
- Technical
- Cost
- Safety
- Environment
- Accessibility
- Maintenance
- Market
- Manufacturing
- Other

---

## 7.2 Idea

Represents an early concept or possibility.

Fields may include:

- Idea ID
- Name
- Description
- Creator
- Origin
- Technique Used
- Workspace
- Related Problem
- Status
- Shared State
- Acceptance State
- Related Solution
- Related AI Output

Possible states:

- Private
- Shared
- Candidate
- Accepted
- Rejected
- Archived

---

## 7.3 Solution

Represents a proposed way to solve one or more problems.

Fields:

- Solution ID
- Description
- Mechanism
- Related Problem(s)
- Related Idea(s)
- Benefits
- Risks
- Status
- Evidence
- Related Feature(s)
- Related Function(s)
- Related Component(s)
- Verification State
- Decision State

---

## 7.4 Feature

Represents a characteristic or capability of the invention/product.

Fields:

- Feature ID
- Name
- Description
- Purpose
- Related Problem
- Related Solution
- Related Function
- Related Component
- Essentiality
- Status
- Evidence
- Version

Essentiality values may include:

- Core
- Supporting
- Optional / Future

---

## 7.5 Function

Represents what the invention or product must do.

Fields:

- Function ID
- Name
- Description
- Trigger/Input
- Output/Result
- Related Solution
- Related Feature
- Related Component
- Related Requirement
- Status

---

## 7.6 Component

Represents a physical, digital, logical, or process element.

Fields:

- Component ID
- Name
- Type
- Description
- Function(s)
- Parent System
- Parent Subsystem
- Connections
- Dependencies
- Risks
- Evidence
- Status
- Version

---

## 7.7 System

Represents a major system within the invention.

Fields:

- System ID
- Name
- Purpose
- Subsystems
- Components
- Functions
- Inputs
- Outputs
- Relationships
- Status

---

## 7.8 Subsystem

Represents a structured sub-area inside a System.

Fields:

- Subsystem ID
- Name
- Parent System
- Purpose
- Components
- Functions
- Connections
- Status

---

## 7.9 Relationship

Represents a structured connection between two objects.

Examples:

- Problem solved by Solution
- Solution delivered through Function
- Function implemented by Component
- Component belongs to Subsystem
- System depends on System
- Evidence supports Decision
- Risk affects Requirement
- Patent overlaps Component

Relationship fields:

- Relationship ID
- Source Object
- Target Object
- Relationship Type
- Description
- Direction
- Status
- Created By
- Evidence Reference if applicable

---

# 8. SCAMPER-Specific Object Support

SCAMPER may create structured Idea objects.

Each SCAMPER result may include:

- Technique
- Original Element
- Change Applied
- Result
- Related Problem
- Related Idea
- User
- Workspace
- Session
- Status

Technique values:

- Substitute
- Combine
- Adapt
- Modify
- Put to Another Use
- Eliminate
- Reverse / Rearrange

---

# 9. Problem Bank

Problem Bank is a structured Artifact containing Problem objects.

It should not be only free text.

A Problem Bank may include:

- list of Problems,
- categories,
- priorities,
- source activity,
- contributors,
- status,
- version,
- instructor feedback.

---

# 10. Solution Bank

Solution Bank is a structured Artifact containing Solution objects.

May include:

- linked Problem,
- solution options,
- origin,
- contributor,
- method used,
- status,
- votes,
- selection result,
- version.

---

# 11. Decision Object

A Decision is a first-class project object.

Fields:

- Decision ID
- Question / Issue
- Options
- Participants
- Method
- Votes
- Concerns
- Evidence
- Reasoning
- Outcome
- Decision Owner
- Date
- Affected Objects
- Affected Artifact
- Status
- Reversal / Supersession Link

Possible methods:

- Team Discussion
- Dot Voting
- Fist to Five
- Planning Poker
- Instructor Approval
- Go / Modify / Stop
- Expert Review

---

# 12. Requirement Object

A Requirement represents something the invention/product must satisfy.

Fields:

- Requirement ID
- Statement
- Type
- Source
- Priority
- Validation Method
- Status
- Related Risk
- Related Function
- Related Component
- Related Test
- Related Evidence

Possible types:

- Functional
- Technical
- Safety
- User
- Manufacturing
- Regulatory
- Cost
- Performance
- Environmental
- Business
- Other

---

# 13. Assumption Object

Represents something currently believed but not yet verified.

Fields:

- Assumption ID
- Statement
- Source
- Impact
- Confidence
- Validation Plan
- Status
- Related Requirement
- Related Risk
- Related Test
- Evidence

Possible status:

- Unverified
- Under Investigation
- Supported
- Rejected
- Modified

---

# 14. Constraint Object

Represents a limitation or boundary.

Examples:

- cost ceiling,
- size,
- power,
- regulation,
- material,
- manufacturing process,
- user environment.

Fields:

- Constraint ID
- Type
- Statement
- Source
- Severity
- Related Requirements
- Related Components
- Status

---

# 15. Risk Object

Fields:

- Risk ID
- Description
- Category
- Cause
- Impact
- Likelihood
- Severity
- Mitigation
- Owner
- Status
- Related Requirement
- Related Component
- Related Test
- Related Evidence

Possible categories:

- Technical
- Safety
- Cost
- Schedule
- Manufacturing
- Market
- Team
- Regulatory
- IP
- Financial

---

# 16. Gap Object

Gap represents something missing, unresolved, weak, uncertain, or potentially differentiating.

Fields:

- Gap ID
- Description
- Gap Type
- Source
- Related Problem
- Related Patent
- Related Architecture Element
- Verification Needed
- Status
- Candidate Solution
- Decision

Gap types may include:

- Missing Solution
- Missing Function
- Missing Component
- Missing Connection
- Patent Gap
- Technical Gap
- Evidence Gap
- Market Gap
- Knowledge Gap

---

# 17. Open Question Object

Represents an unresolved question requiring further action.

Fields:

- Question ID
- Question
- Category
- Related Object
- Priority
- Required Next Action
- Owner
- Status

Possible next actions:

- Search
- Analyze
- Calculate
- Test
- Ask Expert
- Ideate
- Discuss
- Verify

---

# 18. Evidence Object

Evidence must be first-class.

Fields:

- Evidence ID
- Type
- Title
- Source
- Original Source Link/File
- Extracted Information
- Verification State
- Added By
- Date
- Related Objects
- Related Decision
- Related AI Analysis
- Notes

Evidence types:

- Patent
- Patent Claim
- Standard
- Datasheet
- Paper
- Calculation
- Measurement
- Test Result
- Customer Interview
- Market Source
- Verified Secondary Source

---

# 19. Patent Object

Represents a patent document used in research.

Fields may include:

- Patent ID
- Publication Number
- Application Number
- Title
- Applicant
- Inventor
- Filing Date
- Priority Date
- Publication Date
- IPC/CPC
- Source Database
- Document Link
- Relevance
- Why Retained
- Related Search
- Related Evidence
- Related Claim Map
- Related Architecture Map
- Related Gaps

---

# 20. Patent Search Record

Represents one search action.

Fields:

- Search ID
- Query
- Search Method
- Database
- Reason for Search
- Search Direction
- Date
- User
- Results Reviewed
- Relevant Results
- Terms Learned
- IPC/CPC Learned
- Notes
- Next Search

Search method examples:

- Keyword
- Phrase
- Boolean
- Field
- Classification
- Applicant
- Inventor
- Number

---

# 21. Claim Analysis Object

Represents structured analysis of patent claims.

Fields:

- Claim Analysis ID
- Patent
- Claim Number
- Claim Type
- Limitations
- Comparison to Project
- Similarities
- Differences
- Not Identified Items
- Analyst Notes
- Evidence References

---

# 22. Architecture Map Object

Represents components and relationships reconstructed from:

- user's invention,
- patent,
- product,
- technical source.

Fields:

- Architecture Map ID
- Source
- Nodes
- Relationships
- Functional Paths
- Notes
- Version

---

# 23. Problem–Solution Map

Represents:

```text
Problem
→ Solution
→ Components
→ Relationships
→ Mechanism
→ Technical Result
```

Can be used for both:

- project,
- patent comparison.

---

# 24. Similarity / Difference Matrix

Structured comparison Artifact.

May compare:

- project vs patent,
- project vs multiple patents,
- version vs version,
- solution vs solution.

Comparison dimensions may include:

- Problem
- Solution
- Component
- Architecture
- Function
- Claim Limitation
- Technical Result
- Gap

---

# 25. Validation Question

Represents something that must be tested or verified.

Fields:

- Validation Question ID
- Question
- Origin
- Related Assumption
- Related Risk
- Related Requirement
- Priority
- Planned Test
- Status
- Result

---

# 26. Test / Experiment Object

Fields:

- Test ID
- Name
- Objective
- Hypothesis
- Method
- Inputs
- Conditions
- Metrics
- Success Criteria
- Failure Criteria
- Results
- Evidence
- Owner
- Date
- Status
- Decision

---

# 27. Result Object

Fields:

- Result ID
- Test
- Measurement
- Observation
- Outcome
- Interpretation
- Evidence
- Verification State
- Decision Impact

---

# 28. Customer Insight Object

Used in Advanced Course.

Fields:

- Insight ID
- Customer Segment
- Source
- Interview / Research Reference
- Problem
- Need
- Observation
- Quote/Note
- Confidence
- Related Assumption
- Related Feature
- Decision Impact

---

# 29. Market Evidence Object

May represent:

- market size source,
- competitor evidence,
- pricing evidence,
- customer demand evidence,
- adoption evidence,
- channel evidence.

Fields should align with the general Evidence model.

---

# 30. Task Object

Used for execution.

Fields:

- Task ID
- Title
- Description
- Owner
- Team
- Status
- Priority
- Due Date
- Backlog State
- Related Project Object
- Related Milestone
- Related Decision

Possible statuses:

- Backlog
- To Do
- Doing
- Review
- Done
- Blocked

---

# 31. Milestone Object

Fields:

- Milestone ID
- Name
- Description
- Target Date
- Dependencies
- Required Outputs
- Status
- Related Gate

---

# 32. Capability / Team Role Object

Used in team development.

Fields:

- Capability ID
- Capability Needed
- Why Needed
- Existing Owner
- Gap
- Future Role
- External Support
- Priority

---

# 33. Financial Assumption Object

Fields:

- Financial Assumption ID
- Type
- Value
- Unit
- Source
- Confidence
- Evidence
- Scenario
- Status

Possible types:

- Price
- Cost
- Volume
- Margin
- Growth
- Funding Need
- Hiring Cost
- Marketing Cost

---

# 34. Pitch Claim Object

Pitch claims should be traceable.

Fields:

- Claim ID
- Statement
- Slide/Section
- Evidence
- Verification State
- Owner
- Status

Examples:

- "3 paying customers"
- "TRL 7"
- "Patent filed"
- "Prototype tested"

The platform should distinguish:

- claim,
- source evidence,
- current verification.

---

# 35. Funding Activity Object

Fields:

- Funding Activity ID
- Target
- Type
- Contact
- Stage
- Date
- Amount
- Status
- Notes
- Related Pitch
- Related Evidence

Future use:

- investor outreach,
- grant applications,
- funding pipeline.

---

# 36. Artifact Object

Artifacts are structured outputs produced by activities.

Artifact types may include:

- Developed Concept
- Problem Bank
- Solution Bank
- Decision Record
- Invention Structure
- Gap List
- Mind Map
- Minimum Essential Structure
- Invention Concept
- Patent Landscape Snapshot
- Validation Plan
- Risk Map
- Product Roadmap
- Business Feasibility Assessment
- Team Development Map
- Pitch Deck Record

Fields:

- Artifact ID
- Artifact Type
- Project
- Workspace
- Creator
- Contributors
- Status
- Version
- Input Objects
- Output Objects
- Evidence
- Feedback
- Decisions
- AI Outputs

---

# 37. Artifact Status Model

Possible states:

- Draft
- Candidate
- Submitted
- Under Review
- Revision Requested
- Approved
- Current
- Superseded
- Archived
- Unverified
- Verified

Not all artifacts use every status.

---

# 38. Version Object

Version should be first-class.

Fields:

- Version ID
- Artifact
- Version Label
- Created By
- Created Date
- Change Summary
- Origin
- Previous Version
- Status
- Approval
- Related Decision
- Evidence
- AI Contribution
- Feedback

---

# 39. Version Naming

Version labels are artifact-specific.

Examples:

- Developed Concept V2
- Invention Structure V1
- Mind Map V2
- Invention Concept V1
- Invention Concept V2

The platform must not use one global "Project Version."

---

# 40. Feedback Object

Fields:

- Feedback ID
- Author
- Target Artifact/Object
- Target Version
- Comment
- Feedback Type
- Status
- Created Date
- Resolved Date
- Related Revision

Feedback types:

- Comment
- Question
- Correction
- Revision Request
- Approval Note
- Warning
- Suggestion

---

# 41. AI Output Object

AI outputs must be first-class where saved.

Fields:

- AI Output ID
- User
- Workspace
- Project
- Activity
- Role
- Prompt/Task
- Context References
- Evidence References
- Output
- Output Type
- Verification State
- User Disposition
- Related Object
- Related Decision

Output types:

- Analysis
- Suggestion
- Hypothesis
- Draft
- Comparison
- Classification
- Summary
- Candidate Solution

---

# 42. AI Disposition

After AI output, human action may be:

- Keep for Review
- Accept as Candidate
- Modify
- Reject
- Investigate Further
- Link to Evidence
- Convert to Project Object

AI output should not become an approved project object automatically.

---

# 43. Origin / Provenance

Every important object should record origin.

Possible origins:

- User
- Team
- Master
- Mentor
- AI
- Patent
- Technical Source
- Customer Research
- Test
- Calculation
- External Expert
- Imported File

This supports traceability.

---

# 44. Verification State

Relevant objects may use:

- Unverified
- Partially Verified
- Verified
- Contradicted
- Needs Review

Not every object requires verification.

---

# 45. Relationship Types

The platform should support reusable semantic relationships such as:

- Solves
- Supports
- Depends On
- Implements
- Belongs To
- Connected To
- Derived From
- Evidence For
- Evidence Against
- Replaces
- Supersedes
- Validates
- Contradicts
- Proposed By
- Approved By
- Caused By
- Results In
- Tested By
- Compared With
- Identified In
- Shared From

---

# 46. Traceability Chain

A valid project chain may look like:

```text
Problem P12
↓ solved by
Solution S07
↓ delivered by
Function F04
↓ implemented by
Component C09
↓ constrained by
Requirement R06
↓ exposed to
Risk RK03
↓ investigated by
Test T05
↓ produces
Evidence EV12
↓ informs
Decision D08
↓ updates
Invention Concept V2
```

This is a core product differentiator.

---

# 47. Object Reuse Across Sessions

Objects should survive across sessions.

Example:

Problem created in Session 4 may later appear in:

- Session 5 voting,
- Session 6 Affinity Diagram,
- Session 7 Mind Map,
- Session 9 patent comparison,
- Session 10 AI refinement.

The platform should reference the same Problem object rather than duplicate it.

---

# 48. Object Reuse Across Programs

A Requirement created in Advanced Session 1 may later appear in:

- Validation,
- TRL,
- Business Feasibility,
- Pitch Deck,
- Funding discussion.

The platform should preserve continuity.

---

# 49. Project Baseline

The project should maintain a current approved baseline.

The baseline may reference:

- current Invention Concept,
- current Mind Map,
- current Architecture Map,
- current Requirements,
- current Product Roadmap,
- current Business Assumptions,
- current Pitch Claims.

The baseline is not one document.

It is a collection of current approved project states.

---

# 50. Current vs Historical

Every important object/artifact should be able to distinguish:

- Current
- Historical
- Archived
- Superseded

Historical records must remain queryable where permitted.

---

# 51. Project Change Log

Each project should maintain a Change Log.

Fields:

- Change ID
- Date
- User
- Change Type
- Object/Artifact
- Previous State
- New State
- Reason
- Origin
- Related Decision
- Related Evidence
- Related AI Output

---

# 52. Decision Log

The project should maintain a dedicated Decision Log.

This provides fast access to:

- what was decided,
- when,
- by whom,
- why,
- based on what evidence,
- what changed.

---

# 53. Open Questions Register

The project should maintain an Open Questions Register.

This prevents unresolved questions from disappearing between sessions.

Possible status:

- Open
- Assigned
- Investigating
- Resolved
- Deferred

---

# 54. Verification Register

The project should maintain a Verification Register for important claims and assumptions.

Possible items:

- technical assumption,
- AI suggestion,
- patent conclusion,
- market assumption,
- financial assumption,
- pitch claim.

---

# 55. Evidence Map

The project should support an Evidence Map that links:

```text
Evidence
↓
Analysis
↓
Decision
↓
Project Change
```

This supports auditability and AI reliability.

---

# 56. Invention Structure

Invention Structure should be represented using structured links among:

- Systems
- Subsystems
- Components
- Functions
- Problems
- Solutions
- Relationships

This should not be only a diagram image.

---

# 57. Mind Map

Mind Map should eventually reference structured project objects.

Example node may reference:

- System S1
- Component C4
- Gap G2
- Problem P8

The visual map and project objects should remain connected.

---

# 58. Affinity Diagram

Affinity Diagram should group existing cards/objects where possible.

A card may represent:

- Problem
- Solution
- Feature
- Component
- Finding
- Decision

Affinity grouping should not require duplicating source content unnecessarily.

---

# 59. Patent Landscape Snapshot

The Patent Landscape Snapshot may aggregate:

- search logs,
- relevant patents,
- evidence sheets,
- claim maps,
- architecture maps,
- comparison matrix,
- gaps.

It is an Artifact composed of structured supporting objects.

---

# 60. Product Development Question Map

Advanced Course project model should support a structured map of:

- requirements,
- assumptions,
- constraints,
- risks,
- validation questions,
- priorities.

These should connect to later tests and decisions.

---

# 61. Validation Plan

Validation Plan may contain:

- assumption,
- question,
- test,
- metric,
- conditions,
- success criterion,
- decision criterion,
- owner,
- status.

---

# 62. TRL Record

If TRL is used, the platform should store:

- current TRL,
- evidence,
- date,
- rationale,
- next requirements,
- reviewer,
- related tests.

TRL must not be a manually selected number without supporting evidence where the curriculum requires validation.

---

# 63. Business Feasibility Artifact

May include:

- technical readiness,
- customer need,
- market evidence,
- cost,
- price,
- delivery model,
- risks,
- assumptions,
- Go / Modify / Stop decision.

---

# 64. Team Development Map

May include:

```text
Milestone
→ Work Required
→ Capability Required
→ Existing Person
→ Gap
→ Role Needed
→ External Support
```

This should connect to project execution.

---

# 65. Backlog / Kanban Objects

Backlog and Kanban should use Task objects.

Task status should update without losing task history.

The same Task may connect to:

- requirement,
- risk,
- feature,
- test,
- milestone.

---

# 66. Pitch Evidence Link

Pitch claims should be able to link to existing project evidence.

Example:

```text
Pitch Claim:
"Prototype tested at -20°C"
↓
Test Result TR12
↓
Measurement Evidence EV44
```

This helps maintain credibility and consistency.

---

# 67. Project Membership vs Team Membership

These concepts should remain distinct.

A user may:

- be a project owner,
- be a team member,
- be a Mentor,
- be a Master reviewer.

Project access is derived from permissions and roles, not only team membership.

---

# 68. Project Membership History

The platform should preserve:

- who joined,
- when,
- role,
- when removed,
- contribution period.

---

# 69. Confidentiality Level — Future

Architecture may support project-level confidentiality states:

- Standard
- Confidential
- Restricted

Not required in first MVP unless needed.

---

# 70. Searchability

Structured objects should eventually be searchable by:

- title,
- type,
- status,
- creator,
- session,
- evidence,
- relationship,
- tag.

This supports both users and AI.

---

# 71. Tags

Tags may be used for flexible organization but must not replace structured relationships.

Examples:

- Safety
- Electrical
- User Experience
- Patent Gap
- Customer Validation

---

# 72. Object Comments

Some project objects may support comments.

Comments should remain separate from the object's approved content.

---

# 73. Object Attachments

Objects may have files attached.

Example:

Component C08 may have:

- drawing,
- datasheet,
- test photo.

Attachments inherit object permissions unless explicitly overridden.

---

# 74. Object Duplication

The platform should minimize unnecessary duplication.

Prefer references and relationships.

Copy should be used when:

- snapshot required,
- cross-team share requires frozen version,
- template instantiation required.

---

# 75. Object Deletion

Important project objects should prefer:

- archive,
- supersede,
- deactivate

rather than permanent deletion.

Permanent deletion rules will be defined later.

---

# 76. Object Approval

Not every object needs independent approval.

Approval may occur at:

- object level,
- artifact level,
- stage gate.

The workflow specification will define where formal approval is required.

---

# 77. MVP Object Priority

The MVP does not need every object above.

The highest-priority initial structured objects are likely:

1. Development Project
2. User / Team reference
3. Idea
4. Problem
5. Solution
6. Feature
7. Function
8. Component
9. Evidence
10. Decision
11. Artifact
12. Version
13. Feedback
14. AI Output
15. File
16. Share
17. Activity Instance

Advanced objects such as finance/funding can be added later.

Exact MVP scope will be decided in `07_MVP_SCOPE.md`.

---

# 78. Model Decisions Captured

## Decision DPM-001 — Structured Project Model

The Development Project is composed of structured objects, relationships, artifacts, and files.

**Status:** Required.

---

## Decision DPM-002 — Objects Persist Across Sessions

Objects should be referenced across activities rather than recreated.

**Status:** Required.

---

## Decision DPM-003 — Relationship-Based Traceability

Project logic should be represented using explicit object relationships.

**Status:** Required.

---

## Decision DPM-004 — Evidence Is First-Class

Evidence must be linkable directly to project objects and decisions.

**Status:** Required.

---

## Decision DPM-005 — Decision Is First-Class

Formal decisions must exist as dedicated records.

**Status:** Required.

---

## Decision DPM-006 — Artifact-Specific Versioning

Versioning is per artifact/object type, not one global project version.

**Status:** Required.

---

## Decision DPM-007 — AI Output Is Separate

Saved AI output remains a distinct object until human action converts or links it to project content.

**Status:** Required.

---

## Decision DPM-008 — Current Baseline Is Composite

The current project baseline is a collection of current approved artifacts and objects.

**Status:** Recommended.

---

## Decision DPM-009 — Visual Maps Should Reference Structured Objects

Mind Maps, Architecture Maps, and similar tools should connect visual nodes to project objects where practical.

**Status:** Recommended.

---

## Decision DPM-010 — Cross-Program Continuity

The same project object model supports Professional, Advanced, and future programs.

**Status:** Required.

---

# 79. Open Questions for Review

1. Should every Idea become a permanent object, or only ideas intentionally saved?
2. Should private AI conversations be stored as project history by default?
3. Should a rejected Solution remain visible in the main project or move to archive?
4. Should Problem IDs and Component IDs be human-visible (e.g. P01, C08)?
5. Should users be allowed to manually define relationships, or only through specific tools?
6. Should the current project baseline be manually approved or automatically composed from approved artifacts?
7. Should every patent search query be permanently logged?
8. Should every Test require a formal success criterion?
9. Should TRL assessment require Master approval?
10. Should Pitch Claims always require evidence links before being marked Verified?
11. Should Customer Insights support anonymous respondent identities by default?
12. Which objects need soft-delete vs archive?
13. Should private personal artifacts be allowed to link directly into a team-owned project before sharing?
14. Should one Project support multiple inventions, or should each invention be a separate Development Project?

These should be answered before the database schema is finalized.

---

# 80. Required Next Document

The next document is:

# `06_COURSE_ACTIVITY_WORKFLOWS.md`

It should map:

- Workshop,
- Professional Course S1–S10,
- Advanced Course S1–S12,

into:

- session goals,
- inputs,
- activities,
- workspace mode,
- individual/team/live/async behavior,
- instructor actions,
- AI role,
- outputs,
- project objects created,
- dependencies,
- approval points,
- development gates.

---

# 81. Codex Model Rule

Codex must not reduce the Development Project to:

- a generic document,
- a file folder,
- a single JSON blob,
- a single "current state" record without history.

Implementation must preserve:

- stable object identity,
- relationships,
- ownership,
- provenance,
- version history,
- evidence links,
- decision links,
- workspace permissions.

If a project concept cannot be represented without losing traceability, the implementation must be revised before coding proceeds.

---

# End of Document

**Current Status:** Draft v0.1 — Ready for Ahmad/FICI review.  
**Next Document After Approval:** `06_COURSE_ACTIVITY_WORKFLOWS.md`
