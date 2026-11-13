import {z} from "zod";
export const structuralNodeTypes=["SYSTEM","SUBSYSTEM","COMPONENT","FUNCTION","PROBLEM","SOLUTION","GAP"] as const;
const uuid=z.uuid().transform(v=>v.toLowerCase());
const label=z.string().trim().min(1).max(200);
const jsonObject=z.record(z.string(),z.json());
const reserved=new Set(["projectid","workspaceid","teamid","artifactid","artifactversionid","mindmapid","rootnodeid","nodeid","nodetype","developmentobjectid","createdby","creator","actor","userid","owneruserid","status","approvalstate","approved","authorization","scope","editrevision"]);
const metadata=jsonObject.refine(v=>Object.keys(v).every(k=>!reserved.has(k.replaceAll("_","").toLowerCase())));
const mutable={label:label.optional(),parentNodeId:uuid.nullable().optional(),developmentObjectId:uuid.nullable().optional(),positionData:jsonObject.optional(),metadata:metadata.optional()};
export const addMindMapNodeSchema=z.strictObject({mindMapId:uuid,nodeType:z.enum(structuralNodeTypes),...mutable,label,positionData:jsonObject});
export const updateMindMapNodeSchema=z.strictObject({nodeId:uuid,expectedRevision:z.number().int().min(0).max(Number.MAX_SAFE_INTEGER),...mutable}).refine(v=>Object.keys(v).some(k=>!["nodeId","expectedRevision"].includes(k)&&v[k as keyof typeof v]!==undefined));
export type AddMindMapNodeInput=z.infer<typeof addMindMapNodeSchema>;
export type UpdateMindMapNodeInput=z.infer<typeof updateMindMapNodeSchema>;

export const removeMindMapNodeSchema=z.strictObject({nodeId:uuid,expectedRevision:z.number().int().min(0).max(Number.MAX_SAFE_INTEGER)});
export type RemoveMindMapNodeInput=z.infer<typeof removeMindMapNodeSchema>;
