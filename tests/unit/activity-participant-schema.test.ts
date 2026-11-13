import {describe,expect,it} from "vitest";
import {activityParticipantSchema} from "@/features/activities/participant-schema";

const row={id:"00000000-0000-4000-8000-000000000001",activity_instance_id:"00000000-0000-4000-8000-000000000002",user_id:"00000000-0000-4000-8000-000000000003",participant_role:"participant",joined_at:"2026-10-01T10:00:00Z",completed_at:null,created_at:"2026-10-01T10:00:00Z",updated_at:"2026-10-01T10:00:00Z"};
describe("Activity participation data contract",()=>{
 it("accepts an open period",()=>expect(activityParticipantSchema.safeParse(row).success).toBe(true));
 it("accepts a completed historical period",()=>expect(activityParticipantSchema.safeParse({...row,completed_at:row.joined_at}).success).toBe(true));
 it("rejects completion before joining",()=>expect(activityParticipantSchema.safeParse({...row,completed_at:"2026-09-01T10:00:00Z"}).success).toBe(false));
 it("requires joining timestamp",()=>expect(activityParticipantSchema.safeParse({...row,joined_at:null}).success).toBe(false));
 it.each(["owner","team_lead","master","mentor","reviewer","approver","admin"])("rejects authority role %s",participant_role=>expect(activityParticipantSchema.safeParse({...row,participant_role}).success).toBe(false));
 it("rejects client authorization claims",()=>expect(activityParticipantSchema.safeParse({...row,role:"ADMIN",canView:true}).success).toBe(false));
});
