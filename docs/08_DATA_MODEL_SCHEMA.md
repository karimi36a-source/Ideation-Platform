# FICI Invention Education & Development Platform
## Data Model & Schema Specification

**Document:** `08_DATA_MODEL_SCHEMA.md`  
**Status:** Draft v0.1 — For Review  
**Depends on:** `01_PRODUCT_REQUIREMENTS.md`, `02_PLATFORM_ARCHITECTURE.md`, `03_ROLES_PERMISSIONS.md`, `04_WORKSPACE_TEAM_COLLABORATION.md`, `05_DEVELOPMENT_PROJECT_MODEL.md`, `06_COURSE_ACTIVITY_WORKFLOWS.md`, `07_MVP_SCOPE.md`  
**Purpose:** Convert the approved product, collaboration, curriculum, and MVP requirements into a concrete implementation-oriented data model before database technology, migrations, API contracts, or UI implementation are finalized.

---

# 1. Modeling Principles

The schema must preserve:

- stable object identity,
- project continuity,
- workspace isolation,
- team privacy,
- structured curriculum outputs,
- evidence separation,
- AI provenance,
- review and approval history,
- artifact-specific versioning,
- traceability,
- future extensibility.

The schema must not reduce the platform to:

```text
User
Course
File
Submission
```

The platform requires a connected development model.

---

# 2. Schema Layers

The implementation should conceptually contain these layers:

```text
IDENTITY & ACCESS
↓
ORGANIZATION / COURSE / COHORT
↓
WORKSPACE & TEAM
↓
DEVELOPMENT PROJECT
↓
ACTIVITY INSTANCES
↓
STRUCTURED DEVELOPMENT OBJECTS
↓
ARTIFACTS / VERSIONS
↓
EVIDENCE / AI / DECISIONS / FEEDBACK
↓
SHARING / AUDIT / NOTIFICATIONS
```

---

# 3. Global Record Requirements

Most persisted entities should include:

- `id`
- `created_at`
- `created_by`
- `updated_at`
- `updated_by`
- `archived_at` or equivalent soft-delete state where appropriate

Sensitive entities should additionally support:

- owning workspace
- owning project
- visibility
- status
- permission scope
- audit history

UUID-style stable identifiers are recommended conceptually, but exact database type is deferred to the technical architecture.

---

# 4. User Entity

## `users`

Represents an authenticated platform user.

Suggested fields:

- `id`
- `email`
- `display_name`
- `first_name`
- `last_name`
- `profile_image`
- `account_status`
- `timezone`
- `locale`
- `created_at`
- `updated_at`

Possible account statuses:

- invited
- active
- suspended
- archived

Authentication credentials should not be designed here; they may be managed by the selected authentication provider.

---

# 5. Role Entity

## `roles`

Initial values:

- ADMIN
- MASTER
- MENTOR
- STUDENT

Fields:

- `id`
- `code`
- `name`
- `description`
- `is_system_role`

---

# 6. Scoped Role Assignment

## `role_assignments`

A role must be scoped.

Fields:

- `id`
- `user_id`
- `role_id`
- `organization_id` nullable
- `program_id` nullable
- `cohort_id` nullable
- `team_id` nullable
- `project_id` nullable
- `starts_at`
- `ends_at`
- `status`
- `assigned_by`

This prevents the incorrect assumption that a Master has access to every cohort.

---

# 7. Organization Entity

## `organizations`

Initial deployment may use one FICI organization, but the model should support future expansion.

Fields:

- `id`
- `name`
- `slug`
- `status`
- `settings`

---

# 8. Program Entity

## `programs`

Examples:

- Innovation & Invention Workshop
- Professional Course
- Advanced Course

Fields:

- `id`
- `organization_id`
- `name`
- `code`
- `description`
- `program_type`
- `status`
- `current_curriculum_version_id`

---

# 9. Curriculum Version Entity

## `curriculum_versions`

Fields:

- `id`
- `program_id`
- `version_label`
- `status`
- `effective_from`
- `effective_to`
- `notes`

Possible statuses:

- draft
- approved
- retired

This allows future curriculum updates without altering historic cohort records.

---

# 10. Course Session Definition

## `session_definitions`

Fields:

- `id`
- `curriculum_version_id`
- `session_number`
- `title`
- `description`
- `learning_goal`
- `sequence`
- `status`

Examples:

