// M16.19 only: real Auth + PostgREST + PostgreSQL; mock only Daily transport.
import {spawn,spawnSync} from 'node:child_process';
import {existsSync,readdirSync,readFileSync} from 'node:fs';
import {createHmac,randomBytes,randomUUID} from 'node:crypto';
import {createServer} from 'node:net';
import {join,resolve} from 'node:path';
import {sanitizeDiagnostic} from './m1619-diagnostics.mjs';
const root=resolve(import.meta.dirname,'..'),tag='fici-m1619-'+randomUUID();
const docker=process.platform==='win32'&&existsSync('C:/Program Files/Docker/Docker/resources/bin/docker.exe')?'C:/Program Files/Docker/Docker/resources/bin/docker.exe':'docker';
const names={db:tag+'-db',auth:tag+'-auth',rest:tag+'-rest'},children=[];
const password=randomBytes(24).toString('hex'),secret=randomBytes(40).toString('hex');
// Do not inherit configured provider credentials or hosted URLs into test processes.
const cleanEnv=Object.fromEntries(Object.entries(process.env).filter(([key])=>!/(SUPABASE|DAILY|OPENAI|RESEND|LIVEBLOCKS|DATABASE|PGPASSWORD|NODE_OPTIONS|FICI_|AUTH_SITE_URL)/i.test(key)));
function execute(command,args,options={}){return spawnSync(command,args,{cwd:root,windowsHide:true,encoding:'utf8',timeout:180000,maxBuffer:32*1024*1024,env:cleanEnv,...options});}
function checked(label,result){if(result.error||result.status!==0){const error=Error(`${label} failed (exit ${result.status??'unavailable'}); no credential-bearing diagnostics emitted`);error.exitCode=result.status||1;throw error;}return result.stdout;}
const d=(args,options)=>checked('Docker operation',execute(docker,args,options));
const sql=text=>d(['exec','-i','--env','PGOPTIONS=-c statement_timeout=50000',names.db,'psql','-X','-U','postgres','-d','postgres','-v','ON_ERROR_STOP=1','-qAt','-f','-'],{input:text});
const freePort=()=>new Promise((resolve,reject)=>{const server=createServer();server.once('error',reject);server.listen(0,'127.0.0.1',()=>{const port=server.address().port;server.close(()=>resolve(port));});});
const jwt=role=>{const h=Buffer.from(JSON.stringify({alg:'HS256',typ:'JWT'})).toString('base64url'),p=Buffer.from(JSON.stringify({role,iss:'m1619-isolated',exp:Math.floor(Date.now()/1000)+7200})).toString('base64url');return h+'.'+p+'.'+createHmac('sha256',secret).update(h+'.'+p).digest('base64url');};
const diagnosticSecrets=[password,secret,'m1619-test-management-canary',...Object.entries(process.env).filter(([key])=>!key.startsWith('NEXT_PUBLIC_')&&/(SECRET|PASSWORD|TOKEN|API_KEY|DATABASE_URL)/i.test(key)).map(([,value])=>value)];
async function wait(label,url,source){
 const deadline=Date.now()+90000;let last='no response';
 function report(){
  if(typeof source==='string'){
   const state=execute(docker,['inspect','--format','{{.State.Status}} exit={{.State.ExitCode}} oom={{.State.OOMKilled}}',source]);
   console.error(`M16.19 ${label} container: ${sanitizeDiagnostic(state.stdout||'state unavailable',diagnosticSecrets).trim()}`);
   const logs=execute(docker,['logs','--tail','15',source]);
   console.error(sanitizeDiagnostic((logs.stdout||'')+(logs.stderr||''),diagnosticSecrets));
  }else if(source)console.error(sanitizeDiagnostic(source.diagnostics||'No child diagnostics',diagnosticSecrets));
 }
 while(Date.now()<deadline){
  try{const response=await fetch(url,{signal:AbortSignal.timeout(3000)});last=`HTTP ${response.status}`;if(response.ok){console.log(`M16.19 ${label} readiness PASS`);return;}}catch(error){last=/^[A-Z0-9_]+$/.test(error.cause?.code||'')?error.cause.code:'network/timeout';}
  if(source&&typeof source!=='string'&&(source.exitCode!==null||source.spawnFailed)){report();throw Error(`${label} exited before readiness (${last})`);}
  if(typeof source==='string'){const state=execute(docker,['inspect','--format','{{.State.Status}}',source]);if(state.status===0&&['exited','dead'].includes(state.stdout.trim())){report();throw Error(`${label} container stopped before readiness (${last})`);}}
  await new Promise(done=>setTimeout(done,500));
 }
 report();throw Error(`${label} readiness failed (${last}; unchanged 90-second limit)`);
}
function start(args,env){const child=spawn(process.execPath,args,{cwd:root,env:{...cleanEnv,...env},windowsHide:true,stdio:['ignore','pipe','pipe']});children.push(child);child.diagnostics='';const record=data=>{child.diagnostics=(child.diagnostics+sanitizeDiagnostic(data,diagnosticSecrets)).slice(-6000);};child.stdout.on('data',record);child.stderr.on('data',record);child.on('error',()=>{child.spawnFailed=true;});return child;}
function nextLaunchArgs(webPort){
 // One CLI preload only. Next forwards execArgv to workers itself; also setting
 // NODE_OPTIONS would make Next merge the same --require value twice.
 const preload=resolve(root,'scripts','m1619-daily-mock.cjs').replaceAll('\\','/');
 if(!existsSync(preload))throw Error('M16.19 Daily test preload file missing');
 return ['--require',preload,join(root,'node_modules/next/dist/bin/next'),'dev','--hostname','127.0.0.1','--port',String(webPort)];
}
let network=false;
if(process.argv.includes('--preload-smoke')){
 // No Docker/browser/server launch. Exercise the actual launch arguments and
 // Next's installed worker option formatter rather than hand-quoting paths.
 const args=nextLaunchArgs(3100);
 const workerCode=String.raw`const assert=require('node:assert/strict');const u=require('next/dist/server/lib/utils');assert.equal(u.getParsedNodeOptions().require,process.env.FICI_M1619_EXPECTED_PRELOAD);fetch('https://api.daily.co/v1/rooms/fici-'+'a'.repeat(64)).then(r=>r.json()).then(d=>{assert.equal(d.privacy,'private');console.log('M16.19 preload worker inheritance PASS');}).catch(()=>process.exitCode=1);`;
 const probeCode=String.raw`const assert=require('node:assert/strict');const {spawnSync}=require('node:child_process');const u=require('next/dist/server/lib/utils');assert.equal(process.env.NODE_OPTIONS,undefined);assert.equal(process.execArgv.filter(x=>x==='--require').length,1);const parsed=u.getParsedNodeOptions();assert.equal(parsed.require,process.env.FICI_M1619_EXPECTED_PRELOAD);delete parsed.eval;delete parsed.e;const formatted=u.formatNodeOptions(parsed);const r=spawnSync(process.execPath,[...formatted.execArgv,'--eval',process.env.FICI_M1619_WORKER_CODE],{env:{...process.env,NODE_OPTIONS:formatted.nodeOptions},encoding:'utf8'});if(r.status!==0){process.stderr.write(r.stderr);process.exitCode=r.status||1;}else process.stdout.write(r.stdout);`;
 const probe=execute(process.execPath,[...args.slice(0,2),'--eval',probeCode],{env:{...cleanEnv,FICI_M1619_ISOLATED:'1',NEXT_PUBLIC_SUPABASE_URL:'http://127.0.0.1:59999',FICI_M1619_EXPECTED_PRELOAD:args[1],FICI_M1619_WORKER_CODE:workerCode}});
 if(probe.status!==0){console.error('M16.19 preload smoke FAIL');process.exitCode=1;}else{console.log(probe.stdout.trim());console.log('M16.19 single preload argument/path/existence smoke PASS');}
}else try{
 if(d(['info','--format','{{.OSType}}']).trim()!=='linux')throw Error('Docker Linux engine required');
 d(['network','create',tag]);network=true;
 d(['run','-d','--name',names.db,'--network',tag,'--network-alias','db','--tmpfs','/var/lib/postgresql/data:rw','-e','POSTGRES_HOST_AUTH_METHOD=trust','-e','POSTGRES_INITDB_ARGS=--no-locale --encoding=UTF8','postgres:17']);
 let ready=false;for(let i=0;i<120;i++){if(execute(docker,['exec',names.db,'pg_isready','-h','127.0.0.1','-U','postgres']).status===0){ready=true;break;}await new Promise(done=>setTimeout(done,500));}if(!ready)throw Error('PostgreSQL readiness failed');
 sql(`create role anon nologin;create role authenticated nologin;create role service_role nologin bypassrls;create role supabase_auth_admin login superuser password '${password}';create schema auth authorization supabase_auth_admin;grant usage on schema public,auth to anon,authenticated,service_role,supabase_auth_admin;create function auth.uid() returns uuid language sql stable as $$select coalesce(nullif(current_setting('request.jwt.claim.sub',true),''),nullif(current_setting('request.jwt.claims',true),'')::jsonb->>'sub')::uuid$$;`);
 // GoTrue migrations create some types without qualification and later refer
 // to auth.<type>. Match the provider-owned role's schema search path.
 sql('alter role supabase_auth_admin set search_path=auth,public;');
 const authPort=await freePort(),restPort=await freePort(),gatewayPort=await freePort(),webPort=await freePort();
 const base=`http://localhost:${webPort}`,gateway=`http://127.0.0.1:${gatewayPort}`;
 const authEnv={GOTRUE_DB_DRIVER:'postgres',GOTRUE_DB_DATABASE_URL:`postgres://supabase_auth_admin:${password}@db:5432/postgres?sslmode=disable`,GOTRUE_DB_NAMESPACE:'auth',API_EXTERNAL_URL:gateway+'/auth/v1',GOTRUE_SITE_URL:base,GOTRUE_JWT_SECRET:secret,GOTRUE_JWT_EXP:'3600',GOTRUE_JWT_AUD:'authenticated',GOTRUE_JWT_DEFAULT_GROUP_NAME:'authenticated',GOTRUE_JWT_ADMIN_ROLES:'service_role',GOTRUE_API_HOST:'0.0.0.0',GOTRUE_API_PORT:'9999',GOTRUE_MAILER_AUTOCONFIRM:'true',GOTRUE_DISABLE_SIGNUP:'true',GOTRUE_EXTERNAL_EMAIL_ENABLED:'true'};
 d(['run','-d','--name',names.auth,'--network',tag,'-p',`127.0.0.1:${authPort}:9999`,...Object.entries(authEnv).flatMap(([key,value])=>['-e',`${key}=${value}`]),'supabase/gotrue:v2.177.0']);
 await wait('Auth',`http://127.0.0.1:${authPort}/health`,names.auth);
 // GoTrue's historical migration installs the legacy individual-claim GUC
 // reader. Restore the existing repository Auth contract for PostgREST's JSON
 // claims before applying FICI migrations; identities/sessions remain real.
 const uidContract=readFileSync(join(root,'tests/integration/fixtures/auth.sql'),'utf8').match(/create function auth\.uid\(\)[\s\S]*?\$\$;/)?.[0];
 if(!uidContract)throw Error('Existing Auth UID fixture contract missing');
 sql(uidContract.replace('create function','create or replace function'));
 sql("insert into auth.users(id,email) values('00000000-0000-4000-8000-000000000001','a@example.test');");
 for(const file of ['tests/integration/fixtures/realtime.sql','tests/integration/fixtures/storage.sql',...readdirSync(join(root,'supabase/migrations')).filter(f=>f.endsWith('.sql')).sort().map(f=>'supabase/migrations/'+f),'supabase/seed.sql'])sql(readFileSync(join(root,file),'utf8'));
 const fixture=checked('Existing canonical browser fixture',execute(process.execPath,['scripts/mind-map-browser-fixture.mjs']));sql(fixture);
 sql(`begin;insert into auth.users(id,email) values('00000000-0000-4000-8000-000000006009','team-acceptance-6009@example.test');select public.provision_user_profile('00000000-0000-4000-8000-000000006009','active');insert into public.enrollments(cohort_id,user_id,enrollment_role,status) select id,'00000000-0000-4000-8000-000000006009','participant','active' from public.cohorts where name='Unrelated acceptance cohort';update auth.users set instance_id='00000000-0000-0000-0000-000000000000',aud='authenticated',role='authenticated',encrypted_password=crypt('${password}',gen_salt('bf')),email_confirmed_at=clock_timestamp(),raw_app_meta_data='{"provider":"email","providers":["email"]}',raw_user_meta_data='{}',confirmation_token='',recovery_token='',email_change_token_new='',email_change='',phone_change='',phone_change_token='',email_change_token_current='',reauthentication_token='',created_at=coalesce(created_at,clock_timestamp()),updated_at=clock_timestamp() where id between '00000000-0000-4000-8000-000000006001' and '00000000-0000-4000-8000-000000006009';insert into auth.identities(id,provider_id,user_id,identity_data,provider,last_sign_in_at,created_at,updated_at) select id,id::text,id,jsonb_build_object('sub',id::text,'email',email,'email_verified',true),'email',clock_timestamp(),clock_timestamp(),clock_timestamp() from auth.users where id='00000000-0000-4000-8000-000000006009';update public.mind_map_browser_fixture set value=value||jsonb_build_object('cohortId',(select cohort_id from public.activity_instances where id=(select (value#>>'{activity,id}')::uuid from public.mind_map_browser_fixture where key='activity')),'sessionId','00000000-0000-4000-8000-000000950702') where key='scope';commit;`);
 console.log(sql(readFileSync(join(root,'tests/integration/live-team-breakouts.sql'),'utf8')));
 console.log(sql(readFileSync(join(root,'tests/integration/live-activity-metadata.sql'),'utf8')));
 const restEnv={PGRST_DB_URI:'postgres://postgres@db:5432/postgres',PGRST_DB_SCHEMAS:'public',PGRST_DB_ANON_ROLE:'anon',PGRST_JWT_SECRET:secret,PGRST_SERVER_PORT:'3000'};
 d(['run','-d','--name',names.rest,'--network',tag,'-p',`127.0.0.1:${restPort}:3000`,...Object.entries(restEnv).flatMap(([key,value])=>['-e',`${key}=${value}`]),'postgrest/postgrest:v12.2.12']);
 await wait('PostgREST',`http://127.0.0.1:${restPort}/`,names.rest);
 const gatewayChild=start(['scripts/supabase-test-gateway.mjs'],{FICI_TEST_GATEWAY_PORT:String(gatewayPort),FICI_TEST_AUTH_PORT:String(authPort),FICI_TEST_REST_PORT:String(restPort)});await wait('Gateway',gateway+'/auth/v1/health',gatewayChild);
 sql("insert into public.role_assignments(user_id,role_id,organization_id,assigned_by) values('00000000-0000-4000-8000-000000006009','00000000-0000-4000-8000-000000000104','00000000-0000-4000-8000-000000000501','00000000-0000-4000-8000-000000006001');");
 const env={NEXT_PUBLIC_SUPABASE_URL:gateway,NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY:'sb_publishable_m1619_isolated_only',SUPABASE_SECRET_KEY:jwt('service_role'),DAILY_API_KEY:'m1619-test-management-canary',OPENAI_API_KEY:'',RESEND_API_KEY:'',LIVEBLOCKS_SECRET_KEY:'',AUTH_SITE_URL:base,NEXT_TELEMETRY_DISABLED:'1',FICI_M1619_ISOLATED:'1'};
 diagnosticSecrets.push(env.SUPABASE_SECRET_KEY);
 const nextChild=start(nextLaunchArgs(webPort),env);
 // Probe the address actually bound by Next, avoiding localhost IPv6 resolution
 // against an IPv4-only test listener. Browser/auth origin stays unchanged.
 await wait('Next.js',`http://127.0.0.1:${webPort}/login`,nextChild);
 console.log('M16.19 isolated PostgreSQL/Auth/PostgREST environment PASS');
 const child=spawn(process.execPath,['node_modules/@playwright/test/cli.js','test','--config=playwright.live-classroom-auth.config.ts'],{cwd:root,env:{...cleanEnv,...env,FICI_M1619_BASE_URL:base,FICI_M1619_PASSWORD:password,FICI_M1619_CONTAINER:names.db,FICI_M1619_DOCKER:docker,PLAYWRIGHT_NO_COPY_PROMPT:'1'},windowsHide:true,stdio:'inherit'});children.push(child);
 const code=await new Promise((resolve,reject)=>{child.once('error',reject);child.once('exit',resolve);});
 if(code!==0){const error=Error('Authenticated M16.19 browser assertions failed');error.exitCode=code||1;throw error;}
 console.log('M16.19 authenticated Master/Student/My-Team/Team-Portal/breakout/denial/media/Activity/PostgreSQL/rejoin PASS');
}catch(error){process.exitCode=error.exitCode||1;console.error('M16.19 authenticated E2E FAIL: '+error.message);}
finally{
 let cleanup=true;
 for(const child of children.reverse())if(child.exitCode===null){if(process.platform==='win32'){const stopped=execute('taskkill',['/PID',String(child.pid),'/T','/F']);if(stopped.status!==0)cleanup=false;}else child.kill();}
 for(const name of Object.values(names).reverse()){const exists=execute(docker,['container','inspect',name]);if(exists.status===0&&execute(docker,['rm','--force','--volumes',name]).status!==0)cleanup=false;}
 if(network&&execute(docker,['network','rm',tag]).status!==0)cleanup=false;
 console.log('M16.19 cleanup '+(cleanup?'PASS':'WARN'));
}
