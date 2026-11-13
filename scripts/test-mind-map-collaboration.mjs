import {spawnSync} from "node:child_process";
import {writeFileSync,unlinkSync} from "node:fs";
import {join} from "node:path";
import {tmpdir} from "node:os";

export async function testMindMapCollaboration({run,args,binary,childEnv,root}){
 const name="fici_mind_map_collaboration";
 run("psql",[...args,"-c",`create database ${name} template postgres`]);
 const db=args.map((v,i)=>args[i-1]==="-d"?name:v);
 const file=join(tmpdir(),`fici-mind-map-liveblocks-${process.pid}.json`);
 try{
  // Reuse the M11.12 canonical fixture, without the real GoTrue login rows.
  const generated=spawnSync(process.execPath,["scripts/mind-map-browser-fixture.mjs"],{cwd:root,encoding:"utf8",windowsHide:true});
  if(generated.status!==0)throw Error("Mind Map fixture unavailable");
  run("psql",[...db,"-f","-"],generated.stdout.split("update auth.users set")[0]+"commit;");
  const values=run("psql",[...db,"-tA","-c","select jsonb_object_agg(key,value)::text from public.mind_map_browser_fixture"]);
  writeFileSync(file,JSON.stringify({args:db,binary:binary("psql"),values:JSON.parse(values)}));
  const result=spawnSync(process.execPath,["node_modules/vitest/vitest.mjs","run","--config","vitest.liveblocks.config.mts","tests/provider/mind-map-liveblocks.test.ts"],{cwd:root,env:{...childEnv,FICI_MIND_MAP_LIVEBLOCKS_FIXTURE:file},encoding:"utf8",windowsHide:true,timeout:360000});
  if(result.status!==0||result.error){
   process.loadEnvFile(join(root,".env.local"));let diagnostic=(result.stdout??"")+(result.stderr??"");
   const secret=process.env.LIVEBLOCKS_SECRET_KEY;if(secret)diagnostic=diagnostic.split(secret).join("[REDACTED]");
   diagnostic=diagnostic.replace(/eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+/g,"[REDACTED TOKEN]");
   writeFileSync(join(tmpdir(),"fici-mind-map-provider-sanitized.log"),diagnostic);
   throw Error("Mind Map provider verification failed; inspect sanitized diagnostics");
  }
  console.log("M11.13 real-provider private room/two users/isolated events/CAS/reconnect/removal/failure PASS");
  console.log("M11.13 existing issued/open provider session is not immediately revoked; fresh authorization denied");
 }finally{try{unlinkSync(file);}catch{}run("psql",[...args,"-c",`drop database ${name} with (force)`]);}
}