- Professional Session 4 — Brainstorming & Problem Storming
- Advanced Session 8 — Agile & Startup Management Systems

---

# 11. Activity Definition

## `activity_definitions`

Defines reusable curriculum workflow.

Fields:

- `id`
- `session_definition_id`
- `name`
- `description`
- `method_type`
- `workspace_mode`
- `sequence`
- `instructions`
- `ai_role_code`
- `requires_review`
- `requires_approval`
- `completion_rule`
- `configuration`
- `status`

Possible `method_type` values:

- teaching
- reflection
- scamper
- brainstorming
- problem_storming
- voting
- affinity
- mind_map
- patent_research
- comparison
- validation
- roadmap
- kanban
- decision
- review
- custom

---

# 12. Activity Dependency

## `activity_dependencies`

Fields:

- `id`
- `activity_definition_id`
- `required_activity_definition_id`
- `dependency_type`
- `required_artifact_type`
- `is_mandatory`

Possible dependency types:

- completion
- approved_output
- artifact_available
- gate_passed

---

# 13. Cohort Entity

## `cohorts`

Fields:

- `id`
- `program_id`
- `curriculum_version_id`
- `name`
- `start_date`
- `end_date`
- `status`
- `primary_master_id`
- `settings`

---

# 14. Enrollment Entity

## `enrollments`

Fields:

- `id`
- `cohort_id`
- `user_id`
- `enrollment_role`
- `status`
- `joined_at`
- `completed_at`

Possible statuses:

- invited
- active
- completed
- withdrawn
- removed

---

# 15. Workspace Entity

## `workspaces`

All major work happens inside a workspace.

Fields:

- `id`
- `workspace_type`
- `name`
- `owner_user_id` nullable
- `team_id` nullable
- `cohort_id` nullable
- `project_id` nullable
- `status`
- `visibility`
- `settings`

Workspace types:

- PERSONAL
- TEAM
- MASTER
- SHARED
- CASE_STUDY

---

# 16. Team Entity

## `teams`

Fields:

- `id`
- `cohort_id`
- `name`
- `description`
- `status`
- `team_lead_user_id` nullable
- `master_user_id`
- `workspace_id`
- `created_by`
- `archived_at`

---

# 17. Team Membership

## `team_memberships`

Fields:

- `id`
- `team_id`
- `user_id`
- `membership_role`
- `joined_at`
- `left_at`
- `status`
- `added_by`
- `removed_by` nullable

Possible membership roles:

- member
- team_lead
- mentor

Historical memberships must remain persisted after removal.

---

# 18. Development Project

## `development_projects`

Fields:

- `id`
- `name`
- `description`
- `project_type`
- `owner_user_id` nullable
- `owner_team_id` nullable
- `primary_workspace_id`
- `status`
- `current_stage`
- `confidentiality_level`
- `created_at`
- `archived_at`

Project types:

- individual
- team
- instructor_case_study

Project statuses:

- active
- paused
- completed
- archived

---

# 19. Project Membership

## `project_memberships`

Fields:

- `id`
- `project_id`
- `user_id`
- `project_role`
- `starts_at`
- `ends_at`
- `status`

This is distinct from Team Membership.

---

# 20. Program / Project Participation

## `project_program_links`

Allows the same project to continue across programs.

Fields:

- `id`
- `project_id`
- `program_id`
- `cohort_id`
- `entered_at`
- `completed_at`
- `entry_artifact_version_id`
- `exit_artifact_version_id`

Example:

```text
Project A
→ Professional Course
→ Advanced Course
```

---

# 21. Generic Development Object

A common object layer is recommended for project elements.

## `development_objects`

Fields:

- `id`
- `project_id`
- `workspace_id`
- `object_type`
- `title`
- `content`
- `status`
- `verification_status`
- `origin_type`
- `origin_reference_id`
- `created_by`
- `current_version_number`
- `archived_at`
- `metadata`

Possible `object_type` values:

- PROBLEM
- IDEA
- SOLUTION
- FEATURE
- FUNCTION
- COMPONENT
- SYSTEM
- SUBSYSTEM
- REQUIREMENT
- ASSUMPTION
- CONSTRAINT
- RISK
- GAP
- OPEN_QUESTION
- VALIDATION_QUESTION
- CUSTOMER_INSIGHT
- TASK
- MILESTONE
- FINANCIAL_ASSUMPTION
- PITCH_CLAIM
- OTHER

Specialized typed tables may supplement this generic layer when required.

