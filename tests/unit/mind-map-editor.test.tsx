// @vitest-environment jsdom
import {afterEach,beforeAll,beforeEach,describe,expect,it,vi} from "vitest";
import {cleanup,fireEvent,render,screen,waitFor,within} from "@testing-library/react";
import {toFlowEdges,toFlowNodes} from "@/features/mind-map/editor-model";
import {ConnectionLineType} from "@xyflow/react";
import type {MindMapEditorState} from "@/features/mind-map/editor-schema";
const mutate=vi.hoisted(()=>vi.fn());
vi.mock("@/features/mind-map/editor-actions",()=>({mutateMindMapEditor:mutate,reloadMindMapEditor:vi.fn()}));
vi.mock("@/features/mind-map/collaboration-session",()=>({openMindMapCollaboration:()=>({send:vi.fn(),close:vi.fn()})}));
import {MindMapEditor} from "@/features/mind-map/editor";
const uuid=(n:number)=>`00000000-0000-4000-8000-${String(n).padStart(12,"0")}`;
const types=["CENTRAL_INVENTION","SYSTEM","SUBSYSTEM","COMPONENT","FUNCTION","PROBLEM","SOLUTION","GAP"];
const state:MindMapEditorState={mindMap:{id:uuid(1),artifact_id:uuid(2),artifact_version_id:uuid(3),root_node_id:uuid(10)},editable:true,nodes:types.map((node_type,i)=>({id:uuid(10+i),mind_map_id:uuid(1),node_type,label:`${node_type} label`,development_object_id:i?uuid(100+i):null,parent_node_id:i>1?uuid(10+i-1):i===1?uuid(10):null,position_data:{x:i*100,y:i*20},metadata:i===0?{role:"central_invention"}:{} as Record<string,string>,created_by:uuid(90),edit_revision:i})),edges:[{id:uuid(30),mind_map_id:uuid(1),source_node_id:uuid(10),target_node_id:uuid(11),edge_type:"HIERARCHY",label:null,metadata:{},edit_revision:2},{id:uuid(31),mind_map_id:uuid(1),source_node_id:uuid(15),target_node_id:uuid(16),edge_type:"CROSS_CONNECTION",label:"supports",metadata:{},edit_revision:3}],objects:types.slice(1).map((object_type,i)=>({id:uuid(101+i),object_type:object_type as "SYSTEM",title:`Canonical ${object_type}`}))};
beforeAll(()=>{class ResizeObserver{observe(){}unobserve(){}disconnect(){}};vi.stubGlobal("ResizeObserver",ResizeObserver);HTMLElement.prototype.getBoundingClientRect=()=>({x:0,y:0,width:1000,height:700,top:0,left:0,right:1000,bottom:700,toJSON:()=>({})});});
afterEach(cleanup);
beforeEach(()=>mutate.mockResolvedValue({ok:true,data:state}));
describe("M11.12 React Flow Mind Map editor",()=>{
 it("maps canonical IDs, all node types, hierarchy and cross-connections",()=>{const nodes=toFlowNodes(state),edges=toFlowEdges(state);expect(nodes.map(n=>n.id)).toEqual(state.nodes.map(n=>n.id));expect(nodes.map(n=>n.data.nodeType)).toEqual(types);expect(nodes[1].data.linkedObjectTitle).toBe("Canonical SYSTEM");expect(edges[0]).toMatchObject({id:uuid(30),source:uuid(10),target:uuid(11),type:"smoothstep"});expect(edges[1]).toMatchObject({id:uuid(31),type:ConnectionLineType.Bezier,animated:true});});
 it("renders root, linked indicators and excludes CENTRAL_INVENTION from add types",()=>{render(<MindMapEditor activityInstanceId={uuid(40)} initialState={state}/>);expect(within(screen.getByTestId(`rf__node-${uuid(10)}`)).getByText("CENTRAL_INVENTION label")).toBeTruthy();expect(screen.getAllByText(/Linked · Canonical/)).toHaveLength(7);const options=screen.getAllByRole("option").map(x=>x.textContent);expect(options).not.toContain("CENTRAL_INVENTION");for(const type of types.slice(1))expect(options).toContain(type);});
 it("uses node CAS for labels and never offers root removal",async()=>{render(<MindMapEditor activityInstanceId={uuid(40)} initialState={state}/>);fireEvent.click(screen.getByTestId(`rf__node-${uuid(10)}`));expect(screen.queryByText("Remove visual node")).toBeNull();fireEvent.change(screen.getByLabelText("Visual label"),{target:{value:"New visual root"}});fireEvent.click(screen.getByText("Save label"));await waitFor(()=>expect(mutate).toHaveBeenCalledWith(expect.objectContaining({operation:"updateNode",input:{nodeId:uuid(10),expectedRevision:0,label:"New visual root"}})));});
 it("surfaces stale CAS and reloads authoritative state without retry",async()=>{const canonical={...state,nodes:state.nodes.map(n=>n.id===uuid(10)?{...n,label:"Winning canonical label",edit_revision:1}:n)};mutate.mockResolvedValueOnce({ok:false,error:{code:"CONFLICT",message:"This map changed elsewhere. The latest saved state has been loaded."},data:canonical});render(<MindMapEditor activityInstanceId={uuid(40)} initialState={state}/>);fireEvent.click(screen.getByTestId(`rf__node-${uuid(10)}`));fireEvent.change(screen.getByLabelText("Visual label"),{target:{value:"Stale edit"}});fireEvent.click(screen.getByText("Save label"));await waitFor(()=>expect(screen.getByRole("status").textContent).toContain("changed elsewhere"));expect((screen.getByLabelText("Visual label") as HTMLInputElement).value).toBe("Winning canonical label");expect(mutate).toHaveBeenCalledTimes(1);});
 it("renders read-only without mutation controls",()=>{render(<MindMapEditor activityInstanceId={uuid(40)} initialState={{...state,editable:false}}/>);expect(screen.getByText("Read only")).toBeTruthy();expect(screen.queryByText("Add node")).toBeNull();expect(screen.queryByLabelText("New connection")).toBeNull();});
});

it("M11.16 resolves repeated linked nodes from canonical C1 and submits both CAS tokens",async()=>{
 const component=state.nodes.find(n=>n.node_type==="COMPONENT")!;
 const classified:MindMapEditorState={...state,nodes:[...state.nodes,{...component,id:uuid(501),label:"Second view of C1",product_classification:"OPTIONAL_FUTURE"}],objects:state.objects.map(o=>o.id===component.development_object_id?{...o,product_classification:"SUPPORTING",classification_revision:8}:o)};
 const views=toFlowNodes(classified).filter(n=>[component.id,uuid(501)].includes(n.id));
 expect(views.map(n=>n.data.classification)).toEqual(["SUPPORTING","SUPPORTING"]);
 render(<MindMapEditor activityInstanceId={uuid(40)} initialState={classified}/>);
 fireEvent.click(screen.getByTestId(`rf__node-${component.id}`));
 fireEvent.change(screen.getByLabelText("Product classification"),{target:{value:"CORE"}});
 fireEvent.click(screen.getByText("Save classification"));
 await waitFor(()=>expect(mutate).toHaveBeenCalledWith(expect.objectContaining({operation:"classifyNode",input:{nodeId:component.id,expectedRevision:component.edit_revision,expectedObjectRevision:8,classification:"CORE"}})));
});
