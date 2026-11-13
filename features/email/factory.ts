import 'server-only';
import {getServerEnv} from '@/lib/validation/env-server';
import {getAuthSiteUrl} from '@/lib/auth/site-url';
import type {EmailProvider} from './provider';
import type {EmailTemplateDefinition} from './templates';
import {ResendEmailProvider} from './providers/resend';
/** Composition root only. Empty registry enables no business emails. Later
 * server policy may register approved templates and explicitly invoke send. */
export function createEmailProvider(templates:readonly EmailTemplateDefinition[]=[],transport:typeof fetch=fetch):EmailProvider{
 try{const env=getServerEnv();return new ResendEmailProvider({apiKey:env.RESEND_API_KEY,from:env.RESEND_FROM_EMAIL,siteOrigin:getAuthSiteUrl()},templates,transport);}
 catch{return new ResendEmailProvider({},templates,transport);}
}