---

# 22. Object Relationships

## `development_object_relationships`

Fields:

- `id`
- `project_id`
- `source_object_id`
- `target_object_id`
- `relationship_type`
- `description`
- `created_by`
- `status`

Relationship values may include:

- SOLVES
- IMPLEMENTS
- SUPPORTS
- DEPENDS_ON
- BELONGS_TO
- CONNECTED_TO
- DERIVED_FROM
- VALIDATES
- CONTRADICTS
- TESTED_BY
- EVIDENCE_FOR
- EVIDENCE_AGAINST
- REPLACES
- SUPERSEDES
- IDENTIFIED_IN

---

# 23. Specialized Problem Data

## `problem_details`

Optional one-to-one extension of a Problem object.

Fields:

- `development_object_id`
- `problem_category`
- `priority`
- `perspective`

Problem categories may include:

- user
- functional
- technical
- cost
- safety
- environmental
- accessibility
- maintenance
- manufacturing
- market

---

# 24. Specialized Idea Data

## `idea_details`

Fields:

- `development_object_id`
- `technique`
- `acceptance_state`
- `original_private_workspace_id`

Acceptance states:

- private
- shared
- candidate
- accepted
- rejected
- archived

---

# 25. SCAMPER Entry

## `scamper_entries`

Fields:

- `id`
- `activity_instance_id`
- `project_id`
- `workspace_id`
- `created_by`
- `scamper_type`
- `original_element`
- `proposed_change`
- `result_text`
- `idea_object_id` nullable
- `status`

SCAMPER types:

- SUBSTITUTE
- COMBINE
- ADAPT
- MODIFY
- PUT_TO_ANOTHER_USE
- ELIMINATE
- REVERSE_REARRANGE

---

# 26. Artifact Entity

## `artifacts`

Artifacts are higher-level structured outputs.

Fields:

- `id`
- `project_id`
- `workspace_id`
- `artifact_type`
- `title`
- `status`
- `current_version_id`
- `created_by`
- `activity_instance_id`
- `review_required`
- `approval_required`

Artifact examples:

- PROBLEM_BANK
- SOLUTION_BANK
- TEAM_DECISION_RECORD
- INVENTION_STRUCTURE
- GAP_LIST
- MIND_MAP
- INVENTION_CONCEPT
- PATENT_LANDSCAPE
- VALIDATION_PLAN
- RISK_MAP
- PRODUCT_ROADMAP
- BUSINESS_CASE
- MARKET_VALIDATION_MAP
- TEAM_DEVELOPMENT_MAP
- GTM_MAP
- FINANCIAL_MAP
- PITCH_PACKAGE
- FUNDING_STRATEGY

---

# 27. Artifact Version

## `artifact_versions`

Fields:

- `id`
- `artifact_id`
- `version_number`
- `version_label`
- `content_snapshot`
- `change_summary`
- `status`
- `created_by`
- `created_at`
- `previous_version_id`
- `approved_by` nullable
- `approved_at` nullable
- `approval_note` nullable

Statuses:

- DRAFT
- SUBMITTED
- UNDER_REVIEW
- REVISION_REQUESTED
- APPROVED
- CURRENT
- SUPERSEDED
- ARCHIVED

---

# 28. Artifact/Object Membership

## `artifact_object_links`

Links artifacts to structured development objects.

Fields:

- `id`
- `artifact_id`
- `artifact_version_id`
- `development_object_id`
- `role_in_artifact`
- `sequence`
- `metadata`

Example:

Mind Map V2 may reference:

- System S1
- Component C4
- Gap G3

---

# 29. Activity Instance

## `activity_instances`

Represents an actual execution of an Activity Definition.

Fields:

- `id`
- `activity_definition_id`
- `cohort_id`
- `project_id`
- `workspace_id`
- `team_id` nullable
- `started_by`
- `started_at`
- `completed_at`
- `status`
- `configuration_snapshot`

Statuses:

- not_started
- active
- submitted
- under_review
- revision_requested
- completed
- archived

---

# 30. Activity Participants

## `activity_participants`

Fields:

- `id`
- `activity_instance_id`
- `user_id`
- `participant_role`
- `joined_at`
- `completed_at`

---

# 31. Activity Input Link

## `activity_inputs`

Fields:

- `id`
- `activity_instance_id`
- `input_type`
- `artifact_id` nullable
- `artifact_version_id` nullable
- `development_object_id` nullable
- `evidence_id` nullable
- `required`

