reset role;
select set_config('request.jwt.claim.sub','',true);
create temporary table mm_fixture(label text,id uuid);
insert into public.mind_maps(artifact_id,artifact_version_id)
 select (payload->>'artifactId')::uuid,(payload->>'initialVersionId')::uuid from submitted_fixtures;
insert into mm_fixture select f.label,m.id from submitted_fixtures f join public.mind_maps m on m.artifact_id=(f.payload->>'artifactId')::uuid;
create temporary table mm_objects_before as select to_jsonb(o) row from public.development_objects o;
create temporary table mm_relationships_before as select to_jsonb(r) row from public.development_object_relationships r;
create function pg_temp.mm_reject(statement text,expected text) returns void language plpgsql as $$
begin
 begin execute statement;exception when others then if sqlstate=expected then return;end if;raise;end;
 raise exception 'Expected rejection % for %',expected,statement;
end $$;
insert into public.mind_map_nodes(mind_map_id,node_type,label,created_by,development_object_id)
 select m.id,t,t,'00000000-0000-4000-8000-000000006004',(select (payload->>'id')::uuid from logged_objects where label='Problem')
 from mm_fixture m cross join unnest(array['SYSTEM','SUBSYSTEM','COMPONENT','FUNCTION','PROBLEM','SOLUTION','GAP']) t;
