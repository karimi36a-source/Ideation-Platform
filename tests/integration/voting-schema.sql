-- Trusted isolated fixture prepended; all test writes roll back.
reset role;
create temporary table voting_fixture as select id as activity_id,started_by as user_id from public.activity_instances limit 1;
do $$ declare a uuid; u uuid; s uuid; t uuid; o uuid; p uuid; d uuid; begin
 select activity_id,user_id into strict a,u from voting_fixture;
 select id into strict d from public.development_objects limit 1;
 insert into public.voting_sessions(activity_instance_id,voting_type,vote_limit,created_by) values(a,'DOT_VOTE',0,u) returning id into s;
 assert (select status='DRAFT' and not anonymous and reveal_mode='LIVE' from public.voting_sessions where id=s);
 insert into public.voting_sessions(activity_instance_id,voting_type,vote_limit,created_by,status,reveal_mode,opened_at,closed_at) values(a,'FIST_TO_FIVE',3,u,'OPEN','HIDDEN_UNTIL_REVEAL',now(),now()) returning id into t;
 insert into public.voting_sessions(activity_instance_id,voting_type,vote_limit,created_by,status) values(a,'PLANNING_POKER',3,u,'CLOSED');
 begin insert into public.voting_sessions(activity_instance_id,voting_type,vote_limit,created_by) values(gen_random_uuid(),'DOT_VOTE',3,u); raise exception 'Invalid Activity accepted'; exception when foreign_key_violation then null; end;
 begin insert into public.voting_sessions(activity_instance_id,voting_type,vote_limit,created_by) values(a,'DOT_VOTE',-1,u); raise exception 'Negative limit accepted'; exception when check_violation then null; end;
 begin execute format('update public.voting_sessions set status=%L where id=%L','REVEALED',s); raise exception 'Invalid status'; exception when invalid_text_representation then null; end;
 begin execute format('update public.voting_sessions set reveal_mode=%L where id=%L','PUBLIC',s); raise exception 'Invalid reveal'; exception when invalid_text_representation then null; end;
 begin execute format('update public.voting_sessions set voting_type=%L where id=%L','CUSTOM',s); raise exception 'Invalid type'; exception when invalid_text_representation then null; end;
 insert into public.voting_options(voting_session_id,development_object_id,label,sequence) values(s,d,'Canonical object',1) returning id into o;
 insert into public.voting_options(voting_session_id,development_object_id,label,sequence) values(t,d,'Same object different session',1) returning id into p;
 begin insert into public.voting_options(voting_session_id,label,sequence) values(s,'Duplicate sequence',1); raise exception 'Duplicate sequence'; exception when unique_violation then null; end;
 begin insert into public.voting_options(voting_session_id,development_object_id,label,sequence) values(s,d,'Duplicate object',2); raise exception 'Duplicate object'; exception when unique_violation then null; end;
 begin insert into public.voting_options(voting_session_id,development_object_id,label,sequence) values(s,gen_random_uuid(),'Missing object',2); raise exception 'Missing object'; exception when foreign_key_violation then null; end;
 begin insert into public.voting_options(voting_session_id,label,sequence) values(gen_random_uuid(),'Missing session',1); raise exception 'Missing session'; exception when foreign_key_violation then null; end;
 insert into public.votes(voting_session_id,voting_option_id,user_id,value,revealed_at) values(s,o,u,1,now());
 assert (select created_at is not null and revealed_at is not null and user_id=u from public.votes where voting_session_id=s);
 begin insert into public.votes(voting_session_id,voting_option_id,user_id,value) values(s,o,u,1); raise exception 'Duplicate dot'; exception when unique_violation then null; end;
 begin insert into public.votes(voting_session_id,voting_option_id,user_id,value) values(s,p,u,1); raise exception 'Cross session option'; exception when foreign_key_violation then null; end;
 begin insert into public.votes(voting_session_id,voting_option_id,user_id,value) values(s,o,gen_random_uuid(),1); raise exception 'Missing user'; exception when foreign_key_violation then null; end;
 begin insert into public.votes(voting_session_id,voting_option_id,user_id,value) values(s,gen_random_uuid(),u,1); raise exception 'Missing option'; exception when foreign_key_violation then null; end;
 insert into public.votes(voting_session_id,voting_option_id,user_id,value) values(t,p,u,5);
 insert into public.voting_options(voting_session_id,label,sequence) values(s,'Label only',2) returning id into p;
 insert into public.votes(voting_session_id,voting_option_id,user_id,value) values(s,p,u,1);
 insert into public.votes(voting_session_id,voting_option_id,user_id,value) select s,o,id,1 from public.users where id<>u limit 1;
 assert not exists(select 1 from public.decisions);
 assert not exists(select 1 from pg_proc where proname in ('reopen_voting_session'));
 assert (select count(*)=3 from pg_class where oid in ('public.voting_sessions'::regclass,'public.voting_options'::regclass,'public.votes'::regclass) and relrowsecurity);
end $$;
set local role authenticated;
do $$ begin
 begin perform 1 from public.votes; raise exception 'Client read allowed'; exception when insufficient_privilege then null; end;
 begin delete from public.votes; raise exception 'Client delete allowed'; exception when insufficient_privilege then null; end;
 begin update public.voting_sessions set status='OPEN'; raise exception 'Client update allowed'; exception when insufficient_privilege then null; end;
 begin insert into public.voting_options(voting_session_id,label,sequence) values(gen_random_uuid(),'Spoof',1); raise exception 'Client insert allowed'; exception when insufficient_privilege then null; end;
 begin insert into public.votes(voting_session_id,voting_option_id,user_id,value) values(gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),1); raise exception 'Voter spoof allowed'; exception when insufficient_privilege then null; end;
 begin insert into public.voting_sessions(activity_instance_id,voting_type,vote_limit,created_by) values(gen_random_uuid(),'DOT_VOTE',3,gen_random_uuid()); raise exception 'Session spoof allowed'; exception when insufficient_privilege then null; end;
end $$;
set local role anon;
do $$ begin
 begin perform 1 from public.voting_sessions; raise exception 'Anonymous read allowed'; exception when insufficient_privilege then null; end;
end $$;
reset role;
-- M10.14 permits scoped Session/Option metadata; accidental grants still cannot
-- expose unrelated metadata or raw Vote rows.
grant select on public.voting_sessions,public.voting_options,public.votes to authenticated,anon;
set local role authenticated;
do $$ begin
 assert not exists(select 1 from public.voting_sessions where not public.can_read_voting_session(id));
 assert not exists(select 1 from public.voting_options where not public.can_read_voting_session(voting_session_id));
 assert not exists(select 1 from public.votes);
end $$;
set local role anon;
do $$ begin assert not exists(select 1 from public.votes); end $$;
reset role;
select 'M101_SESSIONS='||json_agg(column_name order by column_name)::text from information_schema.columns where table_schema='public' and table_name='voting_sessions';
select 'M101_OPTIONS='||json_agg(column_name order by column_name)::text from information_schema.columns where table_schema='public' and table_name='voting_options';
select 'M101_VOTES='||json_agg(column_name order by column_name)::text from information_schema.columns where table_schema='public' and table_name='votes';
select 'M10.1 voting schema PASS';
rollback;
