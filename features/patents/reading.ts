import 'server-only';
import {z} from 'zod';
import {AuthorizationError,getAuthorizationContext} from '@/lib/auth/authorization';
import {createServerSupabaseClient} from '@/lib/db/server';
import {artifactSchema} from '@/features/artifacts/schema';
import {artifactVersionSchema} from '@/features/artifacts/version-schema';
import {patentReadingSnapshotSchema,savePatentReadingFrameworkSchema} from './reading-schema';
export async function savePatentReadingFramework(input:unknown){
 const actor=await getAuthorizationContext();const parsed=savePatentReadingFrameworkSchema.safeParse(input);
 if(!parsed.success)throw new AuthorizationError('VALIDATION_ERROR');
 const v=parsed.data;const db=await createServerSupabaseClient();
 const {data,error}=await db.rpc('save_patent_reading_framework',{target_instance:v.activityInstanceId,target_patent:v.patentRecordId,notes:v.notes,expected_revision:v.expectedDraftRevision,target_version:v.artifactVersionId});
 if(error)throw new AuthorizationError(error.code==='22023'?'VALIDATION_ERROR':'NOT_FOUND');
 const result=z.strictObject({artifact:artifactSchema,version:artifactVersionSchema}).safeParse(data);
 if(!result.success||(await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError('NOT_FOUND');
 const {artifact,version}=result.data;const body=patentReadingSnapshotSchema.safeParse(version.content_snapshot);
 if(artifact.artifact_type!=='PATENT_READING_FRAMEWORK'||artifact.activity_instance_id!==v.activityInstanceId||version.artifact_id!==artifact.id||!body.success||body.data.source_patent_record_ids[0]!==v.patentRecordId)throw new AuthorizationError('NOT_FOUND');
 return result.data;
}
