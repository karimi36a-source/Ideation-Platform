begin;
create function public.link_file(input jsonb) returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare actor uuid:=public.current_platform_user_id();f public.files;l public.file_links;
 kind public.file_link_entity_type;relation public.file_relationship_type;target uuid;source uuid;
 target_workspace uuid;target_project uuid;a public.artifacts;i public.activity_instances;m public.chat_messages;ch public.chat_channels;
begin
 if actor is null then
  if auth.uid() is null then raise exception 'Authentication required' using errcode='28000';end if;
  raise exception 'Resource unavailable' using errcode='42501';end if;
 if input is null or jsonb_typeof(input)<>'object' or exists(select 1 from jsonb_object_keys(input) k where k not in ('fileId','entityType','entityId','relationshipType'))
 or jsonb_typeof(input->'fileId') is distinct from 'string' or jsonb_typeof(input->'entityId') is distinct from 'string'
 or jsonb_typeof(input->'entityType') is distinct from 'string' or jsonb_typeof(input->'relationshipType') is distinct from 'string'
 then raise exception 'Invalid File link input' using errcode='22023';end if;
 source:=(input->>'fileId')::uuid;target:=(input->>'entityId')::uuid;
 kind:=(input->>'entityType')::public.file_link_entity_type;relation:=(input->>'relationshipType')::public.file_relationship_type;
 if not (case kind
 when 'EVIDENCE' then relation in ('EVIDENCE_SOURCE','ATTACHMENT','REFERENCE')
 when 'ARTIFACT' then relation in ('ARTIFACT_FILE','ATTACHMENT','REFERENCE')
 when 'ACTIVITY_INSTANCE' then relation in ('ATTACHMENT','REFERENCE')
 when 'CHAT_MESSAGE' then relation='CHAT_ATTACHMENT'
 when 'DEVELOPMENT_OBJECT' then relation in ('ATTACHMENT','REFERENCE') else false end)
 then raise exception 'Invalid File relationship' using errcode='22023';end if;
 select * into f from public.files where id=source;
 if f.id is null or f.status<>'active' or f.archived_at is not null or not public.can_read_file_scope(f.workspace_id,f.project_id) then raise exception 'Resource unavailable' using errcode='42501';end if;
 -- Canonical scopes are immutable. Establish write locks before locking the File.
 case kind
 when 'EVIDENCE' then select workspace_id,project_id into target_workspace,target_project from public.evidence where id=target;
 when 'ARTIFACT' then select workspace_id,project_id into target_workspace,target_project from public.artifacts where id=target;
 when 'DEVELOPMENT_OBJECT' then select workspace_id,project_id into target_workspace,target_project from public.development_objects where id=target;
 when 'ACTIVITY_INSTANCE' then select workspace_id,project_id into target_workspace,target_project from public.activity_instances where id=target;
 when 'CHAT_MESSAGE' then select c.workspace_id into target_workspace from public.chat_messages m0 join public.chat_channels c on c.id=m0.chat_channel_id where m0.id=target;
 end case;
 if target_workspace is null or target_workspace is distinct from f.workspace_id or (f.project_id is not null and target_project is not null and f.project_id<>target_project) then raise exception 'Resource unavailable' using errcode='42501';end if;
 if kind='ACTIVITY_INSTANCE' then i:=public.lock_activity_artifact_contribution(target);
 -- Chat has no Project column. A Project-bound Team File still needs the
 -- canonical Project locks against archive/participation changes. Current
 -- Chat post authority is independently required below.
 elsif kind='CHAT_MESSAGE' then perform private.require_file_upload_scope(target_workspace,f.project_id);
 else perform public.require_development_object_write(target_project,target_workspace);end if;
 select * into f from public.files where id=source for update;
 if f.status<>'active' or f.archived_at is not null or not public.can_read_file_scope(f.workspace_id,f.project_id) then raise exception 'Resource unavailable' using errcode='42501';end if;
 case kind
 when 'EVIDENCE' then
  perform 1 from public.evidence where id=target and archived_at is null for share;
  if not found or not public.can_read_development_project(target_project) then raise exception 'Resource unavailable' using errcode='42501';end if;
 when 'ARTIFACT' then
  select * into a from public.artifacts where id=target for share;
  if a.status<>'ACTIVE' or a.archived_at is not null or not public.can_read_development_project(a.project_id)
   or (a.artifact_type='MIND_MAP' and not public.can_read_private_mind_map(a.id))
   or (a.artifact_type in ('MINIMUM_ESSENTIAL_STRUCTURE','INVENTION_CONCEPT') and not public.can_read_session7_output(a.id))
  then raise exception 'Resource unavailable' using errcode='42501';end if;
 when 'DEVELOPMENT_OBJECT' then
  perform 1 from public.development_objects where id=target and archived_at is null for share;
  if not found or not public.can_read_development_project(target_project) then raise exception 'Resource unavailable' using errcode='42501';end if;
 when 'ACTIVITY_INSTANCE' then
  if i.status<>'active' or not public.can_read_activity_instance(i.id) then raise exception 'Resource unavailable' using errcode='42501';end if;
 when 'CHAT_MESSAGE' then
  select * into m from public.chat_messages where id=target for share;
  select * into ch from public.chat_channels where id=m.chat_channel_id for share;
  perform 1 from public.chat_memberships where chat_channel_id=ch.id and user_id=actor order by id for share;
  if m.id is null or m.sender_user_id is distinct from actor or m.deleted_at is not null or ch.status<>'active' or public.get_team_chat_access(ch.id) is distinct from 'read_write'
  then raise exception 'Resource unavailable' using errcode='42501';end if;
 end case;
 -- Parent File lock + existing partial unique index protect concurrent retries.
 select * into l from public.file_links where file_id=source and entity_type=kind and entity_id=target and relationship_type=relation and archived_at is null;
 if l.id is not null then return to_jsonb(l);end if;
 insert into public.file_links(file_id,entity_type,entity_id,relationship_type,created_by) values(source,kind,target,relation,actor) returning * into l;
 return to_jsonb(l);
