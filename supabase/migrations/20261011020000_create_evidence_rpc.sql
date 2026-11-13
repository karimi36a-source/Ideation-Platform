begin;
-- Authorized M12.3 function-only migration. Existing Evidence constraints,
-- RLS, mutation revocations and history guard remain unchanged.
create function public.create_evidence(
 project_id uuid,workspace_id uuid,evidence_type public.evidence_type,
 title text,description text,source_name text,source_url text default null,file_id uuid default null
) returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare actor uuid:=public.current_platform_user_id();e public.evidence;
 normalized_title text:=private.trim_decision_text(title);
 normalized_description text:=private.trim_decision_text(description);
 normalized_source text:=private.trim_decision_text(source_name);
 normalized_url text:=private.trim_decision_text(source_url);
begin
 if actor is null then
  if auth.uid() is null then raise exception 'Authentication required' using errcode='28000';end if;
  raise exception 'Resource unavailable' using errcode='42501';end if;
 if project_id is null or workspace_id is null or evidence_type is null
 or coalesce(length(normalized_title),0)=0 or coalesce(length(normalized_description),0)=0 or coalesce(length(normalized_source),0)=0
 or (source_url is not null and normalized_url !~* '^https?://[^/[:space:]?#]+([/?#][^[:space:]]*)?$')
 then raise exception 'Invalid Evidence input' using errcode='22023';end if;
 -- Locks/rechecks account, enrollment, current Team and explicit Project
 -- participation, Personal ownership or exact Case Study owner authority.
 perform public.require_development_object_write(project_id,workspace_id);
 if file_id is not null then raise exception 'Files dependency unavailable' using errcode='0A000';end if;
 insert into public.evidence(project_id,workspace_id,evidence_type,title,description,source_name,source_url,
  file_id,verification_status,verified_by,verified_at,created_by,captured_at,metadata,updated_by,archived_at)
 values(create_evidence.project_id,create_evidence.workspace_id,create_evidence.evidence_type,normalized_title,normalized_description,normalized_source,normalized_url,
  null,'UNVERIFIED',null,null,actor,clock_timestamp(),'{}',actor,null) returning * into e;
 if public.current_platform_user_id() is distinct from actor then raise exception 'Resource unavailable' using errcode='42501';end if;
 return to_jsonb(e);
end $$;
revoke all on function public.create_evidence(uuid,uuid,public.evidence_type,text,text,text,text,uuid) from public,anon,authenticated,service_role;
grant execute on function public.create_evidence(uuid,uuid,public.evidence_type,text,text,text,text,uuid) to authenticated;
comment on function public.create_evidence(uuid,uuid,public.evidence_type,text,text,text,text,uuid) is 'M12.3 narrow current-scope creation. Identity, UNVERIFIED state, timestamps, empty metadata and non-archived state are server-derived. No generic table write, Files, verification, link, AI or sharing operation.';
commit;
