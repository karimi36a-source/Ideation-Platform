// Test-process preload only; never imported by application or client code.
if(process.env.FICI_M1619_ISOLATED!=='1'||!/^http:\/\/127\.0\.0\.1:\d+$/.test(process.env.NEXT_PUBLIC_SUPABASE_URL||''))throw Error('Isolated M16.19 test context required');
const original=globalThis.fetch;
globalThis.fetch=async function(input,options){
 const url=new URL(typeof input==='string'?input:input instanceof URL?input.href:input.url);
 if(url.origin!=='https://api.daily.co')return original(input,options);
 const name=url.pathname.startsWith('/v1/rooms/')?decodeURIComponent(url.pathname.slice('/v1/rooms/'.length)):options?.body?JSON.parse(options.body).name:null;
 if(url.pathname==='/v1/meeting-tokens')return Response.json({token:'m1619.'+globalThis.crypto.randomUUID()});
 if(!/^fici-[a-f0-9]{64}$/.test(name||''))return Response.json({},{status:400});
 return Response.json({name,privacy:'private',url:'https://m1619.daily.co/'+name});
};
