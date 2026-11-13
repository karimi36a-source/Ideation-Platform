begin;
-- Private shared validator locks current authorization inputs for the transaction.
-- Definer access is needed because ordinary clients cannot read memberships or
-- mutate objects. It accepts resource IDs only; identity always comes from auth.
create function public.require_development_object_write(target_project uuid,target_workspace uuid) returns void
 language plpgsql security definer set search_path='' as $$
declare actor uuid;p public.development_projects;w public.workspaces;source_cohort uuid;
begin
 actor:=public.current_platform_user_id();
 if actor is null then
  if auth.uid() is null then raise exception 'Authentication required' using errcode='28000';end if;
  raise exception 'Access denied' using errcode='42501';end if;
 if not public.can_read_development_project(target_project) then raise exception 'Access denied' using errcode='42501';end if;
 select * into p from public.development_projects where id=target_project;
 select cohort_id into source_cohort from public.workspaces where id=p.primary_workspace_id;
 perform 1 from public.cohorts where id=source_cohort for share;
 if p.owner_team_id is not null then perform 1 from public.teams where id=p.owner_team_id for share;end if;
 select * into p from public.development_projects where id=target_project for share;
 select * into w from public.workspaces where id=p.primary_workspace_id for share;
 if p.primary_workspace_id is distinct from target_workspace or w.id is null or w.status<>'active' or w.visibility<>'private' or w.cohort_id is distinct from source_cohort then raise exception 'Access denied' using errcode='42501';end if;
 perform 1 from public.users where id=actor and account_status='active' for share;
 if not found then raise exception 'Access denied' using errcode='42501';end if;
 perform 1 from public.role_assignments where user_id=actor order by id for share;
 perform 1 from public.enrollments where user_id=actor order by id for share;
 perform 1 from public.project_memberships where project_id=p.id and user_id=actor order by id for share;
 if p.owner_team_id is not null then perform 1 from public.team_memberships where team_id=p.owner_team_id and user_id=actor order by id for share;end if;
 if public.current_platform_user_id() is distinct from actor or not public.can_read_development_project(p.id) then raise exception 'Access denied' using errcode='42501';end if;
 if p.project_type='team' then
  if coalesce(public.get_team_workspace_access(w.id)::text,'') not in ('member','team_lead') then raise exception 'Access denied' using errcode='42501';end if;
 elsif p.project_type='individual' then
  if p.owner_user_id is distinct from actor or w.workspace_type<>'PERSONAL' or w.owner_user_id is distinct from actor then raise exception 'Access denied' using errcode='42501';end if;
 else
  if p.owner_user_id is distinct from actor or w.workspace_type<>'CASE_STUDY' or w.owner_user_id is distinct from actor or w.cohort_id is null or not public.has_active_role_in_cohort('MASTER',w.cohort_id) then raise exception 'Access denied' using errcode='42501';end if;
 end if;
end $$;
revoke all on function public.require_development_object_write(uuid,uuid) from public,anon,authenticated,service_role;
create function public.create_development_object(target_project uuid,target_workspace uuid,kind public.development_object_type,object_title text,object_content text,object_origin text,object_metadata jsonb default '{}') returns jsonb
 language plpgsql security definer set search_path='' as $$
declare o public.development_objects;
begin
 perform public.require_development_object_write(target_project,target_workspace);
 if kind is null or object_title is null or length(btrim(object_title))=0 or object_content is null or (object_origin is not null and length(btrim(object_origin))=0) or object_metadata is null or jsonb_typeof(object_metadata)<>'object' then raise exception 'Invalid object input' using errcode='22023';end if;
 insert into public.development_objects(project_id,workspace_id,object_type,title,content,origin_type,metadata,created_by)
 values(target_project,target_workspace,kind,object_title,object_content,object_origin,object_metadata,public.current_platform_user_id()) returning * into o;
 return to_jsonb(o);
end $$;
create function public.update_development_object(target_object uuid,changes jsonb) returns jsonb
 language plpgsql security definer set search_path='' as $$
declare o public.development_objects;
begin
 if public.current_platform_user_id() is null then
  if auth.uid() is null then raise exception 'Authentication required' using errcode='28000';end if;
  raise exception 'Access denied' using errcode='42501';end if;
 select * into o from public.development_objects where id=target_object;
 if not found then raise exception 'Access denied' using errcode='42501';end if;
 perform public.require_development_object_write(o.project_id,o.workspace_id);
 select * into o from public.development_objects where id=target_object for update;
 if o.archived_at is not null then raise exception 'Invalid object state' using errcode='22023';end if;
 if changes is null or jsonb_typeof(changes)<>'object' or changes='{}'::jsonb then raise exception 'Invalid object input' using errcode='22023';end if;
 if exists(select 1 from jsonb_object_keys(changes) k where k not in ('title','content','metadata'))
 or (changes ? 'title' and (jsonb_typeof(changes->'title')<>'string' or length(btrim(changes->>'title'))=0))
 or (changes ? 'content' and jsonb_typeof(changes->'content')<>'string')
 or (changes ? 'metadata' and jsonb_typeof(changes->'metadata')<>'object') then raise exception 'Invalid object input' using errcode='22023';end if;
 update public.development_objects set title=case when changes ? 'title' then changes->>'title' else title end,
 content=case when changes ? 'content' then changes->>'content' else content end,
 metadata=case when changes ? 'metadata' then changes->'metadata' else metadata end,updated_at=clock_timestamp() where id=target_object returning * into o;
 return to_jsonb(o);
end $$;
create function public.archive_development_object(target_object uuid) returns jsonb
 language plpgsql security definer set search_path='' as $$
declare o public.development_objects;
begin
 if public.current_platform_user_id() is null then
  if auth.uid() is null then raise exception 'Authentication required' using errcode='28000';end if;
  raise exception 'Access denied' using errcode='42501';end if;
 select * into o from public.development_objects where id=target_object;
 if not found then raise exception 'Access denied' using errcode='42501';end if;
 perform public.require_development_object_write(o.project_id,o.workspace_id);
 select * into o from public.development_objects where id=target_object for update;
 if o.archived_at is null then
 update public.development_objects set archived_at=clock_timestamp() where id=target_object returning * into o;end if;
 return to_jsonb(o);
end $$;
revoke all on function public.create_development_object(uuid,uuid,public.development_object_type,text,text,text,jsonb) from public,anon,authenticated,service_role;
revoke all on function public.update_development_object(uuid,jsonb) from public,anon,authenticated,service_role;
revoke all on function public.archive_development_object(uuid) from public,anon,authenticated,service_role;
grant execute on function public.create_development_object(uuid,uuid,public.development_object_type,text,text,text,jsonb) to authenticated;
grant execute on function public.update_development_object(uuid,jsonb) to authenticated;
grant execute on function public.archive_development_object(uuid) to authenticated;
commit;
