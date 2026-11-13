import {getLiveClassroomJoin} from '@/features/live-classroom/classroom';
export async function POST(request:Request){
 const headers={'Cache-Control':'no-store, private','Pragma':'no-cache','Referrer-Policy':'no-referrer'};
 // Same-origin browser mutation transport; no token in GET, redirects or logs.
 if(request.headers.get('origin')!==new URL(request.url).origin)return Response.json({error:'Live classroom unavailable.'},{status:403,headers});
 try{return Response.json(await getLiveClassroomJoin(await request.json()),{headers});}
 catch{return Response.json({error:'Live classroom unavailable. Check your access or try again.'},{status:403,headers});}
}
