import {describe,it,expect} from "vitest";
import {mindMapSchema,mindMapNodeSchema,mindMapEdgeSchema} from "@/features/mind-map/schema";
import type {Database} from "@/lib/db/database.types";
const id="00000000-0000-4000-8000-000000000001";
const other="00000000-0000-4000-8000-000000000002";
const node={id,mind_map_id:other,node_type:"SYSTEM",label:"System",development_object_id:null,parent_node_id:null,position_data:{},metadata:{},created_by:id,edit_revision:0} satisfies Database["public"]["Tables"]["mind_map_nodes"]["Row"];
describe("M11.7 storage contracts",()=>{
 it("accepts a nullable transactional root",()=>{expect(mindMapSchema.safeParse({id,artifact_id:id,artifact_version_id:other,root_node_id:null}).success).toBe(true);});
 it.each(["SYSTEM","SUBSYSTEM","COMPONENT","FUNCTION","PROBLEM","SOLUTION","GAP"])("supports %s visual node",node_type=>{expect(mindMapNodeSchema.safeParse({...node,node_type}).success).toBe(true);});
 it.each([{node_type:" "},{label:""},{label:"x".repeat(201)},{parent_node_id:id},{position_data:[]},{metadata:null},{created_by:"spoof"},{extra:true}])("rejects malformed storage %#",patch=>{expect(mindMapNodeSchema.safeParse({...node,...patch}).success).toBe(false);});
 it("supports nullable presentation edge labels and approved visual type",()=>{const edge={id,mind_map_id:id,source_node_id:id,target_node_id:other,edge_type:"CROSS_CONNECTION",label:null,metadata:{},edit_revision:0} satisfies Database["public"]["Tables"]["mind_map_edges"]["Row"];expect(mindMapEdgeSchema.parse(edge)).toEqual(edge);expect(mindMapEdgeSchema.safeParse({...edge,edge_type:" "}).success).toBe(false);});
});
