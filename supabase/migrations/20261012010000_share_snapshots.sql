-- M13.2: frozen canonical entity content only; no recipient resolver or copying.
begin;
create function private.enforce_mvp_share_mode() returns trigger language plpgsql set search_path='' as $$
begin
 if new.share_mode<>'SNAPSHOT' then
  raise exception 'LIVE_REFERENCE is policy-deferred for M13 MVP' using errcode='0A000';
 end if;
 return new;
end $$;
revoke all on function private.enforce_mvp_share_mode() from public,anon,authenticated,service_role;
create trigger shares_00_mvp_mode before insert on public.shares for each row execute function private.enforce_mvp_share_mode();

create table public.share_snapshots (
 id uuid primary key default gen_random_uuid(),
 share_id uuid not null unique references public.shares(id) on delete restrict,
 source_version_id uuid references public.artifact_versions(id) on delete restrict,
 snapshot_data jsonb not null check(jsonb_typeof(snapshot_data)='object'),
 created_at timestamptz not null default clock_timestamp()
);
create index share_snapshots_version_lookup on public.share_snapshots(source_version_id) where source_version_id is not null;
alter table public.share_snapshots enable row level security;
revoke all on public.share_snapshots from public,anon,authenticated,service_role;

create function private.validate_share_snapshot() returns trigger language plpgsql set search_path='' as $$
declare s public.shares;v public.artifact_versions;body jsonb;creator uuid;version_creator uuid;
 source_workspace uuid;source_project uuid;owner_user uuid;owner_team uuid;frozen jsonb;
begin
 if tg_op<>'INSERT' then raise exception 'Share Snapshots are immutable history' using errcode='23514';end if;
 select * into s from public.shares where id=new.share_id for update;
 if not found then raise exception 'Invalid Snapshot Share' using errcode='23503';end if;
 if s.share_mode<>'SNAPSHOT' then raise exception 'LIVE_REFERENCE is policy-deferred for M13 MVP' using errcode='0A000';end if;
 if s.revoked_at is not null then raise exception 'Cannot snapshot a revoked Share' using errcode='23514';end if;
 if public.current_platform_user_id() is null or s.shared_by<>public.current_platform_user_id() then
  raise exception 'Invalid Snapshot attribution' using errcode='42501';end if;
 if s.shared_entity_type='ARTIFACT' then
  if new.source_version_id is null then raise exception 'Artifact Snapshot requires a canonical Version' using errcode='23514';end if;
  -- Follow the existing Artifact-before-Version mutation lock order.
  perform 1 from public.artifacts where id=s.shared_entity_id for share;
  select * into v from public.artifact_versions where id=new.source_version_id and artifact_id=s.shared_entity_id for share;
  if not found then raise exception 'Invalid Snapshot Version binding' using errcode='23514';end if;
  version_creator:=v.created_by;
 elsif new.source_version_id is not null then
  -- Other M13.1 entities have no canonical Version-row store. The Development
  -- Object counter is retained as content metadata, never fabricated into a UUID.
  raise exception 'Non-versioned source cannot bind an Artifact Version' using errcode='23514';
 end if;
 -- Explicit source-row projections; never serialize a whole row, traverse links,
 -- hydrate references, or include free-form metadata/storage capabilities.
 case s.shared_entity_type
 when 'ARTIFACT' then
  select a.workspace_id,a.project_id,a.created_by,jsonb_build_object('artifact_type',a.artifact_type,'title',a.title,
   'version_number',v.version_number,'version_label',v.version_label,'content_snapshot',v.content_snapshot)
   into source_workspace,source_project,creator,body from public.artifacts a where a.id=s.shared_entity_id for share;
 when 'DEVELOPMENT_OBJECT' then
  select o.workspace_id,o.project_id,o.created_by,jsonb_build_object('object_type',o.object_type,'title',o.title,'content',o.content,
   'current_version_number',o.current_version_number,'product_classification',o.product_classification)
   into source_workspace,source_project,creator,body from public.development_objects o where o.id=s.shared_entity_id for share;
 when 'FILE' then
  select f.workspace_id,f.project_id,f.uploaded_by,jsonb_build_object('filename',f.filename,'mime_type',f.mime_type,'size',f.size)
   into source_workspace,source_project,creator,body from public.files f where f.id=s.shared_entity_id for share;
 when 'EVIDENCE' then
  select e.workspace_id,e.project_id,e.created_by,jsonb_build_object('evidence_type',e.evidence_type,'title',e.title,'description',e.description,
   'source_name',e.source_name,'source_url',e.source_url,'claim_locator',e.claim_locator,'verification_status',e.verification_status)
   into source_workspace,source_project,creator,body from public.evidence e where e.id=s.shared_entity_id for share;
 when 'PATENT_RECORD' then
  select p.workspace_id,p.project_id,p.created_by,jsonb_build_object('publication_number',p.publication_number,'application_number',p.application_number,
   'title',p.title,'applicant',p.applicant,'inventor',p.inventor,'priority_date',p.priority_date,'filing_date',p.filing_date,
   'publication_date',p.publication_date,'ipc_cpc',p.ipc_cpc,'source_database',p.source_database,'source_url',p.source_url,'abstract_text',p.abstract_text)
   into source_workspace,source_project,creator,body from public.patent_records p where p.id=s.shared_entity_id for share;
 when 'SCAMPER_ENTRY' then
  select e.workspace_id,e.project_id,e.created_by,jsonb_build_object('scamper_type',e.scamper_type,'original_element',e.original_element,
   'proposed_change',e.proposed_change,'result_text',e.result_text)
   into source_workspace,source_project,creator,body from public.scamper_entries e where e.id=s.shared_entity_id for share;
 end case;
 if source_workspace is null or source_workspace<>s.source_workspace_id then raise exception 'Invalid Snapshot source scope' using errcode='23514';end if;
 if source_project is not null then
  select p.owner_user_id,p.owner_team_id into owner_user,owner_team from public.development_projects p
   where p.id=source_project and p.primary_workspace_id=source_workspace;
  if not found then raise exception 'Invalid Snapshot Project scope' using errcode='23514';end if;
 else
  -- Canonical ownership is immutable; avoid taking parent locks after source
  -- locks used by existing Project-first business mutations.
  select w.owner_user_id,w.team_id into owner_user,owner_team from public.workspaces w where w.id=source_workspace;
 end if;
 new.created_at:=clock_timestamp();
 frozen:=jsonb_build_object('provenance',jsonb_build_object('share_id',s.id,'source_entity_type',s.shared_entity_type,
  'source_entity_id',s.shared_entity_id,'source_version_id',new.source_version_id,'source_workspace_id',source_workspace,
  'source_owner_user_id',owner_user,'source_owner_team_id',owner_team,'source_created_by',creator,
  'source_version_created_by',version_creator,'snapshot_created_at',new.created_at),'content',body);
 if new.snapshot_data is not null and new.snapshot_data<>frozen then
  raise exception 'Snapshot payload must be server-derived' using errcode='23514';end if;
 new.snapshot_data:=frozen;
 return new;
end $$;
revoke all on function private.validate_share_snapshot() from public,anon,authenticated,service_role;
create trigger share_snapshots_frozen before insert or update or delete on public.share_snapshots for each row execute function private.validate_share_snapshot();
comment on table public.share_snapshots is 'Immutable canonical source projection and internal provenance. No recipient access, source traversal, copying or LIVE_REFERENCE behavior.';
comment on column public.share_snapshots.source_version_id is 'Required exact Artifact Version for ARTIFACT; null for sources without a canonical Version-row store.';
commit;
