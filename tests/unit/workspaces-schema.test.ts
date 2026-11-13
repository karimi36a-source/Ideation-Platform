import {expect,it} from "vitest";
import {workspaceSchema,workspaceTypeSchema,workspaceStatusSchema,workspaceVisibilitySchema} from "@/features/workspaces/schema";
const uid="00000000-0000-4000-8000-000000000001";
const row={id:uid,workspace_type:"PERSONAL",name:"Fixture",owner_user_id:uid,team_id:null,cohort_id:null,project_id:null,status:"active",visibility:"private",settings:{},created_at:"2026-10-01T00:00:00Z",updated_at:"2026-10-01T00:00:00Z",created_by:uid,updated_by:uid,archived_at:null};
it.each(workspaceTypeSchema.options)("accepts approved type %s",workspace_type=>{expect(workspaceSchema.safeParse({...row,workspace_type}).success).toBe(true);});
it("rejects unsupported type, status, visibility and missing Personal owner",()=>{
 for(const change of [{workspace_type:"ADMIN"},{status:"deleted"},{visibility:"public"},{owner_user_id:null}])expect(workspaceSchema.safeParse({...row,...change}).success).toBe(false);
 expect(workspaceStatusSchema.options).toEqual(["active","inactive","archived"]);expect(workspaceVisibilitySchema.options).toEqual(["private"]);
});
