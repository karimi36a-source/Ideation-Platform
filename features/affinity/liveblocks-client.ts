"use client";
import { createClient } from "@liveblocks/client";
import { z } from "zod";
import { boardRequestSchema } from "./collaboration-schema";
/** Each new room authorization invokes the canonical FICI boundary. Provider
 * events are temporary hints only, never database saves or CAS acknowledgements. */
export function createAffinityLiveClient(input: unknown) {
 const { activityInstanceId } = boardRequestSchema.parse(input);
 const roomId = `affinity:${activityInstanceId}`;
 const client = createClient({ authEndpoint: async requestedRoom => {
  if (requestedRoom !== roomId) return { error: "forbidden", reason: "Resource unavailable." };
  const response = await fetch("/api/v1/affinity/collaboration-auth", {
   method: "POST", headers: { "Content-Type": "application/json" }, credentials: "same-origin", cache: "no-store",
   body: JSON.stringify({ activityInstanceId }),
  });
  if (!response.ok) return { error: "forbidden", reason: "Resource unavailable." };
  const value = z.object({ ok: z.literal(true), data: z.strictObject({ token: z.string().min(1) }) }).parse(await response.json());
  return value.data;
 }});
 return { client, roomId };
}
