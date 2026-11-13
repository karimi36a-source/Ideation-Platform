import {describe,expect,it} from 'vitest';
import {shareRuntimePolicyDenial} from '@/features/shares/runtime-policy';
import {sharePermissionLevels} from '@/features/shares/schema';
describe('M13.11 persisted vocabulary never implies runtime capability',()=>{
 it('retains the deferred enum member',()=>expect(sharePermissionLevels).toContain('COLLABORATE'));
 it.each(['VIEW','COMMENT'])('%s remains enabled for SNAPSHOT',permissionLevel=>expect(shareRuntimePolicyDenial({permissionLevel,shareMode:'SNAPSHOT'})).toBeNull());
 it.each(['COLLABORATE','EDIT','ADMIN','collaborate',''])('%s fails closed without fallback',permissionLevel=>expect(shareRuntimePolicyDenial({permissionLevel,shareMode:'SNAPSHOT'})).toBe('PERMISSION_NOT_ALLOWED'));
 it.each(sharePermissionLevels)('LIVE_REFERENCE/%s remains disabled',permissionLevel=>expect(shareRuntimePolicyDenial({permissionLevel,shareMode:'LIVE_REFERENCE'})).toBe('MODE_NOT_ALLOWED'));
});
