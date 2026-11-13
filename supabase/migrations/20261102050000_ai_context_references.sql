begin;
-- Canonical source names; COURSE_CONTEXT uses the existing immutable Activity
-- execution configuration_snapshot, not a new course-content entity.
create type public.ai_context_entity_type as enum ('PROJECT','ARTIFACT_VERSION','DEVELOPMENT_OBJECT','DECISION','FEEDBACK_ITEM','EVIDENCE','PATENT_RECORD','ACTIVITY_INSTANCE');
create type public.ai_context_role as enum ('CURRENT_PROJECT','CURRENT_ARTIFACT','PRIOR_APPROVED_OUTPUT','TEAM_DECISION','INSTRUCTOR_FEEDBACK','EVIDENCE','PATENT','GAP','COURSE_CONTEXT');
create table public.ai_context_references (
 id uuid primary key default gen_random_uuid(),
 ai_output_id uuid not null references public.ai_outputs(id) on delete restrict,
 entity_type public.ai_context_entity_type not null,
 entity_id uuid not null,
 context_role public.ai_context_role not null,
 included_snapshot_hash text not null check(included_snapshot_hash ~ '^[0-9a-f]{64}$'),
 permission_scope jsonb not null,
 share_snapshot_id uuid references public.share_snapshots(id) on delete restrict,
 check(permission_scope=case when share_snapshot_id is null then '{"access":"SOURCE"}'::jsonb else '{"access":"SHARE_SNAPSHOT"}'::jsonb end),
 check(case context_role
  when 'CURRENT_PROJECT' then entity_type='PROJECT'
  when 'CURRENT_ARTIFACT' then entity_type='ARTIFACT_VERSION'
  when 'PRIOR_APPROVED_OUTPUT' then entity_type='ARTIFACT_VERSION'
  when 'TEAM_DECISION' then entity_type='DECISION'
  when 'INSTRUCTOR_FEEDBACK' then entity_type='FEEDBACK_ITEM'
  when 'EVIDENCE' then entity_type='EVIDENCE'
  when 'PATENT' then entity_type='PATENT_RECORD'
  when 'GAP' then entity_type='DEVELOPMENT_OBJECT'
  when 'COURSE_CONTEXT' then entity_type='ACTIVITY_INSTANCE' end)
);
create index ai_context_references_output on public.ai_context_references(ai_output_id);
create index ai_context_references_entity on public.ai_context_references(entity_type,entity_id);
create index ai_context_references_snapshot on public.ai_context_references(share_snapshot_id) where share_snapshot_id is not null;

-- Trusted insertion only; ordinary clients cannot invoke this trigger or write
-- rows. Reuse canonical Project/Workspace and Share authority, never IDs as ACLs.
create function private.preserve_ai_context_reference() returns trigger
language plpgsql set search_path='' as $$
declare o public.ai_outputs;actor uuid:=public.current_platform_user_id();body jsonb;
 pid uuid;wid uuid;ss public.share_snapshots;s public.shares;access_result jsonb;
 v public.artifact_versions;a public.artifacts;f public.feedback_items;
