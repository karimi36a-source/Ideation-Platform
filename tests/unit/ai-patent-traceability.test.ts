import {expect,it,vi} from 'vitest';
vi.mock('server-only',()=>({}));
import {patentResearchOutputSchema,validatePatentAiResponse} from '@/features/ai/patent-traceability';
import {matchesAiOutputSchema} from '@/features/ai/output-validation';
import {patentTestResponse} from '../support/ai-patent-output';
const input=JSON.stringify([{layer:'AUTHORIZED EVIDENCE',content:{sources:[{reference:'source-001',role:'PATENT',content:{publication_number:'WO 2026/001',abstract_text:'A technical element'}},{reference:'source-002',role:'EVIDENCE',content:{claim_locator:'Claim 4',description:'A source-backed element',verification_status:'VERIFIED',evidence_type:'PATENT_CLAIM'}}]}}]);
const validate=(value:unknown,text:string|null=null)=>matchesAiOutputSchema(patentResearchOutputSchema,value)&&validatePatentAiResponse('PATENT_RESEARCH_ASSISTANCE',value,text,input);
it('four traceability fields and technical-only scope are enforced by the canonical schema',()=>{
 const good=patentTestResponse(input);expect(validate(good)).toBe(true);
 for(const key of ['observation','source_reference','interpretation','uncertainty']){const bad=structuredClone(good);Reflect.deleteProperty(bad.source_observations[0],key);expect(validate(bad)).toBe(false);}
 for(const extra of ['novelty_score','patentability_status','verified','fto_conclusion'])expect(validate({...good,[extra]:'YES'})).toBe(false);
});
it.each(['CLAIM','FIGURE','PARAGRAPH','SECTION'])('absent %s location is never invented',kind=>{const bad=patentTestResponse(input);Object.assign(bad.source_observations[0],{location_kind:kind,location:kind+' 999'});expect(validate(bad)).toBe(false);});
it('numbered citations cannot be smuggled into observation prose or cite another source locator',()=>{
 for(const text of ['Claim 999 describes a mechanism','Figure 42 depicts this element','Paragraph 9 explains this','Section 12 describes this','Claim 4 is in this Patent']){const bad=patentTestResponse(input);bad.source_observations[0].observation=text;expect(validate(bad)).toBe(false);}
});
it('a locator prefix is not an exact source location: Claim 4 is not Claim 40',()=>{
 const sourceInput=input.replace('Claim 4','Claim 40'),bad=patentTestResponse(sourceInput);bad.source_observations[1].observation='Claim 4 describes this element';
 expect(validatePatentAiResponse('PATENT_RESEARCH_ASSISTANCE',bad,null,sourceInput)).toBe(false);
});
it('uses only exact saved source locators or explicit strongest-available unspecified references',()=>{
 const good=patentTestResponse(input);Object.assign(good.source_observations[1],{location_kind:'CLAIM',location:'Claim 4',observation:'Claim 4 describes the element'});expect(validate(good)).toBe(true);
 Object.assign(good.source_observations[0],{location_kind:'ABSTRACT',location:'abstract'});expect(validate(good)).toBe(true);
 good.source_observations[0].source_reference='source-002';expect(validate(good)).toBe(false);
});
it.each(['novel','not novel','patentable','not patentable','patentability','infringes','no infringement risk','freedom to operate','FTO clear','legally protected','ｐａｔｅｎｔａｂｌｅ','no\u200Binfringement'])('rejects non-authoritative boundary violation %s, never strips it',statement=>{
 const bad=patentTestResponse(input);bad.interpretation=statement;const before=JSON.stringify(bad);expect(validate(bad)).toBe(false);expect(JSON.stringify(bad)).toBe(before);
 expect(validate(patentTestResponse(input),statement)).toBe(false);
});
it('high confidence does not verify anything or change canonical technical scope',()=>{const good=patentTestResponse(input);good.uncertainty='High confidence in technical correspondence; human source review remains required';expect(validate(good)).toBe(true);expect(good.assessment_scope).toBe('TECHNICAL_OBSERVATIONS_ONLY');});
it('unknown aliases, incomplete citations, empty observations and substituted scope fail closed',()=>{
 for(const change of [(b:ReturnType<typeof patentTestResponse>)=>{b.source_observations=[];},(b:ReturnType<typeof patentTestResponse>)=>{b.source_observations[0].source_reference='source-999';},(b:ReturnType<typeof patentTestResponse>)=>{b.source_observations[0].uncertainty='';},(b:ReturnType<typeof patentTestResponse>)=>{b.assessment_scope='VERIFIED';}]){const bad=patentTestResponse(input);change(bad);expect(validate(bad)).toBe(false);}
});
it('existing non-patent tasks and exact Session 10 output shape remain unaffected',()=>{
 expect(validatePatentAiResponse('SCAMPER_ASSISTANCE',{technique:'A new arrangement'},null,'[]')).toBe(true);
 const comparison={similarities:'This invention is novel.'};expect(validatePatentAiResponse('COMPARATIVE_ANALYSIS',comparison,null,input)).toBe(false);
 expect(validatePatentAiResponse('SESSION10_GAP_REFINEMENT',{current_state:'Technical observation'},null,input)).toBe(true);
});
