begin;
alter type public.project_change_entity_type add value if not exists 'AI_OUTPUT';
alter type public.project_change_type add value if not exists 'AI_OUTPUT_DISPOSITION_CHANGED';
alter table public.ai_outputs add column disposition_revision bigint not null default 0 check(disposition_revision between 0 and 9007199254740991);
create function public.set_ai_output_disposition(target_output uuid,target_disposition public.ai_output_disposition,expected_revision bigint) returns jsonb
language plpgsql security definer set search_path='' as $$
declare o public.ai_outputs; actor uuid:=public.current_platform_user_id();
begin
 if actor is null then raise exception 'Resource unavailable' using errcode='42501';end if;
 select * into o from public.ai_outputs where id=target_output;
 if not found or not public.can_read_development_project(o.project_id) or not exists(select 1 from public.development_projects p where p.id=o.project_id and p.primary_workspace_id=o.workspace_id) then raise exception 'Resource unavailable' using errcode='42501';end if;
 if target_disposition is null or target_disposition='CONVERTED_TO_PROJECT_OBJECT' or expected_revision is null or expected_revision<0 then raise exception 'Invalid disposition' using errcode='22023';end if;
 select * into o from public.ai_outputs where id=target_output for update;
 if not public.can_read_development_project(o.project_id) then raise exception 'Resource unavailable' using errcode='42501';end if;
 if o.disposition='CONVERTED_TO_PROJECT_OBJECT' then raise exception 'Conversion is reserved' using errcode='22023';end if;
 if o.disposition=target_disposition then return to_jsonb(o);end if;
 if o.disposition_revision<>expected_revision then raise exception 'Disposition conflict' using errcode='40001';end if;
 update public.ai_outputs set disposition=target_disposition,disposition_revision=disposition_revision+1 where id=o.id returning * into o;
 return to_jsonb(o);
end$$;
revoke all on function public.set_ai_output_disposition(uuid,public.ai_output_disposition,bigint) from public,anon,authenticated,service_role;
grant execute on function public.set_ai_output_disposition(uuid,public.ai_output_disposition,bigint) to authenticated;
create or replace function private.preserve_ai_output() returns trigger
language plpgsql set search_path='' as $$
declare actor uuid:=public.current_platform_user_id();
begin
 if tg_op='UPDATE' and current_user=pg_catalog.pg_get_userbyid((select proowner from pg_catalog.pg_proc where oid='public.set_ai_output_disposition(uuid,public.ai_output_disposition,bigint)'::regprocedure))
 and (to_jsonb(new)-'disposition'-'disposition_revision')=(to_jsonb(old)-'disposition'-'disposition_revision')
 and new.disposition<>old.disposition and old.disposition<>'CONVERTED_TO_PROJECT_OBJECT' and new.disposition<>'CONVERTED_TO_PROJECT_OBJECT'
 and new.disposition_revision=old.disposition_revision+1
 and actor is not null and public.can_read_development_project(old.project_id)
 then return new;end if;
 if tg_op<>'INSERT' then raise exception 'Generated AI history is immutable' using errcode='55000';end if;
 if new.disposition_revision<>0 or new.disposition<>'KEEP_FOR_REVIEW' then raise exception 'Invalid initial disposition' using errcode='23514';end if;
 if actor is null then raise exception 'Authentication required' using errcode='28000';end if;
 if new.requested_by is distinct from actor then raise exception 'Invalid requester' using errcode='42501';end if;
 perform public.require_development_object_write(new.project_id,new.workspace_id);
 if new.activity_instance_id is not null and not exists(select 1 from public.activity_instances a where a.id=new.activity_instance_id and a.project_id=new.project_id and a.workspace_id=new.workspace_id and public.can_read_activity_instance(a.id)) then
  raise exception 'Incompatible Activity scope' using errcode='23514';end if;
 if new.verification_status<>'UNVERIFIED' then raise exception 'Human verification is deferred' using errcode='23514';end if;
 -- Reject credential-bearing keys at any depth; runtime must additionally avoid
 -- placing secrets in values or in the generated prompt/response themselves.
 if exists(with recursive nodes(body) as (
  select new.metadata union all
  select child.body from nodes n cross join lateral (
   select value body from jsonb_each(case when jsonb_typeof(n.body)='object' then n.body else '{}'::jsonb end)
   union all
   select value body from jsonb_array_elements(case when jsonb_typeof(n.body)='array' then n.body else '[]'::jsonb end)
  ) child
 ) select 1 from nodes n cross join lateral jsonb_each(case when jsonb_typeof(n.body)='object' then n.body else '{}'::jsonb end) e
  where e.key ~* '^(api[_-]?key|provider[_-]?api[_-]?key|secret|password|authorization|access[_-]?token|refresh[_-]?token|service[_-]?role([_-]?key)?|private[_-]?key)$') then
  raise exception 'Credential metadata is forbidden' using errcode='23514';end if;
 new.created_at:=clock_timestamp();
 return new;
end$$;

create function private.audit_ai_disposition() returns trigger language plpgsql security definer set search_path='' as $$
begin
 insert into public.change_log(project_id,entity_type,entity_id,change_type,change_summary,reason,changed_by,related_ai_output_id,created_at)
 values(new.project_id,'AI_OUTPUT',new.id,'AI_OUTPUT_DISPOSITION_CHANGED','AI Output human disposition changed',
 jsonb_build_object('previous',old.disposition,'new',new.disposition,'revision',new.disposition_revision,'workspace_id',new.workspace_id)::text,
 public.current_platform_user_id(),new.id,clock_timestamp());
 return new;
end$$;
revoke all on function private.audit_ai_disposition() from public,anon,authenticated,service_role;
create trigger ai_output_disposition_audit after update on public.ai_outputs for each row execute function private.audit_ai_disposition();
create function private.validate_ai_disposition_change() returns trigger language plpgsql set search_path='' as $$
begin
 if new.entity_type::text='AI_OUTPUT' or new.change_type::text='AI_OUTPUT_DISPOSITION_CHANGED' then
  if new.entity_type::text<>'AI_OUTPUT' or new.change_type::text<>'AI_OUTPUT_DISPOSITION_CHANGED' or new.related_ai_output_id is distinct from new.entity_id
  or new.changed_by is distinct from public.current_platform_user_id()
  or not exists(select 1 from public.ai_outputs o where o.id=new.entity_id and o.project_id=new.project_id and o.disposition::text=new.reason::jsonb->>'new' and o.disposition_revision=(new.reason::jsonb->>'revision')::bigint and o.workspace_id=(new.reason::jsonb->>'workspace_id')::uuid)
  then raise exception 'Invalid AI disposition audit' using errcode='23514';end if;
 end if;
 return new;
end$$;
revoke all on function private.validate_ai_disposition_change() from public,anon,authenticated,service_role;
create trigger change_log_ai_disposition_guard before insert on public.change_log for each row execute function private.validate_ai_disposition_change();
commit;
