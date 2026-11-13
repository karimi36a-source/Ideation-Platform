-- M13.20: execute source queries as the authenticated recipient, never table owner.
create function pg_temp.query_isolation_empty(sql0 text) returns void language plpgsql as $$
declare n bigint;begin
 begin execute 'select count(*) from ('||sql0||') isolated' into n;
  assert n=0,'Shared recipient source query leaked: '||sql0;
 exception when insufficient_privilege then null;end;
end$$;
create function pg_temp.map_query_isolation() returns void language plpgsql as $$
declare w uuid:=(select (payload->>'primary_workspace_id')::uuid from logged_projects where label='Team');
 p uuid:=(select (payload->>'id')::uuid from logged_projects where label='Team');t text;q text;
begin
 foreach t in array array['artifacts','development_objects','files','evidence','patent_records','patent_search_logs','scamper_entries','activity_instances'] loop
  -- Collection, guessed scope, title/content search and pagination cannot inherit Share authority.
  q:=format('select id from public.%I where workspace_id=%L and project_id=%L order by id limit 10 offset 0',t,w,p);
  perform pg_temp.query_isolation_empty(q);
  perform pg_temp.query_isolation_empty(format('select id from public.%I x where workspace_id=%L and to_jsonb(x)::text ilike %L order by id limit 1 offset 1',t,w,'%'));
 end loop;
 perform pg_temp.query_isolation_empty(format('select id from public.artifacts where id=%L',pg_temp.shared_id('Sibling')));
 perform pg_temp.query_isolation_empty(format('select id from public.artifact_versions where artifact_id=%L order by version_number',pg_temp.map_share_id('Artifact')));
 perform pg_temp.query_isolation_empty(format('select id from public.artifact_versions where id=%L',pg_temp.map_share_id('V1')));
 perform pg_temp.query_isolation_empty(format('select id from public.development_objects where id=%L',pg_temp.research_source('Gap')));
 perform pg_temp.query_isolation_empty(format('select id from public.files where id=%L',pg_temp.map_share_id('File')));
 perform pg_temp.query_isolation_empty(format('select v.id from public.artifacts a join public.artifact_versions v on v.artifact_id=a.id where a.workspace_id=%L',w));
 perform pg_temp.query_isolation_empty(format('select id from public.artifact_object_links where artifact_id=%L',pg_temp.map_share_id('Artifact')));
 perform pg_temp.query_isolation_empty(format('select n.id from public.mind_map_nodes n join public.mind_maps m on m.id=n.mind_map_id join public.artifacts a on a.id=m.artifact_id where a.workspace_id=%L',w));
 perform pg_temp.query_isolation_empty(format('select l.id from public.file_links l join public.files f on f.id=l.file_id where f.workspace_id=%L',w));
 perform pg_temp.query_isolation_empty(format('select l.id from public.evidence_links l join public.evidence e on e.id=l.evidence_id where e.workspace_id=%L',w));
 perform pg_temp.query_isolation_empty(format('select id from public.development_object_relationships where project_id=%L',p));
 perform pg_temp.query_isolation_empty(format('select l.id from public.activity_research_links l join public.activity_instances a on a.id=l.activity_instance_id where a.workspace_id=%L',w));
 perform pg_temp.query_isolation_empty(format('select id from public.chat_channels where workspace_id=%L',w));
 perform pg_temp.query_isolation_empty(format('select m.id from public.chat_messages m join public.chat_channels c on c.id=m.chat_channel_id where c.workspace_id=%L',w));
 perform pg_temp.query_isolation_empty(format('select id from public.workspaces where id=%L',w));
 perform pg_temp.query_isolation_empty(format('select id from public.development_projects where id=%L',p));
 assert not public.can_read_development_project(p);
 assert public.get_team_workspace_access(w) is null;
 assert not public.team_workspace_has_chat_access(w);
 assert not public.authorize_shared_file_access(pg_temp.map_share_id('File'));
end$$;
-- Positive controls prove populated source collections, not an empty fixture.
reset role;
do $$declare w uuid:=(select (payload->>'primary_workspace_id')::uuid from logged_projects where label='Team');begin
 assert exists(select 1 from public.artifacts where workspace_id=w);
 assert exists(select 1 from public.files where id=pg_temp.map_share_id('File'));
 assert exists(select 1 from public.artifact_versions where id=pg_temp.map_share_id('V1'));
 assert exists(select 1 from public.development_objects where id=pg_temp.research_source('Gap'));
end$$;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006006',true);
select pg_temp.map_query_isolation();
do $$begin
 perform pg_temp.query_isolation_empty(format('select id from public.team_memberships where team_id=%L',(select (payload->>'teamId')::uuid from acceptance_teams where label='A')));
 perform pg_temp.query_isolation_empty(format('select m.id from public.chat_memberships m join public.chat_channels c on c.id=m.chat_channel_id where c.workspace_id=%L',(select payload->>'primary_workspace_id' from logged_projects where label='Team')));
end$$;
do $$declare r jsonb;begin
 r:=public.resolve_shared_entity_access(jsonb_build_object('shareId',pg_temp.map_share_id('View')));
 assert (r->>'allowed')::boolean and not (r->>'canComment')::boolean;
 assert r->>'sourceVersionId'=pg_temp.map_share_id('V2')::text;
 r:=public.resolve_shared_entity_access(jsonb_build_object('shareId',pg_temp.map_share_id('Comment')));
 assert (r->>'allowed')::boolean and (r->>'canComment')::boolean and not (r->>'canEdit')::boolean and not (r->>'canReshare')::boolean;
end$$;
reset role;
