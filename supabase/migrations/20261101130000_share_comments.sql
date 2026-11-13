begin;
-- M8 feedback requires a formal Submission and reviewer. This minimal context
-- attaches discussion to one frozen Share without creating review authority.
create table public.share_comments(
 id uuid primary key default gen_random_uuid(),
 share_id uuid not null references public.shares(id) on delete restrict,
 target_entity_type public.share_entity_type not null,
 target_entity_id uuid not null,
 target_version_id uuid references public.artifact_versions(id) on delete restrict,
 author_user_id uuid not null references public.users(id) on delete restrict,
 content text not null check(length(content)>0 and content=regexp_replace(content,'^\s+|\s+$','','g')),
 created_at timestamptz not null default clock_timestamp(),
 check((target_entity_type='ARTIFACT')=(target_version_id is not null))
);
create index share_comments_thread on public.share_comments(share_id,created_at,id);
create function private.lock_comment_share(target_share uuid) returns void
language plpgsql security definer set search_path='' as $$
declare actor uuid:=public.current_platform_user_id();s public.shares;w public.workspaces;dw public.workspaces;r jsonb;begin
 r:=public.resolve_shared_entity_access(jsonb_build_object('shareId',target_share));
 if r->>'canComment' is distinct from 'true' then raise exception 'Access denied' using errcode='42501';end if;
 select * into s from public.shares where id=target_share;
 select * into w from public.workspaces where id=s.source_workspace_id;
 if s.destination_type='TEAM' then select x.* into dw from public.teams t join public.workspaces x on x.id=t.workspace_id where t.id=s.destination_id;end if;
 -- Match canonical scope-first ordering. Membership removal, Share revocation,
 -- role expiry/deactivation and account changes cannot race a committed write.
 perform 1 from public.cohorts where id in(w.cohort_id,dw.cohort_id) order by id for share;
 perform 1 from public.teams where id in(w.team_id,dw.team_id) order by id for share;
 perform 1 from public.workspaces where id in(w.id,dw.id) order by id for share;
 perform 1 from public.users where id=actor for share;
 perform 1 from public.role_assignments where user_id=actor order by id for share;
 perform 1 from public.enrollments where user_id=actor order by id for share;
 perform 1 from public.team_memberships where user_id=actor and team_id in(w.team_id,dw.team_id) order by id for share;
 perform 1 from public.shares where id=target_share for share;
 r:=public.resolve_shared_entity_access(jsonb_build_object('shareId',target_share));
 if actor is distinct from public.current_platform_user_id() or r->>'canComment' is distinct from 'true' then raise exception 'Access denied' using errcode='42501';end if;
 if s.destination_type='MASTER' and not exists(select 1 from public.role_assignments ra where ra.id=s.destination_id and ra.starts_at<=clock_timestamp() and (ra.ends_at is null or ra.ends_at>clock_timestamp())) then raise exception 'Access denied' using errcode='42501';end if;
end$$;
create function private.validate_share_comment() returns trigger language plpgsql security definer set search_path='' as $$
declare s public.shares;v uuid;actor uuid:=public.current_platform_user_id();begin
 if tg_op<>'INSERT' then raise exception 'Comment history is immutable' using errcode='23514';end if;
 perform private.lock_comment_share(new.share_id);
 select * into s from public.shares where id=new.share_id;
 select source_version_id into v from public.share_snapshots where share_id=s.id;
 if (new.author_user_id is not null and new.author_user_id is distinct from actor)
 or (new.target_entity_type is not null and new.target_entity_type is distinct from s.shared_entity_type)
 or (new.target_entity_id is not null and new.target_entity_id is distinct from s.shared_entity_id)
 or (new.target_version_id is not null and new.target_version_id is distinct from v)
 then raise exception 'Invalid comment context' using errcode='23514';end if;
 new.author_user_id:=actor;new.target_entity_type:=s.shared_entity_type;new.target_entity_id:=s.shared_entity_id;new.target_version_id:=v;new.created_at:=clock_timestamp();return new;