end$$;
revoke all on function public.link_file(jsonb) from public,anon,authenticated,service_role;
grant execute on function public.link_file(jsonb) to authenticated;
-- Invoker subqueries compose File AND target RLS; links grant no endpoint access.
drop policy file_links_deferred_read on public.file_links;
do $policy$declare predicate text:=$read$
 exists(select 1 from public.files f where f.id=file_id and case entity_type
 when 'EVIDENCE' then exists(select 1 from public.evidence e where e.id=entity_id and e.workspace_id=f.workspace_id and (f.project_id is null or e.project_id=f.project_id))
 when 'ARTIFACT' then exists(select 1 from public.artifacts a where a.id=entity_id and a.workspace_id=f.workspace_id and (f.project_id is null or a.project_id=f.project_id))
 when 'ACTIVITY_INSTANCE' then exists(select 1 from public.activity_instances a where a.id=entity_id and a.workspace_id=f.workspace_id and (f.project_id is null or a.project_id=f.project_id))
 when 'DEVELOPMENT_OBJECT' then exists(select 1 from public.development_objects o where o.id=entity_id and o.workspace_id=f.workspace_id and (f.project_id is null or o.project_id=f.project_id))
 when 'CHAT_MESSAGE' then exists(select 1 from public.chat_messages m join public.chat_channels c on c.id=m.chat_channel_id where m.id=entity_id and c.workspace_id=f.workspace_id and m.deleted_at is null)
 else false end)
 $read$;begin
 execute 'create policy file_links_both_endpoints_read on public.file_links for select to authenticated using ('||predicate||')';
 execute 'create policy file_links_both_endpoints_guard on public.file_links as restrictive for select to authenticated using ('||predicate||')';
end$policy$;
comment on function public.link_file(jsonb) is 'M12.8 current File read + independent target write + exact scopes + author-only Chat attachment + active Activity; serialized immutable link reuse, no endpoint/body/access mutation.';
commit;
