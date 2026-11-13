import { expect, it, vi } from "vitest";
vi.mock("server-only", () => ({}));
import { SYSTEM_ROLE_CODES, roleCodeSchema } from "@/lib/auth/role-codes";

it("defines exactly the four approved system-role identifiers", () => {
  expect(SYSTEM_ROLE_CODES).toEqual(["ADMIN", "MASTER", "MENTOR", "STUDENT"]);
  expect(new Set(SYSTEM_ROLE_CODES).size).toBe(4);
  for (const code of SYSTEM_ROLE_CODES) expect(roleCodeSchema.parse(code)).toBe(code);
});
it.each(["TEAM_LEAD", "OWNER", "admin", "ADMIN ", { code: "ADMIN" }, null])("rejects non-catalog input without granting authority", (input) => {
  expect(roleCodeSchema.safeParse(input).success).toBe(false);
});
