import 'server-only';
import type {LiveClassroomProvider} from './provider';
import {DailyLiveClassroomProvider} from './providers/daily';
/** Server composition root. No room mappings or educational state are stored. */
export function createLiveClassroomProvider(transport:typeof fetch=fetch):LiveClassroomProvider{
 return new DailyLiveClassroomProvider({apiKey:process.env.DAILY_API_KEY},transport);
}
