import {beforeEach,describe,it,expect,vi} from "vitest";
import {createMindMapSchema} from "@/features/mind-map/create-schema";
const id="00000000-0000-4000-8000-000000000001";
const other="00000000-0000-4000-8000-000000000002";
const input={activityInstanceId:id,idempotencyKey:"initialize"};
const auth=vi.hoisted(()=>vi.fn());
const rpc=vi.hoisted(()=>vi.fn());
vi.mock("server-only",()=>({}));
vi.mock("@/lib/auth/authorization",async original=>({...await original<object>(),getAuthorizationContext:auth}));
vi.mock("@/lib/db/server",()=>({createServerSupabaseClient:async()=>({rpc})}));
import {createMindMap,MindMapConflictError,MindMapStateError} from "@/features/mind-map/create";
describe("approved M11.8 initialization contract",()=>{
 beforeEach(()=>{vi.resetAllMocks();auth.mockResolvedValue({userId:id});});
 it("normalizes UUID/key and requires bounded nonblank key",()=>{
  expect(createMindMapSchema.parse({...input,idempotencyKey:" initialize "})).toEqual(input);
  for(const patch of [{idempotencyKey:undefined},{idempotencyKey:" "},{idempotencyKey:"x".repeat(201)},{activityInstanceId:"invalid"}])expect(createMindMapSchema.safeParse({...input,...patch}).success).toBe(false);
 });
 it.each(["title","actor","userId","createdBy","projectId","workspaceId","teamId","artifactId","artifactVersionId","rootNodeId","rootType","rootLabel","developmentObjectId","reviewRequired","approvalRequired","status","baseline"])("rejects client %s",async key=>{
  await expect(createMindMap({...input,[key]:id})).rejects.toMatchObject({code:"VALIDATION_ERROR"});expect(rpc).not.toHaveBeenCalled();
 });
 it("requires verified authentication first",async()=>{const {AuthorizationError}=await import("@/lib/auth/authorization");auth.mockRejectedValue(new AuthorizationError("AUTH_REQUIRED"));await expect(createMindMap(input)).rejects.toMatchObject({code:"AUTH_REQUIRED"});expect(rpc).not.toHaveBeenCalled();});
 it("rejects identity change before and after RPC",async()=>{
  auth.mockResolvedValueOnce({userId:id}).mockResolvedValueOnce({userId:other});await expect(createMindMap(input)).rejects.toMatchObject({code:"NOT_FOUND"});expect(rpc).not.toHaveBeenCalled();
  auth.mockResolvedValueOnce({userId:id}).mockResolvedValueOnce({userId:id}).mockResolvedValueOnce({userId:other});rpc.mockResolvedValue({data:{},error:null});await expect(createMindMap(input)).rejects.toMatchObject({code:"NOT_FOUND"});
 });
 it("returns safe conflict and dependency failures",async()=>{rpc.mockResolvedValueOnce({error:{code:"23505",message:"Private"}}).mockResolvedValueOnce({error:{code:"55000",message:"Private"}});await expect(createMindMap(input)).rejects.toBeInstanceOf(MindMapConflictError);await expect(createMindMap(input)).rejects.toBeInstanceOf(MindMapStateError);});
 it("does not reveal inaccessible resources or transport details",async()=>{rpc.mockResolvedValueOnce({error:{code:"42501",message:"Private root"}}).mockRejectedValueOnce(Error("Backend content"));for(let i=0;i<2;i++)await expect(createMindMap(input)).rejects.toMatchObject({code:"NOT_FOUND",message:"Resource unavailable."});});
 it("rejects fabricated or incomplete results",async()=>{rpc.mockResolvedValue({data:{artifact:{id}},error:null});await expect(createMindMap(input)).rejects.toMatchObject({code:"NOT_FOUND"});});
});
