begin;
-- Frozen display projection only. Never hydrate current map rows, linked Objects,
-- Files or source provenance. The existing renderer uses x/y and no free metadata.
create function private.project_shared_mind_map_content(body jsonb) returns jsonb
language sql immutable set search_path='' as $$
 select jsonb_build_object('artifact_type','MIND_MAP','title',body->'title',
  'version_number',body->'version_number','version_label',body->'version_label',
  'content_snapshot',jsonb_build_object('rootNodeId',body->'content_snapshot'->>'rootNodeId',
   'nodes',coalesce((select jsonb_agg(jsonb_build_object('id',n->>'id','nodeType',n->>'nodeType',
    'label',n->>'label','parentNodeId',n->>'parentNodeId','productClassification',
     case when n->>'productClassification' in('CORE','SUPPORTING','OPTIONAL_FUTURE') then n->>'productClassification' end,
    'positionData',jsonb_build_object('x',case when jsonb_typeof(n->'positionData'->'x')='number' then n->'positionData'->'x' else '0'::jsonb end,
     'y',case when jsonb_typeof(n->'positionData'->'y')='number' then n->'positionData'->'y' else '0'::jsonb end)) order by ordinal)
    from jsonb_array_elements(case when jsonb_typeof(body->'content_snapshot'->'nodes')='array' then body->'content_snapshot'->'nodes' else '[]'::jsonb end) with ordinality as nodes(n,ordinal)
    where jsonb_typeof(n)='object'),'[]'::jsonb),
   'edges',coalesce((select jsonb_agg(jsonb_build_object('id',e->>'id','sourceNodeId',e->>'sourceNodeId',
    'targetNodeId',e->>'targetNodeId','edgeType',e->>'edgeType','label',e->>'label') order by ordinal)
    from jsonb_array_elements(case when jsonb_typeof(body->'content_snapshot'->'edges')='array' then body->'content_snapshot'->'edges' else '[]'::jsonb end) with ordinality as edges(e,ordinal)
    where jsonb_typeof(e)='object'),'[]'::jsonb)))
$$;
revoke all on function private.project_shared_mind_map_content(jsonb) from public,anon,authenticated,service_role;
create function private.project_mind_map_share_snapshot() returns trigger
language plpgsql set search_path='' as $$
begin
 if new.snapshot_data->'content'->>'artifact_type'='MIND_MAP' then
  new.snapshot_data:=jsonb_set(new.snapshot_data,'{content}',private.project_shared_mind_map_content(new.snapshot_data->'content'));
 end if;
 return new;
end$$;
revoke all on function private.project_mind_map_share_snapshot() from public,anon,authenticated,service_role;
-- Alphabetical trigger order runs after the existing server-derived/frozen guard.
create trigger share_snapshots_safe_map_projection before insert on public.share_snapshots
 for each row execute function private.project_mind_map_share_snapshot();

-- Legacy Snapshots are projected from their frozen body, never rewritten or refreshed.
create or replace function public.resolve_shared_entity_access(input jsonb) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=public.current_platform_user_id();s public.shares;ss public.share_snapshots;w public.workspaces;
 wid uuid;pid uuid;destination_valid boolean:=false;v public.artifact_versions;provenance jsonb;
 denied jsonb:='{"allowed":false,"canView":false,"canComment":false,"canEdit":false,"canReshare":false,"isSnapshot":false,"isLiveReference":false}';
