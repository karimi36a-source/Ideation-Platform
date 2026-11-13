begin;
create type public.decision_status as enum ('DRAFT','FINALIZED','SUPERSEDED','ARCHIVED');
create type public.decision_method as enum ('DOT_VOTE','DISCUSSION','CONSENSUS','OTHER');
create type public.decision_link_entity_type as enum ('VOTING_SESSION','ARTIFACT','DEVELOPMENT_OBJECT','EVIDENCE','AI_OUTPUT');
create table public.decisions (
 id uuid primary key default gen_random_uuid(),
 project_id uuid not null,
 workspace_id uuid not null references public.workspaces(id) on update restrict on delete restrict,
 activity_instance_id uuid,
 title text not null check(length(btrim(title))>0),
 question text not null check(length(btrim(question))>0),
 method public.decision_method not null,
 outcome text,reasoning text,
 status public.decision_status not null default 'DRAFT',
 decision_owner_user_id uuid not null references public.users(id) on update restrict on delete restrict,
 decided_at timestamptz,
 constraint decisions_project_workspace foreign key(project_id,workspace_id) references public.development_projects(id,primary_workspace_id) on update restrict on delete restrict,
 constraint decisions_activity_scope foreign key(activity_instance_id,project_id,workspace_id) references public.activity_instances(id,project_id,workspace_id) on update restrict on delete restrict
);
create table public.decision_options (
 id uuid primary key default gen_random_uuid(),
 decision_id uuid not null references public.decisions(id) on update restrict on delete restrict,
 label text not null check(length(btrim(label))>0),description text,
 selected boolean not null default false,
 development_object_id uuid references public.development_objects(id) on update restrict on delete restrict
);
create table public.decision_participants (
 id uuid primary key default gen_random_uuid(),
 decision_id uuid not null references public.decisions(id) on update restrict on delete restrict,
 user_id uuid not null references public.users(id) on update restrict on delete restrict,
 role text not null check(length(btrim(role))>0),position text,comment text,
 constraint decision_participants_one_human unique(decision_id,user_id)
);
create table public.decision_links (
 id uuid primary key default gen_random_uuid(),
 decision_id uuid not null references public.decisions(id) on update restrict on delete restrict,
 linked_entity_type public.decision_link_entity_type not null,
 linked_entity_id uuid not null,
 relationship_type text not null check(length(btrim(relationship_type))>0),
 constraint decision_links_supported_target check(linked_entity_type in ('VOTING_SESSION','ARTIFACT','DEVELOPMENT_OBJECT')),
 constraint decision_links_exact_unique unique(decision_id,linked_entity_type,linked_entity_id,relationship_type)
);
create index decisions_project on public.decisions(project_id);
create index decisions_workspace on public.decisions(workspace_id);
create index decisions_activity on public.decisions(activity_instance_id) where activity_instance_id is not null;
create index decisions_status on public.decisions(status);
create index decisions_owner on public.decisions(decision_owner_user_id);
create index decisions_decided on public.decisions(decided_at) where decided_at is not null;
-- Parent lookups use the uniqueness indexes on participants/links; avoid duplication.
create index decision_options_parent on public.decision_options(decision_id);
create index decision_options_object on public.decision_options(development_object_id) where development_object_id is not null;
create index decision_options_selected on public.decision_options(decision_id,selected);
create index decision_participants_user on public.decision_participants(user_id);
create index decision_links_target on public.decision_links(linked_entity_type,linked_entity_id);
-- Invoker structural guards only: no privileged RPC or business authority is added.
create function public.validate_decision_reference_scope() returns trigger language plpgsql set search_path='' as $$
declare d public.decisions;target_project uuid;target_workspace uuid;
begin
 select * into d from public.decisions where id=new.decision_id for share;
 if not found then raise exception 'Invalid Decision reference' using errcode='23503';end if;
 if tg_table_name='decision_options' then
  if new.development_object_id is null then return new;end if;
  select project_id,workspace_id into target_project,target_workspace from public.development_objects where id=new.development_object_id for share;
 elsif new.linked_entity_type='DEVELOPMENT_OBJECT' then
  select project_id,workspace_id into target_project,target_workspace from public.development_objects where id=new.linked_entity_id for share;
 elsif new.linked_entity_type='ARTIFACT' then
  select project_id,workspace_id into target_project,target_workspace from public.artifacts where id=new.linked_entity_id for share;
 elsif new.linked_entity_type='VOTING_SESSION' then
  select a.project_id,a.workspace_id into target_project,target_workspace from public.voting_sessions s join public.activity_instances a on a.id=s.activity_instance_id where s.id=new.linked_entity_id for share of s,a;
 else raise exception 'Unsupported Decision target' using errcode='23514';end if;
 if target_project is null then raise exception 'Invalid Decision target' using errcode='23503';end if;
 if (d.project_id,d.workspace_id) is distinct from (target_project,target_workspace) then raise exception 'Invalid Decision scope' using errcode='23514';end if;
 return new;
