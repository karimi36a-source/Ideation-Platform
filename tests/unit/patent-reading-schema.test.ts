import {expect,it} from 'vitest';
import {patentReadingNotesSchema,patentReadingSnapshotSchema,savePatentReadingFrameworkSchema} from '@/features/patents/reading-schema';
import {artifactTypeSchema} from '@/features/artifacts/schema';
const id='00000000-0000-4000-8000-000000006004';
const notes={title:'My reading',abstract:'Purpose',description:'Structure',claims:'Claim references',drawings:'Figure references',bibliographic_information:'Family and dates'};
it('accepts the approved canonical Artifact and six learner sections',()=>{
 expect(artifactTypeSchema.parse('PATENT_READING_FRAMEWORK')).toBe('PATENT_READING_FRAMEWORK');
 expect(patentReadingSnapshotSchema.parse({learner_notes:notes,source_patent_record_ids:[id]}).learner_notes).toEqual(notes);
});
it.each(['title','abstract','description','claims','drawings','bibliographic_information'])('requires section %s',key=>{
 const incomplete={...notes} as Record<string,string>;delete incomplete[key];expect(patentReadingNotesSchema.safeParse(incomplete).success).toBe(false);
});
it.each(['createdBy','workspaceId','projectId','sourceUrl','verified','noveltyScore','artifactType'])('rejects client override %s',key=>expect(savePatentReadingFrameworkSchema.safeParse({activityInstanceId:id,patentRecordId:id,notes,[key]:id}).success).toBe(false));
it('does not accept copied source fields as part of the structured notes',()=>expect(patentReadingNotesSchema.safeParse({...notes,source_abstract:'Source text'}).success).toBe(false));
