import "server-only";
import { liveblocksAffinityProvider } from "./liveblocks-server";
import { AuthorizationError, getAuthorizationContext } from "@/lib/auth/authorization";
import { createServerSupabaseClient } from "@/lib/db/server";
import { affinityBoardSchema, boardRequestSchema } from "./collaboration-schema";
import { AffinityActivityStateError } from "./service";

/** Fresh canonical reload also serves as the room authorization boundary.
 * No room/actor/team claim is accepted; minimal layout comes from PostgreSQL. */
export async function getAffinityCollaborationBoard(input: unknown) {
 try {
 const actor = await getAuthorizationContext();
 const request = boardRequestSchema.safeParse(input);
 if (!request.success) throw new AuthorizationError("VALIDATION_ERROR");
 const db = await createServerSupabaseClient();
 if ((await getAuthorizationContext()).userId !== actor.userId) throw new AuthorizationError("NOT_FOUND");
 const { data, error } = await db.rpc("get_affinity_collaboration_board", { target_activity: request.data.activityInstanceId });
 if ((await getAuthorizationContext()).userId !== actor.userId) throw new AuthorizationError("NOT_FOUND");
 if (error) {
  if (error.code === "55000") throw new AffinityActivityStateError();
  throw new AuthorizationError(error.code === "28000" ? "AUTH_REQUIRED" : "NOT_FOUND");
 }
 const board = affinityBoardSchema.safeParse(data);
 if (!board.success || board.data.activityInstanceId !== request.data.activityInstanceId) throw new AuthorizationError("NOT_FOUND");
 return board.data;
 } catch (error) {
  if (error instanceof AffinityActivityStateError) throw error;
  throw new AuthorizationError(error instanceof AuthorizationError && ["AUTH_REQUIRED", "VALIDATION_ERROR"].includes(error.code) ? error.code : "NOT_FOUND");
 }
}

export class AffinityProviderUnavailableError extends Error {
 readonly code = "DEPENDENCY_NOT_READY";
 constructor() { super("Collaboration provider unavailable."); }
}
/** Trusted server adapter only. Must issue access to this exact room, never a
 * wildcard, and put no canonical source content into provider state. */
export interface AffinityRoomProvider {
 authorize(input: Readonly<{ userId: string; roomId: string }>): Promise<unknown>;
}
export function createAffinityRoomAuthorizer(provider: AffinityRoomProvider | null) {
 return async (input: unknown) => {
  const actor = await getAuthorizationContext();
  const board = await getAffinityCollaborationBoard(input);
  if ((await getAuthorizationContext()).userId !== actor.userId) throw new AuthorizationError("NOT_FOUND");
  if (!provider) throw new AffinityProviderUnavailableError();
  let authorization: unknown;
  try { authorization = await provider.authorize({ userId: actor.userId, roomId: board.roomId }); }
  catch { throw new AffinityProviderUnavailableError(); }
  // Revalidate current canonical rights after provider I/O. Never return a grant
  // for an actor removed while awaiting the provider.
  await getAffinityCollaborationBoard(input);
  if ((await getAuthorizationContext()).userId !== actor.userId) throw new AuthorizationError("NOT_FOUND");
  return authorization;
 };
}
// Secret is read server-side at issuance time; missing configuration fails closed.
export const authorizeAffinityCollaboration = createAffinityRoomAuthorizer(liveblocksAffinityProvider);
