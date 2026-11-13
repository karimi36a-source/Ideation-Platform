import {z} from "zod";
import {shareEntityTypes} from "./schema";
import {shareSnapshotContentSchemas} from "./snapshot-schema";
export const sharedEntityAccessInputSchema=z.strictObject({shareId:z.uuid()});
export const deniedSharedEntityAccess={allowed:false,canView:false,canComment:false,canEdit:false,canReshare:false,isSnapshot:false,isLiveReference:false} as const;
export const sharedEntityAccessResultSchema=z.discriminatedUnion("allowed",[
 z.strictObject({allowed:z.literal(false),canView:z.literal(false),canComment:z.literal(false),canEdit:z.literal(false),canReshare:z.literal(false),isSnapshot:z.literal(false),isLiveReference:z.literal(false)}),
 z.strictObject({allowed:z.literal(true),canView:z.literal(true),canComment:z.boolean(),canEdit:z.literal(false),canReshare:z.literal(false),isSnapshot:z.literal(true),isLiveReference:z.literal(false),
  shareId:z.uuid(),sharedEntityType:z.enum(shareEntityTypes),sharedEntityId:z.uuid(),sourceVersionId:z.uuid().nullable(),snapshotContent:z.record(z.string(),z.json())})
  .refine(row=>(row.sharedEntityType==="ARTIFACT")===(row.sourceVersionId!==null),"Invalid frozen Version binding")
  .refine(row=>shareSnapshotContentSchemas[row.sharedEntityType].safeParse(row.snapshotContent).success,"Invalid frozen projection"),
]);
export type SharedEntityAccess=z.infer<typeof sharedEntityAccessResultSchema>;
