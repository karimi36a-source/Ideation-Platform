// @vitest-environment jsdom
import {afterEach,expect,it,vi} from 'vitest';
import {cleanup,render,screen} from '@testing-library/react';
vi.mock('next/navigation',()=>({useRouter:()=>({refresh:vi.fn()})}));
vi.mock('@/features/patents/workspace-actions',()=>({mutatePatentWorkspace:vi.fn()}));
import {PatentWorkspace} from '@/features/patents/workspace-view';
import type {PatentWorkspaceState} from '@/features/patents/workspace';
const id='00000000-0000-4000-8000-000000006004',time='2026-10-27T00:00:00Z';
const empty:PatentWorkspaceState={project:{id,name:'Canonical Project',description:'Existing invention',project_type:'individual',owner_user_id:id,owner_team_id:null,primary_workspace_id:id,status:'active',current_stage:null,confidentiality_level:null,created_at:time,updated_at:time,archived_at:null,required_workspace_type:'PERSONAL'},canEdit:true,patents:[],logs:[],links:[],evidence:[],objects:[],artifacts:[],versions:[],activities:[]};
afterEach(cleanup);
it('renders six learner notes separately from source metadata and preserves the saved Version',()=>{
 const notes={title:'Learner title interpretation',abstract:'Learner abstract interpretation',description:'Learner structure',claims:'Learner claim references',drawings:'Learner figure notes',bibliographic_information:'Learner date notes'};
 const artifact={id,project_id:id,workspace_id:id,artifact_type:'PATENT_READING_FRAMEWORK' as const,title:'Patent Reading Framework',status:'ACTIVE' as const,current_version_id:null,created_by:id,activity_instance_id:id,review_required:false,approval_required:false,created_at:time,updated_at:time,archived_at:null};
 const patent={id,project_id:id,workspace_id:id,publication_number:'WO SOURCE',application_number:null,title:'Original source title',applicant:null,inventor:null,priority_date:null,filing_date:null,publication_date:null,ipc_cpc:null,source_database:'PATENTSCOPE' as const,source_url:'https://patentscope.wipo.int/',abstract_text:'Original source abstract',relevance_status:'NOT_REVIEWED' as const,why_retained:null,created_by:id,created_at:time};
 render(<PatentWorkspace state={{...empty,patents:[patent],artifacts:[artifact],versions:[{id,artifact_id:id,version_number:1,status:'DRAFT',draft_revision:1,content_snapshot:{learner_notes:notes,source_patent_record_ids:[id]}}],activities:[{id,status:'active',configuration_snapshot:{method_type:'patent_research'}}]}}/>);
 for(const [section,value] of Object.entries(notes)){expect((screen.getByRole('textbox',{name:section.replaceAll('_',' ')+' — learner notes'}) as HTMLTextAreaElement).value).toBe(value);expect(screen.getByText(value,{selector:'dd'})).toBeTruthy();}
 expect(screen.getByText('Original source abstract',{selector:'dd'})).toBeTruthy();expect(screen.getByRole('button',{name:'Save reading framework'})).toBeTruthy();
});
it('renders safe partial/empty context and navigation-only public sources',()=>{render(<PatentWorkspace state={empty}/>);for(const text of ['No project references are available yet.','No search logs yet.','No retained patents yet.','No linked Patent Evidence yet.'])expect(screen.getByText(text)).toBeTruthy();expect(screen.queryByRole('button',{name:/compar|similarity|novelty|patentability/i})).toBeNull();expect(screen.queryByText(/automated comparison|similarity score/i)).toBeNull();const links=screen.getAllByRole('link').filter(a=>a.getAttribute('target')==='_blank');expect(links.map(a=>a.getAttribute('href'))).toEqual(['https://patentscope.wipo.int/','https://www.uspto.gov/patents/search','https://patents.google.com/']);for(const a of links)expect(a.getAttribute('rel')).toBe('noopener noreferrer');expect(screen.getByText('Retain a patent')).toBeTruthy();expect(screen.getByText('Create source-backed Evidence')).toBeTruthy();});
it('renders canonical source, private human notes, search process, PATENT and claim locator distinctly',()=>{
 const patent={id,project_id:id,workspace_id:id,publication_number:'WO 123 A1',application_number:null,title:'Canonical patent',applicant:'Applicant',inventor:'Inventor',priority_date:null,filing_date:null,publication_date:null,ipc_cpc:'G01',source_database:'USPTO' as const,source_url:'https://example.test/patent',abstract_text:'Source abstract text',relevance_status:'POSSIBLY_RELEVANT' as const,why_retained:'Private research rationale',created_by:id,created_at:time};
 const evidence={id,project_id:id,workspace_id:id,evidence_type:'PATENT' as const,title:'Canonical evidence',description:'Human source observations',source_name:'USPTO: WO 123 A1',source_url:patent.source_url,file_id:null,verification_status:'UNVERIFIED' as const,verified_by:null,verified_at:null,created_by:id,captured_at:time,metadata:{},created_at:time,updated_at:time,updated_by:id,archived_at:null,claim_locator:null};
 render(<PatentWorkspace state={{...empty,patents:[patent],logs:[{id,project_id:id,workspace_id:id,activity_instance_id:id,database_name:'USPTO',query_text:'Private query',search_method:'Keyword family',reason:'Research strategy',searched_at:time,searched_by:id,results_reviewed_count:2,relevant_results_count:1,terms_learned:['term'],classifications_learned:['G01'],notes:'Search notes'}],evidence:[evidence,{...evidence,id:'00000000-0000-4000-8000-000000006005',evidence_type:'PATENT_CLAIM',claim_locator:'Claims 7–9',title:'Claim evidence'}],links:[{id,evidence_id:id,linked_entity_type:'PATENT_RECORD',linked_entity_id:id,relationship_type:'RELATED_TO',notes:null,created_by:id,created_at:time,archived_at:null}]}}/>);
 for(const text of ['Private research rationale','POSSIBLY_RELEVANT','Claim locator: Claims 7–9','Search notes','Human source observations'])expect(screen.getAllByText(text).length).toBeGreaterThan(0);
 expect(screen.getByText('Source abstract',{selector:'dt'}).nextElementSibling?.textContent).toBe('Source abstract text');
 expect(screen.getAllByText('Why retained / human research notes').some(label=>label.tagName==='DT'&&label.nextElementSibling?.textContent==='Private research rationale')).toBe(true);
 expect(screen.getByRole('heading',{name:'Retained Patent Records — source metadata'})).toBeTruthy();
 expect(screen.getByRole('heading',{name:'Source-backed Project Evidence'})).toBeTruthy();
 expect(screen.getByText('Evidence verification describes research review, not legal validity. AI analysis is not part of this workspace.')).toBeTruthy();
 expect(screen.queryByText('AI Analysis',{exact:true})).toBeNull();
 expect(screen.getByRole('heading',{name:'PATENT — Canonical evidence'})).toBeTruthy();expect(screen.getByRole('heading',{name:'PATENT_CLAIM — Claim evidence'})).toBeTruthy();
 expect(screen.queryByText(/^(PATENTABLE|NOT PATENTABLE|NOVEL|NOT NOVEL|INFRINGEMENT|CLEAR TO OPERATE|VALID|INVALID)$/)).toBeNull();
});
it('read-only access does not render mutation forms',()=>{render(<PatentWorkspace state={{...empty,canEdit:false}}/>);expect(screen.queryByText('Retain a patent')).toBeNull();expect(screen.getByText('This research workspace is read-only.')).toBeTruthy();});

it('references existing Invention Concept V1 and canonical Object IDs without recreating them',()=>{
 const artifact={id,project_id:id,workspace_id:id,artifact_type:'INVENTION_CONCEPT' as const,title:'Invention Concept V1',status:'ACTIVE' as const,current_version_id:null,created_by:id,activity_instance_id:null,review_required:false,approval_required:false,created_at:time,updated_at:time,archived_at:null};
 render(<PatentWorkspace state={{...empty,artifacts:[artifact],versions:[{id,artifact_id:id,version_number:1,status:'DRAFT'}],objects:[{id,project_id:id,workspace_id:id,object_type:'GAP',title:'Canonical Gap',content:'Existing gap',status:null,verification_status:null,origin_type:null,origin_reference_id:null,created_by:id,current_version_number:1,archived_at:null,metadata:{},created_at:time,updated_at:time}]}}/>);
 expect(screen.getByText('INVENTION_CONCEPT: Invention Concept V1 · Artifact '+id+' · No current Version')).toBeTruthy();
 expect(screen.getByText('V1 · DRAFT · Version '+id)).toBeTruthy();expect(screen.getByText('Existing gap')).toBeTruthy();
});
