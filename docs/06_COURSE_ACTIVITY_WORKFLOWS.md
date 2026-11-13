# FICI Invention Education & Development Platform
## Course & Activity Workflow Specification

**Document:** 06_COURSE_ACTIVITY_WORKFLOWS.md  
**Status:** Draft v0.1 — For Review  
**Depends on:** `01_PRODUCT_REQUIREMENTS.md`, `02_PLATFORM_ARCHITECTURE.md`, `03_ROLES_PERMISSIONS.md`, `04_WORKSPACE_TEAM_COLLABORATION.md`, `05_DEVELOPMENT_PROJECT_MODEL.md`  
**Purpose:** Map the FICI Workshop, Professional Course, and Advanced Course into platform workflows, activity modes, inputs, outputs, dependencies, instructor actions, AI roles, persistence requirements, and development gates.

---

# 1. Workflow Principle

The platform must not treat sessions as isolated content pages.

The educational model is:

**Learn → Watch Instructor Case Study → Practice → Apply to Own Project → Receive Feedback → Correct → Carry Output Forward**

Every session may therefore contain several layers:

1. Teaching
2. Instructor demonstration
3. Individual practice
4. Team activity
5. Project application
6. AI assistance where appropriate
7. Instructor review
8. Between-session refinement
9. Output approval
10. Transition to the next session

The platform must preserve the outputs and development history across these stages.

---

# 2. Activity Modes

Every course activity should be classifiable using one or more of the following modes.

## Live

Performed during an instructor-led session.

Examples:

- instructor teaching,
- case-study demonstration,
- team brainstorming,
- voting,
- live patent search,
- group review.

## Individual

Performed privately by one participant.

Examples:

- SCAMPER examples,
- individual brainstorming,
- research notes,
- private AI analysis.

## Team

Performed collaboratively inside a Team Workspace.

Examples:

- Problem Bank,
- Solution Bank,
- voting,
- Affinity Diagram,
- Mind Map,
- team development map,
- GTM map.

## Instructor-Guided

Requires instructor explanation, review, intervention, or approval.

## Between Sessions

Continues asynchronously after the live class.

## AI-Assisted

AI participates as an assistant, analyst, facilitator, or reviewer but does not make the final human decision.

---

# 3. Standard Session Workflow Pattern

Where appropriate, a session should follow this reusable structure:

```text
SESSION OPENS
↓
Review Previous Approved Output
↓
Teach Method / Concept
↓
Instructor Case Study
↓
Individual or Team Practice
↓
Apply to Development Project
↓
AI Assistance where appropriate
↓
Team Review / Decision
↓
Save Structured Output
↓
Submit / Share with Master
↓
Instructor Feedback
↓
Revision if needed
↓
Approved / Current Output
↓
Feeds Next Session
```

Not every session requires every step.

---

# 4. Course Dependency Principle

The platform must support dependencies between activities and artifacts.

An activity may specify:

- Required Inputs
- Optional Inputs
- Output Artifact Type
- Required Review
- Completion Condition
- Next Activity Dependency

Example:

```text
Professional Session 4
Input: Developed Concept V2
Output: Problem Bank + Solution Bank

Professional Session 5
Required Input: Problem Bank + Solution Bank
Output: Team Decision Record
```

---

# 5. Instructor Case Study Workflow

The instructor should maintain one continuing Case Study Project.

The Case Study should use the same tool types as student projects.

Example:

```text
Instructor Demonstrates Mind Mapping
↓
Case Study Mind Map is created
↓
Students view the method
↓
Students open their Team Workspace
↓
Students build their own Mind Map
```

The Case Study should be shareable as:

- Demonstration
- Reference
- Example
- Required Preparation

Students must not accidentally edit the instructor source artifact.

---

# 6. Workshop Module

## 6.1 Purpose

The 4-hour Innovation & Invention Workshop introduces:

- inventor mindset,
- creativity,
- invention thinking,
- SCAMPER,
- Brainstorming,
- Dot Voting,
- Affinity Grouping,
- Inventor Roadmap,
- Patent Search,
- AI as Innovation Assistant.

It is a lighter entry point into the same ecosystem.

## 6.2 Platform Role

The Workshop should not use a separate platform architecture.

It should use a simplified configuration of:

- Learning System
- Personal Workspace
- optional Team Workspace
- selected Method Tools
- Instructor Case Study
- early Development Project

## 6.3 Workshop Workflow

Conceptually:

```text
Understand Inventor Thinking
↓
Identify / Explore Problems
↓
Generate Ideas
↓
Apply Structured Creativity
↓
Evaluate / Organize
↓
Understand Invention Journey
↓
Introduce Patent Search
↓
Introduce AI Assistance
↓
Save Early Project Direction
```

## 6.4 Workshop Output

The Workshop may generate an early project or invention direction that can later become the starting point of the Professional Course.

The platform should allow:

**Workshop Project → Continue into Professional Course**

without forcing recreation of the project.

---

# 7. Professional Course — Overall Workflow

