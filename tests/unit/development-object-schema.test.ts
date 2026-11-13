import {describe,it,expect} from "vitest";
import {developmentObjectSchema,developmentObjectTypeSchema} from "@/features/projects/object-schema";
const id="00000000-0000-4000-8000-000000007201";
const fixture={id,project_id:id,workspace_id:id,object_type:"PROBLEM",title:"Problem",content:"Generic content",status:null,verification_status:null,origin_type:null,origin_reference_id:null,created_by:id,current_version_number:1,archived_at:null,metadata:{},created_at:"2026-10-04T00:00:00Z",updated_at:"2026-10-04T00:00:00Z"};
describe("Development Object schema",()=>{
 it.each(developmentObjectTypeSchema.options)("accepts %s",object_type=>expect(developmentObjectSchema.safeParse({...fixture,object_type}).success).toBe(true));
 it.each([{object_type:"OTHER"},{title:" "},{current_version_number:0},{metadata:[]},{status:""},{verification_status:" "},{origin_type:" "},{project_id:null},{workspace_id:null},{created_by:null}])("rejects invalid core fields %j",change=>expect(developmentObjectSchema.safeParse({...fixture,...change}).success).toBe(false));
 it("metadata cannot replace core fields",()=>expect(developmentObjectSchema.safeParse({metadata:fixture}).success).toBe(false));
 it("accepts archive and descriptive metadata without granting capabilities",()=>expect(developmentObjectSchema.parse({...fixture,archived_at:fixture.created_at,status:"Unspecified",metadata:{role:"ADMIN"}}).object_type).toBe("PROBLEM"));
});
