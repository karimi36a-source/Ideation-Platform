begin;
-- No invented backfill: validation fails atomically if legacy claim rows lack a real locator.
alter table public.evidence add column claim_locator text;
alter table public.evidence add constraint evidence_claim_locator check(
 (evidence_type='PATENT_CLAIM' and claim_locator is not null and length(private.trim_decision_text(claim_locator))>0)
 or (evidence_type='PATENT' and claim_locator is null)
 or evidence_type not in ('PATENT','PATENT_CLAIM'));
comment on column public.evidence.claim_locator is 'Human/source claim locator only; required for PATENT_CLAIM, null for PATENT. No legal interpretation or inferred backfill.';
create or replace function private.evidence_target_allowed(kind public.evidence_link_entity_type,target uuid,project uuid,workspace uuid,new_link boolean) returns boolean
language sql stable set search_path='' as $$
 select public.can_read_development_project(project) and case
 when kind='DECISION' then exists(select 1 from public.decisions d where d.id=target and d.project_id=project and d.workspace_id=workspace and public.can_read_decision(d.id) and (not new_link or d.status<>'ARCHIVED'))
 when kind in ('GAP','REQUIREMENT') then exists(select 1 from public.development_objects o where o.id=target and o.object_type::text=kind::text and o.project_id=project and o.workspace_id=workspace and (not new_link or o.archived_at is null))
 when kind='ARTIFACT' then exists(select 1 from public.artifacts a where a.id=target and a.project_id=project and a.workspace_id=workspace
  and (not new_link or a.status='ACTIVE')
  and (a.artifact_type<>'MIND_MAP' or public.can_read_private_mind_map(a.id))
  and (a.artifact_type not in ('MINIMUM_ESSENTIAL_STRUCTURE','INVENTION_CONCEPT') or public.can_read_session7_output(a.id)))
 when kind='PATENT_RECORD' then exists(select 1 from public.patent_records p where p.id=target and p.project_id=project and p.workspace_id=workspace)
 else false end;
$$;

drop policy evidence_links_read on public.evidence_links;
create policy evidence_links_read on public.evidence_links for select to authenticated using(
 exists(select 1 from public.evidence e where e.id=evidence_id and (
  (linked_entity_type='DECISION' and exists(select 1 from public.decisions d where d.id=linked_entity_id and d.project_id=e.project_id and d.workspace_id=e.workspace_id))
  or (linked_entity_type in ('GAP','REQUIREMENT') and exists(select 1 from public.development_objects o where o.id=linked_entity_id and o.object_type::text=linked_entity_type::text and o.project_id=e.project_id and o.workspace_id=e.workspace_id))
  or (linked_entity_type='PATENT_RECORD' and exists(select 1 from public.patent_records p where p.id=linked_entity_id and p.project_id=e.project_id and p.workspace_id=e.workspace_id))
  or (linked_entity_type='ARTIFACT' and exists(select 1 from public.artifacts a where a.id=linked_entity_id and a.project_id=e.project_id and a.workspace_id=e.workspace_id))
 )));

create function public.link_patent_to_evidence(input jsonb) returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare actor uuid:=public.current_platform_user_id();p public.patent_records;e public.evidence;k text;kind public.evidence_type;
begin
 if actor is null then
  if auth.uid() is null then raise exception 'Authentication required' using errcode='28000';end if;
  raise exception 'Resource unavailable' using errcode='42501';end if;
 if input is null or jsonb_typeof(input)<>'object' then raise exception 'Invalid Patent Evidence input' using errcode='22023';end if;
 if exists(select 1 from jsonb_object_keys(input) x where x not in ('patentRecordId','evidenceType','title','description','claimLocator')) then raise exception 'Invalid Patent Evidence input' using errcode='22023';end if;
 foreach k in array array['patentRecordId','evidenceType','title','description'] loop
  if jsonb_typeof(input->k) is distinct from 'string' or coalesce(length(private.trim_decision_text(input->>k)),0)=0 then raise exception 'Invalid Patent Evidence input' using errcode='22023';end if;
 end loop;
 if input->>'evidenceType' not in ('PATENT','PATENT_CLAIM') then raise exception 'Invalid Patent Evidence type' using errcode='22023';end if;
 kind:=(input->>'evidenceType')::public.evidence_type;
 if (kind='PATENT' and input?'claimLocator') or (kind='PATENT_CLAIM' and (jsonb_typeof(input->'claimLocator') is distinct from 'string' or coalesce(length(private.trim_decision_text(input->>'claimLocator')),0)=0)) then raise exception 'Invalid claim locator' using errcode='22023';end if;
 select * into p from public.patent_records where id=(input->>'patentRecordId')::uuid;
 if p.id is null or not public.can_read_development_project(p.project_id) then raise exception 'Resource unavailable' using errcode='42501';end if;
 perform public.require_development_object_write(p.project_id,p.workspace_id);
 -- Parent authority is locked first; source metadata is then locked and reread.
 select * into p from public.patent_records where id=p.id for share;
 if p.id is null or not public.can_read_development_project(p.project_id) then raise exception 'Resource unavailable' using errcode='42501';end if;
 insert into public.evidence(project_id,workspace_id,evidence_type,title,description,source_name,source_url,file_id,verification_status,verified_by,verified_at,created_by,captured_at,metadata,updated_by,archived_at,claim_locator)
 values(p.project_id,p.workspace_id,kind,input->>'title',input->>'description',p.source_database::text||': '||p.publication_number,p.source_url,null,'UNVERIFIED',null,null,actor,clock_timestamp(),'{}',actor,null,input->>'claimLocator') returning * into e;
 insert into public.evidence_links(evidence_id,linked_entity_type,linked_entity_id,relationship_type,created_by)
 values(e.id,'PATENT_RECORD',p.id,'RELATED_TO',actor);
 if public.current_platform_user_id() is distinct from actor then raise exception 'Resource unavailable' using errcode='42501';end if;
 return to_jsonb(e);
end$$;
revoke all on function public.link_patent_to_evidence(jsonb) from public,anon,authenticated,service_role;
grant execute on function public.link_patent_to_evidence(jsonb) to authenticated;
-- Generic linkEvidence retains all accepted mutation/target checks, including its
-- existing PATENT_RECORD dependency denial; only this narrow operation creates patent provenance.
comment on function public.link_patent_to_evidence(jsonb) is 'M12.14 atomic UNVERIFIED source-backed Evidence + RELATED_TO Patent provenance. No deduplication, verification, source fetch, analysis or sharing.';
commit;
