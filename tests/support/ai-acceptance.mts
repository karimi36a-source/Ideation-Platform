import assert from 'node:assert/strict';

// One acceptance catalogue, backed by existing executable scenarios. Missing
// evidence throws for every row, including all BLOCKER privacy/governance cases.
export const aiAcceptanceCases = [
 {id:'AT-AI-001',blocker:false,tests:['ai-activity-availability.test.ts','ai-task-registry.test.ts'],database:'ai-activity-availability.sql',marker:'M14.9 Activity AI configuration current-authorization independent-work projection PASS'},
 {id:'AT-AI-002',blocker:true,tests:['ai-context-builder.test.ts','ai-run-task.test.ts'],database:'ai-context-builder.sql',marker:'M14.8 AT-AI-002/003/004 LEAK-001/002/003 current-scope/exact-Snapshot/revocation/removal/role-only/Personal/Team/IDs/no-provider/no-output/no-usage PASS'},
 {id:'AT-AI-003',blocker:true,tests:['ai-context-builder.test.ts','ai-output-schema.test.ts'],database:'ai-output-rls.sql',marker:'M14.22 AI-output/reference RLS Personal/Team/current-membership/role-only/direct-ID/immutable/insert-update-delete/history PASS'},
 {id:'AT-AI-004',blocker:true,tests:['ai-run-task.test.ts','ai-context-builder.test.ts'],database:'ai-run-task.sql',marker:'M14.20 AT-AI-004 current-membership/completed-replay/new-key/output-reference-denial/history PASS'},
 {id:'AT-AI-005',blocker:false,tests:['ai-context-schema.test.ts','ai-context-builder.test.ts'],database:'ai-context-references.sql',marker:'M14.2 AT-AI-005 canonical-role-mapping/request-authority/exact-version/snapshot/hash/revocation/history/Personal/Team/removal/role-only/ID/joins/immutable/default-deny PASS'},
 {id:'AT-AI-006',blocker:true,tests:['ai-run-task.test.ts','ai-output-validation.test.ts'],database:'ai-outputs.sql',marker:'M14.1 immutable AI output/types/defaults/server-actor/Personal/Team/Activity/scope/RLS/removal/role-only/no-Evidence/no-Project-mutation PASS'},
 {id:'AT-AI-007',blocker:true,tests:['ai-artifact-revision.test.ts','ai-run-task.test.ts'],database:'ai-artifact-revision.sql',marker:'M14.16 AT-AI-007 generic-Draft/specialized-denial/approved-history/provenance/CAS/rollback/privacy PASS'},
 {id:'AT-AI-008',blocker:false,tests:['ai-conversion.test.ts'],database:'ai-conversion.sql',marker:'M14.15 AT-AI-008 Personal/Team/SCAMPER/Brainstorm/Gap/candidate/AI-provenance/confirmation/atomicity/retry/privacy/governance PASS'},
 {id:'AT-AI-009',blocker:false,tests:['ai-provider.test.ts','ai-run-task.test.ts'],database:'ai-run-task.sql',marker:'M14.21 AT-AI-009 failure-usage/no-project-mutation/no-output-orphans/authorized-retry PASS'},
] as const;
export const aiAcceptanceUnitFiles=[...new Set([
 ...aiAcceptanceCases.flatMap(row=>row.tests),
 'ai-acceptance-harness.test.ts','ai-active-template.test.ts','ai-model-profile-resolver.test.ts','ai-disposition.test.ts',
 'ai-prompt-templates.test.ts','ai-prompt-assembly.test.ts','ai-usage-schema.test.ts',
])].map(file=>'tests/unit/'+file);
export const aiAcceptanceDatabaseFlags=[
 '--ai-outputs','--ai-context','--ai-prompts','--ai-usage','--ai-builder',
 '--ai-availability','--ai-runtime','--ai-disposition','--ai-conversion',
 '--ai-artifact-revision','--ai-evidence-separation','--ai-shared-context',
 '--ai-brainstorm','--ai-rls','--ai-config-usage-rls',
];
const boundaryMarkers=[
 'M14.10 service-only exact-active-template reader/privacy PASS',
 'M14.11 independent-session begin serialization/atomic-save idempotency/exact-result/exact-provenance PASS',
 'M14.14 human-disposition/CAS/audit/rollback/immutability/verification/Personal/Team/role-only/removal PASS',
 'M14.15 independent-session exact-retry/conflicting-conversion/one-candidate/provenance/audit/canonical-edits PASS',
 'M14.17 AT-EV-002 real-AI/verified-source/summary/comparison/patent/candidate/artifact/no-Evidence-mutation/human-only PASS',
 'M14.18 AT-AI-LEAK-003 exact-frozen-Artifact/VIEW-COMMENT/siblings/revocation/history/membership/MASTER-expiry/no-source-mutation PASS',
 'M14.19 saved-output/reference requester-only/direct-ID/role-only/mixed-context/canonical-reveal/unchanged-history/normal-Team/Personal/privacy PASS',
 'M14.19 Brainstorm AI privacy, exact-entry provenance, canonical reveal and membership PASS',
 'M14.23 configuration/usage RLS server-only-template/self-only-current-scope/direct-ID/no-client-mutation/history/minimization PASS',
];
export function assertAiAcceptanceDatabase(stdout:string){
 for(const row of aiAcceptanceCases)assert(stdout.includes(row.marker),row.id+(row.blocker?' BLOCKER':'')+' database evidence missing');
 for(const marker of boundaryMarkers)assert(stdout.includes(marker),'M14 boundary regression missing: '+marker);
 const persisted=(prefix:string)=>{
  const line=stdout.split(/\r?\n/).map(value=>value.trim()).find(value=>value.startsWith(prefix));
  assert(line,'Canonical persisted row missing: '+prefix);
  return JSON.parse(line.slice(prefix.length));
 };
 const output=persisted('AI_OUTPUT_ROW=');
 assert.equal(output.verification_status,'UNVERIFIED');assert.equal(output.disposition,'KEEP_FOR_REVIEW');
 assert.equal(output.output_type,'ANALYSIS');assert(output.requested_by&&output.project_id&&output.workspace_id);
 const reference=persisted('AI_CONTEXT_ROW=');
 assert(reference.ai_output_id&&reference.entity_id&&reference.share_snapshot_id);
 assert.match(reference.included_snapshot_hash,/^[a-f0-9]{64}$/);assert.equal(reference.permission_scope.access,'SHARE_SNAPSHOT');
 assert.equal(persisted('AI_USAGE_ROW=').success_failure,'FAILURE');
 return aiAcceptanceCases.map(row=>({id:row.id,status:'PASS' as const,blocker:row.blocker,database:row.database,tests:row.tests}));
}
