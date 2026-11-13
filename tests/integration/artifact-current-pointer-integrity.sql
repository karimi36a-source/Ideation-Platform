-- Appended to the existing trusted M8 fixture; all rows remain disposable.
reset role;
set constraints all immediate;
do $$declare a uuid;v uuid;begin
 select (payload->>'artifactId')::uuid,(payload->>'initialVersionId')::uuid
  into a,v from submitted_fixtures where label='Team';
 assert (select current_version_id is null from public.artifacts where id=a);
 -- Reproduced before M8.22: this write succeeded even at final constraint check.
 begin
  update public.artifacts set current_version_id=v where id=a;
  raise exception 'Draft accepted as current';
 exception when check_violation then null;end;
 assert (select current_version_id is null from public.artifacts where id=a);
 -- Trusted isolated fixture: establish a valid CURRENT, then verify the other
 -- side of the invariant cannot leave a dangling semantic pointer.
 update public.artifact_versions set status='CURRENT',
  approved_by='00000000-0000-4000-8000-000000006002',approved_at=clock_timestamp()
  where id=v;
 update public.artifacts set current_version_id=v where id=a;
 begin
  update public.artifact_versions set status='SUPERSEDED' where id=v;
  raise exception 'Pointed Version lost CURRENT status';
 exception when check_violation then null;end;
 assert (select status='CURRENT' from public.artifact_versions where id=v);
 -- Deferred checks must permit a coherent multi-step final state.
 set constraints all deferred;
 update public.artifact_versions set status='SUPERSEDED' where id=v;
 update public.artifacts set current_version_id=null where id=a;
 set constraints all immediate;
 assert (select current_version_id is null from public.artifacts where id=a);
 assert (select status='SUPERSEDED' from public.artifact_versions where id=v);
 assert not has_function_privilege('authenticated','public.enforce_artifact_current_pointer()','EXECUTE');
 assert not has_function_privilege('anon','public.enforce_artifact_current_pointer()','EXECUTE');
 assert not has_function_privilege('service_role','public.enforce_artifact_current_pointer()','EXECUTE');
end $$;
rollback;
\echo M8.22 current pointer -> same Artifact CURRENT / status-side protection / deferred atomic transition PASS