do $$declare read_count integer; a uuid;b uuid;n uuid;n2 uuid;foreign_node uuid;foreign_version uuid;art uuid;ver uuid;e uuid;bad uuid:='00000000-0000-4000-8000-000000999999';t text;role_name text;stmt text;begin
 select id into strict a from mm_fixture where label='Personal';select id into strict b from mm_fixture where label='Sibling';
 select id into strict n from public.mind_map_nodes where mind_map_id=a and node_type='SYSTEM';
 select id into strict n2 from public.mind_map_nodes where mind_map_id=a and node_type='GAP';
 select id into strict foreign_node from public.mind_map_nodes where mind_map_id=b and node_type='SYSTEM';
 select artifact_id,artifact_version_id into art,ver from public.mind_maps where id=a;
 -- Use an unbound foreign Version so this attack isolates the composite FK,
 -- rather than colliding first with M11.15's representation uniqueness.
 insert into public.artifact_versions(artifact_id,version_number,content_snapshot,status,created_by,previous_version_id)
 select m.artifact_id,(select max(version_number)+1 from public.artifact_versions where artifact_id=m.artifact_id),'{}'::jsonb,'DRAFT',
 '00000000-0000-4000-8000-000000006004',(select id from public.artifact_versions where artifact_id=m.artifact_id order by version_number desc limit 1)
 from public.mind_maps m where m.id=b returning id into foreign_version;
 perform pg_temp.mm_reject(format('insert into public.mind_maps(artifact_id,artifact_version_id) values(%L,%L)',art,ver),'23505');
 update public.mind_maps set root_node_id=n where id=a;
 assert (select root_node_id=n from public.mind_maps where id=a);
 perform pg_temp.mm_reject(format('update public.mind_maps set root_node_id=%L where id=%L',foreign_node,a),'23503');
 perform pg_temp.mm_reject(format('insert into public.mind_maps(artifact_id,artifact_version_id) values(%L,%L)',art,foreign_version),'23503');
 perform pg_temp.mm_reject(format('update public.mind_maps set artifact_version_id=%L where id=%L',bad,a),'23514');
 perform pg_temp.mm_reject(format('update public.artifacts set artifact_type=''GAP_LIST'' where id=%L',art),'23514');
 update public.mind_map_nodes set parent_node_id=n where id=n2;
 perform pg_temp.mm_reject(format('update public.mind_map_nodes set parent_node_id=%L where id=%L',foreign_node,n2),'23503');
 perform pg_temp.mm_reject(format('update public.mind_map_nodes set parent_node_id=id where id=%L',n2),'23514');
 perform pg_temp.mm_reject(format('update public.mind_map_nodes set development_object_id=%L where id=%L',bad,n2),'23503');
 assert (select count(*) from public.mind_map_nodes where mind_map_id=a and development_object_id is not null)=7;
 insert into public.mind_map_edges(mind_map_id,source_node_id,target_node_id,edge_type) values(a,n,n2,'CROSS_CONNECTION') returning id into e;
 perform pg_temp.mm_reject(format('update public.mind_map_edges set source_node_id=%L where id=%L',foreign_node,e),'23503');
 perform pg_temp.mm_reject(format('update public.mind_map_edges set target_node_id=%L where id=%L',foreign_node,e),'23503');
 perform pg_temp.mm_reject(format('update public.mind_map_edges set target_node_id=%L where id=%L',bad,e),'23503');
 perform pg_temp.mm_reject(format('delete from public.mind_map_nodes where id=%L',n),'23503');
 perform pg_temp.mm_reject(format('update public.mind_map_nodes set node_type='' '' where id=%L',n),'23514');
 perform pg_temp.mm_reject(format('update public.mind_map_nodes set position_data=''[]'' where id=%L',n),'23514');
 perform pg_temp.mm_reject(format('update public.mind_map_edges set metadata=''null'' where id=%L',e),'23514');
 -- Exact-ID attacks use valid SQL, under real database roles. No API mock.
 foreach role_name in array array['anon','authenticated'] loop
  execute format('set local role %I',role_name);
  perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006006',true);
  foreach t in array array['mind_maps','mind_map_nodes','mind_map_edges'] loop
   if role_name='anon' then perform pg_temp.mm_reject(format('select * from public.%I',t),'42501');else execute format('select count(*) from public.%I where id=%L',t,case t when 'mind_maps' then a when 'mind_map_nodes' then n else e end) into read_count;assert read_count=0;end if;
   perform pg_temp.mm_reject(format('update public.%I set id=id where id=%L',t,case t when 'mind_maps' then a when 'mind_map_nodes' then n else e end),'42501');
   perform pg_temp.mm_reject(format('delete from public.%I where id=%L',t,case t when 'mind_maps' then a when 'mind_map_nodes' then n else e end),'42501');
   perform pg_temp.mm_reject(format('insert into public.%I default values',t),'42501');
  end loop;
  execute 'reset role';
 end loop;
 delete from public.mind_map_edges where id=e;
 delete from public.mind_map_nodes where id=n2;
 assert not exists((select row from mm_objects_before except select to_jsonb(o) from public.development_objects o) union all (select to_jsonb(o) from public.development_objects o except select row from mm_objects_before));
 assert not exists((select row from mm_relationships_before except select to_jsonb(r) from public.development_object_relationships r) union all (select to_jsonb(r) from public.development_object_relationships r except select row from mm_relationships_before));
 foreach t in array array['mind_maps','mind_map_nodes','mind_map_edges'] loop
  assert (select relrowsecurity from pg_class where oid=('public.'||t)::regclass);
  assert has_table_privilege('authenticated','public.'||t,'SELECT');
  assert not has_table_privilege('authenticated','public.'||t,'INSERT,UPDATE,DELETE');
  assert exists(select 1 from pg_policies where tablename=t and permissive='PERMISSIVE' and cmd='SELECT');
 end loop;
 assert (select count(*) from pg_indexes where tablename in ('mind_maps','mind_map_nodes','mind_map_edges') and schemaname='public')=15;
 assert exists(select 1 from pg_indexes where indexname='mind_map_one_representation_per_version' and indexdef like 'CREATE UNIQUE INDEX%');
 assert not exists(select 1 from pg_constraint where conrelid in ('public.mind_maps'::regclass,'public.mind_map_nodes'::regclass,'public.mind_map_edges'::regclass) and contype='f' and (confdeltype<>'r' or confupdtype<>'r'));
end $$;
select 'MIND_MAP_ROW='||to_jsonb(m)::text from public.mind_maps m limit 1;
select 'MIND_MAP_NODE_ROW='||to_jsonb(n)::text from public.mind_map_nodes n limit 1;
select 'MIND_MAP_EDGE_ROW='||to_jsonb(e)::text from public.mind_map_edges e limit 1;
-- Emit a real edge after the visual deletion preservation check.
insert into public.mind_map_edges(mind_map_id,source_node_id,target_node_id,edge_type)
 select mind_map_id,min(id::text)::uuid,max(id::text)::uuid,'CROSS_CONNECTION' from public.mind_map_nodes group by mind_map_id;
select 'MIND_MAP_EDGE_ROW='||to_jsonb(e)::text from public.mind_map_edges e limit 1;
select 'M11.7 map/version/root/parent/Object-reference/repeated-reference/edge/cross-map/deletion/default-deny/index/type parity PASS';
rollback;
