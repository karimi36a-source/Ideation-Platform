import {z} from "zod";
import {productClassificationSchema} from "./classification-schema";
import {developmentObjectTypeSchema} from "@/features/projects/object-schema";
import {mindMapEdgeSchema,mindMapNodeSchema,mindMapSchema} from "./schema";

export const editorObjectSchema=z.strictObject({id:z.uuid(),object_type:developmentObjectTypeSchema,title:z.string().trim().min(1),product_classification:productClassificationSchema.nullable().optional(),classification_revision:z.number().int().min(0).max(Number.MAX_SAFE_INTEGER).optional()});
export const mindMapEditorSchema=z.strictObject({
 mindMap:mindMapSchema,nodes:z.array(mindMapNodeSchema),edges:z.array(mindMapEdgeSchema),objects:z.array(editorObjectSchema),editable:z.boolean(),
}).superRefine((value,ctx)=>{
 const ids=new Set(value.nodes.map(n=>n.id));
 if(!value.nodes.some(n=>n.id===value.mindMap.root_node_id&&n.node_type==="CENTRAL_INVENTION"))ctx.addIssue({code:"custom",message:"Missing canonical root"});
 if(value.nodes.some(n=>n.mind_map_id!==value.mindMap.id)||value.edges.some(e=>e.mind_map_id!==value.mindMap.id||!ids.has(e.source_node_id)||!ids.has(e.target_node_id)))ctx.addIssue({code:"custom",message:"Invalid normalized map"});
});
export type MindMapEditorState=z.infer<typeof mindMapEditorSchema>;

export const editorOperationSchema=z.discriminatedUnion("operation",[
 z.strictObject({activityInstanceId:z.uuid(),operation:z.literal("classifyNode"),input:z.unknown()}),
 z.strictObject({activityInstanceId:z.uuid(),operation:z.literal("addNode"),input:z.unknown()}),
 z.strictObject({activityInstanceId:z.uuid(),operation:z.literal("updateNode"),input:z.unknown()}),
 z.strictObject({activityInstanceId:z.uuid(),operation:z.literal("removeNode"),input:z.unknown()}),
 z.strictObject({activityInstanceId:z.uuid(),operation:z.literal("connectEdge"),input:z.unknown()}),
 z.strictObject({activityInstanceId:z.uuid(),operation:z.literal("updateEdge"),input:z.unknown()}),
 z.strictObject({activityInstanceId:z.uuid(),operation:z.literal("removeEdge"),input:z.unknown()}),
]);
export type MindMapEditorOperation=z.infer<typeof editorOperationSchema>;
export type MindMapEditorResult={ok:true;data:MindMapEditorState}|{ok:false;error:{code:string;message:string};data?:MindMapEditorState};
