import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {mkdtempSync,readFileSync,writeFileSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {fileURLToPath} from 'node:url';
const root=fileURLToPath(new URL('../',import.meta.url));
const logs=mkdtempSync(join(tmpdir(),'fici-ai-leakage-'));
console.log('M14.25 penetration logs: '+logs);
function run(label,args,timeout){
 const result=spawnSync(process.execPath,args,{cwd:root,encoding:'utf8',windowsHide:true,timeout,maxBuffer:8*1024*1024});
 writeFileSync(join(logs,label+'.stdout.log'),result.stdout??'');writeFileSync(join(logs,label+'.stderr.log'),result.stderr??'');
 assert(!result.error&&result.status===0,label+' failed; no penetration PASS issued. See logs.');
 return result.stdout;
}
const reportPath=join(logs,'penetration.json');
run('penetration',['node_modules/vitest/vitest.mjs','run','tests/unit/ai-leakage.test.ts','--reporter=json','--outputFile',reportPath],300000);
const report=JSON.parse(readFileSync(reportPath,'utf8'));
assert.equal(report.success,true);assert.equal(report.numPendingTests,0);
const tests=report.testResults.flatMap(suite=>suite.assertionResults);
assert(tests.length>0&&tests.every(test=>test.status==='passed'),'No skipped/failed penetration assertions permitted');
for(const id of ['AT-AI-LEAK-001','AT-AI-LEAK-002','AT-AI-LEAK-003'])assert(tests.some(test=>test.fullName.includes(id)&&test.fullName.includes('[BLOCKER]')),'Missing BLOCKER scenario: '+id);
// Reuse ALL accepted runtime/DB/RLS fixtures, including real PostgreSQL source
// authority, revocation, removal, Brainstorm privacy and persistence rollback.
const acceptance=run('acceptance',['scripts/test-ai-acceptance.mjs'],process.platform==='win32'?7200000:300000);
assert(acceptance.includes('M14.24 AT-AI-001..009 overall PASS; all boundary regressions required.'));
console.log(acceptance.trim());
console.log('AT-AI-LEAK-001 PASS [BLOCKER]\nAT-AI-LEAK-002 PASS [BLOCKER]\nAT-AI-LEAK-003 PASS [BLOCKER]');
console.log('M14.25 direct-ID/injection/provider-preflight/persistence isolation PASS ('+tests.length+' penetration assertions; no skips)');
