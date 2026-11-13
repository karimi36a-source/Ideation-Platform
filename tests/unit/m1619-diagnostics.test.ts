import {expect,it} from 'vitest';
import {sanitizeDiagnostic} from '../../scripts/m1619-diagnostics.mjs';
it('redacts generated credentials, connection URLs, headers and JWTs before output',()=>{
 const output=sanitizeDiagnostic('fatal migration: test-private-value postgres://user:password@db/test Authorization: Bearer opaque-value eyJhbGciOiJIUzI1NiJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIn0.signature',['test-private-value']);
 expect(output).not.toContain('test-private-value');expect(output).not.toContain('postgres://');expect(output).not.toContain('opaque-value');expect(output).not.toContain('eyJhbGci');expect(output).toContain('fatal migration');
});
it('retains useful startup errors while hiding exact and quoted credentials',()=>{const output=sanitizeDiagnostic('migration failed password="with spaces" JWT_PRIVATE [generated-secret]',['generated-secret']);expect(output).toContain('migration failed');expect(output).not.toContain('with spaces');expect(output).not.toContain('generated-secret');});
