M14.10 Prompt Assembly

assembleAiPrompt accepts the Context Builder selectors with required activityInstanceId and optional userInstruction (12,000-character bound, NFC/trim). It accepts no prebuilt context, template/version, role, schema, model or policy overrides. It is a server-only module, not a client-callable Server Action.

Assembly uses fresh Activity AI availability, canonical resume instructions, exact active M14.3 template, M14.7 Task Contract, and only the authorized M14.8 Builder payload. It never traverses references. Those same services revalidate selected state before returning; the result remains ephemeral and is not reusable authorization for later execution.

Seven ordered layers separate FICI rules, role, Activity instructions, Project data, Evidence/source data, current task, and output format. Provider instructions contain only server-owned instructions and data placeholders; the input envelope contains explicitly labeled source/user data. Reference labels map to internal provenance candidates outside provider input. Structural separation cannot guarantee semantic prompt-injection immunity.

Task output schema is authoritative. An identical template schema is compatible; a different generic template schema does not override the Task Contract. Template ID/version and compatibility are retained in internal metadata. No provider output is validated here.

The active-template loader uses the existing server-only Supabase secret credential and a service-role-only exact active-template RPC. It never loads caller Project data with that credential. Authenticated/anonymous clients retain no template-read access. No public route or prompt display is added. No prompt, signed token, output, context reference or usage event is persisted; no provider is called.
