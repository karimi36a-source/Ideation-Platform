begin;
create type public.project_change_type as enum ('PROJECT_CREATED','PROJECT_METADATA_UPDATED','PROJECT_STAGE_CHANGED','PROJECT_STATUS_CHANGED','OBJECT_CREATED','OBJECT_UPDATED','OBJECT_ARCHIVED','RELATIONSHIP_CREATED','RELATIONSHIP_ARCHIVED','PROJECT_ARCHIVED');
create type public.project_change_entity_type as enum ('PROJECT','DEVELOPMENT_OBJECT','DEVELOPMENT_OBJECT_RELATIONSHIP');
create table public.change_log (
 id uuid primary key default gen_random_uuid(),project_id uuid not null references public.development_projects(id) on delete restrict,
 entity_type public.project_change_entity_type not null,entity_id uuid not null,
 previous_version_id uuid,new_version_id uuid,
 change_type public.project_change_type not null,
 change_summary text not null check(length(btrim(change_summary))>0),
 reason text check(reason is null or (reason=regexp_replace(reason,'^\s+|\s+$','','g') and length(reason)>0)),
 changed_by uuid not null references public.users(id) on delete restrict,
 related_decision_id uuid,related_evidence_id uuid,related_ai_output_id uuid,
 created_at timestamptz not null default now()
);
create index change_log_project_time on public.change_log(project_id,created_at,id);
create index change_log_entity on public.change_log(entity_type,entity_id,created_at,id);
create index change_log_actor on public.change_log(changed_by);
create index change_log_type on public.change_log(change_type);
comment on column public.change_log.previous_version_id is 'Nullable UUID; formal version validation/FK deferred to M8. M6 operations leave null.';
comment on column public.change_log.new_version_id is 'Nullable UUID; formal version validation/FK deferred to M8. M6 operations leave null.';
comment on column public.change_log.related_decision_id is 'Nullable UUID; validation/FK deferred until the Decision owning milestone.';
comment on column public.change_log.related_evidence_id is 'Nullable UUID; validation/FK deferred until the Evidence owning milestone.';
comment on column public.change_log.related_ai_output_id is 'Nullable UUID; validation/FK deferred until the AI output owning milestone.';
create function public.validate_project_change_log() returns trigger language plpgsql set search_path='' as $$
begin
 if tg_op<>'INSERT' then raise exception 'Project change history is append-only' using errcode='23514';end if;
 if (new.entity_type='PROJECT' and (new.entity_id<>new.project_id or new.change_type::text not like 'PROJECT_%'))
 or (new.entity_type='DEVELOPMENT_OBJECT' and (not exists(select 1 from public.development_objects o where o.id=new.entity_id and o.project_id=new.project_id) or new.change_type::text not like 'OBJECT_%'))
 or (new.entity_type='DEVELOPMENT_OBJECT_RELATIONSHIP' and (not exists(select 1 from public.development_object_relationships e where e.id=new.entity_id and e.project_id=new.project_id) or new.change_type::text not like 'RELATIONSHIP_%')) then raise exception 'Invalid change entity/Project' using errcode='23514';end if;
 return new;
end $$;
revoke all on function public.validate_project_change_log() from public,anon,authenticated,service_role;
create trigger change_log_validate before insert or update or delete on public.change_log for each row execute function public.validate_project_change_log();
alter table public.change_log enable row level security;
revoke all on public.change_log from public,anon,authenticated,service_role;
grant select on public.change_log to authenticated;
create policy change_log_read on public.change_log for select to authenticated using(exists(select 1 from public.development_projects p where p.id=change_log.project_id));
create policy change_log_read_guard on public.change_log as restrictive for select to authenticated using(exists(select 1 from public.development_projects p where p.id=change_log.project_id));
create policy change_log_insert_deny on public.change_log as restrictive for insert to authenticated with check(false);
create policy change_log_update_deny on public.change_log as restrictive for update to authenticated using(false) with check(false);
create policy change_log_delete_deny on public.change_log as restrictive for delete to authenticated using(false);
create policy change_log_anon_deny on public.change_log as restrictive for all to anon using(false) with check(false);
-- Private definer writer is callable only from trusted business RPC ownership.
-- No actor, summary, version or related-entity claims can be supplied by clients.
create function public.append_project_change(target_project uuid,kind public.project_change_entity_type,target_entity uuid,event public.project_change_type,change_reason text default null) returns void
 language plpgsql security definer set search_path='' as $$
