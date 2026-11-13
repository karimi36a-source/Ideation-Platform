import {describe,it,expect} from "vitest";
import {votingTypeSchema,votingSessionStatusSchema,votingRevealModeSchema,votingSessionSchema,votingOptionSchema,voteSchema} from "@/features/voting/schema";
const id="00000000-0000-4000-8000-000000000001";
describe("Voting storage contracts",()=>{
 it("uses exact approved vocabularies",()=>{
  expect(votingTypeSchema.options).toEqual(["DOT_VOTE","FIST_TO_FIVE","PLANNING_POKER"]);
  expect(votingSessionStatusSchema.options).toEqual(["DRAFT","OPEN","CLOSED"]);
  expect(votingRevealModeSchema.options).toEqual(["LIVE","HIDDEN_UNTIL_REVEAL"]);
  for(const schema of [votingTypeSchema,votingSessionStatusSchema,votingRevealModeSchema]) expect(schema.safeParse("CUSTOM").success).toBe(false);
 });
 it("preserves zero limits and separates anonymity from reveal",()=>{
  const row={id,activity_instance_id:id,voting_type:"DOT_VOTE",status:"DRAFT",vote_limit:0,anonymous:true,reveal_mode:"HIDDEN_UNTIL_REVEAL",created_by:id,opened_at:null,closed_at:null};
  expect(votingSessionSchema.safeParse(row).success).toBe(true);
  for(const vote_limit of [-1,1.5,2147483648]) expect(votingSessionSchema.safeParse({...row,vote_limit}).success).toBe(false);
 });
 it("allows label-only options and positive integer ordering",()=>{
  const row={id,voting_session_id:id,development_object_id:null,label:"Choice",description:null,sequence:1};
  expect(votingOptionSchema.safeParse(row).success).toBe(true);
  expect(votingOptionSchema.safeParse({...row,label:" "}).success).toBe(false);
  expect(votingOptionSchema.safeParse({...row,sequence:0}).success).toBe(false);
 });
 it("keeps canonical voter and future integer values",()=>{
  const row={id,voting_session_id:id,voting_option_id:id,user_id:id,value:5,created_at:"2026-10-09T00:00:00Z",revealed_at:null};
  expect(voteSchema.safeParse(row).success).toBe(true);
  expect(voteSchema.safeParse({...row,value:1.5}).success).toBe(false);
  expect(voteSchema.safeParse({...row,role:"ADMIN"}).success).toBe(false);
 });
});
