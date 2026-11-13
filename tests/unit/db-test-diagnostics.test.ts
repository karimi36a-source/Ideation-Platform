import { spawnSync } from "node:child_process";
import { expect, it } from "vitest";

it("reports command and helper outcomes without SQL, arguments or environment values", () => {
  const moduleUrl = new URL("../../scripts/db-test-diagnostics.mjs", import.meta.url).href;
  const script = `
    import {command,suite} from ${JSON.stringify(moduleUrl)};
    import {spawn} from 'node:child_process';
    const secret='PRIVATE_DIAGNOSTIC_PROBE';
    const result={status:0,pid:123,signal:null};
    if(command('psql',['-c',secret],()=>result)!==result)throw Error('Changed result');
    suite('sync-fixture','fixture.sql',()=>42);
    await suite('async-fixture','fixture.mjs',async()=>42);
    try{suite('failed-fixture','fixture.mjs',()=>{throw Error(secret);});}catch{}
    command('psql',['-f','-'],()=>({status:null,error:{code:'ETIMEDOUT'},signal:'SIGTERM'}));
    await new Promise((resolve,reject)=>{
      const child=spawn(process.execPath,['-e','process.exit(0)',secret],{env:{...process.env,DIAGNOSTIC_SECRET:secret}});
      child.on('error',reject);child.on('close',code=>code===0?resolve():reject(Error('Child failed')));
    });
  `;
  const result = spawnSync(process.execPath, ["--input-type=module", "-e", script], { encoding: "utf8", windowsHide: true });
  expect(result.status).toBe(0);
  expect(result.stderr).toContain("[DB-TEST START]");
  expect(result.stderr).toContain("[DB-TEST PASS]");
  expect(result.stderr).toContain("[DB-TEST FAIL]");
  expect(result.stderr).toContain("[DB-PROCESS START]");
  expect(result.stderr).toContain("error=ETIMEDOUT");
  expect(result.stderr).toContain("signal=SIGTERM");
  expect(result.stderr).toContain("cumulative=");
  expect(result.stderr).not.toContain("PRIVATE_DIAGNOSTIC_PROBE");
});
