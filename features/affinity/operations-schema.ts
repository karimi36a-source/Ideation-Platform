import {z} from "zod";
const name=z.string().trim().min(1).max(200);
const description=z.string().trim().max(10000).nullable().optional();
export const createAffinityGroupSchema=z.strictObject({activityInstanceId:z.uuid().transform(value=>value.toLowerCase()),name,description});
export const renameAffinityGroupSchema=z.strictObject({affinityGroupId:z.uuid().transform(value=>value.toLowerCase()),name,description});
