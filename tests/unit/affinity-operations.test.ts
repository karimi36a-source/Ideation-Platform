import {describe,it,expect} from "vitest";
import {createAffinityGroupSchema,renameAffinityGroupSchema} from "@/features/affinity/operations-schema";
const id="00000000-0000-4000-8000-000000000001";
describe("Affinity operation input boundary",()=>{
 it("normalizes Unicode edge whitespace and nullable descriptions",()=>{expect(createAffinityGroupSchema.parse({activityInstanceId:id,name:"\u00a0 Natural label \u2000",description:" description "}).name).toBe("Natural label");expect(renameAffinityGroupSchema.parse({affinityGroupId:id,name:"Label",description:null}).description).toBeNull();});
 it("rejects blank/oversized labels and descriptions",()=>{for(const name of ["","\u00a0\u2000","x".repeat(201)])expect(createAffinityGroupSchema.safeParse({activityInstanceId:id,name}).success).toBe(false);expect(createAffinityGroupSchema.safeParse({activityInstanceId:id,name:"Label",description:"x".repeat(10001)}).success).toBe(false);});
 it("rejects identity, ordering, scope and lifecycle claims",()=>{for(const key of ["createdBy","sequence","projectId","workspaceId","teamId","userId","role","status"]){expect(createAffinityGroupSchema.safeParse({activityInstanceId:id,name:"Label",[key]:id}).success).toBe(false);expect(renameAffinityGroupSchema.safeParse({affinityGroupId:id,name:"Label",[key]:id}).success).toBe(false);}});
});
