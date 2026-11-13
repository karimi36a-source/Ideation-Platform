begin;
create table public.artifact_object_links (
 id uuid primary key default gen_random_uuid(),
 artifact_id uuid not null references public.artifacts(id) on update restrict on delete restrict,
 artifact_version_id uuid not null,
 development_object_id uuid not null references public.development_objects(id) on update restrict on delete restrict,
 role_in_artifact text check(role_in_artifact is null or (role_in_artifact=btrim(role_in_artifact) and length(role_in_artifact)>0)),
 sequence integer check(sequence is null or sequence>=0),
 metadata jsonb not null default '{}'::jsonb check(jsonb_typeof(metadata)='object'),
 constraint artifact_object_links_version_parent foreign key(artifact_version_id,artifact_id) references public.artifact_versions(id,artifact_id) on update restrict on delete restrict,
 constraint artifact_object_links_membership_unique unique(artifact_version_id,development_object_id)
);
create index artifact_object_links_artifact_lookup on public.artifact_object_links(artifact_id);
-- Membership uniqueness already supplies the Version lookup index.
create index artifact_object_links_object_lookup on public.artifact_object_links(development_object_id);
-- Invoker structural validation only: no caller identity or business mutation API.
create function public.validate_artifact_object_link_scope() returns trigger language plpgsql set search_path='' as $$
declare a public.artifacts; o public.development_objects;
begin
 select * into a from public.artifacts where id=new.artifact_id for key share;
 select * into o from public.development_objects where id=new.development_object_id for key share;
 if a.id is null or o.id is null then raise exception 'Invalid link reference' using errcode='23503';end if;
 if (a.project_id,a.workspace_id) is distinct from (o.project_id,o.workspace_id) then
  raise exception 'Invalid link scope' using errcode='23514';end if;
 return new;
end $$;
revoke all on function public.validate_artifact_object_link_scope() from public,anon,authenticated,service_role;
create trigger artifact_object_links_validate_scope before insert or update on public.artifact_object_links for each row execute function public.validate_artifact_object_link_scope();
alter table public.artifact_object_links enable row level security;
revoke all on public.artifact_object_links from public,anon,authenticated,service_role;
grant select on public.artifact_object_links to authenticated;
create policy artifact_object_links_read on public.artifact_object_links for select to authenticated using(
 exists(select 1 from public.artifact_versions v where v.id=artifact_version_id and v.artifact_id=artifact_object_links.artifact_id)
 and exists(select 1 from public.development_objects o where o.id=development_object_id));
create policy artifact_object_links_read_guard on public.artifact_object_links as restrictive for select to authenticated using(
 exists(select 1 from public.artifact_versions v where v.id=artifact_version_id and v.artifact_id=artifact_object_links.artifact_id)
 and exists(select 1 from public.development_objects o where o.id=development_object_id));
create policy artifact_object_links_insert_deny on public.artifact_object_links as restrictive for insert to authenticated with check(false);
create policy artifact_object_links_update_deny on public.artifact_object_links as restrictive for update to authenticated using(false) with check(false);
create policy artifact_object_links_delete_deny on public.artifact_object_links as restrictive for delete to authenticated using(false);
create policy artifact_object_links_anon_deny on public.artifact_object_links as restrictive for all to anon using(false) with check(false);
comment on table public.artifact_object_links is 'Canonical Object references only, exact Artifact Project/Workspace, dual parent/Object RLS. No public mutation or Version membership editing workflow in M8.3.';
comment on column public.artifact_object_links.role_in_artifact is 'Nullable trimmed contextual text, not controlled vocabulary, authorization or Object type.';
comment on column public.artifact_object_links.metadata is 'Contextual JSON object only; never canonical content, scope or approval authority.';
commit;
