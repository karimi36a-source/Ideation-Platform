begin;
-- Intent metadata only: never persist signed provider capabilities.
create table public.file_upload_requests(
 id uuid primary key default gen_random_uuid(),file_id uuid not null unique default gen_random_uuid(),
 requested_by uuid not null references public.users(id) on delete restrict,
 workspace_id uuid not null references public.workspaces(id) on delete restrict,project_id uuid,
 storage_reference text generated always as ('workspaces/'||workspace_id::text||'/files/'||file_id::text) stored not null unique,
 filename text not null check(filename=btrim(filename) and filename<>'' and filename not in ('.','..') and filename !~ E'[\\\\/[:cntrl:]]' and filename !~ '[. ]$' and filename=normalize(filename,NFKC)),
 mime_type text not null check(mime_type in ('application/pdf','image/jpeg','image/png','image/webp','text/plain','text/csv','application/vnd.openxmlformats-officedocument.wordprocessingml.document','application/vnd.openxmlformats-officedocument.spreadsheetml.sheet','application/vnd.openxmlformats-officedocument.presentationml.presentation')),
 expected_size bigint not null check(expected_size between 1 and 26214400),
 created_at timestamptz not null default clock_timestamp(),expires_at timestamptz not null default clock_timestamp()+interval '2 hours',registered_at timestamptz,
 foreign key(project_id,workspace_id) references public.development_projects(id,primary_workspace_id) on delete restrict,
 check(expires_at>created_at),check(registered_at is null or registered_at>=created_at)
);
create index file_upload_request_actor on public.file_upload_requests(requested_by,workspace_id);
create function private.require_file_upload_scope(target_workspace uuid,target_project uuid) returns void
language plpgsql security definer set search_path='' as $$
declare actor uuid:=public.current_platform_user_id();w public.workspaces;
begin
 if actor is null then raise exception 'Authentication required' using errcode='28000';end if;
 if target_project is not null then
  perform public.require_development_object_write(target_project,target_workspace);
  return;
 end if;
 select * into w from public.workspaces where id=target_workspace;
 -- Match existing lock order: Cohort, Team, Workspace, profile, role/enrollment/membership.
 perform 1 from public.cohorts where id=w.cohort_id for share;
 perform 1 from public.teams where id=w.team_id for share;
 select * into w from public.workspaces where id=target_workspace for share;
 perform 1 from public.users where id=actor for share;
 perform 1 from public.role_assignments where user_id=actor order by id for share;
 perform 1 from public.enrollments where user_id=actor order by id for share;
 perform 1 from public.team_memberships where team_id=w.team_id and user_id=actor order by id for share;
 if not public.can_read_file_scope(target_workspace,target_project) then raise exception 'Resource unavailable' using errcode='42501';end if;
 if w.workspace_type='TEAM' and coalesce(public.get_team_workspace_access(w.id)::text,'') not in ('member','team_lead') then raise exception 'Resource unavailable' using errcode='42501';end if;
end$$;
revoke all on function private.require_file_upload_scope(uuid,uuid) from public,anon,authenticated,service_role;
create function public.request_file_upload(target_workspace uuid,target_project uuid,upload_filename text,upload_mime text,upload_size bigint) returns jsonb
language plpgsql security definer set search_path='' as $$
declare r public.file_upload_requests;
begin
 perform private.require_file_upload_scope(target_workspace,target_project);
 if upload_filename is null or upload_mime is null or upload_size is null then raise exception 'Invalid upload' using errcode='22023';end if;
 -- Reject invisible directional/isolate controls consistently with the public contract.
 if upload_filename ~ U&'[\202A-\202E\2066-\2069]' then raise exception 'Invalid filename' using errcode='22023';end if;
 insert into public.file_upload_requests(requested_by,workspace_id,project_id,filename,mime_type,expected_size)
 values(public.current_platform_user_id(),target_workspace,target_project,upload_filename,upload_mime,upload_size) returning * into r;
 return to_jsonb(r);
end$$;
create function public.get_file_upload_request(target_request uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare r public.file_upload_requests;
begin
 select * into r from public.file_upload_requests where id=target_request and requested_by=public.current_platform_user_id();
 if r.id is null then raise exception 'Resource unavailable' using errcode='42501';end if;
 perform private.require_file_upload_scope(r.workspace_id,r.project_id);
 if r.expires_at<=clock_timestamp() or r.registered_at is not null then raise exception 'Resource unavailable' using errcode='42501';end if;
 return to_jsonb(r);
end$$;
revoke all on function public.get_file_upload_request(uuid) from public,anon,authenticated,service_role;
grant execute on function public.get_file_upload_request(uuid) to authenticated;
create function public.register_uploaded_file(target_request uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare r public.file_upload_requests;f public.files;meta jsonb;actual_size bigint;actual_mime text;
begin
 if public.current_platform_user_id() is null then raise exception 'Authentication required' using errcode='28000';end if;
 select * into r from public.file_upload_requests where id=target_request and requested_by=public.current_platform_user_id();
 if r.id is null then raise exception 'Resource unavailable' using errcode='42501';end if;
 perform private.require_file_upload_scope(r.workspace_id,r.project_id);
 select * into r from public.file_upload_requests where id=target_request for update;
 if r.requested_by is distinct from public.current_platform_user_id() then raise exception 'Resource unavailable' using errcode='42501';end if;
 if r.registered_at is not null then
  select * into f from public.files where id=r.file_id and uploaded_by=r.requested_by and workspace_id=r.workspace_id and project_id is not distinct from r.project_id;
  if f.id is null then raise exception 'Resource unavailable' using errcode='42501';end if;
  return to_jsonb(f);
 end if;
 if r.expires_at<=clock_timestamp() then raise exception 'Upload request expired' using errcode='22023';end if;
 -- Provider-owned metadata is read-only. Clients cannot fabricate this evidence.
 select o.metadata into meta from storage.objects o join storage.buckets b on b.id=o.bucket_id
 where o.bucket_id='fici-private-files' and o.name=r.storage_reference and b.public=false for share of o,b;
 if meta is null or coalesce(meta->>'size','') !~ '^[0-9]+$' then raise exception 'Upload unavailable' using errcode='22023';end if;
 actual_size:=(meta->>'size')::bigint;actual_mime:=nullif(btrim(meta->>'mimetype'),'');
 if actual_size<>r.expected_size or actual_size not between 1 and 26214400 or (actual_mime is not null and actual_mime<>r.mime_type) then raise exception 'Upload metadata mismatch' using errcode='22023';end if;
 insert into public.files(id,uploaded_by,workspace_id,project_id,filename,mime_type,size,updated_by)
 values(r.file_id,r.requested_by,r.workspace_id,r.project_id,r.filename,r.mime_type,actual_size,r.requested_by) returning * into f;
 update public.file_upload_requests set registered_at=clock_timestamp() where id=r.id;
 return to_jsonb(f);
end$$;
revoke all on function public.request_file_upload(uuid,uuid,text,text,bigint),public.register_uploaded_file(uuid) from public,anon,authenticated,service_role;
grant execute on function public.request_file_upload(uuid,uuid,text,text,bigint),public.register_uploaded_file(uuid) to authenticated;
alter table public.file_upload_requests enable row level security;
revoke all on public.file_upload_requests from public,anon,authenticated,service_role;
-- No generic read/mutation path. Narrow RPCs recheck current identity and write scope.
comment on table public.file_upload_requests is 'M12.7 identity-bound upload intents, provider two-hour expiry, atomic consumption; no capability secrets. Failed object cleanup is deferred; test teardown is explicit.';
commit;
