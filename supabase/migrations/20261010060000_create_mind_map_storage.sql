begin;
-- M11.7 storage only. No client operation or collaboration authority.
create table public.mind_maps (
 id uuid primary key default gen_random_uuid(),
 artifact_id uuid not null references public.artifacts(id) on update restrict on delete restrict,
 artifact_version_id uuid not null,
 root_node_id uuid,
 constraint mind_map_version_artifact foreign key(artifact_version_id,artifact_id)
  references public.artifact_versions(id,artifact_id) on update restrict on delete restrict
);
create table public.mind_map_nodes (
 id uuid primary key default gen_random_uuid(),
 mind_map_id uuid not null references public.mind_maps(id) on update restrict on delete restrict,
 node_type text not null check(length(btrim(node_type)) between 1 and 200),
 label text not null check(length(btrim(label)) between 1 and 200),
 development_object_id uuid references public.development_objects(id) on update restrict on delete restrict,
 parent_node_id uuid,
 position_data jsonb not null default '{}' check(jsonb_typeof(position_data)='object'),
 metadata jsonb not null default '{}' check(jsonb_typeof(metadata)='object'),
 created_by uuid not null references public.users(id) on update restrict on delete restrict,
 constraint mind_map_node_identity unique(id,mind_map_id),
 constraint mind_map_node_not_own_parent check(parent_node_id is distinct from id),
 constraint mind_map_parent_same_map foreign key(parent_node_id,mind_map_id)
  references public.mind_map_nodes(id,mind_map_id) on update restrict on delete restrict
);
-- Nullable root permits map -> nodes -> root creation in a single transaction.
alter table public.mind_maps add constraint mind_map_root_same_map
 foreign key(root_node_id,id) references public.mind_map_nodes(id,mind_map_id)
 on update restrict on delete restrict;
create table public.mind_map_edges (
 id uuid primary key default gen_random_uuid(),
 mind_map_id uuid not null references public.mind_maps(id) on update restrict on delete restrict,
 source_node_id uuid not null,
 target_node_id uuid not null,
 edge_type text not null check(length(btrim(edge_type)) between 1 and 200),
 label text check(label is null or length(btrim(label)) between 1 and 200),
 metadata jsonb not null default '{}' check(jsonb_typeof(metadata)='object'),
 constraint mind_map_edge_source_same_map foreign key(source_node_id,mind_map_id)
  references public.mind_map_nodes(id,mind_map_id) on update restrict on delete restrict,
 constraint mind_map_edge_target_same_map foreign key(target_node_id,mind_map_id)
  references public.mind_map_nodes(id,mind_map_id) on update restrict on delete restrict
);
-- Invoker trigger, not a privileged API. Lock the Artifact while validating its
-- type; the counterpart trigger below preserves existing map/type bindings.
create function private.validate_mind_map_artifact() returns trigger
 language plpgsql set search_path='' as $$
begin
 if not exists(select 1 from public.artifacts where id=new.artifact_id and artifact_type='MIND_MAP' for share) then
  raise exception 'Mind Map requires MIND_MAP Artifact' using errcode='23514';
 end if;
 if tg_op='UPDATE' and (new.id,new.artifact_id,new.artifact_version_id) is distinct from (old.id,old.artifact_id,old.artifact_version_id) then
  raise exception 'Mind Map identity is immutable' using errcode='23514';
 end if;
 return new;
end $$;
revoke all on function private.validate_mind_map_artifact() from public,anon,authenticated,service_role;
create trigger mind_map_artifact_guard before insert or update on public.mind_maps
 for each row execute function private.validate_mind_map_artifact();
create function private.preserve_mind_map_artifact_type() returns trigger
 language plpgsql set search_path='' as $$
begin
 if new.artifact_type<>'MIND_MAP' and exists(select 1 from public.mind_maps where artifact_id=old.id) then
  raise exception 'Referenced Mind Map Artifact type is immutable' using errcode='23514';
 end if;
 return new;
end $$;
revoke all on function private.preserve_mind_map_artifact_type() from public,anon,authenticated,service_role;
create trigger mind_map_artifact_type_guard before update of artifact_type on public.artifacts
 for each row execute function private.preserve_mind_map_artifact_type();
create index mind_map_artifact_lookup on public.mind_maps(artifact_id);
create index mind_map_version_lookup on public.mind_maps(artifact_version_id);
create index mind_map_node_map_lookup on public.mind_map_nodes(mind_map_id);
create index mind_map_node_parent_lookup on public.mind_map_nodes(parent_node_id,mind_map_id);
create index mind_map_node_object_lookup on public.mind_map_nodes(development_object_id) where development_object_id is not null;
create index mind_map_node_creator_lookup on public.mind_map_nodes(created_by);
create index mind_map_edge_map_lookup on public.mind_map_edges(mind_map_id);
create index mind_map_edge_source_lookup on public.mind_map_edges(source_node_id,mind_map_id);
create index mind_map_edge_target_lookup on public.mind_map_edges(target_node_id,mind_map_id);
alter table public.mind_maps enable row level security;
alter table public.mind_map_nodes enable row level security;
alter table public.mind_map_edges enable row level security;
revoke all on public.mind_maps,public.mind_map_nodes,public.mind_map_edges from public,anon,authenticated,service_role;
create policy mind_maps_client_deny on public.mind_maps as restrictive for all to authenticated using(false) with check(false);
create policy mind_map_nodes_client_deny on public.mind_map_nodes as restrictive for all to authenticated using(false) with check(false);
create policy mind_map_edges_client_deny on public.mind_map_edges as restrictive for all to authenticated using(false) with check(false);
comment on table public.mind_maps is 'M11.7 schema only; root semantics and operations deferred. No client access. Artifact/Version binding immutable.';
comment on table public.mind_map_nodes is 'Visual references, never canonical Object copies. Extensible nonblank node_type; exact taxonomy/root and coordinate semantics deferred.';
comment on table public.mind_map_edges is 'Visual edges only; no automatic canonical relationship writes. Extensible nonblank edge_type; self-edge product policy deferred.';
commit;
