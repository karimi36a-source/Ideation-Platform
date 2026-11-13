import {z} from 'zod';
const count=z.number().int().nonnegative();
export const learningProgressCountsSchema=z.strictObject({
 requiredActivitiesTotal:count,completedRequiredActivities:count,inProgressActivities:count,
 blockedActivities:count,notStartedActivities:count,
 optionalActivities:z.strictObject({total:count,completed:count}).refine(v=>v.completed<=v.total),
 completionPercentage:z.number().min(0).max(100).nullable(),
}).refine(v=>v.completedRequiredActivities+v.inProgressActivities+v.blockedActivities+v.notStartedActivities===v.requiredActivitiesTotal)
 .refine(v=>v.completionPercentage===(v.requiredActivitiesTotal===0?null:Math.round(v.completedRequiredActivities*1000/v.requiredActivitiesTotal)/10));
const identity=z.strictObject({id:z.uuid(),name:z.string()});
export const myLearningProgressSchema=z.strictObject({contexts:z.array(z.strictObject({
 id:z.uuid(),enrollmentId:z.uuid(),course:identity,cohort:identity,project:identity,
 workspace:z.strictObject({id:z.uuid(),type:z.enum(['PERSONAL','TEAM'])}),team:identity.nullable(),
 currentSessions:z.array(z.strictObject({id:z.uuid(),title:z.string(),sessionNumber:z.number().int(),sequence:z.number().int()})),
 progress:learningProgressCountsSchema,
}))}).refine(v=>new Set(v.contexts.map(c=>c.id)).size===v.contexts.length);
export type MyLearningProgress=z.infer<typeof myLearningProgressSchema>;
