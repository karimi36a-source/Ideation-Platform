reset role;
create function pg_temp.share_request(kind text default 'PATENT_RECORD',source uuid default null,dest text default 'TEAM',target uuid default null,permission0 text default 'VIEW',mode0 text default 'SNAPSHOT') returns jsonb language sql as $$
 select jsonb_build_object('entityType',kind,'entityId',coalesce(source,pg_temp.research_source('Patent')),'destinationType',dest,'destinationId',coalesce(target,(select (payload->>'teamId')::uuid from acceptance_teams where label='B')),'permissionLevel',permission0,'shareMode',mode0)
$$;
create function pg_temp.share_denied(request jsonb,reason text) returns void language plpgsql as $$declare r jsonb;begin
 r:=public.resolve_shareability(request);assert r=jsonb_build_object('allowed',false,'deniedReason',reason),r::text;
end$$;
-- Known creator/member is not a Lead yet.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
select pg_temp.share_denied(pg_temp.share_request(),'SHARE_AUTHORITY_DENIED');
do $$begin assert (public.resolve_shareability(pg_temp.share_request(source=>pg_temp.research_source('PersonalPatent'),target=>(select (payload->>'teamId')::uuid from acceptance_teams where label='A')))->>'allowed')::boolean;end$$;
select pg_temp.share_denied(pg_temp.share_request(source=>pg_temp.research_source('PersonalPatent')),'DESTINATION_SCOPE_DENIED');
select pg_temp.share_denied(pg_temp.share_request(source=>pg_temp.research_source('PersonalPatent'),target=>'ffffffff-ffff-4fff-8fff-ffffffffffff'),'DESTINATION_SCOPE_DENIED');
-- The canonical management operation appoints the Lead; no new SHARE grant table.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006002',true);
select public.remove_team_member(t.id,t.team_lead_user_id,'M13.3 isolated Lead transition') from public.teams t where t.id=(select (payload->>'teamId')::uuid from acceptance_teams where label='A') and t.team_lead_user_id is not null;
select public.assign_team_lead((select (payload->>'teamId')::uuid from acceptance_teams where label='A'),'00000000-0000-4000-8000-000000006004');
select public.assign_team_lead((select (payload->>'teamId')::uuid from acceptance_teams where label='B'),'00000000-0000-4000-8000-000000006007');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