This makes workflow dependencies explicit.

---

# 32. Activity Output Link

## `activity_outputs`

Fields:

- `id`
- `activity_instance_id`
- `output_type`
- `artifact_id` nullable
- `development_object_id` nullable
- `decision_id` nullable
- `evidence_id` nullable

---

# 33. Brainstorming Entry

## `brainstorm_entries`

Fields:

- `id`
- `activity_instance_id`
- `project_id`
- `workspace_id`
- `created_by`
- `content`
- `status`
- `revealed_at` nullable
- `development_object_id` nullable
- `parent_entry_id` nullable

This supports private generation followed by reveal.

---

# 34. Affinity Group

## `affinity_groups`

Fields:

- `id`
- `activity_instance_id`
- `name`
- `description`
- `sequence`
- `created_by`

## `affinity_group_items`

Fields:

- `id`
- `affinity_group_id`
- `development_object_id` nullable
- `brainstorm_entry_id` nullable
- `position`
- `added_by`

---

# 35. Mind Map

## `mind_maps`

Fields:

- `id`
- `artifact_id`
- `artifact_version_id`
- `root_node_id`

## `mind_map_nodes`

Fields:

- `id`
- `mind_map_id`
- `node_type`
- `label`
- `development_object_id` nullable
- `parent_node_id` nullable
- `position_data`
- `metadata`
- `created_by`

## `mind_map_edges`

Fields:

- `id`
- `mind_map_id`
- `source_node_id`
- `target_node_id`
- `edge_type`
- `label`
- `metadata`

---

# 36. Voting Session

## `voting_sessions`

Fields:

- `id`
- `activity_instance_id`
- `voting_type`
- `status`
- `vote_limit`
- `anonymous`
- `reveal_mode`
- `created_by`
- `opened_at`
- `closed_at`

Voting types:

- DOT_VOTE
- FIST_TO_FIVE
- PLANNING_POKER

MVP may initially implement DOT_VOTE only.

---

# 37. Voting Option

## `voting_options`

Fields:

- `id`
- `voting_session_id`
- `development_object_id` nullable
- `label`
- `description`
- `sequence`

---

# 38. Vote

## `votes`

Fields:

- `id`
- `voting_session_id`
- `voting_option_id`
- `user_id`
- `value`
- `created_at`
- `revealed_at` nullable

For private-before-reveal activities, access rules must hide unrevealed values from other participants.

---

# 39. Decision Record

## `decisions`

Fields:

- `id`
- `project_id`
- `workspace_id`
- `activity_instance_id` nullable
- `title`
- `question`
- `method`
- `outcome`
- `reasoning`
- `status`
- `decision_owner_user_id`
- `decided_at`

---

# 40. Decision Option

## `decision_options`

Fields:

- `id`
- `decision_id`
- `label`
- `description`
- `selected`
- `development_object_id` nullable

---

# 41. Decision Participants

## `decision_participants`

Fields:

- `id`
- `decision_id`
- `user_id`
- `role`
- `position` nullable
- `comment` nullable

---

# 42. Decision Links

## `decision_links`

Links decisions to:

- evidence,
- artifacts,
- development objects,
- AI outputs,
- voting sessions.

Fields:

- `id`
- `decision_id`
- `linked_entity_type`
- `linked_entity_id`
- `relationship_type`

---

# 43. Evidence Record

## `evidence`

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

Evidence types:

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

Verification statuses:

- UNVERIFIED
- PARTIALLY_VERIFIED
- VERIFIED
- CONTRADICTED
- NEEDS_REVIEW

---

# 44. Evidence Links

## `evidence_links`

Fields:

- `id`
- `evidence_id`
- `linked_entity_type`
- `linked_entity_id`
- `relationship_type`
- `notes`

Relationship examples:

- SUPPORTS
- CONTRADICTS
- VALIDATES
- SOURCE_FOR
- RELATED_TO

---

# 45. Patent Record

## `patent_records`

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

---

# 46. Patent Search Log

## `patent_search_logs`

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

---

# 47. Patent Comparison

## `patent_comparisons`

Should be available as a future or SHOULD-HAVE structured model.

Fields:

- `id`
- `project_id`
- `patent_record_id`
- `comparison_type`
- `summary`
- `created_by`
- `status`

Detailed row-level comparison entities may be added later.

---

# 48. Feedback

## `feedback_items`

