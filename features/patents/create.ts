import 'server-only';
import {AuthorizationError,getAuthorizationContext} from '@/lib/auth/authorization';
import {createServerSupabaseClient} from '@/lib/db/server';
import {createPatentRecordSchema} from './create-schema';
import {patentRecordSchema,type PatentRecord} from './schema';
/** Exact human-supplied source metadata; no fetch, merge, Evidence or analysis. */
export async function createPatentRecord(input:unknown):Promise<PatentRecord>{try{
 const actor=await getAuthorizationContext();const parsed=createPatentRecordSchema.safeParse(input);
 if(!parsed.success)throw new AuthorizationError('VALIDATION_ERROR');
 const v=parsed.data;const db=await createServerSupabaseClient();
 if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError('NOT_FOUND');
 const result=await db.rpc('create_patent_record',{input:v});
 if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError('NOT_FOUND');
 if(result.error)throw new AuthorizationError(result.error.code==='28000'?'AUTH_REQUIRED':['22023','22P02','22007','22008','23514'].includes(result.error.code??'')?'VALIDATION_ERROR':'NOT_FOUND');
 const row=patentRecordSchema.safeParse(result.data);
 if(!row.success||row.data.project_id.toLowerCase()!==v.projectId.toLowerCase()||row.data.workspace_id.toLowerCase()!==v.workspaceId.toLowerCase()||row.data.created_by!==actor.userId)throw new AuthorizationError('NOT_FOUND');
 const expected={publication_number:v.publicationNumber,application_number:v.applicationNumber??null,title:v.title,applicant:v.applicant??null,inventor:v.inventor??null,priority_date:v.priorityDate??null,filing_date:v.filingDate??null,publication_date:v.publicationDate??null,ipc_cpc:v.ipcCpc??null,source_database:v.sourceDatabase,source_url:v.sourceUrl,abstract_text:v.abstractText??null,why_retained:v.whyRetained??null,relevance_status:v.relevanceStatus??'NOT_REVIEWED'};
 for(const [key,value] of Object.entries(expected))if(row.data[key as keyof PatentRecord]!==value)throw new AuthorizationError('NOT_FOUND');
 return row.data;
 }catch(error){throw new AuthorizationError(error instanceof AuthorizationError&&['AUTH_REQUIRED','VALIDATION_ERROR'].includes(error.code)?error.code:'NOT_FOUND');}}