The Professional Course is the primary invention-development workflow:

```text
Inventor Mindset
↓
SCAMPER
↓
SCAMPER Applied Development
↓
Brainstorming / Problem Storming
↓
Evaluation & Voting
↓
Affinity / Invention Structure
↓
Mind Mapping / Essential Structure
↓
Patent Literacy
↓
Patent Search & Comparative Analysis
↓
AI-Assisted Refinement
↓
Invention Concept V2
```

The platform must preserve outputs from earlier sessions because they become inputs later.

---

# 8. Professional Session 1 — Think Like an Inventor

## Goal

Build foundational understanding of:

- creativity,
- inventor mindset,
- experimentation,
- failure and resilience,
- invention vs idea vs innovation.

## Primary Mode

- Live teaching
- Individual reflection
- Instructor-guided

## Main Inputs

None required beyond enrollment.

## Platform Activities

- learning content,
- discussion prompts,
- reflections,
- optional personal notes,
- instructor examples.

## Primary Output

No major structured invention artifact is required.

Possible stored output:

- Personal Reflection / Readiness Notes
- early problem observations

## AI Role

Minimal / optional.

AI must not replace the conceptual learning in this session.

## Dependency

Prepares participants for structured creativity in Session 2.

---

# 9. Professional Session 2 — The SCAMPER Framework

## Goal

Teach the seven SCAMPER lenses and the FICI holistic-to-detail method.

## Inputs

- Session 1 learning
- example products / systems / solutions.

## Activities

- analyze existing examples,
- identify changes,
- classify the change under SCAMPER,
- create student examples.

## Workspace

Primarily Personal Workspace.

## Structured Method

SCAMPER:

- Substitute
- Combine
- Adapt
- Modify
- Put to Another Use
- Eliminate
- Reverse / Rearrange

## Between-Session Work

Participants prepare 14 SCAMPER examples:

- 7 existing examples
- 7 participant-created examples

with an explanation of what changed.

## Output

**SCAMPER Example Set**

Structured objects:

- Idea
- SCAMPER Technique
- Original Element
- Change
- Result

## Instructor Role

- teach,
- review examples,
- correct classification,
- prepare participants for selection in Session 3.

## AI Role

Optional Structured Creativity Assistant.

AI may assist exploration but should not create the participant's complete exercise automatically.

## Dependency

Session 3 selects and develops one SCAMPER idea.

---

# 10. Professional Session 3 — SCAMPER Applied Workshop

## Goal

Turn one selected SCAMPER idea into a developed invention concept.

## Inputs

- SCAMPER Example Set
- selected participant idea.

## Primary Mode

- Live
- Coach-led
- Individual or Team Project
- AI-assisted
- Instructor-guided

## Workflow

```text
Review SCAMPER Examples
↓
Select One Idea
↓
Break Down Idea
↓
Initial Patent Search
↓
Analyze Relevant Results
↓
Compare Existing Inventions
↓
Identify Unsolved Problems / Gaps
↓
AI-Assisted Analysis
↓
Generate New Innovation
↓
Develop Concept
```

## Platform Tools

- SCAMPER tool
- Patent Search Workspace
- Comparison workspace
- Evidence storage
- AI Analysis
- Development Record

## AI Role

AI may:

- extract,
- compare,
- organize,
- identify possible gaps,
- explore alternative directions.

AI conclusions remain unverified until checked against source documents.

## Output

**Invention Development Record + Developed Concept V2**

Should preserve:

- Original Idea
- Original Problem
- Original Solution
- SCAMPER Technique
- Prior Art
- Similarities
- Differences
- Unsolved Problems
- Gaps
- Improvement Opportunities
- New Solutions
- New Features / Functions
- Problem
- Solution
- Key Features
- Main Function
- Key Difference

## Persistence

Developed Concept V2 becomes the core input to later invention-development sessions.

---

# 11. Professional Session 4 — Brainstorming & Problem Storming

## Goal

Expand the concept before evaluation.

## Input

**Developed Concept V2**

## Workflow

```text
Concept V2
↓
Challenge from Multiple Perspectives
↓
Generate Problems
↓
Problem Bank
↓
Choose Problem
↓
Generate Multiple Solutions
↓
Solution Bank
```

## Problem Perspectives

- User
- Function
- Technical
- Cost
- Safety
- Environment
- Accessibility
- Maintenance

## Methods Supported

- Classic Brainstorming
- Individual Brainstorming
- Brainwriting / Passing Group
- Problem Storming

## Workspace Modes

- Personal generation
- Team generation
- private-before-share
- team collaboration

## Important Rule

No ranking, voting, or elimination during divergence.

## Output

- **Problem Bank**
- **Solution Bank**

## AI Role

Optional ideation facilitator.

AI-generated items must be labeled as AI-generated candidates.

## Dependency

Session 5 evaluates and decides among the generated options.

---

# 12. Professional Session 5 — Idea Evaluation & Voting

## Goal

Convert multiple options and disagreement into a structured team decision.

## Inputs