Fields:

- `id`
- `project_id`
- `target_entity_type`
- `target_entity_id`
- `target_version_id` nullable
- `author_user_id`
- `feedback_type`
- `content`
- `status`
- `created_at`
- `resolved_at`

Feedback types:

- COMMENT
- QUESTION
- CORRECTION
- SUGGESTION
- REVISION_REQUEST
- APPROVAL_NOTE
- WARNING

---

# 49. Submission

## `submissions`

Fields:

- `id`
- `activity_instance_id`
- `artifact_id`
- `artifact_version_id`
- `submitted_by`
- `submitted_at`
- `status`
- `reviewer_user_id`

Statuses:

- SUBMITTED
- UNDER_REVIEW
- REVISION_REQUESTED
- APPROVED
- REJECTED

---

# 50. Review Action

## `review_actions`

Fields:

- `id`
- `submission_id`
- `reviewer_user_id`
- `action_type`
- `note`
- `created_at`

Actions:

- COMMENTED
- REQUESTED_REVISION
- APPROVED
- REOPENED
- REJECTED

---

# 51. AI Output

## `ai_outputs`

Fields:

- `id`
- `project_id`
- `workspace_id`
- `activity_instance_id` nullable
- `requested_by`
- `ai_role`
- `task_type`
- `prompt_text`
- `response_text`
- `output_type`
- `verification_status`
- `disposition`
- `created_at`
- `model_provider_reference` nullable
- `metadata`

Output types:

- ANALYSIS
- SUGGESTION
- HYPOTHESIS
- DRAFT
- COMPARISON
- CLASSIFICATION
- SUMMARY
- CANDIDATE_SOLUTION

Disposition:

- KEEP_FOR_REVIEW
- ACCEPT_AS_CANDIDATE
- MODIFIED
- REJECTED
- INVESTIGATE_FURTHER
- CONVERTED_TO_PROJECT_OBJECT

---

# 52. AI Context Reference

## `ai_context_references`

Do not rely only on storing one large prompt.

Fields:

- `id`
- `ai_output_id`
- `entity_type`
- `entity_id`
- `context_role`
- `included_snapshot_hash` or equivalent
- `permission_scope`

Context roles:

- CURRENT_PROJECT
- CURRENT_ARTIFACT
- PRIOR_APPROVED_OUTPUT
- TEAM_DECISION
- INSTRUCTOR_FEEDBACK
- EVIDENCE
- PATENT
- GAP
- COURSE_CONTEXT

This preserves explainability and context provenance.

---

# 53. Chat Channel

## `chat_channels`

Fields:

- `id`
- `channel_type`
- `workspace_id`
- `team_id` nullable
- `cohort_id` nullable
- `name`
- `status`
- `created_at`

Channel types:

- TEAM
- COHORT
- MASTER_TEAM
- ACTIVITY
- OTHER

MVP priority: TEAM.

---

# 54. Chat Membership

## `chat_memberships`

Fields:

- `id`
- `chat_channel_id`
- `user_id`
- `access_level`
- `joined_at`
- `left_at`

---

# 55. Chat Message

## `chat_messages`

Fields:

- `id`
- `chat_channel_id`
- `sender_user_id`
- `parent_message_id` nullable
- `content`
- `message_type`
- `created_at`
- `edited_at`
- `deleted_at`

Message types:

- TEXT
- FILE
- LINK
- SYSTEM

Hard deletion should be restricted.

---

# 56. File Record

## `files`

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

Storage implementation is deferred.

---

# 57. File Link

## `file_links`

Allows one file to be connected to multiple objects.

Fields:

- `id`
- `file_id`
- `entity_type`
- `entity_id`
- `relationship_type`

Examples:

- ATTACHMENT
- EVIDENCE_SOURCE
- ARTIFACT_FILE
- CHAT_ATTACHMENT
- REFERENCE

---

# 58. Share Record

## `shares`

Every explicit sharing action should be represented.

Fields:

- `id`
- `source_workspace_id`
- `shared_entity_type`
- `shared_entity_id`
- `shared_by`
- `destination_type`
- `destination_id`
- `permission_level`
- `share_mode`
- `created_at`
- `revoked_at`
- `revoked_by`

Destination types:

- USER
- TEAM
- MASTER
- COHORT
- WORKSPACE

Permission levels:

- VIEW
- COMMENT
- COLLABORATE

Share modes:

- LIVE_REFERENCE
- SNAPSHOT

