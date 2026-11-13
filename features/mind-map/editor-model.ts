import type {Edge,Node} from "@xyflow/react";
import type {MindMapEditorState} from "./editor-schema";

export type EditorNodeData={label:string;nodeType:string;linkedObjectTitle:string|null;linked:boolean;revision:number;classification:string|null;[key:string]:unknown};
export function toFlowNodes(state:MindMapEditorState):Node<EditorNodeData>[] {
 const objects=new Map(state.objects.map(o=>[o.id,o]));
 return state.nodes.map(node=>({
  id:node.id,type:"mindMap",position:{x:number(node.position_data.x),y:number(node.position_data.y)},
  draggable:state.editable,connectable:state.editable,selectable:true,
  data:{label:node.label,nodeType:node.node_type,linked:Boolean(node.development_object_id),linkedObjectTitle:node.development_object_id?objects.get(node.development_object_id)?.title??"Linked Project object":null,revision:node.edit_revision,classification:node.development_object_id?objects.get(node.development_object_id)?.product_classification??null:node.product_classification??null},
 }));
}
export function toFlowEdges(state:MindMapEditorState):Edge[] {
 return state.edges.map(edge=>({id:edge.id,source:edge.source_node_id,target:edge.target_node_id,label:edge.label??undefined,type:edge.edge_type==="HIERARCHY"?"smoothstep":"default",animated:edge.edge_type==="CROSS_CONNECTION",selectable:true,
  style:edge.edge_type==="CROSS_CONNECTION"?{stroke:"#7c3aed",strokeDasharray:"7 5"}:{stroke:"#334155",strokeWidth:2},data:{edgeType:edge.edge_type,revision:edge.edit_revision}}));
}
function number(value:unknown){return typeof value==="number"&&Number.isFinite(value)?value:0;}