begin
 if actor is null or jsonb_typeof(input) is distinct from 'object' then return denied;end if;
 if not input?'shareId' or (select count(*) from jsonb_object_keys(input))<>1 or jsonb_typeof(input->'shareId') is distinct from 'string'
  or input->>'shareId' !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then return denied;end if;
 select * into s from public.shares where id=(input->>'shareId')::uuid;
 if not found or s.revoked_at is not null or s.share_mode<>'SNAPSHOT' or s.permission_level not in ('VIEW','COMMENT') then return denied;end if;
 select * into w from public.workspaces where id=s.source_workspace_id;
 if not found then return denied;end if;
 if s.destination_type='TEAM' then
  select exists(select 1 from public.teams t where t.id=s.destination_id and public.get_team_workspace_access(t.workspace_id) is not null) into destination_valid;
 elsif s.destination_type='MASTER' then
  select exists(select 1 from public.role_assignments ra join public.roles r on r.id=ra.role_id join public.users u on u.id=ra.user_id
   where ra.id=s.destination_id and ra.user_id=actor and r.code='MASTER' and u.account_status='active' and ra.status='active'
   and ra.starts_at<=statement_timestamp() and (ra.ends_at is null or ra.ends_at>statement_timestamp())
   and ra.organization_id is null and ra.program_id is null and ra.project_id is null
   and ((ra.team_id=w.team_id and ra.cohort_id is null) or (ra.cohort_id=w.cohort_id and ra.team_id is null))) into destination_valid;
 end if;
 if not destination_valid then return denied;end if;
 -- Independent structural validation, never recipient source membership. Frozen
 -- content is not recomputed from current source content or Version pointers.
 case s.shared_entity_type
 when 'ARTIFACT' then select workspace_id,project_id into wid,pid from public.artifacts where id=s.shared_entity_id;
 when 'DEVELOPMENT_OBJECT' then select workspace_id,project_id into wid,pid from public.development_objects where id=s.shared_entity_id;
 when 'FILE' then select workspace_id,project_id into wid,pid from public.files where id=s.shared_entity_id;
 when 'EVIDENCE' then select workspace_id,project_id into wid,pid from public.evidence where id=s.shared_entity_id;
 when 'PATENT_RECORD' then select workspace_id,project_id into wid,pid from public.patent_records where id=s.shared_entity_id;
 when 'SCAMPER_ENTRY' then select workspace_id,project_id into wid,pid from public.scamper_entries where id=s.shared_entity_id;
 end case;
 if wid is null or wid<>s.source_workspace_id or (pid is not null and not exists(select 1 from public.development_projects where id=pid and primary_workspace_id=wid)) then return denied;end if;
 select * into ss from public.share_snapshots where share_id=s.id;
 if not found then return denied;end if;
 provenance:=ss.snapshot_data->'provenance';
 if (provenance->>'share_id') is distinct from s.id::text or (provenance->>'source_entity_type') is distinct from s.shared_entity_type::text
  or (provenance->>'source_entity_id') is distinct from s.shared_entity_id::text or (provenance->>'source_workspace_id') is distinct from wid::text
  or (provenance->>'source_version_id') is distinct from ss.source_version_id::text
  or jsonb_typeof(ss.snapshot_data->'content') is distinct from 'object' then return denied;end if;
 if s.shared_entity_type='ARTIFACT' then
  select * into v from public.artifact_versions where id=ss.source_version_id and artifact_id=s.shared_entity_id;
  if not found then return denied;end if;
 elsif ss.source_version_id is not null then return denied;end if;
 return jsonb_build_object('allowed',true,'canView',true,'canComment',s.permission_level='COMMENT','canEdit',false,'canReshare',false,
  'isSnapshot',true,'isLiveReference',false,'shareId',s.id,'sharedEntityType',s.shared_entity_type,'sharedEntityId',s.shared_entity_id,
  'sourceVersionId',ss.source_version_id,'snapshotContent',case when s.shared_entity_type='ARTIFACT' and
   (ss.snapshot_data->'content'->>'artifact_type'='MIND_MAP' or exists(select 1 from public.artifacts a where a.id=s.shared_entity_id and a.artifact_type='MIND_MAP'))
   then private.project_shared_mind_map_content(ss.snapshot_data->'content') else ss.snapshot_data->'content' end);
end $$;
revoke all on function public.resolve_shared_entity_access(jsonb) from public,anon,authenticated,service_role;
grant execute on function public.resolve_shared_entity_access(jsonb) to authenticated;
comment on function public.resolve_shared_entity_access(jsonb) is 'M13.5 caller-bound current TEAM/exact MASTER recipient capabilities plus frozen projection only. No source ACL, File signing, live reference, edits, re-sharing or internal provenance exposure.';

commit;
