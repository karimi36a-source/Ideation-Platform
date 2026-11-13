reset role;
select set_config('request.jwt.claim.sub','',true);
create temporary table af_context as select i.* from instances x join public.activity_instances i on i.id=x.id where x.label='Individual';
create temporary table af_sources as select o.* from public.development_objects o where id=(select (payload->>'id')::uuid from logged_objects where label='Individual Idea');
create temporary table af_brain as
with inserted as (insert into public.brainstorm_entries(activity_instance_id,project_id,workspace_id,created_by,content)
 select id,project_id,workspace_id,started_by,'Affinity fixture source' from af_context returning *) select * from inserted;
create temporary table af_group as
with inserted as (insert into public.affinity_groups(activity_instance_id,name,sequence,created_by)
 select id,'Fixture group',1,started_by from af_context returning *) select * from inserted;
create function pg_temp.af_reject(statement text,expected text) returns void language plpgsql as $$
begin
 begin execute statement;exception when others then if sqlstate=expected then return;end if;raise;end;
 raise exception 'Expected rejection: %',expected;
end $$;
insert into public.affinity_group_items(affinity_group_id,development_object_id,position,added_by)
 select g.id,s.id,1,g.created_by from af_group g cross join af_sources s;
insert into public.affinity_group_items(affinity_group_id,brainstorm_entry_id,position,added_by)
 select g.id,b.id,2,g.created_by from af_group g cross join af_brain b;
do $$declare g uuid;u uuid;o uuid;b uuid;bad uuid:='00000000-0000-4000-8000-000000999999';begin
 select id,created_by into strict g,u from af_group;select id into strict o from af_sources;select id into strict b from af_brain;
 assert (select sequence from public.affinity_groups where id=g)=1;
 assert (select array_agg(position order by position) from public.affinity_group_items where affinity_group_id=g)=array[1,2];
 perform pg_temp.af_reject(format('insert into public.affinity_group_items(affinity_group_id,position,added_by) values(%L,3,%L)',g,u),'23514');
 perform pg_temp.af_reject(format('insert into public.affinity_group_items(affinity_group_id,development_object_id,brainstorm_entry_id,position,added_by) values(%L,%L,%L,3,%L)',g,o,b,u),'23514');
 perform pg_temp.af_reject(format('insert into public.affinity_group_items(affinity_group_id,development_object_id,position,added_by) values(%L,%L,3,%L)',g,bad,u),'23503');
 perform pg_temp.af_reject(format('insert into public.affinity_group_items(affinity_group_id,brainstorm_entry_id,position,added_by) values(%L,%L,3,%L)',g,bad,u),'23503');
 perform pg_temp.af_reject(format('insert into public.affinity_group_items(affinity_group_id,development_object_id,position,added_by) values(%L,%L,3,%L)',bad,o,u),'23503');
 perform pg_temp.af_reject(format('insert into public.affinity_group_items(affinity_group_id,development_object_id,position,added_by) values(%L,%L,3,%L)',g,o,u),'23505');
 perform pg_temp.af_reject(format('insert into public.affinity_group_items(affinity_group_id,brainstorm_entry_id,position,added_by) values(%L,%L,3,%L)',g,b,u),'23505');
 perform pg_temp.af_reject(format('insert into public.affinity_group_items(affinity_group_id,development_object_id,position,added_by) values(%L,%L,1,%L)',g,(select (payload->>'id')::uuid from logged_objects where label='Problem'),u),'23505');
 perform pg_temp.af_reject(format('insert into public.affinity_groups(activity_instance_id,name,sequence,created_by) select id,''Duplicate'',1,%L from af_context',u),'23505');
 perform pg_temp.af_reject(format('insert into public.affinity_groups(activity_instance_id,name,sequence,created_by) values(%L,''Invalid'',1,%L)',bad,u),'23503');
 perform pg_temp.af_reject(format('insert into public.affinity_groups(activity_instance_id,name,sequence,created_by) select id,''Invalid actor'',2,%L from af_context',bad),'23503');
 perform pg_temp.af_reject(format('insert into public.affinity_groups(activity_instance_id,name,sequence,created_by) select id,''Invalid order'',0,%L from af_context',u),'23514');
 perform pg_temp.af_reject(format('delete from public.affinity_groups where id=%L',g),'23503');
 -- Same canonical source may occur in a different group.
 insert into public.affinity_groups(activity_instance_id,name,sequence,created_by) select id,'Second',2,u from af_context;
 insert into public.affinity_group_items(affinity_group_id,development_object_id,position,added_by)
 select id,o,1,u from public.affinity_groups where sequence=2 and activity_instance_id=(select id from af_context);
 assert (select to_jsonb(x) from public.development_objects x where id=o)=(select to_jsonb(x) from af_sources x);
 assert (select to_jsonb(x) from public.brainstorm_entries x where id=b)=(select to_jsonb(x) from af_brain x);
 delete from public.affinity_group_items where affinity_group_id=g;
 assert exists(select 1 from public.development_objects where id=o);
 assert exists(select 1 from public.brainstorm_entries where id=b);
end $$;
do $$declare t text;begin
 foreach t in array array['affinity_groups','affinity_group_items'] loop
  assert (select relrowsecurity from pg_class where oid=('public.'||t)::regclass);
  assert has_table_privilege('authenticated','public.'||t,'SELECT');
  assert not has_table_privilege('authenticated','public.'||t,'INSERT,UPDATE,DELETE');
  assert not has_table_privilege('anon','public.'||t,'SELECT,INSERT,UPDATE,DELETE');
  assert exists(select 1 from pg_policies where tablename=t and permissive='PERMISSIVE' and cmd='SELECT');
  assert not exists(select 1 from pg_policies where tablename=t and permissive='PERMISSIVE' and cmd<>'SELECT');
 end loop;
 assert (select count(*) from pg_constraint where conrelid='public.affinity_groups'::regclass and contype='f')=2;
 assert (select count(*) from pg_constraint where conrelid='public.affinity_group_items'::regclass and contype='f')=4;
 assert exists(select 1 from pg_constraint where conname='affinity_item_source');
 assert (select count(*) from pg_indexes where schemaname='public' and tablename in ('affinity_groups','affinity_group_items'))=10;
end $$;
select 'AFFINITY_GROUP_ROW='||to_jsonb(g)::text from public.affinity_groups g order by sequence limit 1;
select 'AFFINITY_ITEM_ROW='||to_jsonb(i)::text from public.affinity_group_items i limit 1;
select 'M11.1 canonical sources/exclusive shape/FK/order/duplicates/source preservation/indexes/default-deny/type parity PASS';
rollback;
