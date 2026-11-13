reset role;
create temporary table vr_session(label text primary key,id uuid);
grant select,insert on vr_session to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
insert into vr_session select 'live',(public.create_voting_session(id,'DOT_VOTE',3,false,'LIVE','[{"label":"A"},{"label":"B"},{"label":"C"},{"label":"D"}]')#>>'{session,id}')::uuid from vc_activities where n=1;
insert into vr_session select 'hidden',(public.create_voting_session(id,'DOT_VOTE',3,true,'HIDDEN_UNTIL_REVEAL','[{"label":"A"},{"label":"B"}]')#>>'{session,id}')::uuid from vc_activities where n=1;
select public.open_voting_session(id) from vr_session;
reset role;
create temporary table vr_options as select o.* from public.voting_options o join vr_session s on s.id=o.voting_session_id;
grant select on vr_options to authenticated;
create function pg_temp.vr_denied(command text) returns void language plpgsql as $$
begin
 begin execute command;exception when insufficient_privilege then return;end;
 raise exception 'Unexpected authorized attack: %',command;
end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$declare s uuid;o uuid;begin
 select id into s from vr_session where label='live';
 assert exists(select 1 from public.voting_sessions where id=s);
 assert (select count(*)=4 from public.voting_options where voting_session_id=s);
 for o in select id from vr_options where voting_session_id=s and sequence<=3 loop perform public.cast_vote(s,o,1);end loop;
 begin perform public.cast_vote(s,(select id from vr_options where voting_session_id=s and sequence=4),1);raise exception 'Limit bypass';exception when others then if sqlstate not in ('23514','55000','23505') then raise;end if;end;
 begin perform public.cast_vote(s,(select id from vr_options where voting_session_id=s and sequence=1),1);raise exception 'Duplicate bypass';exception when others then if sqlstate not in ('23514','55000','23505') then raise;end if;end;
 assert (public.get_voting_results(s)->>'totalVotes')::int=3;
 perform public.cast_vote((select id from vr_session where label='hidden'),(select id from vr_options where voting_session_id=(select id from vr_session where label='hidden') and sequence=1),1);
 assert public.get_voting_results((select id from vr_session where label='hidden'))->'totalVotes'='null'::jsonb;
 perform pg_temp.vr_denied('select * from public.votes');
end $$;
reset role;
create temporary table vr_history as select * from public.votes;
grant select on vr_history to authenticated;
set local role authenticated;
-- Every mutable field and all direct CRUD are denied, even for known own rows.
do $$declare tbl text;col record;s uuid;o uuid;v uuid;begin
 select id into s from vr_session where label='live';select id into o from vr_options where voting_session_id=s limit 1;select id into v from vr_history where voting_session_id=s limit 1;
 foreach tbl in array array['voting_sessions','voting_options','votes'] loop
  perform pg_temp.vr_denied(format('delete from public.%I where id=%L',tbl,case tbl when 'voting_sessions' then s when 'voting_options' then o else v end));
  for col in select column_name from information_schema.columns where table_schema='public' and table_name=tbl loop
   perform pg_temp.vr_denied(format('update public.%I set %I=%I where id=%L',tbl,col.column_name,col.column_name,case tbl when 'voting_sessions' then s when 'voting_options' then o else v end));
  end loop;
 end loop;
 perform pg_temp.vr_denied(format('insert into public.voting_sessions(activity_instance_id,voting_type,vote_limit,created_by) values(%L,''DOT_VOTE'',999,%L)',(select id from vc_activities where n=1),auth.uid()));
 perform pg_temp.vr_denied(format('insert into public.voting_options(voting_session_id,label,sequence) values(%L,''Forged'',99)',s));
 perform pg_temp.vr_denied(format('insert into public.votes(voting_session_id,voting_option_id,user_id,value) values(%L,%L,%L,1)',s,o,auth.uid()));
 perform pg_temp.vr_denied(format('insert into public.votes(voting_session_id,voting_option_id,user_id,value) values(%L,%L,%L,1)',s,o,'00000000-0000-4000-8000-000000006005'));
end $$;
-- Real contexts, known Session/Option/Vote IDs and joins cannot bypass isolation.
do $$declare u uuid;begin
 foreach u in array array['00000000-0000-4000-8000-000000006001','00000000-0000-4000-8000-000000006003','00000000-0000-4000-8000-000000006007','00000000-0000-4000-8000-000000006008']::uuid[] loop
  perform set_config('request.jwt.claim.sub',u::text,true);
  assert not exists(select 1 from public.voting_sessions where id in (select id from vr_session));
  assert not exists(select 1 from public.voting_options where id in (select id from vr_options));
  assert not exists(select 1 from public.voting_sessions s join public.voting_options o on o.voting_session_id=s.id);
  perform pg_temp.vr_denied('select * from public.votes where id in (select id from vr_history)');
  perform pg_temp.vr_denied(format('select public.get_voting_results(%L)',(select id from vr_session where label='live')));
  perform pg_temp.vr_denied(format('select public.cast_vote(%L,%L,1)',(select id from vr_session where label='live'),(select id from vr_options limit 1)));
 end loop;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
do $$begin
 assert exists(select 1 from public.voting_sessions);
 perform pg_temp.vr_denied('select * from public.votes');
end $$;
select public.close_voting_session(id) from vr_session;
select public.reveal_voting_session(id) from vr_session where label='hidden';
do $$begin
 assert (public.get_voting_results((select id from vr_session where label='hidden'))->>'totalVotes')::int=1;
 perform pg_temp.vr_denied('select * from public.votes');
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006009',true);
do $$begin assert exists(select 1 from public.voting_sessions);perform pg_temp.vr_denied('select * from public.votes');end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin
 begin perform public.cast_vote((select id from vr_session where label='live'),(select id from vr_options limit 1),1);raise exception 'Closed vote allowed';exception when object_not_in_prerequisite_state then null;end;
 perform pg_temp.vr_denied('insert into public.votes select * from vr_history');
end $$;
reset role;
-- Exercise RLS independently of grants, including accidental broad policies.
grant select,insert,update,delete on public.votes,public.voting_sessions,public.voting_options to authenticated;
create policy vr_accidental_votes on public.votes for all to authenticated using(true) with check(true);
create policy vr_accidental_sessions on public.voting_sessions for all to authenticated using(true) with check(true);
create policy vr_accidental_options on public.voting_options for all to authenticated using(true) with check(true);
set local role authenticated;
do $$begin
 assert not exists(select 1 from public.votes);
 update public.voting_sessions set vote_limit=999;assert not found;
 update public.voting_options set label='Forged';assert not found;
 delete from public.votes;assert not found;
 perform pg_temp.vr_denied('insert into public.votes select * from vr_history');
end $$;
reset role;
drop policy vr_accidental_votes on public.votes;drop policy vr_accidental_sessions on public.voting_sessions;drop policy vr_accidental_options on public.voting_options;
revoke insert,update,delete on public.voting_sessions,public.voting_options from authenticated;
revoke all on public.votes from authenticated;
-- Creator provenance is not a permanent grant; membership removal preserves votes.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006004',null);
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
do $$begin
 assert not exists(select 1 from public.voting_sessions);
 assert not exists(select 1 from public.voting_options);
 perform pg_temp.vr_denied(format('select public.get_voting_results(%L)',(select id from vr_session where label='live')));
 perform pg_temp.vr_denied(format('select public.cast_vote(%L,%L,1)',(select id from vr_session where label='live'),(select id from vr_options limit 1)));
end $$;
reset role;
do $$begin assert (select count(*) from public.votes)=(select count(*) from vr_history);end $$;
-- Schema-valid Personal context, without a Personal Voting runtime operation.
insert into vr_session select 'personal',gen_random_uuid();
insert into public.voting_sessions(id,activity_instance_id,voting_type,vote_limit,created_by)
select s.id,(b.payload#>>'{activity,id}')::uuid,'DOT_VOTE',3,'00000000-0000-4000-8000-000000006004'
from vr_session s cross join bc_activities b where s.label='personal' and b.label='Personal';
insert into public.voting_options(voting_session_id,label,sequence) select id,'Private choice',1 from vr_session where label='personal';
set local role authenticated;
do $$declare u uuid;begin
 foreach u in array array['00000000-0000-4000-8000-000000006004','00000000-0000-4000-8000-000000006005','00000000-0000-4000-8000-000000006002','00000000-0000-4000-8000-000000006001','00000000-0000-4000-8000-000000006003']::uuid[] loop
  perform set_config('request.jwt.claim.sub',u::text,true);
  assert exists(select 1 from public.voting_sessions where id=(select id from vr_session where label='personal'))=(u='00000000-0000-4000-8000-000000006004'::uuid);
  assert exists(select 1 from public.voting_options where voting_session_id=(select id from vr_session where label='personal'))=(u='00000000-0000-4000-8000-000000006004'::uuid);
 end loop;
end $$;
reset role;
delete from vr_session where label='personal';
-- The fixture Master independently holds member access. Isolate instructional
-- authority using the same read-only mentor context as the M10.7 regression.
create temporary table vr_master_memberships as select id,membership_role from public.team_memberships where user_id='00000000-0000-4000-8000-000000006002' and status='active';
update public.team_memberships set membership_role='mentor' where id in (select id from vr_master_memberships);
create temporary table vr_master_history as select id,status,starts_at,ends_at from public.role_assignments where user_id='00000000-0000-4000-8000-000000006002' and role_id=(select id from public.roles where code='MASTER');
update public.role_assignments set status='inactive' where id in (select id from vr_master_history);
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
do $$begin assert not exists(select 1 from public.voting_sessions where id in (select id from vr_session));end $$;
reset role;
update public.role_assignments r set status=h.status,starts_at=statement_timestamp()+interval '1 hour',ends_at=null from vr_master_history h where r.id=h.id;
set local role authenticated;
do $$begin assert not exists(select 1 from public.voting_sessions where id in (select id from vr_session));end $$;
reset role;
update public.role_assignments set starts_at=statement_timestamp()-interval '2 hours',ends_at=statement_timestamp()-interval '1 hour' where id in (select id from vr_master_history);
set local role authenticated;
do $$begin assert not exists(select 1 from public.voting_sessions where id in (select id from vr_session));end $$;
reset role;
update public.role_assignments r set status=h.status,starts_at=h.starts_at,ends_at=h.ends_at from vr_master_history h where r.id=h.id;
update public.team_memberships m set membership_role=h.membership_role from vr_master_memberships h where m.id=h.id;
-- Creator provenance does not retain access after Team Lead removal.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006009',null);
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006009',true);
do $$begin assert not exists(select 1 from public.voting_sessions);assert not exists(select 1 from public.voting_options);end $$;
reset role;
-- All historical identities remain; reveal only stamps the hidden rows.
do $$begin assert not exists(select 1 from vr_history h left join public.votes v using(id) where v.id is null or (v.user_id,v.created_at,v.value) is distinct from (h.user_id,h.created_at,h.value));end $$;
set local role anon;
select pg_temp.vr_denied('select * from public.voting_sessions');
select pg_temp.vr_denied('select * from public.voting_options');
select pg_temp.vr_denied('select * from public.votes');
reset role;
do $$begin
 assert not has_table_privilege('authenticated','public.votes','select');
 assert not has_table_privilege('authenticated','public.voting_sessions','insert,update,delete');
 assert (select count(*)=3 from pg_class where oid in ('public.voting_sessions'::regclass,'public.voting_options'::regclass,'public.votes'::regclass) and relrowsecurity);
 assert exists(select 1 from pg_proc where oid='public.can_read_voting_session(uuid)'::regprocedure and prosecdef and provolatile='s' and proconfig=array['search_path=""']);
 assert not has_function_privilege('anon','public.can_read_voting_session(uuid)','execute');
 assert not has_function_privilege('service_role','public.can_read_voting_session(uuid)','execute');
end $$;
select 'M10.14 Voting RLS direct-CRUD/raw-votes/reveal/exact-ID/joins/current-scope/history PASS';
rollback;
