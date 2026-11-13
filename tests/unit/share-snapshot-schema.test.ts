import {describe,expect,it} from "vitest";
import {mvpShareModeSchema,shareSnapshotSchema} from "@/features/shares/snapshot-schema";
const id="00000000-0000-4000-8000-000000000001";
const time="2026-10-30T12:00:00Z";
const row={id,share_id:id,source_version_id:id,created_at:time,snapshot_data:{
 provenance:{share_id:id,source_entity_type:"ARTIFACT",source_entity_id:id,source_version_id:id,source_workspace_id:id,
 source_owner_user_id:null,source_owner_team_id:id,source_created_by:id,source_version_created_by:id,snapshot_created_at:time},
 content:{artifact_type:"DEVELOPED_CONCEPT",title:"Selected V2",version_number:2,version_label:null,content_snapshot:{notes:"Frozen"}},
}};
describe("M13.2 frozen Snapshot persistence",()=>{
 it("accepts canonical versioned provenance",()=>expect(shareSnapshotSchema.safeParse(row).success).toBe(true));
 it("does not enable LIVE_REFERENCE through vocabulary",()=>{
  expect(mvpShareModeSchema.safeParse("SNAPSHOT").success).toBe(true);
  expect(mvpShareModeSchema.safeParse("LIVE_REFERENCE").success).toBe(false);
 });
 it("rejects fabricated binding, timestamps and extra graph envelopes",()=>{
  for(const value of [
   {...row,source_version_id:null},
   {...row,created_at:"2026-10-31T12:00:00Z"},
   {...row,snapshot_data:{...row.snapshot_data,workspace:{siblings:[]}}},
   {...row,snapshot_data:{...row.snapshot_data,content:{...row.snapshot_data.content,workspace:{siblings:[]}}}},
   {...row,snapshot_data:{...row.snapshot_data,provenance:{...row.snapshot_data.provenance,source_entity_type:"FILE"}}},
  ])expect(shareSnapshotSchema.safeParse(value).success).toBe(false);
 });
 it("accepts genuinely unversioned provenance without a fabricated Version UUID",()=>{
  expect(shareSnapshotSchema.safeParse({...row,source_version_id:null,snapshot_data:{...row.snapshot_data,content:{filename:"selected.txt",mime_type:"text/plain",size:3},
   provenance:{...row.snapshot_data.provenance,source_entity_type:"FILE",source_version_id:null,source_version_created_by:null}}}).success).toBe(true);
 });
});
