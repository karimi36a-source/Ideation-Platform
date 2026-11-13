import type {LiveRoomMapping} from "@/features/live-classroom/mapping-schema";
import type {AiUsageEvent} from "@/features/ai/usage-schema";
import type {AiPromptTemplate,CreateAiPromptTemplateInput} from "@/features/ai/prompt-template-schema";
import type {AIContextReference} from "@/features/ai/context-schema";
import type {AIOutput} from "@/features/ai/schema";
import type {Session10Checkpoint} from "@/features/ai/session10";
import type {SharedComment} from "@/features/shares/comment-schema";
import type {ShareSnapshot} from "@/features/shares/snapshot-schema";
import type {Share} from "@/features/shares/schema";
import type {ActivityResearchLink} from "@/features/activities/research-schema";
import type {LinkPatentToEvidenceInput} from "@/features/patents/evidence-schema";
import type {CreatePatentSearchLogInput,PatentSearchLog} from "@/features/patents/search-schema";
import type {CreatePatentRecordInput} from "@/features/patents/create-schema";
import type {PatentRecord} from "@/features/patents/schema";
import type {FileRecord,FileLink} from "@/features/files/schema";
import type {UploadRequest} from "@/features/files/upload-schema";
import type {LinkFileInput} from "@/features/files/link-schema";
import type {EvidenceVerificationHistory} from "@/features/evidence/verify-schema";
import type {EvidenceLink,LinkEvidenceInput} from "@/features/evidence/link-schema";
import type {Evidence} from "@/features/evidence/schema";
import type {MindMap,MindMapNode,MindMapEdge} from "@/features/mind-map/schema";
import type {AffinityGroup,AffinityGroupItem} from "@/features/affinity/schema";
import type {Decision,DecisionOption,DecisionParticipant,DecisionLink} from "@/features/decisions/schema";
import type {VotingResults} from "@/features/voting/results-schema";
import type {CreatedVotingSession} from "@/features/voting/create-schema";
import type {VotingSession,VotingOption,Vote} from "@/features/voting/schema";
import type {ComposedSolutionBank} from "@/features/brainstorming/bank-schema";
import type {ComposedProblemBank} from "@/features/problem-storming/bank-schema";
import type {ProblemStormingProblem} from "@/features/problem-storming/schema";
import type {RevealBrainstormResult} from "@/features/brainstorming/reveal-schema";
import type {BrainstormEntry} from "@/features/brainstorming/schema";
import type {ScamperEntry} from "@/features/scamper/schema";
import type {ProjectBaselineItem} from "@/features/projects/baseline-schema";
import type {ReviewAction,FeedbackItem} from "@/features/artifacts/review-schema";
import type {Submission} from "@/features/artifacts/submission-schema";
import type {CreatedArtifact} from "@/features/artifacts/create-schema";
import type {ArtifactObjectLink} from "@/features/artifacts/object-link-schema";
import type {ArtifactVersion} from "@/features/artifacts/version-schema";
import type {Artifact} from "@/features/artifacts/schema";
import type {ActivityInput,ActivityOutput} from "@/features/activities/io-schema";
import type {ActivityParticipant} from "@/features/activities/participant-schema";
import type {ActivityInstance} from "@/features/activities/instance-schema";
import type {ProjectChangeLog} from "@/features/projects/change-log-schema";
import type {DevelopmentRelationship} from "@/features/projects/relationship-schema";
import type {ProblemDetails,IdeaDetails} from "@/features/projects/typed-detail-schema";
import type { DevelopmentObject } from "@/features/projects/object-schema";
import type { ProjectProgramLink } from "@/features/projects/program-link-schema";
import type { ProjectMembership } from "@/features/projects/membership-schema";
import type { DevelopmentProject } from "@/features/projects/schema";
import type { Workspace } from "@/features/workspaces/schema";
import type { Team } from "@/features/teams/schema";
import type { TeamMembership } from "@/features/teams/membership-schema";
import type { ChatChannel,ChatMembership,ChatMessage } from "@/features/chat/schema";
import type { Enrollment } from "@/features/enrollments/schema";
import type { Cohort } from "@/features/cohorts/schema";
import type { ActivityDependency } from "@/features/activity-dependencies/schema";
import type { ActivityDefinition } from "@/features/activities/schema";
import type { SessionDefinition } from "@/features/sessions/schema";
import type { Program, CurriculumVersion } from "@/features/programs/schema";
import type { Organization } from "@/features/organizations/schema";
import type { UserProfile } from "@/features/users/schema";
import type { RoleCode } from "@/lib/auth/role-codes";
import type { RoleAssignment } from "@/features/auth/role-assignments-schema";

export type SystemRole = {
  id: string;
  code: RoleCode;
  name: string;
  description: string;
  is_system_role: boolean;
  created_at: string;
  updated_at: string;
};