MVP cross-team sharing can initially support VIEW/COMMENT and SNAPSHOT or LIVE_REFERENCE.

---

# 59. Share Snapshot

If a frozen share is required:

## `share_snapshots`

Fields:

- `id`
- `share_id`
- `source_version_id`
- `snapshot_data`
- `created_at`

---

# 60. Notification

## `notifications`

Fields:

- `id`
- `recipient_user_id`
- `notification_type`
- `title`
- `body`
- `entity_type`
- `entity_id`
- `read_at`
- `created_at`

MVP may implement only selected notification types.

---

# 61. Change Log

## `change_log`

Fields:

- `id`
- `project_id`
- `entity_type`
- `entity_id`
- `previous_version_id` nullable
- `new_version_id` nullable
- `change_type`
- `change_summary`
- `reason`
- `changed_by`
- `related_decision_id` nullable
- `related_evidence_id` nullable
- `related_ai_output_id` nullable
- `created_at`

---

# 62. Audit Event

## `audit_events`

Security / administration log.

Fields:

- `id`
- `actor_user_id`
- `event_type`
- `entity_type`
- `entity_id`
- `scope_type`
- `scope_id`
- `metadata`
- `created_at`

Events should include:

- TEAM_CREATED
- MEMBER_ADDED
- MEMBER_REMOVED
- ROLE_ASSIGNED
- SHARE_CREATED
- SHARE_REVOKED
- APPROVAL_GRANTED
- PERMISSION_CHANGED
- ARTIFACT_ARCHIVED

---

# 63. Development Gate

## `development_gates`

Fields:

- `id`
- `project_id`
- `gate_type`
- `activity_instance_id` nullable
- `status`
- `outcome`
- `reasoning`
- `reviewer_user_id`
- `decided_at`

Gate types:

- INVENTION_READINESS
- TECHNICAL_DEVELOPMENT
- BUSINESS_FEASIBILITY
- MARKET_VALIDATION
- INVESTMENT_READINESS

Outcomes:

- GO
- MODIFY
- HOLD
- STOP
- MORE_EVIDENCE_REQUIRED

---

# 64. Gate Evidence

## `gate_evidence_links`

Fields:

- `id`
- `development_gate_id`
- `evidence_id`
- `role`

---

# 65. Task / Kanban Data

## `tasks`

Fields:

- `id`
- `project_id`
- `workspace_id`
- `title`
- `description`
- `assigned_to_user_id` nullable
- `status`
- `priority`
- `due_date`
- `related_object_id` nullable
- `related_milestone_id` nullable
- `created_by`

Task statuses:

- BACKLOG
- TODO
- DOING
- REVIEW
- DONE
- BLOCKED

This is SHOULD-HAVE for MVP / useful for Advanced Course.

---

# 66. Milestones

## `milestones`

Fields:

- `id`
- `project_id`
- `name`
- `description`
- `target_date`
- `status`
- `related_gate_id` nullable

---

# 67. Requirement Extensions

Requirements can use `development_objects`, with optional specialized data.

## `requirement_details`

Fields:

- `development_object_id`
- `requirement_type`
- `priority`
- `validation_method`
- `validation_status`

Requirement types:

- FUNCTIONAL
- PERFORMANCE
- USER
- SAFETY
- ENVIRONMENTAL
- MANUFACTURING
- COST
- REGULATORY

---

# 68. Risk Extensions

## `risk_details`

Fields:

- `development_object_id`
- `risk_category`
- `likelihood`
- `impact`
- `severity`
- `mitigation`
- `owner_user_id`

---

# 69. Test / Experiment

## `tests`

Fields:

- `id`
- `project_id`
- `workspace_id`
- `name`
- `objective`
- `hypothesis`
- `method`
- `conditions`
- `metrics`
- `success_criteria`
- `failure_criteria`
- `status`
- `owner_user_id`
- `created_by`

---

# 70. Test Result

## `test_results`

Fields:

- `id`
- `test_id`
- `summary`
- `outcome`
- `interpretation`
- `verification_status`
- `evidence_id` nullable
- `created_by`
- `created_at`

---

# 71. Current Project Baseline

The baseline should not be stored as one giant document.

## `project_baseline_items`

Fields:

- `id`
- `project_id`
- `baseline_type`
- `artifact_id`
- `artifact_version_id`
- `effective_from`
- `effective_to`
- `set_by`

