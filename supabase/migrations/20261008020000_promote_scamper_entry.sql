begin;
-- Narrow source operation: retain M6 contribution checks and integrity triggers,
-- but derive human authorship from the locked source, never caller input.
create function public.promote_scamper_entry_to_idea(target_entry uuid) returns jsonb
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
 return to_jsonb(o);
end $$;
revoke all on function public.promote_scamper_entry_to_idea(uuid) from public,anon,authenticated,service_role;
grant execute on function public.promote_scamper_entry_to_idea(uuid) to authenticated;
comment on function public.promote_scamper_entry_to_idea(uuid) is 'M9.3 atomic same-scope SCAMPER promotion. Source author retained; verified promoter logged separately. No sharing, output registration or synchronization.';
commit;
