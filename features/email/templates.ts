import 'server-only';
import {z} from 'zod';

export type EmailTemplateDefinition=Readonly<{id:string;variablesSchema:z.ZodObject;render:(variables:Record<string,unknown>)=>unknown}>;
// Minimal server-owned rendering seam. No templates or notification eligibility
// are seeded here. All text is plain text; links have a separate route boundary.
const text=z.string().trim().min(1).max(16000).refine(v=>!/(?:[a-z][a-z0-9+.-]*:|www\.|(?:[a-z0-9-]+\.)+[a-z]{2,63}\b)/i.test(v));
const uuid='[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}';
// Only existing authenticated FICI routes; no queries, fragments, encoded paths,
// token-bearing auth/recovery routes, external origins or magic links.
export const emailRelativePathSchema=z.string().refine(v=>v==='/account'||new RegExp('^/projects/'+uuid+'/patents$').test(v)||new RegExp('^/activities/'+uuid+'/mind-map$').test(v));
export const renderedEmailSchema=z.strictObject({subject:text.pipe(z.string().max(160)).refine(v=>!/[\r\n]/.test(v)),text,relativePath:emailRelativePathSchema.optional()});
export function createEmailTemplateRegistry(definitions:readonly EmailTemplateDefinition[]){
 const registry=new Map<string,EmailTemplateDefinition>();
 for(const d of definitions){
  if(!/^[A-Z][A-Z0-9_]{0,63}$/.test(d.id)||registry.has(d.id)||!(d.variablesSchema instanceof z.ZodObject)||typeof d.render!=='function')throw new Error('Invalid email template configuration');
  registry.set(d.id,Object.freeze({id:d.id,variablesSchema:d.variablesSchema.strict(),render:d.render}));
 }
 return (id:string,variables:unknown)=>{
  const definition=registry.get(id);if(!definition)return null;
  const input=definition.variablesSchema.safeParse(variables);if(!input.success)return null;
  const rendered=renderedEmailSchema.safeParse(definition.render(input.data));return rendered.success?rendered.data:null;
 };
}
