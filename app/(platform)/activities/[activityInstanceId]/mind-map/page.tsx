import {notFound} from "next/navigation";
import {MindMapEditor} from "@/features/mind-map/editor";
import {getMindMapEditor} from "@/features/mind-map/editor-service";

export const dynamic="force-dynamic";
async function load(activityInstanceId:string){try{return await getMindMapEditor(activityInstanceId);}catch{return notFound();}}
export default async function MindMapPage({params}:{params:Promise<{activityInstanceId:string}>}){
 const {activityInstanceId}=await params;
 const state=await load(activityInstanceId);
 return <MindMapEditor activityInstanceId={activityInstanceId} initialState={state}/>;
}
