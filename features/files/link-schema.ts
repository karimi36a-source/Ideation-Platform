import {z} from "zod";
import {fileLinkEntityTypeSchema,fileRelationshipTypeSchema} from "./schema";
export const FILE_LINK_RELATIONSHIPS={EVIDENCE:["EVIDENCE_SOURCE","ATTACHMENT","REFERENCE"],ARTIFACT:["ARTIFACT_FILE","ATTACHMENT","REFERENCE"],ACTIVITY_INSTANCE:["ATTACHMENT","REFERENCE"],CHAT_MESSAGE:["CHAT_ATTACHMENT"],DEVELOPMENT_OBJECT:["ATTACHMENT","REFERENCE"]} as const;
export const linkFileSchema=z.strictObject({fileId:z.uuid(),entityType:fileLinkEntityTypeSchema,entityId:z.uuid(),relationshipType:fileRelationshipTypeSchema}).refine(v=>(FILE_LINK_RELATIONSHIPS[v.entityType] as readonly string[]).includes(v.relationshipType),"Incompatible File relationship");
export type LinkFileInput=z.infer<typeof linkFileSchema>;
