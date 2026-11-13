import {expect,it} from "vitest";
import {projectMembershipSchema} from "@/features/projects/membership-schema";
const row={id:"00000000-0000-4000-8000-000000007301",project_id:"00000000-0000-4000-8000-000000007202",user_id:"00000000-0000-4000-8000-000000006004",project_role:"participant",status:"active",starts_at:"2026-10-01T00:00:00Z",ends_at:null,created_at:"2026-10-01T00:00:00Z",updated_at:"2026-10-01T00:00:00Z"};
it("supports scheduled participation without treating it as a new status",()=>expect(projectMembershipSchema.safeParse({...row,starts_at:"2030-01-01T00:00:00Z"}).success).toBe(true));
it("requires an end for inactive history",()=>expect(projectMembershipSchema.safeParse({...row,status:"inactive"}).success).toBe(false));
it("preserves a valid ended period",()=>expect(projectMembershipSchema.safeParse({...row,status:"inactive",ends_at:row.starts_at}).success).toBe(true));
it.each([{project_role:"admin"},{project_role:"owner"},{status:"removed"},{ends_at:"2026-09-01T00:00:00Z"}])("rejects authority/lifecycle/interval invention %j",changes=>expect(projectMembershipSchema.safeParse({...row,...changes}).success).toBe(false));
