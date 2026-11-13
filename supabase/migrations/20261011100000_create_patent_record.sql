begin;
create function public.create_patent_record(input jsonb) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare actor uuid:=public.current_platform_user_id();p uuid;w uuid;k text;r public.patent_records;
 required text[]:=array['projectId','workspaceId','publicationNumber','title','sourceDatabase','sourceUrl'];
 allowed text[]:=array['projectId','workspaceId','publicationNumber','applicationNumber','title','applicant','inventor','priorityDate','filingDate','publicationDate','ipcCpc','sourceDatabase','sourceUrl','abstractText','whyRetained','relevanceStatus'];
begin
 if actor is null then
  if auth.uid() is null then raise exception 'Authentication required' using errcode='28000';end if;
  raise exception 'Resource unavailable' using errcode='42501';end if;
 if input is null or jsonb_typeof(input)<>'object' then raise exception 'Invalid Patent input' using errcode='22023';end if;
 if exists(select 1 from jsonb_object_keys(input) x where not (x=any(allowed))) then raise exception 'Invalid Patent input' using errcode='22023';end if;
 foreach k in array required loop
  if not (input?k) or jsonb_typeof(input->k)<>'string' then raise exception 'Invalid Patent input' using errcode='22023';end if;
 end loop;
 foreach k in array allowed loop
  if input?k and jsonb_typeof(input->k) not in ('string','null') then raise exception 'Invalid Patent input' using errcode='22023';end if;
 end loop;
 if length(btrim(input->>'publicationNumber'))=0 or length(btrim(input->>'title'))=0 or not private.valid_patent_source_url(input->>'sourceUrl')
 or (input?'relevanceStatus' and jsonb_typeof(input->'relevanceStatus')<>'string') then raise exception 'Invalid Patent input' using errcode='22023';end if;
 foreach k in array array['priorityDate','filingDate','publicationDate'] loop
  if input->>k is not null and ((input->>k)!~'^[0-9]{4}-[0-9]{2}-[0-9]{2}$' or not pg_catalog.pg_input_is_valid(input->>k,'pg_catalog.date')) then raise exception 'Invalid Patent date' using errcode='22023';end if;
 end loop;
 p:=(input->>'projectId')::uuid;w:=(input->>'workspaceId')::uuid;
 -- Existing current Workspace + Project mutation checks lock/recheck profile,
 -- Team/Project membership, enrollment or exact owner scope. No role-only bypass.
 perform public.require_development_object_write(p,w);
 insert into public.patent_records(project_id,workspace_id,publication_number,application_number,title,applicant,inventor,priority_date,filing_date,publication_date,ipc_cpc,source_database,source_url,abstract_text,why_retained,relevance_status,created_by)
 values(p,w,input->>'publicationNumber',input->>'applicationNumber',input->>'title',input->>'applicant',input->>'inventor',(input->>'priorityDate')::date,(input->>'filingDate')::date,(input->>'publicationDate')::date,input->>'ipcCpc',(input->>'sourceDatabase')::public.patent_source_database,input->>'sourceUrl',input->>'abstractText',input->>'whyRetained',coalesce(input->>'relevanceStatus','NOT_REVIEWED')::public.patent_relevance_status,actor) returning * into r;
 if public.current_platform_user_id() is distinct from actor then raise exception 'Resource unavailable' using errcode='42501';end if;
 return to_jsonb(r);
end$$;
revoke all on function public.create_patent_record(jsonb) from public,anon,authenticated,service_role;
grant execute on function public.create_patent_record(jsonb) to authenticated;
comment on function public.create_patent_record(jsonb) is 'M12.12 narrow current-scope source capture. Exact human metadata/relevance, server actor and timestamp; one insert; no Evidence, merge, fetch, search or legal inference.';
comment on table public.patent_records is 'Retained patent source metadata; scoped current Project reads, denied direct client mutations, narrow M12.12 creation RPC. No search, Evidence link, AI comparison or legal conclusions.';
commit;
