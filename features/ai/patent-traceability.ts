import 'server-only';

const text={type:'string'};
const observation={type:'object',properties:{observation:text,source_reference:text,interpretation:text,uncertainty:text,location_kind:{type:'string',enum:['UNSPECIFIED','CLAIM','ABSTRACT','DESCRIPTION','FIGURE','PARAGRAPH','SECTION']},location:text},required:['observation','source_reference','interpretation','uncertainty','location_kind','location'],additionalProperties:false};
/** The ordinary Patent Research task, not a second analysis engine. */
export const patentResearchOutputSchema={type:'object',properties:{search_terms:text,source_observations:{type:'array',items:observation},interpretation:text,uncertainty:text,verification_needed:text,assessment_scope:{type:'string',const:'TECHNICAL_OBSERVATIONS_ONLY'}},required:['search_terms','source_observations','interpretation','uncertainty','verification_needed','assessment_scope'],additionalProperties:false};
type Source={reference:string;role:string;content:Record<string,unknown>};
function sources(input:string):Source[]{
 const layers=JSON.parse(input) as {layer:string;content:{sources?:Source[]}}[];
 if(!Array.isArray(layers))throw Error('Invalid source envelope');
 const result=layers.find(layer=>layer.layer==='AUTHORIZED EVIDENCE')?.content.sources??[];
 if(!Array.isArray(result)||result.some(s=>!s||typeof s.reference!=='string'||typeof s.role!=='string'||!s.content||typeof s.content!=='object'||Array.isArray(s.content)))throw Error('Invalid sources');
 return result;
}
// Conservative rejection, never phrase stripping or a legal decision engine.
// Closed technical-only schema and grounded citations are separate requirements.
// Even a disclaimer containing these terms is rejected rather than guessed safe.
function prohibited(value:unknown):boolean{
 const normalized=JSON.stringify(value??null).normalize('NFKC').toLowerCase();
 return [normalized.replace(/[\u200B-\u200D\uFEFF]/g,''),normalized.replace(/[\u200B-\u200D\uFEFF]/g,' ')].some(text=>/\bnovel(?:ty)?\b|\bpatentab(?:le|ility)\b|\binfring(?:e[sd]?|ement)\b|\bfto\b|freedom[\s_-]+to[\s_-]+operate|legally[\s_-]+protected/.test(text));
}
function groundedLocators(value:unknown,selected:Source[]):boolean{
 const locators=(v:unknown)=>JSON.stringify(v).normalize('NFKC').toLowerCase().match(/\b(?:claim|figure|fig\.?|paragraph|section)\s*(?:#\s*)?\d+(?:[.:-]\d+)*/g)??[];
 const material=new Set(selected.flatMap(s=>locators(s.content)));
 return locators(value).every(locator=>material.has(locator));
}
/** Validate only against the exact minimized request already authorized by the
 * Context Builder. Aliases and quoted locators are not source-access tokens. */
export function validatePatentAiResponse(taskType:string,structured:unknown,transportText:string|null,input:string):boolean{
 let selected:Source[]=[];
 try{selected=sources(input);}catch{return taskType!=='PATENT_RESEARCH_ASSISTANCE';}
 const patentTask=taskType==='PATENT_RESEARCH_ASSISTANCE'||selected.some(s=>s.role==='PATENT'||(s.role==='EVIDENCE'&&['PATENT','PATENT_CLAIM'].includes(String(s.content.evidence_type))));
 if(!patentTask)return true;
 if(prohibited(structured)||prohibited(transportText))return false;
 if(taskType!=='PATENT_RESEARCH_ASSISTANCE')return true;
 if(!groundedLocators(structured,selected))return false;
 if(!structured||typeof structured!=='object')return false;
 const result=structured as Record<string,unknown>,rows=result.source_observations;
 if(result.assessment_scope!=='TECHNICAL_OBSERVATIONS_ONLY'||!Array.isArray(rows)||rows.length>64)return false;
 const used=new Set<string>();
 for(const row of rows){
  if(!row||typeof row!=='object')return false;
  const r=row as Record<string,unknown>,source=selected.find(s=>s.reference===r.source_reference);
  if(!source||!['PATENT','EVIDENCE'].includes(source.role)||['observation','interpretation','uncertainty'].some(k=>typeof r[k]!=='string'||!String(r[k]).trim()||String(r[k]).length>12000))return false;
  if(!groundedLocators(r,[source]))return false;
  if(r.location_kind==='UNSPECIFIED'){if(r.location!=='')return false;}
  else if(r.location_kind==='ABSTRACT'){if(r.location!=='abstract'||typeof source.content.abstract_text!=='string'||!source.content.abstract_text.trim())return false;}
  else if(r.location_kind==='DESCRIPTION'){if(r.location!=='description'||typeof source.content.description!=='string'||!source.content.description.trim())return false;}
  else {
   // Existing canonical Evidence claim_locator is the only explicit numbered
   // locator currently projected. Never infer a figure/paragraph from a model.
   if(r.location_kind!=='CLAIM'||typeof source.content.claim_locator!=='string'||r.location!==source.content.claim_locator||!r.location.trim())return false;
  }
  used.add(source.reference);
 }
 return selected.filter(s=>s.role==='PATENT'||s.role==='EVIDENCE').every(s=>used.has(s.reference));
}
