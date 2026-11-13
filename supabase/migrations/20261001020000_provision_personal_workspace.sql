begin;
-- Only current active Personal metadata is readable. No broader M4.3 resolver.
grant select on public.workspaces to authenticated;
create policy workspaces_personal_owner_read on public.workspaces for select to authenticated
 using(workspace_type='PERSONAL' and status='active' and visibility='private' and owner_user_id=public.current_platform_user_id());
-- Definer is necessary for the narrow provisioning command; generic client CRUD
-- remains revoked. Identity is Auth-derived and revalidated under a profile lock.
create function public.create_personal_workspace() returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid; w public.workspaces;
begin
 actor:=auth.uid();
 if actor is null then raise exception 'Authentication required' using errcode='28000';end if;
 perform 1 from public.users where id=actor and account_status='active' for update;
 if not found or public.current_platform_user_id() is distinct from actor then raise exception 'Access denied' using errcode='42501';end if;
 select * into w from public.workspaces where workspace_type='PERSONAL' and owner_user_id=actor and status='active';
 if found then return pg_catalog.to_jsonb(w);end if;
 insert into public.workspaces(workspace_type,name,owner_user_id,status,visibility,created_by,updated_by)
 values('PERSONAL','My Workspace',actor,'active','private',actor,actor)
 on conflict(owner_user_id) where workspace_type='PERSONAL' and status='active' do nothing returning * into w;
 if not found then select * into w from public.workspaces where workspace_type='PERSONAL' and owner_user_id=actor and status='active';end if;
 if w.id is null then raise exception 'Access denied' using errcode='42501';end if;
 return pg_catalog.to_jsonb(w);
end $$;
revoke all on function public.create_personal_workspace() from public,anon,authenticated,service_role;
grant execute on function public.create_personal_workspace() to authenticated;
commit;