begin
 if tg_op<>'INSERT' then raise exception 'AI context history is immutable' using errcode='55000';end if;
 select * into o from public.ai_outputs where id=new.ai_output_id for share;
 if actor is null or o.id is null or o.requested_by is distinct from actor then
  raise exception 'Context unavailable' using errcode='42501';end if;
 -- References and generated output must be saved atomically, not appended to
 -- old output after permissions/content have changed.
 -- Own transaction-ID locks include subtransactions used by atomic RPC error
 -- handling. A top-level transaction-ID comparison would wrongly reject them.
 if not exists(select 1 from public.ai_outputs x join pg_catalog.pg_locks l on l.transactionid=x.xmin
  where x.id=o.id and l.locktype='transactionid' and l.pid=pg_backend_pid() and l.mode='ExclusiveLock' and l.granted) then
  raise exception 'Context must be captured with its output' using errcode='55000';end if;
 perform public.require_development_object_write(o.project_id,o.workspace_id);
 if new.share_snapshot_id is not null then
  select * into ss from public.share_snapshots where id=new.share_snapshot_id;
  select * into s from public.shares where id=ss.share_id for share;
  access_result:=public.resolve_shared_entity_access(jsonb_build_object('shareId',s.id));
  if (access_result->>'allowed') is distinct from 'true' or not (
   (new.entity_type='ARTIFACT_VERSION' and s.shared_entity_type='ARTIFACT' and ss.source_version_id=new.entity_id)
   or (new.entity_type::text=s.shared_entity_type::text and new.entity_id=s.shared_entity_id
    and new.entity_type in ('DEVELOPMENT_OBJECT','EVIDENCE','PATENT_RECORD'))
  ) then raise exception 'Context unavailable' using errcode='42501';end if;
  body:=access_result->'snapshotContent';
  if new.context_role='GAP' and body->>'object_type' is distinct from 'GAP' then raise exception 'Context unavailable' using errcode='42501';end if;
  new.permission_scope:='{"access":"SHARE_SNAPSHOT"}';
 else
  case new.entity_type
   when 'PROJECT' then select to_jsonb(p),p.id,p.primary_workspace_id into body,pid,wid from public.development_projects p where p.id=new.entity_id for share;
   when 'ARTIFACT_VERSION' then
    select * into v from public.artifact_versions where id=new.entity_id for share;
    select * into a from public.artifacts where id=v.artifact_id for share;
    if a.id is not null and (a.artifact_type<>'MIND_MAP' or public.can_read_private_mind_map(a.id))
     and (a.artifact_type not in ('INVENTION_CONCEPT','MINIMUM_ESSENTIAL_STRUCTURE') or public.can_read_session7_output(a.id)) then
     body:=v.content_snapshot;pid:=a.project_id;wid:=a.workspace_id;
    end if;
   when 'DEVELOPMENT_OBJECT' then select to_jsonb(d),d.project_id,d.workspace_id into body,pid,wid from public.development_objects d where d.id=new.entity_id and (new.context_role<>'GAP' or d.object_type='GAP') for share;
   when 'DECISION' then select to_jsonb(d),d.project_id,d.workspace_id into body,pid,wid from public.decisions d where d.id=new.entity_id and public.can_read_decision(d.id) for share;
   when 'FEEDBACK_ITEM' then
    select * into f from public.feedback_items where id=new.entity_id for share;
    select b.* into a from public.artifacts b join public.submissions t on t.artifact_id=b.id where t.id=f.submission_id;
    if a.id is not null and (a.artifact_type<>'MIND_MAP' or public.can_read_private_mind_map(a.id))
     and (a.artifact_type not in ('INVENTION_CONCEPT','MINIMUM_ESSENTIAL_STRUCTURE') or public.can_read_session7_output(a.id)) then
     body:=to_jsonb(f);pid:=f.project_id;wid:=a.workspace_id;
    end if;
   when 'EVIDENCE' then select to_jsonb(e),e.project_id,e.workspace_id into body,pid,wid from public.evidence e where e.id=new.entity_id for share;
   when 'PATENT_RECORD' then select to_jsonb(p),p.project_id,p.workspace_id into body,pid,wid from public.patent_records p where p.id=new.entity_id for share;
   when 'ACTIVITY_INSTANCE' then select x.configuration_snapshot,x.project_id,x.workspace_id into body,pid,wid from public.activity_instances x where x.id=new.entity_id and x.id=o.activity_instance_id and public.can_read_activity_instance(x.id) for share;
  end case;
  if body is null or (pid,wid) is distinct from (o.project_id,o.workspace_id) or not public.can_read_development_project(pid) then
   raise exception 'Context unavailable' using errcode='42501';end if;
  new.permission_scope:='{"access":"SOURCE"}';
 end if;
 if new.context_role='PRIOR_APPROVED_OUTPUT' and not exists(select 1 from public.artifact_versions where id=new.entity_id and status in ('APPROVED','CURRENT','SUPERSEDED') and approved_by is not null and approved_at is not null) then
  raise exception 'Approved context unavailable' using errcode='42501';end if;
 new.included_snapshot_hash:=encode(sha256(convert_to(body::text,'UTF8')),'hex');
 return new;
end$$;
revoke all on function private.preserve_ai_context_reference() from public,anon,authenticated,service_role;
create trigger ai_context_references_preserve before insert or update or delete on public.ai_context_references for each row execute function private.preserve_ai_context_reference();
alter table public.ai_context_references enable row level security;
revoke all on public.ai_context_references from public,anon,authenticated,service_role;
grant select on public.ai_context_references to authenticated;
create policy ai_context_references_parent_read on public.ai_context_references for select to authenticated using(exists(select 1 from public.ai_outputs o where o.id=ai_output_id));
create policy ai_context_references_no_insert on public.ai_context_references as restrictive for insert to authenticated with check(false);
create policy ai_context_references_no_update on public.ai_context_references as restrictive for update to authenticated using(false) with check(false);
create policy ai_context_references_no_delete on public.ai_context_references as restrictive for delete to authenticated using(false);
comment on table public.ai_context_references is 'M14.2 immutable provenance only; no source ACL, resolver, Context Builder or provider call. Current source authorization is always independent.';
comment on column public.ai_context_references.share_snapshot_id is 'Exact frozen recipient representation used; never private-source authority. Revocation retains provenance without granting current access.';
commit;
