import 'server-only';
import {aiPromptOutputSchema} from './prompt-template-schema';

/** Interprets only the canonical bounded schema subset; never coerces output or
 * exposes provider values/schema diagnostics. Transport size bounds apply first. */
export function matchesAiOutputSchema(schema:unknown,value:unknown):boolean {
 const parsed=aiPromptOutputSchema.safeParse(schema);
 if(!parsed.success)return false;
 const visit=(s:Record<string,unknown>,v:unknown,depth:number):boolean=>{
  if(depth>12)return false;
  const kind=s.type;
  if(kind==='object'){
   if(v===null||typeof v!=='object'||Array.isArray(v))return false;
   const props=s.properties as Record<string,Record<string,unknown>>;
   const obj=v as Record<string,unknown>;
   return Object.keys(obj).every(k=>Object.hasOwn(props,k))
    &&((s.required??[]) as string[]).every(k=>Object.hasOwn(obj,k))
    &&Object.entries(obj).every(([k,item])=>visit(props[k],item,depth+1));
  }
  if(kind==='array')return Array.isArray(v)&&v.every(item=>visit(s.items as Record<string,unknown>,item,depth+1));
  const valid=kind==='null'?v===null:kind==='integer'?typeof v==='number'&&Number.isSafeInteger(v):kind==='number'?typeof v==='number'&&Number.isFinite(v):typeof v===kind;
  return valid&&(!Object.hasOwn(s,'const')||v===s.const)&&(!Array.isArray(s.enum)||s.enum.includes(v));
 };
 return visit(parsed.data,value,0);
}
