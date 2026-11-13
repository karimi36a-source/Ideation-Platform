import 'server-only';
import {z} from 'zod';

export const providerRoomRefSchema=z.string().regex(/^[A-Za-z0-9_-]{1,128}$/);
export const roomContextSchema=z.strictObject({roomKey:providerRoomRefSchema});
export const joinContextSchema=z.strictObject({
 providerRoomRef:providerRoomRefSchema,
 userId:z.uuid(),
 displayName:z.string().min(1).max(255).optional(),
 expiresAt:z.number().int().positive().max(Number.MAX_SAFE_INTEGER),
});
export type RoomContext=z.infer<typeof roomContextSchema>;
export type JoinContext=z.infer<typeof joinContextSchema>;
export type ProviderRoom={providerRoomRef:string;url:string};
export type LiveClassroomErrorCode='INVALID_INPUT'|'CONFIGURATION'|'AUTHENTICATION'|'RATE_LIMIT'|'TIMEOUT'|'NETWORK'|'UNAVAILABLE'|'NOT_FOUND'|'CONFLICT'|'REJECTED'|'MALFORMED_RESPONSE'|'UNKNOWN';
export type LiveClassroomResult<T>={success:true;data:T}|{success:false;error:{code:LiveClassroomErrorCode;message:string;retryable:boolean}};
/** Trusted server-to-server media boundary, not an authorization service.
 * Callers must authorize canonical FICI scope before invoking it. Room keys are
 * integration metadata. Token expiry is explicitly supplied by trusted policy. */
export interface LiveClassroomProvider {
 getOrCreateRoom(context:RoomContext):Promise<LiveClassroomResult<ProviderRoom>>;
 createJoinToken(context:JoinContext):Promise<LiveClassroomResult<{token:string;expiresAt:number}>>;
 /** Provider configuration availability, not attendance or Activity state. */
 getRoomStatus(providerRoomRef:string):Promise<LiveClassroomResult<{status:'available'|'missing'|'expired';url?:string}>>;
}


