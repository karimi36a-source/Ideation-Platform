import {z} from "zod";
export const patentRelevanceStatusSchema=z.enum(['NOT_REVIEWED','RELEVANT','POSSIBLY_RELEVANT','NOT_RELEVANT']);
export const patentSourceDatabaseSchema=z.enum(['PATENTSCOPE','USPTO','GOOGLE_PATENTS']);
const text=z.string().refine(v=>v.trim().length>0);
const sourceUrl=z.string().refine(value=>{
 if(!/^https:\/\//i.test(value)||/[\s\\]/.test(value))return false;
 try{const url=new URL(value);return url.protocol==='https:'&&url.hostname.length>0;}catch{return false;}
});
/** Persisted source metadata only. Parsing grants no creation or legal authority. */
export const patentRecordSchema=z.strictObject({
 id:z.uuid(),project_id:z.uuid(),workspace_id:z.uuid(),
 publication_number:text,application_number:z.string().nullable(),title:text,
 applicant:z.string().nullable(),inventor:z.string().nullable(),
 priority_date:z.iso.date().nullable(),filing_date:z.iso.date().nullable(),publication_date:z.iso.date().nullable(),
 ipc_cpc:z.string().nullable(),source_database:patentSourceDatabaseSchema,source_url:sourceUrl,
 abstract_text:z.string().nullable(),relevance_status:patentRelevanceStatusSchema,why_retained:z.string().nullable(),
 created_by:z.uuid(),created_at:z.iso.datetime({offset:true}),
});
export type PatentRecord=z.infer<typeof patentRecordSchema>;
