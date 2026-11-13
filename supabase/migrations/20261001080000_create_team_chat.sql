begin;
create type public.chat_channel_type as enum ('TEAM','COHORT','MASTER_TEAM','ACTIVITY','OTHER');
create type public.chat_channel_status as enum ('active','archived');
create type public.chat_access_level as enum ('read','read_write');
create type public.chat_message_type as enum ('TEXT','FILE','LINK','SYSTEM');
alter table public.teams add constraint teams_id_workspace_cohort_unique unique(id,workspace_id,cohort_id);
create table public.chat_channels (
 id uuid primary key default gen_random_uuid(),
 channel_type public.chat_channel_type not null,
 workspace_id uuid not null references public.workspaces(id) on delete restrict,
 team_id uuid references public.teams(id) on delete restrict,
 cohort_id uuid references public.cohorts(id) on delete restrict,
 name text not null check(length(btrim(name)) between 1 and 200),
 status public.chat_channel_status not null default 'active',
 created_at timestamptz not null default now(),
 constraint chat_channels_team_scope check(channel_type<>'TEAM' or (team_id is not null and cohort_id is not null)),
 constraint chat_channels_team_workspace_cohort foreign key(team_id,workspace_id,cohort_id)
  references public.teams(id,workspace_id,cohort_id) on delete restrict
);
create index chat_channels_team_lookup on public.chat_channels(team_id);
create index chat_channels_workspace_lookup on public.chat_channels(workspace_id);
create table public.chat_memberships (
 id uuid primary key default gen_random_uuid(),
 chat_channel_id uuid not null references public.chat_channels(id) on delete restrict,
 user_id uuid not null references public.users(id) on delete restrict,
 access_level public.chat_access_level not null,
 joined_at timestamptz not null,
 left_at timestamptz,
 check(left_at is null or left_at>=joined_at)
);
create index chat_memberships_authorization_lookup on public.chat_memberships(chat_channel_id,user_id,left_at,joined_at);
create index chat_memberships_user_lookup on public.chat_memberships(user_id,chat_channel_id);
create table public.chat_messages (
 id uuid primary key default gen_random_uuid(),
 chat_channel_id uuid not null references public.chat_channels(id) on delete restrict,
 sender_user_id uuid not null references public.users(id) on delete restrict,
 parent_message_id uuid,
 content text not null,
 message_type public.chat_message_type not null default 'TEXT',
 created_at timestamptz not null default now(),
 edited_at timestamptz,deleted_at timestamptz,
 constraint chat_messages_id_channel_unique unique(id,chat_channel_id),
 constraint chat_messages_same_channel_parent foreign key(parent_message_id,chat_channel_id)
  references public.chat_messages(id,chat_channel_id) on delete restrict,
 constraint chat_messages_text_content check(message_type<>'TEXT' or length(btrim(content))>0)
);
create index chat_messages_channel_order on public.chat_messages(chat_channel_id,created_at,id);
create index chat_messages_parent_lookup on public.chat_messages(parent_message_id);
alter table public.chat_channels enable row level security;
alter table public.chat_memberships enable row level security;
alter table public.chat_messages enable row level security;
revoke all on public.chat_channels,public.chat_memberships,public.chat_messages from public,anon,authenticated,service_role;
comment on table public.chat_channels is 'M5.3 canonical storage only. TEAM is the current priority; other channel types have no product behavior.';
comment on column public.chat_memberships.access_level is 'Approved metadata only: read/read_write. Does not grant access until later M5 authorization.';
comment on column public.chat_messages.message_type is 'TEXT persistence implemented. FILE/LINK/SYSTEM are type support only; no file upload or attachment resolution.';
comment on column public.chat_messages.deleted_at is 'Storage placeholder only. End-user edit/delete policy and retention remain deferred.';
commit;
