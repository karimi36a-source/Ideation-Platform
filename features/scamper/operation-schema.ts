import {z} from "zod";
import {scamperLensSchema} from "./schema";
const canonicalUuid=z.uuid().transform(value=>value.toLowerCase());
const fields={scamperType:scamperLensSchema,originalElement:z.string(),proposedChange:z.string(),resultText:z.string()};
export const createScamperEntrySchema=z.strictObject({activityInstanceId:canonicalUuid,...fields});
export const updateScamperEntrySchema=z.strictObject({entryId:canonicalUuid,scamperType:fields.scamperType.optional(),originalElement:fields.originalElement.optional(),proposedChange:fields.proposedChange.optional(),resultText:fields.resultText.optional()})
 .refine(v=>[v.scamperType,v.originalElement,v.proposedChange,v.resultText].some(x=>x!==undefined),{message:"At least one editable field is required"});
