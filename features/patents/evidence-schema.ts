import {z} from 'zod';
const text=z.string().refine(value=>value.trim().length>0);
export const linkPatentToEvidenceSchema=z.strictObject({patentRecordId:z.uuid(),evidenceType:z.enum(['PATENT','PATENT_CLAIM']),title:text,description:text,claimLocator:text.optional()})
 .refine(v=>v.evidenceType==='PATENT_CLAIM'?v.claimLocator!==undefined:v.claimLocator===undefined);
export type LinkPatentToEvidenceInput=z.infer<typeof linkPatentToEvidenceSchema>;
