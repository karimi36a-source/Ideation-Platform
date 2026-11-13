import {expect,it,vi} from 'vitest';
vi.mock('server-only',()=>({}));
import {DailyLiveClassroomProvider} from '@/features/live-classroom/providers/daily';
it('Daily receives trusted display identity with room/expiry binding and no owner/moderator privileges',async()=>{
 const transport=vi.fn<typeof fetch>().mockResolvedValue(new Response(JSON.stringify({token:'safe.join.token'})));
 const provider=new DailyLiveClassroomProvider({apiKey:'test-server-only-key'},transport);
 const expiresAt=Math.floor(Date.now()/1000)+60;
 expect(await provider.createJoinToken({providerRoomRef:'canonical-room',userId:'00000000-0000-4000-8000-000000160401',displayName:'Trusted name',expiresAt})).toEqual({success:true,data:{token:'safe.join.token',expiresAt}});
 expect(JSON.parse(transport.mock.calls[0][1]!.body as string)).toEqual({properties:{room_name:'canonical-room',user_id:'00000000-0000-4000-8000-000000160401',user_name:'Trusted name',exp:expiresAt,eject_at_token_exp:true,is_owner:false}});
});

