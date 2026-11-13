// Run only after a successful production build. Never print credential values.
import {existsSync,readdirSync,readFileSync} from 'node:fs';
import {join,resolve} from 'node:path';
const root=resolve(import.meta.dirname,'..');
for(const name of ['.env','.env.local','.env.production','.env.production.local','.env.test.local'])if(existsSync(join(root,name)))process.loadEnvFile(join(root,name));
const secrets=Object.entries(process.env).filter(([key,value])=>!key.startsWith('NEXT_PUBLIC_')&&/(SECRET|SERVICE_ROLE|PASSWORD|TOKEN|API_KEY|DATABASE_URL)/i.test(key)&&value&&value.length>=8).map(([,value])=>value);
const dir=join(root,'.next/static');if(!existsSync(dir))throw new Error('Production client output missing');
let files=0,failed=false;
function scan(dir){for(const item of readdirSync(dir,{withFileTypes:true})){const p=join(dir,item.name);if(item.isDirectory())scan(p);else{files++;if(item.name.endsWith('.map'))failed=true;const text=readFileSync(p,'utf8');if(secrets.some(value=>text.includes(value))||/api\.openai\.com|OpenAiResponsesProvider|createAiModelProfileResolver|AiModelProfileResolutionError|getAiTaskDefinition|resolveAiTaskRequest|AiTaskRegistryError|applyAiArtifactRevision|apply_ai_artifact_revision|convertAiOutputToCandidate|convert_ai_output_to_candidate|aiConversionTargets|setAiOutputDisposition|set_ai_output_disposition|matchesAiOutputSchema|runAiTask|createAiTaskPersistenceClient|begin_ai_task_operation|save_ai_task_result|record_ai_task_attempt|release_ai_task_operation|assembleAiPrompt|resolveActiveAiPromptTemplate|read_active_ai_prompt_template|FICI methodology:|getActivityAiAvailability|createActivityAiAvailabilityResolver|resolve_activity_ai_configuration|listAiTaskDefinitions|buildAiContext|resolve_ai_context_source|OPENAI_API_KEY|mock-private-credential|openai\/resources|openai\/client/i.test(text))failed=true;}}}
scan(dir);console.log(`AI provider/client credential and source-map scan: ${failed?'FAIL':'PASS'} (${files} files)`);process.exitCode=failed?1:0;









