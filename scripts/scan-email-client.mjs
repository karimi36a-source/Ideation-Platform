// Post-build email boundary scan. Never prints credential values or matched content.
import {existsSync,readdirSync,readFileSync} from 'node:fs';
import {join,resolve,dirname} from 'node:path';
import ts from 'typescript';
const root=resolve(import.meta.dirname,'..');
for(const name of ['.env','.env.local','.env.production','.env.production.local','.env.test.local'])if(existsSync(join(root,name)))process.loadEnvFile(join(root,name));
const secrets=Object.entries(process.env).filter(([key,value])=>!key.startsWith('NEXT_PUBLIC_')&&/(SECRET|SERVICE_ROLE|PASSWORD|TOKEN|API_KEY|DATABASE_URL)/i.test(key)&&value&&value.length>=8).map(([,value])=>value);
const target=join(root,'.next/static');if(!existsSync(target))throw Error('Production client output missing');
let count=0,failed=false;
function walk(dir,visit){for(const entry of readdirSync(dir,{withFileTypes:true})){const file=join(dir,entry.name);if(entry.isDirectory())walk(file,visit);else visit(file);}}
walk(target,file=>{count++;const text=readFileSync(file,'utf8');if(file.endsWith('.map')||secrets.some(secret=>text.includes(secret))||/get_my_learning_progress|getMyLearningProgress|get_revision_status|getMyRevisionStatus|getMasterRevisionStatus|get_pending_review_queue|getPendingReviewQueue|get_master_cohort_overview|getMasterCohortOverview|get_my_current_work_catalog|getMyCurrentWork|scheduleCommittedNotificationEmails|createNotificationEmailDelivery|notification_email_contexts|pilotNotificationEmailPolicy|createNotificationEmailPolicy|createEmailEligibilityPolicy|RESEND_API_KEY|RESEND_FROM_EMAIL|ResendEmailProvider|createEmailProvider|createEmailTemplateRegistry|api\.resend\.com|re_mock_M1514_PRIVATE_CREDENTIAL/i.test(text))failed=true;});
// All implementation modules are guarded by Next's server-only import boundary;
// provider-specific imports are restricted to the server composition root.
walk(join(root,'features'),file=>{if(!/\.[jt]sx?$/.test(file))return;const text=readFileSync(file,'utf8');const email=file.replaceAll('\\','/').includes('/features/email/');if(email&&!text.includes("import 'server-only'"))failed=true;if(!email&&/providers\/resend|api\.resend\.com|from ['"]resend['"]/.test(text))failed=true;});
// Follow local import edges from every client entry point, even modules that are
// not currently reachable from a production route.
const sources=new Map();
for(const folder of ['app','components','features','hooks','lib'])if(existsSync(join(root,folder)))walk(join(root,folder),file=>{if(/\.[jt]sx?$/.test(file))sources.set(file,readFileSync(file,'utf8'));});
function localImport(from,specifier){
 const base=specifier.startsWith('@/')?join(root,specifier.slice(2)):specifier.startsWith('.')?resolve(dirname(from),specifier):null;
 if(!base)return null;
 return [base,...['.ts','.tsx','.js','.jsx','/index.ts','/index.tsx'].map(ext=>base+ext)].find(file=>sources.has(file));
}
const visited=new Set();
function visit(file){
 if(visited.has(file))return;visited.add(file);
 // Next compiles module-level Server Action imports into client RPC stubs;
 // their implementation imports remain server-side. Bundle scans above still
 // reject implementation markers/credentials if the compiler ever exposes them.
 if(/^\s*['"]use server['"]/.test(sources.get(file)))return;
 if(/\/features\/progress\/(?:current-work|master-cohort-overview|pending-review|revision-status|learning-progress)\.ts$/.test(file.replaceAll('\\','/'))||file.replaceAll('\\','/').includes('/features/email/')||/\/features\/notifications\/email-(?:policy(?:-config)?|delivery|template)\.ts$/.test(file.replaceAll('\\','/')))failed=true;
 for(const imported of ts.preProcessFile(sources.get(file),true,true).importedFiles){const next=localImport(file,imported.fileName);if(next)visit(next);}
}
for(const [file,text] of sources)if(/^\s*['"]use client['"]/.test(text))visit(file);
console.log(`Email provider/client credential, server-module and source-map scan: ${failed?'FAIL':'PASS'} (${count} files)`);process.exitCode=failed?1:0;



