import {NextResponse} from "next/server";
import {AuthorizationError} from "@/lib/auth/authorization";
import {authorizeMindMapCollaboration,MindMapProviderUnavailableError} from "@/features/mind-map/collaboration";
export const dynamic="force-dynamic";
export async function POST(request:Request){
 const headers={"Cache-Control":"private, no-store"};
 try{return NextResponse.json({ok:true,data:await authorizeMindMapCollaboration(await request.json())},{headers});}
 catch(error){
  const code=error instanceof MindMapProviderUnavailableError?"DEPENDENCY_NOT_READY":error instanceof SyntaxError?"VALIDATION_ERROR":error instanceof AuthorizationError&&["AUTH_REQUIRED","VALIDATION_ERROR"].includes(error.code)?error.code:"NOT_FOUND";
  const message=code==="DEPENDENCY_NOT_READY"?"Collaboration provider unavailable.":new AuthorizationError(code as "AUTH_REQUIRED"|"VALIDATION_ERROR"|"NOT_FOUND").message;
  return NextResponse.json({ok:false,error:{code,message}},{headers,status:code==="DEPENDENCY_NOT_READY"?503:code==="AUTH_REQUIRED"?401:code==="VALIDATION_ERROR"?400:404});
 }
}
