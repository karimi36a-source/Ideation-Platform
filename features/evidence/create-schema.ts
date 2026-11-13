import {z} from "zod";
import {evidenceTypeSchema} from "./schema";
const uuid=z.uuid().transform(value=>value.toLowerCase());
const text=z.string().trim().min(1);
// Accepted M12.1 HTTP(S) source-reference format; never fetched or scraped.
const sourceUrl=z.string().trim().regex(/^https?:\/\/[^/\s?#]+([/?#][^\s]*)?$/i);
export const createEvidenceSchema=z.strictObject({
 projectId:uuid,workspaceId:uuid,evidenceType:evidenceTypeSchema.refine(value=>value!=="PATENT_CLAIM",{message:"Use linkPatentToEvidence with a claim locator"}),
 title:text,description:text,sourceName:text,sourceUrl:sourceUrl.optional(),fileId:uuid.optional(),
});
export type CreateEvidenceInput=z.infer<typeof createEvidenceSchema>;
