reset role;
create function pg_temp.make_final(source0 text,title0 text) returns uuid language plpgsql as $$
declare base public.decisions;payload jsonb;did uuid;
begin
 select (jsonb_populate_record(null::public.decisions,f.payload->'decision')).* into base from df_drafts f where f.label=source0;
 payload:=public.create_decision(jsonb_build_object('projectId',base.project_id,'workspaceId',base.workspace_id,'title',title0,'question','Which direction?','method','DISCUSSION','options','[{"label":"Explicit human option"}]'::jsonb)||case when base.activity_instance_id is null then '{}'::jsonb else jsonb_build_object('activityInstanceId',base.activity_instance_id) end);
 did:=(payload#>>'{decision,id}')::uuid;
 perform public.finalize_decision(jsonb_build_object('decisionId',did,'outcome','Human outcome '||title0,'reasoning','Human reasoning '||title0));
 return did;
end $$;
create temporary table sd_cases(label text primary key,id uuid);
grant select,insert on sd_cases to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006009',true);
insert into sd_cases select label,pg_temp.make_final('Team',label) from unnest(array['Old','New','Third','OtherOld','RollbackOld','RollbackNew','LogOld','LogNew','ActivityOld','ActivityNew','ActivityRetryOld','ActivityRetryNew','EqualOld','EqualNew','EarlierOld','EarlierNew','DraftOld','DraftNew','ArchiveOld','ArchiveNew','SupersededNew','Race1Old','Race1New','Race2Old','Race2NewA','Race2NewB','Race3OldA','Race3OldB','Race3New']) label;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006004',true);
insert into sd_cases values('PersonalOld',pg_temp.make_final('Personal','Private old')),('PersonalNew',pg_temp.make_final('Personal','Private new'));
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006007',true);
insert into df_drafts select 'Foreign',public.create_decision(jsonb_build_object('projectId',payload->>'id','workspaceId',payload->>'primary_workspace_id','title','Other Team','question','Q','method','DISCUSSION','options','[{"label":"A"}]'::jsonb)) from logged_projects where label='Brainstorm Team B';
insert into sd_cases values('ForeignNew',pg_temp.make_final('Foreign','Foreign finalized'));
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006009',true);
select public.link_decision_entity(jsonb_build_object('decisionId',(select id from sd_cases where label='Old'),'linkedEntityType','ARTIFACT','linkedEntityId',(select id from df_artifacts where label='Team'),'relationshipType','CONSIDERED_IN_DECISION'));
reset role;
create function pg_temp.sid(label0 text) returns uuid language sql as $$select id from sd_cases where label=label0$$;
create function pg_temp.sd(old0 text,new0 text) returns jsonb language sql as $$select public.supersede_decision(jsonb_build_object('oldDecisionId',pg_temp.sid(old0),'newDecisionId',pg_temp.sid(new0)))$$;
create function pg_temp.denied(old0 text,new0 text,expected0 text) returns void language plpgsql as $$
begin
 begin perform pg_temp.sd(old0,new0);exception when others then if sqlstate=expected0 then return;end if;raise;end;
 raise exception 'Expected supersession denial %',expected0;
end $$;
