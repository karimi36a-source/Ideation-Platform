"use client";
import "@xyflow/react/dist/style.css";
import {useCallback,useEffect,useMemo,useRef,useState,useTransition} from "react";
import {Background,Controls,Handle,MiniMap,Position,ReactFlow,useEdgesState,useNodesState,type Connection,type Node,type NodeProps} from "@xyflow/react";
import {mutateMindMapEditor,reloadMindMapEditor} from "./editor-actions";
import {openMindMapCollaboration} from "./collaboration-session";
import {productClassifications} from "./classification-schema";
import {structuralNodeTypes} from "./node-schema";
import type {MindMapEditorState} from "./editor-schema";
import {toFlowEdges,toFlowNodes,type EditorNodeData} from "./editor-model";
import styles from "./mind-map-editor.module.css";

const colors:Record<string,string>={CENTRAL_INVENTION:"#0f766e",SYSTEM:"#1d4ed8",SUBSYSTEM:"#2563eb",COMPONENT:"#4f46e5",FUNCTION:"#7c3aed",PROBLEM:"#be123c",SOLUTION:"#15803d",GAP:"#b45309"};
function MindMapNode({data,selected}:NodeProps<Node<EditorNodeData>>){return <div className={`${styles.node} ${selected?styles.selected:""}`} style={{borderColor:colors[data.nodeType]??"#475569"}} data-node-type={data.nodeType}>
 <Handle type="target" position={Position.Left}/><span className={styles.type}>{data.nodeType.replaceAll("_"," ")}</span><strong>{data.label}</strong>{data.classification&&<span>{data.classification.replaceAll("_"," ")}</span>}
 <span className={data.linked?styles.linked:styles.unlinked}>{data.linked?`Linked · ${data.linkedObjectTitle}`:"Visual node · unlinked"}</span><Handle type="source" position={Position.Right}/></div>}
const nodeTypes={mindMap:MindMapNode};

