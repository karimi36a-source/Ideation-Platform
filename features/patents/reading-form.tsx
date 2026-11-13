'use client';
import {useState,useTransition} from 'react';
import {useRouter} from 'next/navigation';
import type {PatentWorkspaceState} from './workspace';
import {mutatePatentWorkspace} from './workspace-actions';
import {patentReadingSections,patentReadingSnapshotSchema} from './reading-schema';
export function PatentReadingForm({state}:{state:PatentWorkspaceState}){
 const activities=state.activities.filter(a=>a.configuration_snapshot&&typeof a.configuration_snapshot==='object'&&!Array.isArray(a.configuration_snapshot)&&a.configuration_snapshot.method_type==='patent_research');
 const [activity,setActivity]=useState(activities[0]?.id??'');const [message,setMessage]=useState('');const [pending,startTransition]=useTransition();const router=useRouter();
 const artifact=state.artifacts.find(a=>a.artifact_type==='PATENT_READING_FRAMEWORK'&&a.activity_instance_id===activity);
 const version=state.versions.filter(v=>v.artifact_id===artifact?.id).at(-1);const snapshot=patentReadingSnapshotSchema.safeParse(version?.content_snapshot);
 if(!state.canEdit||!activities.length||!state.patents.length)return null;
 return <section aria-label="Patent Reading Framework"><h2>Patent Reading Framework / Reading Map</h2><p>Record your understanding in six sections. Source metadata stays on the retained Patent Record.</p>
 <label>Reading Activity<select value={activity} onChange={e=>setActivity(e.target.value)}>{activities.map(a=><option key={a.id} value={a.id}>{a.id}</option>)}</select></label>
 <form key={activity+':'+(version?.draft_revision??'new')} action={form=>{
  const notes=Object.fromEntries(patentReadingSections.map(key=>[key,String(form.get(key)??'')]));
  startTransition(async()=>{const result=await mutatePatentWorkspace({operation:'reading',projectId:state.project.id,input:{activityInstanceId:activity,patentRecordId:String(form.get('patentRecordId')),notes,artifactVersionId:version?.id??null,expectedDraftRevision:version?.draft_revision??null}});setMessage(result.message);if(result.ok)router.refresh();});
 }}>
 <label>Source Patent Record<select name="patentRecordId" defaultValue={snapshot.success?snapshot.data.source_patent_record_ids[0]:undefined}>{state.patents.map(p=><option key={p.id} value={p.id}>{p.publication_number} — {p.title}</option>)}</select></label>
 {patentReadingSections.map(key=><label key={key}>{key.replaceAll('_',' ')} — learner notes<textarea name={key} defaultValue={snapshot.success?snapshot.data.learner_notes[key]:''}/></label>)}
 <button disabled={pending||!!version&&version.status!=='DRAFT'}>Save reading framework</button><p role="status">{message}</p></form></section>;
}
