import {z} from 'zod';
import {patentRecordSchema,patentRelevanceStatusSchema} from './schema';
const s=patentRecordSchema.shape;
export const createPatentRecordSchema=z.strictObject({
 projectId:s.project_id,workspaceId:s.workspace_id,publicationNumber:s.publication_number,
 applicationNumber:s.application_number.optional(),title:s.title,applicant:s.applicant.optional(),inventor:s.inventor.optional(),
 priorityDate:s.priority_date.optional(),filingDate:s.filing_date.optional(),publicationDate:s.publication_date.optional(),
 ipcCpc:s.ipc_cpc.optional(),sourceDatabase:s.source_database,sourceUrl:s.source_url,
 abstractText:s.abstract_text.optional(),whyRetained:s.why_retained.optional(),relevanceStatus:patentRelevanceStatusSchema.optional(),
});
export type CreatePatentRecordInput=z.infer<typeof createPatentRecordSchema>;
