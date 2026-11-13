import {beforeEach,expect,it,vi} from 'vitest';
vi.mock('server-only',()=>({}));
const m=vi.hoisted(()=>({auth:vi.fn(),from:vi.fn(),select:vi.fn(),eq:vi.fn(),order:vi.fn(),is:vi.fn(),or:vi.fn(),limit:vi.fn()}));
vi.mock('@/lib/auth/authorization',async original=>({...await original<typeof import('@/lib/auth/authorization')>(),getAuthorizationContext:m.auth}));
vi.mock('@/lib/db/server',()=>({createServerSupabaseClient:async()=>({from:m.from})}));
import {AuthorizationError} from '@/lib/auth/authorization';
import {listMyNotifications} from '@/features/notifications/list';
const id=(n:number)=>'00000000-0000-4000-8000-'+String(n).padStart(12,'0');
const row=(n:number)=>({id:id(n),recipient_user_id:id(1),notification_type:'MEMBER_ADDED',title:'Team membership updated',body:'You have been added to a Team.',entity_type:'team',entity_id:id(99),read_at:null,created_at:'2026-11-06T00:00:00.123456+00:00'});
beforeEach(()=>{
 vi.resetAllMocks();m.auth.mockResolvedValue({userId:id(1)});
 for(const name of ['from','select','eq','order','is','or'] as const)m[name].mockReturnValue(m);
 m.limit.mockResolvedValue({data:[row(5),{...row(4),read_at:'2026-11-06T00:00:01Z'}],error:null});
});
it('lists only the authenticated recipient with bounded deterministic descending query and no joins/mutations',async()=>{
 const page=await listMyNotifications();expect(page.items).toHaveLength(2);expect(page.nextCursor).toBeNull();
 expect(m.from).toHaveBeenCalledExactlyOnceWith('notifications');expect(m.eq).toHaveBeenCalledExactlyOnceWith('recipient_user_id',id(1));
 expect(m.order.mock.calls).toEqual([['created_at',{ascending:false}],['id',{ascending:false}]]);expect(m.limit).toHaveBeenCalledWith(51);
 expect(m.select).toHaveBeenCalledWith('id,recipient_user_id,notification_type,title,body,entity_type,entity_id,read_at,created_at');
 expect(m.is).not.toHaveBeenCalled();expect(page.items[1].read_at).not.toBeNull();
 for(const value of page.items)expect(Object.keys(value).sort()).toEqual(['id','notification_type','title','body','entity_type','entity_id','read_at','created_at'].sort());
});
it.each([1,25,100])('accepts explicit bounded limit %s',async limit=>{await listMyNotifications({limit});expect(m.limit).toHaveBeenCalledWith(limit+1);});
it('pages ties with an exact microsecond timestamp and ID without duplication or skipping',async()=>{
 m.limit.mockResolvedValueOnce({data:[row(5),row(4),row(3)],error:null}).mockResolvedValueOnce({data:[row(3),row(2),row(1)],error:null});
 const first=await listMyNotifications({limit:2}),second=await listMyNotifications({limit:2,cursor:first.nextCursor});
 expect(first.items.map(r=>r.id)).toEqual([id(5),id(4)]);expect(second.items.map(r=>r.id)).toEqual([id(3),id(2)]);
 expect(first.nextCursor).toEqual({createdAt:row(4).created_at,id:id(4)});
 expect(m.or).toHaveBeenCalledWith('created_at.lt.2026-11-06T00:00:00.123456+00:00,and(created_at.eq.2026-11-06T00:00:00.123456+00:00,id.lt.'+id(4)+')');
 expect(new Set([...first.items,...second.items].map(r=>r.id)).size).toBe(4);
});
it('filters unread only without writing read_at',async()=>{
 m.limit.mockResolvedValue({data:[row(1)],error:null});await listMyNotifications({unreadOnly:true});expect(m.is).toHaveBeenCalledExactlyOnceWith('read_at',null);
});
it('preserves safe legacy/unknown codes and optional or inaccessible targets without hydrating them',async()=>{
 m.limit.mockResolvedValue({data:[{...row(1),notification_type:'LEGACY_PILOT_CODE',entity_type:null,entity_id:null},row(2)],error:null});
 const result=await listMyNotifications({unreadOnly:false});expect(result.items[0].notification_type).toBe('LEGACY_PILOT_CODE');expect(result.items[1].entity_id).toBe(id(99));expect(m.from).toHaveBeenCalledTimes(1);
});
it.each([
 {recipientUserId:id(2)},{recipient_user_id:id(2)},{workspaceId:id(2)},{teamId:id(2)},{id:id(2)},
 {limit:0},{limit:101},{limit:1.5},{limit:'10'},{unreadOnly:'true'},
 {cursor:'opaque-unvalidated'},{cursor:{createdAt:'bad',id:id(2)}},{cursor:{createdAt:row(1).created_at,id:'bad'}},
 {cursor:{createdAt:row(1).created_at,id:id(2),recipientUserId:id(2)}},
 {cursor:{createdAt:'2026-11-06T00:00:00Z),recipient_user_id.eq.evil',id:id(2)}},null,[],
])('rejects spoofed/malformed input before query %#',async input=>{
 await expect(listMyNotifications(input)).rejects.toMatchObject({code:'VALIDATION_ERROR'});expect(m.from).not.toHaveBeenCalled();
});
it('requires authentication and preserves standard auth errors',async()=>{
 m.auth.mockRejectedValue(new AuthorizationError('AUTH_REQUIRED'));await expect(listMyNotifications()).rejects.toMatchObject({code:'AUTH_REQUIRED'});expect(m.from).not.toHaveBeenCalled();
});
it.each(['ADMIN','MASTER','MENTOR','STUDENT'])('roles do not widen recipient query for %s',async role=>{
 m.auth.mockResolvedValue({userId:id(2),assignments:[{roleCode:role}]});m.limit.mockResolvedValue({data:[],error:null});expect((await listMyNotifications()).items).toEqual([]);expect(m.eq).toHaveBeenCalledWith('recipient_user_id',id(2));
});
it('rejects cross-user result or extra internal metadata defensively',async()=>{
 for(const extra of [{recipient_user_id:id(2)},{idempotency_digest:'private'},{metadata:{private:'value'}}]){
  m.limit.mockResolvedValue({data:[{...row(1),...extra}],error:null});await expect(listMyNotifications()).rejects.toMatchObject({code:'NOT_FOUND'});
 }
});
it('withholds results after an identity switch',async()=>{
 m.auth.mockResolvedValueOnce({userId:id(1)}).mockResolvedValueOnce({userId:id(2)});await expect(listMyNotifications()).rejects.toMatchObject({code:'NOT_FOUND'});
});
it('does not use another recipient cursor as authority',async()=>{
 m.auth.mockResolvedValue({userId:id(2)});m.limit.mockResolvedValue({data:[],error:null});await listMyNotifications({cursor:{createdAt:row(1).created_at,id:id(1)}});expect(m.eq).toHaveBeenCalledWith('recipient_user_id',id(2));
});
it('returns safe empty and database-failure results',async()=>{
 m.limit.mockResolvedValueOnce({data:[],error:null}).mockResolvedValueOnce({data:null,error:{message:'PRIVATE_DETAIL'}});
 expect(await listMyNotifications()).toEqual({items:[],nextCursor:null});await expect(listMyNotifications()).rejects.toMatchObject({code:'NOT_FOUND',message:'Resource unavailable.'});
});
