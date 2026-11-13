begin;
create table public.patent_search_logs(
 id uuid primary key default gen_random_uuid(),
 project_id uuid not null,
 workspace_id uuid not null references public.workspaces(id) on delete restrict on update restrict,
 activity_instance_id uuid not null references public.activity_instances(id) on delete restrict on update restrict,
 database_name public.patent_source_database not null,
 query_text text not null check(query_text ~ '[^[:space:]]'),
 search_method text not null check(search_method ~ '[^[:space:]]'),
 reason text not null check(reason ~ '[^[:space:]]'),
 searched_at timestamptz not null default statement_timestamp(),
 searched_by uuid not null default public.current_platform_user_id() references public.users(id) on delete restrict on update restrict,
 results_reviewed_count integer check(results_reviewed_count>=0),
 relevant_results_count integer check(relevant_results_count>=0),
 terms_learned text[] not null default '{}',classifications_learned text[] not null default '{}',notes text,
 check(results_reviewed_count is null or relevant_results_count is null or relevant_results_count<=results_reviewed_count),
 check(array_position(terms_learned,null) is null and array_position(classifications_learned,null) is null),
 foreign key(project_id,workspace_id) references public.development_projects(id,primary_workspace_id) on delete restrict on update restrict
);
create index patent_search_logs_project on public.patent_search_logs(project_id);
create index patent_search_logs_workspace on public.patent_search_logs(workspace_id);
create index patent_search_logs_activity_time on public.patent_search_logs(activity_instance_id,searched_at,id);
create function private.preserve_patent_search_log() returns trigger language plpgsql set search_path='' as $$
begin
 if tg_op<>'INSERT' then raise exception 'Search history is append-only' using errcode='55000';end if;
 if public.current_platform_user_id() is null or new.searched_by is distinct from public.current_platform_user_id() then raise exception 'Resource unavailable' using errcode='42501';end if;
 perform 1 from public.activity_instances where id=new.activity_instance_id and project_id=new.project_id and workspace_id=new.workspace_id for share;
 if not found then raise exception 'Incompatible search scope' using errcode='23514';end if;
 new.searched_at:=statement_timestamp();return new;
end$$;
revoke all on function private.preserve_patent_search_log() from public,anon,authenticated,service_role;
create trigger patent_search_logs_history before insert or update or delete on public.patent_search_logs for each row execute function private.preserve_patent_search_log();
alter table public.patent_search_logs enable row level security;
revoke all on public.patent_search_logs from public,anon,authenticated,service_role;
grant select on public.patent_search_logs to authenticated;
create policy patent_search_logs_read on public.patent_search_logs for select to authenticated using(public.can_read_development_project(project_id) and public.can_read_activity_instance(activity_instance_id));
create function public.create_patent_search_log(input jsonb) returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare actor uuid:=public.current_platform_user_id();a public.activity_instances;r public.patent_search_logs;k text;
 required text[]:=array['projectId','workspaceId','activityInstanceId','databaseName','queryText','searchMethod','reason'];
 allowed text[]:=array['projectId','workspaceId','activityInstanceId','databaseName','queryText','searchMethod','reason','resultsReviewedCount','relevantResultsCount','termsLearned','classificationsLearned','notes'];
begin
 if actor is null then
  if auth.uid() is null then raise exception 'Authentication required' using errcode='28000';end if;
  raise exception 'Resource unavailable' using errcode='42501';end if;
 if input is null or jsonb_typeof(input)<>'object' then raise exception 'Invalid search input' using errcode='22023';end if;
 if exists(select 1 from jsonb_object_keys(input) x where not(x=any(allowed))) then raise exception 'Invalid search input' using errcode='22023';end if;
 foreach k in array required loop
  if jsonb_typeof(input->k) is distinct from 'string' or (input->>k)!~'[^[:space:]]' then raise exception 'Invalid search input' using errcode='22023';end if;
 end loop;
 foreach k in array array['resultsReviewedCount','relevantResultsCount'] loop
  if input?k and (jsonb_typeof(input->k)<>'number' or (input->>k)!~'^[0-9]+$' or (input->>k)::numeric>2147483647) then raise exception 'Invalid search count' using errcode='22023';end if;
 end loop;
 if input?'notes' and jsonb_typeof(input->'notes') not in ('string','null') then raise exception 'Invalid search notes' using errcode='22023';end if;
 foreach k in array array['termsLearned','classificationsLearned'] loop
  if input?k then
   if jsonb_typeof(input->k)<>'array' then raise exception 'Invalid learned terms' using errcode='22023';end if;
   if exists(select 1 from jsonb_array_elements(input->k) v where jsonb_typeof(v)<>'string') then raise exception 'Invalid learned terms' using errcode='22023';end if;
  end if;
 end loop;
 if (input->>'relevantResultsCount')::integer>(input->>'resultsReviewedCount')::integer then raise exception 'Invalid search count' using errcode='22023';end if;
 a:=public.lock_activity_artifact_contribution((input->>'activityInstanceId')::uuid);
 if a.project_id is distinct from (input->>'projectId')::uuid or a.workspace_id is distinct from (input->>'workspaceId')::uuid then raise exception 'Resource unavailable' using errcode='42501';end if;
 insert into public.patent_search_logs(project_id,workspace_id,activity_instance_id,database_name,query_text,search_method,reason,searched_by,results_reviewed_count,relevant_results_count,terms_learned,classifications_learned,notes)
 values(a.project_id,a.workspace_id,a.id,(input->>'databaseName')::public.patent_source_database,input->>'queryText',input->>'searchMethod',input->>'reason',actor,(input->>'resultsReviewedCount')::integer,(input->>'relevantResultsCount')::integer,array(select jsonb_array_elements_text(input->'termsLearned')),array(select jsonb_array_elements_text(input->'classificationsLearned')),input->>'notes') returning * into r;
 return to_jsonb(r);
end$$;
revoke all on function public.create_patent_search_log(jsonb) from public,anon,authenticated,service_role;
grant execute on function public.create_patent_search_log(jsonb) to authenticated;
comment on table public.patent_search_logs is 'M12.13 append-only human search history. Current Activity and Project privacy; no provider search, Evidence linking, AI or legal conclusions.';
commit;
