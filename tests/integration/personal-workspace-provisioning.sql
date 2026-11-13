\set ON_ERROR_STOP on
begin;
insert into auth.users(id,email) values('00000000-0000-4000-8000-000000001501','workspace-a@example.test'),('00000000-0000-4000-8000-000000001502','workspace-b@example.test'),('00000000-0000-4000-8000-000000001503','workspace-suspended@example.test');
select public.provision_user_profile('00000000-0000-4000-8000-000000001501','active');
select public.provision_user_profile('00000000-0000-4000-8000-000000001502','active');
select public.provision_user_profile('00000000-0000-4000-8000-000000001503','suspended');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000001501',true);
do $$ declare a jsonb; b jsonb; begin
 a:=public.create_personal_workspace();b:=public.create_personal_workspace();assert a=b,'retry unchanged';
 assert a->>'owner_user_id'='00000000-0000-4000-8000-000000001501' and a->>'name'='My Workspace' and a->>'status'='active' and a->>'visibility'='private','server-derived owner and defaults';
 assert (select count(*) from public.workspaces)=1,'one visible active Personal';
 begin perform public.create_personal_workspace('00000000-0000-4000-8000-000000001502'::uuid);raise exception 'owner override';exception when undefined_function then null;end;
 begin insert into public.workspaces(workspace_type,name,owner_user_id,created_by,updated_by) values('PERSONAL','Attack','00000000-0000-4000-8000-000000001502','00000000-0000-4000-8000-000000001501','00000000-0000-4000-8000-000000001501');raise exception 'direct insert';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000001502',true);
select public.create_personal_workspace();
do $$ begin assert (select count(*) from public.workspaces)=1,'B cannot read A';end $$;
reset role;
grant insert on public.workspaces to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000001501',true);
do $$ begin
 begin insert into public.workspaces(workspace_type,name,owner_user_id,created_by,updated_by) values('PERSONAL','Attack','00000000-0000-4000-8000-000000001502','00000000-0000-4000-8000-000000001501','00000000-0000-4000-8000-000000001501');raise exception 'RLS insert bypass';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000001503',true);
do $$ begin begin perform public.create_personal_workspace();raise exception 'suspended provisioning';exception when insufficient_privilege then null;end;end $$;
select set_config('request.jwt.claim.sub','',true);
do $$ begin begin perform public.create_personal_workspace();raise exception 'missing identity';exception when invalid_authorization_specification then null;end;end $$;
set local role anon;
do $$ begin begin perform public.create_personal_workspace();raise exception 'anonymous provisioning';exception when insufficient_privilege then null;end;end $$;
reset role;
rollback;
\echo Personal workspace owner binding, idempotency, isolation, active profile and direct RLS PASS