Examples:

- CURRENT_INVENTION_CONCEPT
- CURRENT_MIND_MAP
- CURRENT_ARCHITECTURE_MAP
- CURRENT_REQUIREMENTS
- CURRENT_PRODUCT_ROADMAP
- CURRENT_BUSINESS_CASE

---

# 72. Open Questions Register

Open questions can use the generic Development Object model, but a dedicated queryable view should expose:

- question,
- owner,
- priority,
- status,
- related object,
- next action.

Statuses:

- OPEN
- ASSIGNED
- INVESTIGATING
- RESOLVED
- DEFERRED

---

# 73. Verification Register

The platform should provide a queryable register over objects that require verification.

It may be implemented as a view over:

- assumptions,
- AI outputs,
- evidence,
- pitch claims,
- technical conclusions,
- market assumptions.

No separate table is required unless implementation needs it.

---

# 74. Human-Readable IDs

The platform may optionally display project-scoped labels such as:

- P-001 Problem
- S-003 Solution
- C-008 Component
- EV-014 Evidence
- D-006 Decision
- G-004 Gap

These labels should be separate from the immutable database primary key.

## `project_object_counters`

Optional implementation helper:

- `project_id`
- `object_type`
- `next_number`

---

# 75. Permission Evaluation Inputs

Authorization decisions should be based on data such as:

- user role assignment,
- enrollment,
- team membership,
- project membership,
- workspace ownership,
- explicit share,
- artifact ownership,
- assignment as Master/Mentor.

Do not encode authorization only into frontend visibility.

Backend/data-layer authorization is mandatory.

---

# 76. Privacy Boundary

The following must never be globally queryable by normal student users:

- another student's Personal Workspace,
- another team's private content,
- another team's private chat,
- unshared AI output,
- restricted instructor notes.

All relevant entities must contain enough scope information for authorization enforcement.

---

# 77. Soft Delete / Archive Rules

Prefer archival over destructive deletion for:

- Development Projects
- Teams
- Artifacts
- Approved Versions
- Decisions
- Evidence
- Feedback
- Chat history associated with formal project activity

Personal temporary drafts may allow deletion according to future policy.

---

# 78. Referential Integrity Rules

Examples:

1. Artifact Version cannot exist without Artifact.
2. Activity Instance must reference an Activity Definition.
3. Team Workspace must reference a valid Team.
4. A Vote must reference a valid Voting Session.
5. AI Context Reference must point to an entity the requester was authorized to access at generation time.
6. Evidence links must not point to permanently deleted entities.
7. Removing Team Membership must not cascade-delete contributions.
8. Archiving Project must not destroy versions, decisions, or evidence.

---

# 79. MVP Entity Priority

## MUST HAVE — Initial Implementation

- users
- roles
- role_assignments
- programs
- curriculum_versions
- session_definitions
- activity_definitions
- cohorts
- enrollments
- workspaces
- teams
- team_memberships
- development_projects
- project_memberships
- development_objects
- development_object_relationships
- scamper_entries
- artifacts
- artifact_versions
- artifact_object_links
- activity_instances
- activity_participants
- activity_inputs
- activity_outputs
- brainstorm_entries
- affinity_groups
- affinity_group_items
- mind_maps
- mind_map_nodes
- mind_map_edges
- voting_sessions
- voting_options
- votes
- decisions
- decision_options
- evidence
- evidence_links
- patent_records
- patent_search_logs
- feedback_items
- submissions
- review_actions
- ai_outputs
- ai_context_references
- chat_channels
- chat_memberships
- chat_messages
- files
- file_links
- shares
- change_log
- audit_events

## SHOULD HAVE

- notifications
- development_gates
- tasks
- milestones
- tests
- test_results
- patent comparison structures

## LATER

- finance-specialized entities
- investor CRM
- advanced fundraising pipeline
- advanced market research datasets
- full analytics warehouse

---

# 80. High-Level Relationship Map

