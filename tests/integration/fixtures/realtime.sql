-- Test-only capture of the documented Broadcast database boundary.
-- Does NOT implement a websocket server or claim hosted delivery coverage.
create schema realtime;
grant usage on schema realtime to authenticated,anon;
create table realtime.messages(id bigint generated always as identity primary key,topic text not null,extension text not null default 'broadcast',event text,payload jsonb,private boolean not null default true);
alter table realtime.messages enable row level security;
grant select on realtime.messages to authenticated;
create function realtime.topic() returns text language sql stable as $$select current_setting('realtime.topic',true)$$;
create function realtime.send(payload jsonb,event text,topic text,private boolean default true) returns void language sql as $$
 insert into realtime.messages(payload,event,topic,private) values(payload,event,topic,private);
$$;
