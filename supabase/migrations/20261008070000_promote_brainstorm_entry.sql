begin;
-- Narrow source operation: retain M6 contribution checks and integrity triggers,
-- but derive human authorship from the locked source, never caller input.
create function public.promote_brainstorm_entry_to_idea(target_entry uuid) returns jsonb
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
 return to_jsonb(o);
end $$;
revoke all on function public.promote_brainstorm_entry_to_idea(uuid) from public,anon,authenticated,service_role;
grant execute on function public.promote_brainstorm_entry_to_idea(uuid) to authenticated;
comment on function public.promote_brainstorm_entry_to_idea(uuid) is 'M9.9 atomic same-scope BRAINSTORM promotion. Source author retained; verified promoter logged separately. No sharing, output registration or synchronization.';
create or replace function public.validate_brainstorm_entry() returns trigger language plpgsql set search_path='' as $$
declare actor uuid:=auth.uid();reveal_change boolean:=false;promotion_change boolean:=false;
begin
 if tg_op='DELETE' then raise exception 'Brainstorm history must be preserved' using errcode='23514';end if;
 if tg_op='UPDATE' then
  if old.revealed_at is not null and new.revealed_at is distinct from old.revealed_at then raise exception 'Reveal history is immutable' using errcode='23514';end if;
  reveal_change:=old.revealed_at is null and new.revealed_at is not null;
 end if;
 if tg_op='UPDATE' and old.development_object_id is null and new.development_object_id is not null then
  promotion_change:=current_user=pg_catalog.pg_get_userbyid((select proowner from pg_catalog.pg_proc where oid='public.promote_brainstorm_entry_to_idea(uuid)'::regprocedure))
   and (to_jsonb(new)-array['development_object_id','updated_at','updated_by'])=(to_jsonb(old)-array['development_object_id','updated_at','updated_by']);
  if promotion_change and actor is not null then
   perform private.require_brainstorm_write(new.activity_instance_id);
   if not public.can_read_brainstorm_entry(old.id) or not exists(select 1 from public.development_objects o where o.id=new.development_object_id and o.object_type='IDEA' and o.project_id=new.project_id and o.workspace_id=new.workspace_id and o.created_by=new.created_by and o.origin_type='BRAINSTORM' and o.origin_reference_id=new.id)
    or not exists(select 1 from public.workspaces w where w.id=new.workspace_id and ((w.workspace_type='PERSONAL' and w.owner_user_id=actor and new.created_by=actor) or (w.workspace_type='TEAM' and new.revealed_at is not null))) then raise exception 'Resource unavailable' using errcode='42501';end if;
  end if;
 end if;
 if actor is not null and reveal_change then
  -- Execution role, not a caller-writable GUC, restricts the one transition.
  if current_user is distinct from pg_catalog.pg_get_userbyid((select proowner from pg_catalog.pg_proc where oid='public.reveal_brainstorm_entries(uuid,uuid[])'::regprocedure))
   or (to_jsonb(new)-array['revealed_at','updated_at','updated_by']) is distinct from (to_jsonb(old)-array['revealed_at','updated_at','updated_by']) then
   raise exception 'Resource unavailable' using errcode='42501';end if;
  begin perform private.require_brainstorm_reveal(new.activity_instance_id);
  exception when others then raise exception 'Resource unavailable' using errcode='42501';end;
 end if;
 if actor is not null and not reveal_change and not promotion_change and (public.current_platform_user_id() is distinct from actor or new.created_by is distinct from actor
  or not public.can_read_activity_instance(new.activity_instance_id)) then raise exception 'Resource unavailable' using errcode='42501';end if;
 if actor is not null and new.revealed_at is not null and not reveal_change and not promotion_change then raise exception 'Reveal workflow unavailable' using errcode='42501';end if;
 if tg_op='UPDATE' then
  if (new.id,new.activity_instance_id,new.project_id,new.workspace_id,new.created_by,new.created_at)
   is distinct from (old.id,old.activity_instance_id,old.project_id,old.workspace_id,old.created_by,old.created_at) then
   raise exception 'Brainstorm identity and provenance are immutable' using errcode='23514';end if;
  if old.status='archived' and new is distinct from old then raise exception 'Archived Brainstorm history is immutable' using errcode='23514';end if;
  if new is not distinct from old then return old;end if;

 end if;
 if not exists(select 1 from public.activity_instances i join public.activity_definitions d on d.id=i.activity_definition_id
  where i.id=new.activity_instance_id and i.project_id=new.project_id and i.workspace_id=new.workspace_id and d.method_type='brainstorming' and (not (i.configuration_snapshot ? 'method_type') or i.configuration_snapshot->>'method_type'='brainstorming')) then
  raise exception 'Invalid Brainstorm Activity context' using errcode='23514';end if;
 if new.development_object_id is not null and not exists(select 1 from public.development_objects o
  where o.id=new.development_object_id and o.object_type in ('IDEA','SOLUTION') and o.project_id=new.project_id and o.workspace_id=new.workspace_id) then
  raise exception 'Invalid Brainstorm Object context' using errcode='23514';end if;
 if new.parent_entry_id is not null and actor is not null and not reveal_change and not promotion_change and not exists(select 1 from public.brainstorm_entries p
  where p.id=new.parent_entry_id and (p.created_by=actor or (p.revealed_at is not null and public.can_read_brainstorm_entry(p.id))) and p.activity_instance_id=new.activity_instance_id
  and p.project_id=new.project_id and p.workspace_id=new.workspace_id) then raise exception 'Resource unavailable' using errcode='42501';end if;
 if tg_op='INSERT' then new.updated_by:=new.created_by;
 else new.updated_by:=coalesce(actor,new.updated_by);new.updated_at:=pg_catalog.clock_timestamp();end if;
 return new;
end $$;

commit;
