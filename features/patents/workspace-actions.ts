"use server";
import {z} from 'zod';
import {revalidatePath} from 'next/cache';
import {getPatentWorkspace} from './workspace';
import {createPatentRecord} from './create';
import {createPatentSearchLog} from './search';
import {linkPatentToEvidence} from './evidence';
import {createPatentRecordSchema} from './create-schema';
import {createPatentSearchLogSchema} from './search-schema';
import {linkPatentToEvidenceSchema} from './evidence-schema';
import {savePatentReadingFrameworkSchema} from './reading-schema';
import {savePatentReadingFramework} from './reading';
const operation=z.discriminatedUnion('operation',[
 z.strictObject({operation:z.literal('retain'),projectId:z.uuid(),input:createPatentRecordSchema}),
 z.strictObject({operation:z.literal('searchLog'),projectId:z.uuid(),input:createPatentSearchLogSchema}),
 z.strictObject({operation:z.literal('evidence'),projectId:z.uuid(),input:linkPatentToEvidenceSchema}),
 z.strictObject({operation:z.literal('reading'),projectId:z.uuid(),input:savePatentReadingFrameworkSchema}),
]);
export async function mutatePatentWorkspace(raw:unknown){
 const parsed=operation.safeParse(raw);if(!parsed.success)return {ok:false,message:'Check the required fields and try again.'};
 try{
  const v=parsed.data;const state=await getPatentWorkspace(v.projectId);
  if(!state.canEdit)return {ok:false,message:'This workspace is read-only.'};
  if(v.operation==='reading'){
   if(!state.patents.some(p=>p.id===v.input.patentRecordId)||!state.activities.some(a=>a.id===v.input.activityInstanceId))return {ok:false,message:'The reading context is unavailable.'};
   await savePatentReadingFramework(v.input);
  }else if(v.operation==='evidence'){
   if(!state.patents.some(p=>p.id===v.input.patentRecordId))return {ok:false,message:'The record is unavailable.'};
   await linkPatentToEvidence(v.input);
  }else{
   if(v.input.projectId!==state.project.id||v.input.workspaceId!==state.project.primary_workspace_id)return {ok:false,message:'The workspace is unavailable.'};
   if(v.operation==='retain')await createPatentRecord(v.input);
   else await createPatentSearchLog(v.input);
  }
  revalidatePath('/projects/'+v.projectId+'/patents');return {ok:true,message:'Saved.'};
 }catch{return {ok:false,message:'Unable to save. Check the fields and your current access, then try again.'};}
}
