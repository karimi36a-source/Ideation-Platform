import {testStudentCurrentWork} from './test-current-work.mjs';
import {testEmailProviderIsolation} from './test-email-provider.mjs';
import {testCommentNotificationCommit} from './test-comment-notifications.mjs';
import {testApprovalNotificationCommit} from './test-approval-notifications.mjs';
import {testRevisionNotificationCommit} from './test-revision-notifications.mjs';
import {testSubmissionNotificationCommit} from './test-submission-notifications.mjs';
import {testShareNotificationCommit} from './test-share-notifications.mjs';
import {testNotificationCommit} from './test-notification-realtime.mjs';
import {testAiConversionConcurrency} from './test-ai-conversion.mjs';
import {testAiArtifactRevisionConcurrency} from './test-ai-artifact-revision.mjs';
import {testAiRuntimeConcurrency} from './test-ai-runtime.mjs';
import {testAiUsageEvents} from './test-ai-usage-events.mjs';
import {testAiPromptTemplates} from './test-ai-prompt-templates.mjs';
import {testShareComments} from './test-share-comments.mjs';
import {testShareRevoke} from './test-share-revoke.mjs';
import {testSharedFiles} from './test-shared-files.mjs';
import {testMindMapShare} from './test-mind-map-share.mjs';
import {testShareRls} from './test-share-rls.mjs';
import {testSharingPrivacy} from './test-sharing-privacy.mjs';
import {testShareHistory} from './test-share-history.mjs';
import {testShareView} from './test-share-view.mjs';
import {testPersonalSharing} from "./test-personal-sharing.mjs";
import {testShareEntityConcurrency} from "./test-share-entity.mjs";
import {session9Fixture} from './session9-fixture.mjs';
import {testActivityResearch} from './test-activity-research.mjs';
import {session8Fixture} from './session8-fixture.mjs';
import {testSession8Reading} from './test-session8-reading.mjs';
import {testDecisionEvidence} from './test-decision-evidence.mjs';
import {testPatentWorkspace} from './test-patent-workspace.mjs';
import {testPatentEvidenceService} from "./test-patent-evidence-service.mjs";
import {testPatentSearchService} from "./test-patent-search-service.mjs";
import {testPatentCreateService} from "./test-patent-create-service.mjs";
import {testFileLinks} from "./test-file-links.mjs";
import {testFileUploadService} from "./test-file-upload-service.mjs";
import {testEvidenceVerificationConcurrency} from "./test-evidence-verification.mjs";
import {scanEvidenceCreationPaths} from "./scan-evidence-creation-paths.mjs";
import {testEvidenceCreateService} from "./test-evidence-create-service.mjs";
import {testEvidenceLinkConcurrency} from "./test-evidence-links.mjs";
import {testSession7Integration} from "./test-session7-integration.mjs";
import {testSession6Integration} from "./test-session6-integration.mjs";
import {testCollaborativeEditAcceptance} from "./test-collaborative-edit-acceptance.mjs";
import {testMindMapRls} from "./test-mind-map-rls.mjs";
import {testSession7Outputs} from "./test-session7-outputs.mjs";
import {testSession6Outputs} from "./test-session6-outputs.mjs";
import {testMindMapClassification} from "./test-mind-map-classification.mjs";
import {testMindMapVersion} from "./test-mind-map-version.mjs";
import {testMindMapDraft} from "./test-mind-map-draft.mjs";
import {testMindMapNodeRemoval} from "./test-mind-map-node-removal.mjs";
import {testMindMapCollaboration} from "./test-mind-map-collaboration.mjs";
import {testMindMapEdges} from "./test-mind-map-edges.mjs";
import {testMindMapNodes} from "./test-mind-map-nodes.mjs";
import {testMindMapCreation} from "./test-mind-map-creation.mjs";
import {testGapCapture} from "./test-gap-capture.mjs";
import {testAffinityStructure} from "./test-affinity-structure.mjs";
import {testAffinityCollaboration} from "./test-affinity-collaboration.mjs";
import {affinityItemFixture} from "./affinity-item-fixture.mjs";
import {testAffinityItemConcurrency} from "./test-affinity-item-concurrency.mjs";
import {affinityOperationFixture} from "./affinity-operation-fixture.mjs";
import {testAffinityConcurrency} from "./test-affinity-concurrency.mjs";
import {testM10ConcurrencyHardening} from "./test-m10-concurrency-hardening.mjs";
import {testSession5Integration} from "./test-session5-integration.mjs";
import {testVotingVoteCloseConcurrency} from "./test-voting-vote-close-concurrency.mjs";
import {testDecisionSupersessionConcurrency} from "./test-decision-supersession-concurrency.mjs";
import {decisionArtifactFixture} from "./decision-artifact-fixture.mjs";
import {testDecisionArtifactConcurrency} from "./test-decision-artifact-concurrency.mjs";
import {testDecisionLinkConcurrency} from "./test-decision-link-concurrency.mjs";
import { command, suite } from "./db-test-diagnostics.mjs";
import {testDecisionFinalizationConcurrency as testDecisionFinalizationConcurrencyImplementation} from "./test-decision-finalization-concurrency.mjs";
import {testVotingCloseConcurrency as testVotingCloseConcurrencyImplementation} from "./test-voting-close-concurrency.mjs";
import {testVotingRevealConcurrency as testVotingRevealConcurrencyImplementation} from "./test-voting-reveal-concurrency.mjs";
import {testVotingCastConcurrency as testVotingCastConcurrencyImplementation} from "./test-voting-cast-concurrency.mjs";
import {testVotingOpeningConcurrency as testVotingOpeningConcurrencyImplementation} from "./test-voting-opening-concurrency.mjs";
import {votingCreationFixture} from "./voting-creation-fixture.mjs";
import {testSession4Integration as testSession4IntegrationImplementation} from "./test-session4-integration.mjs";
import {testM9BankReconnect as testM9BankReconnectImplementation} from "./test-m9-bank-reconnect.mjs";
import {testM9ActivityReconnect as testM9ActivityReconnectImplementation} from "./test-m9-activity-reconnect.mjs";
import {m9ActivityIntegrationFixture} from "./m9-activity-integration-fixture.mjs";
import {solutionBankFixture} from "./solution-bank-fixture.mjs";
import {testSolutionBankConcurrency as testSolutionBankConcurrencyImplementation} from "./test-solution-bank-concurrency.mjs";
import {solutionPromotionFixture} from "./solution-promotion-fixture.mjs";
import {testSolutionPromotionConcurrency as testSolutionPromotionConcurrencyImplementation} from "./test-solution-promotion-concurrency.mjs";
import {testProblemBankConcurrency as testProblemBankConcurrencyImplementation} from "./test-problem-bank-concurrency.mjs";
import {problemBankFixture} from "./problem-bank-fixture.mjs";
import {problemStormingFixture} from "./problem-storming-fixture.mjs";
import {brainstormPromotionFixture} from './brainstorm-promotion-fixture.mjs';
import {testBrainstormPromotionConcurrency as testBrainstormPromotionConcurrencyImplementation} from './test-brainstorm-promotion-concurrency.mjs';
import {brainstormRevealFixture} from "./brainstorm-reveal-fixture.mjs";
import {brainstormCreateFixture} from "./brainstorm-create-fixture.mjs";
import {brainstormSchemaFixture} from "./brainstorm-schema-fixture.mjs";
import {testArtifactDraftConcurrency as testArtifactDraftConcurrencyImplementation} from "./test-artifact-draft-concurrency.mjs";
import {testScamperPromotionConcurrency as testScamperPromotionConcurrencyImplementation} from "./test-scamper-promotion-concurrency.mjs";
import {artifactReviewSecurityFixture} from "./artifact-review-security-fixture.mjs";
import {testReviewTerminalConcurrency as testReviewTerminalConcurrencyImplementation} from "./test-review-terminal-concurrency.mjs";
import {activityArtifactFixture} from "./activity-artifact-fixture.mjs";
import {testActivityArtifactConcurrency as testActivityArtifactConcurrencyImplementation} from "./test-activity-artifact-concurrency.mjs";
import {testProjectBaselineConcurrency as testProjectBaselineConcurrencyImplementation} from "./test-project-baseline-concurrency.mjs";
import {testArtifactApprovalConcurrency as testArtifactApprovalConcurrencyImplementation} from "./test-artifact-approval-concurrency.mjs";
import {testArtifactReopenConcurrency as testArtifactReopenConcurrencyImplementation} from "./test-artifact-reopen-concurrency.mjs";
import {testArtifactResubmissionConcurrency as testArtifactResubmissionConcurrencyImplementation} from "./test-artifact-resubmission-concurrency.mjs";
import {testArtifactRevisionConcurrency as testArtifactRevisionConcurrencyImplementation} from "./test-artifact-revision-concurrency.mjs";
import {testArtifactReviewConcurrency as testArtifactReviewConcurrencyImplementation} from "./test-artifact-review-concurrency.mjs";
import {testArtifactSubmissionConcurrency as testArtifactSubmissionConcurrencyImplementation} from "./test-artifact-submission-concurrency.mjs";
import {testArtifactArchiveConcurrency as testArtifactArchiveConcurrencyImplementation} from "./test-artifact-archive-concurrency.mjs";
import {testArtifactVersionConcurrency as testArtifactVersionConcurrencyImplementation} from "./test-artifact-version-concurrency.mjs";
import {testArtifactCreationConcurrency as testArtifactCreationConcurrencyImplementation} from "./test-artifact-creation-concurrency.mjs";
import {testActivityResumeAcceptance as testActivityResumeAcceptanceImplementation} from "./test-activity-resume-acceptance.mjs";
import {testActivityCompletionConcurrency as testActivityCompletionConcurrencyImplementation} from "./test-activity-completion-concurrency.mjs";
import {testActivityOutputConcurrency as testActivityOutputConcurrencyImplementation} from "./test-activity-output-concurrency.mjs";
import {testActivityInputConcurrency as testActivityInputConcurrencyImplementation} from "./test-activity-input-concurrency.mjs";
import {testActivityResumeReconnect as testActivityResumeReconnectImplementation} from "./test-activity-resume-reconnect.mjs";
const testDecisionFinalizationConcurrency = options => suite("test-decision-finalization-concurrency", "scripts/test-decision-finalization-concurrency.mjs", () => testDecisionFinalizationConcurrencyImplementation(options));
const testVotingCloseConcurrency = options => suite("test-voting-close-concurrency", "scripts/test-voting-close-concurrency.mjs", () => testVotingCloseConcurrencyImplementation(options));
const testVotingRevealConcurrency = options => suite("test-voting-reveal-concurrency", "scripts/test-voting-reveal-concurrency.mjs", () => testVotingRevealConcurrencyImplementation(options));
const testVotingCastConcurrency = options => suite("test-voting-cast-concurrency", "scripts/test-voting-cast-concurrency.mjs", () => testVotingCastConcurrencyImplementation(options));
const testVotingOpeningConcurrency = options => suite("test-voting-opening-concurrency", "scripts/test-voting-opening-concurrency.mjs", () => testVotingOpeningConcurrencyImplementation(options));
const testSession4Integration = options => suite("test-session4-integration", "scripts/test-session4-integration.mjs", () => testSession4IntegrationImplementation(options));
const testM9BankReconnect = options => suite("test-m9-bank-reconnect", "scripts/test-m9-bank-reconnect.mjs", () => testM9BankReconnectImplementation(options));
const testM9ActivityReconnect = options => suite("test-m9-activity-reconnect", "scripts/test-m9-activity-reconnect.mjs", () => testM9ActivityReconnectImplementation(options));
const testSolutionBankConcurrency = options => suite("test-solution-bank-concurrency", "scripts/test-solution-bank-concurrency.mjs", () => testSolutionBankConcurrencyImplementation(options));
const testSolutionPromotionConcurrency = options => suite("test-solution-promotion-concurrency", "scripts/test-solution-promotion-concurrency.mjs", () => testSolutionPromotionConcurrencyImplementation(options));
const testProblemBankConcurrency = options => suite("test-problem-bank-concurrency", "scripts/test-problem-bank-concurrency.mjs", () => testProblemBankConcurrencyImplementation(options));
const testBrainstormPromotionConcurrency = options => suite("test-brainstorm-promotion-concurrency", "scripts/test-brainstorm-promotion-concurrency.mjs", () => testBrainstormPromotionConcurrencyImplementation(options));
const testArtifactDraftConcurrency = options => suite("test-artifact-draft-concurrency", "scripts/test-artifact-draft-concurrency.mjs", () => testArtifactDraftConcurrencyImplementation(options));
const testScamperPromotionConcurrency = options => suite("test-scamper-promotion-concurrency", "scripts/test-scamper-promotion-concurrency.mjs", () => testScamperPromotionConcurrencyImplementation(options));
const testReviewTerminalConcurrency = options => suite("test-review-terminal-concurrency", "scripts/test-review-terminal-concurrency.mjs", () => testReviewTerminalConcurrencyImplementation(options));
const testActivityArtifactConcurrency = options => suite("test-activity-artifact-concurrency", "scripts/test-activity-artifact-concurrency.mjs", () => testActivityArtifactConcurrencyImplementation(options));
const testProjectBaselineConcurrency = options => suite("test-project-baseline-concurrency", "scripts/test-project-baseline-concurrency.mjs", () => testProjectBaselineConcurrencyImplementation(options));
const testArtifactApprovalConcurrency = options => suite("test-artifact-approval-concurrency", "scripts/test-artifact-approval-concurrency.mjs", () => testArtifactApprovalConcurrencyImplementation(options));
const testArtifactReopenConcurrency = options => suite("test-artifact-reopen-concurrency", "scripts/test-artifact-reopen-concurrency.mjs", () => testArtifactReopenConcurrencyImplementation(options));
const testArtifactResubmissionConcurrency = options => suite("test-artifact-resubmission-concurrency", "scripts/test-artifact-resubmission-concurrency.mjs", () => testArtifactResubmissionConcurrencyImplementation(options));
const testArtifactRevisionConcurrency = options => suite("test-artifact-revision-concurrency", "scripts/test-artifact-revision-concurrency.mjs", () => testArtifactRevisionConcurrencyImplementation(options));
const testArtifactReviewConcurrency = options => suite("test-artifact-review-concurrency", "scripts/test-artifact-review-concurrency.mjs", () => testArtifactReviewConcurrencyImplementation(options));
const testArtifactSubmissionConcurrency = options => suite("test-artifact-submission-concurrency", "scripts/test-artifact-submission-concurrency.mjs", () => testArtifactSubmissionConcurrencyImplementation(options));
const testArtifactArchiveConcurrency = options => suite("test-artifact-archive-concurrency", "scripts/test-artifact-archive-concurrency.mjs", () => testArtifactArchiveConcurrencyImplementation(options));
const testArtifactVersionConcurrency = options => suite("test-artifact-version-concurrency", "scripts/test-artifact-version-concurrency.mjs", () => testArtifactVersionConcurrencyImplementation(options));
const testArtifactCreationConcurrency = options => suite("test-artifact-creation-concurrency", "scripts/test-artifact-creation-concurrency.mjs", () => testArtifactCreationConcurrencyImplementation(options));
const testActivityResumeAcceptance = options => suite("test-activity-resume-acceptance", "scripts/test-activity-resume-acceptance.mjs", () => testActivityResumeAcceptanceImplementation(options));
const testActivityCompletionConcurrency = options => suite("test-activity-completion-concurrency", "scripts/test-activity-completion-concurrency.mjs", () => testActivityCompletionConcurrencyImplementation(options));
const testActivityOutputConcurrency = options => suite("test-activity-output-concurrency", "scripts/test-activity-output-concurrency.mjs", () => testActivityOutputConcurrencyImplementation(options));
const testActivityInputConcurrency = options => suite("test-activity-input-concurrency", "scripts/test-activity-input-concurrency.mjs", () => testActivityInputConcurrencyImplementation(options));
const testActivityResumeReconnect = options => suite("test-activity-resume-reconnect", "scripts/test-activity-resume-reconnect.mjs", () => testActivityResumeReconnectImplementation(options));
const testActivityStartConcurrency = options => suite("test-activity-start-concurrency", "scripts/test-activity-start-concurrency.mjs", () => testActivityStartConcurrencyImplementation(options));
// Runs only in a fresh disposable cluster. Never accepts a database URL.
import { spawn, spawnSync } from "node:child_process";
import {testActivityStartConcurrency as testActivityStartConcurrencyImplementation} from "./test-activity-start-concurrency.mjs";
import { mkdtempSync, readFileSync, rmSync, realpathSync, openSync, closeSync, readdirSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve, dirname, relative, isAbsolute } from "node:path";
import { fileURLToPath } from "node:url";
import { createServer } from "node:net";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const reviewAcceptanceOnly = process.argv.slice(2).includes("--review-acceptance");
const versionAcceptanceOnly = process.argv.slice(2).includes("--version-acceptance");
const approvalRollbackOnly = process.argv.slice(2).includes("--approval-rollback");
const terminalConcurrencyOnly = process.argv.slice(2).includes("--terminal-concurrency");
const draftConflictsOnly = process.argv.slice(2).includes("--draft-conflicts");
const revisionCycleOnly = process.argv.slice(2).includes("--revision-cycle");
const rlsOnly = process.argv.slice(2).includes("--rls-privacy");
const handoffOnly = process.argv.slice(2).includes("--activity-handoff");
const m9ActivityIntegrationOnly = process.argv.slice(2).includes("--m9-activity-integration");
const solutionBankOnly = process.argv.slice(2).includes("--solution-bank");
const solutionPromotionOnly = process.argv.slice(2).includes("--solution-promotion");
const problemBankOnly = process.argv.slice(2).includes("--problem-bank");
const problemStormingOnly = process.argv.slice(2).includes("--problem-storming");
const brainstormPromotionOnly = process.argv.slice(2).includes("--brainstorm-promotion");
const brainstormRevealOnly = process.argv.slice(2).includes("--brainstorm-reveal");
const brainstormPrivacyOnly = process.argv.slice(2).includes("--brainstorm-privacy");
const brainstormCreateOnly = process.argv.slice(2).includes("--brainstorm-create");
const brainstormSchemaOnly = process.argv.slice(2).includes("--brainstorm-schema");
const scamperSchemaOnly = process.argv.slice(2).includes("--scamper-schema");
const scamperOperationsOnly = process.argv.slice(2).includes("--scamper-operations");
const scamperPromotionOnly = process.argv.slice(2).includes("--scamper-promotion");
const scamperPrivacyOnly = process.argv.slice(2).includes("--scamper-privacy");
const m9LeakageOnly=process.argv.slice(2).includes("--m9-leakage");
const m10LeakageOnly=process.argv.slice(2).includes("--m10-leakage");
const m10ConcurrencyOnly=process.argv.slice(2).includes("--m10-concurrency");
const session5Only=process.argv.slice(2).includes("--session5");
const session4Only=process.argv.slice(2).includes("--session4");
const decisionSupersessionOnly=process.argv.slice(2).includes("--decision-supersession");
const decisionAcceptanceOnly=process.argv.slice(2).includes("--decision-acceptance");
const votingAcceptanceOnly=process.argv.slice(2).includes("--voting-acceptance");
const decisionRlsOnly=process.argv.slice(2).includes("--decision-rls");
const votingRlsOnly=process.argv.slice(2).includes("--voting-rls");
const decisionArtifactOnly=process.argv.slice(2).includes("--decision-artifact");
const decisionLinkGroups=process.argv.slice(2).includes("--decision-link-groups");
const decisionLinksOnly=process.argv.slice(2).includes("--decision-links");
const aiConfigUsageRlsOnly=process.argv.includes('--ai-config-usage-rls');
const notificationIntegrityOnly=process.argv.includes('--notification-integrity');
const pilotProgressOnly=process.argv.includes('--pilot-progress');
const pilotNotificationsOnly=process.argv.includes('--pilot-notifications');
const pilotStudentOnly=process.argv.includes('--pilot-student');
const pilotMasterOnly=process.argv.includes('--pilot-master');
const pilotAdminOnly=process.argv.includes('--pilot-admin');
const pilotAdminRegressions=new Set(['user-profiles','system-roles','role-assignments','security-helpers','base-rls','m2-security-audit','organizations','program-curriculum','cohorts','enrollments','m3-cohort-enrollment-acceptance','m3-security-audit','teams','team-memberships','create-team','add-team-member','remove-team-member','move-team-member','assign-team-lead','m5-audit-notifications','team-management-acceptance','cross-team-leakage','pilot-admin-acceptance'].map(name=>'tests/integration/'+name+'.sql'));
const currentWorkOnly=process.argv.includes('--current-work');
const emailProviderOnly=currentWorkOnly||process.argv.includes('--email-provider');
const commentNotificationsOnly=emailProviderOnly||process.argv.includes('--comment-notifications');
const approvalNotificationsOnly=commentNotificationsOnly||process.argv.includes('--approval-notifications');
const revisionNotificationsOnly=approvalNotificationsOnly||process.argv.includes('--revision-notifications');
const submissionNotificationsOnly=revisionNotificationsOnly||process.argv.includes('--submission-notifications');
const shareNotificationsOnly=submissionNotificationsOnly||process.argv.includes('--share-notifications');
const membershipNotificationsOnly=pilotAdminOnly||shareNotificationsOnly||process.argv.includes('--membership-notifications');
const notificationRealtimeOnly=membershipNotificationsOnly||process.argv.includes('--notification-realtime');
const notificationRlsOnly=notificationRealtimeOnly||process.argv.includes('--notification-rls');
const notificationReadOnly=notificationRlsOnly||process.argv.includes('--notification-read');
const notificationListOnly=notificationReadOnly||process.argv.includes('--notification-list');
const notificationServiceOnly=notificationListOnly||process.argv.includes('--notification-service');
const notificationsOnly=notificationServiceOnly||process.argv.includes('--notifications');
const aiGovernanceOnly=process.argv.includes('--ai-governance');
const aiSession10Only=process.argv.includes('--ai-session10');
const aiRlsOnly=process.argv.includes('--ai-rls');
const aiBrainstormOnly=process.argv.includes('--ai-brainstorm');
const aiSharedContextOnly=process.argv.includes('--ai-shared-context');
const aiEvidenceSeparationOnly=process.argv.includes('--ai-evidence-separation');
const aiArtifactRevisionOnly=process.argv.includes('--ai-artifact-revision');
const aiConversionOnly=process.argv.includes('--ai-conversion');
const aiDispositionOnly=process.argv.includes('--ai-disposition');
const aiRuntimeOnly=process.argv.includes('--ai-runtime');
const aiAvailabilityOnly=process.argv.includes('--ai-availability');
const aiBuilderOnly=process.argv.includes('--ai-builder');
const aiUsageOnly=process.argv.includes("--ai-usage");
const aiPromptsOnly=process.argv.includes("--ai-prompts");
const aiContextOnly=process.argv.includes("--ai-context");
const aiOutputsOnly=process.argv.includes("--ai-outputs");
const patentRlsOnly=process.argv.includes("--patent-rls");
const evidenceRlsOnly=process.argv.includes("--evidence-rls");
const activityResearchOnly=process.argv.includes("--activity-research");
const sharingPrivacyOnly=process.argv.includes("--sharing-privacy");
const shareRlsOnly=sharingPrivacyOnly||process.argv.includes("--share-rls")||process.argv.includes("--shared-query-isolation");
const mindMapShareOnly=shareRlsOnly||process.argv.includes("--mind-map-share");
const sharedFilesOnly=mindMapShareOnly||process.argv.includes("--shared-files");
const shareHistoryOnly=sharedFilesOnly||process.argv.includes("--share-history");
const shareRevokeOnly=shareHistoryOnly||process.argv.includes("--share-revoke");
const shareCommentsOnly=shareRevokeOnly||process.argv.includes("--share-comments");
const shareViewOnly=shareCommentsOnly||process.argv.includes("--share-view");
const personalSharingOnly=shareViewOnly||process.argv.includes("--personal-sharing");
const sharedAccessOnly=personalSharingOnly||process.argv.includes("--shared-access");
const shareEntityOnly=sharedAccessOnly||process.argv.includes("--share-entity");
const shareabilityOnly=shareEntityOnly||process.argv.includes("--shareability");
const shareSnapshotsOnly=shareabilityOnly||process.argv.includes("--share-snapshots");
const sharesSchemaOnly=shareSnapshotsOnly||process.argv.includes("--shares-schema");
const m12LeakageOnly=process.argv.includes("--m12-leakage");
const session9Only=process.argv.includes("--session9");
const session8Only=process.argv.includes("--session8");
const decisionEvidenceOnly=process.argv.includes("--decision-evidence");
const decisionFinalizationOnly=process.argv.slice(2).includes("--decision-finalization");
const decisionCreationOnly=process.argv.slice(2).includes("--decision-creation");
const decisionSchemaOnly=process.argv.slice(2).includes("--decision-schema");
const votingResultsOnly=process.argv.slice(2).includes("--voting-results");
const votingCloseOnly=process.argv.slice(2).includes("--voting-close");
const votingRevealOnly=process.argv.slice(2).includes("--voting-reveal");
const votingCastOnly=process.argv.slice(2).includes("--voting-cast");
const votingOpeningOnly=process.argv.slice(2).includes("--voting-opening");
const votingCreationOnly=process.argv.slice(2).includes("--voting-creation");
const votingSchemaOnly=process.argv.slice(2).includes("--voting-schema");
const mindMapNodeRemovalOnly=process.argv.slice(2).includes("--mind-map-node-removal");
const mindMapEditorOnly=process.argv.slice(2).includes("--mind-map-editor");
const mindMapClassificationOnly=process.argv.slice(2).includes("--mind-map-classification");
const mindMapVersionOnly=process.argv.slice(2).includes("--mind-map-version");
const mindMapDraftOnly=process.argv.slice(2).includes("--mind-map-draft");
const mindMapCollaborationOnly=process.argv.slice(2).includes("--mind-map-collaboration");
const mindMapEdgesOnly=process.argv.slice(2).includes("--mind-map-edges");
const mindMapNodesOnly=process.argv.slice(2).includes("--mind-map-nodes");
const mindMapCreationOnly=process.argv.slice(2).includes("--mind-map-creation");
const mindMapRlsOnly=process.argv.slice(2).includes("--mind-map-rls");
const mindMapSchemaOnly=process.argv.slice(2).includes("--mind-map-schema");
const collaborativeEditOnly=process.argv.slice(2).includes("--collaborative-edit-acceptance");
const gapCaptureOnly=process.argv.slice(2).includes("--gap-capture");
const affinityStructureOnly=process.argv.slice(2).includes("--affinity-structure");
const affinityCollaborationOnly=process.argv.slice(2).some(flag=>["--affinity-collaboration","--affinity-acceptance"].includes(flag));
const affinityItemsOnly=process.argv.slice(2).includes("--affinity-items");
const affinityOperationsOnly=process.argv.slice(2).includes("--affinity-operations");
const affinityRlsOnly=process.argv.slice(2).includes("--affinity-rls");
const affinitySchemaOnly=process.argv.slice(2).includes("--affinity-schema");
const session6IntegrationOnly=process.argv.slice(2).includes("--session6-integration");
const session6OutputsOnly=process.argv.slice(2).includes("--session6-outputs");
const patentComparisonBoundaryOnly=process.argv.includes("--patent-comparison-boundary");
const patentBoundaryOnly=process.argv.includes("--patent-boundary");
const patentWorkspaceOnly=patentBoundaryOnly||process.argv.includes("--patent-workspace");
const patentEvidenceOnly=patentWorkspaceOnly||process.argv.includes("--patent-evidence");
const patentSearchOnly=patentEvidenceOnly||process.argv.includes("--patent-search");
const patentCreateOnly=patentSearchOnly||process.argv.includes("--patent-create");
const patentSchemaOnly=patentCreateOnly||process.argv.includes("--patent-schema");
const fileRlsOnly=process.argv.includes("--file-rls");
const fileLinksOnly=fileRlsOnly||patentSchemaOnly||process.argv.includes("--file-links");
const uploadOnly=fileLinksOnly||process.argv.slice(2).some(x=>["--file-upload","--file-provider"].includes(x));
const filesSchemaOnly=uploadOnly||process.argv.slice(2).includes("--files-schema");
const evidenceVerifyOnly=filesSchemaOnly||process.argv.slice(2).some(flag=>["--evidence-verify","--evidence-boundary"].includes(flag));
const evidenceCreateOnly=process.argv.slice(2).includes("--evidence-create");
const evidenceLinksOnly=process.argv.slice(2).includes("--evidence-links");
const evidenceSchemaOnly=process.argv.slice(2).includes("--evidence-schema");
const session7IntegrationOnly=process.argv.slice(2).includes("--session7-integration");
const session7OutputsOnly=process.argv.slice(2).includes("--session7-outputs");
const selectedSecurityGroup = patentRlsOnly || evidenceRlsOnly || activityResearchOnly || decisionEvidenceOnly || patentComparisonBoundaryOnly || evidenceVerifyOnly || evidenceCreateOnly || evidenceLinksOnly || evidenceSchemaOnly || session7IntegrationOnly || session6IntegrationOnly || collaborativeEditOnly || mindMapRlsOnly || affinityRlsOnly || session7OutputsOnly || session6OutputsOnly || mindMapClassificationOnly || mindMapVersionOnly || mindMapDraftOnly || mindMapCollaborationOnly || mindMapEditorOnly || mindMapNodeRemovalOnly || mindMapEdgesOnly || mindMapNodesOnly || mindMapCreationOnly || mindMapSchemaOnly || gapCaptureOnly || affinityStructureOnly || affinityCollaborationOnly || affinityItemsOnly || affinityOperationsOnly || affinitySchemaOnly || m10LeakageOnly || m10ConcurrencyOnly || session5Only || decisionAcceptanceOnly || votingAcceptanceOnly || decisionRlsOnly || votingRlsOnly || decisionArtifactOnly || decisionSupersessionOnly || decisionLinkGroups || decisionLinksOnly || decisionFinalizationOnly || decisionCreationOnly || decisionSchemaOnly || votingResultsOnly || votingCloseOnly || votingRevealOnly || votingCastOnly || votingOpeningOnly || votingCreationOnly || votingSchemaOnly || m9LeakageOnly || session4Only || m9ActivityIntegrationOnly || solutionBankOnly || solutionPromotionOnly || problemBankOnly || problemStormingOnly || brainstormPromotionOnly || brainstormRevealOnly || brainstormPrivacyOnly || brainstormCreateOnly || brainstormSchemaOnly || rlsOnly || handoffOnly || scamperSchemaOnly || scamperOperationsOnly || scamperPromotionOnly || scamperPrivacyOnly;
const foundationOnly = notificationIntegrityOnly || pilotProgressOnly || pilotNotificationsOnly || pilotStudentOnly || pilotMasterOnly || notificationsOnly || aiGovernanceOnly || aiSession10Only || aiConfigUsageRlsOnly || aiRlsOnly || aiBrainstormOnly || aiSharedContextOnly || aiEvidenceSeparationOnly || aiArtifactRevisionOnly || aiConversionOnly || aiDispositionOnly || aiRuntimeOnly || aiAvailabilityOnly || aiBuilderOnly || aiUsageOnly || aiPromptsOnly || aiContextOnly || aiOutputsOnly || sharesSchemaOnly || m12LeakageOnly || session9Only || session8Only || mindMapCollaborationOnly || selectedSecurityGroup || revisionCycleOnly || draftConflictsOnly || reviewAcceptanceOnly || versionAcceptanceOnly || approvalRollbackOnly || terminalConcurrencyOnly;
const tempRoot = realpathSync(tmpdir());
const cluster = mkdtempSync(join(tempRoot, "fici-profile-tests-"));
const bin = process.env.POSTGRES_BIN ?? "";
const childEnv = Object.fromEntries(Object.entries(process.env).filter(([name]) => !name.toUpperCase().startsWith("PG")));
const binary = (name) => join(bin, process.platform === "win32" ? `${name}.exe` : name);
const run = (name, args, input) => {
  const startedAt = performance.now();
  // Report command phases without SQL, fixture payloads, or environment values.
  const fileIndex = args.indexOf("-f");
  const phase = fileIndex >= 0 ? `${name} ${args[fileIndex + 1]}` : name;
  console.error(`[database] START ${phase}`);
  const result = command(name, args, () => spawnSync(binary(name), args, {
    cwd: root, encoding: "utf8", windowsHide: true, input,
    env: childEnv,
  }));
  console.error(`[database] END ${phase} ${(performance.now() - startedAt).toFixed(0)}ms status=${result.status}`);
  if (result.error || result.status !== 0) {
    throw new Error(`${name} failed: ${result.error?.message ?? result.stderr ?? result.stdout}`);
  }
  return result.stdout;
};
const port = await new Promise((resolvePort, reject) => {
  const server = createServer();
  server.once("error", reject);
  server.listen(0, "127.0.0.1", () => {
    const address = server.address();
    if (!address || typeof address === "string") return reject(new Error("No test port"));
    server.close(() => resolvePort(address.port));
  });
});
let started = false;
let server;
try {
  run("initdb", ["-D", cluster, "-U", "postgres", "-A", "trust", "--no-locale", "--encoding=UTF8"]);
  const log = openSync(join(cluster, "server.log"), "a");
  server = spawn(binary("postgres"), ["-D", cluster, "-h", "127.0.0.1", "-p", String(port)], {
    windowsHide: true, env: childEnv, stdio: ["ignore", log, log],
  });
  closeSync(log);
  let launchError;
  server.on("error", (error) => { launchError = error; });
  for (let attempt = 0; attempt < 100; attempt++) {
    if (launchError) throw launchError;
    if (server.exitCode !== null) throw new Error("PostgreSQL exited during startup");
    const ready = spawnSync(binary("pg_isready"), ["-h", "127.0.0.1", "-p", String(port), "-U", "postgres", "-d", "postgres"], { windowsHide: true, env: childEnv, stdio: "ignore" });
    if (ready.status === 0) { started = true; break; }
    await new Promise((done) => setTimeout(done, 100));
  }
  if (!started) throw new Error("PostgreSQL startup timed out");
  const args = ["-X", "-h", "127.0.0.1", "-p", String(port), "-U", "postgres", "-d", "postgres", "-v", "ON_ERROR_STOP=1"];
  for (const file of [
    "tests/integration/fixtures/auth.sql",
    "tests/integration/fixtures/realtime.sql",
    "tests/integration/fixtures/storage.sql",
    ...readdirSync(join(root, "supabase/migrations")).filter((name) => name.endsWith(".sql")).sort().map((name) => `supabase/migrations/${name}`),
    "supabase/seed.sql",
    "supabase/seed.sql",
    "tests/integration/professional-seed-validation.sql",
    "tests/integration/live-session-rooms.sql",
    "tests/integration/user-profiles.sql",
    "tests/integration/system-roles.sql",
    "tests/integration/role-assignments.sql",
    "tests/integration/security-helpers.sql",
    "tests/integration/base-rls.sql",
    "tests/integration/m2-security-audit.sql",
    "tests/integration/organizations.sql",
    "tests/integration/program-curriculum.sql",
    "tests/integration/sessions.sql",
    "tests/integration/activities.sql",
    "tests/integration/activity-dependencies.sql",
    "tests/integration/cohorts.sql",
    "tests/integration/enrollments.sql",
    "tests/integration/m3-cohort-enrollment-acceptance.sql",
    "tests/integration/m3-security-audit.sql",
    "tests/integration/workspaces.sql",
    "tests/integration/personal-workspace-provisioning.sql",
    "tests/integration/workspace-access.sql",
    "tests/integration/personal-workspace-rls.sql",
    "tests/integration/workspace-foundations.sql",
    "tests/integration/workspace-security-audit.sql",
    "tests/integration/teams.sql",
    "tests/integration/team-memberships.sql",
    "tests/integration/team-chat.sql",
    "tests/integration/create-team.sql",
    "tests/integration/add-team-member.sql",
    "tests/integration/remove-team-member.sql",
    "tests/integration/move-team-member.sql",
    "tests/integration/assign-team-lead.sql",
    "tests/integration/team-chat-operations.sql",
    "tests/integration/team-chat-realtime.sql",
    "tests/integration/team-chat-rls-security.sql",
    "tests/integration/m5-audit-notifications.sql",
    "tests/integration/archive-team.sql",
    "tests/integration/team-management-acceptance.sql",
    "tests/integration/pilot-admin-acceptance.sql",
    "tests/integration/team-chat-acceptance.sql",
    "tests/integration/cross-team-leakage.sql",
    "tests/integration/member-removal-scenario.sql",
    "tests/integration/m5-security-audit.sql",
    "tests/integration/development-projects.sql",
    "tests/integration/project-memberships.sql",
    "tests/integration/create-development-project.sql",
    "tests/integration/project-program-links.sql",
    "tests/integration/development-objects.sql",
    "tests/integration/development-object-operations.sql",
    "tests/integration/development-object-typed-details.sql",
    "tests/integration/development-object-relationships.sql",
    "tests/integration/project-metadata.sql",
    "tests/integration/project-change-log.sql",
    "tests/integration/project-archive.sql",
    "tests/integration/project-rls-hardening.sql",
    "tests/integration/project-session-continuity.sql",
    "tests/integration/object-context-reuse.sql",
    "tests/integration/project-cross-program-continuity.sql",
    "tests/integration/project-leakage-security.sql",
    "tests/integration/m6-security-integrity-audit.sql",
    "tests/integration/activity-instances.sql",
    "tests/integration/activity-participants.sql",
    "tests/integration/activity-inputs-outputs.sql",
    "tests/integration/activity-availability.sql",
    "tests/integration/activity-dependency-evaluation.sql",
    "tests/integration/activity-start.sql",
    "tests/integration/activity-resume.sql",
    "tests/integration/activity-input-operation.sql",
    "tests/integration/activity-output-operation.sql",
    "tests/integration/activity-completion.sql",
    "tests/integration/activity-rls-security.sql",
    "tests/integration/activity-start-acceptance.sql",
    "tests/integration/activity-dependency-acceptance.sql",
    "tests/integration/activity-output-handoff-acceptance.sql",
    "tests/integration/activity-leakage-security.sql",
    "tests/integration/activity-snapshot-integrity.sql",
    "tests/integration/artifact-schema-security.sql",
    "tests/integration/artifact-version-security.sql",
    "tests/integration/artifact-object-links.sql",
    "tests/integration/create-artifact.sql",
    "tests/integration/create-artifact-version.sql",
    "tests/integration/artifact-history-archive.sql",
    "tests/integration/submit-artifact.sql",
    "tests/integration/start-review-feedback.sql",
    "tests/integration/request-revision.sql",
    "tests/integration/revision-resubmission.sql",
    "tests/integration/approve-artifact.sql",
    "tests/integration/reopen-approved-artifact.sql",
  ].filter(file => !foundationOnly || file.startsWith("supabase/") || file.startsWith("tests/integration/fixtures/") || pilotAdminOnly&&pilotAdminRegressions.has(file))) {
    console.log(run("psql", [...args, "-f", file]));
  }
  if(notificationsOnly)console.log(run('psql',[...args,'-f','tests/integration/m5-audit-notifications.sql']));
  if(!foundationOnly||notificationsOnly){console.log(run('psql',[...args,'-f','-'],artifactReviewSecurityFixture(root)+readFileSync(join(root,'tests/integration/notifications.sql'),'utf8')));}
  if(!foundationOnly||commentNotificationsOnly)console.log(run('psql',[...args,'-f','-'],artifactReviewSecurityFixture(root)+readFileSync(join(root,'tests/integration/comment-notifications.sql'),'utf8')));
  if(!foundationOnly||approvalNotificationsOnly)console.log(run('psql',[...args,'-f','-'],artifactReviewSecurityFixture(root)+readFileSync(join(root,'tests/integration/approval-notifications.sql'),'utf8')));
  if(!foundationOnly||revisionNotificationsOnly)console.log(run('psql',[...args,'-f','-'],artifactReviewSecurityFixture(root)+readFileSync(join(root,'tests/integration/revision-notifications.sql'),'utf8')));
  if(!foundationOnly||submissionNotificationsOnly)console.log(run('psql',[...args,'-f','-'],artifactReviewSecurityFixture(root)+readFileSync(join(root,'tests/integration/submission-notifications.sql'),'utf8')));
  if(!foundationOnly||shareNotificationsOnly)console.log(run('psql',[...args,'-f','-'],artifactReviewSecurityFixture(root)+readFileSync(join(root,'tests/integration/share-notifications.sql'),'utf8')));
  if(!foundationOnly||membershipNotificationsOnly)console.log(run('psql',[...args,'-f','-'],artifactReviewSecurityFixture(root)+readFileSync(join(root,'tests/integration/membership-notifications.sql'),'utf8')));
  if(!foundationOnly||notificationServiceOnly)console.log(run('psql',[...args,'-f','-'],artifactReviewSecurityFixture(root)+readFileSync(join(root,'tests/integration/notification-service.sql'),'utf8')));
  if(!foundationOnly||notificationListOnly)console.log(run('psql',[...args,'-f','-'],artifactReviewSecurityFixture(root)+readFileSync(join(root,'tests/integration/notification-list.sql'),'utf8')));
  if(!foundationOnly||notificationReadOnly)console.log(run('psql',[...args,'-f','-'],artifactReviewSecurityFixture(root)+readFileSync(join(root,'tests/integration/notification-read.sql'),'utf8')));
  if(!foundationOnly||notificationRealtimeOnly)console.log(run('psql',[...args,'-f','-'],artifactReviewSecurityFixture(root)+readFileSync(join(root,'tests/integration/notification-realtime.sql'),'utf8')));
  if(!foundationOnly||notificationRlsOnly)console.log(run('psql',[...args,'-f','-'],artifactReviewSecurityFixture(root)+readFileSync(join(root,'tests/integration/notification-rls.sql'),'utf8')));
  if(!foundationOnly||patentComparisonBoundaryOnly)console.log(run("psql",[...args,"-f","tests/integration/patent-comparison-boundary.sql"]));
  if(!foundationOnly||patentRlsOnly)console.log(run("psql",[...args,"-f","-"],artifactReviewSecurityFixture(root)+readFileSync(join(root,"tests/integration/activity-research-setup.sql"),"utf8")+readFileSync(join(root,"tests/integration/patent-rls.sql"),"utf8")));
  if(!foundationOnly||evidenceRlsOnly)console.log(run("psql",[...args,"-f","-"],artifactReviewSecurityFixture(root)+readFileSync(join(root,"tests/integration/decision-evidence-setup.sql"),"utf8")+readFileSync(join(root,"tests/integration/evidence-rls.sql"),"utf8")));
  if(!foundationOnly||aiDispositionOnly)console.log(run('psql',[...args,'-f','-'],artifactReviewSecurityFixture(root)+readFileSync(join(root,'tests/integration/ai-outputs.sql'),'utf8').split('set local role authenticated;')[0]+readFileSync(join(root,'tests/integration/ai-disposition.sql'),'utf8')));
  if(!foundationOnly||aiGovernanceOnly)console.log(run('psql',[...args,'-f','-'],artifactReviewSecurityFixture(root)+readFileSync(join(root,'tests/integration/activity-research-setup.sql'),'utf8')+readFileSync(join(root,'tests/integration/ai-session10.sql'),'utf8').split('-- Direct mutations remain denied')[0]+readFileSync(join(root,'tests/integration/ai-governance.sql'),'utf8')));
  if(!foundationOnly||aiSession10Only)console.log(run('psql',[...args,'-f','-'],artifactReviewSecurityFixture(root)+readFileSync(join(root,'tests/integration/activity-research-setup.sql'),'utf8')+readFileSync(join(root,'tests/integration/ai-session10.sql'),'utf8')));
  if(!foundationOnly||aiOutputsOnly)console.log(run("psql",[...args,"-f","-"],artifactReviewSecurityFixture(root)+readFileSync(join(root,"tests/integration/ai-outputs.sql"),"utf8")));
  if(!foundationOnly||aiUsageOnly){console.log(run("psql",[...args,"-f","-"],artifactReviewSecurityFixture(root)+readFileSync(join(root,"tests/integration/ai-usage-events.sql"),"utf8")));await testAiUsageEvents({run,args,binary,childEnv,root});}
  if(!foundationOnly||aiPromptsOnly){console.log(run("psql",[...args,"-f","-"],artifactReviewSecurityFixture(root)+readFileSync(join(root,"tests/integration/ai-prompt-templates.sql"),"utf8")));await testAiPromptTemplates({run,args,binary,childEnv,root});}
  if(!foundationOnly||aiEvidenceSeparationOnly)console.log(run('psql',[...args,'-f','-'],artifactReviewSecurityFixture(root)+readFileSync(join(root,'tests/integration/activity-research-setup.sql'),'utf8')+readFileSync(join(root,'tests/integration/ai-activity-availability.sql'),'utf8').split('-- No resource differentiation')[0]+readFileSync(join(root,'tests/integration/ai-run-task.sql'),'utf8').split('-- RUNTIME TESTS')[0]+readFileSync(join(root,'tests/integration/ai-conversion.sql'),'utf8').split('-- CONVERSION TESTS')[0]+readFileSync(join(root,'tests/integration/ai-artifact-revision.sql'),'utf8').split('-- REVISION TESTS')[0]+readFileSync(join(root,'tests/integration/ai-evidence-separation.sql'),'utf8')));
  if(!foundationOnly||aiArtifactRevisionOnly)console.log(run('psql',[...args,'-f','-'],artifactReviewSecurityFixture(root)+readFileSync(join(root,'tests/integration/activity-research-setup.sql'),'utf8')+readFileSync(join(root,'tests/integration/ai-activity-availability.sql'),'utf8').split('-- No resource differentiation')[0]+readFileSync(join(root,'tests/integration/ai-run-task.sql'),'utf8').split('-- RUNTIME TESTS')[0]+readFileSync(join(root,'tests/integration/ai-conversion.sql'),'utf8').split('-- CONVERSION TESTS')[0]+readFileSync(join(root,'tests/integration/ai-artifact-revision.sql'),'utf8')));
  if(!foundationOnly||aiConversionOnly)console.log(run('psql',[...args,'-f','-'],artifactReviewSecurityFixture(root)+readFileSync(join(root,'tests/integration/activity-research-setup.sql'),'utf8')+readFileSync(join(root,'tests/integration/ai-activity-availability.sql'),'utf8').split('-- No resource differentiation')[0]+readFileSync(join(root,'tests/integration/ai-run-task.sql'),'utf8').split('-- RUNTIME TESTS')[0]+readFileSync(join(root,'tests/integration/ai-conversion.sql'),'utf8')));
  if(!foundationOnly||aiArtifactRevisionOnly)await testAiArtifactRevisionConcurrency({run,args,binary,childEnv,root});
  if(!foundationOnly||aiConversionOnly)await testAiConversionConcurrency({run,args,binary,childEnv,root});
  if(!foundationOnly||aiRuntimeOnly)console.log(run('psql',[...args,'-f','-'],artifactReviewSecurityFixture(root)+readFileSync(join(root,'tests/integration/activity-research-setup.sql'),'utf8')+readFileSync(join(root,'tests/integration/ai-activity-availability.sql'),'utf8').split('-- No resource differentiation')[0]+readFileSync(join(root,'tests/integration/ai-run-task.sql'),'utf8')));
  if(!foundationOnly||aiRuntimeOnly)await testAiRuntimeConcurrency({run,args,binary,childEnv,root});
  if(!foundationOnly||aiAvailabilityOnly)console.log(run('psql',[...args,'-f','-'],artifactReviewSecurityFixture(root)+readFileSync(join(root,'tests/integration/activity-research-setup.sql'),'utf8')+readFileSync(join(root,'tests/integration/ai-activity-availability.sql'),'utf8')));
  if(!foundationOnly||aiBrainstormOnly)console.log(run('psql',[...args,'-f','-'],artifactReviewSecurityFixture(root)+readFileSync(join(root,'tests/integration/activity-research-setup.sql'),'utf8')+readFileSync(join(root,'tests/integration/ai-brainstorm-privacy.sql'),'utf8')));
  if(!foundationOnly||aiSharedContextOnly)console.log(run('psql',[...args,'-f','-'],artifactReviewSecurityFixture(root)+readFileSync(join(root,'tests/integration/activity-research-setup.sql'),'utf8')+readFileSync(join(root,'tests/integration/share-entity-setup.sql'),'utf8')+readFileSync(join(root,'tests/integration/ai-context-builder.sql'),'utf8').split('-- New source version')[0]+readFileSync(join(root,'tests/integration/ai-shared-context.sql'),'utf8')));
  if(!foundationOnly||aiBuilderOnly)console.log(run('psql',[...args,'-f','-'],artifactReviewSecurityFixture(root)+readFileSync(join(root,'tests/integration/activity-research-setup.sql'),'utf8')+readFileSync(join(root,'tests/integration/share-entity-setup.sql'),'utf8')+readFileSync(join(root,'tests/integration/ai-context-builder.sql'),'utf8')));
  if(!foundationOnly||aiConfigUsageRlsOnly)console.log(run('psql',[...args,'-f','-'],artifactReviewSecurityFixture(root)+readFileSync(join(root,'tests/integration/ai-prompt-templates.sql'),'utf8').split('-- The bounded schema')[0]+readFileSync(join(root,'tests/integration/ai-usage-events.sql'),'utf8').split('-- Another current authorized Team participant')[0]+readFileSync(join(root,'tests/integration/ai-config-usage-rls.sql'),'utf8')));
  if(!foundationOnly||aiRlsOnly)console.log(run('psql',[...args,'-f','-'],artifactReviewSecurityFixture(root)+readFileSync(join(root,'tests/integration/activity-research-setup.sql'),'utf8')+readFileSync(join(root,'tests/integration/share-entity-setup.sql'),'utf8')+readFileSync(join(root,'tests/integration/ai-context-references.sql'),'utf8').split('-- Successful capture')[0]+readFileSync(join(root,'tests/integration/ai-output-rls.sql'),'utf8')));
  if(!foundationOnly||aiContextOnly)console.log(run("psql",[...args,"-f","-"],artifactReviewSecurityFixture(root)+readFileSync(join(root,"tests/integration/activity-research-setup.sql"),"utf8")+readFileSync(join(root,"tests/integration/share-entity-setup.sql"),"utf8")+readFileSync(join(root,"tests/integration/ai-context-references.sql"),"utf8")));
  if(!foundationOnly||aiDispositionOnly)console.log(run('psql',[...args,'-f','-'],artifactReviewSecurityFixture(root)+readFileSync(join(root,'tests/integration/ai-outputs.sql'),'utf8').split('set local role authenticated;')[0]+readFileSync(join(root,'tests/integration/ai-disposition.sql'),'utf8')));
  if(!foundationOnly||aiOutputsOnly)console.log(run("psql",[...args,"-f","-"],artifactReviewSecurityFixture(root)+readFileSync(join(root,"tests/integration/review-authorization-fast-deny.sql"),"utf8")));
  if(!foundationOnly||sharingPrivacyOnly)testSharingPrivacy({run,args,childEnv,root});
  if(!foundationOnly||shareRlsOnly)testShareRls({run,args,root});
  if(!foundationOnly||mindMapShareOnly)testMindMapShare({run,args,root});
  if(!foundationOnly||sharedFilesOnly)testSharedFiles({run,args,childEnv,root});
  if(!foundationOnly||shareHistoryOnly)testShareHistory({run,args,childEnv,root});
  if(!foundationOnly||shareRevokeOnly)testShareRevoke({run,args,childEnv,root});
  if(!foundationOnly||shareCommentsOnly)testShareComments({run,args,childEnv,root});
  if(!foundationOnly||shareViewOnly)testShareView({run,args,childEnv,root});
  if(!foundationOnly||personalSharingOnly)testPersonalSharing({run,args,childEnv,root});
  if(!foundationOnly||sharedAccessOnly)console.log(run("psql",[...args,"-f","-"],artifactReviewSecurityFixture(root)+readFileSync(join(root,"tests/integration/activity-research-setup.sql"),"utf8")+readFileSync(join(root,"tests/integration/share-entity-setup.sql"),"utf8")+readFileSync(join(root,"tests/integration/team-sharing-cohort.sql"),"utf8")+readFileSync(join(root,"tests/integration/shared-access.sql"),"utf8")));
  if(!foundationOnly||shareEntityOnly){console.log(run("psql",[...args,"-f","-"],artifactReviewSecurityFixture(root)+readFileSync(join(root,"tests/integration/activity-research-setup.sql"),"utf8")+readFileSync(join(root,"tests/integration/share-entity-setup.sql"),"utf8")+readFileSync(join(root,"tests/integration/share-entity.sql"),"utf8")));await testShareEntityConcurrency({run,args,binary,childEnv,root});}
  if(!foundationOnly||shareabilityOnly)console.log(run("psql",[...args,"-f","-"],artifactReviewSecurityFixture(root)+readFileSync(join(root,"tests/integration/activity-research-setup.sql"),"utf8")+readFileSync(join(root,"tests/integration/shareability.sql"),"utf8")));
  if(!foundationOnly||shareSnapshotsOnly)console.log(run("psql",[...args,"-f","-"],artifactReviewSecurityFixture(root)+readFileSync(join(root,"tests/integration/activity-research-setup.sql"),"utf8")+readFileSync(join(root,"tests/integration/share-snapshots.sql"),"utf8")));
  if(!foundationOnly||sharesSchemaOnly)console.log(run("psql",[...args,"-f","-"],artifactReviewSecurityFixture(root)+readFileSync(join(root,"tests/integration/activity-research-setup.sql"),"utf8")+readFileSync(join(root,"tests/integration/shares-schema.sql"),"utf8")));
  if(!foundationOnly||m12LeakageOnly)console.log(run("psql",[...args,"-f","-"],artifactReviewSecurityFixture(root)+readFileSync(join(root,"tests/integration/activity-research-setup.sql"),"utf8")+readFileSync(join(root,"tests/integration/m12-leakage.sql"),"utf8")));
  if(!foundationOnly||session9Only)console.log(run("psql",[...args,"-f","-"],session9Fixture(root)+readFileSync(join(root,"tests/integration/session9-patent-research.sql"),"utf8")));
  if(!foundationOnly||session8Only){console.log(run("psql",[...args,"-f","-"],session8Fixture(root)+readFileSync(join(root,"tests/integration/session8-patent-reading.sql"),"utf8")));await testSession8Reading({run,args,binary,childEnv,root});}
  if(!foundationOnly||activityResearchOnly){console.log(run("psql",[...args,"-f","-"],artifactReviewSecurityFixture(root)+readFileSync(join(root,"tests/integration/activity-research-setup.sql"),"utf8")+readFileSync(join(root,"tests/integration/activity-research.sql"),"utf8")));await testActivityResearch({run,args,binary,childEnv,root});}
  if(!foundationOnly||decisionEvidenceOnly){console.log(run("psql",[...args,"-f","-"],artifactReviewSecurityFixture(root)+readFileSync(join(root,"tests/integration/decision-evidence-setup.sql"),"utf8")+readFileSync(join(root,"tests/integration/decision-evidence.sql"),"utf8")));await testDecisionEvidence({run,args,binary,childEnv,root});}
  if (!foundationOnly || filesSchemaOnly)console.log(run("psql",[...args,"-f","-"],artifactReviewSecurityFixture(root)+readFileSync(join(root,"tests/integration/files-schema.sql"),"utf8")));
  if (!foundationOnly || uploadOnly)console.log(run("psql",[...args,"-f","-"],artifactReviewSecurityFixture(root)+readFileSync(join(root,"tests/integration/file-upload.sql"),"utf8")));
  if (!foundationOnly || fileLinksOnly)console.log(run("psql",[...args,"-f","-"],artifactReviewSecurityFixture(root)+readFileSync(join(root,"tests/integration/file-links.sql"),"utf8")));
  if (!foundationOnly || fileLinksOnly)await testFileLinks({run,args,binary,childEnv,root});
  if (!foundationOnly || fileLinksOnly)console.log(run("psql",[...args,"-f","-"],artifactReviewSecurityFixture(root)+readFileSync(join(root,"tests/integration/file-archive.sql"),"utf8")));
  if (!foundationOnly || fileRlsOnly)console.log(run("psql",[...args,"-f","-"],artifactReviewSecurityFixture(root)+readFileSync(join(root,"tests/integration/file-rls.sql"),"utf8")));
  if (!foundationOnly || patentSchemaOnly)console.log(run("psql",[...args,"-f","-"],artifactReviewSecurityFixture(root)+readFileSync(join(root,"tests/integration/patent-records.sql"),"utf8")));
  if (!foundationOnly || patentCreateOnly){console.log(run("psql",[...args,"-f","-"],artifactReviewSecurityFixture(root)+readFileSync(join(root,"tests/integration/patent-create.sql"),"utf8")));testPatentCreateService({run,args,childEnv,root});}
  if (!foundationOnly || patentSearchOnly){console.log(run("psql",[...args,"-f","-"],artifactReviewSecurityFixture(root)+readFileSync(join(root,"tests/integration/patent-search.sql"),"utf8")));testPatentSearchService({run,args,childEnv,root});}
  if (!foundationOnly || patentEvidenceOnly){console.log(run("psql",[...args,"-f","-"],artifactReviewSecurityFixture(root)+readFileSync(join(root,"tests/integration/patent-evidence.sql"),"utf8")));testPatentEvidenceService({run,args,childEnv,root});if(!foundationOnly||patentWorkspaceOnly)testPatentWorkspace({run,args,childEnv,root});}
  if(!foundationOnly||patentBoundaryOnly)console.log(run("psql",[...args,"-f","-"],artifactReviewSecurityFixture(root)+readFileSync(join(root,"tests/integration/patent-analysis-boundary.sql"),"utf8")));
  if (process.argv.includes("--file-provider"))testFileUploadService({run,args,childEnv:{...childEnv,FICI_FILE_PROVIDER:"1"},root});
  if (!foundationOnly || evidenceVerifyOnly){scanEvidenceCreationPaths(root);console.log(run("psql",[...args,"-f","-"],artifactReviewSecurityFixture(root)+readFileSync(join(root,"tests/integration/evidence-analysis-boundary.sql"),"utf8")));console.log(run("psql",[...args,"-f","-"],artifactReviewSecurityFixture(root)+readFileSync(join(root,"tests/integration/evidence-verification.sql"),"utf8")));await testEvidenceVerificationConcurrency({run,args,binary,childEnv,root});}
  if (!foundationOnly || evidenceCreateOnly || evidenceVerifyOnly){console.log(run("psql",[...args,"-f","-"],artifactReviewSecurityFixture(root)+readFileSync(join(root,"tests/integration/evidence-create.sql"),"utf8")));testEvidenceCreateService({run,args,childEnv,root});}
  if (!foundationOnly || evidenceLinksOnly || evidenceCreateOnly || evidenceVerifyOnly){console.log(run("psql",[...args,"-f","-"],artifactReviewSecurityFixture(root)+readFileSync(join(root,"tests/integration/evidence-links.sql"),"utf8")));await testEvidenceLinkConcurrency({run,args,binary,childEnv,root});}
  if (!foundationOnly || evidenceSchemaOnly || evidenceCreateOnly || evidenceVerifyOnly)console.log(run("psql",[...args,"-f","-"],artifactReviewSecurityFixture(root)+readFileSync(join(root,"tests/integration/evidence-schema.sql"),"utf8")));
  if (!foundationOnly || collaborativeEditOnly) await testCollaborativeEditAcceptance({run,args,binary,childEnv,root});
  if (!foundationOnly || mindMapRlsOnly) await testMindMapRls({run,args,binary,childEnv,root});
  if (!foundationOnly || affinityRlsOnly) console.log(run("psql",[...args,"-f","-"],affinityItemFixture(root)+readFileSync(join(root,"tests/integration/affinity-rls.sql"),"utf8")));
  if (!foundationOnly || affinityItemsOnly || affinityCollaborationOnly) {console.log(run("psql",[...args,"-f","-"],affinityItemFixture(root)+readFileSync(join(root,"tests/integration/affinity-items.sql"),"utf8").split("-- Assertions")[1]));await testAffinityItemConcurrency({run,args,binary,childEnv,root});}
  if (!foundationOnly || mindMapNodeRemovalOnly || mindMapEditorOnly) await testMindMapNodeRemoval({run,args,binary,childEnv,root});
  if(!foundationOnly || session7IntegrationOnly)await testSession7Integration({run,args,binary,childEnv,root});
  if(!foundationOnly || session7OutputsOnly)await testSession7Outputs({run,args,binary,childEnv,root});
  if(!foundationOnly || session6IntegrationOnly)await testSession6Integration({run,args,binary,childEnv,root});
  if(!foundationOnly || session6OutputsOnly)await testSession6Outputs({run,args,binary,childEnv,root});
  if(!foundationOnly || mindMapClassificationOnly)await testMindMapClassification({run,args,binary,childEnv,root});
  if(!foundationOnly || mindMapVersionOnly)await testMindMapVersion({run,args,binary,childEnv,root});
  if(!foundationOnly || mindMapDraftOnly)await testMindMapDraft({run,args,binary,childEnv,root});
  if(mindMapCollaborationOnly)await testMindMapCollaboration({run,args,binary,childEnv,root});
  if (!foundationOnly || mindMapEdgesOnly) await testMindMapEdges({run,args,binary,childEnv,root});
  if (!foundationOnly || mindMapNodesOnly) await testMindMapNodes({run,args,binary,childEnv,root});
  if (!foundationOnly || mindMapCreationOnly) await testMindMapCreation({run,args,binary,childEnv,root});
  if (!foundationOnly || mindMapSchemaOnly) console.log(run("psql",[...args,"-f","-"],artifactReviewSecurityFixture(root).replaceAll("'PROBLEM_BANK'","'MIND_MAP'")+readFileSync(join(root,"tests/integration/mind-map-schema.sql"),"utf8")));
  if (!foundationOnly || gapCaptureOnly) await testGapCapture({run,args,binary,childEnv,root});
  if (!foundationOnly || affinityStructureOnly) await testAffinityStructure({run,args,binary,childEnv,root});
  if (!foundationOnly || affinityCollaborationOnly) await testAffinityCollaboration({run,args,binary,childEnv,root});
  if (!foundationOnly || affinityOperationsOnly) {console.log(run("psql",[...args,"-f","-"],affinityOperationFixture(root)+readFileSync(join(root,"tests/integration/affinity-operations.sql"),"utf8").split("-- Assertions")[1]));await testAffinityConcurrency({run,args,binary,childEnv,root});}
  if (!foundationOnly || affinitySchemaOnly) console.log(run("psql",[...args,"-f","-"],brainstormSchemaFixture(root)+readFileSync(join(root,"tests/integration/affinity-schema.sql"),"utf8")));
  if (!foundationOnly || revisionCycleOnly) console.log(run("psql",[...args,"-f","-"],activityArtifactFixture(root)+readFileSync(join(root,"tests/integration/artifact-revision-cycle.sql"),"utf8")));
  if (!(selectedSecurityGroup || revisionCycleOnly || draftConflictsOnly || approvalRollbackOnly || terminalConcurrencyOnly)) console.log(run("psql",[...args,"-f","-"],artifactReviewSecurityFixture(root)+readFileSync(join(root,"tests/integration/review-workflow-acceptance.sql"),"utf8")));
  if (!(selectedSecurityGroup || revisionCycleOnly || draftConflictsOnly || reviewAcceptanceOnly || approvalRollbackOnly || terminalConcurrencyOnly)) {
    const lifecycle = readFileSync(join(root,"tests/integration/review-workflow-acceptance.sql"),"utf8");
    const boundary = "-- Existing supersession semantics exercised as an isolated branch.";
    if (!lifecycle.includes(boundary)) throw new Error("Version acceptance lifecycle boundary missing");
    console.log(run("psql",[...args,"-f","-"],artifactReviewSecurityFixture(root)+lifecycle.split(boundary)[0]+readFileSync(join(root,"tests/integration/versioning-acceptance.sql"),"utf8")));
  }
  if (!(selectedSecurityGroup || revisionCycleOnly || draftConflictsOnly || reviewAcceptanceOnly || versionAcceptanceOnly || terminalConcurrencyOnly)) {
    const handoff = readFileSync(join(root,"tests/integration/activity-artifact-handoff.sql"),"utf8");
    const boundary = "select public.approve_artifact((data->>'id')::uuid) from artifact_handoff where label='submission';";
    if (!handoff.includes(boundary)) throw new Error("Approval rollback fixture boundary missing");
    console.log(run("psql",[...args,"-f","-"],activityArtifactFixture(root)+handoff.split(boundary)[0]+readFileSync(join(root,"tests/integration/approval-rollback-acceptance.sql"),"utf8")));
  }
  if (!foundationOnly || draftConflictsOnly) console.log(run("psql",[...args,"-f","-"],artifactReviewSecurityFixture(root)+readFileSync(join(root,"tests/integration/artifact-draft-conflicts.sql"),"utf8")));
  if (!foundationOnly || draftConflictsOnly) await testArtifactDraftConcurrency({run,args,binary,childEnv,root});
  if (!foundationOnly || terminalConcurrencyOnly) await testReviewTerminalConcurrency({run,args,binary,childEnv,root});
  if (rlsOnly) {
    console.log(run("psql",[...args,"-f","-"],artifactReviewSecurityFixture(root)+readFileSync(join(root,"tests/integration/artifact-current-pointer-integrity.sql"),"utf8")));
    console.log(run("psql",[...args,"-f","-"],artifactReviewSecurityFixture(root)+readFileSync(join(root,"tests/integration/artifact-review-rls.sql"),"utf8")));
  }
  // Generic multiple-candidate regression uses a non-Bank type; M9.11 and
  // M8.21 retain explicit PROBLEM_BANK approval/handoff coverage.
  if (handoffOnly) console.log(run("psql",[...args,"-f","-"],activityArtifactFixture(root).replaceAll("'PROBLEM_BANK'","'PITCH_DECK_RECORD'")+readFileSync(join(root,"tests/integration/activity-artifact-handoff.sql"),"utf8").replaceAll("'PROBLEM_BANK'","'PITCH_DECK_RECORD'")));
  if (!foundationOnly || m10LeakageOnly) console.log(run("psql",[...args,"-f","-"],decisionArtifactFixture(root).replace("update public.curriculum_versions set status='approved'", "update public.session_definitions set session_number=5,sequence=5,title='M10.20 isolated Session 5' where id='00000000-0000-4000-8000-000000950702';\nupdate public.curriculum_versions set status='approved'")+readFileSync(join(root,"tests/integration/voting-decision-leakage.sql"),"utf8")));
  if (!foundationOnly || m10ConcurrencyOnly) await suite("test-m10-concurrency-hardening","scripts/test-m10-concurrency-hardening.mjs",()=>testM10ConcurrencyHardening({run,args,binary,childEnv,root}));
  if (!foundationOnly || session5Only) await suite("test-session5-integration","scripts/test-session5-integration.mjs",()=>testSession5Integration({run,args,root}));
  if (!foundationOnly || session4Only || m9LeakageOnly) testSession4Integration({run,args,root});
  if (!foundationOnly || scamperPrivacyOnly || m9LeakageOnly || personalSharingOnly) console.log(run("psql",[...args,"-f","-"],artifactReviewSecurityFixture(root)+readFileSync(join(root,"tests/integration/scamper-privacy.sql"),"utf8")));
  if (!foundationOnly || scamperPromotionOnly || personalSharingOnly) {
    console.log(run("psql",[...args,"-f","-"],artifactReviewSecurityFixture(root)+readFileSync(join(root,"tests/integration/scamper-promotion.sql"),"utf8")));
    await testScamperPromotionConcurrency({run,args,binary,childEnv,root});
  }
  if (!foundationOnly || scamperOperationsOnly || personalSharingOnly) console.log(run("psql",[...args,"-f","-"],artifactReviewSecurityFixture(root)+readFileSync(join(root,"tests/integration/scamper-operations.sql"),"utf8")));
  if (!foundationOnly || m9ActivityIntegrationOnly) { console.log(run("psql",[...args,"-f","-"],m9ActivityIntegrationFixture(root)+readFileSync(join(root,"tests/integration/m9-activity-integration-setup.sql"),"utf8")+readFileSync(join(root,"tests/integration/m9-activity-integration.sql"),"utf8")));
    await testM9ActivityReconnect({run,args,root,binary,childEnv});
    testM9BankReconnect({run,args,root});
  }
  if (!foundationOnly || solutionBankOnly) {
    console.log(run("psql",[...args,"-f","-"],solutionBankFixture(root)+readFileSync(join(root,"tests/integration/solution-bank-setup.sql"),"utf8")+readFileSync(join(root,"tests/integration/solution-bank.sql"),"utf8")));
    await testSolutionBankConcurrency({run,args,binary,childEnv,root});
  }
  if (!foundationOnly || solutionPromotionOnly) {
    console.log(run("psql",[...args,"-f","-"],solutionPromotionFixture(root)+readFileSync(join(root,"tests/integration/solution-promotion.sql"),"utf8")));
    await testSolutionPromotionConcurrency({run,args,binary,childEnv,root});
  }
  if (!foundationOnly || problemBankOnly) {console.log(run("psql",[...args,"-f","-"],problemBankFixture(root)+readFileSync(join(root,"tests/integration/problem-bank-setup.sql"),"utf8")+readFileSync(join(root,"tests/integration/problem-bank.sql"),"utf8")));
    await testProblemBankConcurrency({run,args,binary,childEnv,root});
  }
  if (!foundationOnly || problemStormingOnly) console.log(run("psql",[...args,"-f","-"],problemStormingFixture(root)+readFileSync(join(root,"tests/integration/problem-storming.sql"),"utf8")));
  if (!foundationOnly || brainstormPromotionOnly) {
    console.log(run("psql",[...args,"-f","-"],brainstormPromotionFixture(root)+readFileSync(join(root,"tests/integration/brainstorm-promotion.sql"),"utf8")));
    await testBrainstormPromotionConcurrency({run,args,binary,childEnv,root});
  }
  if (!foundationOnly || brainstormRevealOnly || m9LeakageOnly) {
    const reveal = readFileSync(join(root,"tests/integration/brainstorm-reveal.sql"),"utf8");
    const boundary = "-- Lead reveals two peer-owned sources.";
    const security = readFileSync(join(root,"tests/integration/brainstorm-rls-security.sql"),"utf8").split("-- M9.16 AFTER REVEAL AND REMOVAL");
    if (!reveal.includes(boundary) || security.length !== 2) throw new Error("Brainstorm security fixture boundary missing");
    console.log(run("psql",[...args,"-f","-"],brainstormRevealFixture(root)+readFileSync(join(root,"tests/integration/brainstorm-create.sql"),"utf8").split("-- A trusted own revealed fixture")[0]+reveal.replace(boundary,()=>security[0]+boundary).replace("rollback;",()=>security[1]+"\nrollback;")));
  }
  if (!foundationOnly || brainstormPrivacyOnly || m9LeakageOnly) console.log(run("psql",[...args,"-f","-"],brainstormCreateFixture(root)+readFileSync(join(root,"tests/integration/brainstorm-create.sql"),"utf8").split("-- A trusted own revealed fixture")[0]+readFileSync(join(root,"tests/integration/brainstorm-privacy.sql"),"utf8")));
  if (!foundationOnly || brainstormCreateOnly) console.log(run("psql",[...args,"-f","-"],brainstormCreateFixture(root)+readFileSync(join(root,"tests/integration/brainstorm-create.sql"),"utf8")));
  if (!foundationOnly || session5Only || decisionAcceptanceOnly) {
    const setup=votingCreationFixture(root)+readFileSync(join(root,"tests/integration/voting-creation.sql"),"utf8").split("do $$declare a uuid;begin")[0];
    console.log(run("psql",[...args,"-f","-"],setup+readFileSync(join(root,"tests/integration/decision-finalization-setup.sql"),"utf8")+readFileSync(join(root,"tests/integration/decision-acceptance.sql"),"utf8")));
  }
  if (!foundationOnly || decisionAcceptanceOnly || session5Only || decisionRlsOnly) {
    console.log(run("psql",[...args,"-f","-"],decisionArtifactFixture(root)+readFileSync(join(root,"tests/integration/decision-rls.sql"),"utf8")));
  }
  if (!foundationOnly || votingAcceptanceOnly || session5Only || votingRlsOnly) {
    const setup=votingCreationFixture(root)+readFileSync(join(root,"tests/integration/voting-creation.sql"),"utf8").split("do $$declare a uuid;begin")[0];
    console.log(run("psql",[...args,"-f","-"],setup+readFileSync(join(root,"tests/integration/voting-rls.sql"),"utf8")));
  }
  if (!foundationOnly || decisionAcceptanceOnly || session5Only || decisionArtifactOnly) {
    console.log(run("psql",[...args,"-f","-"],decisionArtifactFixture(root)+readFileSync(join(root,"tests/integration/decision-artifact.sql"),"utf8")));
    await suite("test-decision-artifact-concurrency","scripts/test-decision-artifact-concurrency.mjs",()=>testDecisionArtifactConcurrency({run,args,binary,childEnv,root}));
  }
  if (!foundationOnly || decisionAcceptanceOnly || session5Only || decisionSupersessionOnly) {
    const setup=votingCreationFixture(root)+readFileSync(join(root,"tests/integration/voting-creation.sql"),"utf8").split("do $$declare a uuid;begin")[0]+readFileSync(join(root,"tests/integration/decision-finalization-setup.sql"),"utf8")+readFileSync(join(root,"tests/integration/decision-supersession-setup.sql"),"utf8");
    console.log(run("psql",[...args,"-f","-"],setup+readFileSync(join(root,"tests/integration/decision-supersession.sql"),"utf8")));
    await suite("test-decision-supersession-concurrency","scripts/test-decision-supersession-concurrency.mjs",()=>testDecisionSupersessionConcurrency({run,args,binary,childEnv,root}));
  }
  if (!foundationOnly || decisionLinkGroups) {
    const setup=votingCreationFixture(root)+readFileSync(join(root,"tests/integration/voting-creation.sql"),"utf8").split("do $$declare a uuid;begin")[0]+readFileSync(join(root,"tests/integration/decision-finalization-setup.sql"),"utf8");
    for(const group of ["archival","targets","scope","retry","finalized","rollback","client"]){
      const start=Date.now();console.log(`[M1011 GROUP START] ${group} ${new Date(start).toISOString()}`);
      console.log(run("psql",[...args,"-f","-"],setup+readFileSync(join(root,`tests/integration/decision-links-${group}.sql`),"utf8")));
      console.log(`[M1011 GROUP PASS] ${group} ${new Date().toISOString()} elapsed=${Date.now()-start}ms exit=0`);
    }
    await suite("test-decision-link-concurrency","scripts/test-decision-link-concurrency.mjs",()=>testDecisionLinkConcurrency({run,args,binary,childEnv,root}));
  }
  if (!foundationOnly || decisionAcceptanceOnly || decisionLinksOnly) {
    const setup=votingCreationFixture(root)+readFileSync(join(root,"tests/integration/voting-creation.sql"),"utf8").split("do $$declare a uuid;begin")[0];
    console.log(run("psql",[...args,"-f","-"],setup+readFileSync(join(root,"tests/integration/decision-finalization-setup.sql"),"utf8")+readFileSync(join(root,"tests/integration/decision-links.sql"),"utf8")));
    await suite("test-decision-link-concurrency","scripts/test-decision-link-concurrency.mjs",()=>testDecisionLinkConcurrency({run,args,binary,childEnv,root}));
  }
  if (!foundationOnly || decisionAcceptanceOnly || session5Only || decisionFinalizationOnly) {
    const setup=votingCreationFixture(root)+readFileSync(join(root,"tests/integration/voting-creation.sql"),"utf8").split("do $$declare a uuid;begin")[0];
    console.log(run("psql",[...args,"-f","-"],setup+readFileSync(join(root,"tests/integration/decision-finalization-setup.sql"),"utf8")+readFileSync(join(root,"tests/integration/decision-finalization.sql"),"utf8")));
    await testDecisionFinalizationConcurrency({run,args,binary,childEnv,root});
  }
  if (!foundationOnly || decisionAcceptanceOnly || decisionCreationOnly) {
    const setup=votingCreationFixture(root)+readFileSync(join(root,"tests/integration/voting-creation.sql"),"utf8").split("do $$declare a uuid;begin")[0];
    console.log(run("psql",[...args,"-f","-"],setup+readFileSync(join(root,"tests/integration/decision-creation.sql"),"utf8")));
  }
  if (!foundationOnly || decisionSchemaOnly) {
    const setup=votingCreationFixture(root)+readFileSync(join(root,"tests/integration/voting-creation.sql"),"utf8").split("do $$declare a uuid;begin")[0];
    console.log(run("psql",[...args,"-f","-"],setup+readFileSync(join(root,"tests/integration/decision-schema.sql"),"utf8")));
  }
  if (!foundationOnly || votingAcceptanceOnly || decisionAcceptanceOnly || session5Only || votingResultsOnly) {
    const setup=votingCreationFixture(root)+readFileSync(join(root,"tests/integration/voting-creation.sql"),"utf8").split("do $$declare a uuid;begin")[0];
    console.log(run("psql",[...args,"-f","-"],setup+readFileSync(join(root,"tests/integration/voting-results.sql"),"utf8").replace("rollback;",()=>readFileSync(join(root,"tests/integration/voting-acceptance.sql"),"utf8")+"\nrollback;")));
  }
  if (!foundationOnly || votingAcceptanceOnly || session5Only || votingCloseOnly) {
    const setup=votingCreationFixture(root)+readFileSync(join(root,"tests/integration/voting-creation.sql"),"utf8").split("do $$declare a uuid;begin")[0];
    console.log(run("psql",[...args,"-f","-"],setup+readFileSync(join(root,"tests/integration/voting-close.sql"),"utf8")));
    await testVotingCloseConcurrency({run,args,binary,childEnv,root});
    await suite("test-voting-vote-close-concurrency","scripts/test-voting-vote-close-concurrency.mjs",()=>testVotingVoteCloseConcurrency({run,args,binary,childEnv,root}));
  }
  if (!foundationOnly || votingAcceptanceOnly || session5Only || votingRevealOnly) {
    const setup=votingCreationFixture(root)+readFileSync(join(root,"tests/integration/voting-creation.sql"),"utf8").split("do $$declare a uuid;begin")[0];
    console.log(run("psql",[...args,"-f","-"],setup+readFileSync(join(root,"tests/integration/voting-reveal.sql"),"utf8")));
    await testVotingRevealConcurrency({run,args,binary,childEnv,root});
  }
  if (!foundationOnly || votingAcceptanceOnly || session5Only || votingCastOnly) {
    const setup=votingCreationFixture(root)+readFileSync(join(root,"tests/integration/voting-creation.sql"),"utf8").split("do $$declare a uuid;begin")[0];
    console.log(run("psql",[...args,"-f","-"],setup+readFileSync(join(root,"tests/integration/voting-cast.sql"),"utf8")));
    await testVotingCastConcurrency({run,args,binary,childEnv,root});
  }
  if (!foundationOnly || votingAcceptanceOnly || votingOpeningOnly) {
    const setup=votingCreationFixture(root)+readFileSync(join(root,"tests/integration/voting-creation.sql"),"utf8").split("do $$declare a uuid;begin")[0];
    console.log(run("psql",[...args,"-f","-"],setup+readFileSync(join(root,"tests/integration/voting-opening.sql"),"utf8")));
    await testVotingOpeningConcurrency({run,args,binary,childEnv,root});
  }
  if (!foundationOnly || votingAcceptanceOnly || votingCreationOnly) console.log(run("psql",[...args,"-f","-"],votingCreationFixture(root)+readFileSync(join(root,"tests/integration/voting-creation.sql"),"utf8")));
  if (!foundationOnly || votingSchemaOnly) console.log(run("psql",[...args,"-f","-"],brainstormSchemaFixture(root)+readFileSync(join(root,"tests/integration/voting-schema.sql"),"utf8")));
  if (!foundationOnly || brainstormSchemaOnly) console.log(run("psql",[...args,"-f","-"],brainstormSchemaFixture(root)+readFileSync(join(root,"tests/integration/brainstorm-schema.sql"),"utf8")));
  if (!foundationOnly || scamperSchemaOnly || personalSharingOnly) console.log(run("psql",[...args,"-f","-"],artifactReviewSecurityFixture(root)+readFileSync(join(root,"tests/integration/scamper-schema.sql"),"utf8")));
  if (!foundationOnly) {
  console.log(run("psql",[...args,"-f","-"],artifactReviewSecurityFixture(root)+readFileSync(join(root,"tests/integration/artifact-current-pointer-integrity.sql"),"utf8")));
  console.log(run("psql",[...args,"-f","-"],artifactReviewSecurityFixture(root)+readFileSync(join(root,"tests/integration/artifact-review-rls.sql"),"utf8")));
  // Preserve multiple generic candidates without competing canonical Banks.
  console.log(run("psql",[...args,"-f","-"],activityArtifactFixture(root).replaceAll("'PROBLEM_BANK'","'PITCH_DECK_RECORD'")+readFileSync(join(root,"tests/integration/activity-artifact-handoff.sql"),"utf8").replaceAll("'PROBLEM_BANK'","'PITCH_DECK_RECORD'")));
  const baselinePrefix=readFileSync(join(root,"tests/integration/approve-artifact.sql"),"utf8").split("-- Submit/review the existing second Draft")[0];
  console.log(run("psql",[...args,"-f","-"],baselinePrefix+readFileSync(join(root,"tests/integration/project-baseline.sql"),"utf8")));
  // Two independent database sessions race provisioning for the same identity.
  run("psql",[...args,"-c", "insert into auth.users(id,email) values('00000000-0000-4000-8000-000000001510','workspace-concurrent@example.test'); select public.provision_user_profile('00000000-0000-4000-8000-000000001510','active');"]);
  const raceSql="begin; set local role authenticated; select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000001510',true); select public.create_personal_workspace()->>'id'; select pg_sleep(0.5); commit;";
  const race=()=>new Promise((done,reject)=>{const child=spawn(binary("psql"),[...args,"-t","-A","-c",raceSql],{cwd:root,windowsHide:true,env:childEnv});let out="",err="";child.stdout.on("data",x=>out+=x);child.stderr.on("data",x=>err+=x);child.on("error",reject);child.on("close",code=>code===0?done(out):reject(new Error("Provisioning race failed: "+err)));});
  const results=await Promise.all([race(),race()]);
  const ids=results.map(out=>out.split(/\r?\n/).filter(x=>/^[0-9a-f-]{36}$/.test(x)));
  if(ids.some(x=>x.length!==2)||ids[0][1]!==ids[1][1])throw new Error("Concurrent provisioning did not reuse identity");
  const count=run("psql",[...args,"-t","-A","-c","select count(*) from public.workspaces where owner_user_id='00000000-0000-4000-8000-000000001510' and workspace_type='PERSONAL' and status='active';"]).trim();
  if(count!=="1")throw new Error("Concurrent provisioning created duplicates");
  console.log("Concurrent independent-session Personal provisioning PASS");
  const fixtures = JSON.parse(readFileSync(join(root, "tests/fixtures/m2-authorization.json"), "utf8"));
  const values = { ...fixtures.users, ...fixtures.scopes };
  const acceptanceSql = readFileSync(join(root, "tests/integration/rbac-acceptance.sql"), "utf8").replace(/\{\{(\w+)\}\}/g, (_, key) => {
    const value = values[key];
    if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/.test(value ?? "")) throw new Error("Invalid acceptance fixture UUID");
    return value;
  });
  console.log(run("psql", [...args, "-f", "-"], acceptanceSql));
  await testArtifactApprovalConcurrency({run,args,binary,childEnv,root});
  await testActivityArtifactConcurrency({run,args,binary,childEnv,root});
  await testProjectBaselineConcurrency({run,args,binary,childEnv,root});
  await testArtifactReopenConcurrency({run,args,binary,childEnv,root});
  await testArtifactResubmissionConcurrency({run,args,binary,childEnv,root});
  await testArtifactRevisionConcurrency({run,args,binary,childEnv,root});
  await testArtifactReviewConcurrency({run,args,binary,childEnv,root});
  await testArtifactSubmissionConcurrency({run,args,binary,childEnv,root});
  await testArtifactArchiveConcurrency({run,args,binary,childEnv,root});
  await testArtifactVersionConcurrency({run,args,binary,childEnv,root});
  await testArtifactCreationConcurrency({run,args,binary,childEnv,root});
  await testActivityStartConcurrency({run,args,binary,childEnv,root});
  testActivityResumeReconnect({run,args,root});
  testActivityResumeAcceptance({run,args,root});
  await testActivityInputConcurrency({run,args,binary,childEnv,root});
  await testActivityOutputConcurrency({run,args,binary,childEnv,root});
  await testActivityCompletionConcurrency({run,args,binary,childEnv,root});
  const codes = run("psql", [...args, "-t", "-A", "-c", "select json_agg(code order by code) from public.roles;"]).trim();
  console.log(`FICI_ROLE_CODES=${codes}`);
  const catalog = run("psql", [...args, "-t", "-A", "-c", "select json_object_agg(code, id) from public.roles;"]).trim();
  console.log(`FICI_ROLE_IDS=${catalog}`);
  const sessions = run("psql", [...args, "-t", "-A", "-c", "select json_agg(json_build_object('id',id,'session_number',session_number,'title',title,'description',description,'learning_goal',learning_goal,'sequence',sequence,'status',status) order by sequence) from public.session_definitions where curriculum_version_id='00000000-0000-4000-8000-000000000602';"]).trim();
  console.log(`FICI_SESSIONS=${sessions}`);
  const activities = run("psql", [...args, "-t", "-A", "-c", "select json_agg(to_jsonb(a)-'created_at'-'updated_at' order by sequence) from public.activity_definitions a;"]).trim();
  console.log(`FICI_ACTIVITIES=${activities}`);
  console.log("Profile and role migrations, seeds, provisioning, grants, and RLS tests passed.");
  }
  if(!foundationOnly||notificationRealtimeOnly)await testNotificationCommit({binary,args,env:childEnv,run});
  if(submissionNotificationsOnly){
   await testArtifactSubmissionConcurrency({run,args,binary,childEnv,root});
   await testArtifactReviewConcurrency({run,args,binary,childEnv,root});
   if(approvalNotificationsOnly)await testArtifactApprovalConcurrency({run,args,binary,childEnv,root});
   if(revisionNotificationsOnly)await testArtifactRevisionConcurrency({run,args,binary,childEnv,root});
   await testArtifactResubmissionConcurrency({run,args,binary,childEnv,root});
  }
  if(!foundationOnly||commentNotificationsOnly)await testCommentNotificationCommit({root,binary,args,env:childEnv,run});
  if(!foundationOnly||approvalNotificationsOnly)await testApprovalNotificationCommit({root,binary,args,env:childEnv,run});
  if(!foundationOnly||revisionNotificationsOnly)await testRevisionNotificationCommit({root,binary,args,env:childEnv,run});
  if(!foundationOnly||submissionNotificationsOnly)await testSubmissionNotificationCommit({root,binary,args,env:childEnv,run});
  if(notificationIntegrityOnly){
   for(const file of ['submission-notifications','approval-notifications'])console.log(run('psql',[...args,'-qAt'],artifactReviewSecurityFixture(root)+readFileSync(join(root,'tests/integration',file+'.sql'),'utf8')));
   await testSubmissionNotificationCommit({root,binary,args,env:childEnv,run});
   await testApprovalNotificationCommit({root,binary,args,env:childEnv,run});
  }
  if(!foundationOnly||emailProviderOnly||notificationIntegrityOnly)testEmailProviderIsolation({root,run,args,childEnv,integrityOnly:notificationIntegrityOnly});
  if(!foundationOnly||currentWorkOnly||pilotMasterOnly||pilotStudentOnly||pilotNotificationsOnly||pilotProgressOnly)testStudentCurrentWork({root,run,args,childEnv,pilotMasterOnly,pilotStudentOnly,pilotNotificationsOnly,pilotProgressOnly});
  if(!foundationOnly||shareNotificationsOnly)await testShareNotificationCommit({root,binary,args,env:childEnv,run});
} catch (error) {
  try { console.error(readFileSync(join(cluster, "server.log"), "utf8")); } catch { /* Startup may not have reached logging. */ }
  throw error;
} finally {
  if (started) {
    run("pg_ctl", ["-D", cluster, "-m", "fast", "-w", "stop"]);
    if (server.exitCode === null) await new Promise((done) => server.once("exit", done));
  }
  else if (server?.pid && server.exitCode === null) {
    server.kill();
    await new Promise((done) => server.once("exit", done));
  }
  // Verify the exact generated target before recursive removal on Windows.
  const target = realpathSync(cluster);
  const child = relative(tempRoot, target);
  if (!child.startsWith("fici-profile-tests-") || child.includes("..") || isAbsolute(child) || dirname(target) !== tempRoot) {
    throw new Error(`Unexpected temporary cluster path: ${target}`);
  }
  rmSync(target, { recursive: true, force: true, maxRetries: 5, retryDelay: 200 });
}





















