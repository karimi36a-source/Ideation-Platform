import {testVotingCastConcurrency} from "./test-voting-cast-concurrency.mjs";
import {testVotingVoteCloseConcurrency} from "./test-voting-vote-close-concurrency.mjs";
import {testVotingCloseConcurrency} from "./test-voting-close-concurrency.mjs";
import {testDecisionFinalizationConcurrency} from "./test-decision-finalization-concurrency.mjs";
import {testDecisionSupersessionConcurrency} from "./test-decision-supersession-concurrency.mjs";

export async function testM10ConcurrencyHardening(options) {
 for(let iteration=1;iteration<=3;iteration++) {
  await testVotingCastConcurrency(options);
  await testVotingVoteCloseConcurrency(options);
  await testVotingVoteCloseConcurrency({...options,multiple:true});
  await testVotingCloseConcurrency(options);
  await testDecisionFinalizationConcurrency(options);
  await testDecisionSupersessionConcurrency(options);
  const active=Number(options.run("psql",[...options.args,"-t","-A","-c","select count(*) from pg_stat_activity where datname like 'fici_%' or application_name like 'm1019_%' or application_name='m1016_vote_close';"]).trim());
  const databases=Number(options.run("psql",[...options.args,"-t","-A","-c","select count(*) from pg_database where datname like 'fici_%';"]).trim());
  if(active!==0||databases!==0)throw new Error("M10 race backend/database resource leak");
  console.log(`M10.19 isolated core race iteration ${iteration}/3 no deadlock/partial state/orphan connection PASS`);
 }
 console.log("M10.19 repeated concurrency hardening PASS");
}
