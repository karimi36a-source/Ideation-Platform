import {z} from "zod";
export const cohortStatusSchema=z.enum(["planned","active","completed","archived"]);
const fields={name:z.string().trim().min(1).max(200),startDate:z.iso.date(),endDate:z.iso.date().nullable().default(null),primaryMasterId:z.uuid(),status:cohortStatusSchema.default("planned"),settings:z.record(z.string(),z.json()).default({})};
const dates=(v:{startDate:string;endDate:string|null})=>v.endDate===null||v.endDate>=v.startDate;
export const createCohortSchema=z.strictObject({...fields,programId:z.uuid(),curriculumVersionId:z.uuid()}).refine(dates);
export const updateCohortSchema=z.strictObject({...fields,status:cohortStatusSchema,settings:z.record(z.string(),z.json()),id:z.uuid()}).refine(dates);
export const cohortSchema=z.object({id:z.uuid(),program_id:z.uuid(),curriculum_version_id:z.uuid(),name:fields.name,start_date:z.iso.date(),end_date:z.iso.date().nullable(),status:cohortStatusSchema,primary_master_id:z.uuid(),settings:fields.settings,primary_master_assignment_id:z.uuid(),created_at:z.iso.datetime({offset:true}),updated_at:z.iso.datetime({offset:true})}).refine(v=>v.end_date===null||v.end_date>=v.start_date);
export type Cohort=z.infer<typeof cohortSchema>;

export const assignMasterToCohortSchema=z.strictObject({cohortId:z.uuid(),primaryMasterId:z.uuid()});
