import {expect,it} from 'vitest';
import {aiContextReferenceSchema,aiContextEntityTypeSchema,aiContextRoleSchema} from '@/features/ai/context-schema';
const id='00000000-0000-4000-8000-000000006004';
const row={id,ai_output_id:id,entity_type:'ARTIFACT_VERSION',entity_id:id,context_role:'CURRENT_ARTIFACT',included_snapshot_hash:'a'.repeat(64),share_snapshot_id:null,permission_scope:{access:'SOURCE'}};
it('parses exact version provenance without granting source access',()=>{
 expect(aiContextReferenceSchema.parse(row)).toEqual(row);
 expect(aiContextReferenceSchema.parse({...row,share_snapshot_id:id,permission_scope:{access:'SHARE_SNAPSHOT'}}).share_snapshot_id).toBe(id);
 for(const bad of [{entity_type:'FILE'},{entity_type:'ARTIFACT'},{context_role:'EVIDENCE'},{permission_scope:{access:'SOURCE',members:[]}},{included_snapshot_hash:'url'},{share_snapshot_id:id},{canView:true}])expect(aiContextReferenceSchema.safeParse({...row,...bad}).success).toBe(false);
});
it('uses only canonical supported source kinds and approved context roles including narrow Brainstorm context',()=>{
 expect(aiContextEntityTypeSchema.options).toHaveLength(9);
 expect(aiContextRoleSchema.options).toHaveLength(10);
 const kinds=['PROJECT','ARTIFACT_VERSION','ARTIFACT_VERSION','DECISION','FEEDBACK_ITEM','EVIDENCE','PATENT_RECORD','DEVELOPMENT_OBJECT','ACTIVITY_INSTANCE','BRAINSTORM_ENTRY'];
 aiContextRoleSchema.options.forEach((context_role,i)=>expect(aiContextReferenceSchema.safeParse({...row,context_role,entity_type:kinds[i]}).success).toBe(true));
});
it('M14.19 exact Brainstorm provenance cannot become Share-derived context',()=>{
 expect(aiContextReferenceSchema.safeParse({...row,entity_type:'BRAINSTORM_ENTRY',context_role:'BRAINSTORM'}).success).toBe(true);
 expect(aiContextReferenceSchema.safeParse({...row,entity_type:'BRAINSTORM_ENTRY',context_role:'BRAINSTORM',share_snapshot_id:id,permission_scope:{access:'SHARE_SNAPSHOT'}}).success).toBe(false);
});
