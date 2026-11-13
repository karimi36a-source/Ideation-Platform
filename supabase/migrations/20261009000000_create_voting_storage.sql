begin;
create type public.voting_type as enum ('DOT_VOTE','FIST_TO_FIVE','PLANNING_POKER');
create type public.voting_session_status as enum ('DRAFT','OPEN','CLOSED');
create type public.voting_reveal_mode as enum ('LIVE','HIDDEN_UNTIL_REVEAL');
create table public.voting_sessions (
 id uuid primary key default gen_random_uuid(),
 activity_instance_id uuid not null references public.activity_instances(id) on delete restrict,
 voting_type public.voting_type not null,
 status public.voting_session_status not null default 'DRAFT',
 vote_limit integer not null check (vote_limit >= 0),
 anonymous boolean not null default false,
 reveal_mode public.voting_reveal_mode not null default 'LIVE',
 created_by uuid not null references public.users(id) on delete restrict,
 opened_at timestamptz,
 closed_at timestamptz
);
create table public.voting_options (
 id uuid primary key default gen_random_uuid(),
 voting_session_id uuid not null references public.voting_sessions(id) on delete restrict,
 development_object_id uuid references public.development_objects(id) on delete restrict,
 label text not null check (length(btrim(label)) > 0),
 description text,
 sequence integer not null check (sequence > 0),
 unique (voting_session_id,sequence),
 unique (voting_session_id,id)
);
create unique index voting_options_object_unique on public.voting_options(voting_session_id,development_object_id) where development_object_id is not null;
create table public.votes (
 id uuid primary key default gen_random_uuid(),
 voting_session_id uuid not null references public.voting_sessions(id) on delete restrict,
 voting_option_id uuid not null,
 user_id uuid not null references public.users(id) on delete restrict,
 value integer not null,
 created_at timestamptz not null default now(),
 revealed_at timestamptz,
 foreign key (voting_session_id,voting_option_id) references public.voting_options(voting_session_id,id) on delete restrict,
 unique (voting_session_id,voting_option_id,user_id)
);
create index voting_sessions_activity_idx on public.voting_sessions(activity_instance_id);
create index voting_sessions_status_idx on public.voting_sessions(status);
create index voting_sessions_type_idx on public.voting_sessions(voting_type);
create index voting_options_object_idx on public.voting_options(development_object_id) where development_object_id is not null;
create index votes_session_user_idx on public.votes(voting_session_id,user_id);
create index votes_option_idx on public.votes(voting_option_id);
create index votes_user_idx on public.votes(user_id);
-- Existing unique indexes cover session/option counting and ordered option lookup.
alter table public.voting_sessions enable row level security;
alter table public.voting_options enable row level security;
alter table public.votes enable row level security;
revoke all on public.voting_sessions,public.voting_options,public.votes from public,anon,authenticated;
-- No browser policies or RPCs yet. M10.14 owns authorized voting access.
comment on column public.votes.value is 'Integer method value. DOT_VOTE canonical cast must enforce value=1; future methods remain schema-compatible.';
comment on column public.voting_sessions.vote_limit is 'Maximum total dot rows per user; aggregate enforcement belongs to canonical transactional castVote.';
commit;
