M14.9 server-only availability

Call getActivityAiAvailability({activityInstanceId, projectId, workspaceId, requestedTaskType?}). Unknown request fields are rejected. This read-only result is not an authorization token for later execution.

Explicit configuration lives in Activity Definition configuration.ai and its existing immutable start snapshot:
- enabled: true is required in both current and frozen configuration.
- allowed_tasks: optional registered task subset; current/frozen subsets intersect with canonical role and Activity method.
- independent_work_required: optional boolean. When true, proof must satisfy the frozen configuration.ai.completion_rule using the existing M7 {min_required_inputs, min_outputs} grammar. Missing, unsupported, empty or zero-only proof rules fail closed. Only exact canonical currently authorized Object references count; output authorship must match the actor. A changed current required rule cannot reuse old proof. General Activity completion is never proof.
- requires_revealed_pool: optional boolean for operations configured to require a revealed pool. A currently readable canonically revealed Brainstorm entry is required. This does not authorize hidden peer content; Context Builder remains authoritative for every selected source. Self-only assistance is not globally blocked before reveal.

Only active/revision_requested are eligible. Missing or unreadable Activities return the same safe denial. Role/task changes cannot expand a frozen execution. A trusted server composition hook permits usage by default until a canonical limiter exists; hook denial returns USAGE_LIMIT_REACHED. No hook or gate values are accepted from clients.

The narrow configuration RPC reuses current Activity/Project/Workspace authorization. It creates no provider request, context, output, usage event, membership or source access. No historical snapshot or curriculum seed is retrofitted.
