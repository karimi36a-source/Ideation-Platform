import {beforeEach,afterEach,expect,it,vi} from "vitest";
const sdk=vi.hoisted(()=>({options:null as null|{authEndpoint:(room:string)=>Promise<unknown>},enter:vi.fn(),leave:vi.fn(),broadcast:vi.fn(),listeners:new Map<string,(value:never)=>void>()}));
vi.mock("@liveblocks/client",()=>({createClient:(options:typeof sdk.options)=>{sdk.options=options;return {enterRoom:sdk.enter};}}));
import {createMindMapLiveClient} from "@/features/mind-map/collaboration-client";
import {openMindMapCollaboration} from "@/features/mind-map/collaboration-session";
const activity="00000000-0000-4000-8000-000000000001",map="00000000-0000-4000-8000-000000000002";
const fetcher=vi.fn();
beforeEach(()=>{vi.stubGlobal("fetch",fetcher);fetcher.mockReset().mockResolvedValue({ok:true,json:async()=>({ok:true,data:{token:"unit-token"}})});sdk.enter.mockReset().mockReturnValue({leave:sdk.leave,room:{subscribe:(name:string,callback:(value:never)=>void)=>{sdk.listeners.set(name,callback);return vi.fn();},getStatus:()=>"connected",broadcastEvent:sdk.broadcast}});sdk.leave.mockReset();sdk.broadcast.mockReset();sdk.listeners.clear();});
afterEach(()=>vi.unstubAllGlobals());
it("preauthorizes before connection timeout and still rechecks every subsequent SDK auth",async()=>{
 const instance=createMindMapLiveClient(activity,map);await instance.prepare();expect(fetcher).toHaveBeenCalledTimes(1);
 expect(await sdk.options!.authEndpoint(instance.roomId)).toEqual({token:"unit-token"});expect(fetcher).toHaveBeenCalledTimes(1);
 await sdk.options!.authEndpoint(instance.roomId);expect(fetcher).toHaveBeenCalledTimes(2);
 expect(fetcher).toHaveBeenLastCalledWith("/api/v1/mind-map/collaboration-auth",expect.objectContaining({credentials:"same-origin",cache:"no-store",body:JSON.stringify({activityInstanceId:activity})}));
 await sdk.options!.authEndpoint("mind-map:foreign");expect(fetcher).toHaveBeenCalledTimes(2);
});
it("does not enter provider on denied/malformed auth, and exposes a generic offline state",async()=>{
 fetcher.mockResolvedValue({ok:false});const status=vi.fn(),session=openMindMapCollaboration(activity,map,{event:vi.fn(),status});
 await vi.waitFor(()=>expect(status).toHaveBeenCalledWith("offline"));expect(sdk.enter).not.toHaveBeenCalled();session.close();
});
it("does not join after unmount while FICI authorization is pending",async()=>{
 let resolve!:(value:unknown)=>void;fetcher.mockReturnValue(new Promise(r=>resolve=r));const session=openMindMapCollaboration(activity,map,{event:vi.fn(),status:vi.fn()});session.close();resolve({ok:true,json:async()=>({ok:true,data:{token:"unit-token"}})});await new Promise(r=>setTimeout(r,0));expect(sdk.enter).not.toHaveBeenCalled();
});
it("accepts validated events only, never writes canonical data, and cleans subscriptions",async()=>{
 const event=vi.fn(),session=openMindMapCollaboration(activity,map,{event,status:vi.fn()});await vi.waitFor(()=>expect(sdk.enter).toHaveBeenCalledTimes(1));
 sdk.listeners.get("event")!({event:{type:"mind-map-move",nodeId:map,revision:0,x:1,y:2},user:{canWrite:true}} as never);expect(event).toHaveBeenCalledTimes(1);
 sdk.listeners.get("event")!({event:{type:"mind-map-move",nodeId:map,revision:0,x:9,y:9},user:{canWrite:false}} as never);expect(event).toHaveBeenCalledTimes(1);
 sdk.listeners.get("event")!({event:{type:"mind-map-reload",nodes:["fabricated"]}} as never);expect(event).toHaveBeenCalledTimes(1);
 session.send({type:"mind-map-reload"});expect(sdk.broadcast).toHaveBeenCalledWith({type:"mind-map-reload"});expect(fetcher).toHaveBeenCalledTimes(1);session.close();expect(sdk.leave).toHaveBeenCalledTimes(1);
});
