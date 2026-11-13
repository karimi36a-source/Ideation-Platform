begin;
-- Admission counters only: no source content, raw IPs, permissions or commercial quotas.
create table private.file_upload_rate_limits(
 key text primary key,
 requests integer not null check(requests>0),
 reset_at timestamptz not null
);
create index file_upload_rate_limits_expiry on private.file_upload_rate_limits(reset_at);
alter table private.file_upload_rate_limits enable row level security;
revoke all on private.file_upload_rate_limits from public,anon,authenticated,service_role;

create function public.consume_file_upload_rate_limit(target_actor uuid,target_source_hash text,user_limit integer,source_limit integer,window_seconds integer)
returns jsonb language plpgsql security definer set search_path='' as $$
declare user_key text:='user:'||target_actor::text;source_key text:='source:'||target_source_hash;
 u private.file_upload_rate_limits;s private.file_upload_rate_limits;now0 timestamptz;retry0 integer:=0;
begin
 if target_actor is null or user_limit is null or source_limit is null or window_seconds is null
 or user_limit not between 1 and 1000000 or source_limit not between 1 and 1000000 or window_seconds not between 1 and 86400
 or (target_source_hash is not null and target_source_hash !~ '^[a-f0-9]{64}$') then raise exception 'Invalid upload admission' using errcode='22023';end if;
 if not exists(select 1 from public.users where id=target_actor and account_status='active') then raise exception 'Resource unavailable' using errcode='42501';end if;
 -- Consistent user -> source lock order serializes bursts and cross-account abuse.
 perform pg_advisory_xact_lock(hashtextextended('file-upload:'||user_key,0));
 if source_key is not null then perform pg_advisory_xact_lock(hashtextextended('file-upload:'||source_key,0));end if;
 now0:=clock_timestamp();
 -- Bounded expiry cleanup never waits on another request's counter rows.
 delete from private.file_upload_rate_limits where key in
  (select key from private.file_upload_rate_limits where reset_at<=now0 limit 100 for update skip locked);
 select * into u from private.file_upload_rate_limits where key=user_key;
 if source_key is not null then select * into s from private.file_upload_rate_limits where key=source_key;end if;
 if u.reset_at>now0 and u.requests>=user_limit then retry0:=ceil(extract(epoch from u.reset_at-now0))::integer;end if;
 if s.reset_at>now0 and s.requests>=source_limit then retry0:=greatest(retry0,ceil(extract(epoch from s.reset_at-now0))::integer);end if;
 if retry0>0 then return jsonb_build_object('allowed',false,'retryAfterSeconds',retry0);end if;
 insert into private.file_upload_rate_limits(key,requests,reset_at) values(user_key,1,now0+make_interval(secs=>window_seconds))
 on conflict(key) do update set requests=case when private.file_upload_rate_limits.reset_at<=now0 then 1 else private.file_upload_rate_limits.requests+1 end,
 reset_at=case when private.file_upload_rate_limits.reset_at<=now0 then excluded.reset_at else private.file_upload_rate_limits.reset_at end;
 if source_key is not null then
  insert into private.file_upload_rate_limits(key,requests,reset_at) values(source_key,1,now0+make_interval(secs=>window_seconds))
  on conflict(key) do update set requests=case when private.file_upload_rate_limits.reset_at<=now0 then 1 else private.file_upload_rate_limits.requests+1 end,
  reset_at=case when private.file_upload_rate_limits.reset_at<=now0 then excluded.reset_at else private.file_upload_rate_limits.reset_at end;
 end if;
 return jsonb_build_object('allowed',true,'retryAfterSeconds',0);
end$$;
revoke all on function public.consume_file_upload_rate_limit(uuid,text,integer,integer,integer) from public,anon,authenticated,service_role;
grant execute on function public.consume_file_upload_rate_limit(uuid,text,integer,integer,integer) to service_role;
commit;