export function MindMapEditor({activityInstanceId,initialState}:{activityInstanceId:string;initialState:MindMapEditorState}){
 const [state,setState]=useState(initialState),[nodes,setNodes,onNodesChange]=useNodesState(toFlowNodes(initialState)),[edges,setEdges,onEdgesChange]=useEdgesState(toFlowEdges(initialState));
 const [selectedNodeId,setSelectedNodeId]=useState<string|null>(null),[selectedEdgeId,setSelectedEdgeId]=useState<string|null>(null),[notice,setNotice]=useState<string|null>(null),[connectType,setConnectType]=useState<"HIERARCHY"|"CROSS_CONNECTION">("CROSS_CONNECTION"),[pending,startTransition]=useTransition();
 const canonical=useRef(initialState),epoch=useRef(0),mutating=useRef(false),drag=useRef<{id:string;revision:number}|null>(null),live=useRef<ReturnType<typeof openMindMapCollaboration>|null>(null);
 const [collaboration,setCollaboration]=useState("Connecting collaboration"),[unsaved,setUnsaved]=useState(false);
 const selectedNode=state.nodes.find(n=>n.id===selectedNodeId),selectedEdge=state.edges.find(e=>e.id===selectedEdgeId);
 const sync=useCallback((next:MindMapEditorState)=>{canonical.current=next;setState(next);setNodes(toFlowNodes(next));setEdges(toFlowEdges(next));setUnsaved(false);},[setEdges,setNodes]);
 useEffect(()=>{
  let disposed=false,reloading=false,queued=false;let timer:ReturnType<typeof setTimeout>|undefined;
  const reload=async()=>{
   if(disposed)return;if(reloading||mutating.current||drag.current){queued=true;return;}
   reloading=true;queued=false;const ticket=++epoch.current;
   try{const result=await reloadMindMapEditor(activityInstanceId);if(!disposed&&ticket===epoch.current&&!mutating.current&&!drag.current){
    if(result.ok)sync(result.data);else{live.current?.close();live.current=null;setNodes([]);setEdges([]);setState(s=>({...s,editable:false,nodes:[],edges:[],objects:[]}));setNotice(result.error.message);}
   }}catch{if(!disposed)setCollaboration("Collaboration unavailable; saved editing remains available");}
   finally{reloading=false;if(queued&&!disposed)timer=setTimeout(()=>void reload(),150);}
  };
  const onFocus=()=>void reload();window.addEventListener("focus",onFocus);
  const transient=new Map<string,number>();
  try{live.current=openMindMapCollaboration(activityInstanceId,initialState.mindMap.id,{
   status:value=>{if(disposed)return;setCollaboration(value==="connected"?"Collaboration connected":"Collaboration unavailable; saved editing remains available");if(value!=="connected"){transient.clear();setUnsaved(false);setNodes(toFlowNodes(canonical.current));}},
   event:event=>{
    if(disposed)return;
    if(event.type==="mind-map-reload"){transient.clear();void reload();return;}
    const current=canonical.current.nodes.find(n=>n.id===event.nodeId);
    if(!canonical.current.editable||!current||current.edit_revision!==event.revision||drag.current?.id===event.nodeId)return;
    transient.set(event.nodeId,Date.now());setUnsaved(true);
    setNodes(rows=>rows.map(n=>n.id===event.nodeId?{...n,position:{x:event.x,y:event.y}}:n));
   },
  });}catch{timer=setTimeout(()=>{if(!disposed)setCollaboration("Collaboration unavailable; saved editing remains available");},0);}
  const expiry=setInterval(()=>{
   const stale=[...transient].filter(([,time])=>Date.now()-time>5000).map(([id])=>id);
   if(stale.length){for(const id of stale)transient.delete(id);const saved=new Map(toFlowNodes(canonical.current).map(n=>[n.id,n]));setNodes(rows=>rows.map(n=>stale.includes(n.id)&&drag.current?.id!==n.id?saved.get(n.id)??n:n));if(!transient.size)setUnsaved(false);}
   if(queued&&!reloading&&!mutating.current&&!drag.current)void reload();
  },1000);
  return()=>{disposed=true;window.removeEventListener("focus",onFocus);clearInterval(expiry);clearTimeout(timer);live.current?.close();live.current=null;};
 },[activityInstanceId,initialState.mindMap.id,setEdges,setNodes,sync]);
 const run=useCallback((operation:Parameters<typeof mutateMindMapEditor>[0])=>new Promise<boolean>(resolve=>startTransition(async()=>{
  ++epoch.current;mutating.current=true;
  try{const result=await mutateMindMapEditor(operation);++epoch.current;
   if(result.ok){sync(result.data);setNotice("Saved to the canonical Mind Map.");resolve(true);}
   else{if(result.data)sync(result.data);else{const saved=await reloadMindMapEditor(activityInstanceId);if(saved.ok)sync(saved.data);else{setNodes([]);setEdges([]);setState(s=>({...s,editable:false,nodes:[],edges:[],objects:[]}));live.current?.close();live.current=null;}}setNotice(result.error.message);resolve(false);}
  }catch{sync(canonical.current);setNotice("The change was not confirmed. Reload the saved map before retrying.");resolve(false);}
  finally{mutating.current=false;live.current?.send({type:"mind-map-reload"});}
 })),[activityInstanceId,setEdges,setNodes,sync]);
 const mutate=(operation:string,input:unknown)=>run({activityInstanceId,operation,input} as Parameters<typeof mutateMindMapEditor>[0]);
 const onDragStart=(_:unknown,node:Node)=>{const saved=canonical.current.nodes.find(n=>n.id===node.id);if(saved)drag.current={id:node.id,revision:saved.edit_revision};};
 const lastMovement=useRef(0);
 const onDrag=(_:unknown,node:Node)=>{if(!drag.current||Date.now()-lastMovement.current<50)return;lastMovement.current=Date.now();live.current?.send({type:"mind-map-move",nodeId:node.id,revision:drag.current.revision,x:node.position.x,y:node.position.y});};
 const onDragStop=(_:unknown,node:Node)=>{const started=drag.current;drag.current=null;if(started&&state.editable)void mutate("updateNode",{nodeId:node.id,expectedRevision:started.revision,positionData:node.position});};
 const onConnect=async(connection:Connection)=>{if(!state.editable||!connection.source||!connection.target)return;const target=state.nodes.find(n=>n.id===connection.target);if(!target)return;
  if(connectType==="HIERARCHY"&&target.parent_node_id!==connection.source){const changed=await mutate("updateNode",{nodeId:target.id,expectedRevision:target.edit_revision,parentNodeId:connection.source});if(!changed)return;}
  await mutate("connectEdge",{mindMapId:state.mindMap.id,sourceNodeId:connection.source,targetNodeId:connection.target,edgeType:connectType});};
 const hasChildren=useMemo(()=>new Set(state.nodes.flatMap(n=>n.parent_node_id?[n.parent_node_id]:[])),[state.nodes]);
 return <section className={styles.shell} aria-busy={pending}>
  <header className={styles.header}><div><p className={styles.eyebrow}>Session 7 · Invention Mind Map</p><h1>Structure the whole invention</h1><p>Visual changes are saved to PostgreSQL. Linked Project objects remain canonical and independent.</p></div><span className={state.editable?styles.editable:styles.readonly}>{state.editable?"Editable draft":"Read only"}</span></header>
  <p data-testid="mind-map-collaboration-status">{collaboration}{unsaved?" · Live movement is not saved yet":""}</p>
  {notice&&<div className={styles.notice} role="status">{notice}<button onClick={()=>setNotice(null)} aria-label="Dismiss message">×</button></div>}
  {state.editable&&<Toolbar state={state} disabled={pending} connectType={connectType} setConnectType={setConnectType} mutate={mutate}/>} 
  <div className={styles.workspace}>
   <div className={styles.canvas} data-testid="mind-map-canvas">{state.nodes.length===1&&<p className={styles.empty}>The central invention is ready. Add a system or another structural node to begin.</p>}
    <ReactFlow nodes={nodes} edges={edges} nodeTypes={nodeTypes} onNodesChange={onNodesChange} onEdgesChange={onEdgesChange} onNodeDragStart={onDragStart} onNodeDrag={onDrag} onNodeDragStop={onDragStop} onConnect={onConnect} onNodeClick={(_,n)=>{setSelectedNodeId(n.id);setSelectedEdgeId(null)}} onEdgeClick={(_,e)=>{setSelectedEdgeId(e.id);setSelectedNodeId(null)}} nodesDraggable={state.editable} nodesConnectable={state.editable} fitView minZoom={0.25} maxZoom={2} deleteKeyCode={null}>
     <Background gap={24}/><MiniMap nodeColor={node=>colors[String(node.data.nodeType)]??"#64748b"}/><Controls/>
    </ReactFlow>
   </div>
   <aside className={styles.panel}>{selectedNode?<NodePanel key={`${selectedNode.id}:${selectedNode.edit_revision}:${state.objects.find(o=>o.id===selectedNode.development_object_id)?.classification_revision??0}`} state={state} node={selectedNode} hasChildren={hasChildren.has(selectedNode.id)} pending={pending} mutate={mutate}/>:selectedEdge?<EdgePanel key={`${selectedEdge.id}:${selectedEdge.edit_revision}`} edge={selectedEdge} pending={pending} editable={state.editable} mutate={mutate}/>:<p>Select a node or connection to inspect it.</p>}</aside>
  </div>
 </section>;
}

