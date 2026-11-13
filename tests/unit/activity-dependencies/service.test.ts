import { beforeEach, expect, it, vi } from "vitest";
vi.mock("server-only", () => ({}));
const { user, assignments, client } = vi.hoisted(() => ({ user: vi.fn(), assignments: vi.fn(), client: vi.fn() }));
vi.mock("@/features/users/service", () => ({ requireActivePlatformUser: user }));
vi.mock("@/features/auth/role-assignments", () => ({ getActiveRoleAssignments: assignments }));
vi.mock("@/lib/db/server", () => ({ createServerSupabaseClient: client }));
import { manageActivityDependency } from "@/features/activity-dependencies/service";
import { dependencyInputSchema, dependencyTypeSchema } from "@/features/activity-dependencies/schema";
import { SYSTEM_ROLE_IDS } from "@/lib/auth/role-codes";

const uuid = (suffix: number) => `00000000-0000-4000-8000-${String(suffix).padStart(12,"0")}`;
const org = uuid(501), programId = uuid(601), versionId = uuid(912), uid = uuid(911);
const activityId = uuid(914), requiredId = uuid(915), dependencyId = uuid(925);
const meta = { created_at: "2026-09-01T00:00:00Z", updated_at: "2026-09-01T00:00:00Z" };
const input = { required_activity_definition_id: requiredId, dependency_type: "completion", required_artifact_type: null, is_mandatory: true };
const rpc = vi.fn();
let status = "draft", requiredVersion = versionId, missingRequired = false;
beforeEach(() => {
  status = "draft"; requiredVersion = versionId; missingRequired = false;
  user.mockReset().mockResolvedValue({ id: uid, account_status: "active" });
  assignments.mockReset().mockResolvedValue([{ id: uuid(926), user_id: uid, role_id: SYSTEM_ROLE_IDS.ADMIN, organization_id: org, program_id: null, cohort_id: null, team_id: null, project_id: null, starts_at: "2020-01-01T00:00:00Z", ends_at: null, status: "active", assigned_by: uid, ...meta }]);
  rpc.mockReset().mockResolvedValue({ data: { id: dependencyId, activity_definition_id: activityId, ...input, ...meta }, error: null });
  client.mockReset().mockResolvedValue({ rpc, from: (table: string) => ({ select: () => ({ eq: (_column: string, id: string) => ({ maybeSingle: async () => {
    let data;
    if (table === "activity_definitions") data = missingRequired && id === requiredId ? null : { id, session_definition_id: id, name: "Fixture", description: null, method_type: "reflection", workspace_mode: null, sequence: 1, instructions: null, ai_role_code: null, requires_review: false, requires_approval: false, completion_rule: null, configuration: {}, status: "active", ...meta };
    else if (table === "session_definitions") data = { id, curriculum_version_id: id === requiredId ? requiredVersion : versionId, session_number: 1, title: "Fixture", description: "", learning_goal: "Fixture", sequence: 1, status: "active", ...meta };
    else if (table === "curriculum_versions") data = { id, program_id: programId, version_label: "Fixture", status, effective_from: null, effective_to: null, notes: "", ...meta };
    else data = { id: programId, organization_id: org, name: "Professional Course", code: "PROFESSIONAL_COURSE", description: "", program_type: "professional_course", status: "active", current_curriculum_version_id: null, current_curriculum_required_status: "approved", ...meta };
    return { data, error: null };
  } }) }) }) });
});
it("exact organization Admin creates a same-version draft prerequisite", async () => {
  expect(await manageActivityDependency(activityId,null,input)).toMatchObject({activity_definition_id:activityId,...input});
  expect(rpc).toHaveBeenCalledWith("manage_activity_dependency", { target_activity: activityId, target_dependency: null, required_activity: requiredId, kind: "completion", artifact_type: null, mandatory: true });
});
it.each(["approved","retired"])("%s definitions cannot reach mutation", async lifecycle => {
  status=lifecycle;await expect(manageActivityDependency(activityId,null,input)).rejects.toMatchObject({code:"FORBIDDEN"});expect(rpc).not.toHaveBeenCalled();
});
it("Student cannot manage prerequisites",async()=>{
  const rows=await assignments();assignments.mockResolvedValue([{...rows[0],role_id:SYSTEM_ROLE_IDS.STUDENT}]);
  await expect(manageActivityDependency(activityId,null,input)).rejects.toMatchObject({code:"FORBIDDEN"});expect(rpc).not.toHaveBeenCalled();
});
it("Admin in unrelated organization cannot manage prerequisites",async()=>{
  const rows=await assignments();assignments.mockResolvedValue([{...rows[0],organization_id:uuid(999)}]);
  await expect(manageActivityDependency(activityId,null,input)).rejects.toMatchObject({code:"FORBIDDEN"});expect(rpc).not.toHaveBeenCalled();
});
it("cross-version prerequisite is denied",async()=>{
  requiredVersion=uuid(916);await expect(manageActivityDependency(activityId,null,input)).rejects.toMatchObject({code:"FORBIDDEN"});expect(rpc).not.toHaveBeenCalled();
});
it("missing/inaccessible prerequisite exposes no resource details",async()=>{
  missingRequired=true;await expect(manageActivityDependency(activityId,null,input)).rejects.toMatchObject({code:"FORBIDDEN",message:"Access denied."});expect(rpc).not.toHaveBeenCalled();
});
it("self dependency and browser identity fields are rejected",async()=>{
  await expect(manageActivityDependency(activityId,null,{...input,required_activity_definition_id:activityId})).rejects.toMatchObject({code:"VALIDATION_ERROR"});
  await expect(manageActivityDependency(activityId,null,{...input,userId:uid,role:"ADMIN"})).rejects.toMatchObject({code:"VALIDATION_ERROR"});expect(rpc).not.toHaveBeenCalled();
});
it("definition vocabulary and explicit mandatory flag are validated",()=>{
  expect(dependencyTypeSchema.options).toEqual(["completion","approved_output","artifact_available","gate_passed"]);
  expect(dependencyInputSchema.safeParse({...input,dependency_type:"invented"}).success).toBe(false);
  const {is_mandatory,...unspecified}=input;expect(is_mandatory).toBe(true);expect(dependencyInputSchema.safeParse(unspecified).success).toBe(false);
  expect(dependencyInputSchema.safeParse({...input,required_artifact_type:""}).success).toBe(false);
});
it("duplicate database failure is stable and hides provider details",async()=>{
  rpc.mockResolvedValue({data:null,error:{code:"23505",message:"Sensitive SQL diagnostics"}});
  await expect(manageActivityDependency(activityId,null,input)).rejects.toMatchObject({code:"VALIDATION_ERROR",message:"Invalid authorization request."});
});
it("mismatched response identity fails closed",async()=>{
  rpc.mockResolvedValue({data:{id:uuid(998),activity_definition_id:activityId,...input,...meta},error:null});
  await expect(manageActivityDependency(activityId,dependencyId,input)).rejects.toMatchObject({code:"FORBIDDEN"});
});