declare actor uuid;summary text;clean_reason text;
begin
 actor:=public.current_platform_user_id();if actor is null then raise exception 'Authentication required' using errcode='28000';end if;
 clean_reason:=regexp_replace(change_reason,'^\s+|\s+$','','g');
 if clean_reason='' then raise exception 'Invalid reason' using errcode='22023';end if;
 summary:=case event
 when 'PROJECT_CREATED' then 'Project created'
 when 'PROJECT_METADATA_UPDATED' then 'Project metadata updated'
 when 'PROJECT_STAGE_CHANGED' then 'Project stage changed'
 when 'PROJECT_STATUS_CHANGED' then 'Project status changed'
 when 'OBJECT_CREATED' then 'Development Object created'
 when 'OBJECT_UPDATED' then 'Development Object updated'
 when 'OBJECT_ARCHIVED' then 'Development Object archived'
 when 'RELATIONSHIP_CREATED' then 'Relationship created'
 when 'RELATIONSHIP_ARCHIVED' then 'Relationship unlinked'
 when 'PROJECT_ARCHIVED' then 'Project archived' end;
 insert into public.change_log(project_id,entity_type,entity_id,change_type,change_summary,reason,changed_by) values(target_project,kind,target_entity,event,summary,clean_reason,actor);
end $$;
revoke all on function public.append_project_change(uuid,public.project_change_entity_type,uuid,public.project_change_type,text) from public,anon,authenticated,service_role;
create or replace function public.create_development_project(project_name text,kind public.development_project_type,target_workspace uuid,
 project_description text default null,target_owner_user uuid default null,target_owner_team uuid default null)
 returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid;w public.workspaces;t public.teams;scope uuid;org uuid;p public.development_projects;
begin
 actor:=public.current_platform_user_id();
 if actor is null then
  if auth.uid() is null then raise exception 'Authentication required' using errcode='28000';end if;
  raise exception 'Access denied' using errcode='42501';
 end if;
 if kind is null or project_name is null or length(btrim(project_name)) not between 1 and 200 or target_workspace is null
 then raise exception 'Invalid Project input' using errcode='22023';end if;
 if kind='team' then
  if target_owner_team is null or target_owner_user is not null or not public.can_manage_team(target_owner_team)
  then raise exception 'Access denied' using errcode='42501';end if;
  -- Match Team lifecycle operations: Cohort first, Team second. Hold eligibility
  -- rows through insert to prevent concurrent archive or authority revocation.
  select c.id into scope from public.cohorts c join public.teams t0 on t0.cohort_id=c.id where t0.id=target_owner_team for share of c;
  select * into t from public.teams where id=target_owner_team for share;
  if not found or t.cohort_id is distinct from scope or t.status not in ('created','active') or t.workspace_id<>target_workspace
  or not public.can_manage_team(t.id) then raise exception 'Access denied' using errcode='42501';end if;
  select p0.organization_id into org from public.programs p0 join public.cohorts c on c.program_id=p0.id where c.id=scope for share of p0;
  perform 1 from public.role_assignments a join public.roles r on r.id=a.role_id
   where a.user_id=actor and a.status='active' and a.starts_at<=statement_timestamp() and (a.ends_at is null or a.ends_at>statement_timestamp())
   and a.program_id is null and a.project_id is null and (
    (r.code='ADMIN' and a.organization_id=org and a.cohort_id is null and a.team_id is null)
    or (r.code='MASTER' and a.organization_id is null and a.cohort_id=scope and a.team_id is null)
    or (r.code='MASTER' and a.organization_id is null and a.cohort_id is null and a.team_id=t.id)) for share of a;
  if not found then raise exception 'Access denied' using errcode='42501';end if;
 elsif kind='individual' then
  if target_owner_team is not null or (target_owner_user is not null and target_owner_user<>actor)
  then raise exception 'Access denied' using errcode='42501';end if;
  target_owner_user:=actor;
 else
  if target_owner_team is not null or target_owner_user is distinct from actor then raise exception 'Access denied' using errcode='42501';end if;
  select cohort_id into scope from public.workspaces where id=target_workspace and workspace_type='CASE_STUDY' and owner_user_id=actor;
  if scope is null or not public.has_active_role_in_cohort('MASTER',scope) then raise exception 'Access denied' using errcode='42501';end if;
  perform 1 from public.cohorts where id=scope for share;
  if not found then raise exception 'Access denied' using errcode='42501';end if;
  perform 1 from public.role_assignments a join public.roles r on r.id=a.role_id where a.user_id=actor and r.code='MASTER'
   and a.cohort_id=scope and a.organization_id is null and a.program_id is null and a.team_id is null and a.project_id is null
   and a.status='active' and a.starts_at<=statement_timestamp() and (a.ends_at is null or a.ends_at>statement_timestamp()) for share of a;
  if not found then raise exception 'Access denied' using errcode='42501';end if;
 end if;
 select * into w from public.workspaces where id=target_workspace for share;
 if not found or w.status<>'active' or w.visibility<>'private' then raise exception 'Access denied' using errcode='42501';end if;
 if kind='team' then
  if w.workspace_type<>'TEAM' or w.team_id is distinct from t.id or w.cohort_id is distinct from scope then raise exception 'Access denied' using errcode='42501';end if;
 elsif w.owner_user_id is distinct from actor or w.team_id is not null or
  (kind='individual' and w.workspace_type<>'PERSONAL') or
  (kind='instructor_case_study' and (w.workspace_type<>'CASE_STUDY' or w.cohort_id is distinct from scope or not public.has_active_role_in_cohort('MASTER',scope)))
 then raise exception 'Access denied' using errcode='42501';end if;
 perform 1 from public.users where id=actor and account_status='active' for share;
 if not found or public.current_platform_user_id() is distinct from actor then raise exception 'Access denied' using errcode='42501';end if;
 insert into public.development_projects(name,description,project_type,owner_user_id,owner_team_id,primary_workspace_id)
 values(btrim(project_name),project_description,kind,target_owner_user,target_owner_team,target_workspace) returning * into p;
 perform public.append_project_change(p.id,'PROJECT',p.id,'PROJECT_CREATED');
 return to_jsonb(p);
