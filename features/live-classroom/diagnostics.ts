import 'server-only';
import {recordStructuredFailure} from '@/lib/observability/structured-log';
const phases=new Set(['PROVIDER','ROOM_RESOLUTION','MAPPING_SAVE','TOKEN_ISSUANCE']);
const codes=new Set(['CONFIGURATION','AUTHENTICATION','RATE_LIMIT','TIMEOUT','NETWORK','UNAVAILABLE','REJECTED','MALFORMED_RESPONSE','UNKNOWN']);
/** Allowlisted classifications only: never serialize provider responses, errors,
 * URLs, headers, credentials or join capabilities. Verified IDs come only from
 * the request's allowlisted server context. Logging is not
 * a required transactional step and cannot turn failure into state mutation. */
export function recordLiveClassroomFailure(phase:unknown,code:unknown){
 const event={phase:typeof phase==='string'&&phases.has(phase)?phase:'PROVIDER',code:typeof code==='string'&&codes.has(code)?code:'UNKNOWN'};
 recordStructuredFailure('LIVE_FAILURE',{...event,...(event.phase==='MAPPING_SAVE'?{provider:'SUPABASE',task:'master_live_room_mapping'}:{})});
}
