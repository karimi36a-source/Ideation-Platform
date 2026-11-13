import type {MyCurrentWork} from './current-work-schema';
import styles from './current-work-view.module.css';
const stateLabel=(value:string)=>value.toLowerCase().replaceAll('_',' ');
/** Presentation only: authorization, selection and ordering belong to M15.17. */
export function CurrentWorkOverview({state}:{state:MyCurrentWork}){
 return <main className={styles.overview}>
  <h1>My current work</h1>
  <p>Unread notifications: {state.unreadNotificationCount}</p>
  {state.contexts.length===0?<p>No active work is currently available. Your authorized work will appear here when available.</p>:state.contexts.map(context=><section className={styles.context} key={context.id} aria-labelledby={`context-${context.id}`}>
   <h2 id={`context-${context.id}`}>{context.project.name}</h2>
   <p>{context.course.name} · {context.cohort.name}</p>
   <p>{context.team?`Team: ${context.team.name}`:'Personal workspace · No Team in this context'}</p>
   {context.team&&<p><a href={`/teams/${context.team.id}`}>Open My Team</a></p>}
   {context.activities.length===0?<p>No current Activity in this context.</p>:context.activities.map((activity,index)=><section className={styles.activity} key={activity.instanceId??activity.definition.id} aria-labelledby={`activity-${context.id}-${index}`}>
    <p>Session {activity.session.sessionNumber}: {activity.session.title}</p>
    <h3 id={`activity-${context.id}-${index}`}>{activity.definition.name}</h3>
    <p>Activity status: {activity.status?stateLabel(activity.status):activity.availability.available?'available to start':'not available to start'}</p>
    {activity.status==='completed'&&<p>Completed Activity — retained approved output below.</p>}
    {activity.work.length===0&&<p>No Draft or Artifact yet.</p>}
    {activity.work.map(work=><article key={work.id}>
     <h4>{work.title}</h4>
     <p>Artifact type: {stateLabel(work.artifactType)}</p>
     {work.artifactType==='MIND_MAP'&&activity.instanceId&&<p><a href={`/activities/${activity.instanceId}/mind-map`}>Open Mind Map Activity: {activity.definition.name}</a></p>}
     {work.drafts.length===0?<p>No Draft yet.</p>:<ul aria-label={`Drafts for ${work.title}`}>{work.drafts.map(v=><li key={v.id}>Work in progress: Version {v.versionNumber} · {stateLabel(v.status)}</li>)}</ul>}
     {work.submissions.length===0?<p>No Submission yet.</p>:work.submissions.map(s=><div key={s.id}>
      <p>Submission for Version {s.versionNumber}: {stateLabel(s.status)}</p>
      {s.revisionRequested&&<p className={styles.callout}><strong>Revision requested for Version {s.versionNumber}.</strong> Review the feedback in the canonical Submission context when available.</p>}
      {s.status==='REVISION_REQUESTED'&&!s.revisionRequested&&<p>Historical revision request — no outstanding revision obligation.</p>}
      {['SUBMITTED','UNDER_REVIEW'].includes(s.status)&&<p>Pending review for Version {s.versionNumber}.</p>}
     </div>)}
     {work.approvedOutput?<p>Approved output: Version {work.approvedOutput.versionNumber} · {stateLabel(work.approvedOutput.status)} · Version ID: {work.approvedOutput.id}</p>:<p>No approved output yet.</p>}
    </article>)}
   </section>)}
  </section>)}
 </main>;
}

