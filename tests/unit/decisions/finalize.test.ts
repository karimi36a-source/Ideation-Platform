import {it,expect,vi,beforeEach} from "vitest";
vi.mock("server-only",()=>({}));
const state=vi.hoisted(()=>({rpc:vi.fn(),auth:vi.fn()}));
vi.mock("@/lib/auth/authorization",async original=>({...await original<typeof import("@/lib/auth/authorization")>(),getAuthorizationContext:state.auth}));
vi.mock("@/lib/db/server",()=>({createServerSupabaseClient:async()=>({rpc:state.rpc})}));
import {finalizeDecision} from "@/features/decisions/finalize";
import {finalizeDecisionSchema} from "@/features/decisions/finalize-schema";
const id="bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb",actor="aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa";
const input={decisionId:id,outcome:" Human choice ",reasoning:" Human reasoning "};
const result={id,project_id:id,workspace_id:id,activity_instance_id:null,title:"T",question:"Q",method:"DISCUSSION",status:"FINALIZED",decision_owner_user_id:id,outcome:"Human choice",reasoning:"Human reasoning",decided_at:"2026-10-11T00:00:00Z"};
beforeEach(()=>{state.rpc.mockReset();state.auth.mockReset();state.auth.mockResolvedValue({userId:actor});state.rpc.mockResolvedValue({data:result,error:null});});
it("returns canonical Decision without rewriting different creator",async()=>{expect(await finalizeDecision(input)).toEqual(result);expect(state.rpc).toHaveBeenCalledExactlyOnceWith("finalize_decision",{input:finalizeDecisionSchema.parse(input)});});
it.each(["status","decidedAt","decisionOwnerUserId","finalizerUserId","participants","participantIds","votingSessionId","voteCount","winner","selectedOptionIds","projectId","workspaceId","teamId","role"])("rejects unknown %s",async f=>{await expect(finalizeDecision({...input,[f]:id})).rejects.toMatchObject({code:"VALIDATION_ERROR"});expect(state.rpc).not.toHaveBeenCalled();});
it.each(["outcome","reasoning"])("rejects blank Unicode %s",async f=>{await expect(finalizeDecision({...input,[f]:"\u00a0\ufeff"})).rejects.toMatchObject({code:"VALIDATION_ERROR"});expect(state.rpc).not.toHaveBeenCalled();});
it.each(["linkedArtifactIds","linkedObjectIds"])("rejects normalized duplicate %s",async f=>{await expect(finalizeDecision({...input,[f]:[id,id.toUpperCase()]})).rejects.toMatchObject({code:"VALIDATION_ERROR"});expect(state.rpc).not.toHaveBeenCalled();});
it("passes canonical Evidence IDs to the same atomic finalization RPC",async()=>{expect(await finalizeDecision({...input,linkedEvidenceIds:[id]})).toEqual(result);expect(state.rpc).toHaveBeenCalledExactlyOnceWith("finalize_decision",{input:finalizeDecisionSchema.parse({...input,linkedEvidenceIds:[id]})});});
it("empty Evidence and omitted selection are accepted",async()=>{expect(await finalizeDecision({...input,linkedEvidenceIds:[]})).toEqual(result);});
it.each([["40001","CONFLICT"],["55000","INVALID_STATE"],["0A000","DEPENDENCY_REQUIRED"],["42501","NOT_FOUND"],["23503","NOT_FOUND"],["22023","VALIDATION_ERROR"],["28000","AUTH_REQUIRED"]])("stable safe provider %s",async(code,expected)=>{state.rpc.mockResolvedValue({error:{code,message:"Private details"}});await expect(finalizeDecision(input)).rejects.toMatchObject({code:expected});});
it("anonymous stops before RPC",async()=>{const {AuthorizationError}=await import("@/lib/auth/authorization");state.auth.mockRejectedValue(new AuthorizationError("AUTH_REQUIRED"));await expect(finalizeDecision(input)).rejects.toMatchObject({code:"AUTH_REQUIRED"});expect(state.rpc).not.toHaveBeenCalled();});
it("identity change stops before RPC",async()=>{state.auth.mockResolvedValueOnce({userId:actor}).mockResolvedValue({userId:id});await expect(finalizeDecision(input)).rejects.toMatchObject({code:"NOT_FOUND"});expect(state.rpc).not.toHaveBeenCalled();});
it.each([{status:"DRAFT"},{outcome:"Other"},{reasoning:"Other"},{decided_at:null},{id:actor}])("rejects inconsistent canonical result %j",async patch=>{state.rpc.mockResolvedValue({data:{...result,...patch},error:null});await expect(finalizeDecision(input)).rejects.toMatchObject({code:"NOT_FOUND"});});

it("repeated Evidence IDs remain legal and are normalized by the canonical transaction",async()=>{expect(await finalizeDecision({...input,linkedEvidenceIds:[id,id]})).toEqual(result);expect(state.rpc).toHaveBeenCalledExactlyOnceWith("finalize_decision",{input:finalizeDecisionSchema.parse({...input,linkedEvidenceIds:[id,id]})});});

it.each(['verificationStatus','verifiedBy','verifiedAt','evidenceNotes','evidenceType'])('rejects Evidence mutation override %s',async key=>{await expect(finalizeDecision({...input,linkedEvidenceIds:[id],[key]:'spoof'})).rejects.toMatchObject({code:'VALIDATION_ERROR'});expect(state.rpc).not.toHaveBeenCalled();});
it('rejects embedded Evidence payloads instead of accepting canonical IDs',async()=>{await expect(finalizeDecision({...input,linkedEvidenceIds:[{id,verificationStatus:'VERIFIED'}]})).rejects.toMatchObject({code:'VALIDATION_ERROR'});expect(state.rpc).not.toHaveBeenCalled();});
