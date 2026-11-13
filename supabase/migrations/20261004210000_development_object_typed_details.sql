begin;
create type public.idea_acceptance_state as enum ('private','shared','candidate','accepted','rejected','archived');
create table public.problem_details (
 development_object_id uuid primary key references public.development_objects(id) on delete restrict on update restrict,
 problem_category text check(problem_category is null or length(btrim(problem_category))>0),
 priority text check(priority is null or length(btrim(priority))>0),
 perspective text check(perspective is null or length(btrim(perspective))>0)
);
create table public.idea_details (
 development_object_id uuid primary key references public.development_objects(id) on delete restrict on update restrict,
 technique text check(technique is null or length(btrim(technique))>0),
 acceptance_state public.idea_acceptance_state not null,
 original_private_workspace_id uuid references public.workspaces(id) on delete restrict on update restrict
);
create index idea_details_private_provenance on public.idea_details(original_private_workspace_id) where original_private_workspace_id is not null;
comment on column public.idea_details.acceptance_state is 'Descriptive classification only: no sharing, approval, Decision, archive operation, or authorization side effects.';
comment on column public.idea_details.original_private_workspace_id is 'Provenance only. Never authorizes private Workspace access or broadens parent Object visibility.';
create function public.validate_development_object_details() returns trigger language plpgsql set search_path='' as $$
declare expected public.development_object_type; actual public.development_object_type;
begin
 if tg_op='DELETE' then raise exception 'Typed history must be preserved' using errcode='23514';end if;
 if tg_op='UPDATE' and new.development_object_id is distinct from old.development_object_id then raise exception 'Parent identity is immutable' using errcode='23514';end if;
 expected:=case when tg_table_name='problem_details' then 'PROBLEM'::public.development_object_type else 'IDEA'::public.development_object_type end;
 select object_type into actual from public.development_objects where id=new.development_object_id for share;
 if actual is distinct from expected then raise exception 'Invalid parent type' using errcode='23514';end if;
 if tg_table_name='idea_details' then
 if new.original_private_workspace_id is not null then
 if not exists(select 1 from public.workspaces where id=new.original_private_workspace_id and workspace_type='PERSONAL') then raise exception 'Invalid provenance type' using errcode='23514';end if;
 if not exists(select 1 from public.workspaces w join public.development_objects o on o.id=new.development_object_id where w.id=new.original_private_workspace_id and w.owner_user_id=o.created_by) then raise exception 'Invalid source owner' using errcode='23514';end if;
 end if;end if;
 return new;
end $$;
revoke all on function public.validate_development_object_details() from public,anon,authenticated,service_role;
create trigger problem_details_validate before insert or update or delete on public.problem_details for each row execute function public.validate_development_object_details();
create trigger idea_details_validate before insert or update or delete on public.idea_details for each row execute function public.validate_development_object_details();
create function public.preserve_development_object_detail_type() returns trigger language plpgsql set search_path='' as $$
begin
 if new.object_type is distinct from old.object_type and (exists(select 1 from public.problem_details where development_object_id=old.id) or exists(select 1 from public.idea_details where development_object_id=old.id)) then raise exception 'Typed parent type is immutable' using errcode='23514';end if;
 return new;
end $$;
revoke all on function public.preserve_development_object_detail_type() from public,anon,authenticated,service_role;
create trigger development_objects_preserve_detail_type before update on public.development_objects for each row execute function public.preserve_development_object_detail_type();
create function public.preserve_idea_provenance_workspace() returns trigger language plpgsql set search_path='' as $$
begin
 if (new.id,new.workspace_type,new.owner_user_id) is distinct from (old.id,old.workspace_type,old.owner_user_id)
 and exists(select 1 from public.idea_details where original_private_workspace_id=old.id) then raise exception 'Provenance identity must be preserved' using errcode='23514';end if;
 return new;
end $$;
revoke all on function public.preserve_idea_provenance_workspace() from public,anon,authenticated,service_role;
create trigger workspaces_preserve_idea_provenance before update on public.workspaces for each row execute function public.preserve_idea_provenance_workspace();
alter table public.problem_details enable row level security;
revoke all on public.problem_details from public,anon,authenticated,service_role;
grant select on public.problem_details to authenticated;
create policy problem_details_read on public.problem_details for select to authenticated using(exists(select 1 from public.development_objects o where o.id=development_object_id));
create policy problem_details_read_guard on public.problem_details as restrictive for select to authenticated using(exists(select 1 from public.development_objects o where o.id=development_object_id));
create policy problem_details_insert_deny on public.problem_details as restrictive for insert to authenticated with check(false);
create policy problem_details_update_deny on public.problem_details as restrictive for update to authenticated using(false) with check(false);
create policy problem_details_delete_deny on public.problem_details as restrictive for delete to authenticated using(false);
create policy problem_details_anon_deny on public.problem_details as restrictive for all to anon using(false) with check(false);
alter table public.idea_details enable row level security;
revoke all on public.idea_details from public,anon,authenticated,service_role;
grant select on public.idea_details to authenticated;
create policy idea_details_read on public.idea_details for select to authenticated using(exists(select 1 from public.development_objects o where o.id=development_object_id));
create policy idea_details_read_guard on public.idea_details as restrictive for select to authenticated using(exists(select 1 from public.development_objects o where o.id=development_object_id));
create policy idea_details_insert_deny on public.idea_details as restrictive for insert to authenticated with check(false);
create policy idea_details_update_deny on public.idea_details as restrictive for update to authenticated using(false) with check(false);
create policy idea_details_delete_deny on public.idea_details as restrictive for delete to authenticated using(false);
create policy idea_details_anon_deny on public.idea_details as restrictive for all to anon using(false) with check(false);

