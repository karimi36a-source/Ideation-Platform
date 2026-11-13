import {expect,it,vi} from 'vitest';
vi.mock('server-only',()=>({}));
import {matchesAiOutputSchema} from '@/features/ai/output-validation';
import {getAiTaskDefinition} from '@/features/ai/task-registry';
for(const task of ['SCAMPER_ASSISTANCE','GAP_ANALYSIS']){
 const schema:unknown=getAiTaskDefinition(task).outputSchema;
 const fields=(schema as {required:string[]}).required;
 const valid=Object.fromEntries(fields.map(k=>[k,'Human review required']));
 it(`${task} accepts exact registry output`,()=>expect(matchesAiOutputSchema(schema,valid)).toBe(true));
 for(const [label,value] of Object.entries({missing:{},extra:{...valid,unexpected:'secret'},wrongType:{...valid,[fields[0]]:3},nullValue:{...valid,[fields[0]]:null},array:[],text:'{}',wrongTask:{candidate_options:'x'}})){
  it(`${task} rejects ${label}`,()=>expect(matchesAiOutputSchema(schema,value)).toBe(false));
 }
 it(`${task} preserves schema-permitted empty strings without invented rules`,()=>expect(matchesAiOutputSchema(schema,Object.fromEntries(fields.map(k=>[k,''])))).toBe(true));
}
const nested={type:'object',properties:{items:{type:'array',items:{type:'object',properties:{state:{type:'string',enum:['OPEN','CLOSED']},count:{type:'integer'},fixed:{type:'boolean',const:true}},required:['state','count','fixed'],additionalProperties:false}}},required:['items'],additionalProperties:false};
it('validates nested arrays/enums/constants without coercion',()=>{
 expect(matchesAiOutputSchema(nested,{items:[{state:'OPEN',count:1,fixed:true}]})).toBe(true);
 for(const item of [{state:'UNKNOWN',count:1,fixed:true},{state:'OPEN',count:'1',fixed:true},{state:'OPEN',count:1,fixed:false},{state:'OPEN',count:1,fixed:true,extra:1}])expect(matchesAiOutputSchema(nested,{items:[item]})).toBe(false);
});
it('rejects unsupported schema configuration fail closed',()=>expect(matchesAiOutputSchema({type:'object',$ref:'remote'},{})).toBe(false));