type Mutate=(operation:string,input:unknown)=>Promise<boolean>;
function Toolbar({state,disabled,connectType,setConnectType,mutate}:{state:MindMapEditorState;disabled:boolean;connectType:string;setConnectType:(v:"HIERARCHY"|"CROSS_CONNECTION")=>void;mutate:Mutate}){
 const [type,setType]=useState<(typeof structuralNodeTypes)[number]>("SYSTEM"),[label,setLabel]=useState("New system"),[parent,setParent]=useState(state.mindMap.root_node_id??"");
 return <form className={styles.toolbar} onSubmit={e=>{e.preventDefault();void mutate("addNode",{mindMapId:state.mindMap.id,nodeType:type,label,parentNodeId:parent||null,positionData:{x:120,y:120}})}}>
  <label>Node type<select value={type} onChange={e=>setType(e.target.value as typeof type)}>{structuralNodeTypes.map(t=><option key={t}>{t}</option>)}</select></label>
  <label>Label<input value={label} onChange={e=>setLabel(e.target.value)} maxLength={200}/></label>
  <label>Parent<select value={parent} onChange={e=>setParent(e.target.value)}><option value="">No parent</option>{state.nodes.map(n=><option key={n.id} value={n.id}>{n.label}</option>)}</select></label>
  <button disabled={disabled}>Add node</button><label>New connection<select value={connectType} onChange={e=>setConnectType(e.target.value as "HIERARCHY"|"CROSS_CONNECTION")}><option value="CROSS_CONNECTION">Cross-connection</option><option value="HIERARCHY">Hierarchy</option></select></label>
 </form>}
