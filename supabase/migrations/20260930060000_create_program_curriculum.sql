begin;
create type public.program_type as enum ('workshop','professional_course','advanced_course');
create type public.program_status as enum ('active','inactive','archived');
create type public.curriculum_status as enum ('draft','approved','retired');
create table public.programs (
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.organizations(id) on delete restrict,
 name text not null check(length(btrim(name)) between 1 and 200),
 code text not null check(code ~ '^[A-Z0-9]+(_[A-Z0-9]+)*$'),
 description text not null default '', program_type public.program_type not null,
 status public.program_status not null default 'active', current_curriculum_version_id uuid,
 -- Internal constant makes same-program + approved-pointer integrity declarative.
 current_curriculum_required_status public.curriculum_status generated always as ('approved'::public.curriculum_status) stored,
 created_at timestamptz not null default now(),updated_at timestamptz not null default now(),
 unique(organization_id,code)
);
create table public.curriculum_versions (
 id uuid primary key default gen_random_uuid(),
 program_id uuid not null references public.programs(id) on delete restrict,
 version_label text not null check(length(btrim(version_label)) between 1 and 100),
 status public.curriculum_status not null default 'draft',
 effective_from timestamptz,effective_to timestamptz, notes text not null default '',
 created_at timestamptz not null default now(),updated_at timestamptz not null default now(),
 unique(program_id,version_label),unique(id,program_id,status),
 check(effective_to is null or effective_from is null or effective_to>effective_from)
);
alter table public.programs add constraint programs_current_curriculum_fkey
 foreign key(current_curriculum_version_id,id,current_curriculum_required_status)
 references public.curriculum_versions(id,program_id,status) on delete restrict on update restrict;
alter table public.role_assignments add constraint role_assignments_program_id_fkey
 foreign key(program_id) references public.programs(id) on delete restrict;
create function public.protect_program_history() returns trigger language plpgsql set search_path='' as $$
begin
 if tg_op='DELETE' then raise exception 'Archive programs instead' using errcode='23514'; end if;
 if new.id is distinct from old.id or new.organization_id is distinct from old.organization_id or new.code is distinct from old.code or new.created_at is distinct from old.created_at then
  raise exception 'Program identity is immutable' using errcode='23514'; end if;
 new.updated_at:=pg_catalog.clock_timestamp();return new;
end $$;
create trigger programs_history before update or delete on public.programs for each row execute function public.protect_program_history();
create function public.protect_curriculum_history() returns trigger language plpgsql set search_path='' as $$
begin
 if tg_op='DELETE' then raise exception 'Retire curriculum instead' using errcode='23514'; end if;
 if new.id is distinct from old.id or new.program_id is distinct from old.program_id or new.created_at is distinct from old.created_at then
  raise exception 'Curriculum identity is immutable' using errcode='23514'; end if;
 if old.status='retired' or (old.status='approved' and (
  new.status not in ('approved','retired') or new.version_label is distinct from old.version_label
  or new.effective_from is distinct from old.effective_from or new.effective_to is distinct from old.effective_to or new.notes is distinct from old.notes
 )) then raise exception 'Approved curriculum definition is immutable' using errcode='23514'; end if;
 new.updated_at:=pg_catalog.clock_timestamp();return new;
end $$;
create trigger curriculum_history before update or delete on public.curriculum_versions for each row execute function public.protect_curriculum_history();
revoke all on function public.protect_program_history(),public.protect_curriculum_history() from public,anon,authenticated,service_role;
alter table public.programs enable row level security;
alter table public.curriculum_versions enable row level security;
revoke all on public.programs,public.curriculum_versions from public,anon,authenticated,service_role;
grant select on public.programs,public.curriculum_versions to authenticated;
create policy programs_admin_read on public.programs for select to authenticated using(public.has_active_role_in_organization('ADMIN',organization_id));
create policy curriculum_admin_read on public.curriculum_versions for select to authenticated using(exists(
 select 1 from public.programs p where p.id=program_id and public.has_active_role_in_organization('ADMIN',p.organization_id)
));
-- Explicit command only; no generic table writes or caller identity argument.
create function public.manage_program(target_organization uuid,target_program uuid,program_name text,program_code text,program_description text,kind public.program_type,lifecycle public.program_status)
returns jsonb language plpgsql security definer set search_path='' as $$
declare result public.programs;
begin
 if not public.has_active_role_in_organization('ADMIN',target_organization) then raise exception 'Access denied' using errcode='42501'; end if;
 if target_program is null then
  insert into public.programs(organization_id,name,code,description,program_type,status) values(target_organization,program_name,program_code,program_description,kind,lifecycle) returning * into result;
 else
  update public.programs set name=program_name,description=program_description,program_type=kind,status=lifecycle
  where id=target_program and organization_id=target_organization and code=program_code returning * into result;
  if not found then raise exception 'Access denied' using errcode='42501'; end if;
 end if; return pg_catalog.to_jsonb(result);
