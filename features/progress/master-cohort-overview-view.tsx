'use client';
import {useId,useState} from 'react';
import type {MasterCohortOverview} from './master-cohort-overview-schema';
import styles from './master-cohort-overview-view.module.css';
const filters=['all','pending','revision','active','completed'] as const;
type Filter=typeof filters[number];
const labels:Record<Filter,string>={all:'All Teams',pending:'Pending review',revision:'Revision requested',active:'Active Teams',completed:'Completed Teams'};
const label=(value:string)=>value.toLowerCase().replaceAll('_',' ');
/** Presentation/filtering only. Never discovers scopes or loads source records. */
export function MasterCohortOverviewView({state}:{state:MasterCohortOverview}){
 const [filter,setFilter]=useState<Filter>('all');const filterId=useId();
 const teams=state.teams.filter(t=>filter==='all'||filter==='pending'&&t.projects.some(p=>p.pendingReview.count>0)||filter==='revision'&&t.projects.some(p=>p.revisionRequested.pending)||filter==='active'&&t.team.status==='active'||filter==='completed'&&t.team.status==='completed');
 return <main className={styles.overview}>
  <nav aria-label="Account"><a href="/account">Back to account</a></nav>
  <h1>{state.cohort.name} — Cohort overview</h1>
  <p>Cohort status: {label(state.cohort.status)}</p>
  <label htmlFor={filterId}>Show Teams</label>{' '}
  <select id={filterId} value={filter} onChange={event=>{const next=event.target.value;if(filters.some(value=>value===next))setFilter(next as Filter);}}>
   {filters.map(value=><option key={value} value={value}>{labels[value]}</option>)}
  </select>
  <p role="status">{teams.length} {teams.length===1?'Team shown':'Teams shown'}</p>
  {state.teams.length===0?<p>No Teams in this Cohort.</p>:teams.length===0?<p>No Teams match this filter.</p>:teams.map(team=><section className={styles.team} key={team.team.id} aria-labelledby={`team-${team.team.id}`}>
   <header><h2 id={`team-${team.team.id}`}>{team.team.name}</h2><p>Team status: {label(team.team.status)} · Active members: {team.activeMemberCount}</p></header>
   {team.projects.length===0?<p>No qualifying Project.</p>:team.projects.map(project=><section className={styles.project} key={project.project.id} aria-labelledby={`project-${project.project.id}`}>
    <h3 id={`project-${project.project.id}`}>{project.project.name}</h3>
    <p>Project status: {label(project.project.status)}</p>
    <p className={project.pendingReview.count>0?styles.callout:undefined}><strong>Pending review: {project.pendingReview.count}</strong>{project.pendingReview.count===0?' — No submission awaiting your review.':''}</p>
    {project.pendingReview.targets.length>0&&<ul aria-label="Pending review targets">{project.pendingReview.targets.map(target=><li key={target.submissionId}>Version {target.versionNumber}: {label(target.status)} · Submission ID: {target.submissionId}</li>)}</ul>}
    {project.revisionRequested.pending?<div className={styles.callout}><strong>Revision requested</strong><ul>{project.revisionRequested.targets.map(target=><li key={target.submissionId}>Revision required for Version {target.versionNumber} · Submission ID: {target.submissionId}</li>)}</ul></div>:<p>No revision requested.</p>}
    {project.activities.length===0?<p>No current Activity.</p>:<ul aria-label="Activity candidates">{project.activities.map(activity=><li key={activity.definition.id}>
     <p>Session {activity.session.sessionNumber}: {activity.session.title} · {activity.definition.name}</p>
     {activity.instances.map(instance=><p key={instance.id}>Activity status: {label(instance.status)}</p>)}
     {activity.availableToStart&&<p>Available to start</p>}
    </li>)}</ul>}
    <h4>Approved output</h4>
    {project.approvedOutputs.length===0?<p>No approved output.</p>:<ul>{project.approvedOutputs.map(output=><li key={output.artifactId}>{label(output.artifactType)} · Approved Version {output.versionNumber} · {label(output.status)} · Version ID: {output.versionId}</li>)}</ul>}
    <p>Last meaningful workflow update: {project.lastMeaningfulWorkflowUpdateAt?<time dateTime={project.lastMeaningfulWorkflowUpdateAt}>{project.lastMeaningfulWorkflowUpdateAt}</time>:'No workflow update yet.'}</p>
   </section>)}
  </section>)}
 </main>;
}
