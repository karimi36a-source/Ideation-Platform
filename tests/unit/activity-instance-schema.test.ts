import {it,expect} from "vitest";
import {activityInstanceSchema,activityInstanceStatusSchema} from "@/features/activities/instance-schema";
const id="00000000-0000-4000-8000-000000006004",stamp="2026-10-05T00:00:00Z";
const row={id,activity_definition_id:id,cohort_id:id,project_id:id,workspace_id:id,team_id:null,started_by:id,started_at:stamp,completed_at:null,status:"active",configuration_snapshot:{},created_at:stamp,updated_at:stamp};
it.each(activityInstanceStatusSchema.options)("M7.1 accepts %s timestamps",status=>expect(activityInstanceSchema.safeParse({...row,status,...(status==="not_started"?{started_by:null,started_at:null}:status==="completed"?{completed_at:stamp}:{})}).success).toBe(true));
it.each([{status:"other"},{started_by:null},{started_at:null},{status:"not_started"},{status:"completed"},{status:"completed",completed_at:"2000-01-01T00:00:00Z"},{completed_at:stamp},{configuration_snapshot:[]},{project_id:null},{team_id:"invalid"}])("M7.1 rejects invalid shape %j",patch=>expect(activityInstanceSchema.safeParse({...row,...patch}).success).toBe(false));
it("M7.1 snapshot metadata cannot replace canonical fields",()=>expect(activityInstanceSchema.safeParse({configuration_snapshot:row}).success).toBe(false));
it("M7.1 supports optional Team reference as schema data only",()=>expect(activityInstanceSchema.parse({...row,team_id:id,configuration_snapshot:{role:"ADMIN"}}).team_id).toBe(id));
