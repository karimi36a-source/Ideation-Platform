"use client";
import {useState,useTransition} from 'react';
import {useRouter} from 'next/navigation';
import {mutatePatentWorkspace} from './workspace-actions';
import {patentSourceDatabaseSchema,patentRelevanceStatusSchema} from './schema';
import type {PatentWorkspaceState} from './workspace';
export function PatentWorkspaceForms({state}:{state:PatentWorkspaceState}){
 const [message,setMessage]=useState('');const [pending,startTransition]=useTransition();const router=useRouter();
 const scope={projectId:state.project.id,workspaceId:state.project.primary_workspace_id};
 function submit(kind:'retain'|'searchLog'|'evidence',form:FormData){
  const text=(key:string)=>String(form.get(key)??'');const optional=(key:string)=>text(key)||undefined;
  let input:unknown;
  if(kind==='retain')input={...scope,publicationNumber:text('publicationNumber'),title:text('title'),sourceDatabase:text('sourceDatabase'),sourceUrl:text('sourceUrl'),relevanceStatus:text('relevanceStatus'),
   applicationNumber:optional('applicationNumber'),applicant:optional('applicant'),inventor:optional('inventor'),priorityDate:optional('priorityDate'),filingDate:optional('filingDate'),publicationDate:optional('publicationDate'),ipcCpc:optional('ipcCpc'),abstractText:optional('abstractText'),whyRetained:optional('whyRetained')};
  else if(kind==='searchLog')input={...scope,activityInstanceId:text('activityInstanceId'),databaseName:text('databaseName'),queryText:text('queryText'),searchMethod:text('searchMethod'),reason:text('reason'),
   resultsReviewedCount:optional('resultsReviewedCount')===undefined?undefined:Number(text('resultsReviewedCount')),relevantResultsCount:optional('relevantResultsCount')===undefined?undefined:Number(text('relevantResultsCount')),
   termsLearned:text('termsLearned').split('\n').filter(Boolean),classificationsLearned:text('classificationsLearned').split('\n').filter(Boolean),notes:optional('notes')};
  else input={patentRecordId:text('patentRecordId'),evidenceType:text('evidenceType'),title:text('title'),description:text('description'),...(text('evidenceType')==='PATENT_CLAIM'?{claimLocator:text('claimLocator')}:{})};
  startTransition(async()=>{const result=await mutatePatentWorkspace({operation:kind,projectId:scope.projectId,input});setMessage(result.message);if(result.ok)router.refresh();});
 }
 const sourceOptions=patentSourceDatabaseSchema.options.map(s=><option key={s}>{s}</option>);
 if(!state.canEdit)return <p>This research workspace is read-only.</p>;
 return <section aria-label="Research actions"><h2>Add research</h2><p role="status" aria-live="polite">{message}</p>
 <details><summary>Record a search</summary>{state.activities.length===0?<p>No accessible active Activity is available. Start an authorized Activity before recording a search.</p>:<form action={f=>submit('searchLog',f)}>
 <label>Activity<select name="activityInstanceId">{state.activities.map(a=><option key={a.id} value={a.id}>{a.id}</option>)}</select></label>
 <label>Database<select name="databaseName">{sourceOptions}</select></label>
 <label>Query<input name="queryText" required/></label><label>Search method<input name="searchMethod" required/></label><label>Reason<textarea name="reason" required/></label>
 <label>Results reviewed<input name="resultsReviewedCount" type="number" min="0" step="1"/></label><label>Relevant results<input name="relevantResultsCount" type="number" min="0" step="1"/></label>
 <label>Terms learned (one per line)<textarea name="termsLearned"/></label><label>Classifications learned (one per line)<textarea name="classificationsLearned"/></label>
 <label>Research notes<textarea name="notes"/></label><button disabled={pending}>Save search log</button></form>}</details>
 <details><summary>Retain a patent</summary><form action={f=>submit('retain',f)}>
 <label>Publication number<input name="publicationNumber" required/></label><label>Title<input name="title" required/></label>
 <label>Database<select name="sourceDatabase">{sourceOptions}</select></label><label>Source URL<input name="sourceUrl" type="url" required pattern="[Hh][Tt][Tt][Pp][Ss]://.*"/></label>
 <label>Application number<input name="applicationNumber"/></label><label>Applicant<input name="applicant"/></label><label>Inventor<input name="inventor"/></label>
 <label>Priority date<input name="priorityDate" type="date"/></label><label>Filing date<input name="filingDate" type="date"/></label><label>Publication date<input name="publicationDate" type="date"/></label>
 <label>IPC/CPC<input name="ipcCpc"/></label><label>Source abstract<textarea name="abstractText"/></label>
 <label>Human research relevance<select name="relevanceStatus">{patentRelevanceStatusSchema.options.map(s=><option key={s}>{s}</option>)}</select></label>
 <label>Why retained / human research notes<textarea name="whyRetained"/></label><button disabled={pending}>Save patent record</button></form></details>
 <details><summary>Create source-backed Evidence</summary>{state.patents.length===0?<p>Retain a patent before creating its Evidence.</p>:<form action={f=>submit('evidence',f)}>
 <label>Patent<select name="patentRecordId">{state.patents.map(p=><option key={p.id} value={p.id}>{p.publication_number} — {p.title}</option>)}</select></label>
 <label>Evidence type<select name="evidenceType"><option>PATENT</option><option>PATENT_CLAIM</option></select></label>
 <label>Evidence title<input name="title" required/></label><label>Source-backed description<textarea name="description" required/></label>
 <label>Claim locator (required for PATENT_CLAIM only)<input name="claimLocator"/></label>
 <p>New Evidence starts UNVERIFIED. A locator identifies the source claim; it does not interpret its legal scope.</p>
 <button disabled={pending}>Create Evidence</button></form>}</details></section>;
}
