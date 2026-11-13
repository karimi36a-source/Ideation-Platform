import "server-only";
import { createServerSupabaseClient } from "@/lib/db/server";
import { AuthorizationError, defineScopedRolePolicy, requireAdminScope } from "@/lib/auth/authorization";
import { organizationSchema, organizationUpdateSchema, type Organization } from "./schema";
const organizationAdminPolicy = defineScopedRolePolicy({role:"ADMIN",scopeType:"organization",access:"operational"}, async id => {
 const client = await createServerSupabaseClient();
 const {data,error} = await client.from("organizations").select("*").eq("id",id).maybeSingle();
 const parsed=organizationSchema.safeParse(data);
 if(error || !parsed.success || parsed.data.id !== id) return null;
 return {id,scope:{type:"organization",id},access:"operational",resourcePolicyAllows:true};
});
/** Rename/lifecycle only. Identity and scope never come from submitted profile claims. */
export async function updateOrganization(organizationId: unknown,input: unknown): Promise<Organization> {
 const authorized=await requireAdminScope(organizationAdminPolicy,organizationId);
 const parsed=organizationUpdateSchema.safeParse(input);
 if(!parsed.success) throw new AuthorizationError("VALIDATION_ERROR");
 const client=await createServerSupabaseClient();
 const {data,error}=await client.rpc("update_organization",{organization_id:authorized.resource.id,new_name:parsed.data.name,new_status:parsed.data.status});
 if(error) throw new AuthorizationError(error.code === "22023" ? "VALIDATION_ERROR" : "FORBIDDEN");
 const result=organizationSchema.safeParse(data);
 if(!result.success || result.data.id !== authorized.resource.id) throw new AuthorizationError("FORBIDDEN");
 return result.data;
}