- Problem Bank
- Solution Bank
- candidate features / directions.

## Primary Mode

Team.

## Methods

### Dot Voting

For prioritizing options.

### Fist to Five

For revealing support and concerns.

### Planning Poker

For estimating effort / complexity and exposing different assumptions.

## Workflow

```text
Display Options
↓
Individual Evaluation / Voting
↓
Reveal Differences
↓
Discuss
↓
Refine
↓
Re-vote where needed
↓
Team Decision
```

## Important Rule

Voting is not automatically the final decision.

## Output

**Team Decision Record**

Should preserve:

- selected problems,
- selected solutions,
- selected features,
- votes,
- concerns,
- reasoning,
- final decision.

## Platform Requirements

- hidden votes before reveal where required,
- simultaneous Planning Poker reveal,
- vote attribution / anonymity configuration,
- decision log.

## Dependency

Selected work feeds Session 6.

---

# 13. Professional Session 6 — Affinity Diagram

## Goal

Organize accumulated information into an early invention structure.

## Inputs

- Problems
- Solutions
- Features
- Decisions
- Components
- Search Findings

## Workflow

```text
Collect
↓
Spread Information
↓
Group by Natural Affinity
↓
Name Groups
↓
Identify Relationships
↓
Transform Groups into Systems / Subsystems
↓
Connect Problem → Solution → Function → Component
↓
Identify Gaps
```

## Primary Mode

Team collaboration.

## Platform Tool

Affinity Board with structured cards.

## Output

1. **Invention Structure V1**
2. **Gap List**

## Data Requirement

Affinity cards should reference existing structured objects where possible instead of duplicating them.

## Instructor Role

Guide grouping without imposing categories prematurely.

## AI Role

Optional pattern analyst.

## Dependency

Session 7 converts the structure into a whole-invention map.

---

# 14. Professional Session 7 — Mind Mapping

## Goal

Visualize the entire invention and identify the minimum essential invention structure.

## Inputs

- Invention Structure V1
- Gap List.

## Workflow

```text
Central Invention
↓
Main Systems
↓
Subsystems
↓
Components
↓
Functions
↓
Problems / Solutions
↓
Cross-Connections
↓
Unresolved Gaps
↓
Targeted Search / AI
↓
Team Review
↓
Update Map
↓
Classify Core / Supporting / Future
```

## Platform Tool

Structured collaborative Mind Map.

## AI Role

System Structure Analyst.

AI may help examine:

- missing component,
- unclear function,
- weak connection,
- unresolved gap.

## Output

- **Invention Mind Map**
- **Minimum Essential Invention Structure**
- **Invention Concept V1**

## Classification

- Core
- Supporting
- Optional / Future

## Dependency

Invention Concept V1 becomes the baseline entering formal patent-literacy and patent-analysis stages.

---

# 15. Professional Session 8 — Patent Document & Reading Basics

## Goal

Teach participants how to understand and navigate patent documents.

## Input

- Invention Concept V1
- existing project structure.

## Learning Areas

- Intellectual Property
- Patent
- Trademark
- Copyright
- Industrial Design
- Trade Secret
- WIPO
- PCT
- patent front page,
- Title,
- Abstract,
- Description,
- Claims,
- Drawings,
- bibliographic information.

## Primary Mode

- Live teaching
- Instructor demonstration
- individual reading practice.

## Platform Requirements

- patent reference materials,
- patent document viewer / links,
- structured Patent Reading framework,
- notes linked to patent sections.

## Output

**Patent Reading Framework / Reading Map**

This is a reusable knowledge framework rather than a major new invention version.

## AI Role

Limited.

AI should assist understanding, but participants must learn to read the source patent.

## Dependency

Session 9 applies the framework to patent search and comparative analysis.

---

# 16. Professional Session 9 — Patent Search & Comparative Analysis

## Goal

Build an evidence-based picture of what already exists and identify potential technical gaps.

## Inputs

- Invention Concept V1
- Mind Map
- Minimum Essential Structure
- Problem/Solution structure
- Patent Reading Framework.

## Workflow

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

## Platform Tools

- Search Map
- Search Log
- Patent Record
- Evidence Sheet
- Claim Map
- Architecture Map
- Problem–Solution Map
- Similarity / Difference Matrix
- Gap Map

## External Sources

May include:

- WIPO PATENTSCOPE
- USPTO
- Google Patents

## AI Role

Limited research and analysis assistant.

AI may suggest:

- synonyms,
- technical terms,
- extraction,
- comparison.

AI suggestions are not patent evidence.

## Output

**Patent Landscape Snapshot**

Composed from:

- Search Map / Log
- Relevant Patent Set
- Evidence Sheets
- Claim Maps
- Architecture Maps
- Problem–Solution Maps
- Similarity / Difference Matrix
- Gap Map

## Important Rule

The session identifies gaps; it does not prematurely declare novelty or patentability.

## Dependency

Session 10 uses the Patent Landscape Snapshot for structured invention refinement.

---

