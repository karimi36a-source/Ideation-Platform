import "server-only";
import {z} from "zod";
import {AuthorizationError,getAuthorizationContext} from "@/lib/auth/authorization";
import {createServerSupabaseClient} from "@/lib/db/server";
import {getWorkspaceAccess} from "@/features/workspaces/access";
import {artifactSchema,type Artifact} from "./schema";
import {artifactVersionSchema,type ArtifactVersion} from "./version-schema";
import {submittedArtifactMetadataSchema} from "./submission-schema";
const safe=(error:unknown)=>new AuthorizationError(error instanceof AuthorizationError&&["AUTH_REQUIRED","VALIDATION_ERROR"].includes(error.code)?error.code:"NOT_FOUND");
const artifactData=(a:Artifact)=>({id:a.id,projectId:a.project_id,workspaceId:a.workspace_id,artifactType:a.artifact_type,title:a.title,status:a.status,currentVersionId:a.current_version_id,createdBy:a.created_by,activityInstanceId:a.activity_instance_id,reviewRequired:a.review_required,approvalRequired:a.approval_required,createdAt:a.created_at,updatedAt:a.updated_at,archivedAt:a.archived_at});
const versionData=(v:ArtifactVersion)=>({id:v.id,artifactId:v.artifact_id,versionNumber:v.version_number,draftRevision:v.draft_revision,versionLabel:v.version_label,contentSnapshot:v.content_snapshot,changeSummary:v.change_summary,status:v.status,createdBy:v.created_by,createdAt:v.created_at,previousVersionId:v.previous_version_id,approvedBy:v.approved_by,approvedAt:v.approved_at,approvalNote:v.approval_note});
function resourceId(value:unknown){const id=z.uuid().safeParse(value);if(!id.success)throw new AuthorizationError("VALIDATION_ERROR");return id.data;}
async function parent(id:string){const db=await createServerSupabaseClient();const result=await db.from("artifacts").select("*").eq("id",id).maybeSingle();const parsed=artifactSchema.safeParse(result.data);if(result.error||!parsed.success||parsed.data.id!==id||!(await getWorkspaceAccess(parsed.data.workspace_id)).canView)throw new AuthorizationError("NOT_FOUND");return {db,row:parsed.data};}
async function reviewMetadata(id:string){const db=await createServerSupabaseClient();const result=await db.rpc("get_submitted_artifact_metadata",{target_artifact:id});const a=submittedArtifactMetadataSchema.safeParse(result.data);if(result.error||!a.success||a.data.id!==id)throw new AuthorizationError("NOT_FOUND");return a.data;}
async function sameActor(actor:string){if((await getAuthorizationContext()).userId!==actor)throw new AuthorizationError("NOT_FOUND");}
export async function getArtifact(artifactId:unknown){try{
 const actor=await getAuthorizationContext();const id=resourceId(artifactId);let data;try{const {row}=await parent(id);data=artifactData(row);}catch{data=await reviewMetadata(id);}await sameActor(actor.userId);return data;
}catch(error){throw safe(error);}}
export async function getArtifactVersion(versionId:unknown){try{
 const actor=await getAuthorizationContext();const id=resourceId(versionId);const db=await createServerSupabaseClient();const result=await db.from("artifact_versions").select("*").eq("id",id).maybeSingle();const v=artifactVersionSchema.safeParse(result.data);if(result.error||!v.success||v.data.id!==id)throw new AuthorizationError("NOT_FOUND");try{await parent(v.data.artifact_id);}catch{await reviewMetadata(v.data.artifact_id);}await sameActor(actor.userId);return versionData(v.data);
}catch(error){throw safe(error);}}
export async function listArtifactVersions(artifactId:unknown){try{
 const actor=await getAuthorizationContext();const id=resourceId(artifactId);let db;try{db=(await parent(id)).db;}catch{await reviewMetadata(id);db=await createServerSupabaseClient();}const result=await db.from("artifact_versions").select("*").eq("artifact_id",id).order("version_number",{ascending:true});const rows=z.array(artifactVersionSchema).safeParse(result.data);if(result.error||!rows.success||rows.data.some(v=>v.artifact_id!==id))throw new AuthorizationError("NOT_FOUND");await sameActor(actor.userId);return rows.data.map(versionData);
}catch(error){throw safe(error);}}
export async function archiveArtifact(artifactId:unknown){try{
 const actor=await getAuthorizationContext();const id=resourceId(artifactId);const {db,row:before}=await parent(id);if(!(await getWorkspaceAccess(before.workspace_id)).canEdit)throw new AuthorizationError("NOT_FOUND");await sameActor(actor.userId);
 const result=await db.rpc("archive_artifact",{target_artifact:id});await sameActor(actor.userId);if(result.error)throw new AuthorizationError(result.error.code==="28000"?"AUTH_REQUIRED":"NOT_FOUND");const after=artifactSchema.safeParse(result.data);
 const fixed=["id","project_id","workspace_id","artifact_type","title","created_by","created_at","activity_instance_id","review_required","approval_required","current_version_id"] as const;
 if(!after.success||after.data.status!=="ARCHIVED"||after.data.archived_at===null||fixed.some(k=>after.data[k]!==before[k])||(before.status==="ARCHIVED"&&after.data.archived_at!==before.archived_at))throw new AuthorizationError("NOT_FOUND");return artifactData(after.data);
}catch(error){throw safe(error);}}
