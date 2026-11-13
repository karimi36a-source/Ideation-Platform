import {describe,expect,it} from 'vitest';
import {patentRecordSchema,patentRelevanceStatusSchema,patentSourceDatabaseSchema} from '@/features/patents/schema';
const id='00000000-0000-4000-8000-000000006004';
const row={id,project_id:id,workspace_id:id,publication_number:' WO 2025/012345 A1 ',application_number:null,title:'Retained source',applicant:null,inventor:null,priority_date:null,filing_date:null,publication_date:null,ipc_cpc:null,source_database:'PATENTSCOPE',source_url:'https://research.example.test/patent?q=WO%202025',abstract_text:null,relevance_status:'NOT_REVIEWED',why_retained:null,created_by:id,created_at:'2026-10-26T00:00:00Z'};
describe('Patent Record persistence vocabulary',()=>{
 it.each(patentSourceDatabaseSchema.options)('accepts source %s',source_database=>expect(patentRecordSchema.safeParse({...row,source_database}).success).toBe(true));
 it.each(patentRelevanceStatusSchema.options)('accepts human classification %s',relevance_status=>expect(patentRecordSchema.safeParse({...row,relevance_status}).success).toBe(true));
 it.each(['CUSTOM','EPO','google_patents',''])('rejects source %s',source_database=>expect(patentRecordSchema.safeParse({...row,source_database}).success).toBe(false));
 it.each(['APPROVED','PATENTABLE','NOVEL','VALID','FTO_CLEAR',''])('rejects conclusion/status %s',relevance_status=>expect(patentRecordSchema.safeParse({...row,relevance_status}).success).toBe(false));
 it.each(['http://example.test','ftp://example.test','javascript:alert(1)','https://','https://example.test:bad/a','https://exa mple.test','https://example.test\\bad'])('rejects source URL %s',source_url=>expect(patentRecordSchema.safeParse({...row,source_url}).success).toBe(false));
 it.each(['https://other-research.example.test/patent','https://[::1]/source','HTTPS://Example.test/Source?q=A%20B'])('permits HTTPS without domain allowlist %s',source_url=>expect(patentRecordSchema.parse({...row,source_url}).source_url).toBe(source_url));
 it('preserves number formatting without normalization',()=>expect(patentRecordSchema.parse(row).publication_number).toBe(row.publication_number));
 it('accepts optional text and source dates',()=>expect(patentRecordSchema.safeParse({...row,applicant:'Original applicant',inventor:'Original inventor',ipc_cpc:'A01B 1/00',priority_date:'2020-02-29',filing_date:'2021-01-01',publication_date:'2022-02-03'}).success).toBe(true));
 it('rejects impossible dates',()=>expect(patentRecordSchema.safeParse({...row,priority_date:'2025-02-30'}).success).toBe(false));
 it.each(['novelty_score','patentability_status','infringement_risk','legal_status_conclusion','fto_conclusion'])('rejects extra legal field %s',key=>expect(patentRecordSchema.safeParse({...row,[key]:'positive'}).success).toBe(false));
 it.each(['id','project_id','workspace_id','publication_number','title','source_database','source_url','relevance_status','created_by'])('requires %s',key=>{const copy:Record<string,unknown>={...row};delete copy[key];expect(patentRecordSchema.safeParse(copy).success).toBe(false);});
});