# 17. Professional Session 10 — AI-Assisted Invention Refinement

## Goal

Connect all previous work into a structured, evidence-based refinement process.

## Inputs

- Invention Concept V1
- Invention Structure
- Mind Map
- Minimum Essential Structure
- Patent Landscape Snapshot
- Search Log
- Evidence Sheets
- Claim Maps
- Architecture Maps
- Similarity / Difference Matrix
- Gap Map
- team decisions,
- prior instructor feedback.

## AI-Assisted Invention Loop

```text
Organize
↓
Analyze
↓
Investigate
↓
Ideate
↓
Refine
↓
Verify
↓
Decide
↓
Update
↺
```

## Workflow

### Stage 1 — Reconstruct Current State

AI analyzes the approved baseline and patent landscape.

### Stage 2 — Analysis Gate

Humans confirm:

- current invention,
- existing approaches,
- overlaps,
- differences,
- gaps,
- uncertainties.

### Stage 3 — Resolve One Gap at a Time

Reuse:

- Root Cause
- Problem Storming
- SCAMPER
- Brainstorming
- Critical Review

### Stage 4 — Candidate Solutions

AI-generated solutions remain candidates.

### Stage 5 — Impact Analysis

Check:

- Components
- Functions
- Relationships
- Architecture
- Inputs / Outputs
- New risks
- Complexity
- Safety
- Manufacturing
- Maintenance
- Dependencies.

### Stage 6 — Draft Concept V2

Preserve V1 baseline.

### Stage 7 — Search Again

Any invention change may create new prior-art questions.

### Stage 8 — Human Decision

Keep / Modify / Reject / Investigate Further.

## AI Governance

**AI Generates → Human Evaluates → Evidence Verifies → Team Decides**

## Outputs

Final Professional Course package should include:

- **Invention Concept V2**
- updated Mind Map
- updated Architecture Map
- updated Problem–Solution Map
- Patent Landscape Snapshot
- Gap Resolution Log
- Change Log
- AI / Team Decision Log
- Verification Register
- Open Questions / Future Work

## Course Outcome

The participant leaves with a structured invention-development package, not with an automatic patentability conclusion or finished commercial product.

---

# 18. Professional Course Dependency Chain

```text
S1 Mindset
↓
S2 SCAMPER Example Set
↓
S3 Developed Concept V2
↓
S4 Problem Bank + Solution Bank
↓
S5 Team Decision Record
↓
S6 Invention Structure V1 + Gap List
↓
S7 Invention Mind Map + Essential Structure + Invention Concept V1
↓
S8 Patent Reading Framework
↓
S9 Patent Landscape Snapshot + Gap Map
↓
S10 Invention Concept V2 + Final Invention Development Package
```

---

# 19. Advanced Course — Overall Workflow

The Advanced Course continues from:

**Professional Course Final Invention Concept V2**

and moves toward:

**Startup Development Roadmap + Final Startup Pitch**

Overall path:

```text
Invention Concept V2
↓
Product Development Questions
↓
Validation & Prototyping
↓
TRL & Technical Roadmap
↓
Technical Development Gate
↓
Business Feasibility
↓
Business Decision Gate
↓
Market Validation
↓
Team & Founder Structure
↓
Leadership & Conflict
↓
Agile Execution System
↓
Go-to-Market
↓
Startup Finance
↓
Pitch
↓
Funding Strategy
```

---

# 20. Advanced Session 1 — From Invention to Product

## Core Question

What do we need to prove before we know what to build?

## Input

**Invention Concept V2**

## Workflow

```text
Intended User
↓
Problem & Value
↓
Key Functions
↓
Critical Assumptions
↓
Initial Requirements
↓
Constraints
↓
Risks
↓
Validation Questions
↓
Top Development Priorities
```

## Activities

- define intended user,
- define problem/value,
- identify key functions,
- classify assumptions,
- create initial requirements,
- identify constraints and trade-offs,
- map risks,
- create validation questions,
- prioritize top 1–3 questions.

## Workspace

Primarily Team Workspace.

## Outputs

- Product Development Question Map
- Initial Requirements
- Critical Assumptions
- Constraints & Trade-offs
- Initial Risk Map
- Validation Questions
- Top Development Priorities

## Between-Session Work

Continue and refine the map with instructor feedback.

## Instructor Role

Review and correct the map before Session 2.

## Dependency

Corrected output feeds Session 2.

---

# 21. Advanced Session 2 — PoC, Prototype, MVP & Validation

## Core Question

How should we prove it?

## Inputs

Session 1 outputs.

## Workflow

```text
Select Top Questions
↓
Identify Assumption
↓
Choose Validation Method
↓
Define Minimum Build/Test
↓
Define Evidence
↓
Define Decision Criteria
↓
Plan Iteration
↓
Sequence Work
```

## Supported Validation Methods

- Research
- Calculation
- Simulation
- Experiment
- PoC
- Prototype
- MVP
- User Test

## Output

**Initial Validation & Prototyping Plan**

Contains:

