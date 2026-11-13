import { beforeEach, afterEach, it, expect, vi } from "vitest";
const s=vi.hoisted(()=>({room:{defaultAccesses:[] as string[],usersAccesses:{} as Record<string,string[]>,groupsAccesses:{} as Record<string,string[]>},allow:vi.fn(),authorize:vi.fn(),failure:false}));
vi.mock('server-only',()=>({}));
vi.mock('@liveblocks/node',()=>({Liveblocks:class{
 async getOrCreateRoom(){if(s.failure)throw new Error('private provider internals');return s.room;}
 prepareSession(){return {allow:s.allow,authorize:s.authorize};}
}}));
import {liveblocksAffinityProvider} from '@/features/affinity/liveblocks-server';
import {authorizePrivateToolRoom} from '@/lib/collaboration/liveblocks-server';
const input={userId:'00000000-0000-4000-8000-000000000001',roomId:'affinity:00000000-0000-4000-8000-000000000002'};
beforeEach(()=>{vi.stubEnv('LIVEBLOCKS_SECRET_KEY','unit-only-placeholder');s.failure=false;s.room={defaultAccesses:[],usersAccesses:{},groupsAccesses:{}};s.allow.mockReset();s.authorize.mockReset().mockResolvedValue({status:200,body:JSON.stringify({token:'unit-token'})});});
afterEach(()=>vi.unstubAllEnvs());
it('grants only the exact room and returns only a token',async()=>{const result=await liveblocksAffinityProvider.authorize(input);expect(Object.keys(result)).toEqual(['token']);expect(s.allow).toHaveBeenCalledWith(input.roomId,['*:write','comments:none','feeds:none']);});
it('shared issuer restricts a read-only Mind Map to read with Comments/Feeds denied',async()=>{const roomId=input.roomId.replace('affinity:','mind-map:');await authorizePrivateToolRoom({userId:input.userId,roomId,writable:false});expect(s.allow).toHaveBeenCalledWith(roomId,['*:read','comments:none','feeds:none']);await expect(liveblocksAffinityProvider.authorize({...input,roomId})).rejects.toThrow('Provider unavailable.');});
it('rejects missing configuration and wildcard room patterns',async()=>{vi.stubEnv('LIVEBLOCKS_SECRET_KEY','');await expect(liveblocksAffinityProvider.authorize(input)).rejects.toThrow('Provider unavailable.');vi.stubEnv('LIVEBLOCKS_SECRET_KEY','unit-only-placeholder');await expect(liveblocksAffinityProvider.authorize({...input,roomId:'affinity:*'})).rejects.toThrow('Provider unavailable.');expect(s.allow).not.toHaveBeenCalled();});
it('fails closed on pre-existing public or user/group ACLs',async()=>{const rooms: typeof s.room[] = [{defaultAccesses:['*:write'],usersAccesses:{},groupsAccesses:{}},{defaultAccesses:[],usersAccesses:{foreign:['*:write']},groupsAccesses:{}},{defaultAccesses:[],usersAccesses:{},groupsAccesses:{foreign:['*:write']}}];for(const room of rooms){s.room=room;await expect(liveblocksAffinityProvider.authorize(input)).rejects.toThrow('Provider unavailable.');}expect(s.allow).not.toHaveBeenCalled();});
it('masks SDK/internal failures and rejects malformed grants',async()=>{s.failure=true;await expect(liveblocksAffinityProvider.authorize(input)).rejects.toThrow('Provider unavailable.');s.failure=false;for(const result of [{status:403,body:'private failure'},{status:200,body:JSON.stringify({token:'unit-token',secret:'private field'})}]){s.authorize.mockResolvedValue(result);await expect(liveblocksAffinityProvider.authorize(input)).rejects.toThrow('Provider unavailable.');}});
