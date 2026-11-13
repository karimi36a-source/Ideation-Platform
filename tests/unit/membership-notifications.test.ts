import {expect,it,vi} from 'vitest';
import {readFileSync} from 'node:fs';
vi.mock('server-only',()=>({}));
import {getNotificationTypeDefinition} from '@/features/notifications/type-registry';
import texts from '@/features/notifications/membership-registry.json';
const migration=readFileSync('supabase/migrations/20261106040000_membership_notifications.sql','utf8');
it.each(Object.keys(texts))('database deployment projection matches actual registry formatter %s',code=>{
 const projected=JSON.parse(migration.split('$registry$')[1]);const d=getNotificationTypeDefinition(code);
 expect(projected[code]).toEqual({title:d.titleFormatter({}),body:d.bodyFormatter({})});expect(d.targetEntityType).toBe('team');expect(d.recipientResolution.strategy).toBe('AFFECTED_MEMBERSHIP_USER');
});
it('contains only approved membership types and no source-content formatter inputs',()=>{
 expect(Object.keys(texts)).toEqual(['MEMBER_ADDED','MEMBER_REMOVED','MEMBER_MOVED']);
 for(const code of Object.keys(texts))expect(()=>getNotificationTypeDefinition(code).bodyFormatter({privateContent:'hidden'} as never)).toThrow();
});