end$$;
create trigger share_comments_preserve before insert or update or delete on public.share_comments for each row execute function private.validate_share_comment();
create function public.can_read_share_comments(target_share uuid) returns boolean
language plpgsql stable security definer set search_path='' as $$
declare s public.shares;wid uuid;pid uuid;activity uuid;r jsonb;begin
 if public.current_platform_user_id() is null then return false;end if;
 select * into s from public.shares where id=target_share;
 if not found or s.permission_level<>'COMMENT' or s.share_mode<>'SNAPSHOT' then return false;end if;
 r:=public.resolve_shared_entity_access(jsonb_build_object('shareId',target_share));
 if r->>'canComment'='true' then return true;end if;
 -- Independent canonical source authority survives recipient access revocation.
 case s.shared_entity_type
 when 'ARTIFACT' then select workspace_id,project_id into wid,pid from public.artifacts where id=s.shared_entity_id;
 when 'DEVELOPMENT_OBJECT' then select workspace_id,project_id into wid,pid from public.development_objects where id=s.shared_entity_id;
 when 'FILE' then select workspace_id,project_id into wid,pid from public.files where id=s.shared_entity_id;
 when 'EVIDENCE' then select workspace_id,project_id into wid,pid from public.evidence where id=s.shared_entity_id;
 when 'PATENT_RECORD' then select workspace_id,project_id into wid,pid from public.patent_records where id=s.shared_entity_id;
 when 'SCAMPER_ENTRY' then select workspace_id,project_id,activity_instance_id into wid,pid,activity from public.scamper_entries where id=s.shared_entity_id;
 end case;
 -- Preserve existing narrow M8 source-read exceptions without inferring any
 -- formal review authority from the Share or exposing sibling Versions.
 if wid=s.source_workspace_id and s.shared_entity_type='ARTIFACT' and public.can_review_artifact_version((select source_version_id from public.share_snapshots where share_id=s.id)) then return true;end if;
 if wid=s.source_workspace_id and s.shared_entity_type='DEVELOPMENT_OBJECT' and public.can_review_linked_object(s.shared_entity_id) then return true;end if;
 return coalesce(wid=s.source_workspace_id and public.can_read_file_scope(wid,pid)
 and (activity is null or public.can_read_activity_instance(activity)),false);
end$$;
alter table public.share_comments enable row level security;
revoke all on public.share_comments from public,anon,authenticated,service_role;
grant select on public.share_comments to authenticated;
create policy share_comments_read on public.share_comments for select to authenticated using(public.can_read_share_comments(share_id));
create policy share_comments_insert_denied on public.share_comments as restrictive for insert to authenticated with check(false);
create policy share_comments_update_denied on public.share_comments as restrictive for update to authenticated using(false) with check(false);
create policy share_comments_delete_denied on public.share_comments as restrictive for delete to authenticated using(false);
create function public.add_share_comment(input jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare result public.share_comments;sid uuid;begin
 if public.current_platform_user_id() is null then raise exception 'Access denied' using errcode='42501';end if;
 if jsonb_typeof(input) is distinct from 'object' or not(input?&array['shareId','content'])
 or (select count(*) from jsonb_object_keys(input))<>2
 or jsonb_typeof(input->'shareId') is distinct from 'string' or jsonb_typeof(input->'content') is distinct from 'string'
 or input->>'shareId' !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
 or length(regexp_replace(input->>'content','^\s+|\s+$','','g'))=0 then raise exception 'Invalid comment input' using errcode='22023';end if;
 sid:=(input->>'shareId')::uuid;
 insert into public.share_comments(share_id,content) values(sid,regexp_replace(input->>'content','^\s+|\s+$','','g')) returning * into result;
 return to_jsonb(result);
end$$;
create function public.list_share_comments(input jsonb) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare sid uuid;begin
 if jsonb_typeof(input) is distinct from 'object' or (select count(*) from jsonb_object_keys(input))<>1
 or jsonb_typeof(input->'shareId') is distinct from 'string'
 or input->>'shareId' !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then raise exception 'Invalid thread input' using errcode='22023';end if;
 sid:=(input->>'shareId')::uuid;
 if not public.can_read_share_comments(sid) then raise exception 'Access denied' using errcode='42501';end if;
 return (select coalesce(jsonb_agg(to_jsonb(c) order by c.created_at,c.id),'[]'::jsonb) from public.share_comments c where share_id=sid);
end$$;
revoke all on function private.lock_comment_share(uuid),private.validate_share_comment() from public,anon,authenticated,service_role;
revoke all on function public.can_read_share_comments(uuid),public.add_share_comment(jsonb),public.list_share_comments(jsonb) from public,anon,authenticated,service_role;
grant execute on function public.can_read_share_comments(uuid),public.add_share_comment(jsonb),public.list_share_comments(jsonb) to authenticated;
comment on table public.share_comments is 'M13.10 exact-Share append-only discussion; no Submission, formal review, source edit grant or lifecycle mutation. Current source readers retain historical discussion after revocation.';
commit;
