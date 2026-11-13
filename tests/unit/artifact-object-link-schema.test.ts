import {describe,expect,it} from "vitest";
import {artifactObjectLinkSchema} from "@/features/artifacts/object-link-schema";
const id="00000000-0000-4000-8000-000000000001";
const row={id,artifact_id:id,artifact_version_id:id,development_object_id:id,role_in_artifact:null,sequence:null,metadata:{}};
describe("Artifact canonical Object link schema",()=>{
 it("accepts nullable context without interpreting authority",()=>expect(artifactObjectLinkSchema.parse(row)).toEqual(row));
 it("accepts arbitrary trimmed contextual role and sparse sequence",()=>expect(artifactObjectLinkSchema.safeParse({...row,role_in_artifact:"context for presentation",sequence:123,metadata:{role:"ADMIN",scope:{cohort:id}}}).success).toBe(true));
 it.each(["id","artifact_id","artifact_version_id","development_object_id"])("requires UUID %s",key=>expect(artifactObjectLinkSchema.safeParse({...row,[key]:null}).success).toBe(false));
 it.each([""," "," padded "])("rejects blank/untrimmed role %s",role=>expect(artifactObjectLinkSchema.safeParse({...row,role_in_artifact:role}).success).toBe(false));
 it.each([-1,1.2,2147483648])("rejects invalid sequence %s",sequence=>expect(artifactObjectLinkSchema.safeParse({...row,sequence}).success).toBe(false));
 it.each([null,[],"content"])("requires structured object metadata %s",metadata=>expect(artifactObjectLinkSchema.safeParse({...row,metadata}).success).toBe(false));
 it("does not accept copied canonical content columns",()=>expect(artifactObjectLinkSchema.safeParse({...row,content:"private"}).success).toBe(false));
});