/** M1/M2.4 schema contract; keep aligned with the approved migrations. */
export type Database = {
  public: {
    Tables: {
      live_team_breakout_rooms:{Row:{id:string;live_session_room_id:string;team_id:string;provider:'DAILY';provider_room_ref:string;status:'ACTIVE'|'EXPIRED';created_by:string;created_at:string;updated_at:string;ended_at:string|null};Insert:never;Update:never;Relationships:[]};
      live_session_rooms:{Row:LiveRoomMapping;Insert:never;Update:never;Relationships:[]};
      notifications:{Row:{id:string;recipient_user_id:string;notification_type:string;title:string;body:string;entity_type:string|null;entity_id:string|null;read_at:string|null;created_at:string;metadata:Record<string,unknown>;idempotency_digest:string|null;request_fingerprint:string|null};Insert:never;Update:never;Relationships:[]};
      ai_context_references:{Row:AIContextReference;Insert:never;Update:never;Relationships:[]};
      session10_reconstruction_checkpoints:{Row:Session10Checkpoint;Insert:never;Update:never;Relationships:[]};
      ai_task_operations:{Row:{id:string;requested_by:string;idempotency_key:string;request_fingerprint:string;project_id:string;workspace_id:string;activity_instance_id:string;task_type:string;ai_role:string;model_profile:AiUsageEvent['model_profile'];status:'running'|'retryable'|'completed';attempt_id:string;output_id:string|null;created_at:string;session10_checkpoint_id:string|null;session10_gap_id:string|null;session10_gap_share_id:string|null};Insert:never;Update:never;Relationships:[]};
      ai_usage_events:{Row:AiUsageEvent;Insert:never;Update:never;Relationships:[]};
      ai_prompt_templates:{Row:AiPromptTemplate;Insert:never;Update:never;Relationships:[]};
      ai_outputs:{Row:AIOutput;Insert:never;Update:never;Relationships:[]};
      share_comments:{Row:SharedComment;Insert:never;Update:never;Relationships:[]};
      share_snapshots:{Row:ShareSnapshot;Insert:never;Update:never;Relationships:[]};
      shares:{Row:Share;Insert:never;Update:never;Relationships:[]};
      evidence_verification_history:{Row:EvidenceVerificationHistory;Insert:never;Update:never;Relationships:[]};
      evidence_links:{Row:EvidenceLink;Insert:never;Update:never;Relationships:[]};
      patent_search_logs:{Row:PatentSearchLog;Insert:never;Update:never;Relationships:[]};
      patent_records:{Row:PatentRecord;Insert:never;Update:never;Relationships:[]};
      files:{Row:FileRecord;Insert:never;Update:never;Relationships:[]};
      file_upload_requests:{Row:UploadRequest;Insert:never;Update:never;Relationships:[]};
      file_links:{Row:FileLink;Insert:never;Update:never;Relationships:[]};
      evidence:{Row:Evidence;Insert:never;Update:never;Relationships:[]};
      mind_maps:{Row:MindMap;Insert:Pick<MindMap,"artifact_id"|"artifact_version_id"> & Partial<MindMap>;Update:Partial<MindMap>;Relationships:[]};
      mind_map_nodes:{Row:MindMapNode;Insert:Pick<MindMapNode,"mind_map_id"|"node_type"|"label"|"created_by"> & Partial<MindMapNode>;Update:Partial<MindMapNode>;Relationships:[]};
      mind_map_edges:{Row:MindMapEdge;Insert:Pick<MindMapEdge,"mind_map_id"|"source_node_id"|"target_node_id"|"edge_type"> & Partial<MindMapEdge>;Update:Partial<MindMapEdge>;Relationships:[]};
      affinity_groups:{Row:AffinityGroup;Insert:Pick<AffinityGroup,"activity_instance_id"|"name"|"sequence"|"created_by"> & Partial<AffinityGroup>;Update:Partial<AffinityGroup>;Relationships:[]};
      affinity_group_items:{Row:AffinityGroupItem;Insert:Pick<AffinityGroupItem,"affinity_group_id"|"position"|"added_by"> & Partial<AffinityGroupItem>;Update:Partial<AffinityGroupItem>;Relationships:[]};
      artifact_decision_sources:{Row:import("zod").infer<typeof import("@/features/decisions/artifact").decisionArtifactSourceSchema>;Insert:never;Update:never;Relationships:[]};
      decisions:{Row:Decision;Insert:Pick<Decision,"project_id"|"workspace_id"|"title"|"question"|"method"|"decision_owner_user_id"> & Partial<Decision>;Update:Partial<Decision>;Relationships:[]};
      decision_options:{Row:DecisionOption;Insert:Pick<DecisionOption,"decision_id"|"label"> & Partial<DecisionOption>;Update:Partial<DecisionOption>;Relationships:[]};
      decision_participants:{Row:DecisionParticipant;Insert:Pick<DecisionParticipant,"decision_id"|"user_id"|"role"> & Partial<DecisionParticipant>;Update:Partial<DecisionParticipant>;Relationships:[]};
      decision_links:{Row:DecisionLink;Insert:Pick<DecisionLink,"decision_id"|"linked_entity_type"|"linked_entity_id"|"relationship_type"> & Partial<DecisionLink>;Update:never;Relationships:[]};
      voting_sessions:{Row:VotingSession;Insert:Pick<VotingSession,"activity_instance_id"|"voting_type"|"vote_limit"|"created_by"> & Partial<VotingSession>;Update:Partial<VotingSession>;Relationships:[]};
      voting_options:{Row:VotingOption;Insert:Pick<VotingOption,"voting_session_id"|"label"|"sequence"> & Partial<VotingOption>;Update:Partial<VotingOption>;Relationships:[]};
      votes:{Row:Vote;Insert:Pick<Vote,"voting_session_id"|"voting_option_id"|"user_id"|"value"> & Partial<Vote>;Update:never;Relationships:[]};
      project_baseline_items:{Row:ProjectBaselineItem;Insert:Pick<ProjectBaselineItem,"project_id"|"baseline_type"|"artifact_id"|"artifact_version_id"|"set_by"> & Partial<ProjectBaselineItem>;Update:never;Relationships:[]};
      artifact_object_links:{Row:ArtifactObjectLink;Insert:Pick<ArtifactObjectLink,"artifact_id"|"artifact_version_id"|"development_object_id"> & Partial<ArtifactObjectLink>;Update:Partial<ArtifactObjectLink>;Relationships:[]};
      artifact_versions:{Row:ArtifactVersion;Insert:Pick<ArtifactVersion,"artifact_id"|"version_number"|"content_snapshot"|"status"|"created_by"> & Partial<ArtifactVersion>;Update:Partial<ArtifactVersion>;Relationships:[]};
      review_actions:{Row:ReviewAction;Insert:Partial<ReviewAction>;Update:Partial<ReviewAction>;Relationships:[]};
      feedback_items:{Row:FeedbackItem;Insert:Partial<FeedbackItem>;Update:Partial<FeedbackItem>;Relationships:[]};
      submissions:{Row:Submission;Insert:Partial<Submission>;Update:Partial<Submission>;Relationships:[]};
      brainstorm_entries:{Row:BrainstormEntry;Insert:Pick<BrainstormEntry,"activity_instance_id"|"project_id"|"workspace_id"|"content"> & Partial<BrainstormEntry>;Update:Partial<BrainstormEntry>;Relationships:[]};
      scamper_entries:{Row:ScamperEntry;Insert:Pick<ScamperEntry,"activity_instance_id"|"project_id"|"workspace_id"|"scamper_type"|"original_element"|"proposed_change"|"result_text"> & Partial<ScamperEntry>;Update:Partial<ScamperEntry>;Relationships:[]};
      artifacts:{Row:Artifact;Insert:Pick<Artifact,"project_id"|"workspace_id"|"artifact_type"|"title"|"created_by"> & Partial<Artifact>;Update:Partial<Artifact>;Relationships:[]};
      activity_research_links:{Row:ActivityResearchLink;Insert:Omit<ActivityResearchLink,"id"|"created_at"> & Partial<ActivityResearchLink>;Update:never;Relationships:[]};
      activity_inputs:{Row:ActivityInput;Insert:Pick<ActivityInput,"activity_instance_id"|"input_type"|"development_object_id"|"required"> & Partial<ActivityInput>;Update:Partial<ActivityInput>;Relationships:[]};
      activity_outputs:{Row:ActivityOutput;Insert:Pick<ActivityOutput,"activity_instance_id"|"output_type"|"development_object_id"> & Partial<ActivityOutput>;Update:Partial<ActivityOutput>;Relationships:[]};
      activity_participants:{Row:ActivityParticipant;Insert:Pick<ActivityParticipant,"activity_instance_id"|"user_id"|"joined_at"> & Partial<ActivityParticipant>;Update:Partial<ActivityParticipant>;Relationships:[]};
      activity_instances:{Row:ActivityInstance;Insert:Pick<ActivityInstance,"activity_definition_id"|"cohort_id"|"project_id"|"workspace_id"> & Partial<ActivityInstance>;Update:Partial<ActivityInstance>;Relationships:[]};
 change_log:{Row:ProjectChangeLog;Insert:Pick<ProjectChangeLog,"project_id"|"entity_type"|"entity_id"|"change_type"|"change_summary"|"changed_by"> & Partial<ProjectChangeLog>;Update:never;Relationships:[]};
 development_object_relationships:{Row:DevelopmentRelationship;Insert:Pick<DevelopmentRelationship,"project_id"|"source_object_id"|"target_object_id"|"relationship_type"|"created_by"> & Partial<DevelopmentRelationship>;Update:Partial<DevelopmentRelationship>;Relationships:[]};
 problem_details:{Row:ProblemDetails;Insert:Pick<ProblemDetails,"development_object_id"> & Partial<ProblemDetails>;Update:Partial<ProblemDetails>;Relationships:[]};
 idea_details:{Row:IdeaDetails;Insert:Pick<IdeaDetails,"development_object_id"|"acceptance_state"> & Partial<IdeaDetails>;Update:Partial<IdeaDetails>;Relationships:[]};
 development_objects:{Row:DevelopmentObject;Insert:Pick<DevelopmentObject,"project_id"|"workspace_id"|"object_type"|"title"|"created_by"> & Partial<DevelopmentObject>;Update:Partial<DevelopmentObject>;Relationships:[]};
      project_program_links:{Row:ProjectProgramLink;Insert:Pick<ProjectProgramLink,"project_id"|"program_id"|"cohort_id"> & Partial<ProjectProgramLink>;Update:Partial<ProjectProgramLink>;Relationships:[]};
      project_memberships:{Row:ProjectMembership;Insert:Pick<ProjectMembership,"project_id"|"user_id"> & Partial<ProjectMembership>;Update:Partial<ProjectMembership>;Relationships:[]};
      development_projects:{Row:DevelopmentProject;Insert:Pick<DevelopmentProject,"name"|"project_type"|"primary_workspace_id"> & Partial<Omit<DevelopmentProject,"required_workspace_type">>;Update:Partial<Omit<DevelopmentProject,"required_workspace_type">>;Relationships:[]};
      chat_channels:{Row:ChatChannel;Insert:Pick<ChatChannel,"channel_type"|"workspace_id"|"name"> & Partial<ChatChannel>;Update:Partial<ChatChannel>;Relationships:[]};
      chat_memberships:{Row:ChatMembership;Insert:Pick<ChatMembership,"chat_channel_id"|"user_id"|"access_level"|"joined_at"> & Partial<ChatMembership>;Update:Partial<ChatMembership>;Relationships:[]};
      chat_messages:{Row:ChatMessage;Insert:Pick<ChatMessage,"chat_channel_id"|"sender_user_id"|"content"> & Partial<ChatMessage>;Update:Partial<ChatMessage>;Relationships:[]};
      team_memberships:{Row:TeamMembership;Insert:Pick<TeamMembership,"team_id"|"user_id"|"membership_role"|"joined_at"|"added_by"> & Partial<TeamMembership>;Update:Partial<TeamMembership>;Relationships:[]};
      teams:{Row:Team;Insert:Pick<Team,"cohort_id"|"name"|"master_user_id"|"workspace_id"|"created_by"> & Partial<Omit<Team,"workspace_type">>;Update:Partial<Omit<Team,"workspace_type">>;Relationships:[]};
      workspaces: {Row:Workspace;Insert:Pick<Workspace,"workspace_type"|"name"|"created_by"|"updated_by"> & Partial<Workspace>;Update:Partial<Workspace>;Relationships:[]};
      enrollments: {Row:Enrollment;Insert:Pick<Enrollment,"cohort_id"|"user_id"|"enrollment_role"|"status"> & Partial<Enrollment>;Update:Partial<Enrollment>;Relationships:[{foreignKeyName:"enrollments_cohort_id_fkey";columns:["cohort_id"];isOneToOne:false;referencedRelation:"cohorts";referencedColumns:["id"]},{foreignKeyName:"enrollments_user_id_fkey";columns:["user_id"];isOneToOne:false;referencedRelation:"users";referencedColumns:["id"]}]};
      cohorts: {Row:Cohort;Insert:Pick<Cohort,"program_id"|"curriculum_version_id"|"name"|"start_date"|"primary_master_id"> & Partial<Omit<Cohort,"primary_master_assignment_id">> & {primary_master_assignment_id?:string|null};Update:Partial<Cohort>;Relationships:[]};
      activity_dependencies: {Row:ActivityDependency;Insert:Pick<ActivityDependency,"activity_definition_id"|"required_activity_definition_id"|"dependency_type"|"is_mandatory"> & Partial<ActivityDependency>;Update:Partial<ActivityDependency>;Relationships:[{foreignKeyName:"activity_dependencies_activity_definition_id_fkey";columns:["activity_definition_id"];isOneToOne:false;referencedRelation:"activity_definitions";referencedColumns:["id"]},{foreignKeyName:"activity_dependencies_required_activity_definition_id_fkey";columns:["required_activity_definition_id"];isOneToOne:false;referencedRelation:"activity_definitions";referencedColumns:["id"]}]};
      activity_definitions: {Row:ActivityDefinition;Insert:Pick<ActivityDefinition,"session_definition_id"|"name"|"method_type"|"sequence"> & Partial<ActivityDefinition>;Update:Partial<ActivityDefinition>;Relationships:[{foreignKeyName:"activity_definitions_session_definition_id_fkey";columns:["session_definition_id"];isOneToOne:false;referencedRelation:"session_definitions";referencedColumns:["id"]}]};
      session_definitions: { Row:SessionDefinition; Insert:Pick<SessionDefinition,"curriculum_version_id"|"session_number"|"title"|"description"|"learning_goal"|"sequence"> & Partial<SessionDefinition>; Update:Partial<SessionDefinition>; Relationships:[{foreignKeyName:"session_definitions_curriculum_version_id_fkey";columns:["curriculum_version_id"];isOneToOne:false;referencedRelation:"curriculum_versions";referencedColumns:["id"]}] };
      programs: { Row: Program; Insert: Pick<Program,"organization_id"|"name"|"code"|"program_type"> & Partial<Omit<Program,"current_curriculum_required_status">>; Update: Partial<Omit<Program,"current_curriculum_required_status">>; Relationships: [] };
      curriculum_versions: { Row: CurriculumVersion; Insert: Pick<CurriculumVersion,"program_id"|"version_label"> & Partial<CurriculumVersion>; Update: Partial<CurriculumVersion>; Relationships: [] };
      organizations: { Row: Organization; Insert: Pick<Organization,"name"|"slug"> & Partial<Organization>; Update: Partial<Organization>; Relationships: [] };
      role_assignments: {
        Row: RoleAssignment;
        Insert: Pick<RoleAssignment, "user_id" | "role_id" | "assigned_by"> & Partial<Omit<RoleAssignment, "user_id" | "role_id" | "assigned_by">>;
        Update: Partial<RoleAssignment>;
        Relationships: [
          {foreignKeyName:"role_assignments_cohort_id_fkey";columns:["cohort_id"];isOneToOne:false;referencedRelation:"cohorts";referencedColumns:["id"]},
          { foreignKeyName: "role_assignments_program_id_fkey"; columns: ["program_id"]; isOneToOne: false; referencedRelation: "programs"; referencedColumns: ["id"] },
          { foreignKeyName: "role_assignments_organization_id_fkey"; columns: ["organization_id"]; isOneToOne: false; referencedRelation: "organizations"; referencedColumns: ["id"] },
          { foreignKeyName: "role_assignments_user_id_fkey"; columns: ["user_id"]; isOneToOne: false; referencedRelation: "users"; referencedColumns: ["id"] },
          { foreignKeyName: "role_assignments_role_id_fkey"; columns: ["role_id"]; isOneToOne: false; referencedRelation: "roles"; referencedColumns: ["id"] },
          { foreignKeyName: "role_assignments_assigned_by_fkey"; columns: ["assigned_by"]; isOneToOne: false; referencedRelation: "users"; referencedColumns: ["id"] },
        ];
      };
      roles: {
        Row: SystemRole;
        Insert: Pick<SystemRole, "id" | "code" | "name" | "description"> & Partial<Pick<SystemRole, "is_system_role" | "created_at" | "updated_at">>;
        Update: Partial<SystemRole>;
        Relationships: [];
      };
      users: {
        Row: UserProfile;
        Insert: Pick<UserProfile, "id" | "account_status"> & Partial<Omit<UserProfile, "id" | "account_status">>;
        Update: Partial<UserProfile>;
        Relationships: [];
      };
    };
    Views: { [_ in never]: never };
        Functions: {
          authorize_master_live_breakout:{Args:{parent_room:string;target_team:string};Returns:unknown};
          find_team_live_breakout:{Args:{parent_room:string;target_team:string};Returns:string|null};
          list_live_breakout_teams:{Args:{parent_room:string};Returns:unknown};
          manage_live_breakout_mapping:{Args:{command:string;parent_room:string;target_team:string;actor:string;room_reference?:string|null};Returns:unknown};
          authorize_live_breakout_join:{Args:{target_breakout:string};Returns:unknown};
        get_live_classroom_context:{Args:{target_room:string};Returns:unknown};
        authorize_live_session_join:{Args:{target_room:string};Returns:unknown};
        can_join_live_session:{Args:{target_room:string};Returns:boolean};
        authorize_master_live_room:{Args:{target_cohort:string;target_session:string;target_activity?:string|null};Returns:unknown};
        master_live_room_mapping:{Args:{command:string;target_cohort:string;target_session:string;target_activity:string|null;room_reference:string|null;actor:string};Returns:unknown};
        manage_live_room_mapping:{Args:{command:string;target_cohort:string;target_session:string;target_provider:string;room_reference:string|null;actor:string;expected_room?:string|null};Returns:unknown};
      list_pilot_active_users:{Args:{target_organization:string};Returns:unknown};
      mark_notification_read:{Args:{target_notification:string};Returns:{id:string;read_at:string}};
      get_my_learning_progress:{Args:{target_project:string;target_workspace:string;target_cohort:string;target_team?:string|null};Returns:unknown};
      get_revision_status:{Args:{target_cohort?:string|null};Returns:unknown};
      get_pending_review_queue:{Args:{target_cohort:string};Returns:unknown};
      get_master_cohort_overview:{Args:{target_cohort:string};Returns:unknown};
      get_my_current_work_catalog:{Args:{target_project:string;target_workspace:string;target_cohort:string;target_team?:string|null};Returns:import('zod').infer<ReturnType<typeof import('zod').json>>};
      notification_email_contexts:{Args:{input:import('zod').infer<ReturnType<typeof import('zod').json>>};Returns:import('zod').infer<ReturnType<typeof import('zod').json>>};
      comment_notification_contexts:{Args:{target_source:string};Returns:import('zod').infer<ReturnType<typeof import('zod').json>>};
      approval_notification_contexts:{Args:{target_submission:string};Returns:import('zod').infer<ReturnType<typeof import('zod').json>>};
      revision_notification_contexts:{Args:{target_submission:string};Returns:import('zod').infer<ReturnType<typeof import('zod').json>>};
      artifact_share_notification_contexts:{Args:{target_share:string};Returns:import('zod').infer<ReturnType<typeof import('zod').json>>};
      create_domain_notification:{Args:{input:Record<string,import('zod').infer<ReturnType<typeof import('zod').json>>>};Returns:import('zod').infer<ReturnType<typeof import('zod').json>>};
      apply_ai_artifact_revision:{Args:{input:Record<string,import('zod').infer<ReturnType<typeof import('zod').json>>>};Returns:import('zod').infer<ReturnType<typeof import('zod').json>>};
      convert_ai_output_to_candidate:{Args:{input:Record<string,import('zod').infer<ReturnType<typeof import('zod').json>>>};Returns:import('zod').infer<ReturnType<typeof import('zod').json>>};
      set_ai_output_disposition:{Args:{target_output:string;target_disposition:string;expected_revision:number};Returns:import('zod').infer<ReturnType<typeof import('zod').json>>};
      begin_ai_task_operation:{Args:{input:Record<string,import('zod').infer<ReturnType<typeof import('zod').json>>>};Returns:import('zod').infer<ReturnType<typeof import('zod').json>>};
      record_ai_task_attempt:{Args:{input:Record<string,import('zod').infer<ReturnType<typeof import('zod').json>>>};Returns:undefined};
      release_ai_task_operation:{Args:{input:Record<string,import('zod').infer<ReturnType<typeof import('zod').json>>>};Returns:undefined};
      save_ai_task_result:{Args:{input:Record<string,import('zod').infer<ReturnType<typeof import('zod').json>>>};Returns:string};
      read_active_ai_prompt_template:{Args:{role0:import('@/features/ai/prompt-template-schema').AiPromptTemplate['role_code'];activity0:import('zod').infer<typeof import('@/features/activities/schema').activityMethodSchema>};Returns:import('zod').infer<ReturnType<typeof import('zod').json>>};
      resolve_activity_ai_configuration:{Args:{target_instance:string};Returns:import('zod').infer<ReturnType<typeof import('zod').json>>|null};
      resolve_ai_context_source:{Args:{input:Record<string,string>};Returns:Record<string,import('zod').infer<ReturnType<typeof import('zod').json>>>|null};
      confirm_session10_reconstruction:{Args:{input:{activityInstanceId:string;reconstructionAiOutputId:string;confirmed:true}};Returns:Session10Checkpoint};
      validate_session10_reconstruction_scope:{Args:{target_activity:string;target_project:string;target_workspace:string};Returns:boolean};
      resolve_session10_checkpoint:{Args:{input:{checkpointId:string;reconstructionAiOutputId:string;activityInstanceId:string;projectId:string;workspaceId:string}};Returns:(Session10Checkpoint&{baseline_version_id:string})|null};
      create_ai_prompt_template:{Args:{input:CreateAiPromptTemplateInput};Returns:AiPromptTemplate};
      set_ai_prompt_template_active:{Args:{target_template:string;activate:boolean};Returns:AiPromptTemplate};
      seed_ai_prompt_templates:{Args:Record<string,never>;Returns:number};
        resolve_shared_entity_access:{Args:{input:import("zod").infer<typeof import("@/features/shares/access-schema").sharedEntityAccessInputSchema>};Returns:import("@/features/shares/access-schema").SharedEntityAccess};
        can_read_share_comments:{Args:{target_share:string};Returns:boolean};
        add_share_comment:{Args:{input:{shareId:string;content:string}};Returns:SharedComment};
        list_share_comments:{Args:{input:{shareId:string}};Returns:SharedComment[]};
        share_entity:{Args:{input:import("@/features/shares/create-schema").ShareEntityInput};Returns:import("@/features/shares/schema").Share};
        revoke_share:{Args:{input:{shareId:string}};Returns:Share};
        get_file_signing_record:{Args:{target_file:string};Returns:FileRecord|null};
        authorize_shared_file_access:{Args:{target_file:string};Returns:boolean};
        list_entity_shares:{Args:{input:import("@/features/shares/history-schema").ListEntitySharesInput};Returns:import("@/features/shares/history-schema").EntityShareHistory};
        resolve_shareability:{Args:{input:import("zod").infer<typeof import("@/features/shares/shareability-schema").shareabilityInputSchema>};Returns:import("@/features/shares/shareability-schema").ShareabilityResult};
        finalize_session7_outputs:{Args:{input:import("@/features/mind-map/session7-schema").FinalizeSession7OutputsInput};Returns:import("@/features/mind-map/session7-schema").FinalizedSession7Outputs};
        can_read_session7_output:{Args:{target_artifact:string};Returns:boolean};
        create_mind_map_version:{Args:{input:import("@/features/mind-map/version-schema").CreateMindMapVersionInput};Returns:import("@/features/mind-map/version-schema").CreatedMindMapVersion};
        can_read_private_mind_map:{Args:{target_artifact:string};Returns:boolean};
        save_mind_map_draft:{Args:{input:import("@/features/mind-map/draft-schema").SaveMindMapDraftInput};Returns:import("@/features/mind-map/draft-schema").SavedMindMapDraft};
      classify_mind_map_node:{Args:{input:import("@/features/mind-map/classification-schema").ClassifyMindMapNodeInput};Returns:MindMapNode};
      get_mind_map_editor:{Args:{target_activity:string};Returns:import("@/features/mind-map/editor-schema").MindMapEditorState};
      connect_mind_map_nodes:{Args:{input:import("@/features/mind-map/edge-schema").ConnectMindMapNodesInput};Returns:MindMapEdge};
      update_mind_map_edge:{Args:{input:import("@/features/mind-map/edge-schema").UpdateMindMapEdgeInput};Returns:MindMapEdge};
      remove_mind_map_edge:{Args:{input:import("@/features/mind-map/edge-schema").RemoveMindMapEdgeInput};Returns:MindMapEdge};
      remove_mind_map_node:{Args:{input:import("@/features/mind-map/node-schema").RemoveMindMapNodeInput};Returns:MindMapNode};
      add_mind_map_node:{Args:{input:import("@/features/mind-map/node-schema").AddMindMapNodeInput};Returns:MindMapNode};
      update_mind_map_node:{Args:{input:import("@/features/mind-map/node-schema").UpdateMindMapNodeInput};Returns:MindMapNode};
      create_mind_map:{Args:{input:import("zod").infer<typeof import("@/features/mind-map/create-schema").createMindMapSchema>};Returns:import("@/features/mind-map/create-schema").CreatedMindMap};
      capture_gap:{Args:{input:import("zod").infer<typeof import("@/features/affinity/gap-schema").captureGapSchema>};Returns:import("@/features/affinity/gap-schema").CapturedGap};
      confirm_affinity_structure:{Args:{input:import("zod").infer<typeof import("@/features/affinity/structure-schema").confirmAffinityStructureSchema>};Returns:import("@/features/affinity/structure-schema").AffinityStructureResult};
      add_affinity_item:{Args:{input:import("zod").infer<typeof import("@/features/affinity/item-operations-schema").addAffinityItemSchema>};Returns:AffinityGroupItem};
      get_affinity_collaboration_board:{Args:{target_activity:string};Returns:import("@/features/affinity/collaboration-schema").AffinityBoard};
      move_affinity_item:{Args:{input:import("zod").infer<typeof import("@/features/affinity/item-operations-schema").moveAffinityItemSchema>};Returns:AffinityGroupItem};
      can_read_mind_map:{Args:{target_map:string};Returns:boolean};
      can_read_mind_map_node:{Args:{target_node:string};Returns:boolean};
      can_read_mind_map_edge:{Args:{target_edge:string};Returns:boolean};
      can_read_affinity_group:{Args:{target_group:string};Returns:boolean};
      can_read_affinity_item:{Args:{target_item:string};Returns:boolean};
      create_affinity_group:{Args:{input:import("zod").infer<typeof import("@/features/affinity/operations-schema").createAffinityGroupSchema>};Returns:AffinityGroup};
      rename_affinity_group:{Args:{input:import("zod").infer<typeof import("@/features/affinity/operations-schema").renameAffinityGroupSchema>};Returns:AffinityGroup};
      supersede_decision:{Args:{input:import("@/features/decisions/supersede-schema").SupersedeDecisionInput};Returns:import("@/features/decisions/schema").DecisionLink};
      create_team_decision_record_artifact:{Args:{target_decision:string};Returns:import("@/features/decisions/artifact").TeamDecisionRecord};
      verify_evidence:{Args:{target_evidence:string;target_status:Evidence["verification_status"];verification_note?:string|null};Returns:Evidence};
      can_read_file_scope:{Args:{target_workspace:string;target_project:string|null};Returns:boolean};
      consume_file_upload_rate_limit:{Args:{target_actor:string;target_source_hash:string|null;user_limit:number;source_limit:number;window_seconds:number};Returns:{allowed:boolean;retryAfterSeconds:number}};
      request_file_upload:{Args:{target_workspace:string;target_project:string|null;upload_filename:string;upload_mime:string;upload_size:number};Returns:UploadRequest};
      get_file_upload_request:{Args:{target_request:string};Returns:UploadRequest};
      register_uploaded_file:{Args:{target_request:string};Returns:FileRecord};
      link_file:{Args:{input:LinkFileInput};Returns:FileLink};
      archive_file:{Args:{target_file:string};Returns:FileRecord};
      link_patent_to_evidence:{Args:{input:LinkPatentToEvidenceInput};Returns:Evidence};
      create_patent_search_log:{Args:{input:CreatePatentSearchLogInput};Returns:PatentSearchLog};
      create_patent_record:{Args:{input:CreatePatentRecordInput};Returns:PatentRecord};
      create_evidence:{Args:{project_id:string;workspace_id:string;evidence_type:Evidence["evidence_type"];title:string;description:string;source_name:string;source_url?:string|null;file_id?:string|null};Returns:Evidence};
      link_evidence:{Args:{input:LinkEvidenceInput};Returns:EvidenceLink};
      link_decision_entity:{Args:{input:import("@/features/decisions/link-schema").LinkDecisionEntityInput};Returns:import("@/features/decisions/schema").DecisionLink};
      finalize_decision:{Args:{input:import("@/features/decisions/finalize-schema").FinalizeDecisionInput};Returns:import("@/features/decisions/schema").Decision};
      create_decision:{Args:{input:import("zod").infer<typeof import("@/features/decisions/create-schema").createDecisionSchema>};Returns:import("@/features/decisions/create-schema").CreatedDecision};
      get_voting_results:{Args:{target_session:string};Returns:VotingResults};
      cast_vote:{Args:{target_session:string;target_option:string;dot_value:number};Returns:Vote};
      close_voting_session:{Args:{target_session:string};Returns:VotingSession};
      reveal_voting_session:{Args:{target_session:string};Returns:VotingSession};
      open_voting_session:{Args:{target_session:string};Returns:VotingSession};
      create_voting_session:{Args:{target_instance:string;kind:string;dot_limit:number;is_anonymous:boolean;visibility:string;choices:{developmentObjectId?:string;label:string;description?:string}[]};Returns:CreatedVotingSession};
      can_read_brainstorm_entry:{Args:{target_entry:string};Returns:boolean};
      reveal_brainstorm_entries:{Args:{target_instance:string;target_entries:string[]};Returns:RevealBrainstormResult};
      create_brainstorm_entry:{Args:{target_instance:string;entry_content:string;visibility_state:string;parent_entry?:string|null};Returns:BrainstormEntry};
      create_scamper_entry:{Args:{target_instance:string;lens:ScamperEntry["scamper_type"];original_value:string;proposed_value:string;result_value:string};Returns:ScamperEntry};
      update_scamper_entry:{Args:{target_entry:string;changes:{scamperType?:ScamperEntry["scamper_type"];originalElement?:string;proposedChange?:string;resultText?:string}};Returns:ScamperEntry};
      compose_solution_bank:{Args:{target_instance:string;solution_ids:string[];bank_title?:string|null};Returns:ComposedSolutionBank};
      compose_problem_bank:{Args:{target_instance:string;problem_ids:string[];bank_title?:string|null};Returns:ComposedProblemBank};
      create_problem_storming_problem:{Args:{target_instance:string;problem_content:string;category:string;problem_perspective?:string|null};Returns:ProblemStormingProblem};
      promote_brainstorm_entry_to_solution:{Args:{target_entry:string;target_problem:string};Returns:DevelopmentObject};
      promote_brainstorm_entry_to_idea:{Args:{target_entry:string};Returns:DevelopmentObject};
      promote_scamper_entry_to_idea:{Args:{target_entry:string};Returns:DevelopmentObject};
      list_scamper_entries:{Args:{target_instance:string};Returns:ScamperEntry[]};
      get_scamper_entry:{Args:{target_entry:string};Returns:ScamperEntry};
      list_activity_artifact_candidates:{Args:{target_definition:string;target_project:string;target_workspace:string;target_team:string|null};Returns:import("@/features/activities/artifact-candidates").ActivityArtifactCandidate[]};
      add_activity_research_reference:{Args:{target_instance:string;target_type:string;target_entity:string};Returns:ActivityResearchLink};
      add_activity_evidence_input:{Args:{target_instance:string;target_evidence:string;is_required:boolean};Returns:ActivityInput};
      add_activity_evidence_output:{Args:{target_instance:string;target_evidence:string};Returns:ActivityOutput};
      add_activity_artifact_input:{Args:{target_instance:string;target_artifact:string;target_version:string|null;is_required:boolean};Returns:ActivityInput};
      add_activity_artifact_output:{Args:{target_instance:string;target_artifact:string};Returns:ActivityOutput};
      set_project_baseline_item:{Args:{target_project:string;baseline_type_input:string;target_artifact:string;target_version:string};Returns:ProjectBaselineItem};
      start_review:{Args:{target_submission:string};Returns:Submission};
      approve_artifact:{Args:{target_submission:string;approval_note_input?:string|null};Returns:Submission};
      reopen_approved_artifact:{Args:{target_artifact:string};Returns:{version:ArtifactVersion;sourceVersionId:string;currentVersionId:string}};
      request_revision:{Args:{target_submission:string;revision_note:string};Returns:Submission};
      create_revision_draft:{Args:{target_submission:string;snapshot:ArtifactVersion["content_snapshot"];summary:string|null};Returns:ArtifactVersion};
      add_feedback:{Args:{target_kind:FeedbackItem["target_entity_type"];target_entity:string;target_version:string|null;kind:FeedbackItem["feedback_type"];body:string};Returns:FeedbackItem};
      submit_artifact:{Args:{target_artifact:string;target_version:string;target_activity:string};Returns:Submission};
      get_submitted_artifact_metadata:{Args:{target_artifact:string};Returns:unknown};
      can_review_submission:{Args:{target_submission:string};Returns:boolean};
      can_review_artifact_version:{Args:{target_version:string};Returns:boolean};
      can_review_linked_object:{Args:{target_object:string};Returns:boolean};
      archive_artifact:{Args:{target_artifact:string};Returns:Artifact};
      create_artifact_version:{Args:{target_artifact:string;snapshot:ArtifactVersion["content_snapshot"];summary:string|null;decision_ids?:string[];evidence_ids?:string[];ai_output_ids?:string[]};Returns:ArtifactVersion};
      update_artifact_draft:{Args:{target_version:string;expected_revision:number;snapshot:ArtifactVersion["content_snapshot"];summary?:string|null;set_summary?:boolean};Returns:ArtifactVersion};
      create_artifact:{Args:{target_project:string;target_workspace:string;kind:Artifact["artifact_type"];artifact_title:string;target_activity:string|null;needs_review:boolean;needs_approval:boolean};Returns:CreatedArtifact};
      save_patent_reading_framework:{Args:{target_instance:string;target_patent:string;notes:unknown;expected_revision:number|null;target_version:string|null};Returns:unknown};
      complete_activity:{Args:{target_instance:string};Returns:import("@/features/activities/instance-schema").ActivityInstance};
      add_activity_output:{Args:{target_instance:string;target_object:string};Returns:import("@/features/activities/io-schema").ActivityOutput};
      add_activity_input:{Args:{target_instance:string;target_object:string;is_required:boolean};Returns:import("@/features/activities/io-schema").ActivityInput};
      activity_resume_definition_metadata:{Args:{target_instance:string};Returns:{id:string;name:string;session_definition_id:string;method_type:string}|null};
      resume_activity:{Args:{target_instance:string};Returns:import("@/features/activities/resume-schema").ActivityResumeState|null};
      start_activity:{Args:{target_definition:string;target_project:string;target_workspace:string;target_team?:string|null};Returns:import("@/features/activities/start-schema").ActivityStartResult};
      evaluate_activity_dependencies:{Args:{target_definition:string;target_project:string;target_workspace:string;target_team?:string|null};Returns:import("@/features/activities/dependencies-schema").ActivityDependencies};
      resolve_activity_availability:{Args:{target_definition:string;target_project:string;target_workspace:string;target_team?:string|null};Returns:import("@/features/activities/availability-schema").ActivityAvailability};
      can_read_decision:{Args:{target_decision:string};Returns:boolean};
      can_read_voting_session:{Args:{target_session:string};Returns:boolean};
      can_read_activity_instance:{Args:{target_instance:string};Returns:boolean};
      archive_development_project:{Args:{target_project:string};Returns:DevelopmentProject};
 get_development_project_metadata_for_edit:{Args:{target_project:string};Returns:DevelopmentProject};
 update_project_metadata:{Args:{target_project:string;changes:{name?:string;description?:string|null;status?:"active"|"paused"|"completed";current_stage?:string|null}};Returns:DevelopmentProject};
 relate_development_objects:{Args:{source_object:string;target_object:string;kind:DevelopmentRelationship["relationship_type"];relationship_description?:string|null};Returns:DevelopmentRelationship};
 unlink_development_objects:{Args:{target_relationship:string};Returns:DevelopmentRelationship};
 write_problem_details:{Args:{target_object:string;details:Record<string,unknown>;create_new:boolean};Returns:ProblemDetails};
 write_idea_details:{Args:{target_object:string;details:Record<string,unknown>;create_new:boolean};Returns:IdeaDetails};
 create_development_object:{Args:{target_project:string;target_workspace:string;kind:DevelopmentObject["object_type"];object_title:string;object_content:string;object_origin:string|null;object_metadata?:Record<string,unknown>};Returns:DevelopmentObject};
 update_development_object:{Args:{target_object:string;changes:{title?:string;content?:string;metadata?:Record<string,unknown>}};Returns:DevelopmentObject};
 archive_development_object:{Args:{target_object:string};Returns:DevelopmentObject};

      can_read_project_program_link:{Args:{target_link:string};Returns:boolean};
      link_project_to_program:{Args:{target_project:string;target_program:string;target_cohort:string;entry_version?:string|null};Returns:unknown};
      create_development_project:{Args:{project_name:string;kind:DevelopmentProject["project_type"];target_workspace:string;project_description?:string|null;target_owner_user?:string|null;target_owner_team?:string|null};Returns:unknown};
      has_active_project_membership:{Args:{target_project:string};Returns:boolean};
      can_read_development_project:{Args:{target_project:string};Returns:boolean};
      can_receive_notification_broadcast:{Args:{channel_topic:string};Returns:boolean};
      can_receive_team_chat_broadcast:{Args:{channel_topic:string};Returns:boolean};
      send_team_chat_message:{Args:{target_team:string;message_content:string;reply_parent?:string|null};Returns:unknown};
      list_team_chat_messages:{Args:{target_channel:string;page_limit?:number;after_time?:string|null;after_id?:string|null};Returns:unknown};
      archive_team:{Args:{target_team:string};Returns:unknown};
      assign_team_lead:{Args:{target_team:string;target_user:string};Returns:unknown};
      move_team_member:{Args:{target_user:string;source_team:string;destination_team:string;move_reason?:string|null};Returns:unknown};
      remove_team_member:{Args:{target_team:string;target_user:string;removal_reason?:string|null};Returns:unknown};
      add_team_member:{Args:{target_team:string;target_user:string;kind:TeamMembership["membership_role"]};Returns:unknown};
      can_manage_team:{Args:{target_team:string};Returns:boolean};
      get_team_workspace_access:{Args:{target_workspace:string};Returns:string|null};
      can_access_team_chat:{Args:{target_channel:string};Returns:boolean};
      get_team_chat_access:{Args:{target_channel:string};Returns:string|null};
      team_workspace_has_chat_access:{Args:{target_workspace:string};Returns:boolean};
      create_team:{Args:{target_cohort:string;team_name:string;team_description?:string|null;lead_user?:string|null;target_project?:string|null};Returns:unknown};
      create_master_workspace:{Args:{target_cohort:string};Returns:unknown};
      create_personal_workspace:{Args:Record<string,never>;Returns:unknown};
      has_active_enrollment: {Args:{scope_id:string};Returns:boolean};
      has_enrollment_read_access: {Args:{scope_id:string};Returns:boolean};
      can_manage_enrollment: {Args:{scope_id:string;kind:Enrollment["enrollment_role"]};Returns:boolean};
      enroll_user: {Args:{target_cohort:string;target_user:string;kind:Enrollment["enrollment_role"];initial_status:Enrollment["status"]};Returns:unknown};
      transition_enrollment: {Args:{target_enrollment:string;next_status:Enrollment["status"]};Returns:unknown};
      remove_enrollment: {Args:{target_enrollment:string};Returns:unknown};
      create_cohort: {Args:{target_program:string;target_version:string;cohort_name:string;starts_on:string;ends_on:string|null;master_id:string;lifecycle:Cohort["status"];configuration:unknown};Returns:unknown};
      assign_master_to_cohort: {Args:{target_cohort:string;master_id:string};Returns:unknown};
      update_cohort: {Args:{target_cohort:string;cohort_name:string;starts_on:string;ends_on:string|null;master_id:string;lifecycle:Cohort["status"];configuration:unknown};Returns:unknown};
      manage_activity_dependency: {Args:{target_activity:string;target_dependency:string|null;required_activity:string;kind:ActivityDependency["dependency_type"];artifact_type:string|null;mandatory:boolean};Returns:unknown};
      seed_professional_activity: {Args:Record<string,never>;Returns:undefined};
      manage_activity: {Args:{target_session:string;target_activity:string|null;definition:unknown};Returns:unknown};
      seed_professional_sessions: { Args:Record<string,never>; Returns:undefined };
      manage_session: { Args:{target_version:string;target_session:string|null;number:number;session_title:string;session_description:string;goal:string;session_position:number;lifecycle:SessionDefinition["status"]}; Returns:unknown };
      seed_professional_curriculum: { Args: Record<string,never>; Returns: undefined };
      manage_program: { Args: {target_organization:string;target_program:string|null;program_name:string;program_code:string;program_description:string;kind:Program["program_type"];lifecycle:Program["status"]}; Returns: unknown };
      manage_curriculum: { Args: {target_program:string;target_version:string|null;label:string;starts_at:string|null;ends_at:string|null;version_notes:string}; Returns: unknown };
      transition_curriculum: { Args: {target_version:string;next_status:CurriculumVersion["status"]}; Returns: unknown };
      set_current_curriculum: { Args: {target_program:string;target_version:string|null}; Returns: unknown };
      seed_initial_organization: { Args: Record<string, never>; Returns: undefined };
      update_organization: { Args: { organization_id: string; new_name: string; new_status: Organization["status"] }; Returns: unknown };
      current_platform_user_id: { Args: Record<string, never>; Returns: string | null };
      has_active_role: { Args: { role_code: RoleCode }; Returns: boolean };
      has_active_role_in_organization: { Args: { role_code: RoleCode; scope_id: string }; Returns: boolean };
      has_active_role_in_program: { Args: { role_code: RoleCode; scope_id: string }; Returns: boolean };
      has_active_role_in_cohort: { Args: { role_code: RoleCode; scope_id: string }; Returns: boolean };
      has_active_role_in_team: { Args: { role_code: RoleCode; scope_id: string }; Returns: boolean };
      has_active_role_in_project: { Args: { role_code: RoleCode; scope_id: string }; Returns: boolean };

      provision_user_profile: { Args: { auth_user_id: string; initial_status: UserProfile["account_status"] }; Returns: undefined };
      seed_system_roles: { Args: Record<string, never>; Returns: undefined };
      get_active_role_assignments: { Args: Record<string, never>; Returns: RoleAssignment[] };
    };
    Enums: { ai_usage_model_profile:AiUsageEvent["model_profile"];ai_usage_result:AiUsageEvent["success_failure"];ai_prompt_role_code:AiPromptTemplate["role_code"];ai_prompt_template_status:AiPromptTemplate["status"];ai_context_entity_type:AIContextReference["entity_type"];ai_context_role:AIContextReference["context_role"];ai_output_type:AIOutput["output_type"];ai_output_verification_status:AIOutput["verification_status"];ai_output_disposition:AIOutput["disposition"];share_entity_type:Share["shared_entity_type"];share_destination_type:Share["destination_type"];share_permission_level:Share["permission_level"];share_mode:Share["share_mode"]; patent_relevance_status:PatentRecord["relevance_status"];patent_source_database:PatentRecord["source_database"]; file_status:FileRecord["status"];file_link_entity_type:FileLink["entity_type"];file_relationship_type:FileLink["relationship_type"]; evidence_link_entity_type:EvidenceLink["linked_entity_type"];evidence_relationship_type:EvidenceLink["relationship_type"]; evidence_type:Evidence["evidence_type"];evidence_verification_status:Evidence["verification_status"]; decision_status:Decision["status"];decision_method:Decision["method"];decision_link_entity_type:DecisionLink["linked_entity_type"]; voting_type:VotingSession["voting_type"];voting_session_status:VotingSession["status"];voting_reveal_mode:VotingSession["reveal_mode"]; brainstorm_entry_status:BrainstormEntry["status"]; scamper_lens:ScamperEntry["scamper_type"];scamper_entry_status:ScamperEntry["status"]; project_change_type:ProjectChangeLog["change_type"];project_change_entity_type:ProjectChangeLog["entity_type"]; development_relationship_type:DevelopmentRelationship["relationship_type"];development_relationship_status:DevelopmentRelationship["status"]; idea_acceptance_state:IdeaDetails["acceptance_state"]; development_object_type:DevelopmentObject["object_type"]; development_project_type:DevelopmentProject["project_type"];development_project_status:DevelopmentProject["status"];project_membership_role:ProjectMembership["project_role"];project_membership_status:ProjectMembership["status"]; chat_channel_type:ChatChannel["channel_type"];chat_channel_status:ChatChannel["status"];chat_access_level:ChatMembership["access_level"];chat_message_type:ChatMessage["message_type"]; team_membership_role:TeamMembership["membership_role"];team_membership_status:TeamMembership["status"]; team_status:Team["status"]; workspace_type:Workspace["workspace_type"];workspace_status:Workspace["status"];workspace_visibility:Workspace["visibility"]; enrollment_role:Enrollment["enrollment_role"];enrollment_status:Enrollment["status"]; cohort_status:Cohort["status"]; activity_dependency_type:ActivityDependency["dependency_type"]; activity_status:ActivityDefinition["status"];activity_method_type:ActivityDefinition["method_type"]; session_status:SessionDefinition["status"]; program_type: Program["program_type"]; program_status: Program["status"]; curriculum_status: CurriculumVersion["status"]; organization_status: Organization["status"]; account_status: UserProfile["account_status"]; role_assignment_status: RoleAssignment["status"] };
    CompositeTypes: { [_ in never]: never };
  };
};























