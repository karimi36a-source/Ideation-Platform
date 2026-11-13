import {z} from 'zod';
import {patentSourceDatabaseSchema} from './schema';
const text=z.string().refine(v=>v.trim().length>0);
const count=z.number().int().min(0).max(2147483647);
export const createPatentSearchLogSchema=z.strictObject({
 projectId:z.uuid(),workspaceId:z.uuid(),activityInstanceId:z.uuid(),databaseName:patentSourceDatabaseSchema,
 queryText:text,searchMethod:text,reason:text,resultsReviewedCount:count.optional(),relevantResultsCount:count.optional(),
 termsLearned:z.array(z.string()).optional(),classificationsLearned:z.array(z.string()).optional(),notes:z.string().nullable().optional(),
}).refine(v=>v.resultsReviewedCount===undefined||v.relevantResultsCount===undefined||v.relevantResultsCount<=v.resultsReviewedCount);
export type CreatePatentSearchLogInput=z.infer<typeof createPatentSearchLogSchema>;
export const patentSearchLogSchema=z.strictObject({
 id:z.uuid(),project_id:z.uuid(),workspace_id:z.uuid(),activity_instance_id:z.uuid(),database_name:patentSourceDatabaseSchema,
 query_text:text,search_method:text,reason:text,searched_at:z.iso.datetime({offset:true}),searched_by:z.uuid(),
 results_reviewed_count:count.nullable(),relevant_results_count:count.nullable(),terms_learned:z.array(z.string()),classifications_learned:z.array(z.string()),notes:z.string().nullable(),
}).refine(v=>v.results_reviewed_count===null||v.relevant_results_count===null||v.relevant_results_count<=v.results_reviewed_count);
export type PatentSearchLog=z.infer<typeof patentSearchLogSchema>;
