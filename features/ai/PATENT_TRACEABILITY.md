# Patent AI traceability

The existing PATENT_RESEARCH_ASSISTANCE task now requires structured
source_observations with observation, source_reference, interpretation,
uncertainty, location_kind and location. Its assessment_scope is fixed to
TECHNICAL_OBSERVATIONS_ONLY. Each included Patent/Evidence source must be cited
using its ephemeral source-NNN alias, which maps to the exact saved canonical
Context Reference. Aliases grant no access and are not canonical source IDs.
The immutable Output's internal metadata preserves that alias-to-source/hash/
Snapshot binding, independent of later row ordering. Runtime display responses
do not expose the internal metadata or turn provenance into source access.

Numbered locators must be supported by the cited minimized source. CLAIM quotes
the saved claim_locator exactly; ABSTRACT and DESCRIPTION require their saved
source fields. No figure/paragraph/section locator is synthesized from model
knowledge. Missing locations use UNSPECIFIED plus an empty location and explicit
uncertainty. The alias and retained Context Reference remain the strongest source
identity. This does not assess whether a technical interpretation is true.

Prompt safeguards, a closed structured technical-only contract, grounded source
references and conservative response rejection work together. Patent-bearing
comparative/Session 10 tasks also reject prohibited legal-determination language.
The lexical rejection is deliberately conservative (including disclaimers using
the prohibited terms); it is not a general semantic/legal truth detector. Nothing
is stripped or rewritten to look compliant. Failure uses ordinary M14.21 telemetry
and retry handling, without saving Output/References or touching Patent/Evidence.

No provider call, legal decision engine, Evidence conversion, migration or new
authorization model is introduced. Prior saved Outputs/templates remain unchanged;
current runtime sends the registry schema. Existing current-source and frozen
Share authorization, RLS, removal and revocation rules remain authoritative.
