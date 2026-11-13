import "server-only";
import {AuthorizationError,getAuthorizationContext} from "@/lib/auth/authorization";
import {createServerSupabaseClient} from "@/lib/db/server";
import {createProblemStormingProblemSchema,problemStormingProblemSchema,type ProblemStormingProblem} from "./schema";
export class ProblemStormingError extends Error {
 constructor(readonly code:"DEPENDENCY_NOT_MET"|"CONFLICT"|"INVALID_STATE"){super(code==="DEPENDENCY_NOT_MET"?"Required Activity input unavailable.":code==="CONFLICT"?"Activity input integrity conflict.":"Activity not writable.");this.name="ProblemStormingError";}
}
export async function createProblemStormingProblem(input:unknown):Promise<ProblemStormingProblem>{
 try{
  const actor=await getAuthorizationContext();const parsed=createProblemStormingProblemSchema.safeParse(input);
  if(!parsed.success)throw new AuthorizationError("VALIDATION_ERROR");
  const v=parsed.data;const db=await createServerSupabaseClient();
  if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError("NOT_FOUND");
  const {data,error}=await db.rpc("create_problem_storming_problem",{target_instance:v.activityInstanceId,problem_content:v.content,category:v.problemCategory,problem_perspective:v.perspective??null});
  if((await getAuthorizationContext()).userId!==actor.userId)throw new AuthorizationError("NOT_FOUND");
  if(error){if(error.code==="0A000")throw new ProblemStormingError("DEPENDENCY_NOT_MET");if(error.code==="23505")throw new ProblemStormingError("CONFLICT");if(error.code==="55000")throw new ProblemStormingError("INVALID_STATE");throw new AuthorizationError(error.code==="28000"?"AUTH_REQUIRED":error.code==="22023"?"VALIDATION_ERROR":"NOT_FOUND");}
  const result=problemStormingProblemSchema.safeParse(data);
  if(!result.success)throw new AuthorizationError("NOT_FOUND");
  const o=result.data;
  if(o.object_type!=="PROBLEM"||o.created_by!==actor.userId||o.content!==v.content||o.origin_type!=="PROBLEM_STORMING"||o.origin_reference_id!==v.activityInstanceId||o.archived_at!==null||o.status!==null||o.verification_status!==null||o.current_version_number!==1||o.problem_details.development_object_id!==o.id||o.problem_details.problem_category!==v.problemCategory||o.problem_details.perspective!==(v.perspective??null)||o.problem_details.priority!==null)throw new AuthorizationError("NOT_FOUND");
  return o;
 }catch(error){if(error instanceof ProblemStormingError)throw new ProblemStormingError(error.code);throw new AuthorizationError(error instanceof AuthorizationError&&["AUTH_REQUIRED","VALIDATION_ERROR"].includes(error.code)?error.code:"NOT_FOUND");}
}
