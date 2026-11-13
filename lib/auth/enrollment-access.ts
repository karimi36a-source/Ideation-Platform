import "server-only";
import {z} from "zod";
import {createServerSupabaseClient} from "@/lib/db/server";
import {AuthorizationError,getAuthorizationContext} from "./authorization";
/** Read-only enrollment access never supplies a platform role or caller identity. */
export async function requireEnrollmentRead(cohortId:unknown){
 const before=await getAuthorizationContext();const id=z.uuid().safeParse(cohortId);if(!id.success)throw new AuthorizationError("VALIDATION_ERROR");
 const client=await createServerSupabaseClient();const allowed=await client.rpc("has_enrollment_read_access",{scope_id:id.data});
 if(allowed.error||allowed.data!==true)throw new AuthorizationError("FORBIDDEN");
 const after=await getAuthorizationContext();if(after.userId!==before.userId)throw new AuthorizationError("FORBIDDEN");
 const fresh=await client.rpc("has_enrollment_read_access",{scope_id:id.data});if(fresh.error||fresh.data!==true)throw new AuthorizationError("FORBIDDEN");return id.data;
}