- Top Questions
- Assumptions
- Methods
- Test Scope
- Metrics
- Conditions
- Decision Criteria
- Iteration Plan

## Important Principle

Build only what is necessary to answer the current question.

## Dependency

Feeds Session 3.

---

# 22. Advanced Session 3 — TRL & Product Development Roadmap

## Core Question

Can we develop it?

## Inputs

- Invention Concept V2
- Product Development Question Map
- Validation & Prototyping Plan
- current technical evidence.

## Workflow

```text
Inventory Current Evidence
↓
Estimate Current TRL
↓
Define Next Target State
↓
Identify Development Gaps
↓
Prioritize
↓
Plan Build / Test
↓
Define Evidence
↓
Set Milestone
↓
Reassess
```

## Output

**TRL Development Map / Product Development Roadmap**

The output captures:

- current state,
- current TRL,
- target state,
- gap,
- priority,
- build/test actions,
- evidence,
- milestone,
- reassessment.

## Development Gate

# Technical Development Gate — Can We Develop It?

Possible outcomes:

### YES
A credible technical development path exists.

### NOT YET
Important technical uncertainties remain but can be investigated.

### NO
A critical assumption, requirement, or constraint makes the current approach infeasible.

## Important Rule

Technical feasibility does not equal business feasibility.

## Dependency

Feeds Session 4.

---

# 23. Advanced Session 4 — Business Feasibility & Business Plan

## Core Question

Is it worth building a business around this?

## Inputs

- technical development roadmap,
- product assumptions,
- current evidence.

## Activities

Build an Initial Business Case using:

- Business Model
- Market Opportunity
- Revenue Logic
- Cost Structure
- Financial View
- Scenarios
- Capital Required
- Critical Assumptions

## Output

**Initial Business Case**

## Development Gate

# Business Decision Gate

Possible outcomes:

- GO
- MODIFY
- STOP

GO means promising enough to continue while remaining uncertainty can still be investigated.

MODIFY means business logic needs revision.

STOP means the current case does not justify further investment at this stage.

## Dependency

Feeds market validation in Session 5.

---

# 24. Advanced Session 5 — Market Research & Customer Validation

## Core Question

Is there a real market?

## Inputs

- Initial Business Case
- business assumptions
- product value proposition.

## Workflow

```text
Identify Critical Market Assumptions
↓
Define Research Questions
↓
Analyze Market / TAM / SAM / SOM
↓
Map Competition
↓
Map Customer Roles
↓
Customer Discovery
↓
Price / Value Hypothesis
↓
Demand Test
↓
Collect Evidence
↓
Update Business Case
```

## Validation Principle

Evidence strength generally increases from:

Opinion → Interest → Intent → Commitment → Behavior → Payment

## Output

- **Market Validation Map**
- **Updated Business Case**

## Market Validation Gate

Evidence status:

- Supported
- Uncertain
- Not Supported

Decision:

- GO
- MODIFY
- STOP

## Dependency

Feeds Team / Founder Structure.

---

# 25. Advanced Session 6 — Startup Team & Founder Structure

## Core Question

Who will build the company?

## Inputs

- development milestones,
- product roadmap,
- market evidence,
- business case.

## Principle

Start with the work, not the people.

## Workflow

```text
Next Milestones
↓
Required Work
↓
Capabilities
↓
Current Team / T-Shaped Profiles
↓
Capability Gaps
↓
Founder Fit
↓
Ownership
↓
Fill Gaps
↓
Coordination
↓
Support Needs
↓
Current Team Stage
↓
Initial Structure
↓
Future Team
```

## Output

**Startup Team Development Map**

Includes:

- Core Team
- Extended Team
- Future Team
- Must Have Now
- Need Soon
- Can Wait
- External Support

## Readiness Check

Possible states:

- Ready
- Partially Ready
- Not Ready Yet

## Dependency

Feeds Leadership / Conflict work in Session 7.

---

# 26. Advanced Session 7 — Leadership, Management & Conflict Resolution

## Core Question

How will we lead, communicate, make decisions, and handle conflict?

## Inputs

- Startup Team Development Map
- founder structure,
- team responsibilities.

## Areas

- leadership,
- management,
- communication,
- decision-making,
- conflict,
- team performance.

## Output

**Leadership & Conflict Management Map**

## Platform Needs

- role ownership,
- decision rights,
- conflict records where appropriate,
- team agreements,
- communication expectations,
- decision processes.

## Dependency

Feeds execution system design in Session 8.

---

# 27. Advanced Session 8 — Agile & Startup Management Systems

## Core Question

How will we manage the work?

## Inputs

- team structure,
- leadership structure,
- project milestones,
- development work.

## Learning / Methods

- project delivery approaches,
- Agile,
- Scrum,
- Kanban,
- Lean Startup,
- execution systems.

## Platform Tools

- Backlog
- Task
- Kanban
- Work in Progress
- Priority
- Dependency
- Blocker
- Review
- Progress
- learning / evidence loops

## Expected Output

