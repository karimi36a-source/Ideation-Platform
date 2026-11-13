/** M11.26: attacks execute as real authenticated PostgreSQL identities. */
export async function testM11Leakage({call,rpc,ok,deny,sql,fixture,scope,activity,editor,outputs,removed=false}){
 const a1='00000000-0000-4000-8000-000000006004',a2='00000000-0000-4000-8000-000000006005';
 const b='00000000-0000-4000-8000-000000006007';
 const actors=removed?[a1]:[b,'00000000-0000-4000-8000-000000006002','00000000-0000-4000-8000-000000006001','00000000-0000-4000-8000-000000006003'];
 const map=editor.mindMap,node=editor.nodes.find(n=>n.development_object_id),edge=editor.edges[0];
 const revision=sql(`(select draft_revision from public.artifact_versions where id='${map.artifact_version_id}')`);
 const group=sql(`(select to_jsonb(g) from public.affinity_groups g join public.activity_instances a on a.id=g.activity_instance_id where a.project_id='${scope.projectId}' and exists(select 1 from public.affinity_group_items i where i.affinity_group_id=g.id) order by g.sequence limit 1)`);
 const item=sql(`(select to_jsonb(i) from public.affinity_group_items i where affinity_group_id='${group.id}' order by position limit 1)`);
 if(!node||!edge||!item)throw Error('M11.26 attack fixtures incomplete');
 const objectRevision=sql(`(select classification_revision from public.development_objects where id='${node.development_object_id}')`);
 const tables=['affinity_groups','affinity_group_items','mind_maps','mind_map_nodes','mind_map_edges','development_objects','artifacts','artifact_versions','artifact_object_links','activity_outputs'];
 const snapshot=()=>sql(`jsonb_build_array(${tables.map(t=>`(select coalesce(jsonb_agg(to_jsonb(x) order by id),'[]') from public.${t} x)`).join(',')})`);
 const before=JSON.stringify(snapshot());
 const ids=[group.id,item.id,map.id,node.id,edge.id,node.development_object_id,outputs.mindMap.artifact.id,map.artifact_version_id,null,null];
 const artifacts=[outputs.mindMap.artifact.id,outputs.essentialStructure.artifact.id,outputs.inventionConcept.artifact.id,fixture.session6Structure.artifact.id,fixture.session6Gap.artifact.id];
 const filter=artifacts.map(id=>`'${id}'`).join(',');
 for(const actor of actors){
  for(let i=0;i<tables.length;i++){
   const table=tables[i];const condition=ids[i]?`id='${ids[i]}'`:table==='activity_outputs'?`activity_instance_id='${activity}'`:`artifact_id in(${filter})`;
   if(ok(await call(actor,`(select count(*) from public.${table} where ${condition})`))!==0)throw Error(`M11.26 ${table} exact-ID leak`);
   for(const statement of [`insert into public.${table} default values`,`update public.${table} set id=id where ${condition}`,`delete from public.${table} where ${condition}`])deny(await call(actor,'null::jsonb',statement+';'));
  }
  const joins=`jsonb_build_array((select count(*) from public.affinity_groups g join public.affinity_group_items i on i.affinity_group_id=g.id join public.development_objects o on o.id=i.development_object_id where g.id='${group.id}'),(select count(*) from public.mind_map_nodes n join public.development_objects o on o.id=n.development_object_id where n.mind_map_id='${map.id}'),(select count(*) from public.artifact_versions v join public.artifact_object_links l on l.artifact_version_id=v.id join public.development_objects o on o.id=l.development_object_id where v.artifact_id in(${filter})),(select count(*) from public.activity_outputs o join public.artifacts a on a.id=o.artifact_id where a.id in(${filter})),(select count(*) from public.artifacts where id in(${filter})),(select count(*) from public.artifact_versions where artifact_id in(${filter})))`;
  if(JSON.stringify(ok(await call(actor,joins)))!=='[0,0,0,0,0,0]')throw Error('M11.26 output/history/join leak');
  for(const [operation,input] of [
   ['create_affinity_group',{activityInstanceId:group.activity_instance_id,name:'Unauthorized'}],
   ['rename_affinity_group',{affinityGroupId:group.id,name:'Unauthorized'}],
   ['add_affinity_item',{affinityGroupId:group.id,developmentObjectId:node.development_object_id}],
   ['move_affinity_item',{itemId:item.id,targetGroupId:group.id,position:1,expectedRevision:item.move_revision}],
   ['confirm_affinity_structure',{activityInstanceId:group.activity_instance_id,affinityGroupId:group.id,mode:'LINK_EXISTING',targetObjectId:node.development_object_id,idempotencyKey:'attack'}],
   ['capture_gap',{activityInstanceId:group.activity_instance_id,mode:'CREATE_NEW',newGap:{title:'Attack'},idempotencyKey:'attack'}],
   ['add_mind_map_node',{mindMapId:map.id,nodeType:'COMPONENT',label:'Attack',positionData:{x:0,y:0}}],
   ...[{label:'Attack'},{positionData:{x:999,y:999}},{parentNodeId:map.root_node_id},{developmentObjectId:node.development_object_id},{developmentObjectId:null}].map(p=>['update_mind_map_node',{nodeId:node.id,expectedRevision:node.edit_revision,...p}]),
   ['remove_mind_map_node',{nodeId:node.id,expectedRevision:node.edit_revision}],
   ['connect_mind_map_nodes',{mindMapId:map.id,sourceNodeId:map.root_node_id,targetNodeId:node.id,edgeType:'CROSS_CONNECTION'}],
   ['update_mind_map_edge',{edgeId:edge.id,expectedRevision:edge.edit_revision,label:'Attack'}],
   ['remove_mind_map_edge',{edgeId:edge.id,expectedRevision:edge.edit_revision}],
   ['save_mind_map_draft',{mindMapId:map.id,expectedDraftRevision:revision}],
   ['create_mind_map_version',{mindMapId:map.id,expectedDraftRevision:revision,changeSummary:'Attack'}],
   ['classify_mind_map_node',{nodeId:node.id,expectedRevision:node.edit_revision,expectedObjectRevision:objectRevision,classification:'OPTIONAL_FUTURE'}],
   ['finalize_session7_outputs',{activityInstanceId:activity,mindMapId:map.id,expectedDraftRevision:revision,idempotencyKey:'attack'}],
  ])deny(await rpc(actor,operation,input));
  deny(await call(actor,`public.get_mind_map_editor('${activity}')`));
  deny(await call(actor,`public.add_activity_artifact_output('${activity}','${outputs.mindMap.artifact.id}')`));
 }
 if(JSON.stringify(snapshot())!==before)throw Error('M11.26 denied attack mutated canonical/history state');
 if(!removed){
  // A legitimate editor remains usable after every adversarial category.
  if(ok(await call(a2,`public.get_mind_map_editor('${activity}')`)).mindMap.id!==map.id)throw Error('M11.26 authorized editor broken');
  ok(await rpc(a2,'update_mind_map_node',{nodeId:node.id,expectedRevision:node.edit_revision,label:node.label}));
 }else{
  if(ok(await call(a2,`public.get_mind_map_editor('${activity}')`)).mindMap.id!==map.id)throw Error('M11.26 remaining member denied');
 }
 console.log(`M11.26 ${removed?'removed-member':'TeamB/role-only'} Affinity/map/node/edge/Draft/version/classification/composition/directCRUD/exactID/joins/historical/Session6/Session7/no-partial-write/authorized-control PASS`);
}
