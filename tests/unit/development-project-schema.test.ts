import {describe,it,expect} from "vitest";
import {developmentProjectSchema,developmentProjectTypeSchema,developmentProjectStatusSchema} from "@/features/projects/schema";
const row={id:"00000000-0000-4000-8000-000000007201",name:"Project",description:null,project_type:"individual",owner_user_id:"00000000-0000-4000-8000-000000006004",owner_team_id:null,primary_workspace_id:"00000000-0000-4000-8000-000000007101",status:"active",current_stage:null,confidentiality_level:null,created_at:"2026-10-04T12:00:00Z",updated_at:"2026-10-04T12:00:00Z",archived_at:null,required_workspace_type:"PERSONAL"};
describe("M6.1 persistent Project shape",()=>{
 it("accepts nullable metadata without invented stages",()=>expect(developmentProjectSchema.safeParse(row).success).toBe(true));
 it.each(["individual","team","instructor_case_study"])("supports %s",v=>expect(developmentProjectTypeSchema.safeParse(v).success).toBe(true));
 it.each(["active","paused","completed","archived"])("supports %s status",v=>expect(developmentProjectStatusSchema.safeParse(v).success).toBe(true));
 it.each([{owner_team_id:row.owner_user_id},{owner_user_id:null},{required_workspace_type:"TEAM"},{project_type:"unknown"},{status:"deleted"},{current_stage:" "},{confidentiality_level:""}])("rejects contradictory or invalid shape %j",changes=>expect(developmentProjectSchema.safeParse({...row,...changes}).success).toBe(false));
});