```text
USER
├── ROLE ASSIGNMENT
├── ENROLLMENT
├── TEAM MEMBERSHIP
└── PROJECT MEMBERSHIP

PROGRAM
└── CURRICULUM VERSION
    └── SESSION DEFINITION
        └── ACTIVITY DEFINITION
            └── ACTIVITY INSTANCE

COHORT
├── ENROLLMENTS
├── TEAMS
└── ACTIVITY INSTANCES

TEAM
├── TEAM MEMBERSHIPS
├── TEAM WORKSPACE
├── TEAM CHAT
└── DEVELOPMENT PROJECT

DEVELOPMENT PROJECT
├── DEVELOPMENT OBJECTS
├── ARTIFACTS
├── EVIDENCE
├── PATENT RECORDS
├── DECISIONS
├── AI OUTPUTS
├── CHANGE LOG
└── VERSIONS

ARTIFACT
└── ARTIFACT VERSION
    ├── DEVELOPMENT OBJECT LINKS
    ├── FEEDBACK
    ├── SUBMISSIONS
    └── REVIEW ACTIONS

AI OUTPUT
└── AI CONTEXT REFERENCES

SHARE
└── SELECTED ENTITY + DESTINATION + PERMISSION
```

---

# 81. Data Model Decisions Captured

## DM-001 — Stable Structured Objects

Problems, solutions, evidence, decisions, artifacts, and other major project elements must have stable IDs.

**Status:** Required.

## DM-002 — Project and Workspace Are Separate

The Development Project stores long-term project state; Workspace controls collaboration scope.

**Status:** Required.

## DM-003 — Role + Scope Authorization

Roles are not global permission shortcuts.

**Status:** Required.

## DM-004 — Artifact Version Is First-Class

Approved and historical versions must be stored explicitly.

**Status:** Required.

## DM-005 — Sharing Is Explicit Data

Sharing must be stored as a permission-bearing record, not inferred from copying content.

**Status:** Required.

## DM-006 — AI Context Provenance

Saved AI outputs should retain references to the context used to produce them.

**Status:** Required.

## DM-007 — Team Removal Does Not Delete History

Membership history and authored contributions survive member removal.

**Status:** Required.

## DM-008 — Curriculum Versioning

Cohorts must remain tied to the curriculum version they used.

**Status:** Required.

## DM-009 — Evidence and AI Are Separate

AI output is never stored as evidence merely because it contains factual language.

**Status:** Required.

## DM-010 — Generic + Specialized Object Model

Use a common Development Object foundation with specialized extensions only where needed.

**Status:** Recommended.

---

# 82. Open Questions Before Database Finalization

1. Should the database use a generic `development_objects` table as the primary model, or separate tables for Problem, Solution, Feature, etc.?
2. Should Mind Map state be stored as normalized nodes/edges only, or also include a serialized visual snapshot for performance?
3. Should chat message editing be allowed after posting?
4. Should Master have permanent access to archived team chat?
5. Should personal AI outputs be retained by default or only when the user saves them?
6. Should artifact approval automatically set the corresponding project baseline item?
7. Should cross-team sharing default to snapshot or live reference?
8. Do we need organization-level tenancy in MVP, or can FICI be the only organization initially while preserving organization IDs?
9. Should every project object receive a human-readable code such as P-001/C-001?
10. Should submissions point only to Artifact Versions, or also directly to individual Development Objects?
11. Should rejected ideas remain searchable by default or be hidden under archive?
12. Which audit events are legally/security critical enough to be immutable?
13. How long should archived chat and AI history be retained?
14. Should evidence verification be limited to Master/Mentor roles, or can a student/team mark evidence verified?

These must be resolved before `10_DATABASE_SCHEMA.md` / migrations are treated as final implementation instructions.

---

# 83. Required Next Document

The next document is:

# `09_AI_ASSISTANT_SPEC.md`

It will define:

- AI roles,
- context assembly,
- permissions,
- task-specific behavior,
- evidence separation,
- AI output lifecycle,
- human approval,
- prompt architecture,
- project memory/context,
- cost controls,
- provider abstraction,
- safeguards against cross-team context leakage.

After that, the technical architecture can select actual infrastructure and implementation technologies.

---

# 84. Codex Data Rule

Codex must not:

- collapse all Development Project state into one mutable JSON document,
- implement permissions only in the frontend,
- delete project history when memberships change,
- treat AI responses as verified evidence,
- overwrite approved artifacts,
- expose Team Workspace records across teams,
- use a generic file upload as a substitute for structured curriculum outputs,
- hard-code activity logic so tightly that future curriculum versions require database redesign.

When implementation requires simplifying the model, Codex must document the trade-off and request approval before changing the approved schema intent.

---

# End of Document

**Current Status:** Draft v0.1 — Ready for Ahmad/FICI review.  
**Next Document After Approval:** `09_AI_ASSISTANT_SPEC.md`
