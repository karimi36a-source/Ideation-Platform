begin;

-- Submission visibility alone must not expose independently inaccessible
-- target content. Compose existing RLS instead of adding a definer bypass or
-- broadening the exact submitted-Version reviewer entitlement. No write grants.
create policy feedback_items_target_guard on public.feedback_items
as restrictive for select to authenticated using (
 exists (
  select 1 from public.submissions s
  join public.artifact_versions v on v.id=s.artifact_version_id and v.artifact_id=s.artifact_id
  where s.id=feedback_items.submission_id
  and (feedback_items.target_version_id is null or feedback_items.target_version_id=v.id)
  and (
   (feedback_items.target_entity_type='ARTIFACT' and feedback_items.target_entity_id=s.artifact_id)
   or (feedback_items.target_entity_type='DEVELOPMENT_OBJECT' and exists (
    select 1 from public.artifact_object_links l
    join public.development_objects o on o.id=l.development_object_id
    where l.artifact_id=s.artifact_id and l.artifact_version_id=v.id
    and o.id=feedback_items.target_entity_id and o.project_id=feedback_items.project_id
   ))
  )
 )
);
comment on policy feedback_items_target_guard on public.feedback_items is
 'M8.15 defense against Feedback child-table leakage: exact Submission plus current submitted-Version and linked Object visibility. Existing business entitlements and write boundaries unchanged.';

commit;
