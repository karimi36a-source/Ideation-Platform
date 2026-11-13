import 'server-only';
import {AuthorizationError,getAuthorizationContext} from '@/lib/auth/authorization';
import {createServerSupabaseClient} from '@/lib/db/server';
import {createPatentSearchLogSchema,patentSearchLogSchema,type PatentSearchLog} from './search-schema';
/** Append human research history. No provider search, inference or metadata overwrite. */
export async function createPatentSearchLog(input:unknown):Promise<PatentSearchLog>{try{
 const actor=await getAuthorizationContext();const parsed=createPatentSearchLogSchema.safeParse(input);
 if(!parsed.success)throw new AuthorizationError('VALIDATION_ERROR');
 const v=parsed.data;const db=await createServerSupabaseClient();
 if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError('NOT_FOUND');
 const result=await db.rpc('create_patent_search_log',{input:v});
 if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError('NOT_FOUND');
 if(result.error)throw new AuthorizationError(result.error.code==='28000'?'AUTH_REQUIRED':['22023','22P02','23514','22003'].includes(result.error.code??'')?'VALIDATION_ERROR':'NOT_FOUND');
 const row=patentSearchLogSchema.safeParse(result.data);
 if(!row.success||row.data.searched_by!==actor.userId)throw new AuthorizationError('NOT_FOUND');
 for(const [key,value] of Object.entries({project_id:v.projectId,workspace_id:v.workspaceId,activity_instance_id:v.activityInstanceId}))if(row.data[key as 'project_id'].toLowerCase()!==value.toLowerCase())throw new AuthorizationError('NOT_FOUND');
 const expected={database_name:v.databaseName,query_text:v.queryText,search_method:v.searchMethod,reason:v.reason,results_reviewed_count:v.resultsReviewedCount??null,relevant_results_count:v.relevantResultsCount??null,terms_learned:v.termsLearned??[],classifications_learned:v.classificationsLearned??[],notes:v.notes??null};
 for(const [key,value] of Object.entries(expected))if(JSON.stringify(row.data[key as keyof PatentSearchLog])!==JSON.stringify(value))throw new AuthorizationError('NOT_FOUND');
 return row.data;
 }catch(error){throw new AuthorizationError(error instanceof AuthorizationError&&['AUTH_REQUIRED','VALIDATION_ERROR'].includes(error.code)?error.code:'NOT_FOUND');}}
