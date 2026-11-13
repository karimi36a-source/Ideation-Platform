import { readFileSync, readdirSync } from "node:fs";
import { join } from "node:path";

// Reuse the canonical M8.7 setup before any submissions or assertions. All
// resources are disposable; no hosted URL or production identity is accepted.
export function artifactReviewSecurityFixture(root) {
  const source = readFileSync(join(root, "tests/integration/submit-artifact.sql"), "utf8");
  const marker = "create temporary table submission_before";
  if (!source.includes(marker)) throw new Error("M8 security fixture boundary missing");
  const functions = new Set();
  for (const file of readdirSync(join(root, "supabase/migrations")).filter(name => /^20261007.*\.sql$/.test(name))) {
    const sql = readFileSync(join(root, "supabase/migrations", file), "utf8");
    for (const match of sql.matchAll(/create\s+(?:or\s+replace\s+)?function\s+public\.([a-z_]+)/gi)) functions.add(match[1]);
  }
  return source.split(marker)[0] + `
create temporary table m8_function_inventory(name text primary key);
insert into m8_function_inventory values ${[...functions].sort().map(name => `('${name}')`).join(",")};
grant select on m8_function_inventory to authenticated,anon;
`;
}
