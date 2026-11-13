import { z } from "zod";
const id = z.uuid();
export const boardRequestSchema = z.strictObject({ activityInstanceId: id.transform(v => v.toLowerCase()) });
export const boardItemSchema = z.strictObject({
 id, affinity_group_id: id, position: z.number().int().positive(),
 move_revision: z.number().int().min(0).max(2147483647),
 development_object_id: id.nullable(), brainstorm_entry_id: id.nullable(),
}).refine(v => (v.development_object_id === null) !== (v.brainstorm_entry_id === null));
export const affinityBoardSchema = z.strictObject({
 activityInstanceId: id, roomId: z.string(),
 groups: z.array(z.strictObject({ id, sequence: z.number().int().positive() })),
 items: z.array(boardItemSchema),
}).superRefine((b, ctx) => {
 const groups = new Set(b.groups.map(g => g.id));
 if (groups.size !== b.groups.length || new Set(b.items.map(i => i.id)).size !== b.items.length || b.roomId !== `affinity:${b.activityInstanceId}`)
  ctx.addIssue({ code: "custom", message: "Invalid canonical board" });
 for (const g of b.groups) {
  const items = b.items.filter(i => i.affinity_group_id === g.id).sort((a,b) => a.position-b.position);
  if (items.some((i,n) => i.position !== n+1)) ctx.addIssue({ code: "custom", message: "Invalid ordering" });
 }
 if (b.items.some(i => !groups.has(i.affinity_group_id))) ctx.addIssue({ code: "custom", message: "Invalid group" });
});
export type AffinityBoard = z.infer<typeof affinityBoardSchema>;
