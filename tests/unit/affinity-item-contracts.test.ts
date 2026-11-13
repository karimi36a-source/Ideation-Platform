import {describe,it,expect} from "vitest";
import {addAffinityItemSchema,moveAffinityItemSchema} from "@/features/affinity/item-operations-schema";
const id="00000000-0000-4000-8000-000000000001";
describe("Affinity item input boundary",()=>{
 it("requires exactly one canonical source",()=>{expect(addAffinityItemSchema.safeParse({affinityGroupId:id}).success).toBe(false);expect(addAffinityItemSchema.safeParse({affinityGroupId:id,developmentObjectId:id,brainstormEntryId:id}).success).toBe(false);expect(addAffinityItemSchema.safeParse({affinityGroupId:id,brainstormEntryId:id}).success).toBe(true);});
 it("rejects client identity/scope/content claims",()=>{for(const key of ['addedBy','projectId','workspaceId','teamId','activityInstanceId','content','role','createdBy'])expect(addAffinityItemSchema.safeParse({affinityGroupId:id,developmentObjectId:id,[key]:id}).success).toBe(false);});
 it("requires positive integer movement positions",()=>{for(const position of [0,-1,1.5,2147483648])expect(moveAffinityItemSchema.safeParse({itemId:id,targetGroupId:id,position}).success).toBe(false);expect(moveAffinityItemSchema.safeParse({itemId:id,targetGroupId:id}).success).toBe(false);expect(moveAffinityItemSchema.safeParse({itemId:id,targetGroupId:id,position:1,developmentObjectId:id}).success).toBe(false);});
});
