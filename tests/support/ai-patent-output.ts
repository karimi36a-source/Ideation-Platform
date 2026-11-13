/** Synthetic provider response only; never performs source retrieval. */
export function patentTestResponse(input:string){
 let sources:{reference:string;role:string}[]=[];
 try{sources=JSON.parse(input).find((l:{layer:string})=>l.layer==='AUTHORIZED EVIDENCE')?.content.sources??[];}catch{/* Isolated runtime fixtures have no sources. */}
 return {search_terms:'Human-selected technical terms',source_observations:sources.filter(s=>['PATENT','EVIDENCE'].includes(s.role)).map(s=>({observation:'Recorded source describes a technical element',source_reference:s.reference,interpretation:'Possible technical correspondence requiring human review',uncertainty:'Exact source location unavailable; verify original source',location_kind:'UNSPECIFIED',location:''})),interpretation:'Tentative technical interpretation',uncertainty:'Source support is incomplete',verification_needed:'Human source review required',assessment_scope:'TECHNICAL_OBSERVATIONS_ONLY'};
}