**Startup Execution / Agile Management System**

At minimum the output should make visible:

- goal,
- workstreams,
- priorities,
- accountability,
- active work,
- blockers,
- WIP,
- dependencies,
- progress,
- feedback/evidence loops.

## Readiness Check

Execution Readiness Check.

## Dependency

Feeds Go-to-Market execution in Session 9.

---

# 28. Advanced Session 9 — Go-to-Market & Marketing

## Core Question

How will we enter the market?

## Inputs

- Market Validation Map
- Updated Business Case
- target segment,
- team execution system.

## Workflow

```text
Beachhead Segment
↓
Customer Value
↓
Positioning
↓
Channels
↓
Funnel
↓
GTM Assumptions
↓
Experiment
↓
Measure
↓
Evidence
↓
Decision
↓
Learn
```

## Output

**Initial Go-to-Market System / Startup GTM Map**

Core sequence:

**Target → Position → Reach → Convert → Measure → Test → Learn**

## Important Principle

Do not leave with random marketing ideas.

Leave with an executable GTM system.

## Dependency

Feeds finance/economics in Session 10.

---

# 29. Advanced Session 10 — Startup Finance & Business Economics

## Core Question

Do the economics work?

## Inputs

- business case,
- market evidence,
- GTM model,
- revenue assumptions,
- cost assumptions.

## Areas

- Revenue
- Cost
- Cash
- Runway
- Break-even
- Profitability
- planning,
- control,
- financial decisions.

## Output

**Financial Management & Profitability Map**

Core sequence:

**Plan → Measure → Control → Decide → Act → Improve**

## Financial Readiness Check

Team should be able to explain:

- revenue,
- cost,
- cash,
- runway,
- break-even,
- profitability.

## Dependency

Feeds investor-facing story in Session 11.

---

# 30. Advanced Session 11 — Pitch Deck & Startup Presentation

## Core Question

How do we turn business evidence into an investor-ready story?

## Inputs

- product evidence,
- business case,
- market evidence,
- team,
- GTM,
- financial model,
- funding needs.

## Workflow

```text
Business Evidence
↓
Audience
↓
Story
↓
Deck
↓
Delivery
↓
Q&A
↓
Next Step
```

## Platform Requirements

- Pitch Claim records,
- evidence links,
- slide/story structure,
- presentation review,
- Q&A preparation,
- feedback.

## Credibility Principle

Claims must be accurate and verifiable.

Examples of supporting evidence may include:

- IP,
- certification,
- testing,
- prototypes,
- pilots,
- customers,
- sales,
- grants,
- awards.

## Output

**Startup Pitch / Pitch Deck Package**

The platform should allow pitch claims to link back to project evidence.

## Dependency

Feeds funding strategy in Session 12.

---

# 31. Advanced Session 12 — Investors, Funding & Fundraising Strategy

## Core Question

How will we fund the next development stage?

## Inputs

- startup pitch,
- funding needs,
- milestones,
- financial plan,
- team,
- development roadmap.

## Learning Areas

May include:

- funding sources,
- investors,
- angel investors,
- investor fit,
- fundraising process,
- investor relationship,
- governance,
- post-investment communication,
- future financing planning.

## Workflow

```text
Funding Need
↓
Target Milestone
↓
Funding Source / Investor Type
↓
Target List
↓
Approach
↓
Pitch
↓
Due Diligence / Discussion
↓
Decision
↓
Closing
↓
Governance / Communication
↓
Next Milestone
```

## Output

**Funding & Fundraising Strategy / Funding Roadmap**

Should connect:

- capital requirement,
- milestone,
- funding source,
- target investor,
- stage,
- outreach,
- status,
- follow-up,
- governance considerations.

## Advanced Course Final Outcome

The Advanced Course should culminate in a project package combining:

- Product Development Roadmap
- Validation Plan / Evidence
- Business Case
- Market Validation Map
- Startup Team Development Map
- Leadership & Conflict Management Map
- Execution System
- GTM Map
- Financial Management & Profitability Map
- Startup Pitch
- Funding Strategy

---

# 32. Advanced Course Dependency Chain

```text
Professional Course Final Output:
Invention Concept V2
↓
A1 Product Development Question Map
↓
A2 Validation & Prototyping Plan
↓
A3 TRL Development Map
↓
TECHNICAL DEVELOPMENT GATE
↓
A4 Initial Business Case
↓
BUSINESS DECISION GATE
↓
A5 Market Validation Map + Updated Business Case
↓
MARKET VALIDATION GATE
↓
A6 Startup Team Development Map
↓
A7 Leadership & Conflict Management Map
↓
A8 Startup Execution / Agile Management System
↓
A9 Initial GTM System
↓
A10 Financial Management & Profitability Map
↓
A11 Startup Pitch
↓
A12 Funding & Fundraising Strategy
```

---

# 33. Workspace Modes Across the Curriculum

