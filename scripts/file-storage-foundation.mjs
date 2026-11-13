// Local provider infrastructure/privacy test only; not an upload business API.
import {randomUUID} from "node:crypto";
import {existsSync} from "node:fs";
import {join} from "node:path";
import {createClient} from "@supabase/supabase-js";
const bucket="fici-private-files";
for(const name of [".env.local",".env.test.local"]){const file=join(import.meta.dirname,"..",name);if(existsSync(file))process.loadEnvFile(file);}
const endpoint=process.env.FICI_STORAGE_TEST_URL;
const serverKey=process.env.FICI_STORAGE_TEST_SERVICE_ROLE_KEY;
const anonKey=process.env.FICI_STORAGE_TEST_ANON_KEY;
async function main(){
 if(!endpoint||!serverKey)throw Error("Storage provider verification BLOCKED: local test endpoint/service credential not configured");
 const url=new URL(endpoint);
 if(!["http:","https:"].includes(url.protocol)||!["127.0.0.1","localhost","[::1]"].includes(url.hostname)||url.username||url.password||url.search||url.hash||!['','/'].includes(url.pathname))throw Error("Storage foundation is local-only; hosted changes are not authorized");
 const client=createClient(url.origin,serverKey,{auth:{persistSession:false,autoRefreshToken:false}});
 let result=await client.storage.getBucket(bucket);
 if(result.error){await client.storage.createBucket(bucket,{public:false});result=await client.storage.getBucket(bucket);}
 if(result.error||result.data?.id!==bucket||result.data.public!==false)throw Error("Private bucket setup failed or bucket is public");
 console.log("Local private Storage bucket configuration PASS");
 if(process.argv.includes("--setup-only"))return;
 if(!anonKey)throw Error("Storage provider verification BLOCKED: local anonymous test credential not configured");
 const path=`__m126_privacy_tests/${randomUUID()}.txt`;
 const payload=Buffer.from(`M12.6 disposable privacy test ${randomUUID()}`);
 let uploaded=false;
 try{
  const upload=await client.storage.from(bucket).upload(path,payload,{contentType:"text/plain",upsert:false});
  if(upload.error)throw Error("Disposable provider fixture upload failed");uploaded=true;
  const control=await client.storage.from(bucket).download(path);
  if(control.error||!control.data||!Buffer.from(await control.data.arrayBuffer()).equals(payload))throw Error("Provider fixture existence control failed");
  const response=await fetch(`${url.origin}/storage/v1/object/public/${bucket}/${path}`,{signal:AbortSignal.timeout(15000),redirect:"error"});
  const body=Buffer.from(await response.arrayBuffer());
  if(response.ok||body.equals(payload))throw Error("Private object exposed through anonymous public URL");
  const anonymousKeyControl=await fetch(`${url.origin}/auth/v1/settings`,{headers:{apikey:anonKey},signal:AbortSignal.timeout(15000),redirect:"error"});
  if(!anonymousKeyControl.ok)throw Error("Anonymous provider credential control failed");
  const anonymous=createClient(url.origin,anonKey,{auth:{persistSession:false,autoRefreshToken:false}});
  const privateDownload=await anonymous.storage.from(bucket).download(path);
  if(!privateDownload.error||privateDownload.data)throw Error("Private object exposed through anonymous authorized-endpoint access");
  const listing=await anonymous.storage.from(bucket).list("__m126_privacy_tests");
  if(!listing.error&&(!Array.isArray(listing.data)||listing.data.length!==0))throw Error("Private objects exposed through anonymous listing");
  if(/^https?:/i.test(path))throw Error("Storage reference became a URL");
  console.log("M12.6 REAL provider existing-object public URL/listing denial PASS");
 }finally{
  if(uploaded){const cleanup=await client.storage.from(bucket).remove([path]);if(cleanup.error)throw Error("Disposable provider fixture cleanup failed");}
 }
}
main().catch(error=>{console.error(error instanceof Error&&error.message.startsWith("Storage provider verification BLOCKED")?error.message:"Storage provider setup/privacy verification failed; no credential details logged");process.exitCode=2;});
