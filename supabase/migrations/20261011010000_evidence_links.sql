begin;
create type public.evidence_link_entity_type as enum ('DECISION','REQUIREMENT','GAP','ARTIFACT','PATENT_RECORD');
create type public.evidence_relationship_type as enum ('SUPPORTS','CONTRADICTS','VALIDATES','SOURCE_FOR','RELATED_TO');
create table public.evidence_links (
 id uuid primary key default gen_random_uuid(),
 evidence_id uuid not null references public.evidence(id) on update restrict on delete restrict,
 linked_entity_type public.evidence_link_entity_type not null,
 linked_entity_id uuid not null,
 relationship_type public.evidence_relationship_type not null,
 notes text,
 created_by uuid not null default public.current_platform_user_id() references public.users(id) on update restrict on delete restrict,
 created_at timestamptz not null default now(),
 archived_at timestamptz check(archived_at is null or archived_at>=created_at)
);
create unique index evidence_links_active_identity on public.evidence_links(evidence_id,linked_entity_type,linked_entity_id,relationship_type) where archived_at is null;
-- The unique index also supports Evidence lookup; include historical rows with
-- this separate index because future archive must not impair history loading.
create index evidence_links_source on public.evidence_links(evidence_id);
create index evidence_links_target on public.evidence_links(linked_entity_type,linked_entity_id);
comment on column public.evidence_links.linked_entity_id is 'Stable Decision / REQUIREMENT or GAP Development Object / Artifact identity. Polymorphic identity validated against canonical tables, never a fictitious generic FK. PATENT_RECORD resolution deferred to its owning M12 milestone.';
comment on column public.evidence_links.archived_at is 'History-preserving archive foundation only; no unlink/restore API in M12.2.';

-- Private, caller-bound target validation. Canonical target identities and
-- scopes are already immutable and their ordinary hard deletion is forbidden.
create function private.evidence_target_allowed(kind public.evidence_link_entity_type,target uuid,project uuid,workspace uuid,new_link boolean) returns boolean
language sql stable set search_path='' as $$
 select public.can_read_development_project(project) and case
 when kind='DECISION' then exists(select 1 from public.decisions d where d.id=target and d.project_id=project and d.workspace_id=workspace and public.can_read_decision(d.id) and (not new_link or d.status<>'ARCHIVED'))
 when kind in ('GAP','REQUIREMENT') then exists(select 1 from public.development_objects o where o.id=target and o.object_type::text=kind::text and o.project_id=project and o.workspace_id=workspace and (not new_link or o.archived_at is null))
 when kind='ARTIFACT' then exists(select 1 from public.artifacts a where a.id=target and a.project_id=project and a.workspace_id=workspace
  and (not new_link or a.status='ACTIVE')
  and (a.artifact_type<>'MIND_MAP' or public.can_read_private_mind_map(a.id))
  and (a.artifact_type not in ('MINIMUM_ESSENTIAL_STRUCTURE','INVENTION_CONCEPT') or public.can_read_session7_output(a.id)))
 else false end;
$$;
revoke all on function private.evidence_target_allowed(public.evidence_link_entity_type,uuid,uuid,uuid,boolean) from public,anon,authenticated,service_role;

create function private.preserve_evidence_link() returns trigger language plpgsql set search_path='' as $$
declare e public.evidence;
begin
 if tg_op='DELETE' then raise exception 'Evidence Link history is preserved' using errcode='55000';end if;
 if tg_op='UPDATE' then
  if (new.id,new.evidence_id,new.linked_entity_type,new.linked_entity_id,new.relationship_type,new.notes,new.created_by,new.created_at)
   is distinct from (old.id,old.evidence_id,old.linked_entity_type,old.linked_entity_id,old.relationship_type,old.notes,old.created_by,old.created_at)
   or (old.archived_at is not null and new.archived_at is distinct from old.archived_at)
  then raise exception 'Evidence Link identity/history is immutable' using errcode='23514';end if;
  return new;
 end if;
 select * into e from public.evidence where id=new.evidence_id;
 if new.created_by is distinct from public.current_platform_user_id() or new.archived_at is not null or e.id is null or e.archived_at is not null
 or not private.evidence_target_allowed(new.linked_entity_type,new.linked_entity_id,e.project_id,e.workspace_id,true)
 then raise exception 'Resource unavailable' using errcode='42501';end if;
 return new;
end $$;
revoke all on function private.preserve_evidence_link() from public,anon,authenticated,service_role;
create trigger evidence_links_history before insert or update or delete on public.evidence_links for each row execute function private.preserve_evidence_link();

