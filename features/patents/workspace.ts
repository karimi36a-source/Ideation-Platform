import 'server-only';
import {z} from 'zod';
import {AuthorizationError,getAuthorizationContext} from '@/lib/auth/authorization';
import {createServerSupabaseClient} from '@/lib/db/server';
import {getWorkspaceAccess} from '@/features/workspaces/access';
import {developmentProjectSchema} from '@/features/projects/schema';
import {developmentObjectSchema} from '@/features/projects/object-schema';
import {artifactSchema} from '@/features/artifacts/schema';
import {evidenceSchema} from '@/features/evidence/schema';
import {evidenceLinkSchema} from '@/features/evidence/link-schema';
import {patentRecordSchema} from './schema';
import {patentSearchLogSchema} from './search-schema';
/** Gate before research queries; every query still uses the request's RLS client. */
export async function getPatentWorkspace(projectId:unknown){
 try{
  const id=z.uuid().parse(projectId);const actor=await getAuthorizationContext();const db=await createServerSupabaseClient();
  const allowed=await db.rpc('can_read_development_project',{target_project:id});
  if(allowed.error||allowed.data!==true)throw new AuthorizationError('NOT_FOUND');
  const result=await db.from('development_projects').select('*').eq('id',id).maybeSingle();
  const project=developmentProjectSchema.parse(result.data);
  if(result.error||project.id!==id)throw new AuthorizationError('NOT_FOUND');
  const access=await getWorkspaceAccess(project.primary_workspace_id);
  if(!access.canView)throw new AuthorizationError('NOT_FOUND');
  const workspaceId=project.primary_workspace_id;
  const patents=await db.from('patent_records').select('*').eq('project_id',id).eq('workspace_id',workspaceId).order('created_at',{ascending:false});
  if(patents.error)throw new AuthorizationError('NOT_FOUND');
  const records=z.array(patentRecordSchema).parse(patents.data);
  const [logs,links,evidence,objects,artifacts,activities]=await Promise.all([
   db.from('patent_search_logs').select('*').eq('project_id',id).eq('workspace_id',workspaceId).order('searched_at',{ascending:false}),
   records.length?db.from('evidence_links').select('*').eq('linked_entity_type','PATENT_RECORD').in('linked_entity_id',records.map(p=>p.id)):Promise.resolve({data:[],error:null}),
   db.from('evidence').select('*').eq('project_id',id).eq('workspace_id',workspaceId).in('evidence_type',['PATENT','PATENT_CLAIM']),
   db.from('development_objects').select('*').eq('project_id',id).eq('workspace_id',workspaceId).in('object_type',['PROBLEM','SOLUTION','GAP']).is('archived_at',null),
   db.from('artifacts').select('*').eq('project_id',id).eq('workspace_id',workspaceId).in('artifact_type',['INVENTION_CONCEPT','MIND_MAP','MINIMUM_ESSENTIAL_STRUCTURE','PATENT_READING_FRAMEWORK']).eq('status','ACTIVE'),
   db.from('activity_instances').select('id,status,configuration_snapshot').eq('project_id',id).eq('workspace_id',workspaceId).eq('status','active'),
  ]);
  if([patents,logs,links,evidence,objects,artifacts,activities].some(r=>r.error))throw new AuthorizationError('NOT_FOUND');
  const patentIds=new Set(records.map(p=>p.id));
  const scopedLinks=z.array(evidenceLinkSchema).parse(links.data).filter(l=>patentIds.has(l.linked_entity_id));
  const evidenceIds=new Set(scopedLinks.map(l=>l.evidence_id));
  const linkedEvidence=z.array(evidenceSchema).parse(evidence.data).filter(e=>evidenceIds.has(e.id));
  const references=z.array(artifactSchema).parse(artifacts.data);
  const versions=references.length?await db.from('artifact_versions').select('id,artifact_id,version_number,status,content_snapshot,draft_revision').in('artifact_id',references.map(a=>a.id)).order('version_number',{ascending:true}):{data:[],error:null};
  if(versions.error)throw new AuthorizationError('NOT_FOUND');
  const versionReferences=z.array(z.object({id:z.uuid(),artifact_id:z.uuid(),version_number:z.number().int().positive(),status:z.string(),content_snapshot:z.json().optional(),draft_revision:z.number().int().min(0).optional()})).parse(versions.data);
  const latest=await getAuthorizationContext();const recheck=await db.rpc('can_read_development_project',{target_project:id});
  if(latest.userId!==actor.userId||recheck.error||recheck.data!==true||!(await getWorkspaceAccess(workspaceId)).canView)throw new AuthorizationError('NOT_FOUND');
  return {project,canEdit:access.canEdit,patents:records,logs:z.array(patentSearchLogSchema).parse(logs.data),links:scopedLinks,evidence:linkedEvidence,
   objects:z.array(developmentObjectSchema).parse(objects.data),artifacts:references,versions:versionReferences,
   activities:z.array(z.object({id:z.uuid(),status:z.literal('active'),configuration_snapshot:z.json().optional()})).parse(activities.data)};
 }catch{throw new AuthorizationError('NOT_FOUND');}
}
export type PatentWorkspaceState=Awaited<ReturnType<typeof getPatentWorkspace>>;
