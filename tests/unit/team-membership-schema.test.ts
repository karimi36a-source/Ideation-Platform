import {expect,it} from "vitest";
import {teamMembershipSchema} from "@/features/teams/membership-schema";
const id="00000000-0000-4000-8000-000000002901";
const row={id,team_id:id,user_id:id,membership_role:"member",joined_at:"2026-01-01T00:00:00Z",left_at:null,status:"active",added_by:id,removed_by:null,created_at:"2026-01-01T00:00:00Z"};
it.each(["member","team_lead","mentor"])("accepts approved %s metadata",membership_role=>{expect(teamMembershipSchema.safeParse({...row,membership_role}).success).toBe(true);});
it("rejects an Admin platform role used as membership metadata",()=>{expect(teamMembershipSchema.safeParse({...row,membership_role:"ADMIN"}).success).toBe(false);});
it("requires complete coherent removal metadata",()=>{
 expect(teamMembershipSchema.safeParse({...row,status:"removed"}).success).toBe(false);
 expect(teamMembershipSchema.safeParse({...row,status:"removed",left_at:"2025-12-31T23:59:59Z",removed_by:id}).success).toBe(false);
 expect(teamMembershipSchema.safeParse({...row,status:"removed",left_at:row.joined_at,removed_by:id}).success).toBe(true);
});
it("rejects active rows carrying removal metadata",()=>{
 expect(teamMembershipSchema.safeParse({...row,left_at:row.joined_at}).success).toBe(false);
 expect(teamMembershipSchema.safeParse({...row,removed_by:id}).success).toBe(false);
});
