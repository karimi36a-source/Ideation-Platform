import {describe,it,expect} from "vitest";
import {affinityGroupSchema,affinityGroupItemSchema} from "@/features/affinity/schema";
const id="00000000-0000-4000-8000-000000000001";
const group={id,activity_instance_id:id,name:"Group",description:null,sequence:1,created_by:id,created_at:"2026-10-13T00:00:00Z"};
const item={id,affinity_group_id:id,development_object_id:id,brainstorm_entry_id:null,position:1,move_revision:0,added_by:id,created_at:group.created_at};
describe("Affinity persisted contracts",()=>{
 it("accepts canonical sources separately",()=>{expect(affinityGroupSchema.safeParse(group).success).toBe(true);expect(affinityGroupItemSchema.safeParse(item).success).toBe(true);expect(affinityGroupItemSchema.safeParse({...item,development_object_id:null,brainstorm_entry_id:id}).success).toBe(true);});
 it("rejects missing/ambiguous sources",()=>{expect(affinityGroupItemSchema.safeParse({...item,development_object_id:null}).success).toBe(false);expect(affinityGroupItemSchema.safeParse({...item,brainstorm_entry_id:id}).success).toBe(false);});
 it("rejects invalid ordering and copied content",()=>{for(const position of [0,-1,1.5,2147483648])expect(affinityGroupItemSchema.safeParse({...item,position}).success).toBe(false);expect(affinityGroupSchema.safeParse({...group,sequence:0}).success).toBe(false);expect(affinityGroupItemSchema.safeParse({...item,content:"Copied source"}).success).toBe(false);});
});