-- Narrow definer writes are necessary because direct client writes remain denied.
-- Reuse M6.6 locking/identity validation; only extension fields are accepted.
create function public.write_problem_details(target_object uuid,details jsonb,create_new boolean) returns jsonb
 language plpgsql security definer set search_path='' as $$
declare o public.development_objects;d public.problem_details;k text;
begin
 if public.current_platform_user_id() is null then
 if auth.uid() is null then raise exception 'Authentication required' using errcode='28000';end if;raise exception 'Access denied' using errcode='42501';end if;
 select * into o from public.development_objects where id=target_object;
 if not found then raise exception 'Access denied' using errcode='42501';end if;
 perform public.require_development_object_write(o.project_id,o.workspace_id);
 select * into o from public.development_objects where id=target_object for update;
 if o.object_type<>'PROBLEM' or o.archived_at is not null then raise exception 'Invalid parent' using errcode='22023';end if;
 if create_new is null or details is null or jsonb_typeof(details)<>'object' or (not create_new and details='{}') then raise exception 'Invalid detail input' using errcode='22023';end if;
 for k in select jsonb_object_keys(details) loop
 if k not in ('problem_category','priority','perspective') or jsonb_typeof(details->k) not in ('string','null') or (jsonb_typeof(details->k)='string' and length(btrim(details->>k))=0) then raise exception 'Invalid detail input' using errcode='22023';end if;end loop;
 if create_new then
 insert into public.problem_details(development_object_id,problem_category,priority,perspective) values(target_object,details->>'problem_category',details->>'priority',details->>'perspective') returning * into d;
 else
 update public.problem_details set problem_category=case when details ? 'problem_category' then details->>'problem_category' else problem_category end,
 priority=case when details ? 'priority' then details->>'priority' else priority end,perspective=case when details ? 'perspective' then details->>'perspective' else perspective end where development_object_id=target_object returning * into d;
 if not found then raise exception 'Access denied' using errcode='42501';end if;end if;
 return to_jsonb(d);
end $$;
create function public.write_idea_details(target_object uuid,details jsonb,create_new boolean) returns jsonb
 language plpgsql security definer set search_path='' as $$
declare o public.development_objects;d public.idea_details;k text;source_workspace uuid;w public.workspaces;actor uuid;
begin
 actor:=public.current_platform_user_id();
 if actor is null then
 if auth.uid() is null then raise exception 'Authentication required' using errcode='28000';end if;raise exception 'Access denied' using errcode='42501';end if;
 select * into o from public.development_objects where id=target_object;
 if not found then raise exception 'Access denied' using errcode='42501';end if;
 perform public.require_development_object_write(o.project_id,o.workspace_id);
 select * into o from public.development_objects where id=target_object for update;
 if o.object_type<>'IDEA' or o.archived_at is not null then raise exception 'Invalid parent' using errcode='22023';end if;
 if create_new is null or details is null or jsonb_typeof(details)<>'object' or (not create_new and details='{}') then raise exception 'Invalid detail input' using errcode='22023';end if;
 for k in select jsonb_object_keys(details) loop
 if k not in ('technique','acceptance_state','original_private_workspace_id') then raise exception 'Invalid detail input' using errcode='22023';end if;end loop;
 if (details ? 'technique' and (jsonb_typeof(details->'technique') not in ('string','null') or (jsonb_typeof(details->'technique')='string' and length(btrim(details->>'technique'))=0)))
 or (create_new and not details ? 'acceptance_state')
 or (details ? 'acceptance_state' and (jsonb_typeof(details->'acceptance_state')<>'string' or details->>'acceptance_state' not in ('private','shared','candidate','accepted','rejected','archived')))
 or (details ? 'original_private_workspace_id' and jsonb_typeof(details->'original_private_workspace_id') not in ('string','null')) then raise exception 'Invalid detail input' using errcode='22023';end if;
 if details ? 'original_private_workspace_id' and details->>'original_private_workspace_id' is not null then
 source_workspace:=(details->>'original_private_workspace_id')::uuid;
 select * into w from public.workspaces where id=source_workspace for share;
 if not found or w.workspace_type<>'PERSONAL' or w.status<>'active' or w.visibility<>'private' or w.owner_user_id is distinct from actor or o.created_by is distinct from actor then raise exception 'Access denied' using errcode='42501';end if;
 end if;
 if create_new then
 insert into public.idea_details(development_object_id,technique,acceptance_state,original_private_workspace_id) values(target_object,details->>'technique',(details->>'acceptance_state')::public.idea_acceptance_state,source_workspace) returning * into d;
 else
 update public.idea_details set technique=case when details ? 'technique' then details->>'technique' else technique end,
 acceptance_state=case when details ? 'acceptance_state' then (details->>'acceptance_state')::public.idea_acceptance_state else acceptance_state end,
 original_private_workspace_id=case when details ? 'original_private_workspace_id' then source_workspace else original_private_workspace_id end where development_object_id=target_object returning * into d;
 if not found then raise exception 'Access denied' using errcode='42501';end if;end if;
 return to_jsonb(d);
end $$;
revoke all on function public.write_problem_details(uuid,jsonb,boolean) from public,anon,authenticated,service_role;
revoke all on function public.write_idea_details(uuid,jsonb,boolean) from public,anon,authenticated,service_role;
grant execute on function public.write_problem_details(uuid,jsonb,boolean) to authenticated;
grant execute on function public.write_idea_details(uuid,jsonb,boolean) to authenticated;
commit;
