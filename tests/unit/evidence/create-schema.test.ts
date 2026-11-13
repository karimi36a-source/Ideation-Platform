import {it,expect} from "vitest";
import {createEvidenceSchema} from "@/features/evidence/create-schema";
import {evidenceTypeSchema} from "@/features/evidence/schema";
const id="aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa";
const input={projectId:id,workspaceId:id,evidenceType:"MEASUREMENT",title:"Measurement",description:"Recorded observations",sourceName:"Lab notebook"};
it.each(evidenceTypeSchema.options.filter(type=>type!=="PATENT_CLAIM"))("accepts approved %s with an offline named source",evidenceType=>{expect(createEvidenceSchema.safeParse({...input,evidenceType}).success).toBe(true);});
it("normalizes authored text without inventing content or a URL",()=>{expect(createEvidenceSchema.parse({...input,title:" \tMeasurement\n",description:"  Recorded observations  ",sourceName:" \u00a0Lab notebook\u00a0 ",projectId:id.toUpperCase()})).toEqual(input);});
it("accepts and trims the approved external source reference",()=>{expect(createEvidenceSchema.parse({...input,sourceUrl:"  https://example.test/source?q=1#section  "}).sourceUrl).toBe("https://example.test/source?q=1#section");});
it.each(["title","description","sourceName"])("rejects blank %s",key=>{expect(createEvidenceSchema.safeParse({...input,[key]:" \t\n\u00a0 "}).success).toBe(false);});
it.each(["not a URL","https://","https://bad host/source","javascript:alert(1)","file:///source","data:text/plain,source",""])("rejects malformed/unsafe URL %s",sourceUrl=>{expect(createEvidenceSchema.safeParse({...input,sourceUrl}).success).toBe(false);});
it.each(["verificationStatus","verifiedBy","verifiedAt","createdBy","capturedAt","metadata","archivedAt","ownerUserId","ownerTeamId","storagePath","idempotencyKey","role","teamId"])("rejects additional %s",key=>{expect(createEvidenceSchema.safeParse({...input,[key]:id}).success).toBe(false);});
it.each(["AI_OUTPUT","CUSTOM","patent",""])("rejects unknown Evidence type %s",evidenceType=>{expect(createEvidenceSchema.safeParse({...input,evidenceType}).success).toBe(false);});
it("keeps optional file ID typed for explicit dependency handling",()=>{expect(createEvidenceSchema.parse({...input,fileId:id}).fileId).toBe(id);expect(createEvidenceSchema.safeParse({...input,fileId:"storage/path"}).success).toBe(false);});
it("does not accept null as a supplied URL or file reference",()=>{expect(createEvidenceSchema.safeParse({...input,sourceUrl:null}).success).toBe(false);expect(createEvidenceSchema.safeParse({...input,fileId:null}).success).toBe(false);});

it("requires the dedicated M12.14 claim-locator operation for PATENT_CLAIM",()=>expect(createEvidenceSchema.safeParse({...input,evidenceType:"PATENT_CLAIM"}).success).toBe(false));
it.each(['aiOutputId','createVerifiedEvidence','promoteToEvidence','sourceBypass','verified_by','verified_at'])('M14.17 rejects AI promotion or verifier override %s',key=>expect(createEvidenceSchema.safeParse({...input,[key]:id}).success).toBe(false));
