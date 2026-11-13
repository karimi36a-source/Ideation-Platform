import { moveAffinityItemSchema } from "./item-operations-schema";
import { affinityGroupItemSchema, type AffinityGroupItem } from "./schema";

export type AffinityMove = import("zod").infer<typeof moveAffinityItemSchema>;
export type MovementState =
 | { phase: "optimistic"; input: AffinityMove }
 | { phase: "persisted"; input: AffinityMove; item: AffinityGroupItem }
 | { phase: "conflict" | "failed"; input: AffinityMove };

/** Provider-independent acknowledgement plumbing. Optimistic state is never
 * labelled saved before the validated PostgreSQL operation returns. On failure
 * discard the optimistic layout and reload canonical board; no automatic retry
 * with a refreshed revision may overwrite an acknowledged competing move. */
export async function persistCollaborativeAffinityMove(
 input: AffinityMove,
 persist: (move: AffinityMove) => Promise<AffinityGroupItem>,
 report: (state: MovementState) => void,
) {
 const move = moveAffinityItemSchema.parse(input);
 report({ phase: "optimistic", input: move });
 try {
  const item = affinityGroupItemSchema.parse(await persist(move));
  if (item.id !== move.itemId || item.affinity_group_id !== move.targetGroupId || item.position !== move.position || ![move.expectedRevision, move.expectedRevision + 1].includes(item.move_revision))
   throw new Error("Invalid persistence acknowledgement.");
  report({ phase: "persisted", input: move, item });
  return item;
 } catch (error) {
  report({ phase: error instanceof Error && "code" in error && error.code === "CONFLICT" ? "conflict" : "failed", input: move });
  throw error;
 }
}