| Activity Type | Personal | Team | Live | Async | Master Review |
|---|---:|---:|---:|---:|---:|
| Reflection | Yes | Optional | Yes | Yes | Optional |
| SCAMPER | Yes | Yes | Yes | Yes | Yes |
| Individual Brainstorming | Yes | No | Yes | Yes | Optional |
| Team Brainstorming | No | Yes | Yes | Yes | Yes |
| Brainwriting | No | Yes | Yes | Optional | Yes |
| Problem Bank | Yes | Yes | Yes | Yes | Yes |
| Solution Bank | Yes | Yes | Yes | Yes | Yes |
| Voting | Optional | Yes | Yes | Optional | Yes |
| Affinity Diagram | Yes | Yes | Yes | Yes | Yes |
| Mind Map | Yes | Yes | Yes | Yes | Yes |
| Patent Research | Yes | Yes | Yes | Yes | Yes |
| Evidence Analysis | Yes | Yes | Yes | Yes | Yes |
| AI Refinement | Yes | Yes | Yes | Yes | Yes |
| Requirements | Yes | Yes | Yes | Yes | Yes |
| Validation Plan | Yes | Yes | Yes | Yes | Yes |
| TRL Roadmap | Optional | Yes | Yes | Yes | Yes |
| Business Case | Optional | Yes | Yes | Yes | Yes |
| Market Validation | Yes | Yes | Yes | Yes | Yes |
| Team Map | No | Yes | Yes | Yes | Yes |
| Agile / Kanban | Optional | Yes | Yes | Yes | Yes |
| GTM | Optional | Yes | Yes | Yes | Yes |
| Finance | Optional | Yes | Yes | Yes | Yes |
| Pitch | Optional | Yes | Yes | Yes | Yes |
| Funding | Optional | Yes | Yes | Yes | Yes |

---

# 34. Instructor Workflow Across Sessions

The Master should be able to:

1. Open the current session.
2. Review required previous outputs.
3. Present teaching material.
4. Open Instructor Case Study.
5. Launch the relevant activity.
6. Assign participants to Personal or Team mode.
7. Observe team progress where allowed.
8. Enter team workspace or chat where allowed.
9. Provide guidance.
10. Review submitted artifact.
11. Comment / annotate.
12. Request revision.
13. Approve when appropriate.
14. Mark gate state where applicable.
15. Release the next activity/session.

---

# 35. Student Workflow Across Sessions

The student should be able to:

1. Enter current session.
2. See required inputs.
3. Watch / attend instruction.
4. See instructor Case Study.
5. Open the assigned tool.
6. Work privately when required.
7. Share selected outputs to Team.
8. Collaborate.
9. Use AI where allowed.
10. Save work continuously.
11. Submit output.
12. Review Master feedback.
13. Revise without losing history.
14. See approved output.
15. Carry it automatically into the next stage.

---

# 36. Team Workflow Across Sessions

A team should be able to:

```text
Open Team Workspace
↓
Review Previous Current/Approved Outputs
↓
Start Activity
↓
Collect Individual Inputs if required
↓
Collaborate
↓
Discuss in Team Chat
↓
Use Structured Methods
↓
Use AI as Assistant
↓
Make Decision
↓
Save Team Artifact
↓
Submit to Master
↓
Receive Feedback
↓
Revise
↓
Approve / Continue
```

---

# 37. AI Workflow Across Sessions

AI behavior should depend on activity.

## Early Ideation

AI role:

- creativity assistant,
- ideation facilitator.

## Structural Development

AI role:

- pattern analyst,
- systems analyst,
- critical reviewer.

## Patent / Evidence Stage

AI role:

- research assistant,
- extraction assistant,
- comparison assistant.

## Product Development

AI role:

- requirements analyst,
- risk analyst,
- validation planning assistant.

## Market / Business

AI role:

- research assistant,
- assumption challenger,
- comparison assistant.

## Execution / Finance

AI role:

- planning assistant,
- analytical assistant.

## Pitch / Funding

AI role:

- story reviewer,
- claim verifier against project evidence,
- critical reviewer.

AI must always respect:

**AI Suggestion ≠ Evidence ≠ Team Decision ≠ Instructor Approval**

---

# 38. Between-Session Workflow

The platform must support continuing work after the live class.

Possible tasks:

- finish artifact,
- upload evidence,
- conduct research,
- revise instructor feedback,
- update map,
- run validation,
- collect customer evidence,
- update business assumptions,
- complete backlog items,
- prepare pitch.

The same artifact continues between live and async work.

The system should not create a separate homework copy unless versioning requires it.

---

# 39. Review and Revision Pattern

Where review is required:

```text
Draft
↓
Submitted
↓
Under Review
↓
Approved
OR
Revision Requested
↓
Revised Version
↓
Resubmitted
↓
Approved
```

The previous version remains available.

---

# 40. Gate Pattern

Development Gates should be reusable workflow objects.

Gate should contain:

- Gate Type
- Inputs
- Evidence
- Readiness Questions
- Reviewer
- Outcome
- Reasoning
- Required Next Action
- Date

Possible outcomes:

