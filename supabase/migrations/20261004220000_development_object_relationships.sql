begin;
create type public.development_relationship_type as enum ('SOLVES','IMPLEMENTS','SUPPORTS','DEPENDS_ON','BELONGS_TO','CONNECTED_TO','DERIVED_FROM','VALIDATES','CONTRADICTS','TESTED_BY','EVIDENCE_FOR','EVIDENCE_AGAINST','REPLACES','SUPERSEDES','IDENTIFIED_IN');
create type public.development_relationship_status as enum ('active','inactive');
alter table public.development_objects add constraint development_objects_id_project_unique unique(id,project_id);
create table public.development_object_relationships (
 id uuid primary key default gen_random_uuid(),
 project_id uuid not null references public.development_projects(id) on delete restrict,
 source_object_id uuid not null,target_object_id uuid not null,
 relationship_type public.development_relationship_type not null,
 description text,
 created_by uuid not null references public.users(id) on delete restrict,
 status public.development_relationship_status not null default 'active',
 created_at timestamptz not null default now(),updated_at timestamptz not null default now(),
 foreign key(source_object_id,project_id) references public.development_objects(id,project_id) on delete restrict on update restrict,
 foreign key(target_object_id,project_id) references public.development_objects(id,project_id) on delete restrict on update restrict,
 check(source_object_id<>target_object_id)
);
create unique index development_relationships_active_edge on public.development_object_relationships(project_id,source_object_id,target_object_id,relationship_type) where status='active';
create index development_relationships_source on public.development_object_relationships(source_object_id);
create index development_relationships_target on public.development_object_relationships(target_object_id);
create index development_relationships_project_status on public.development_object_relationships(project_id,status);
create function public.preserve_development_relationship_history() returns trigger language plpgsql set search_path='' as $$
begin
 if tg_op='DELETE' then raise exception 'Relationship history must be preserved' using errcode='23514';end if;
 if (new.id,new.project_id,new.source_object_id,new.target_object_id,new.relationship_type,new.description,new.created_by,new.created_at) is distinct from
 (old.id,old.project_id,old.source_object_id,old.target_object_id,old.relationship_type,old.description,old.created_by,old.created_at)
 or (old.status='inactive' and new is distinct from old) then raise exception 'Relationship identity/history is immutable' using errcode='23514';end if;
 return new;
end $$;
revoke all on function public.preserve_development_relationship_history() from public,anon,authenticated,service_role;
create trigger development_relationships_preserve_history before update or delete on public.development_object_relationships for each row execute function public.preserve_development_relationship_history();
alter table public.development_object_relationships enable row level security;
revoke all on public.development_object_relationships from public,anon,authenticated,service_role;
grant select on public.development_object_relationships to authenticated;
create policy development_relationships_read on public.development_object_relationships for select to authenticated using(exists(select 1 from public.development_projects p where p.id=development_object_relationships.project_id)
 and exists(select 1 from public.development_objects o where o.id=development_object_relationships.source_object_id and o.project_id=development_object_relationships.project_id)
 and exists(select 1 from public.development_objects o where o.id=development_object_relationships.target_object_id and o.project_id=development_object_relationships.project_id));
create policy development_relationships_read_guard on public.development_object_relationships as restrictive for select to authenticated using(exists(select 1 from public.development_projects p where p.id=development_object_relationships.project_id)
 and exists(select 1 from public.development_objects o where o.id=development_object_relationships.source_object_id and o.project_id=development_object_relationships.project_id)
 and exists(select 1 from public.development_objects o where o.id=development_object_relationships.target_object_id and o.project_id=development_object_relationships.project_id));
create policy development_relationships_insert_deny on public.development_object_relationships as restrictive for insert to authenticated with check(false);
create policy development_relationships_update_deny on public.development_object_relationships as restrictive for update to authenticated using(false) with check(false);
create policy development_relationships_delete_deny on public.development_object_relationships as restrictive for delete to authenticated using(false);
create policy development_relationships_anon_deny on public.development_object_relationships as restrictive for all to anon using(false) with check(false);
-- Definer RPCs are narrow identity-bound mutations, not general CRUD. Fixed empty
-- search_path and private M6.6 locking validator preserve current authorization.
create function public.relate_development_objects(source_object uuid,target_object uuid,kind public.development_relationship_type,relationship_description text default null) returns jsonb
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
 return to_jsonb(r);
end $$;
create function public.unlink_development_objects(target_relationship uuid) returns jsonb
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
 if r.status='active' then update public.development_object_relationships set status='inactive',updated_at=clock_timestamp() where id=r.id returning * into r;end if;
 return to_jsonb(r);
end $$;
revoke all on function public.relate_development_objects(uuid,uuid,public.development_relationship_type,text) from public,anon,authenticated,service_role;
revoke all on function public.unlink_development_objects(uuid) from public,anon,authenticated,service_role;
grant execute on function public.relate_development_objects(uuid,uuid,public.development_relationship_type,text) to authenticated;
grant execute on function public.unlink_development_objects(uuid) to authenticated;
comment on table public.development_object_relationships is 'Explicit directional semantic edges; inactive rows preserve unlink history. No inverse generation or Object cloning. Current edges must exclude archived endpoints; authorized historical reads remain subject to both Objects RLS.';
commit;