end $$;
revoke all on function public.validate_decision_reference_scope() from public,anon,authenticated,service_role;
create trigger decision_options_scope before insert or update on public.decision_options for each row execute function public.validate_decision_reference_scope();
create trigger decision_links_scope before insert or update on public.decision_links for each row execute function public.validate_decision_reference_scope();
create function public.preserve_decision_identity_history() returns trigger language plpgsql set search_path='' as $$
begin
 if tg_op='DELETE' then raise exception 'Decision history must be preserved' using errcode='23514';end if;
 if new.id<>old.id then raise exception 'Decision identity is immutable' using errcode='23514';end if;
 if tg_table_name='decisions' then
  if (new.project_id,new.workspace_id,new.activity_instance_id,new.decision_owner_user_id) is distinct from (old.project_id,old.workspace_id,old.activity_instance_id,old.decision_owner_user_id) then raise exception 'Decision scope and ownership are immutable' using errcode='23514';end if;
 else
  if new.decision_id<>old.decision_id then raise exception 'Decision parent is immutable' using errcode='23514';end if;
  if tg_table_name='decision_participants' then
   if new.user_id<>old.user_id then raise exception 'Participant identity is immutable' using errcode='23514';end if;
  end if;
  if tg_table_name='decision_links' and new is distinct from old then raise exception 'Decision link history is immutable' using errcode='23514';end if;
 end if;
 return new;
end $$;
revoke all on function public.preserve_decision_identity_history() from public,anon,authenticated,service_role;
create trigger decisions_history before update or delete on public.decisions for each row execute function public.preserve_decision_identity_history();
create trigger decision_options_history before update or delete on public.decision_options for each row execute function public.preserve_decision_identity_history();
create trigger decision_participants_history before update or delete on public.decision_participants for each row execute function public.preserve_decision_identity_history();
create trigger decision_links_history before update or delete on public.decision_links for each row execute function public.preserve_decision_identity_history();
-- Polymorphic targets cannot have ordinary FKs. Protect the reverse reference too;
-- target-row locks in validation serialize creation against deletion/retargeting.
create function public.restrict_decision_link_target_change() returns trigger language plpgsql set search_path='' as $$
declare kind public.decision_link_entity_type; p uuid;w uuid;
begin
 kind:=case tg_table_name when 'voting_sessions' then 'VOTING_SESSION' when 'artifacts' then 'ARTIFACT' else 'DEVELOPMENT_OBJECT' end;
 if tg_op='DELETE' and exists(select 1 from public.decision_links where linked_entity_type=kind and linked_entity_id=old.id) then raise exception 'Decision target is referenced' using errcode='23503';end if;
 if tg_op='UPDATE' and tg_table_name='voting_sessions' then
  select project_id,workspace_id into p,w from public.activity_instances where id=new.activity_instance_id;
  if exists(select 1 from public.decision_links l join public.decisions d on d.id=l.decision_id where l.linked_entity_type=kind and l.linked_entity_id=old.id and (new.id<>old.id or (d.project_id,d.workspace_id) is distinct from (p,w))) then raise exception 'Decision target scope is referenced' using errcode='23503';end if;
 end if;
 if tg_op='DELETE' then return old;end if;return new;
end $$;
revoke all on function public.restrict_decision_link_target_change() from public,anon,authenticated,service_role;
create trigger voting_sessions_decision_reference before delete or update on public.voting_sessions for each row execute function public.restrict_decision_link_target_change();
create trigger artifacts_decision_reference before delete on public.artifacts for each row execute function public.restrict_decision_link_target_change();
create trigger development_objects_decision_reference before delete on public.development_objects for each row execute function public.restrict_decision_link_target_change();
alter table public.decisions enable row level security;
alter table public.decision_options enable row level security;
alter table public.decision_participants enable row level security;
alter table public.decision_links enable row level security;
revoke all on public.decisions,public.decision_options,public.decision_participants,public.decision_links from public,anon,authenticated,service_role;
create policy decisions_client_deny on public.decisions as restrictive for all to authenticated using(false) with check(false);
create policy decision_options_client_deny on public.decision_options as restrictive for all to authenticated using(false) with check(false);
create policy decision_participants_client_deny on public.decision_participants as restrictive for all to authenticated using(false) with check(false);
create policy decision_links_client_deny on public.decision_links as restrictive for all to authenticated using(false) with check(false);
comment on table public.decisions is 'M10.8 durable schema only; no creation, finalization, supersession, archive operation or implicit voting authority.';
comment on column public.decision_options.selected is 'Boolean metadata default false; multiple selected Options remain structurally possible. Finalization policy belongs to M10.10.';
comment on column public.decision_participants.role is 'Nonblank contextual historical metadata only; never platform authorization.';
comment on column public.decision_links.relationship_type is 'Nonblank contextual text; M10.11 owns runtime relationship semantics.';
comment on column public.decision_links.linked_entity_type is 'EVIDENCE/AI_OUTPUT are extension enum values only; row creation remains denied until M12/M14 target storage and validation exist.';
commit;
