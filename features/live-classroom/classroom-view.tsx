'use client';
import {useEffect,useRef,useState} from 'react';
import type {ClassroomView,ClassroomActivity} from './classroom-schema';
import styles from './classroom-view.module.css';
function ActivitySummary({activity}:{activity:ClassroomActivity}){return <article><h3>{activity.name}</h3><p>Activity type: {activity.activityType.replaceAll('_',' ')}</p><p>Status: {activity.status.replaceAll('_',' ')}</p>{activity.projectName&&<p>Project: {activity.projectName}</p>}{activity.teamName&&<p>Team: {activity.teamName}</p>}<a href={activity.href}>Open Current Activity</a></article>;}
/** Daily Prebuilt owns media only. No Activity/Project mutation endpoint exists
 * in this component. Capabilities live only in memory/the intended Daily frame. */
export function LiveClassroom({state}:{state:ClassroomView}){
 const [src,setSrc]=useState<string|null>(null),[status,setStatus]=useState<'idle'|'loading'|'open'|'error'>('idle');
 const request=useRef<AbortController|null>(null),generation=useRef(0);
 useEffect(()=>()=>{generation.current++;request.current?.abort();},[]);
 const frameRef=useRef<HTMLIFrameElement|null>(null);
 useEffect(()=>{
  const frame=frameRef.current;if(!src||!frame)return;
  const version=generation.current;
  const failed=()=>{if(version===generation.current){generation.current++;setSrc(null);setStatus('error');}};
  const timer=setTimeout(failed,20000);
  const loaded=()=>{clearTimeout(timer);if(version===generation.current)setStatus('open');};
  frame.addEventListener('load',loaded);frame.addEventListener('error',failed);
  return ()=>{clearTimeout(timer);frame.removeEventListener('load',loaded);frame.removeEventListener('error',failed);};
 },[src]);
 function leave(){generation.current++;request.current?.abort();request.current=null;setSrc(null);setStatus('idle');}
 async function join(){
  const version=++generation.current;request.current?.abort();const controller=new AbortController();request.current=controller;setSrc(null);setStatus('loading');
  const timer=setTimeout(()=>{if(version===generation.current){generation.current++;controller.abort();setSrc(null);setStatus('error');}},15000);
  try{
   const response=await fetch(state.breakoutRoomId?'/api/live-classroom/breakout-join':'/api/live-classroom/join',{method:'POST',credentials:'same-origin',cache:'no-store',headers:{'Content-Type':'application/json'},body:JSON.stringify(state.breakoutRoomId?{breakoutRoomId:state.breakoutRoomId}:{liveSessionRoomId:state.liveSessionRoomId}),signal:controller.signal});
   if(!response.ok)throw Error();const data:unknown=await response.json();
   if(!data||typeof data!=='object'||!('url'in data)||typeof data.url!=='string'||!('token'in data)||typeof data.token!=='string'||!('expiresAt'in data)||typeof data.expiresAt!=='number'||data.expiresAt<=Date.now()/1000||data.expiresAt>Date.now()/1000+61||!/^[A-Za-z0-9_.-]{1,16384}$/.test(data.token))throw Error();
   const url=new URL(data.url);if(url.protocol!=='https:'||!url.hostname.endsWith('.daily.co')||url.username||url.password||url.port||url.search||url.hash)throw Error();
   url.searchParams.set('t',data.token);url.searchParams.set('embed','true');
   if(version===generation.current)setSrc(url.href);
  }catch{if(version===generation.current){setSrc(null);setStatus('error');}}finally{clearTimeout(timer);}
 }
 return <main className={styles.classroom}>
  <header><p>Live classroom</p><h1>{state.sessionTitle}</h1><p>Cohort: {state.cohortName}</p></header>
  {state.teams?.length&&<nav aria-label="My Teams">{state.teams.map(team=><article key={team.id}><p>{team.name}</p><a href={team.href}>Open My Team</a>{!state.breakoutRoomId&&<p><a href={`/live-classroom/${state.liveSessionRoomId}/teams/${team.id}`}>Open Team breakout</a></p>}</article>)}</nav>}
  {state.masterBreakoutsHref&&<p><a href={state.masterBreakoutsHref}>Team breakouts</a></p>}
  <section aria-labelledby="current-activity"><h2 id="current-activity">Current Activity</h2>
   {state.activity?<ActivitySummary activity={state.activity}/>:state.activityCandidates?.length?<><p>Multiple current Activities are available. Choose your authorized work.</p>{state.activityCandidates.map(a=><ActivitySummary key={a.activityInstanceId} activity={a}/>)}</>:<><p>No current Activity is available in this Session for your authorized work.</p><a href="/current-work">Open Current Activity</a></>}
  </section>
  <section aria-label="Daily live classroom"><h2>Classroom call</h2>
   <p role="status" aria-live="polite">{status==='loading'?'Preparing secure classroom access…':status==='open'?'Daily classroom is open. Complete joining inside the classroom.':status==='error'?'Classroom connection unavailable. Try again.':'You are not connected.'}</p>
   <div className={styles.controls}><button type="button" onClick={join} disabled={status==='loading'||src!==null}>{status==='error'?'Try joining again':'Join classroom'}</button><button type="button" onClick={leave} disabled={status==='idle'}>Leave classroom</button></div>
   {src&&<iframe ref={frameRef} className={styles.frame} title="Daily live classroom" src={src} allow="camera; microphone; fullscreen; display-capture; autoplay" referrerPolicy="no-referrer"/>}
  </section>
 </main>;
}





