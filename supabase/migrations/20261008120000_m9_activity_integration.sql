begin;
-- M9.14: opt-in canonical IDEA outputs from immutable execution configuration.
create or replace function public.promote_scamper_entry_to_idea(target_entry uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=public.current_platform_user_id();s public.scamper_entries;a public.activity_instances;o public.development_objects;t text;
begin
 if actor is null then
  if auth.uid() is null then raise exception 'Authentication required' using errcode='28000';end if;
  raise exception 'Resource unavailable' using errcode='42501';end if;
 select * into s from public.scamper_entries where id=target_entry;
 if not found then raise exception 'Resource unavailable' using errcode='42501';end if;
 a:=private.require_scamper_write(s.activity_instance_id);
 select * into s from public.scamper_entries where id=target_entry for update;
 a:=private.require_scamper_write(s.activity_instance_id);
 if s.project_id<>a.project_id or s.workspace_id<>a.workspace_id then raise exception 'Resource unavailable' using errcode='42501';end if;
 if s.status<>'active' then raise exception 'Entry not writable' using errcode='55000';end if;
 if s.idea_object_id is not null then
  select * into o from public.development_objects where id=s.idea_object_id for share;
  if not found or o.object_type<>'IDEA' or o.project_id<>s.project_id or o.workspace_id<>s.workspace_id
   or o.created_by<>s.created_by or o.origin_type is distinct from 'SCAMPER' or o.origin_reference_id is distinct from s.id then
   raise exception 'Promotion integrity conflict' using errcode='23505';end if;
  if a.configuration_snapshot #> '{configuration,output_registration,promoted_ideas}'='true'::jsonb then
   perform public.add_activity_output(a.id,o.id);
  end if;
  return to_jsonb(o);
 end if;
 t:=case when length(btrim(s.proposed_change))>0 then s.proposed_change when length(btrim(s.result_text))>0 then s.result_text else 'SCAMPER '||s.scamper_type::text end;
 insert into public.development_objects(project_id,workspace_id,object_type,title,content,origin_type,origin_reference_id,created_by)
 values(s.project_id,s.workspace_id,'IDEA',t,jsonb_build_object('scamper_type',s.scamper_type,'original_element',s.original_element,'proposed_change',s.proposed_change,'result_text',s.result_text)::text,'SCAMPER',s.id,s.created_by)
 returning * into o;
 update public.scamper_entries set idea_object_id=o.id where id=s.id;
 -- Canonical history records the acting promoter; source identity is structured
 -- on the Object, Workspace scope derives from the immutable parent relation.
 perform public.append_project_change(o.project_id,'DEVELOPMENT_OBJECT',o.id,'OBJECT_CREATED','SCAMPER entry '||s.id::text);
 if a.configuration_snapshot #> '{configuration,output_registration,promoted_ideas}'='true'::jsonb then
   perform public.add_activity_output(a.id,o.id);
  end if;
  return to_jsonb(o);
end $$;
revoke all on function public.promote_scamper_entry_to_idea(uuid) from public,anon,authenticated,service_role;
grant execute on function public.promote_scamper_entry_to_idea(uuid) to authenticated;
create or replace function public.promote_brainstorm_entry_to_idea(target_entry uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=public.current_platform_user_id();s public.brainstorm_entries;a public.activity_instances;o public.development_objects;t text;
begin
 if actor is null then
  if auth.uid() is null then raise exception 'Authentication required' using errcode='28000';end if;
  raise exception 'Resource unavailable' using errcode='42501';end if;
 select * into s from public.brainstorm_entries where id=target_entry;
 if not found or not public.can_read_brainstorm_entry(s.id) then raise exception 'Resource unavailable' using errcode='42501';end if;
 a:=private.require_brainstorm_write(s.activity_instance_id);
 select * into s from public.brainstorm_entries where id=target_entry for update;
 a:=private.require_brainstorm_write(s.activity_instance_id);
 if not public.can_read_brainstorm_entry(s.id) or not exists(select 1 from public.workspaces w where w.id=s.workspace_id and ((w.workspace_type='PERSONAL' and w.owner_user_id=actor and s.created_by=actor) or (w.workspace_type='TEAM' and w.team_id=a.team_id and s.revealed_at is not null and a.configuration_snapshot #>> '{configuration,brainstorming,reveal_authority}'='team_lead_or_scoped_master'))) then raise exception 'Resource unavailable' using errcode='42501';end if;
 if s.project_id<>a.project_id or s.workspace_id<>a.workspace_id then raise exception 'Resource unavailable' using errcode='42501';end if;
 if s.status<>'active' then raise exception 'Entry not writable' using errcode='55000';end if;
 if s.development_object_id is not null then
  select * into o from public.development_objects where id=s.development_object_id for share;
  if not found or o.object_type<>'IDEA' or o.project_id<>s.project_id or o.workspace_id<>s.workspace_id
   or o.created_by<>s.created_by or o.origin_type is distinct from 'BRAINSTORM' or o.origin_reference_id is distinct from s.id then
   raise exception 'Promotion integrity conflict' using errcode='23505';end if;
  if a.configuration_snapshot #> '{configuration,output_registration,promoted_ideas}'='true'::jsonb then
   perform public.add_activity_output(a.id,o.id);
  end if;
  return to_jsonb(o);
 end if;
 t:=case when length(btrim(s.content))>0 then s.content else 'Brainstorm Idea' end;
 insert into public.development_objects(project_id,workspace_id,object_type,title,content,origin_type,origin_reference_id,created_by)
 values(s.project_id,s.workspace_id,'IDEA',t,s.content,'BRAINSTORM',s.id,s.created_by)
 returning * into o;
 update public.brainstorm_entries set development_object_id=o.id where id=s.id;
 -- Canonical history records the acting promoter; source identity is structured
 -- on the Object, Workspace scope derives from the immutable parent relation.
 perform public.append_project_change(o.project_id,'DEVELOPMENT_OBJECT',o.id,'OBJECT_CREATED','BRAINSTORM entry '||s.id::text);
 if a.configuration_snapshot #> '{configuration,output_registration,promoted_ideas}'='true'::jsonb then
   perform public.add_activity_output(a.id,o.id);
  end if;
  return to_jsonb(o);
end $$;
revoke all on function public.promote_brainstorm_entry_to_idea(uuid) from public,anon,authenticated,service_role;
grant execute on function public.promote_brainstorm_entry_to_idea(uuid) to authenticated;
comment on function public.promote_scamper_entry_to_idea(uuid) is 'Atomic SCAMPER IDEA promotion; optional canonical output from immutable configuration.output_registration.promoted_ideas boolean. No sharing or synchronization.';
comment on function public.promote_brainstorm_entry_to_idea(uuid) is 'Atomic Brainstorm IDEA promotion; optional canonical output from immutable configuration.output_registration.promoted_ideas boolean. No sharing or synchronization.';
-- Activity-ID discovery composes the same predicate as get_scamper_entry.
-- Needed to reload unpromoted source rows without client-memory entry IDs.
create function public.list_scamper_entries(target_instance uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
 if public.current_platform_user_id() is null then
  if auth.uid() is null then raise exception 'Authentication required' using errcode='28000';end if;
  raise exception 'Resource unavailable' using errcode='42501';end if;
 if not public.can_read_activity_instance(target_instance) then raise exception 'Resource unavailable' using errcode='42501';end if;
 return (select coalesce(jsonb_agg(to_jsonb(s) order by s.created_at,s.id),'[]'::jsonb) from public.scamper_entries s where s.activity_instance_id=target_instance);
end $$;
revoke all on function public.list_scamper_entries(uuid) from public,anon,authenticated,service_role;
grant execute on function public.list_scamper_entries(uuid) to authenticated;
comment on function public.list_scamper_entries(uuid) is 'Feature source reload by authorized canonical Activity ID; same M7 privacy as exact-entry retrieval. No generic resume expansion.';
commit;
