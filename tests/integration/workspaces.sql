\set ON_ERROR_STOP on
begin;
select public.provision_user_profile('00000000-0000-4000-8000-000000000001','active');
do $$ declare uid uuid:='00000000-0000-4000-8000-000000000001';kind public.workspace_type; wid uuid; begin
 foreach kind in array enum_range(null::public.workspace_type) loop
  insert into public.workspaces(workspace_type,name,owner_user_id,created_by,updated_by) values(kind,'Schema fixture',uid,uid,uid);
 end loop;
 assert (select count(*) from public.workspaces)=5,'five valid workspace types';
 begin insert into public.workspaces(workspace_type,name,created_by,updated_by) values('INVALID','Bad',uid,uid);raise exception 'invalid type';exception when invalid_text_representation then null;end;
 begin insert into public.workspaces(workspace_type,name,created_by,updated_by) values('PERSONAL','No owner',uid,uid);raise exception 'missing owner';exception when check_violation then null;end;
 begin insert into public.workspaces(workspace_type,name,owner_user_id,created_by,updated_by) values('PERSONAL','Missing owner identity','00000000-0000-4000-8000-000000009999',uid,uid);raise exception 'invalid owner FK';exception when foreign_key_violation then null;end;
 begin insert into public.workspaces(workspace_type,name,owner_user_id,created_by,updated_by) values('PERSONAL','Duplicate',uid,uid,uid);raise exception 'duplicate active';exception when unique_violation then null;end;
 select id into wid from public.workspaces where workspace_type='PERSONAL';
 update public.workspaces set status='archived',archived_at=now() where id=wid;
 insert into public.workspaces(workspace_type,name,owner_user_id,created_by,updated_by) values('PERSONAL','New active',uid,uid,uid);
 assert (select count(*) from public.workspaces where workspace_type='PERSONAL' and status='active')=1,'one active plus archive';
 assert exists(select 1 from public.workspaces where id=wid and status='archived'),'archive retained';
 begin update public.workspaces set status='active' where id=wid;raise exception 'conflicting restore';exception when unique_violation then null;end;
 assert (select relrowsecurity from pg_class where oid='public.workspaces'::regclass),'RLS enabled';
 assert not has_table_privilege('authenticated','public.workspaces','INSERT,UPDATE,DELETE'),'no direct client mutations';
end $$;
rollback;
\echo M4.1 workspace types, owner FK, active uniqueness, archive preservation and schema-only security PASS
