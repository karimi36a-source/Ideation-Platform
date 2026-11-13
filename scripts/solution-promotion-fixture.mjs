import {brainstormPromotionFixture} from "./brainstorm-promotion-fixture.mjs";
import {readFileSync} from "node:fs";
import {join} from "node:path";
export function solutionPromotionFixture(root){return brainstormPromotionFixture(root)+readFileSync(join(root,"tests/integration/solution-promotion-setup.sql"),"utf8");}