function NodePanel({state,node,hasChildren,pending,mutate}:{state:MindMapEditorState;node:MindMapEditorState["nodes"][number];hasChildren:boolean;pending:boolean;mutate:Mutate}){
 const [label,setLabel]=useState(node.label),[objectId,setObjectId]=useState(node.development_object_id??""),[parent,setParent]=useState(node.parent_node_id??"");
 const linked=state.objects.find(o=>o.id===node.development_object_id);
 const currentClassification=node.development_object_id?linked?.product_classification??null:node.product_classification??null;
 const [classification,setClassification]=useState(currentClassification??"");
 const root=node.node_type==="CENTRAL_INVENTION"||node.id===state.mindMap.root_node_id;const compatible=state.objects.filter(o=>o.object_type===node.node_type);
 return <div className={styles.inspector}><span className={styles.type}>{node.node_type}</span><h2>{node.label}</h2><p>Concurrency token: {node.edit_revision}</p>{state.editable?<>
  {!root&&<><label>Product classification<select value={classification} onChange={e=>setClassification(e.target.value)}><option value="">Unclassified</option>{productClassifications.map(c=><option key={c} value={c}>{c.replaceAll("_"," ")}</option>)}</select></label><button disabled={pending||classification===(currentClassification??"")} onClick={()=>void mutate("classifyNode",{nodeId:node.id,expectedRevision:node.edit_revision,expectedObjectRevision:node.development_object_id?linked?.classification_revision??null:null,classification:classification||null})}>Save classification</button></>}
  <label>Visual label<input value={label} onChange={e=>setLabel(e.target.value)}/></label><button disabled={pending||label.trim()===node.label} onClick={()=>void mutate("updateNode",{nodeId:node.id,expectedRevision:node.edit_revision,label})}>Save label</button>
  {!root&&<><label>Parent<select value={parent} onChange={e=>setParent(e.target.value)}><option value="">No parent</option>{state.nodes.filter(n=>n.id!==node.id).map(n=><option key={n.id} value={n.id}>{n.label}</option>)}</select></label><button disabled={pending||parent===(node.parent_node_id??"")} onClick={()=>void mutate("updateNode",{nodeId:node.id,expectedRevision:node.edit_revision,parentNodeId:parent||null})}>Save parent</button>
  <label>Canonical Project object<select value={objectId} onChange={e=>setObjectId(e.target.value)}><option value="">Visual node only</option>{compatible.map(o=><option key={o.id} value={o.id}>{o.title}</option>)}</select></label><button disabled={pending||objectId===(node.development_object_id??"")} onClick={()=>void mutate("updateNode",{nodeId:node.id,expectedRevision:node.edit_revision,developmentObjectId:objectId||null})}>{objectId?"Link object":"Remove visual reference"}</button>
  <button className={styles.danger} disabled={pending||hasChildren} title={hasChildren?"Move or remove child nodes first":undefined} onClick={()=>void mutate("removeNode",{nodeId:node.id,expectedRevision:node.edit_revision})}>Remove visual node</button>{hasChildren&&<p>Move or remove child nodes before removing this node.</p>}</>}</>:<p>Mutation controls are unavailable in this context.</p>}</div>}
function EdgePanel({edge,pending,editable,mutate}:{edge:MindMapEditorState["edges"][number];pending:boolean;editable:boolean;mutate:Mutate}){const [label,setLabel]=useState(edge.label??""),[type,setType]=useState(edge.edge_type);return <div className={styles.inspector}><span className={styles.type}>{edge.edge_type}</span><h2>Visual connection</h2><p>Endpoints cannot be reassigned. Remove and reconnect instead.</p>{editable&&<><label>Type<select value={type} onChange={e=>setType(e.target.value as typeof type)}><option>HIERARCHY</option><option>CROSS_CONNECTION</option></select></label><label>Label<input value={label} onChange={e=>setLabel(e.target.value)}/></label><button disabled={pending} onClick={()=>void mutate("updateEdge",{edgeId:edge.id,expectedRevision:edge.edit_revision,edgeType:type,label:label.trim()||null})}>Save connection</button><button className={styles.danger} disabled={pending} onClick={()=>void mutate("removeEdge",{edgeId:edge.id,expectedRevision:edge.edit_revision})}>Remove visual connection</button></>}</div>}
