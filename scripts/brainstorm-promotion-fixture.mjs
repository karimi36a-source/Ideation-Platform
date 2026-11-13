import {readFileSync} from 'node:fs';
import {join} from 'node:path';
import {brainstormRevealFixture} from './brainstorm-reveal-fixture.mjs';
export function brainstormPromotionFixture(root){return brainstormRevealFixture(root)+readFileSync(join(root,'tests/integration/brainstorm-create.sql'),'utf8').split('-- A trusted own revealed fixture')[0]+readFileSync(join(root,'tests/integration/brainstorm-reveal.sql'),'utf8').split('create temporary table br_before')[0]+`
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000006009',true);
select public.reveal_brainstorm_entries((select (payload #>> '{activity,id}')::uuid from bc_activities where label='Reveal1'),array[(select (payload->>'id')::uuid from bc_entries where label='R1')]);
reset role;
select set_config('request.jwt.claim.sub','',true);
`;}
