import {describe,expect,it} from "vitest";
import {activityInputSchema,activityOutputSchema} from "@/features/activities/io-schema";
const common={id:"00000000-0000-4000-8000-000000000001",activity_instance_id:"00000000-0000-4000-8000-000000000002",development_object_id:"00000000-0000-4000-8000-000000000003",artifact_id:null,evidence_id:null,created_at:"2026-10-01T10:00:00Z",updated_at:"2026-10-01T10:00:00Z"};
const input={...common,input_type:"development_object",artifact_version_id:null,required:true};
const output={...common,output_type:"development_object",decision_id:null};
describe("Canonical Activity link contracts",()=>{
 it.each([true,false])("accepts explicit required=%s",required=>expect(activityInputSchema.safeParse({...input,required}).success).toBe(true));
 it("requires an explicit required flag",()=>expect(activityInputSchema.safeParse({...input,required:undefined}).success).toBe(false));
 it("accepts Object output without approval fields",()=>expect(activityOutputSchema.safeParse(output).success).toBe(true));
 it.each(["artifact_id","artifact_version_id","evidence_id"])("rejects input deferred target %s",field=>expect(activityInputSchema.safeParse({...input,[field]:common.id}).success).toBe(false));
 it.each(["artifact_id","decision_id","evidence_id"])("rejects output deferred target %s",field=>expect(activityOutputSchema.safeParse({...output,[field]:common.id}).success).toBe(false));
 it("rejects empty input target",()=>expect(activityInputSchema.safeParse({...input,development_object_id:null}).success).toBe(false));
 it("rejects empty output target",()=>expect(activityOutputSchema.safeParse({...output,development_object_id:null}).success).toBe(false));
 it("rejects unsupported input type",()=>expect(activityInputSchema.safeParse({...input,input_type:"artifact"}).success).toBe(false));
 it("rejects unsupported output type",()=>expect(activityOutputSchema.safeParse({...output,output_type:"decision"}).success).toBe(false));
 it("rejects copied input content",()=>expect(activityInputSchema.safeParse({...input,content:"private"}).success).toBe(false));
 it("rejects approval/verification metadata on output",()=>expect(activityOutputSchema.safeParse({...output,approved:true,verification_status:"verified"}).success).toBe(false));
});
