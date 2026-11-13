import {createServer,request} from "node:http";

const port=Number(process.env.FICI_TEST_GATEWAY_PORT??"55440");
const routes=[["/auth/v1",Number(process.env.FICI_TEST_AUTH_PORT??"55441")],["/rest/v1",Number(process.env.FICI_TEST_REST_PORT??"55442")]];

createServer((incoming,response)=>{
 const route=routes.find(([prefix])=>incoming.url?.startsWith(prefix));
 if(!route){response.writeHead(404,{"content-type":"application/json"});response.end('{"message":"Not found"}');return;}
 const [prefix,targetPort]=route;
 const headers={...incoming.headers,host:`127.0.0.1:${targetPort}`};
 if(headers.authorization?.startsWith("Bearer sb_publishable_"))delete headers.authorization;
 const upstream=request({hostname:"127.0.0.1",port:targetPort,path:incoming.url.slice(prefix.length)||"/",method:incoming.method,headers},upstreamResponse=>{
  response.writeHead(upstreamResponse.statusCode??502,{...upstreamResponse.headers,"access-control-allow-origin":incoming.headers.origin??"*","access-control-allow-credentials":"true"});
  upstreamResponse.pipe(response);
 });
 upstream.on("error",()=>{if(!response.headersSent)response.writeHead(502,{"content-type":"application/json"});response.end('{"message":"Unavailable"}');});
 incoming.pipe(upstream);
}).listen(port,"127.0.0.1",()=>process.stdout.write(`FICI test gateway ready on ${port}\n`));
