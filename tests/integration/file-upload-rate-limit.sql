-- Disposable identities; admission never grants Workspace/File permissions.
insert into auth.users(id,email) values
('00000000-0000-4000-8000-000000006004','upload-rate-a@example.test'),
('00000000-0000-4000-8000-000000006005','upload-rate-b@example.test');
select public.provision_user_profile(id,'active') from auth.users where email like 'upload-rate-%@example.test';
set role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',false);
do $$begin
 begin perform public.consume_file_upload_rate_limit(auth.uid(),repeat('a',64),3,10,60);raise exception 'Client forged admission';exception when insufficient_privilege then null;end;
 begin delete from private.file_upload_rate_limits;raise exception 'Client reset counters';exception when insufficient_privilege then null;end;
end$$;
reset role;
set role service_role;
do $$declare r jsonb;begin
 for n in 1..3 loop assert public.consume_file_upload_rate_limit('00000000-0000-4000-8000-000000006004',repeat('a',64),3,10,60)->>'allowed'='true';end loop;
 r:=public.consume_file_upload_rate_limit('00000000-0000-4000-8000-000000006004',repeat('a',64),3,10,60);
 assert r->>'allowed'='false' and (r->>'retryAfterSeconds')::integer between 1 and 60,'Authenticated burst not limited';
 assert public.consume_file_upload_rate_limit('00000000-0000-4000-8000-000000006004',repeat('b',64),3,10,60)->>'allowed'='false','Changing source bypassed user limit';
end$$;
reset role;
truncate private.file_upload_rate_limits;
set role service_role;
do $$begin
 for n in 1..2 loop assert public.consume_file_upload_rate_limit('00000000-0000-4000-8000-000000006004',repeat('c',64),2,3,60)->>'allowed'='true';end loop;
 assert public.consume_file_upload_rate_limit('00000000-0000-4000-8000-000000006005',repeat('c',64),2,3,60)->>'allowed'='true';
 assert public.consume_file_upload_rate_limit('00000000-0000-4000-8000-000000006005',repeat('c',64),2,3,60)->>'allowed'='false','Cross-account shared-source cap bypassed';
 assert public.consume_file_upload_rate_limit('00000000-0000-4000-8000-000000006005',repeat('d',64),2,3,60)->>'allowed'='true','Unrelated source/available user capacity blocked';
end$$;
reset role;
do $$begin
 assert (select requests=3 from private.file_upload_rate_limits where key='source:'||repeat('c',64)),'Denied attempt consumed shared-source capacity';
 assert (select count(*) from public.file_upload_requests)=0,'Admission created upload intents';
 assert not has_function_privilege('anon','public.consume_file_upload_rate_limit(uuid,text,integer,integer,integer)','EXECUTE');
 assert not has_table_privilege('service_role','private.file_upload_rate_limits','UPDATE');
end$$;
truncate private.file_upload_rate_limits;
set role service_role;
do $$declare r jsonb;begin
 assert public.consume_file_upload_rate_limit('00000000-0000-4000-8000-000000006004',null,1,10,1)->>'allowed'='true';
 r:=public.consume_file_upload_rate_limit('00000000-0000-4000-8000-000000006004',null,1,10,1);
 assert r='{"allowed":false,"retryAfterSeconds":1}'::jsonb,'Window retry timing';
 perform pg_sleep(1.1);
 assert public.consume_file_upload_rate_limit('00000000-0000-4000-8000-000000006004',null,1,10,1)='{"allowed":true,"retryAfterSeconds":0}'::jsonb,'Window failed to reset';
end$$;
reset role;
truncate private.file_upload_rate_limits;
\echo M17.17 authenticated burst/cross-account source/user-source independence/real clock reset/trusted-RPC denial PASS