alter table public.evidence_links enable row level security;
revoke all on public.evidence_links from public,anon,authenticated,service_role;
grant select on public.evidence_links to authenticated;
-- Invoker subqueries compose BOTH source and target RLS. Links never become an
-- alternative authorization path into either table or its private metadata.
create policy evidence_links_read on public.evidence_links for select to authenticated using(
 exists(select 1 from public.evidence e where e.id=evidence_id and (
  (linked_entity_type='DECISION' and exists(select 1 from public.decisions d where d.id=linked_entity_id and d.project_id=e.project_id and d.workspace_id=e.workspace_id))
  or (linked_entity_type in ('GAP','REQUIREMENT') and exists(select 1 from public.development_objects o where o.id=linked_entity_id and o.object_type::text=linked_entity_type::text and o.project_id=e.project_id and o.workspace_id=e.workspace_id))
  or (linked_entity_type='ARTIFACT' and exists(select 1 from public.artifacts a where a.id=linked_entity_id and a.project_id=e.project_id and a.workspace_id=e.workspace_id))
 )));
create policy evidence_links_no_insert on public.evidence_links as restrictive for insert to authenticated with check(false);
create policy evidence_links_no_update on public.evidence_links as restrictive for update to authenticated using(false) with check(false);
create policy evidence_links_no_delete on public.evidence_links as restrictive for delete to authenticated using(false);

create function public.link_evidence(input jsonb) returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare actor uuid:=public.current_platform_user_id();e public.evidence;l public.evidence_links;kind public.evidence_link_entity_type;relation public.evidence_relationship_type;target uuid;source uuid;
begin
 if actor is null then
  if auth.uid() is null then raise exception 'Authentication required' using errcode='28000';end if;
  raise exception 'Resource unavailable' using errcode='42501';end if;
 if input is null or jsonb_typeof(input)<>'object' or exists(select 1 from jsonb_object_keys(input) k where k not in ('evidenceId','entityType','entityId','relationshipType','notes'))
 or jsonb_typeof(input->'evidenceId') is distinct from 'string' or jsonb_typeof(input->'entityId') is distinct from 'string'
 or jsonb_typeof(input->'entityType') is distinct from 'string' or jsonb_typeof(input->'relationshipType') is distinct from 'string'
 or (input ? 'notes' and jsonb_typeof(input->'notes') is distinct from 'string')
 then raise exception 'Invalid link input' using errcode='22023';end if;
 source:=(input->>'evidenceId')::uuid;target:=(input->>'entityId')::uuid;
 kind:=(input->>'entityType')::public.evidence_link_entity_type;relation:=(input->>'relationshipType')::public.evidence_relationship_type;
 select * into e from public.evidence where id=source;
 if e.id is null or not public.can_read_development_project(e.project_id) then raise exception 'Resource unavailable' using errcode='42501';end if;
 perform public.require_development_object_write(e.project_id,e.workspace_id);
 -- Parent lock serializes duplicate creation and archive; canonical write
 -- validation locks current account/enrollment/Team/Project authority.
 select * into e from public.evidence where id=source for update;
 if kind='PATENT_RECORD' then raise exception 'Target dependency unavailable' using errcode='0A000';end if;
 if kind='DECISION' then perform 1 from public.decisions where id=target for share;
 elsif kind='ARTIFACT' then perform 1 from public.artifacts where id=target for share;
 else perform 1 from public.development_objects where id=target for share;end if;
 perform public.require_development_object_write(e.project_id,e.workspace_id);
 select * into l from public.evidence_links where evidence_id=source and linked_entity_type=kind and linked_entity_id=target and relationship_type=relation and archived_at is null;
 if not private.evidence_target_allowed(kind,target,e.project_id,e.workspace_id,l.id is null) then raise exception 'Resource unavailable' using errcode='42501';end if;
 if l.id is not null then return to_jsonb(l);end if;
 if e.archived_at is not null then raise exception 'Resource unavailable' using errcode='42501';end if;
 insert into public.evidence_links(evidence_id,linked_entity_type,linked_entity_id,relationship_type,notes,created_by)
 values(source,kind,target,relation,input->>'notes',actor) returning * into l;
 if public.current_platform_user_id() is distinct from actor then raise exception 'Resource unavailable' using errcode='42501';end if;
 return to_jsonb(l);
end $$;
revoke all on function public.link_evidence(jsonb) from public,anon,authenticated,service_role;
grant execute on function public.link_evidence(jsonb) to authenticated;
comment on function public.link_evidence(jsonb) is 'M12.2 exact-scope current Project write + both endpoint read authorization, immutable reference, serialized canonical retry. No verification, target mutation, access transfer or sharing.';
commit;
