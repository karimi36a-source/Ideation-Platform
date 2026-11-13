begin;
-- Archived metadata remains subject to exactly the same current canonical scope.
alter policy files_current_scope_read on public.files using(public.can_read_file_scope(workspace_id,project_id));
create function public.archive_file(target_file uuid) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare actor uuid:=public.current_platform_user_id();f public.files;
begin
 if actor is null then raise exception 'Authentication required' using errcode='28000';end if;
 if target_file is null then raise exception 'Invalid File' using errcode='22023';end if;
 select * into f from public.files where id=target_file;
 if f.id is null or not public.can_read_file_scope(f.workspace_id,f.project_id) then raise exception 'Resource unavailable' using errcode='42501';end if;
 -- Reuse canonical mutation authorization and its scope/membership lock ordering.
 perform private.require_file_upload_scope(f.workspace_id,f.project_id);
 select * into f from public.files where id=target_file for update;
 if f.id is null or not public.can_read_file_scope(f.workspace_id,f.project_id) then raise exception 'Resource unavailable' using errcode='42501';end if;
 if f.status='archived' then return to_jsonb(f);end if;
 update public.files set status='archived',archived_at=statement_timestamp() where id=f.id returning * into f;
 return to_jsonb(f);
end$$;
revoke all on function public.archive_file(uuid) from public,anon,authenticated,service_role;
grant execute on function public.archive_file(uuid) to authenticated;
comment on function public.archive_file(uuid) is 'Logical archive only: current File read plus canonical scope mutation authority; serialized idempotent archive; no Storage deletion, link changes, restore or retention policy.';
commit;
