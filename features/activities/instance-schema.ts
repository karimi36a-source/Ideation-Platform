import {z} from "zod";
export const activityInstanceStatusSchema=z.enum(["not_started","active","submitted","under_review","revision_requested","completed","archived"]);
const timestamp=z.iso.datetime({offset:true}).nullable();
export const activityInstanceSchema=z.strictObject({
 id:z.uuid(),activity_definition_id:z.uuid(),cohort_id:z.uuid(),project_id:z.uuid(),workspace_id:z.uuid(),team_id:z.uuid().nullable(),
 started_by:z.uuid().nullable(),started_at:timestamp,completed_at:timestamp,status:activityInstanceStatusSchema,
 configuration_snapshot:z.record(z.string(),z.json()),created_at:z.iso.datetime({offset:true}),updated_at:z.iso.datetime({offset:true}),
}).refine(v=>{
 if(v.status==="not_started")return v.started_by===null&&v.started_at===null&&v.completed_at===null;
 if(v.started_by===null||v.started_at===null)return false;
 if(v.status==="completed")return v.completed_at!==null&&Date.parse(v.completed_at)>=Date.parse(v.started_at);
 if(v.status==="archived")return v.completed_at===null||Date.parse(v.completed_at)>=Date.parse(v.started_at);
 return v.completed_at===null;
},{message:"Invalid Activity lifecycle timestamps"});
export type ActivityInstance=z.infer<typeof activityInstanceSchema>;