end $$;
create function public.manage_curriculum(target_program uuid,target_version uuid,label text,starts_at timestamptz,ends_at timestamptz,version_notes text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare result public.curriculum_versions; org uuid;
begin
 select organization_id into org from public.programs where id=target_program;
 if org is null or not public.has_active_role_in_organization('ADMIN',org) then raise exception 'Access denied' using errcode='42501'; end if;
 if target_version is null then
  insert into public.curriculum_versions(program_id,version_label,effective_from,effective_to,notes) values(target_program,label,starts_at,ends_at,version_notes) returning * into result;
 else
  update public.curriculum_versions set version_label=label,effective_from=starts_at,effective_to=ends_at,notes=version_notes where id=target_version and program_id=target_program and status='draft' returning * into result;
  if not found then raise exception 'Access denied' using errcode='42501'; end if;
 end if;return pg_catalog.to_jsonb(result);
end $$;
create function public.transition_curriculum(target_version uuid,next_status public.curriculum_status)
returns jsonb language plpgsql security definer set search_path='' as $$
declare result public.curriculum_versions; org uuid;
begin
 select p.organization_id into org from public.programs p join public.curriculum_versions v on v.program_id=p.id where v.id=target_version;
 if org is null or not public.has_active_role_in_organization('ADMIN',org) then raise exception 'Access denied' using errcode='42501'; end if;
 update public.curriculum_versions set status=next_status where id=target_version and ((status='draft' and next_status='approved') or (status='approved' and next_status='retired')) returning * into result;
 if not found then raise exception 'Invalid curriculum transition' using errcode='22023'; end if;return pg_catalog.to_jsonb(result);
end $$;
create function public.set_current_curriculum(target_program uuid,target_version uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare result public.programs; org uuid;
begin
 select organization_id into org from public.programs where id=target_program;
 if org is null or not public.has_active_role_in_organization('ADMIN',org) then raise exception 'Access denied' using errcode='42501'; end if;
 update public.programs set current_curriculum_version_id=target_version where id=target_program returning * into result;
 return pg_catalog.to_jsonb(result);
end $$;
revoke all on function public.manage_program(uuid,uuid,text,text,text,public.program_type,public.program_status),public.manage_curriculum(uuid,uuid,text,timestamptz,timestamptz,text),public.transition_curriculum(uuid,public.curriculum_status),public.set_current_curriculum(uuid,uuid) from public,anon,authenticated,service_role;
grant execute on function public.manage_program(uuid,uuid,text,text,text,public.program_type,public.program_status),public.manage_curriculum(uuid,uuid,text,timestamptz,timestamptz,text),public.transition_curriculum(uuid,public.curriculum_status),public.set_current_curriculum(uuid,uuid) to authenticated;
create function public.seed_professional_curriculum() returns void language plpgsql security invoker set search_path='' as $$
declare p uuid; fresh boolean;
begin
 insert into public.programs(id,organization_id,name,code,description,program_type,status) values
 ('00000000-0000-4000-8000-000000000601','00000000-0000-4000-8000-000000000501','Professional Course','PROFESSIONAL_COURSE','','professional_course','active') on conflict(organization_id,code) do nothing returning id into p;
 fresh:=found;
 select id into p from public.programs where organization_id='00000000-0000-4000-8000-000000000501' and code='PROFESSIONAL_COURSE';
 insert into public.curriculum_versions(id,program_id,version_label,status) values('00000000-0000-4000-8000-000000000602',p,'2026 v1','approved') on conflict(program_id,version_label) do nothing;
 -- Initialize only once; retries must never reset a changed/cleared current pointer.
 if fresh then
  update public.programs set current_curriculum_version_id=(select id from public.curriculum_versions where program_id=p and version_label='2026 v1' and status='approved') where id=p and current_curriculum_version_id is null;
 end if;
end $$;
revoke all on function public.seed_professional_curriculum() from public,anon,authenticated,service_role;
select public.seed_professional_curriculum();
commit;

