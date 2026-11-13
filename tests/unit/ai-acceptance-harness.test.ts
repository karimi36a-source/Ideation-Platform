import {expect,it} from 'vitest';
import {aiAcceptanceCases,assertAiAcceptanceDatabase} from '../support/ai-acceptance.mjs';
it('requires exactly the approved acceptance cases and BLOCKER classifications',()=>{
 expect(aiAcceptanceCases.map(row=>row.id)).toEqual(Array.from({length:9},(_,i)=>'AT-AI-00'+(i+1)));
 expect(aiAcceptanceCases.filter(row=>row.blocker).map(row=>row.id)).toEqual(['AT-AI-002','AT-AI-003','AT-AI-004','AT-AI-006','AT-AI-007']);
});
it.each(aiAcceptanceCases)('missing $id runtime/database proof fails overall acceptance',target=>{
 const incomplete=aiAcceptanceCases.filter(row=>row.id!==target.id).map(row=>row.marker).join('\n');
 expect(()=>assertAiAcceptanceDatabase(incomplete)).toThrow(target.id+(target.blocker?' BLOCKER':''));
});
