import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {mkdtempSync,readFileSync,writeFileSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {fileURLToPath} from 'node:url';
import {aiAcceptanceUnitFiles,aiAcceptanceDatabaseFlags,assertAiAcceptanceDatabase} from '../tests/support/ai-acceptance.mts';
const root=fileURLToPath(new URL('../',import.meta.url));
const logs=mkdtempSync(join(tmpdir(),'fici-ai-acceptance-'));
console.log('M14.24 acceptance logs: '+logs);
function execute(label,args,timeout){
 const result=spawnSync(process.execPath,args,{cwd:root,encoding:'utf8',windowsHide:true,timeout,maxBuffer:8*1024*1024});
 writeFileSync(join(logs,label+'.stdout.log'),result.stdout??'');writeFileSync(join(logs,label+'.stderr.log'),result.stderr??'');
 assert(!result.error&&result.status===0,label+' failed; see acceptance logs. No matrix PASS is issued.');
 return result.stdout;
}
const reportPath=join(logs,'units.json');
execute('units',['node_modules/vitest/vitest.mjs','run',...aiAcceptanceUnitFiles,'--reporter=json','--outputFile',reportPath],300000);
const report=JSON.parse(readFileSync(reportPath,'utf8'));
assert.equal(report.success,true);assert.equal(report.numPendingTests,0);assert(report.numTotalTests>0);
for(const file of aiAcceptanceUnitFiles){
 const suite=report.testResults.find(row=>row.name.replaceAll('\\','/').endsWith('/'+file));
 assert(suite&&suite.assertionResults.length>0,'Required runtime unit suite missing: '+file);
 assert(suite.assertionResults.every(row=>row.status==='passed'),'Skipped/failed runtime assertion: '+file);
}
console.log('M14.24 runtime/support units PASS ('+report.numTotalTests+' tests; no skips)');
const stdout=execute('database',['scripts/test-db.mjs',...aiAcceptanceDatabaseFlags],process.platform==='win32'?7200000:300000);
const matrix=assertAiAcceptanceDatabase(stdout);
for(const row of matrix)console.log(row.id+' PASS'+(row.blocker?' [BLOCKER]':'')+' — '+row.database);
writeFileSync(join(logs,'matrix.json'),JSON.stringify({units:report.numTotalTests,matrix},null,2));
console.log('M14.24 AT-AI-001..009 overall PASS; all boundary regressions required.');
