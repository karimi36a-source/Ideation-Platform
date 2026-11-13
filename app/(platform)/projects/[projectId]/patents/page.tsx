import {notFound} from 'next/navigation';
import {getPatentWorkspace} from '@/features/patents/workspace';
import {PatentWorkspace} from '@/features/patents/workspace-view';
export const dynamic='force-dynamic';
export default async function PatentWorkspacePage({params}:{params:Promise<{projectId:string}>}){
 const {projectId}=await params;
 const state=await getPatentWorkspace(projectId).catch(()=>notFound());
 return <PatentWorkspace state={state}/>;
}