end $$;
create or replace function public.create_development_object(target_project uuid,target_workspace uuid,kind public.development_object_type,object_title text,object_content text,object_origin text,object_metadata jsonb default '{}') returns jsonb
 language plpgsql security definer set search_path='' as $$
declare o public.development_objects;
begin
 perform public.require_development_object_write(target_project,target_workspace);
 if kind is null or object_title is null or length(btrim(object_title))=0 or object_content is null or (object_origin is not null and length(btrim(object_origin))=0) or object_metadata is null or jsonb_typeof(object_metadata)<>'object' then raise exception 'Invalid object input' using errcode='22023';end if;
 insert into public.development_objects(project_id,workspace_id,object_type,title,content,origin_type,metadata,created_by)
 values(target_project,target_workspace,kind,object_title,object_content,object_origin,object_metadata,public.current_platform_user_id()) returning * into o;
 perform public.append_project_change(o.project_id,'DEVELOPMENT_OBJECT',o.id,'OBJECT_CREATED');
 return to_jsonb(o);
end $$;
create or replace function public.update_development_object(target_object uuid,changes jsonb) returns jsonb
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
 if (case when changes ? 'title' then changes->>'title' else o.title end,case when changes ? 'content' then changes->>'content' else o.content end,case when changes ? 'metadata' then changes->'metadata' else o.metadata end) is not distinct from (o.title,o.content,o.metadata) then return to_jsonb(o);end if;
 update public.development_objects set title=case when changes ? 'title' then changes->>'title' else title end,
 content=case when changes ? 'content' then changes->>'content' else content end,
 metadata=case when changes ? 'metadata' then changes->'metadata' else metadata end,updated_at=clock_timestamp() where id=target_object returning * into o;
 perform public.append_project_change(o.project_id,'DEVELOPMENT_OBJECT',o.id,'OBJECT_UPDATED');
 return to_jsonb(o);
end $$;
create or replace function public.archive_development_object(target_object uuid) returns jsonb
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
 update public.development_objects set archived_at=clock_timestamp() where id=target_object returning * into o;
 perform public.append_project_change(o.project_id,'DEVELOPMENT_OBJECT',o.id,'OBJECT_ARCHIVED');end if;
 return to_jsonb(o);
end $$;
create or replace function public.relate_development_objects(source_object uuid,target_object uuid,kind public.development_relationship_type,relationship_description text default null) returns jsonb
 language plpgsql security definer set search_path='' as $$
declare s public.development_objects;t public.development_objects;r public.development_object_relationships;
begin
 if public.current_platform_user_id() is null then
 if auth.uid() is null then raise exception 'Authentication required' using errcode='28000';end if;raise exception 'Access denied' using errcode='42501';end if;
 select * into s from public.development_objects where id=source_object;
 if not found then raise exception 'Access denied' using errcode='42501';end if;
 select * into t from public.development_objects where id=target_object;
 if not found then raise exception 'Access denied' using errcode='42501';end if;
 perform public.require_development_object_write(s.project_id,s.workspace_id);
 perform public.require_development_object_write(t.project_id,t.workspace_id);
 if source_object=target_object or s.project_id<>t.project_id or kind is null then raise exception 'Invalid relationship input' using errcode='22023';end if;
 perform 1 from public.development_objects where id in (source_object,target_object) order by id for update;
 select * into s from public.development_objects where id=source_object;
 select * into t from public.development_objects where id=target_object;
 if s.archived_at is not null or t.archived_at is not null then raise exception 'Invalid relationship state' using errcode='22023';end if;
 insert into public.development_object_relationships(project_id,source_object_id,target_object_id,relationship_type,description,created_by)
 values(s.project_id,s.id,t.id,kind,relationship_description,public.current_platform_user_id()) returning * into r;
 perform public.append_project_change(r.project_id,'DEVELOPMENT_OBJECT_RELATIONSHIP',r.id,'RELATIONSHIP_CREATED');
 return to_jsonb(r);
