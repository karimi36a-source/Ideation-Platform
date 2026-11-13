import {z} from 'zod';
export const patentReadingSections=['title','abstract','description','claims','drawings','bibliographic_information'] as const;
export const patentReadingNotesSchema=z.strictObject({title:z.string(),abstract:z.string(),description:z.string(),claims:z.string(),drawings:z.string(),bibliographic_information:z.string()});
export const savePatentReadingFrameworkSchema=z.strictObject({activityInstanceId:z.uuid(),patentRecordId:z.uuid(),notes:patentReadingNotesSchema,artifactVersionId:z.uuid().nullable().default(null),expectedDraftRevision:z.number().int().min(0).max(2147483647).nullable().default(null)}).refine(v=>(v.artifactVersionId===null)===(v.expectedDraftRevision===null),{message:'Version identity and revision are required together'});
export const patentReadingSnapshotSchema=z.strictObject({learner_notes:patentReadingNotesSchema,source_patent_record_ids:z.array(z.uuid()).length(1)});
