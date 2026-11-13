import {z} from "zod";
import {shareEntityTypes} from "./schema";
import {artifactTypeSchema} from "@/features/artifacts/schema";
import {developmentObjectTypeSchema} from "@/features/projects/object-schema";
import {productClassificationSchema} from "@/features/mind-map/classification-schema";
import {evidenceTypeSchema,evidenceVerificationStatusSchema} from "@/features/evidence/schema";
import {patentSourceDatabaseSchema} from "@/features/patents/schema";
import {scamperLensSchema} from "@/features/scamper/schema";

export const mvpShareModeSchema=z.literal("SNAPSHOT");
const timestamp=z.iso.datetime({offset:true});
const nullableText=z.string().nullable();
export const shareSnapshotContentSchemas={
 ARTIFACT:z.strictObject({artifact_type:artifactTypeSchema,title:z.string(),version_number:z.number().int().positive(),version_label:nullableText,content_snapshot:z.json()}),
 DEVELOPMENT_OBJECT:z.strictObject({object_type:developmentObjectTypeSchema,title:z.string(),content:z.string(),current_version_number:z.number().int().positive(),product_classification:productClassificationSchema.nullable()}),
 FILE:z.strictObject({filename:z.string(),mime_type:z.string(),size:z.number().int().nonnegative()}),
 EVIDENCE:z.strictObject({evidence_type:evidenceTypeSchema,title:z.string(),description:z.string(),source_name:z.string(),source_url:nullableText,claim_locator:nullableText,verification_status:evidenceVerificationStatusSchema}),
 PATENT_RECORD:z.strictObject({publication_number:z.string(),application_number:nullableText,title:z.string(),applicant:nullableText,inventor:nullableText,
  priority_date:z.iso.date().nullable(),filing_date:z.iso.date().nullable(),publication_date:z.iso.date().nullable(),ipc_cpc:nullableText,
  source_database:patentSourceDatabaseSchema,source_url:z.string(),abstract_text:nullableText}),
 SCAMPER_ENTRY:z.strictObject({scamper_type:scamperLensSchema,original_element:z.string(),proposed_change:z.string(),result_text:z.string()}),
};
const provenance=z.strictObject({
 share_id:z.uuid(),source_entity_type:z.enum(shareEntityTypes),source_entity_id:z.uuid(),source_version_id:z.uuid().nullable(),
 source_workspace_id:z.uuid(),source_owner_user_id:z.uuid().nullable(),source_owner_team_id:z.uuid().nullable(),
 source_created_by:z.uuid(),source_version_created_by:z.uuid().nullable(),snapshot_created_at:timestamp,
});
/** Persistence only. There is no recipient read or public Snapshot-write API. */
export const shareSnapshotSchema=z.strictObject({
 id:z.uuid(),share_id:z.uuid(),source_version_id:z.uuid().nullable(),
 snapshot_data:z.strictObject({provenance,content:z.record(z.string(),z.json())}),created_at:timestamp,
}).refine(row=>row.share_id===row.snapshot_data.provenance.share_id&&row.source_version_id===row.snapshot_data.provenance.source_version_id,
 "Snapshot identity/provenance mismatch")
 .refine(row=>Date.parse(row.created_at)===Date.parse(row.snapshot_data.provenance.snapshot_created_at),"Snapshot timestamp mismatch")
 .refine(row=>(row.snapshot_data.provenance.source_entity_type==="ARTIFACT")===(row.source_version_id!==null),"Invalid source Version binding")
 .refine(row=>shareSnapshotContentSchemas[row.snapshot_data.provenance.source_entity_type].safeParse(row.snapshot_data.content).success,"Invalid canonical content projection");
export type ShareSnapshot=z.infer<typeof shareSnapshotSchema>;
