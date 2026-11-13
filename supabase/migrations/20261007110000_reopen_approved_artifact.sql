begin;

-- Extend the immutable audit foundation only for the approved Artifact reopen
-- event. Generated targets retain database-level identity integrity.
alter table public.audit_events drop constraint audit_events_context_check;
alter table public.audit_events add constraint audit_events_context_check check (
 (event_type in ('TEAM_CREATED','MEMBER_ADDED','MEMBER_REMOVED','MEMBER_MOVED','TEAM_LEAD_CHANGED','TEAM_ARCHIVED') and entity_type='team' and scope_type='team')
 or (event_type in ('REVISION_REQUESTED','ARTIFACT_APPROVED') and entity_type='submission' and scope_type='submission' and metadata='{}'::jsonb)
 or (event_type='ARTIFACT_REOPENED' and entity_type='artifact' and scope_type='artifact' and entity_id=scope_id and metadata='{}'::jsonb));
alter table public.audit_events
 add column artifact_target_id uuid generated always as (case when entity_type='artifact' then entity_id end) stored
 references public.artifacts(id) on update restrict on delete restrict;

-- Caller authority is exactly the existing protected Version-write boundary.
-- The Artifact row serializes numbering, approval, archive, and concurrent reopen.
create function public.reopen_approved_artifact(target_artifact uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid;a public.artifacts;source public.artifact_versions;draft public.artifact_versions;next_number bigint;stamp timestamptz;
begin
 actor:=public.current_platform_user_id();
 if actor is null then
  if auth.uid() is null then raise exception 'Authentication required' using errcode='28000';end if;
  raise exception 'Access denied' using errcode='42501';
 end if;
 select * into a from public.artifacts where id=target_artifact;
 if a.id is null then raise exception 'Access denied' using errcode='42501';end if;
 perform public.require_development_object_write(a.project_id,a.workspace_id);
 select * into a from public.artifacts where id=target_artifact for update;
 if a.id is null or a.status<>'ACTIVE' or a.archived_at is not null
  or a.current_version_id is null or public.current_platform_user_id() is distinct from actor
 then raise exception 'Access denied' using errcode='42501';end if;
 -- Recheck canonical write authority after any wait on the Artifact lock.
 perform public.require_development_object_write(a.project_id,a.workspace_id);
 select * into source from public.artifact_versions where id=a.current_version_id for share;
 if source.id is null or source.artifact_id<>a.id or source.status<>'CURRENT'
  or source.approved_by is null or source.approved_at is null
 then raise exception 'Invalid current Version' using errcode='22023';end if;
 select coalesce(max(version_number)::bigint,0)+1 into next_number from public.artifact_versions where artifact_id=a.id;
 if next_number>2147483647 then raise exception 'Version number capacity exhausted' using errcode='22023';end if;
 stamp:=clock_timestamp();
 insert into public.artifact_versions(artifact_id,version_number,version_label,content_snapshot,change_summary,status,created_by,created_at,previous_version_id,approved_by,approved_at,approval_note)
 values(a.id,next_number::integer,null,source.content_snapshot,null,'DRAFT',actor,stamp,source.id,null,null,null)
 returning * into draft;
 insert into public.audit_events(actor_user_id,event_type,entity_type,entity_id,scope_type,scope_id,metadata,created_at)
 values(actor,'ARTIFACT_REOPENED','artifact',a.id,'artifact',a.id,'{}',stamp);
 return jsonb_build_object('version',to_jsonb(draft),'sourceVersionId',source.id,'currentVersionId',a.current_version_id);
end $$;
revoke all on function public.reopen_approved_artifact(uuid) from public,anon,authenticated,service_role;
grant execute on function public.reopen_approved_artifact(uuid) to authenticated;
comment on function public.reopen_approved_artifact(uuid) is 'Creates a caller-authorized Draft from the locked exact CURRENT approved Version. Preserves source, Artifact pointer, links, Objects, review history and Activity; appends minimal ARTIFACT_REOPENED audit.';

commit;
