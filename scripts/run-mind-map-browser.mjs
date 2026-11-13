import {spawn,spawnSync} from "node:child_process";
import {join} from "node:path";

const root=process.cwd();
const runtime=join(process.env.LOCALAPPDATA,"Temp","fici-m1112-runtime");
const psql="C:\\Program Files\\PostgreSQL\\17\\bin\\psql.exe";
const jwtSecret="m1112-local-jwt-secret-at-least-thirty-two-chars";
const anonKey="sb_publishable_m1112_local_browser_only";
let databasePassword;
for(const candidate of ["postgres","root","password"]){
 const check=spawnSync(psql,["-w","-X","-h","127.0.0.1","-p","5432","-U","postgres","-d","fici_m1112_browser","-tAc","select 1"],{env:{...process.env,PGPASSWORD:candidate},stdio:"ignore",windowsHide:true});
 if(check.status===0){databasePassword=candidate;break;}
}
if(!databasePassword)throw new Error("Disposable browser database is unavailable");

const children=[];
const start=(name,command,args,env={})=>{
 const child=spawn(command,args,{cwd:root,env:{...process.env,...env},stdio:["ignore","pipe","pipe"],windowsHide:true});
 child.stdout.on("data",data=>process.stdout.write(`[${name}] ${data}`));
 child.stderr.on("data",data=>process.stderr.write(`[${name}] ${data}`));
 children.push(child);return child;
};
const waitFor=async url=>{for(let attempt=0;attempt<180;attempt++){try{const response=await fetch(url);if(response.status<500)return;}catch{}await new Promise(resolve=>setTimeout(resolve,500));}throw new Error(`Timed out waiting for ${url}`);};
const stop=child=>{if(child.exitCode===null)child.kill();};

try{
 start("auth",join(runtime,"auth.exe"),["serve"],{
  GOTRUE_DB_DRIVER:"postgres",DB_NAMESPACE:"auth",DATABASE_URL:"postgres://supabase_auth_admin:m1112-local-auth-only@127.0.0.1:5432/fici_m1112_browser?sslmode=disable",
  API_EXTERNAL_URL:"http://127.0.0.1:55440/auth/v1",GOTRUE_SITE_URL:"http://127.0.0.1:3101",GOTRUE_URI_ALLOW_LIST:"http://127.0.0.1:3101/**",
  GOTRUE_JWT_SECRET:jwtSecret,GOTRUE_JWT_EXP:"3600",GOTRUE_JWT_AUD:"authenticated",GOTRUE_JWT_DEFAULT_GROUP_NAME:"authenticated",
  GOTRUE_API_HOST:"127.0.0.1",GOTRUE_API_MAX_REQUEST_DURATION:"60s",PORT:"55441",GOTRUE_MAILER_AUTOCONFIRM:"true",GOTRUE_DISABLE_SIGNUP:"true",
 });
 start("rest",join(runtime,"postgrest","postgrest.exe"),[],{
  PGRST_DB_URI:`postgres://postgres:${databasePassword}@127.0.0.1:5432/fici_m1112_browser`,PGRST_DB_SCHEMAS:"public",PGRST_DB_ANON_ROLE:"anon",
  PGRST_JWT_SECRET:jwtSecret,PGRST_SERVER_HOST:"127.0.0.1",PGRST_SERVER_PORT:"55442",PATH:`C:\\Program Files\\PostgreSQL\\17\\bin;${process.env.PATH}`,
 });
 start("gateway","node",["scripts/supabase-test-gateway.mjs"],{FICI_TEST_GATEWAY_PORT:"55440",FICI_TEST_AUTH_PORT:"55441",FICI_TEST_REST_PORT:"55442"});
 start("next","node",["node_modules/next/dist/bin/next","dev","--hostname","127.0.0.1","--port","3101"],{
  NEXT_PUBLIC_SUPABASE_URL:"http://127.0.0.1:55440",NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY:anonKey,NEXT_TELEMETRY_DISABLED:"1",AUTH_SITE_URL:"http://127.0.0.1:3101",
 });
 await waitFor("http://127.0.0.1:3101/login");
 const testArgs=["node_modules/@playwright/test/cli.js","test","--config=playwright.mind-map.config.ts"];
 if(process.env.FICI_MIND_MAP_GREP)testArgs.push("--grep",process.env.FICI_MIND_MAP_GREP);
 const test=spawn(process.execPath,testArgs,{cwd:root,env:{...process.env,
  NEXT_PUBLIC_SUPABASE_URL:"http://127.0.0.1:55440",NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY:anonKey,FICI_MIND_MAP_BASE_URL:"http://127.0.0.1:3101",
  FICI_MIND_MAP_DB_PASSWORD:databasePassword,FICI_MIND_MAP_USER_PASSWORD:"M11.12-browser-password!",PLAYWRIGHT_BROWSERS_PATH:join(process.env.LOCALAPPDATA,"Temp","fici-playwright"),
 },stdio:"inherit",windowsHide:true});
 const status=await new Promise((resolve,reject)=>{test.once("error",reject);test.once("exit",resolve);});
 if(status!==0)process.exitCode=Number(status)||1;
}finally{for(const child of children.reverse())stop(child);}