end $$;
create or replace function public.unlink_development_objects(target_relationship uuid) returns jsonb
 language plpgsql security definer set search_path='' as $$
declare r public.development_object_relationships;s public.development_objects;t public.development_objects;
begin
 if public.current_platform_user_id() is null then
 if auth.uid() is null then raise exception 'Authentication required' using errcode='28000';end if;raise exception 'Access denied' using errcode='42501';end if;
 select * into r from public.development_object_relationships where id=target_relationship;
 if not found then raise exception 'Access denied' using errcode='42501';end if;
 select * into s from public.development_objects where id=r.source_object_id;
 select * into t from public.development_objects where id=r.target_object_id;
 perform public.require_development_object_write(s.project_id,s.workspace_id);
 perform public.require_development_object_write(t.project_id,t.workspace_id);
 perform 1 from public.development_objects where id in (s.id,t.id) order by id for update;
 select * into r from public.development_object_relationships where id=target_relationship for update;
 if r.status='active' then update public.development_object_relationships set status='inactive',updated_at=clock_timestamp() where id=r.id returning * into r;
 perform public.append_project_change(r.project_id,'DEVELOPMENT_OBJECT_RELATIONSHIP',r.id,'RELATIONSHIP_ARCHIVED');end if;
 return to_jsonb(r);
end $$;
create or replace function public.update_project_metadata(target_project uuid,changes jsonb) returns jsonb
 language plpgsql security definer set search_path='' as $$
declare p public.development_projects;next_name text;next_description text;next_stage text;next_status public.development_project_status;metadata_changed boolean;stage_changed boolean;status_changed boolean;
begin
 p:=public.require_development_project_write(target_project,true);
 select * into p from public.development_projects where id=target_project for update;
 -- Concurrent metadata updates serialize on the same canonical row.
 if p.archived_at is not null or p.status not in ('active','paused') then raise exception 'Access denied' using errcode='42501';end if;
 if changes is null or jsonb_typeof(changes)<>'object' or changes='{}' or exists(select 1 from jsonb_object_keys(changes) k where k not in ('name','description','status','current_stage')) then raise exception 'Invalid metadata input' using errcode='22023';end if;
 if (changes ? 'name' and (jsonb_typeof(changes->'name')<>'string' or length(regexp_replace(changes->>'name','^\s+|\s+$','','g'))=0 or length(regexp_replace(changes->>'name','^\s+|\s+$','','g'))>200))
 or (changes ? 'description' and jsonb_typeof(changes->'description') not in ('string','null'))
 or (changes ? 'current_stage' and (jsonb_typeof(changes->'current_stage') not in ('string','null') or (jsonb_typeof(changes->'current_stage')='string' and length(regexp_replace(changes->>'current_stage','^\s+|\s+$','','g'))=0)))
 or (changes ? 'status' and (jsonb_typeof(changes->'status')<>'string' or changes->>'status' not in ('active','paused','completed'))) then raise exception 'Invalid metadata input' using errcode='22023';end if;
 next_name:=case when changes ? 'name' then regexp_replace(changes->>'name','^\s+|\s+$','','g') else p.name end;
 next_description:=case when changes ? 'description' then changes->>'description' else p.description end;
 next_stage:=case when changes ? 'current_stage' then regexp_replace(changes->>'current_stage','^\s+|\s+$','','g') else p.current_stage end;
 next_status:=case when changes ? 'status' then (changes->>'status')::public.development_project_status else p.status end;
 if (next_name,next_description,next_stage,next_status) is not distinct from (p.name,p.description,p.current_stage,p.status) then return to_jsonb(p);end if;
 metadata_changed:=(next_name,next_description) is distinct from (p.name,p.description);
 stage_changed:=next_stage is distinct from p.current_stage;status_changed:=next_status is distinct from p.status;
 update public.development_projects set name=next_name,description=next_description,current_stage=next_stage,status=next_status,updated_at=clock_timestamp() where id=p.id returning * into p;
 if metadata_changed then perform public.append_project_change(p.id,'PROJECT',p.id,'PROJECT_METADATA_UPDATED');end if;
 if stage_changed then perform public.append_project_change(p.id,'PROJECT',p.id,'PROJECT_STAGE_CHANGED');end if;
 if status_changed then perform public.append_project_change(p.id,'PROJECT',p.id,'PROJECT_STATUS_CHANGED');end if;
 return to_jsonb(p);
end $$;
commit;
