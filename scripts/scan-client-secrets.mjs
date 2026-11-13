import {existsSync,readdirSync,readFileSync} from "node:fs";
import {join,resolve} from "node:path";
const root=resolve(import.meta.dirname,"..");
for(const name of ['.env.local','.env.test.local'])if(existsSync(join(root,name)))process.loadEnvFile(join(root,name));
const values=Object.entries(process.env).filter(([key,value])=>!key.startsWith('NEXT_PUBLIC_')&&/(SECRET|SERVICE_ROLE|DATABASE|PASSWORD|ACCESS_TOKEN)/i.test(key)&&value&&value.length>=8).map(([,value])=>value);
if(!process.env.LIVEBLOCKS_SECRET_KEY)throw new Error('Liveblocks secret configuration unavailable for scan.');
const target=join(root,'.next/static');if(!existsSync(target))throw new Error('Fresh client output missing.');
let fail=false,count=0;
function inspect(dir){for(const item of readdirSync(dir,{withFileTypes:true})){const file=join(dir,item.name);if(item.isDirectory())inspect(file);else if(/\.(js|json|map|html|txt)$/.test(item.name)){count++;const source=readFileSync(file,'utf8');if(values.some(value=>source.includes(value))||/postgres(?:ql)?:\/\/[^\s"']+:[^\s"']+@/i.test(source))fail=true;for(const token of source.matchAll(/eyJ[A-Za-z0-9_-]+\.([A-Za-z0-9_-]+)\.[A-Za-z0-9_-]+/g)){try{if(JSON.parse(Buffer.from(token[1],'base64url').toString()).role==='service_role')fail=true;}catch{}}}}}
inspect(target);console.log(`Client secret scan ${fail?'FAIL':'PASS'} (${count} files; includes configured Liveblocks server secret)`);process.exitCode=fail?1:0;
