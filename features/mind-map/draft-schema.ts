import {z} from "zod";
export const saveMindMapDraftSchema=z.strictObject({mindMapId:z.uuid(),expectedDraftRevision:z.number().int().min(0).max(2147483647)});
export const savedMindMapDraftSchema=z.strictObject({mindMapId:z.uuid(),artifactVersionId:z.uuid(),draftRevision:z.number().int().min(1).max(2147483647)});
export type SaveMindMapDraftInput=z.infer<typeof saveMindMapDraftSchema>;
export type SavedMindMapDraft=z.infer<typeof savedMindMapDraftSchema>;
