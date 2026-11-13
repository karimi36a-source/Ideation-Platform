begin;
-- Source text stays on Patent Records; only canonical IDs accompany learner notes.
create function private.valid_patent_reading_snapshot(body jsonb) returns boolean
language plpgsql immutable set search_path='' as $$
begin
 if jsonb_typeof(body) is distinct from 'object' or jsonb_typeof(body->'learner_notes') is distinct from 'object'
 or jsonb_typeof(body->'source_patent_record_ids') is distinct from 'array' then return false;end if;
 return (select count(*)=2 from jsonb_object_keys(body))
 and (select count(*)=6 from jsonb_object_keys(body->'learner_notes'))
 and not exists(select 1 from unnest(array['title','abstract','description','claims','drawings','bibliographic_information']) k
 where jsonb_typeof(body->'learner_notes'->k) is distinct from 'string')
 and jsonb_array_length(body->'source_patent_record_ids')=1
 and coalesce(pg_catalog.pg_input_is_valid(body#>>'{source_patent_record_ids,0}','pg_catalog.uuid'),false);
end$$;
revoke all on function private.valid_patent_reading_snapshot(jsonb) from public,anon,authenticated,service_role;
create function private.guard_patent_reading_version() returns trigger
language plpgsql set search_path='' as $$
declare a public.artifacts;p public.patent_records;
begin
 select * into a from public.artifacts where id=new.artifact_id;
 if a.artifact_type::text is distinct from 'PATENT_READING_FRAMEWORK' then return new;end if;
 -- M8 creates an empty initial Draft, which cannot yet be registered as output.
 if tg_op='INSERT' and new.version_number=1 and new.status='DRAFT' and new.content_snapshot='{}'::jsonb then return new;end if;
 if not private.valid_patent_reading_snapshot(new.content_snapshot) then raise exception 'Invalid reading framework' using errcode='22023';end if;
 select * into p from public.patent_records where id=(new.content_snapshot#>>'{source_patent_record_ids,0}')::uuid for share;
 if p.id is null or (p.project_id,p.workspace_id) is distinct from (a.project_id,a.workspace_id) then raise exception 'Resource unavailable' using errcode='42501';end if;
 return new;
end$$;
revoke all on function private.guard_patent_reading_version() from public,anon,authenticated,service_role;
create trigger artifact_versions_patent_reading before insert or update on public.artifact_versions for each row execute function private.guard_patent_reading_version();
create function private.guard_patent_reading_output() returns trigger
language plpgsql set search_path='' as $$
declare a public.artifacts;v public.artifact_versions;
begin
 select * into a from public.artifacts where id=new.artifact_id;
 if a.artifact_type::text='PATENT_READING_FRAMEWORK' then
  select * into v from public.artifact_versions where artifact_id=a.id order by version_number desc limit 1 for share;
  if v.id is null or not private.valid_patent_reading_snapshot(v.content_snapshot)
  or not exists(select 1 from public.activity_research_links r where r.activity_instance_id=new.activity_instance_id and r.entity_type='PATENT_RECORD' and r.entity_id=(v.content_snapshot#>>'{source_patent_record_ids,0}')::uuid)
  then raise exception 'Save reading notes and source reference first' using errcode='22023';end if;
 end if;
 return new;
end$$;
revoke all on function private.guard_patent_reading_output() from public,anon,authenticated,service_role;
create trigger activity_outputs_patent_reading before insert on public.activity_outputs for each row execute function private.guard_patent_reading_output();
create function public.save_patent_reading_framework(target_instance uuid,target_patent uuid,notes jsonb,expected_revision integer default null,target_version uuid default null) returns jsonb
language plpgsql security definer set search_path='' as $$
declare i public.activity_instances;p public.patent_records;a public.artifacts;v public.artifact_versions;made jsonb;body jsonb;result jsonb;
begin
 i:=public.lock_activity_artifact_contribution(target_instance);
 if i.configuration_snapshot->>'method_type' is distinct from 'patent_research' then raise exception 'Resource unavailable' using errcode='42501';end if;
 select * into p from public.patent_records where id=target_patent for share;
 if p.id is null or (p.project_id,p.workspace_id) is distinct from (i.project_id,i.workspace_id)
 or not public.can_read_development_project(p.project_id) then raise exception 'Resource unavailable' using errcode='42501';end if;
 body:=jsonb_build_object('learner_notes',notes,'source_patent_record_ids',jsonb_build_array(p.id));
 if not private.valid_patent_reading_snapshot(body) or expected_revision<0 or (expected_revision is null)<>(target_version is null) then raise exception 'Invalid reading framework' using errcode='22023';end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('fici-patent-reading:'||i.id::text,1226));
 i:=public.lock_activity_artifact_contribution(target_instance);
 select * into a from public.artifacts where activity_instance_id=i.id and artifact_type::text='PATENT_READING_FRAMEWORK' order by created_at,id limit 1 for update;
 if a.id is null then
  if expected_revision is not null then raise exception 'Stale Draft' using errcode='23505';end if;
  made:=public.create_artifact(i.project_id,i.workspace_id,'PATENT_READING_FRAMEWORK','Patent Reading Framework',i.id,false,false);
  select * into a from public.artifacts where id=(made->>'artifactId')::uuid;
  result:=public.update_artifact_draft((made->>'initialVersionId')::uuid,0,body,null,false);
 else
  select * into v from public.artifact_versions where artifact_id=a.id order by version_number desc limit 1 for update;
  if expected_revision is null then
   if v.content_snapshot is distinct from body then raise exception 'Reload the existing Draft before editing' using errcode='23505';end if;
   result:=to_jsonb(v);
  else
   if v.id is distinct from target_version then raise exception 'Stale Draft' using errcode='23505';end if;
   result:=public.update_artifact_draft(v.id,expected_revision,body,null,false);
  end if;
 end if;
 perform public.add_activity_research_reference(i.id,'PATENT_RECORD',p.id);
 perform public.add_activity_artifact_output(i.id,a.id);
 select * into a from public.artifacts where id=a.id;
 return jsonb_build_object('artifact',to_jsonb(a),'version',result);
end$$;
revoke all on function public.save_patent_reading_framework(uuid,uuid,jsonb,integer,uuid) from public,anon,authenticated,service_role;
grant execute on function public.save_patent_reading_framework(uuid,uuid,jsonb,integer,uuid) to authenticated;
comment on function public.save_patent_reading_framework(uuid,uuid,jsonb,integer,uuid) is 'M12.26 atomic canonical Artifact/Draft/source-reference/output composition. Learner notes, M8 CAS and history. No Evidence, AI or legal inference.';
commit;
