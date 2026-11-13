import {describe,it,expect,vi,beforeEach} from "vitest";
vi.mock('@/features/files/upload-rate-limit',()=>({enforceFileUploadRateLimit:vi.fn().mockResolvedValue(undefined),FileUploadRateLimitError:class extends Error{}}));
import {requestUploadSchema,registerUploadedFileSchema,UPLOAD_MIME_TYPES,MAX_UPLOAD_BYTES} from "@/features/files/upload-schema";
const id="00000000-0000-4000-8000-000000006004";
const input={workspaceId:id,filename:"drawing.pdf",mimeType:"application/pdf",size:1};
describe("approved upload contracts",()=>{
 it.each(UPLOAD_MIME_TYPES)("accepts %s",mimeType=>expect(requestUploadSchema.safeParse({...input,mimeType}).success).toBe(true));
 it.each(["image/svg+xml","text/html","application/javascript","application/zip","application/octet-stream","application/x-msdownload","application/vnd.ms-excel.sheet.macroEnabled.12"])("rejects %s",mimeType=>expect(requestUploadSchema.safeParse({...input,mimeType}).success).toBe(false));
 it.each([1,MAX_UPLOAD_BYTES])("accepts boundary %s",size=>expect(requestUploadSchema.safeParse({...input,size}).success).toBe(true));
 it.each([0,-1,MAX_UPLOAD_BYTES+1,1.5,NaN,Infinity,"1"])("rejects size %s",size=>expect(requestUploadSchema.safeParse({...input,size}).success).toBe(false));
 it.each([""," ","../file","a/b","a\\b","a\u0000b","a\u202eb","..","."," file","file.","ｆile"])("rejects unsafe filename %j",filename=>expect(requestUploadSchema.safeParse({...input,filename}).success).toBe(false));
 it.each(["uploadedBy","storageReference","bucket","fileId","ownerId","expiry","objectPath"])("rejects request spoof %s",key=>expect(requestUploadSchema.safeParse({...input,[key]:id}).success).toBe(false));
 it("accepts only uploadRequestId at registration",()=>expect(registerUploadedFileSchema.parse({uploadRequestId:id})).toEqual({uploadRequestId:id}));
 it.each(["workspaceId","projectId","filename","mimeType","size","storageReference","storagePath","bucket","uploadedBy","fileId","status","createdAt","force"])("rejects registration %s",key=>expect(registerUploadedFileSchema.safeParse({uploadRequestId:id,[key]:id}).success).toBe(false));
});
vi.mock("server-only",()=>({}));
const mocks=vi.hoisted(()=>({auth:vi.fn(),rpc:vi.fn(),sign:vi.fn(),env:vi.fn()}));
vi.mock("@/lib/auth/authorization",async original=>({...await original<typeof import("@/lib/auth/authorization")>(),getAuthorizationContext:mocks.auth}));
vi.mock("@/lib/db/server",()=>({createServerSupabaseClient:async()=>({rpc:mocks.rpc})}));
vi.mock("@/lib/validation/env-server",()=>({getServerEnv:mocks.env}));
vi.mock("@supabase/supabase-js",()=>({createClient:()=>({storage:{getBucket:async()=>({data:{public:false,file_size_limit:null},error:null}),from:()=>({createSignedUploadUrl:mocks.sign})}})}));
import {requestUpload,registerUploadedFile} from "@/features/files/upload";
import {AuthorizationError} from "@/lib/auth/authorization";
describe("server-only upload boundary",()=>{
 beforeEach(()=>{vi.resetAllMocks();mocks.auth.mockResolvedValue({userId:id});mocks.env.mockReturnValue({NEXT_PUBLIC_SUPABASE_URL:"https://example.test",SUPABASE_SECRET_KEY:"test-only"});});
 it("anonymous rejected before signing",async()=>{mocks.auth.mockRejectedValue(new AuthorizationError("AUTH_REQUIRED"));await expect(requestUpload(input)).rejects.toMatchObject({code:"AUTH_REQUIRED"});expect(mocks.rpc).not.toHaveBeenCalled();expect(mocks.sign).not.toHaveBeenCalled();});
 it("scope denial never signs",async()=>{mocks.rpc.mockResolvedValue({error:{code:"42501"}});await expect(requestUpload(input)).rejects.toMatchObject({code:"NOT_FOUND"});expect(mocks.sign).not.toHaveBeenCalled();});
 it("oversize rejected before RPC/sign",async()=>{await expect(requestUpload({...input,size:MAX_UPLOAD_BYTES+1})).rejects.toMatchObject({code:"VALIDATION_ERROR"});expect(mocks.rpc).not.toHaveBeenCalled();});
 it("unknown register fields rejected before RPC",async()=>{await expect(registerUploadedFile({uploadRequestId:id,uploadedBy:id})).rejects.toMatchObject({code:"VALIDATION_ERROR"});expect(mocks.rpc).not.toHaveBeenCalled();});
 it("does not return provider errors or secrets",async()=>{mocks.rpc.mockRejectedValue(new Error("private server detail"));await expect(requestUpload(input)).rejects.toMatchObject({code:"NOT_FOUND"});});
 it("provider failure leaves registration uncalled and returns a safe denial",async()=>{
 const r={id,file_id:id,requested_by:id,workspace_id:id,project_id:null,storage_reference:`workspaces/${id}/files/${id}`,filename:input.filename,mime_type:input.mimeType,expected_size:1,created_at:'2026-10-26T00:00:00Z',expires_at:'2026-10-26T02:00:00Z',registered_at:null};
 mocks.rpc.mockResolvedValue({data:r,error:null});mocks.sign.mockResolvedValue({error:{message:'sensitive provider detail'}});
 await expect(requestUpload(input)).rejects.toMatchObject({code:'NOT_FOUND'});expect(mocks.rpc.mock.calls.map(c=>c[0])).toEqual(['request_file_upload']);expect(mocks.sign).toHaveBeenCalledWith(r.storage_reference,{upsert:false});
 });
});
