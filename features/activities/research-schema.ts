import {z} from 'zod';
export const addActivityResearchReferenceSchema=z.strictObject({activityInstanceId:z.uuid(),entityType:z.enum(['PATENT_RECORD','PATENT_SEARCH_LOG']),entityId:z.uuid()});
export const activityResearchLinkSchema=z.strictObject({id:z.uuid(),activity_instance_id:z.uuid(),entity_type:z.enum(['PATENT_RECORD','PATENT_SEARCH_LOG']),entity_id:z.uuid(),relationship_type:z.literal('OUTPUT_REFERENCE'),created_by:z.uuid(),created_at:z.iso.datetime({offset:true})});
export type ActivityResearchLink=z.infer<typeof activityResearchLinkSchema>;