- Go / Yes
- Modify / Not Yet
- Hold
- Stop / No
- More Evidence Required

---

# 41. Course Completion vs Project Readiness

Session completion should never automatically equal development readiness.

Example:

A participant may complete Advanced Session 3 but still receive:

**Technical Development Gate: NOT YET**

The platform should therefore separately track:

### Learning Completion
and
### Development Readiness

---

# 42. Activity Definition Model

Every structured activity should be configurable with:

- Activity ID
- Program
- Session
- Activity Name
- Method Type
- Workspace Mode
- Required Inputs
- Optional Inputs
- Participants
- AI Role
- Instructor Role
- Output Artifact
- Output Objects
- Completion Criteria
- Review Requirement
- Approval Requirement
- Next Dependency

This allows curricula to evolve without rewriting the entire platform.

---

# 43. Activity Instance Model

When a real user/team performs an activity, create an Activity Instance.

Example:

```text
Definition:
Professional S5 / Dot Voting

Instance:
Fall 2026 / Team 3 / Solution Prioritization
```

Instance stores:

- participants,
- start/end,
- workspace,
- inputs,
- actions,
- votes,
- output,
- status,
- related decision,
- instructor feedback.

---

# 44. Curriculum Versioning

Course definitions may change over time.

The platform should preserve which curriculum version a cohort used.

Example:

- Professional Course 2026 v1
- Professional Course 2027 v2

Existing project outputs must remain linked to the curriculum version under which they were created.

---

# 45. Workflow Decisions Captured

## Decision WF-001 — Sessions Are Workflow Containers

A session contains teaching + activities + project transformations, not only content.

**Status:** Required.

## Decision WF-002 — Outputs Become Inputs

Session artifacts must be directly reusable by later activities.

**Status:** Required.

## Decision WF-003 — Live and Async Use Same Artifact

The same work continues after class unless a new version is intentionally created.

**Status:** Required.

## Decision WF-004 — Instructor Case Study Uses Same Tooling

Case Study should use the same activity engine as participant projects.

**Status:** Required.

## Decision WF-005 — Gates Are Separate from Completion

Project readiness is distinct from educational completion.

**Status:** Required.

## Decision WF-006 — Advanced Course Continues Professional Project

The same Development Project should carry Invention Concept V2 into Advanced Course workflows.

**Status:** Required.

## Decision WF-007 — AI Role Depends on Activity

AI is context- and workflow-aware.

**Status:** Required.

## Decision WF-008 — Curriculum Must Be Configurable

Program/session/activity definitions should not be hard-coded wherever practical.

**Status:** Required.

---

# 46. Open Questions for Review

1. Should Workshop participants automatically receive a Development Project, or only when they choose an idea to continue?
2. Should Professional Course Session 1 store any mandatory reflection artifact?
3. Should SCAMPER homework be formally approved before Session 3?
4. Should Master approval be required at every Professional Course transition, or only selected milestones?
5. Should Session 5 team decisions require Master approval?
6. Should Session 7 Invention Concept V1 be a formal gate before Patent Search?
7. Should Patent Reading practice in Session 8 be stored as an assessed assignment?
8. Should Session 9 Patent Landscape Snapshot require instructor approval before Session 10 AI refinement?
9. Who may approve the Technical Development Gate in Advanced Session 3?
10. Who may approve Business and Market GO/MODIFY/STOP gates?
11. Should Advanced Session 8 Kanban continue as a permanent project board after the course?
12. Should Pitch Deck creation happen natively in the platform, or should the platform initially manage pitch structure/evidence and export to presentation tools?
13. Should Funding Strategy include an investor CRM in the first Advanced module, or later?
14. Are all Advanced Course PDFs now to be treated as final/locked curriculum, or current approved design input subject to later revision?

These questions should be resolved before implementation of course-specific workflows.

---

# 47. Required Next Document

The next document is:

# `07_MVP_SCOPE.md`

It must decide what we actually build first.

It should classify every major capability as:

- MUST HAVE — MVP
- SHOULD HAVE
- LATER
- OPTIONAL / EXPERIMENTAL

and define the first usable release that can validate:

- Development Project continuity,
- Personal + Team Workspaces,
- private team chat,
- team management,
- sharing,
- core invention tools,
- instructor review,
- evidence,
- versioning,
- AI assistance,
- course workflow.

---

# 48. Codex Workflow Rule

Codex must not implement course sessions as isolated static pages when the approved workflow requires structured project transformations.

For course-specific implementation:

1. Read the activity definition.
2. Resolve required input artifacts.
3. Check workspace permissions.
4. Create or resume the Activity Instance.
5. Save structured output.
6. Preserve provenance and history.
7. Route output into review if required.
8. Make approved output available to dependent activities.

If the curriculum and implementation appear inconsistent, Codex must flag the conflict instead of changing the curriculum silently.

---

# End of Document

**Current Status:** Draft v0.1 — Ready for Ahmad/FICI review.  
**Next Document After Approval:** `07_MVP_SCOPE.md`
